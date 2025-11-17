# ============================================================================
# DOWNSTREAM IMPACTS: UNCERTAINTY PROPAGATION & SENSITIVITY ANALYSIS
# ============================================================================
# Purpose: Quantify uncertainty in downstream impact estimates using Monte Carlo
#
# Methods:
#   - Monte Carlo simulation with parameter uncertainty
#   - Sensitivity analysis (Sobol indices or correlation-based)
#   - Credible intervals for impact metrics
#
# Author: NorthStar Labs Blue Carbon Team
# Date: 2024-11
# ============================================================================

library(terra)
library(sf)
library(dplyr)
library(tidyr)
library(ggplot2)

source("blue_carbon_config.R")

cat("\n============================================\n")
cat("UNCERTAINTY PROPAGATION & SENSITIVITY\n")
cat("============================================\n\n")

set.seed(MC_SEED)

# Load results from previous analyses
sediment_results <- read.csv("outputs/downstream/tables/sediment_reduction_by_poi.csv")
nutrient_results <- read.csv("outputs/downstream/tables/nutrient_reduction_by_poi.csv")
flood_results <- read.csv("outputs/downstream/tables/flood_mitigation_by_poi.csv")

cat("1. Setting up Monte Carlo parameter distributions...\n")

# Function to sample from specified distribution
sample_parameter <- function(dist_spec, n) {
  if (dist_spec$type == "normal") {
    return(rnorm(n, mean = dist_spec$mean, sd = dist_spec$sd))
  } else if (dist_spec$type == "beta") {
    return(rbeta(n, shape1 = dist_spec$shape1, shape2 = dist_spec$shape2))
  } else if (dist_spec$type == "lognormal") {
    return(rlnorm(n, meanlog = dist_spec$meanlog, sdlog = dist_spec$sdlog))
  } else if (dist_spec$type == "normal_bounded") {
    samples <- rnorm(n, mean = dist_spec$mean, sd = dist_spec$sd)
    return(pmax(dist_spec$min, pmin(dist_spec$max, samples)))
  } else {
    stop(paste("Unknown distribution type:", dist_spec$type))
  }
}

cat("  Parameter distributions configured ✓\n\n")

cat("2. Running Monte Carlo simulation (", MC_ITERATIONS, "iterations)...\n", sep = "")

# Initialize storage for MC results
mc_sediment <- matrix(NA, nrow = MC_ITERATIONS, ncol = nrow(sediment_results))
mc_nitrogen <- matrix(NA, nrow = MC_ITERATIONS, ncol = nrow(nutrient_results))
mc_phosphorus <- matrix(NA, nrow = MC_ITERATIONS, ncol = nrow(nutrient_results))
mc_peak_flow <- matrix(NA, nrow = MC_ITERATIONS, ncol = nrow(flood_results))

# Store parameter samples for sensitivity analysis
param_samples <- data.frame(
  iter = 1:MC_ITERATIONS,
  rusle_r = sample_parameter(UNCERTAINTY_DISTRIBUTIONS$rusle_r, MC_ITERATIONS),
  delivery_ratio = sample_parameter(UNCERTAINTY_DISTRIBUTIONS$delivery_ratio, MC_ITERATIONS),
  nutrient_export = sample_parameter(UNCERTAINTY_DISTRIBUTIONS$nutrient_export, MC_ITERATIONS),
  curve_number = sample_parameter(UNCERTAINTY_DISTRIBUTIONS$curve_number, MC_ITERATIONS)
)

# Progress bar
pb <- txtProgressBar(min = 0, max = MC_ITERATIONS, style = 3)

for (iter in 1:MC_ITERATIONS) {
  # Sample parameters
  rusle_r_mult <- param_samples$rusle_r[iter] / RUSLE_R_DEFAULT
  sdr_mult <- param_samples$delivery_ratio[iter]
  nutrient_mult <- param_samples$nutrient_export[iter]
  cn_delta <- param_samples$curve_number[iter] - 85  # Deviation from baseline

  # Propagate to sediment results
  for (i in 1:nrow(sediment_results)) {
    baseline_adjusted <- sediment_results$sediment_load_baseline_t_yr[i] * rusle_r_mult
    project_adjusted <- sediment_results$sediment_load_project_y5_t_yr[i] * rusle_r_mult
    # Adjust delivery ratio
    reduction <- (baseline_adjusted - project_adjusted) * sdr_mult
    mc_sediment[iter, i] <- reduction
  }

  # Propagate to nutrient results
  for (i in 1:nrow(nutrient_results)) {
    mc_nitrogen[iter, i] <- nutrient_results$n_reduction_kg_yr[i] * nutrient_mult
    mc_phosphorus[iter, i] <- nutrient_results$p_reduction_kg_yr[i] * nutrient_mult
  }

  # Propagate to flood results (CN affects runoff nonlinearly)
  for (i in 1:nrow(flood_results)) {
    # Simplified: assume linear sensitivity to CN changes
    cn_sensitivity <- -0.02  # 1 unit CN increase → 2% flow increase
    flow_mult <- 1 + (cn_delta * cn_sensitivity)
    mc_peak_flow[iter, i] <- flood_results$peak_flow_reduction_m3s[i] * flow_mult
  }

  setTxtProgressBar(pb, iter)
}
close(pb)

cat("\n  Monte Carlo simulation complete ✓\n\n")

cat("3. Computing uncertainty bounds...\n")

# Function to compute confidence intervals
compute_ci <- function(mc_matrix, poi_names) {
  ci_results <- data.frame()

  for (i in 1:ncol(mc_matrix)) {
    samples <- mc_matrix[, i]

    ci_results <- rbind(ci_results, data.frame(
      poi_name = poi_names[i],
      mean = mean(samples, na.rm = TRUE),
      median = median(samples, na.rm = TRUE),
      sd = sd(samples, na.rm = TRUE),
      cv_pct = (sd(samples, na.rm = TRUE) / mean(samples, na.rm = TRUE)) * 100,
      ci_50_lower = quantile(samples, 0.25, na.rm = TRUE),
      ci_50_upper = quantile(samples, 0.75, na.rm = TRUE),
      ci_80_lower = quantile(samples, 0.10, na.rm = TRUE),
      ci_80_upper = quantile(samples, 0.90, na.rm = TRUE),
      ci_95_lower = quantile(samples, 0.025, na.rm = TRUE),
      ci_95_upper = quantile(samples, 0.975, na.rm = TRUE)
    ))
  }

  return(ci_results)
}

# Compute CIs for each impact type
sediment_ci <- compute_ci(mc_sediment, sediment_results$poi_name)
sediment_ci$metric <- "sediment_reduction_t_yr"

nitrogen_ci <- compute_ci(mc_nitrogen, nutrient_results$poi_name)
nitrogen_ci$metric <- "nitrogen_reduction_kg_yr"

phosphorus_ci <- compute_ci(mc_phosphorus, nutrient_results$poi_name)
phosphorus_ci$metric <- "phosphorus_reduction_kg_yr"

peak_flow_ci <- compute_ci(mc_peak_flow, flood_results$poi_name)
peak_flow_ci$metric <- "peak_flow_reduction_m3s"

# Combine all results
all_ci <- rbind(sediment_ci, nitrogen_ci, phosphorus_ci, peak_flow_ci)
all_ci <- all_ci %>% mutate(across(where(is.numeric), ~ round(.x, 3)))

write.csv(all_ci, "outputs/downstream/tables/uncertainty_intervals_by_metric.csv", row.names = FALSE)

cat("  Uncertainty intervals computed ✓\n")
cat("  Mean coefficient of variation:", round(mean(all_ci$cv_pct, na.rm = TRUE), 1), "%\n\n")

cat("4. Sensitivity analysis...\n")

# Compute Spearman correlation between parameters and outputs
sensitivity_results <- data.frame()

for (metric_name in c("sediment", "nitrogen", "phosphorus", "peak_flow")) {
  mc_data <- get(paste0("mc_", metric_name))
  total_metric <- rowSums(mc_data, na.rm = TRUE)

  for (param_name in SENSITIVITY_PARAMS) {
    if (param_name %in% names(param_samples)) {
      corr <- cor(param_samples[[param_name]], total_metric, method = "spearman")

      sensitivity_results <- rbind(sensitivity_results, data.frame(
        metric = metric_name,
        parameter = param_name,
        spearman_rho = corr,
        importance = abs(corr)
      ))
    }
  }
}

sensitivity_results <- sensitivity_results %>%
  arrange(metric, desc(importance)) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))

write.csv(sensitivity_results, "outputs/downstream/tables/sensitivity_analysis.csv", row.names = FALSE)

cat("  Sensitivity analysis complete ✓\n\n")

cat("5. Creating visualizations...\n")

# Uncertainty waterfall chart
png("outputs/downstream/maps/uncertainty_intervals.png", width = 12, height = 8, units = "in", res = 300)

ggplot(all_ci %>% filter(metric == "sediment_reduction_t_yr"),
       aes(x = reorder(poi_name, mean), y = mean)) +
  geom_bar(stat = "identity", fill = "#2E86AB", alpha = 0.7) +
  geom_errorbar(aes(ymin = ci_95_lower, ymax = ci_95_upper), width = 0.2, color = "darkred") +
  geom_errorbar(aes(ymin = ci_50_lower, ymax = ci_50_upper), width = 0.4, color = "darkblue", size = 1) +
  coord_flip() +
  labs(
    title = "Sediment Reduction with Uncertainty Intervals",
    subtitle = "Dark blue = 50% CI, Red = 95% CI",
    x = "Point of Interest",
    y = "Sediment Reduction (tonnes/yr)"
  ) +
  theme_minimal()

dev.off()

# Sensitivity tornado chart
png("outputs/downstream/maps/sensitivity_tornado.png", width = 10, height = 6, units = "in", res = 300)

ggplot(sensitivity_results %>% filter(metric == "sediment"),
       aes(x = reorder(parameter, importance), y = spearman_rho, fill = spearman_rho > 0)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  scale_fill_manual(values = c("TRUE" = "#2E86AB", "FALSE" = "#A23B72")) +
  labs(
    title = "Parameter Sensitivity (Sediment Reduction)",
    x = "Parameter",
    y = "Spearman Correlation",
    fill = "Direction"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

dev.off()

cat("  Visualizations saved ✓\n\n")

# Summary report
sink("outputs/downstream/uncertainty_summary.txt")
cat("============================================\n")
cat("UNCERTAINTY & SENSITIVITY ANALYSIS\n")
cat("============================================\n\n")

cat("Monte Carlo Simulation:\n")
cat("  Iterations:", MC_ITERATIONS, "\n")
cat("  Random seed:", MC_SEED, "\n\n")

cat("Uncertainty Summary (95% CI):\n")
cat("─────────────────────────────────────────\n")

metrics <- unique(all_ci$metric)
for (m in metrics) {
  subset_data <- all_ci %>% filter(metric == m)
  total_mean <- sum(subset_data$mean)
  total_lower <- sum(subset_data$ci_95_lower)
  total_upper <- sum(subset_data$ci_95_upper)
  rel_uncertainty <- ((total_upper - total_lower) / (2 * total_mean)) * 100

  cat("\n", m, ":\n", sep = "")
  cat("  Mean:", round(total_mean, 2), "\n")
  cat("  95% CI: [", round(total_lower, 2), ",", round(total_upper, 2), "]\n")
  cat("  Relative uncertainty:", round(rel_uncertainty, 1), "%\n")
}

cat("\n\nMost Influential Parameters:\n")
cat("─────────────────────────────────────────\n")

top_params <- sensitivity_results %>%
  group_by(parameter) %>%
  summarize(mean_importance = mean(importance)) %>%
  arrange(desc(mean_importance)) %>%
  head(5)

for (i in 1:nrow(top_params)) {
  cat("  ", i, ". ", top_params$parameter[i], " (importance: ",
      round(top_params$mean_importance[i], 3), ")\n", sep = "")
}

sink()

cat("============================================\n")
cat("UNCERTAINTY ANALYSIS COMPLETE!\n")
cat("============================================\n\n")
cat("Outputs:\n")
cat("  - outputs/downstream/tables/uncertainty_intervals_by_metric.csv\n")
cat("  - outputs/downstream/tables/sensitivity_analysis.csv\n")
cat("  - outputs/downstream/maps/uncertainty_intervals.png\n")
cat("  - outputs/downstream/maps/sensitivity_tornado.png\n")
cat("  - outputs/downstream/uncertainty_summary.txt\n\n")
