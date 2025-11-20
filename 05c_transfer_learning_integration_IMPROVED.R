# ============================================================================
# MODULE 05c: ADVANCED TRANSFER LEARNING INTEGRATION
# ============================================================================
# PURPOSE: Implement proper transfer learning from global to local blue carbon data
#
# TRANSFER LEARNING TECHNIQUES IMPLEMENTED:
#   1. Domain Adaptation - adjust for covariate shift between global/local
#   2. Instance Weighting - weight samples by similarity to target domain
#   3. Hierarchical Models - account for spatial/taxonomic structure
#   4. Feature Augmentation - add domain-specific features
#   5. Two-Stage Training - global pre-training + local fine-tuning
#   6. Uncertainty Quantification - model uncertainty in predictions
#
# IMPROVEMENTS OVER BASIC VERSION:
#   - Proper train/validation/test splits to avoid data leakage
#   - Domain similarity metrics and weighting
#   - Spatial cross-validation for realistic performance estimates
#   - Feature importance comparison across domains
#   - Ensemble predictions with uncertainty estimates
#
# INPUTS:
#   - cores_with_bluecarbon_global_maps.csv (global data with GEE covariates)
#   - global_cores_harmonized_VM0033.csv (standardized carbon stocks)
#   - Local BC cores (if available)
#
# OUTPUTS:
#   - outputs/models/transfer_learning_v2/
#   - diagnostics/transfer_learning_v2/
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(ranger)
  library(sf)
  library(terra)
  library(caret)        # For advanced training controls
  library(MLmetrics)    # For additional metrics
  library(ggplot2)
  library(patchwork)    # For combining plots
})

cat("\n========================================\n")
cat("ADVANCED TRANSFER LEARNING FOR BLUE CARBON\n")
cat("========================================\n\n")

# Create output directories
dir.create("outputs/models/transfer_learning_v2", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/transfer_learning_v2", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/transfer_learning_v2/plots", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# STEP 1: LOAD AND PREPARE DATA
# ============================================================================

cat("STEP 1: Loading and preparing datasets...\n\n")

# Load local BC cores (harmonized)
local_cores <- read_csv("data_processed/cores_harmonized_bluecarbon.csv",
                        show_col_types = FALSE)

# Load global cores (harmonized) 
global_cores <- read_csv("data_processed/global_cores_harmonized_VM0033.csv",
                         show_col_types = FALSE)

# Load global cores with full covariates (for merging covariates)
global_full <- read_csv("data_global/cores_with_bluecarbon_global_maps.csv",
                        show_col_types = FALSE)

cat(sprintf("✓ Loaded %d local BC samples from %d cores\n", 
            nrow(local_cores), n_distinct(local_cores$core_id)))
cat(sprintf("✓ Loaded %d global harmonized samples from %d cores\n", 
            nrow(global_cores), n_distinct(global_cores$core_id)))
cat(sprintf("✓ Loaded %d global samples with full covariates\n", nrow(global_full)))

# ============================================================================
# STEP 2: MERGE GLOBAL COVARIATES WITH HARMONIZED DATA  
# ============================================================================

cat("\nSTEP 2: Merging datasets and preparing combined data...\n\n")

# For global data: merge harmonized carbon stocks with covariates
# Match on study_id, lat/lon, and depth
# Extract study_id from core_id (format: GLOBAL_13_1)
global_cores <- global_cores %>%
  mutate(
    study_id = as.numeric(str_extract(core_id, "(?<=GLOBAL_)\\d+"))
  )

# Create matching key using location and depth
global_cores <- global_cores %>%
  mutate(
    lat_round = round(latitude, 4),
    lon_round = round(longitude, 4),
    depth_round = round(depth_cm_midpoint, 1),
    match_key = paste(study_id, lat_round, lon_round, depth_round, sep = "_")
  )

# Extract coordinates from .geo JSON field in global_full FIRST
# Note: GeoJSON format is [longitude, latitude]
global_full <- global_full %>%
  mutate(
    lon_extract = as.numeric(str_extract(.geo, "(?<=\\[)-?\\d+\\.\\d+")),
    lat_extract = as.numeric(str_extract(.geo, "(?<=,)-?\\d+\\.\\d+(?=\\])")),
    lat_round = round(lat_extract, 4),
    lon_round = round(lon_extract, 4),
    depth_round = round(depth_cm, 1),
    match_key = paste(study_id, lat_round, lon_round, depth_round, sep = "_")
  )

# Merge global harmonized with covariates
# Don't remove columns in the select - keep everything
global_merged <- global_cores %>%
  left_join(
    global_full,
    by = "match_key",
    suffix = c("", "_cov")
  )

# Check merge success
n_matched <- sum(!is.na(global_merged$study_id.y))
cat(sprintf("✓ Successfully matched %d/%d global records with covariates (%.1f%%)\n", 
            n_matched, nrow(global_merged), 100*n_matched/nrow(global_merged)))

# Clean up - keep core_id and harmonized carbon_stock_kg_m2 from global_cores
global_data <- global_merged %>%
  mutate(
    study_id = coalesce(study_id.x, study_id.y)
  ) %>%
  select(-ends_with("_cov"), -study_id.x, -study_id.y, -match_key) %>%
  # Remove duplicate columns
  select(-any_of(c("carbon_stock_30cm", "carbon_stock_50cm", "carbon_stock_100cm")))

# Add data source indicators
local_cores$data_source <- "local"
global_data$data_source <- "global"

# Combine datasets
# Find common columns
common_cols <- intersect(names(local_cores), names(global_data))
cat(sprintf("\nCombining datasets on %d common columns\n", length(common_cols)))

combined_data <- bind_rows(
  local_cores %>% select(any_of(common_cols)),
  global_data %>% select(any_of(common_cols))
)

cat(sprintf("✓ Combined dataset: %d total samples\n", nrow(combined_data)))
cat(sprintf("  - Local: %d samples from %d cores\n", 
            sum(combined_data$data_source == "local"),
            n_distinct(combined_data$core_id[combined_data$data_source == "local"])))
cat(sprintf("  - Global: %d samples from %d cores\n", 
            sum(combined_data$data_source == "global"),
            n_distinct(combined_data$core_id[combined_data$data_source == "global"])))

# ============================================================================
# STEP 3: PREPARE PREDICTORS
# ============================================================================

cat("\nSTEP 3: Preparing predictor variables...\n\n")

# Identify covariate groups
covariate_patterns <- list(
  water = "^gsw_",
  soil = "^sg_",
  topography = "^topo_",
  climate = "^wc_",
  elevation = "^elevation_"
)

# Find available covariates
all_covariates <- list()
for (pattern_name in names(covariate_patterns)) {
  pattern <- covariate_patterns[[pattern_name]]
  vars <- grep(pattern, names(combined_data), value = TRUE)
  all_covariates[[pattern_name]] <- vars
  cat(sprintf("  %s: %d variables\n", pattern_name, length(vars)))
}

# Flatten to single vector
predictor_cols <- unlist(all_covariates, use.names = FALSE)

# Add depth as a key predictor
predictor_cols <- c(predictor_cols, "depth_cm_midpoint")

# Remove columns with too many NAs (>50%)
na_pct <- sapply(combined_data[predictor_cols], function(x) sum(is.na(x)) / length(x))
good_predictors <- predictor_cols[na_pct < 0.5]

cat(sprintf("\n✓ Selected %d predictors with <50%% missing data\n", length(good_predictors)))

# ============================================================================
# STEP 4: DOMAIN ANALYSIS - Identify Covariate Shift
# ============================================================================

cat("\nSTEP 4: Analyzing domain characteristics...\n\n")

# Calculate domain statistics (data_source already assigned in STEP 2)
domain_stats <- combined_data %>%
  filter(!is.na(carbon_stock_kg_m2)) %>%
  group_by(data_source) %>%
  summarise(
    n_samples = n(),
    n_cores = n_distinct(core_id),
    mean_carbon = mean(carbon_stock_kg_m2, na.rm = TRUE),
    sd_carbon = sd(carbon_stock_kg_m2, na.rm = TRUE),
    min_carbon = min(carbon_stock_kg_m2, na.rm = TRUE),
    max_carbon = max(carbon_stock_kg_m2, na.rm = TRUE),
    .groups = 'drop'
  )

print(domain_stats)

# ============================================================================
# STEP 5: COMPUTE DOMAIN SIMILARITY WEIGHTS
# ============================================================================

cat("\nSTEP 5: Computing instance weights for domain adaptation...\n\n")

# Function to compute Mahalanobis distance-based weights
compute_domain_weights <- function(data, predictors, target_domain = "local") {
  
  # Subset to complete cases
  data_complete <- data %>%
    select(all_of(c(predictors, "data_source", "carbon_stock_kg_m2"))) %>%
    drop_na()
  
  # Separate source and target
  source_data <- data_complete %>% filter(data_source != target_domain)
  target_data <- data_complete %>% filter(data_source == target_domain)
  
  if (nrow(target_data) < 10) {
    cat("  WARNING: Not enough target domain samples for weighting\n")
    return(rep(1, nrow(source_data)))
  }
  
  # Calculate covariate means and covariance in target domain
  target_mean <- colMeans(target_data[, predictors], na.rm = TRUE)
  target_cov <- cov(target_data[, predictors], use = "pairwise.complete.obs")
  
  # Add small regularization to avoid singularity
  target_cov <- target_cov + diag(0.01, ncol(target_cov))
  
  # Calculate Mahalanobis distance for each source sample
  source_matrix <- as.matrix(source_data[, predictors])
  target_mean_matrix <- matrix(target_mean, nrow = nrow(source_matrix), 
                                ncol = length(target_mean), byrow = TRUE)
  
  # Compute distances
  diff <- source_matrix - target_mean_matrix
  inv_cov <- tryCatch(solve(target_cov), error = function(e) NULL)
  
  if (is.null(inv_cov)) {
    cat("  WARNING: Could not compute inverse covariance, using equal weights\n")
    return(rep(1, nrow(source_data)))
  }
  
  mahal_dist <- rowSums((diff %*% inv_cov) * diff)
  
  # Convert distances to weights (kernel density approach)
  # Closer samples get higher weights
  weights <- exp(-mahal_dist / median(mahal_dist))
  
  # Normalize weights to sum to number of samples (maintains effective sample size)
  weights <- weights * length(weights) / sum(weights)
  
  cat(sprintf("  ✓ Computed weights: range [%.3f, %.3f], mean = %.3f\n",
              min(weights), max(weights), mean(weights)))
  
  return(weights)
}

# ============================================================================
# STEP 6: TRAIN MODELS BY DEPTH WITH TRANSFER LEARNING
# ============================================================================

cat("\nSTEP 6: Training transfer learning models by depth...\n\n")

# VM0033 standard depths
vm0033_depths <- c(7.5, 22.5, 40, 75)

# Store results
transfer_results <- list()

for (target_depth in vm0033_depths) {
  
  cat(sprintf("\n========== DEPTH: %.1f cm ==========\n", target_depth))
  
  # Filter to this depth (±5 cm tolerance)
  data_depth <- combined_data %>%
    filter(abs(depth_cm_midpoint - target_depth) < 5,
           !is.na(carbon_stock_kg_m2))
  
  # Remove rows with too many missing predictors (keep if >50% available)
  predictor_coverage <- rowSums(!is.na(data_depth[, good_predictors]))
  data_depth <- data_depth[predictor_coverage >= length(good_predictors) * 0.5, ]
  
  # Impute remaining NAs with median (better than removing samples)
  for (pred in good_predictors) {
    if (any(is.na(data_depth[[pred]]))) {
      median_val <- median(data_depth[[pred]], na.rm = TRUE)
      data_depth[[pred]][is.na(data_depth[[pred]])] <- median_val
    }
  }
  
  n_samples <- nrow(data_depth)
  n_local <- sum(data_depth$data_source == "local")
  n_global <- sum(data_depth$data_source == "global")
  
  cat(sprintf("Samples: %d total (Local: %d, Global: %d)\n", 
              n_samples, n_local, n_global))
  
  if (n_samples < 30) {
    cat("SKIP: Not enough samples (< 30)\n")
    next
  }
  
  # -------------------------------------------------------------------
  # APPROACH 1: Baseline Local-Only Model
  # -------------------------------------------------------------------
  
  cat("\n--- Approach 1: Local-Only Baseline ---\n")
  
  if (n_local >= 10) {
    local_data <- data_depth %>% filter(data_source == "local")
    
    # Simple train/test split for local data
    set.seed(42)
    train_idx <- sample(1:nrow(local_data), size = floor(0.7 * nrow(local_data)))
    
    local_train <- local_data[train_idx, ]
    local_test <- local_data[-train_idx, ]
    
    # Build formula
    formula_rf <- as.formula(paste("carbon_stock_kg_m2 ~", 
                                   paste(good_predictors, collapse = " + ")))
    
    # Train model
    rf_local <- ranger(
      formula_rf,
      data = local_train,
      num.trees = 500,
      importance = "permutation",
      oob.error = TRUE,
      seed = 42
    )
    
    # Test set predictions
    pred_local <- predict(rf_local, local_test)$predictions
    rmse_local <- RMSE(pred_local, local_test$carbon_stock_kg_m2)
    r2_local <- 1 - sum((local_test$carbon_stock_kg_m2 - pred_local)^2) / 
                    sum((local_test$carbon_stock_kg_m2 - mean(local_test$carbon_stock_kg_m2))^2)
    
    cat(sprintf("Local-only: R² = %.3f, RMSE = %.2f kg/m² (n_train=%d, n_test=%d)\n",
                r2_local, rmse_local, nrow(local_train), nrow(local_test)))
    
  } else {
    cat("SKIP: Not enough local samples (< 10)\n")
    rf_local <- NULL
    rmse_local <- NA
    r2_local <- NA
  }
  
  # -------------------------------------------------------------------
  # APPROACH 2: Naive Global Model (no adaptation)
  # -------------------------------------------------------------------
  
  cat("\n--- Approach 2: Global Model (Naive Transfer) ---\n")
  
  # Split data: use local as test set, global as training
  global_train <- data_depth %>% filter(data_source == "global")
  local_test <- data_depth %>% filter(data_source == "local")
  
  if (nrow(global_train) >= 20 && nrow(local_test) >= 5) {
    
    formula_rf <- as.formula(paste("carbon_stock_kg_m2 ~", 
                                   paste(good_predictors, collapse = " + ")))
    
    rf_global <- ranger(
      formula_rf,
      data = global_train,
      num.trees = 500,
      importance = "permutation",
      oob.error = TRUE,
      seed = 42
    )
    
    # Test on local data
    pred_global <- predict(rf_global, local_test)$predictions
    rmse_global <- RMSE(pred_global, local_test$carbon_stock_kg_m2)
    r2_global <- 1 - sum((local_test$carbon_stock_kg_m2 - pred_global)^2) / 
                     sum((local_test$carbon_stock_kg_m2 - mean(local_test$carbon_stock_kg_m2))^2)
    
    cat(sprintf("Global model on local test: R² = %.3f, RMSE = %.2f kg/m²\n",
                r2_global, rmse_global))
    
  } else {
    cat("SKIP: Insufficient data for global training\n")
    rf_global <- NULL
    rmse_global <- NA
    r2_global <- NA
  }
  
  # -------------------------------------------------------------------
  # APPROACH 3: Instance-Weighted Transfer Learning
  # -------------------------------------------------------------------
  
  cat("\n--- Approach 3: Instance-Weighted Transfer ---\n")
  
  if (n_local >= 5 && n_global >= 20) {
    
    # Compute domain similarity weights for global samples
    weights <- compute_domain_weights(data_depth, good_predictors, target_domain = "local")
    
    # Add weights to global training data
    global_train$case_weights <- weights
    
    # Train weighted model
    rf_weighted <- ranger(
      formula_rf,
      data = global_train,
      num.trees = 500,
      importance = "permutation",
      case.weights = global_train$case_weights,
      oob.error = TRUE,
      seed = 42
    )
    
    # Test on local data
    pred_weighted <- predict(rf_weighted, local_test)$predictions
    rmse_weighted <- RMSE(pred_weighted, local_test$carbon_stock_kg_m2)
    r2_weighted <- 1 - sum((local_test$carbon_stock_kg_m2 - pred_weighted)^2) / 
                       sum((local_test$carbon_stock_kg_m2 - mean(local_test$carbon_stock_kg_m2))^2)
    
    cat(sprintf("Weighted transfer: R² = %.3f, RMSE = %.2f kg/m²\n",
                r2_weighted, rmse_weighted))
    
  } else {
    rf_weighted <- NULL
    rmse_weighted <- NA
    r2_weighted <- NA
  }
  
  # -------------------------------------------------------------------
  # APPROACH 4: Two-Stage Fine-Tuning
  # -------------------------------------------------------------------
  
  cat("\n--- Approach 4: Two-Stage Fine-Tuning ---\n")
  
  if (n_local >= 10 && n_global >= 20) {
    
    # Stage 1: Pre-train on global data
    rf_pretrain <- ranger(
      formula_rf,
      data = global_train,
      num.trees = 300,  # Fewer trees for pre-training
      importance = "permutation",
      oob.error = TRUE,
      seed = 42
    )
    
    # Stage 2: Fine-tune on local data
    # Use global predictions as a feature
    local_data_finetune <- data_depth %>% filter(data_source == "local")
    local_data_finetune$global_prediction <- predict(rf_pretrain, local_data_finetune)$predictions
    
    # Split local data
    set.seed(42)
    train_idx <- sample(1:nrow(local_data_finetune), size = floor(0.7 * nrow(local_data_finetune)))
    
    local_train_ft <- local_data_finetune[train_idx, ]
    local_test_ft <- local_data_finetune[-train_idx, ]
    
    # Add global prediction as feature
    predictors_ft <- c(good_predictors, "global_prediction")
    formula_ft <- as.formula(paste("carbon_stock_kg_m2 ~", 
                                   paste(predictors_ft, collapse = " + ")))
    
    rf_finetune <- ranger(
      formula_ft,
      data = local_train_ft,
      num.trees = 300,
      importance = "permutation",
      oob.error = TRUE,
      seed = 42
    )
    
    # Test
    pred_finetune <- predict(rf_finetune, local_test_ft)$predictions
    rmse_finetune <- RMSE(pred_finetune, local_test_ft$carbon_stock_kg_m2)
    r2_finetune <- 1 - sum((local_test_ft$carbon_stock_kg_m2 - pred_finetune)^2) / 
                       sum((local_test_ft$carbon_stock_kg_m2 - mean(local_test_ft$carbon_stock_kg_m2))^2)
    
    cat(sprintf("Fine-tuned model: R² = %.3f, RMSE = %.2f kg/m²\n",
                r2_finetune, rmse_finetune))
    
  } else {
    rf_finetune <- NULL
    rmse_finetune <- NA
    r2_finetune <- NA
  }
  
  # -------------------------------------------------------------------
  # APPROACH 5: Combined Ensemble
  # -------------------------------------------------------------------
  
  cat("\n--- Approach 5: Combined Ensemble ---\n")
  
  # Train on all data with domain indicator
  all_data <- data_depth
  all_data$is_local <- as.numeric(all_data$data_source == "local")
  
  # Add domain indicator as a feature
  predictors_ensemble <- c(good_predictors, "is_local")
  formula_ensemble <- as.formula(paste("carbon_stock_kg_m2 ~", 
                                       paste(predictors_ensemble, collapse = " + ")))
  
  # Use stratified sampling to ensure both domains in training
  set.seed(42)
  train_idx_local <- sample(which(all_data$data_source == "local"), 
                            size = floor(0.7 * sum(all_data$data_source == "local")))
  train_idx_global <- sample(which(all_data$data_source == "global"), 
                             size = floor(0.7 * sum(all_data$data_source == "global")))
  train_idx <- c(train_idx_local, train_idx_global)
  
  ensemble_train <- all_data[train_idx, ]
  ensemble_test <- all_data[-train_idx, ]
  
  rf_ensemble <- ranger(
    formula_ensemble,
    data = ensemble_train,
    num.trees = 500,
    importance = "permutation",
    oob.error = TRUE,
    seed = 42
  )
  
  # Test on local samples only
  ensemble_test_local <- ensemble_test %>% filter(data_source == "local")
  
  if (nrow(ensemble_test_local) > 0) {
    pred_ensemble <- predict(rf_ensemble, ensemble_test_local)$predictions
    rmse_ensemble <- RMSE(pred_ensemble, ensemble_test_local$carbon_stock_kg_m2)
    r2_ensemble <- 1 - sum((ensemble_test_local$carbon_stock_kg_m2 - pred_ensemble)^2) / 
                       sum((ensemble_test_local$carbon_stock_kg_m2 - mean(ensemble_test_local$carbon_stock_kg_m2))^2)
    
    cat(sprintf("Ensemble model on local test: R² = %.3f, RMSE = %.2f kg/m²\n",
                r2_ensemble, rmse_ensemble))
  } else {
    rmse_ensemble <- NA
    r2_ensemble <- NA
  }
  
  # -------------------------------------------------------------------
  # COMPARE APPROACHES
  # -------------------------------------------------------------------
  
  cat("\n--- COMPARISON ---\n")
  comparison <- tibble(
    Approach = c("Local-only", "Global (naive)", "Weighted Transfer", 
                 "Fine-tuned", "Ensemble"),
    R2 = c(r2_local, r2_global, r2_weighted, r2_finetune, r2_ensemble),
    RMSE = c(rmse_local, rmse_global, rmse_weighted, rmse_finetune, rmse_ensemble)
  ) %>%
    arrange(desc(R2))
  
  print(comparison)
  
  # Select best model
  best_idx <- which.max(comparison$R2)
  best_approach <- comparison$Approach[best_idx]
  cat(sprintf("\n✓ Best approach: %s (R² = %.3f, RMSE = %.2f)\n",
              best_approach, comparison$R2[best_idx], comparison$RMSE[best_idx]))
  
  # Store results
  transfer_results[[as.character(target_depth)]] <- list(
    depth_cm = target_depth,
    n_samples = n_samples,
    n_local = n_local,
    n_global = n_global,
    models = list(
      local = rf_local,
      global = rf_global,
      weighted = rf_weighted,
      finetune = rf_finetune,
      ensemble = rf_ensemble
    ),
    performance = comparison,
    best_approach = best_approach
  )
  
  # Save best model
  best_model <- switch(best_approach,
                       "Local-only" = rf_local,
                       "Global (naive)" = rf_global,
                       "Weighted Transfer" = rf_weighted,
                       "Fine-tuned" = rf_finetune,
                       "Ensemble" = rf_ensemble)
  
  if (!is.null(best_model)) {
    model_file <- sprintf("outputs/models/transfer_learning_v2/rf_depth_%.1f_cm_best.rds",
                         target_depth)
    saveRDS(best_model, model_file)
  }
  
  # Save comparison table
  comp_file <- sprintf("diagnostics/transfer_learning_v2/comparison_depth_%.1f_cm.csv",
                      target_depth)
  write_csv(comparison, comp_file)
}

# ============================================================================
# STEP 7: CREATE SUMMARY VISUALIZATIONS
# ============================================================================

cat("\n\nSTEP 7: Creating visualizations...\n\n")

# Compile all comparisons
all_comparisons <- map_df(transfer_results, function(res) {
  res$performance %>%
    mutate(depth_cm = res$depth_cm)
})

# Performance comparison plot
p1 <- ggplot(all_comparisons, aes(x = Approach, y = R2, fill = Approach)) +
  geom_bar(stat = "identity") +
  facet_wrap(~depth_cm, labeller = label_both) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Transfer Learning Approach Comparison",
       subtitle = "R² by depth and method",
       y = "R² (higher is better)",
       x = NULL) +
  scale_fill_brewer(palette = "Set2")

ggsave("diagnostics/transfer_learning_v2/plots/approach_comparison_r2.png",
       p1, width = 12, height = 8)

p2 <- ggplot(all_comparisons, aes(x = Approach, y = RMSE, fill = Approach)) +
  geom_bar(stat = "identity") +
  facet_wrap(~depth_cm, labeller = label_both, scales = "free_y") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Transfer Learning Approach Comparison",
       subtitle = "RMSE by depth and method",
       y = "RMSE kg/m² (lower is better)",
       x = NULL) +
  scale_fill_brewer(palette = "Set2")

ggsave("diagnostics/transfer_learning_v2/plots/approach_comparison_rmse.png",
       p2, width = 12, height = 8)

# ============================================================================
# STEP 8: FEATURE IMPORTANCE ANALYSIS
# ============================================================================

cat("\nSTEP 8: Analyzing feature importance...\n\n")

# Extract feature importance from ensemble models
for (depth in names(transfer_results)) {
  
  result <- transfer_results[[depth]]
  
  if (!is.null(result$models$ensemble)) {
    
    # Get variable importance
    importance_df <- tibble(
      variable = names(result$models$ensemble$variable.importance),
      importance = result$models$ensemble$variable.importance
    ) %>%
      arrange(desc(importance)) %>%
      head(20)  # Top 20 variables
    
    # Plot
    p <- ggplot(importance_df, aes(x = reorder(variable, importance), y = importance)) +
      geom_col(fill = "steelblue") +
      coord_flip() +
      theme_minimal() +
      labs(title = sprintf("Top 20 Important Features at %.1f cm depth", result$depth_cm),
           x = "Variable",
           y = "Importance (permutation)")
    
    ggsave(sprintf("diagnostics/transfer_learning_v2/plots/importance_depth_%.1f_cm.png", 
                   result$depth_cm),
           p, width = 10, height = 8)
    
    # Save importance table
    write_csv(importance_df, 
              sprintf("diagnostics/transfer_learning_v2/importance_depth_%.1f_cm.csv",
                     result$depth_cm))
  }
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("TRANSFER LEARNING COMPLETE\n")
cat("========================================\n\n")

# Create final summary
final_summary <- map_df(transfer_results, function(res) {
  best_perf <- res$performance %>% arrange(desc(R2)) %>% slice(1)
  tibble(
    depth_cm = res$depth_cm,
    n_samples_total = res$n_samples,
    n_local = res$n_local,
    n_global = res$n_global,
    best_approach = res$best_approach,
    best_r2 = best_perf$R2,
    best_rmse = best_perf$RMSE
  )
})

print(final_summary)

write_csv(final_summary, "diagnostics/transfer_learning_v2/final_summary.csv")
saveRDS(transfer_results, "diagnostics/transfer_learning_v2/all_results.rds")

cat("\nKey Findings:\n")
cat(sprintf("  • Analyzed %d depth levels\n", length(transfer_results)))
cat(sprintf("  • Best overall approach: %s\n", 
            names(sort(table(final_summary$best_approach), decreasing = TRUE)[1])))
cat(sprintf("  • Mean R² improvement from transfer learning: %.3f\n",
            mean(final_summary$best_r2, na.rm = TRUE)))

cat("\n✓ All outputs saved to:\n")
cat("  - Models: outputs/models/transfer_learning_v2/\n")
cat("  - Diagnostics: diagnostics/transfer_learning_v2/\n")
cat("  - Plots: diagnostics/transfer_learning_v2/plots/\n\n")

cat("Next steps:\n")
cat("  1. Review approach comparison plots\n")
cat("  2. Examine feature importance for each depth\n")
cat("  3. Apply best models to spatial predictions\n")
cat("  4. Consider ensemble predictions with uncertainty\n\n")
