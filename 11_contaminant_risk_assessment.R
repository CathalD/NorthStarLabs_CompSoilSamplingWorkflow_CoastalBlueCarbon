# ============================================================================
# MODULE 11: CONTAMINANT RISK ASSESSMENT AND SAMPLING DESIGN
# ============================================================================
# PURPOSE: Assess contamination risk and design integrated sampling plan
#          for Indigenous agriculture restoration sites
#
# INPUTS:
#   - blue_carbon_config.R (configuration)
#   - data_raw/site_characteristics.csv (land use history, proximity factors)
#   - data_raw/core_locations.csv (GPS coordinates from carbon sampling)
#   - ccme_soil_quality_guidelines.csv (CCME standards reference)
#
# OUTPUTS:
#   Risk Assessment (diagnostics/contaminant_assessment/):
#     - risk_assessment_summary.csv (overall risk rating by site/stratum)
#     - recommended_analytes.csv (contaminants to test based on risk)
#     - sampling_plan_contaminants.csv (integrated sampling design)
#     - contaminant_budget_estimate.csv (cost estimate)
#
#   Maps (outputs/maps/contaminant_risk/):
#     - risk_zones_map.png (spatial risk visualization)
#     - sampling_locations_map.png (proposed sampling)
#
# INTEGRATION: Run after Module 01 (data prep) to leverage existing
#              carbon sampling locations for contaminant co-collection
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found. Run 00b_setup_directories.R first.")
}

# Create required output directories
required_dirs <- c(
  "logs",
  "diagnostics/contaminant_assessment",
  "outputs/maps/contaminant_risk",
  "data_processed/contaminant"
)

for (dir in required_dirs) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
}

# Initialize logging
log_file <- file.path("logs", paste0("contaminant_risk_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 11: CONTAMINANT RISK ASSESSMENT ===")

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(sf)
  library(ggplot2)
})

log_message("Packages loaded successfully")

# ============================================================================
# LOAD CCME STANDARDS
# ============================================================================

ccme_standards <- read_csv("ccme_soil_quality_guidelines.csv",
                           show_col_types = FALSE)

log_message(sprintf("Loaded CCME standards for %d contaminants", nrow(ccme_standards)))

# ============================================================================
# RISK SCORING FUNCTIONS
# ============================================================================

#' Calculate contamination risk score based on site characteristics
#'
#' @param site_data Data frame with site characteristics
#' @return Data frame with risk scores (0-100) and risk category
calculate_risk_score <- function(site_data) {

  site_data <- site_data %>%
    mutate(
      # Initialize risk score
      risk_score = 0,

      # Proximity factors (additive scoring)
      risk_score = risk_score + case_when(
        distance_to_road_m < 50 ~ 25,
        distance_to_road_m < 100 ~ 15,
        distance_to_road_m < 200 ~ 5,
        TRUE ~ 0
      ),

      risk_score = risk_score + case_when(
        distance_to_urban_m < 200 ~ 20,
        distance_to_urban_m < 500 ~ 10,
        distance_to_urban_m < 1000 ~ 5,
        TRUE ~ 0
      ),

      risk_score = risk_score + case_when(
        distance_to_industrial_m < 500 ~ 30,
        distance_to_industrial_m < 1000 ~ 15,
        distance_to_industrial_m < 2000 ~ 5,
        TRUE ~ 0
      ),

      risk_score = risk_score + case_when(
        distance_to_railway_m < 100 ~ 20,
        distance_to_railway_m < 200 ~ 10,
        distance_to_railway_m < 500 ~ 5,
        TRUE ~ 0
      ),

      risk_score = risk_score + case_when(
        distance_to_landfill_m < 1000 ~ 25,
        distance_to_landfill_m < 2000 ~ 10,
        TRUE ~ 0
      ),

      # Land use history factors
      risk_score = risk_score + case_when(
        grepl("orchard|nursery", historical_land_use, ignore.case = TRUE) ~ 30,
        grepl("intensive.*agriculture", historical_land_use, ignore.case = TRUE) ~ 20,
        grepl("moderate.*agriculture", historical_land_use, ignore.case = TRUE) ~ 10,
        grepl("industrial", historical_land_use, ignore.case = TRUE) ~ 40,
        grepl("mining", historical_land_use, ignore.case = TRUE) ~ 35,
        grepl("military", historical_land_use, ignore.case = TRUE) ~ 30,
        grepl("urban|residential", historical_land_use, ignore.case = TRUE) ~ 15,
        grepl("natural|undisturbed", historical_land_use, ignore.case = TRUE) ~ 0,
        TRUE ~ 5  # Unknown history = precautionary
      ),

      # Site characteristics
      risk_score = risk_score + case_when(
        floodplain == TRUE ~ 15,
        TRUE ~ 0
      ),

      risk_score = risk_score + case_when(
        visible_contamination == TRUE ~ 50,
        TRUE ~ 0
      ),

      risk_score = risk_score + case_when(
        former_structures == TRUE ~ 10,
        TRUE ~ 0
      ),

      # Cap at 100
      risk_score = pmin(risk_score, 100),

      # Assign risk category
      risk_category = case_when(
        risk_score >= 70 ~ "HIGH",
        risk_score >= 40 ~ "MEDIUM",
        risk_score >= 15 ~ "LOW",
        TRUE ~ "MINIMAL"
      ),

      # Assign priority
      testing_priority = case_when(
        risk_category == "HIGH" ~ "MANDATORY",
        risk_category == "MEDIUM" ~ "RECOMMENDED",
        risk_category == "LOW" ~ "CONSIDER",
        TRUE ~ "OPTIONAL"
      )
    )

  return(site_data)
}

#' Recommend contaminant analytes based on risk factors
#'
#' @param site_data Data frame with site characteristics and risk scores
#' @return Data frame with recommended analytes per site
recommend_analytes <- function(site_data) {

  analyte_recommendations <- list()

  for (i in 1:nrow(site_data)) {
    site <- site_data[i, ]
    analytes <- c()

    # Core suite (always if risk >= MEDIUM)
    if (site$risk_score >= 40) {
      analytes <- c(analytes, "Metals_Core_8")
    }

    # Proximity-based additions
    if (site$distance_to_road_m < 200) {
      analytes <- c(analytes, "Lead", "PAHs", "Zinc")
    }

    if (site$distance_to_railway_m < 200) {
      analytes <- c(analytes, "Metals_Core_8", "PAHs", "PHC_F1_F4")
    }

    if (site$distance_to_industrial_m < 1000) {
      analytes <- c(analytes, "Metals_Extended", "PAHs", "PCBs", "PHC_F1_F4")
    }

    # Land use history based
    if (grepl("orchard|nursery", site$historical_land_use, ignore.case = TRUE)) {
      analytes <- c(analytes, "Arsenic", "Copper", "Lead", "OCPs")
    }

    if (grepl("agriculture", site$historical_land_use, ignore.case = TRUE)) {
      analytes <- c(analytes, "Metals_Core_8", "OCPs", "Herbicides")
    }

    if (grepl("fuel|petroleum|gas", site$historical_land_use, ignore.case = TRUE)) {
      analytes <- c(analytes, "PHC_F1_F4", "BTEX", "PAHs")
    }

    if (grepl("mining", site$historical_land_use, ignore.case = TRUE)) {
      analytes <- c(analytes, "Metals_Extended", "Arsenic", "Cadmium", "Lead", "Mercury")
    }

    # Floodplain
    if (site$floodplain == TRUE) {
      analytes <- c(analytes, "Arsenic", "Cadmium", "Mercury", "Lead")
    }

    # Visible contamination
    if (site$visible_contamination == TRUE) {
      analytes <- c(analytes, "Metals_Extended", "PAHs", "PCBs", "PHC_F1_F4", "VOCs")
    }

    # Remove duplicates and collapse
    analytes <- unique(analytes)

    analyte_recommendations[[i]] <- data.frame(
      site_id = site$site_id,
      stratum = site$stratum,
      risk_category = site$risk_category,
      recommended_analytes = paste(analytes, collapse = "; "),
      analyte_count = length(analytes)
    )
  }

  return(bind_rows(analyte_recommendations))
}

#' Estimate laboratory analysis costs
#'
#' @param analyte_list Character vector of recommended analytes
#' @param n_samples Number of samples
#' @return Estimated cost in CAD
estimate_lab_costs <- function(analyte_list, n_samples = 1) {

  # Cost lookup table (CAD, typical 2024 rates)
  cost_table <- data.frame(
    analyte = c("Metals_Core_8", "Metals_Extended", "PAHs", "PCBs",
                "PHC_F1_F4", "VOCs", "BTEX", "OCPs", "Herbicides",
                "PFAS", "Dioxins_Furans", "Arsenic", "Lead", "Cadmium",
                "Mercury", "Copper", "Zinc", "Chromium_VI"),
    cost_per_sample = c(120, 200, 180, 200, 150, 180, 100, 250, 200,
                        500, 1200, 30, 30, 30, 40, 30, 30, 80)
  )

  total_cost <- 0

  for (analyte in analyte_list) {
    if (analyte %in% cost_table$analyte) {
      total_cost <- total_cost + cost_table$cost_per_sample[cost_table$analyte == analyte]
    }
  }

  # Add overhead (shipping, COC, project management)
  overhead <- total_cost * 0.15

  # QA/QC samples (10% duplicates + 1 blank per batch)
  qaqc_samples <- ceiling(n_samples * 0.1) + 1
  qaqc_cost <- (total_cost / n_samples) * qaqc_samples

  total_project_cost <- (total_cost * n_samples) + overhead + qaqc_cost

  return(list(
    cost_per_sample = total_cost,
    total_samples = n_samples,
    qaqc_samples = qaqc_samples,
    overhead = overhead,
    qaqc_cost = qaqc_cost,
    total_project_cost = total_project_cost
  ))
}

# ============================================================================
# LOAD SITE DATA
# ============================================================================

log_message("Loading site characteristics...")

# Check if site characteristics file exists
if (!file.exists("data_raw/site_characteristics.csv")) {

  log_message("site_characteristics.csv not found. Creating template...", "WARNING")

  # Create template
  template <- data.frame(
    site_id = c("SITE_001", "SITE_002", "SITE_003"),
    stratum = c("Upper Marsh", "Mid Marsh", "Lower Marsh"),
    distance_to_road_m = c(75, 150, 300),
    distance_to_urban_m = c(500, 500, 600),
    distance_to_industrial_m = c(2000, 2000, 2000),
    distance_to_railway_m = c(500, 450, 400),
    distance_to_landfill_m = c(5000, 5000, 5000),
    historical_land_use = c("moderate agriculture", "natural wetland", "natural wetland"),
    floodplain = c(TRUE, TRUE, TRUE),
    visible_contamination = c(FALSE, FALSE, FALSE),
    former_structures = c(FALSE, FALSE, FALSE),
    notes = c("Near old farmstead", "Pristine", "Pristine")
  )

  write_csv(template, "data_raw/site_characteristics.csv")

  log_message("Template created at data_raw/site_characteristics.csv")
  log_message("Please fill in site-specific data and re-run this module.", "INFO")

  cat("\n")
  cat("======================================================================\n")
  cat("ACTION REQUIRED: Edit data_raw/site_characteristics.csv\n")
  cat("======================================================================\n")
  cat("\n")
  cat("A template has been created. Please provide:\n")
  cat("  - Distances to potential contamination sources (meters)\n")
  cat("  - Historical land use information\n")
  cat("  - Site characteristics (floodplain, visible contamination, etc.)\n")
  cat("\n")
  cat("Then re-run this script to generate risk assessment.\n")
  cat("======================================================================\n")

  stop("Site characteristics data required. Template created.")
}

# Load site data
site_data <- read_csv("data_raw/site_characteristics.csv", show_col_types = FALSE)

log_message(sprintf("Loaded characteristics for %d sites", nrow(site_data)))

# ============================================================================
# CALCULATE RISK SCORES
# ============================================================================

log_message("Calculating contamination risk scores...")

site_risk <- calculate_risk_score(site_data)

# Summary statistics
risk_summary <- site_risk %>%
  group_by(risk_category, testing_priority) %>%
  summarise(
    n_sites = n(),
    mean_risk_score = mean(risk_score),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_risk_score))

log_message("Risk assessment complete:")
for (i in 1:nrow(risk_summary)) {
  log_message(sprintf("  %s: %d sites (mean score: %.1f)",
                      risk_summary$risk_category[i],
                      risk_summary$n_sites[i],
                      risk_summary$mean_risk_score[i]))
}

# ============================================================================
# RECOMMEND ANALYTES
# ============================================================================

log_message("Determining recommended analytes by site...")

analyte_recommendations <- recommend_analytes(site_risk)

# ============================================================================
# ESTIMATE COSTS
# ============================================================================

log_message("Estimating laboratory analysis costs...")

cost_estimates <- list()

for (i in 1:nrow(analyte_recommendations)) {
  analytes <- strsplit(analyte_recommendations$recommended_analytes[i], "; ")[[1]]

  # Assume 2 depths per site (0-15 cm, 15-30 cm) for food safety
  n_samples <- 2

  cost_est <- estimate_lab_costs(analytes, n_samples)

  cost_estimates[[i]] <- data.frame(
    site_id = analyte_recommendations$site_id[i],
    stratum = analyte_recommendations$stratum[i],
    n_samples = n_samples,
    cost_per_sample_CAD = cost_est$cost_per_sample,
    total_cost_CAD = cost_est$total_project_cost
  )
}

cost_summary <- bind_rows(cost_estimates)

total_project_cost <- sum(cost_summary$total_cost_CAD)

log_message(sprintf("Total estimated project cost: $%.2f CAD", total_project_cost))

# ============================================================================
# SAVE OUTPUTS
# ============================================================================

log_message("Saving risk assessment outputs...")

# Risk assessment summary
write_csv(site_risk,
          "diagnostics/contaminant_assessment/risk_assessment_summary.csv")

# Analyte recommendations
write_csv(analyte_recommendations,
          "diagnostics/contaminant_assessment/recommended_analytes.csv")

# Cost estimates
write_csv(cost_summary,
          "diagnostics/contaminant_assessment/contaminant_budget_estimate.csv")

# Summary report
summary_report <- site_risk %>%
  select(site_id, stratum, risk_score, risk_category, testing_priority,
         distance_to_road_m, distance_to_urban_m, historical_land_use)

write_csv(summary_report,
          "diagnostics/contaminant_assessment/risk_summary_report.csv")

log_message("Outputs saved to diagnostics/contaminant_assessment/")

# ============================================================================
# VISUALIZATION
# ============================================================================

log_message("Creating risk assessment visualizations...")

# Risk score distribution
p_risk_dist <- ggplot(site_risk, aes(x = risk_category, y = risk_score, fill = risk_category)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, alpha = 0.5) +
  scale_fill_manual(values = c(
    "HIGH" = "#d32f2f",
    "MEDIUM" = "#f57c00",
    "LOW" = "#fbc02d",
    "MINIMAL" = "#689f38"
  )) +
  labs(
    title = "Contamination Risk Assessment Summary",
    subtitle = paste("Total sites:", nrow(site_risk)),
    x = "Risk Category",
    y = "Risk Score (0-100)",
    fill = "Risk Category"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("outputs/maps/contaminant_risk/risk_distribution.png",
       p_risk_dist, width = 8, height = 6, dpi = 300)

# Risk by stratum
p_risk_stratum <- ggplot(site_risk, aes(x = stratum, y = risk_score, fill = risk_category)) +
  geom_col() +
  scale_fill_manual(values = c(
    "HIGH" = "#d32f2f",
    "MEDIUM" = "#f57c00",
    "LOW" = "#fbc02d",
    "MINIMAL" = "#689f38"
  )) +
  labs(
    title = "Risk Score by Stratum",
    x = "Stratum",
    y = "Risk Score",
    fill = "Risk Category"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("outputs/maps/contaminant_risk/risk_by_stratum.png",
       p_risk_stratum, width = 10, height = 6, dpi = 300)

log_message("Visualizations saved to outputs/maps/contaminant_risk/")

# ============================================================================
# INTEGRATION WITH CARBON SAMPLING
# ============================================================================

log_message("Checking integration with carbon sampling locations...")

if (file.exists("data_raw/core_locations.csv")) {

  core_locations <- read_csv("data_raw/core_locations.csv", show_col_types = FALSE)

  # Match sites to core locations
  integrated_plan <- core_locations %>%
    left_join(site_risk, by = c("stratum" = "stratum")) %>%
    left_join(analyte_recommendations, by = c("stratum" = "stratum")) %>%
    select(core_id, longitude, latitude, stratum, risk_category,
           testing_priority, recommended_analytes)

  write_csv(integrated_plan,
            "data_processed/contaminant/integrated_sampling_plan.csv")

  log_message(sprintf("Integrated sampling plan created for %d cores", nrow(integrated_plan)))

} else {
  log_message("core_locations.csv not found. Run Module 01 first for full integration.", "WARNING")
}

# ============================================================================
# GENERATE PLAIN-LANGUAGE SUMMARY
# ============================================================================

cat("\n")
cat("======================================================================\n")
cat("CONTAMINANT RISK ASSESSMENT SUMMARY\n")
cat("======================================================================\n")
cat("\n")
cat(sprintf("Project: %s\n", PROJECT_NAME))
cat(sprintf("Assessment Date: %s\n", Sys.Date()))
cat("\n")

cat("RISK CATEGORY BREAKDOWN:\n")
cat("------------------------\n")
for (i in 1:nrow(risk_summary)) {
  cat(sprintf("  %s (%s): %d sites\n",
              risk_summary$risk_category[i],
              risk_summary$testing_priority[i],
              risk_summary$n_sites[i]))
}
cat("\n")

cat("ESTIMATED COSTS:\n")
cat("----------------\n")
cat(sprintf("  Total project cost: $%.2f CAD\n", total_project_cost))
cat(sprintf("  Average per site: $%.2f CAD\n", mean(cost_summary$total_cost_CAD)))
cat("\n")

cat("RECOMMENDED ACTIONS:\n")
cat("--------------------\n")

high_risk <- site_risk %>% filter(risk_category == "HIGH")
if (nrow(high_risk) > 0) {
  cat(sprintf("  • %d HIGH RISK sites require MANDATORY contaminant testing\n", nrow(high_risk)))
  cat("    (Core metals + additional analyses based on site history)\n")
}

medium_risk <- site_risk %>% filter(risk_category == "MEDIUM")
if (nrow(medium_risk) > 0) {
  cat(sprintf("  • %d MEDIUM RISK sites - Testing RECOMMENDED\n", nrow(medium_risk)))
  cat("    (At minimum: 8 priority metals)\n")
}

low_risk <- site_risk %>% filter(risk_category == "LOW")
if (nrow(low_risk) > 0) {
  cat(sprintf("  • %d LOW RISK sites - Consider baseline testing\n", nrow(low_risk)))
}

cat("\n")
cat("NEXT STEPS:\n")
cat("-----------\n")
cat("  1. Review detailed outputs in diagnostics/contaminant_assessment/\n")
cat("  2. Finalize sampling plan and budget\n")
cat("  3. Select accredited laboratory (see CONTAMINANT_TESTING_GUIDE.md)\n")
cat("  4. Collect samples using integrated protocol (Module 01 + 11)\n")
cat("  5. Process lab results with Module 12\n")
cat("\n")
cat("For detailed guidance, see: CONTAMINANT_TESTING_GUIDE.md\n")
cat("======================================================================\n")

log_message("=== MODULE 11 COMPLETE ===")
log_message(sprintf("Total runtime: %.1f seconds", as.numeric(Sys.time() - SESSION_START, units = "secs")))
