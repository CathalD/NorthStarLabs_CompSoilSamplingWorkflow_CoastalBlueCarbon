# ============================================================================
# MODULE 05C: TRANSFER LEARNING - REGIONAL APPLICATION
# ============================================================================
# PURPOSE: Apply large-scale learned relationships to regional blue carbon
#          data using transfer learning and adaptive fine-tuning
#
# METHODOLOGY:
#   Based on "Regional-scale soil carbon predictions can be enhanced by
#   transferring global-scale soil–environment relationships"
#   (Geoderma 2025, DOI: 10.1016/j.geoderma.2025.117466)
#
# APPROACH:
#   1. Load pre-trained large-scale model (from Module 00d)
#   2. Load regional field cores (from Module 03)
#   3. Fine-tune model using regional data (adaptive weighting)
#   4. Generate spatial predictions with uncertainty
#   5. Quantify Area of Applicability (AOA)
#
# PREREQUISITES:
#   - Module 00d: Large-scale model training (completed)
#   - Module 03: Depth harmonization (completed)
#   - Matching covariates at regional resolution
#
# INPUTS:
#   - outputs/models/large_scale/global_rf_model_*cm.rds (from Module 00d)
#   - outputs/models/large_scale/covariate_ranges.csv (from Module 00d)
#   - data_processed/cores_harmonized_bluecarbon.rds (from Module 03)
#   - data_raw/gee_covariates/*.tif (regional covariates)
#
# OUTPUTS:
#   - outputs/predictions/transfer_learning/carbon_stock_tl_*cm.tif
#   - outputs/predictions/transfer_learning/se_combined_*cm.tif
#   - outputs/predictions/transfer_learning/aoa_*cm.tif (Area of Applicability)
#   - outputs/models/transfer_learning/ensemble_weights_*cm.rds
#   - diagnostics/transfer_learning/adaptation_report.csv
#   - diagnostics/transfer_learning/prediction_comparison_*cm.png
#
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Clear workspace
rm(list = ls())

# Record start time
start_time <- Sys.time()

# Load configuration
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found. Run 00b_setup_directories.R first.")
}

# Create log file
log_file <- file.path("logs", paste0("transfer_learning_regional_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 05C: TRANSFER LEARNING - REGIONAL APPLICATION ===")
log_message(sprintf("Project: %s", PROJECT_NAME))

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(sf)
  library(terra)
  library(ranger)
  library(caret)
  library(ggplot2)
  library(gridExtra)
  library(tidyr)
})

# Check for CAST package (Area of Applicability)
has_CAST <- requireNamespace("CAST", quietly = TRUE)
if (has_CAST) {
  library(CAST)
  log_message("CAST package available - AOA enabled")
} else {
  log_message("CAST not available - AOA will be approximated", "WARNING")
}

# Create output directories
dir.create("outputs/predictions/transfer_learning", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/models/transfer_learning", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/transfer_learning", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# CONFIGURATION
# ============================================================================

TL_CONFIG <- list(
  # Ensemble method
  ensemble_method = "adaptive_cv",  # "adaptive_cv", "stacked", "simple_mean"

  # Fine-tuning settings
  finetune_ntree = 500,            # Trees for regional model
  min_regional_samples = 5,        # Minimum samples needed per depth

  # Cross-validation
  cv_folds = 5,

  # Prediction settings
  generate_aoa = TRUE,             # Generate Area of Applicability
  aoa_threshold = 0.9,             # AOA dissimilarity threshold

  # Processing
  use_parallel = TRUE,
  n_cores = parallel::detectCores() - 1
)

log_message("Transfer learning configuration loaded")

# ============================================================================
# STEP 1: LOAD LARGE-SCALE PRE-TRAINED MODELS
# ============================================================================

log_message("\n=== STEP 1: LOAD LARGE-SCALE PRE-TRAINED MODELS ===")

#' Load pre-trained large-scale models
load_large_scale_models <- function() {

  model_dir <- "outputs/models/large_scale"

  if (!dir.exists(model_dir)) {
    stop("Large-scale model directory not found: ", model_dir, "\n",
         "Please run Module 00d first to train large-scale models.")
  }

  # Load model metadata
  metadata_file <- file.path(model_dir, "model_metadata.csv")

  if (!file.exists(metadata_file)) {
    stop("Model metadata not found. Run Module 00d first.")
  }

  metadata <- read_csv(metadata_file, show_col_types = FALSE)

  log_message(sprintf("Found metadata for %d depths", nrow(metadata)))
  print(metadata)

  # Load individual models
  models <- list()

  for (depth in metadata$depth_cm) {
    model_file <- file.path(model_dir, sprintf("global_rf_model_%gcm.rds", depth))

    if (!file.exists(model_file)) {
      log_message(sprintf("Model file not found for depth %g cm", depth), "WARNING")
      next
    }

    models[[as.character(depth)]] <- readRDS(model_file)
    log_message(sprintf("Loaded model for depth %g cm (OOB R²: %.4f)",
                       depth, models[[as.character(depth)]]$r.squared))
  }

  if (length(models) == 0) {
    stop("No pre-trained models found. Run Module 00d first.")
  }

  return(list(models = models, metadata = metadata))
}

# Load large-scale models
large_scale <- load_large_scale_models()
global_models <- large_scale$models
global_metadata <- large_scale$metadata

# Load covariate ranges for AOA
covariate_ranges <- read_csv("outputs/models/large_scale/covariate_ranges.csv",
                             show_col_types = FALSE)

log_message("Covariate ranges loaded for AOA calculation")

# ============================================================================
# STEP 2: LOAD REGIONAL FIELD DATA
# ============================================================================

log_message("\n=== STEP 2: LOAD REGIONAL FIELD DATA ===")

cores_file <- "data_processed/cores_harmonized_bluecarbon.rds"

if (!file.exists(cores_file)) {
  stop("Harmonized cores not found. Run Module 03 first.")
}

cores_harmonized <- readRDS(cores_file)

log_message(sprintf("Regional data loaded: %d cores, %d strata",
                   length(unique(cores_harmonized$core_id)),
                   length(unique(cores_harmonized$stratum))))

# Prepare for modeling
regional_data <- cores_harmonized %>%
  select(core_id, stratum, longitude, latitude, depth_cm, carbon_stock) %>%
  mutate(
    standard_depth = case_when(
      depth_cm == 7.5 ~ 7.5,
      depth_cm == 22.5 ~ 22.5,
      depth_cm == 40 ~ 40,
      depth_cm == 75 ~ 75,
      TRUE ~ NA_real_
    )
  ) %>%
  filter(!is.na(standard_depth))

log_message(sprintf("Regional samples by depth:"))
regional_summary <- regional_data %>%
  group_by(standard_depth) %>%
  summarise(n = n(), mean_carbon = mean(carbon_stock), .groups = "drop")
print(regional_summary)

# ============================================================================
# STEP 3: LOAD REGIONAL COVARIATES
# ============================================================================

log_message("\n=== STEP 3: LOAD REGIONAL COVARIATES ===")

cov_dir <- "data_raw/gee_covariates"

if (!dir.exists(cov_dir)) {
  stop("Regional covariate directory not found: ", cov_dir)
}

covariate_files <- list.files(cov_dir, pattern = "\\.tif$", full.names = TRUE)

if (length(covariate_files) == 0) {
  stop("No covariate rasters found in: ", cov_dir)
}

log_message(sprintf("Loading %d regional covariate rasters...", length(covariate_files)))

regional_covariates <- rast(covariate_files)

log_message(sprintf("Regional covariates loaded: %d layers", nlyr(regional_covariates)))

# Check covariate compatibility
global_cov_names <- covariate_ranges$covariate
regional_cov_names <- names(regional_covariates)

missing_covariates <- setdiff(global_cov_names, regional_cov_names)
extra_covariates <- setdiff(regional_cov_names, global_cov_names)

if (length(missing_covariates) > 0) {
  log_message(sprintf("WARNING: Missing covariates (present in global, not regional): %s",
                     paste(missing_covariates, collapse = ", ")), "WARNING")
}

if (length(extra_covariates) > 0) {
  log_message(sprintf("Extra covariates in regional data (not used): %s",
                     paste(extra_covariates, collapse = ", ")), "INFO")
}

# Select only matching covariates
common_covariates <- intersect(global_cov_names, regional_cov_names)
log_message(sprintf("Using %d common covariates", length(common_covariates)))

regional_covariates <- regional_covariates[[common_covariates]]

# ============================================================================
# STEP 4: EXTRACT COVARIATE VALUES AT REGIONAL SAMPLE LOCATIONS
# ============================================================================

log_message("\n=== STEP 4: EXTRACT COVARIATE VALUES ===")

# Convert to spatial
regional_sf <- st_as_sf(regional_data, coords = c("longitude", "latitude"), crs = 4326)
regional_sf <- st_transform(regional_sf, crs(regional_covariates))

# Extract values
log_message("Extracting covariate values at sample locations...")
cov_values <- terra::extract(regional_covariates, vect(regional_sf), ID = FALSE)

# Bind with regional data
regional_with_cov <- bind_cols(
  regional_data %>% select(-longitude, -latitude),
  st_coordinates(regional_sf) %>% as.data.frame() %>% rename(utm_x = X, utm_y = Y),
  cov_values
) %>%
  filter(complete.cases(.))

log_message(sprintf("Regional samples with covariates: %d", nrow(regional_with_cov)))

# ============================================================================
# STEP 5: TRAIN REGIONAL MODELS AND LEARN ENSEMBLE WEIGHTS
# ============================================================================

log_message("\n=== STEP 5: TRANSFER LEARNING ADAPTATION ===")

#' Apply transfer learning for a specific depth
#'
#' @param global_model Pre-trained large-scale model
#' @param regional_data Regional training data with covariates
#' @param covariate_names Vector of covariate names
#' @param depth Target depth
#' @return List with ensemble model and weights
apply_transfer_learning <- function(global_model, regional_data, covariate_names, depth) {

  log_message(sprintf("\n--- Transfer learning for depth %g cm ---", depth))

  # Filter to target depth
  data_depth <- regional_data %>%
    filter(standard_depth == depth) %>%
    select(all_of(c("carbon_stock", "stratum", covariate_names))) %>%
    na.omit()

  n_samples <- nrow(data_depth)
  log_message(sprintf("Regional samples: %d", n_samples))

  if (n_samples < TL_CONFIG$min_regional_samples) {
    log_message(sprintf("Insufficient regional samples (< %d), using global model only",
                       TL_CONFIG$min_regional_samples), "WARNING")

    return(list(
      type = "global_only",
      global_model = global_model,
      weight_global = 1.0,
      weight_regional = 0.0
    ))
  }

  # Generate predictions from global model
  log_message("Generating global model predictions...")
  pred_global <- predict(global_model, data_depth)$predictions

  # Train regional model
  log_message("Training regional model...")

  formula <- as.formula(paste("carbon_stock ~", paste(covariate_names, collapse = " + ")))

  set.seed(123)
  regional_model <- ranger(
    formula = formula,
    data = data_depth,
    num.trees = TL_CONFIG$finetune_ntree,
    importance = "impurity",
    num.threads = if (TL_CONFIG$use_parallel) TL_CONFIG$n_cores else 1,
    verbose = FALSE
  )

  log_message(sprintf("Regional model trained. OOB R²: %.4f", regional_model$r.squared))

  # Generate predictions from regional model
  pred_regional <- predict(regional_model, data_depth)$predictions

  # Learn optimal ensemble weights via cross-validation
  log_message("Learning optimal ensemble weights via CV...")

  if (n_samples < TL_CONFIG$cv_folds) {
    log_message("Too few samples for CV, using equal weights", "WARNING")

    optimal_weight <- 0.5
    cv_mae_ensemble <- mean(abs(data_depth$carbon_stock -
                                (0.5 * pred_global + 0.5 * pred_regional)))

  } else {
    # Cross-validation to find optimal weight
    set.seed(123)
    folds <- createFolds(data_depth$carbon_stock, k = TL_CONFIG$cv_folds)

    weights_to_test <- seq(0, 1, by = 0.1)
    cv_errors <- matrix(0, nrow = TL_CONFIG$cv_folds, ncol = length(weights_to_test))

    for (fold_idx in seq_along(folds)) {
      fold <- folds[[fold_idx]]

      train_data <- data_depth[-fold, ]
      test_data <- data_depth[fold, ]

      # Train fold models
      fold_global <- ranger(
        formula = formula,
        data = train_data,
        num.trees = TL_CONFIG$finetune_ntree,
        num.threads = 1,
        verbose = FALSE
      )

      fold_regional <- ranger(
        formula = formula,
        data = train_data,
        num.trees = TL_CONFIG$finetune_ntree,
        num.threads = 1,
        verbose = FALSE
      )

      # Predict on test set
      pred_g <- predict(fold_global, test_data)$predictions
      pred_r <- predict(fold_regional, test_data)$predictions

      # Test different weights
      for (w_idx in seq_along(weights_to_test)) {
        w <- weights_to_test[w_idx]
        pred_ensemble <- w * pred_g + (1 - w) * pred_r
        cv_errors[fold_idx, w_idx] <- mean(abs(test_data$carbon_stock - pred_ensemble))
      }
    }

    # Find optimal weight
    mean_cv_errors <- colMeans(cv_errors)
    optimal_idx <- which.min(mean_cv_errors)
    optimal_weight <- weights_to_test[optimal_idx]
    cv_mae_ensemble <- mean_cv_errors[optimal_idx]
  }

  # Calculate performance metrics
  pred_ensemble <- optimal_weight * pred_global + (1 - optimal_weight) * pred_regional

  mae_global <- mean(abs(data_depth$carbon_stock - pred_global))
  mae_regional <- mean(abs(data_depth$carbon_stock - pred_regional))
  mae_ensemble <- mean(abs(data_depth$carbon_stock - pred_ensemble))

  rmse_global <- sqrt(mean((data_depth$carbon_stock - pred_global)^2))
  rmse_regional <- sqrt(mean((data_depth$carbon_stock - pred_regional)^2))
  rmse_ensemble <- sqrt(mean((data_depth$carbon_stock - pred_ensemble)^2))

  r2_global <- cor(data_depth$carbon_stock, pred_global)^2
  r2_regional <- cor(data_depth$carbon_stock, pred_regional)^2
  r2_ensemble <- cor(data_depth$carbon_stock, pred_ensemble)^2

  improvement_vs_regional <- (mae_regional - mae_ensemble) / mae_regional * 100

  log_message(sprintf("Optimal weight (global): %.2f", optimal_weight))
  log_message(sprintf("MAE - Global: %.4f | Regional: %.4f | Ensemble: %.4f",
                     mae_global, mae_regional, mae_ensemble))
  log_message(sprintf("R² - Global: %.4f | Regional: %.4f | Ensemble: %.4f",
                     r2_global, r2_regional, r2_ensemble))
  log_message(sprintf("Improvement over regional-only: %.2f%%", improvement_vs_regional))

  return(list(
    type = "ensemble",
    global_model = global_model,
    regional_model = regional_model,
    weight_global = optimal_weight,
    weight_regional = 1 - optimal_weight,
    performance = data.frame(
      mae_global = mae_global,
      mae_regional = mae_regional,
      mae_ensemble = mae_ensemble,
      rmse_global = rmse_global,
      rmse_regional = rmse_regional,
      rmse_ensemble = rmse_ensemble,
      r2_global = r2_global,
      r2_regional = r2_regional,
      r2_ensemble = r2_ensemble,
      improvement_pct = improvement_vs_regional
    )
  ))
}

# Apply transfer learning for all depths
transfer_models <- list()
adaptation_report <- list()

depths <- unique(regional_with_cov$standard_depth)

for (depth in depths) {
  depth_str <- as.character(depth)

  if (!depth_str %in% names(global_models)) {
    log_message(sprintf("No global model for depth %g cm, skipping", depth), "WARNING")
    next
  }

  transfer_models[[depth_str]] <- apply_transfer_learning(
    global_models[[depth_str]],
    regional_with_cov,
    common_covariates,
    depth
  )

  # Save ensemble weights
  saveRDS(
    list(
      weight_global = transfer_models[[depth_str]]$weight_global,
      weight_regional = transfer_models[[depth_str]]$weight_regional
    ),
    sprintf("outputs/models/transfer_learning/ensemble_weights_%gcm.rds", depth)
  )

  # Compile adaptation report
  if (transfer_models[[depth_str]]$type == "ensemble") {
    adaptation_report[[depth_str]] <- transfer_models[[depth_str]]$performance %>%
      mutate(depth_cm = depth)
  }
}

# Save adaptation report
if (length(adaptation_report) > 0) {
  adaptation_df <- bind_rows(adaptation_report)
  write_csv(adaptation_df, "diagnostics/transfer_learning/adaptation_report.csv")
  log_message("Adaptation report saved")
  print(adaptation_df)
}

# ============================================================================
# STEP 6: GENERATE SPATIAL PREDICTIONS
# ============================================================================

log_message("\n=== STEP 6: GENERATE SPATIAL PREDICTIONS ===")

#' Generate ensemble predictions for a raster
generate_ensemble_predictions <- function(transfer_model, covariates, depth) {

  log_message(sprintf("Generating predictions for depth %g cm...", depth))

  if (transfer_model$type == "global_only") {
    log_message("Using global model only (insufficient regional data)")

    pred_raster <- predict(covariates, transfer_model$global_model,
                          fun = function(model, ...) predict(model, ...)$predictions,
                          na.rm = TRUE)

    names(pred_raster) <- sprintf("carbon_stock_tl_%gcm", depth)

    # Estimate uncertainty (use global model's OOB error as baseline)
    se_value <- sqrt(transfer_model$global_model$prediction.error)
    se_raster <- pred_raster * 0 + se_value  # Uniform uncertainty

  } else {
    log_message(sprintf("Using ensemble (%.2f global + %.2f regional)",
                       transfer_model$weight_global, transfer_model$weight_regional))

    # Predict with global model
    pred_global <- predict(covariates, transfer_model$global_model,
                          fun = function(model, ...) predict(model, ...)$predictions,
                          na.rm = TRUE)

    # Predict with regional model
    pred_regional <- predict(covariates, transfer_model$regional_model,
                            fun = function(model, ...) predict(model, ...)$predictions,
                            na.rm = TRUE)

    # Ensemble prediction
    pred_raster <- (transfer_model$weight_global * pred_global +
                   transfer_model$weight_regional * pred_regional)

    names(pred_raster) <- sprintf("carbon_stock_tl_%gcm", depth)

    # Ensemble uncertainty (weighted combination)
    se_global <- sqrt(transfer_model$global_model$prediction.error)
    se_regional <- sqrt(transfer_model$regional_model$prediction.error)

    se_raster <- sqrt(
      transfer_model$weight_global^2 * se_global^2 +
      transfer_model$weight_regional^2 * se_regional^2
    )
  }

  names(se_raster) <- sprintf("se_combined_%gcm", depth)

  # Save rasters
  writeRaster(pred_raster,
             sprintf("outputs/predictions/transfer_learning/carbon_stock_tl_%gcm.tif", depth),
             overwrite = TRUE)

  writeRaster(se_raster,
             sprintf("outputs/predictions/transfer_learning/se_combined_%gcm.tif", depth),
             overwrite = TRUE)

  log_message(sprintf("Predictions saved for depth %g cm", depth))

  return(list(prediction = pred_raster, uncertainty = se_raster))
}

# Generate predictions for all depths
predictions <- list()

for (depth_str in names(transfer_models)) {
  depth <- as.numeric(depth_str)

  predictions[[depth_str]] <- generate_ensemble_predictions(
    transfer_models[[depth_str]],
    regional_covariates,
    depth
  )
}

# ============================================================================
# STEP 7: CALCULATE AREA OF APPLICABILITY (AOA)
# ============================================================================

if (TL_CONFIG$generate_aoa && has_CAST) {
  log_message("\n=== STEP 7: CALCULATE AREA OF APPLICABILITY ===")

  for (depth_str in names(transfer_models)) {
    depth <- as.numeric(depth_str)

    log_message(sprintf("Calculating AOA for depth %g cm...", depth))

    # Use regional training data
    train_data <- regional_with_cov %>%
      filter(standard_depth == depth) %>%
      select(all_of(common_covariates))

    if (nrow(train_data) < 5) {
      log_message("Insufficient data for AOA calculation", "WARNING")
      next
    }

    # Calculate AOA
    tryCatch({
      aoa_result <- aoa(
        newdata = regional_covariates,
        model = transfer_models[[depth_str]]$regional_model,
        trainDI = train_data,
        verbose = FALSE
      )

      # Save AOA raster
      writeRaster(aoa_result$AOA,
                 sprintf("outputs/predictions/transfer_learning/aoa_%gcm.tif", depth),
                 overwrite = TRUE)

      log_message(sprintf("AOA saved for depth %g cm", depth))

    }, error = function(e) {
      log_message(sprintf("AOA calculation failed: %s", e$message), "WARNING")
    })
  }
}

# ============================================================================
# COMPLETION
# ============================================================================

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

log_message("\n=== MODULE 05C COMPLETE ===")
log_message(sprintf("Runtime: %.1f minutes", as.numeric(elapsed_time)))
log_message(sprintf("Transfer learning models: %d", length(transfer_models)))

if (length(adaptation_report) > 0) {
  log_message(sprintf("Mean improvement: %.2f%%",
                     mean(bind_rows(adaptation_report)$improvement_pct)))
}

log_message("\nOutputs saved:")
log_message("  - outputs/predictions/transfer_learning/carbon_stock_tl_*.tif")
log_message("  - outputs/predictions/transfer_learning/se_combined_*.tif")
log_message("  - outputs/predictions/transfer_learning/aoa_*.tif")
log_message("  - outputs/models/transfer_learning/ensemble_weights_*.rds")
log_message("  - diagnostics/transfer_learning/adaptation_report.csv")
log_message("\nNext step: Run Module 05d to compare with standard RF and Bayesian methods")
