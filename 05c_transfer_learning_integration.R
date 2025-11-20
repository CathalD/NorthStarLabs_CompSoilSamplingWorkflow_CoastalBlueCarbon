# ============================================================================
# MODULE 05c: TRANSFER LEARNING INTEGRATION
# ============================================================================
# PURPOSE: Combine local and global harmonized cores to train improved models
#
# PRIMARY GOAL:
#   Train Random Forest models to predict carbon_stock_kg_m2 using:
#   1. Local field data + Global dataset (Janousek) = More training data
#   2. Compare performance with local-only vs combined dataset
#
# INPUTS:
#   - data_processed/cores_harmonized_bluecarbon.csv (from Module 03)
#   - data_processed/global_cores_harmonized_VM0033.csv (from Module 03)
#   - covariates/*.tif (optional - for local predictors)
#
# OUTPUTS:
#   - outputs/models/transfer_learning/rf_depth_*.rds
#   - diagnostics/transfer_learning/performance_summary.csv
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(ranger)
  library(sf)
  library(terra)
})

cat("\n========================================\n")
cat("MODULE 05c: TRANSFER LEARNING\n")
cat("========================================\n\n")

# Create output directories
dir.create("outputs/models/transfer_learning", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/transfer_learning", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# STEP 1: LOAD HARMONIZED DATA
# ============================================================================

cat("STEP 1: Loading harmonized datasets...\n\n")

# Load local cores (harmonized by Module 03)
if (!file.exists("data_processed/cores_harmonized_bluecarbon.csv")) {
  stop("Local harmonized cores not found!\n",
       "Run Module 03 first: Rscript 03_depth_harmonization_bluecarbon.R")
}

local_cores <- read_csv("data_processed/cores_harmonized_bluecarbon.csv",
                        show_col_types = FALSE)
cat(sprintf("✓ Local cores: %d samples from %d cores\n",
            nrow(local_cores), n_distinct(local_cores$core_id)))

# Load global cores (harmonized by Module 03)
use_global <- FALSE
if (file.exists("data_processed/global_cores_harmonized_VM0033.csv")) {
  global_cores <- read_csv("data_processed/global_cores_harmonized_VM0033.csv",
                          show_col_types = FALSE)
  cat(sprintf("✓ Global cores: %d samples from %d cores\n",
              nrow(global_cores), n_distinct(global_cores$core_id)))
  use_global <- TRUE
} else {
  cat("  (No global dataset found - using local only)\n")
}

# ============================================================================
# STEP 2: COMBINE DATASETS
# ============================================================================

cat("\nSTEP 2: Combining datasets...\n\n")

if (use_global) {
  # Add source identifier
  local_cores$data_source <- "local"
  global_cores$data_source <- "global"

  # Required columns for modeling
  required <- c("core_id", "depth_cm_midpoint", "carbon_stock_kg_m2")

  if (!all(required %in% names(local_cores))) {
    stop("Local cores missing required columns: ",
         paste(setdiff(required, names(local_cores)), collapse = ", "))
  }

  if (!all(required %in% names(global_cores))) {
    stop("Global cores missing required columns: ",
         paste(setdiff(required, names(global_cores)), collapse = ", "))
  }

  # Find common columns
  common_cols <- intersect(names(local_cores), names(global_cores))

  # Combine on common columns
  combined_data <- bind_rows(
    local_cores %>% select(all_of(common_cols)),
    global_cores %>% select(all_of(common_cols))
  )

  cat(sprintf("✓ Combined: %d total samples\n", nrow(combined_data)))
  cat(sprintf("  - Local: %d samples\n", sum(combined_data$data_source == "local")))
  cat(sprintf("  - Global: %d samples\n", sum(combined_data$data_source == "global")))

} else {
  combined_data <- local_cores
  cat("✓ Using local data only\n")
}

# ============================================================================
# STEP 3: EXTRACT LOCAL COVARIATES (Optional)
# ============================================================================

cat("\nSTEP 3: Checking for local covariates...\n\n")

# Check if covariates folder exists
if (dir.exists("covariates")) {

  covariate_files <- list.files("covariates", pattern = "\\.tif$",
                                full.names = TRUE, recursive = TRUE,
                                ignore.case = TRUE)

  if (length(covariate_files) > 0) {

    cat(sprintf("✓ Found %d covariate rasters\n", length(covariate_files)))

    # Load raster stack
    covariate_stack <- rast(covariate_files)
    names(covariate_stack) <- gsub("\\.(tif|tiff)$", "", basename(covariate_files))

    cat("  Covariates:", paste(names(covariate_stack), collapse = ", "), "\n\n")

    # Extract for cores with lat/lon
    if (all(c("latitude", "longitude") %in% names(combined_data))) {

      cores_with_coords <- combined_data %>%
        filter(!is.na(latitude), !is.na(longitude))

      cores_sf <- st_as_sf(cores_with_coords,
                          coords = c("longitude", "latitude"),
                          crs = 4326)
      cores_sf <- st_transform(cores_sf, crs = crs(covariate_stack))

      # Extract values
      covariate_values <- terra::extract(covariate_stack, cores_sf, ID = FALSE)

      # Add to data
      combined_data <- bind_cols(cores_with_coords, covariate_values)

      cat(sprintf("✓ Extracted %d covariates at core locations\n",
                  ncol(covariate_values)))

    } else {
      cat("  (No latitude/longitude - skipping extraction)\n")
    }
  } else {
    cat("  (No .tif files found)\n")
  }
} else {
  cat("  (No covariates folder found)\n")
}

# ============================================================================
# STEP 4: PREPARE FOR MODELING
# ============================================================================

cat("\nSTEP 4: Preparing for modeling...\n\n")

# Check required columns
if (!"depth_cm_midpoint" %in% names(combined_data)) {
  stop("Missing depth_cm_midpoint column!")
}

if (!"carbon_stock_kg_m2" %in% names(combined_data)) {
  stop("Missing carbon_stock_kg_m2 column!")
}

# Identify predictor columns
exclude_cols <- c("core_id", "sample_id", "latitude", "longitude", "ecosystem",
                 "site", "stratum", "depth_cm_midpoint", "carbon_stock_kg_m2",
                 "soc_harmonized", "bd_harmonized", "data_source",
                 "qa_pass", "qa_realistic", "qa_monotonic")

# Find numeric predictors
all_cols <- names(combined_data)
predictor_cols <- setdiff(all_cols, exclude_cols)
predictor_cols <- predictor_cols[sapply(combined_data[predictor_cols], is.numeric)]

if (length(predictor_cols) == 0) {
  cat("\nWARNING: No predictor variables found!\n")
  cat("Available columns:\n")
  print(names(combined_data))
  cat("\nCannot train models without predictors.\n")
  cat("Please add covariate rasters to ./covariates/ folder\n\n")
  quit(save = "no", status = 1)
}

cat(sprintf("✓ Found %d predictor variables:\n", length(predictor_cols)))
for (pred in predictor_cols) {
  cat(sprintf("  - %s\n", pred))
}

# ============================================================================
# STEP 5: TRAIN MODELS BY DEPTH
# ============================================================================

cat("\nSTEP 5: Training models by depth...\n\n")

# VM0033 standard depths
vm0033_depths <- c(7.5, 22.5, 40, 75)

# Store results
results <- list()

for (target_depth in vm0033_depths) {

  cat(sprintf("\n--- Depth: %g cm ---\n", target_depth))

  # Filter to this depth (±5 cm tolerance)
  data_depth <- combined_data %>%
    filter(abs(depth_cm_midpoint - target_depth) < 5,
           !is.na(carbon_stock_kg_m2)) %>%
    drop_na(all_of(predictor_cols))  # Remove NA predictors

  n_samples <- nrow(data_depth)
  cat(sprintf("  Samples: %d\n", n_samples))

  if (n_samples < 10) {
    cat("  SKIP: Not enough samples (< 10)\n")
    next
  }

  # Split by data source if global data available
  if (use_global && "data_source" %in% names(data_depth)) {
    n_local <- sum(data_depth$data_source == "local")
    n_global <- sum(data_depth$data_source == "global")
    cat(sprintf("  - Local: %d\n", n_local))
    cat(sprintf("  - Global: %d\n", n_global))
  }

  # Build formula
  formula_str <- paste("carbon_stock_kg_m2 ~", paste(predictor_cols, collapse = " + "))
  formula_rf <- as.formula(formula_str)

  # Train Random Forest
  cat("  Training Random Forest...\n")

  rf_model <- ranger(
    formula_rf,
    data = data_depth,
    num.trees = 500,
    importance = "permutation",
    oob.error = TRUE,
    seed = 42
  )

  # Get performance metrics
  r2 <- rf_model$r.squared
  rmse <- sqrt(rf_model$prediction.error)

  cat(sprintf("  ✓ R² = %.3f, RMSE = %.2f kg/m²\n", r2, rmse))

  # Store results
  results[[as.character(target_depth)]] <- list(
    depth_cm = target_depth,
    n_samples = n_samples,
    n_predictors = length(predictor_cols),
    r_squared = r2,
    rmse = rmse,
    model = rf_model
  )

  # Save model
  model_file <- sprintf("outputs/models/transfer_learning/rf_depth_%g_cm.rds",
                       target_depth)
  saveRDS(rf_model, model_file)
  cat(sprintf("  Saved: %s\n", basename(model_file)))
}

# ============================================================================
# STEP 6: SUMMARIZE PERFORMANCE
# ============================================================================

cat("\n========================================\n")
cat("PERFORMANCE SUMMARY\n")
cat("========================================\n\n")

# Create summary table
summary_df <- map_df(results, function(res) {
  tibble(
    depth_cm = res$depth_cm,
    n_samples = res$n_samples,
    n_predictors = res$n_predictors,
    r_squared = res$r_squared,
    rmse_kg_m2 = res$rmse
  )
})

print(summary_df)

# Save summary
write_csv(summary_df, "diagnostics/transfer_learning/performance_summary.csv")
saveRDS(results, "diagnostics/transfer_learning/model_results.rds")

cat("\n✓ Transfer learning complete!\n")
cat("\nOutputs:\n")
cat("  - Models: outputs/models/transfer_learning/\n")
cat("  - Summary: diagnostics/transfer_learning/performance_summary.csv\n\n")

cat("Next steps:\n")
cat("  1. Review model performance by depth\n")
cat("  2. Check variable importance plots\n")
cat("  3. Make spatial predictions with best model\n\n")
