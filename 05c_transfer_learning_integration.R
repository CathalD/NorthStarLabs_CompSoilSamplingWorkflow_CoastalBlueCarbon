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

  # Standardize core_id type - convert both to character
  # (Local is character, global is numeric - need to match)
  local_cores$core_id <- as.character(local_cores$core_id)
  global_cores$core_id <- as.character(global_cores$core_id)

  cat("Standardizing core_id types...\n")
  cat(sprintf("  Local core_id: character (%d unique)\n", n_distinct(local_cores$core_id)))
  cat(sprintf("  Global core_id: character (%d unique)\n", n_distinct(global_cores$core_id)))

  # Find common columns
  common_cols <- intersect(names(local_cores), names(global_cores))

  # Add latitude/longitude to common columns if they exist in local data
  # (these may not be in global dataset but we need them for covariate extraction)
  if ("latitude" %in% names(local_cores) && !"latitude" %in% common_cols) {
    common_cols <- c(common_cols, "latitude")
  }
  if ("longitude" %in% names(local_cores) && !"longitude" %in% common_cols) {
    common_cols <- c(common_cols, "longitude")
  }

  # Combine on common columns (will add NAs for global rows where coords don't exist)
  combined_data <- bind_rows(
    local_cores %>% select(any_of(common_cols)),
    global_cores %>% select(any_of(common_cols))
  )

  cat(sprintf("✓ Combined: %d total samples\n", nrow(combined_data)))
  cat(sprintf("  - Local: %d samples\n", sum(combined_data$data_source == "local")))
  cat(sprintf("  - Global: %d samples\n", sum(combined_data$data_source == "global")))

} else {
  combined_data <- local_cores
  cat("✓ Using local data only\n")
}

# ============================================================================
# STEP 3: CHECK AND EXTRACT COVARIATES (if needed)
# ============================================================================

cat("\nSTEP 3: Checking covariates...\n\n")

# Check if global data already has covariates (from GEE)
existing_covariates <- names(combined_data)[grepl("^(gsw_|sg_|topo_|wc_|elevation_)", names(combined_data))]

if (length(existing_covariates) > 0) {
  cat(sprintf("✓ Global data has %d existing covariates\n", length(existing_covariates)))
  cat("  Examples:", paste(head(existing_covariates, 3), collapse = ", "), "...\n")

  # Check how many rows have covariate data
  has_covariates <- rowSums(!is.na(combined_data[, existing_covariates, drop = FALSE])) > 0
  cat(sprintf("  - %d samples with covariates (global)\n", sum(has_covariates)))
  cat(sprintf("  - %d samples without covariates (local)\n", sum(!has_covariates)))

} else {
  cat("No existing covariates found - will try to extract from rasters\n")
}

# Try to extract local covariates for samples that don't have them
if (dir.exists("covariates")) {

  covariate_files <- list.files("covariates", pattern = "\\.tif$",
                                full.names = TRUE, recursive = TRUE,
                                ignore.case = TRUE)

  if (length(covariate_files) > 0 && all(c("latitude", "longitude") %in% names(combined_data))) {

    cat(sprintf("\n✓ Found %d local covariate rasters\n", length(covariate_files)))

    # Identify which rows need covariate extraction (local data without covariates)
    if (length(existing_covariates) > 0) {
      has_covariates <- rowSums(!is.na(combined_data[, existing_covariates, drop = FALSE])) > 0
      needs_extraction <- !has_covariates & !is.na(combined_data$latitude) & !is.na(combined_data$longitude)
    } else {
      needs_extraction <- !is.na(combined_data$latitude) & !is.na(combined_data$longitude)
    }

    if (sum(needs_extraction) > 0) {
      cat(sprintf("  Extracting for %d local samples...\n", sum(needs_extraction)))

      # Load raster stack
      covariate_stack <- rast(covariate_files)
      names(covariate_stack) <- gsub("\\.(tif|tiff)$", "", basename(covariate_files))

      # Extract for local cores
      local_cores_sf <- st_as_sf(combined_data[needs_extraction, ],
                                coords = c("longitude", "latitude"),
                                crs = 4326)
      local_cores_sf <- st_transform(local_cores_sf, crs = crs(covariate_stack))

      # Extract values
      local_covariate_values <- terra::extract(covariate_stack, local_cores_sf, ID = FALSE)

      # Add extracted values to combined_data for local rows
      for (col in names(local_covariate_values)) {
        if (!col %in% names(combined_data)) {
          combined_data[[col]] <- NA
        }
        combined_data[needs_extraction, col] <- local_covariate_values[[col]]
      }

      cat(sprintf("✓ Extracted %d local covariates\n", ncol(local_covariate_values)))

    } else {
      cat("  (All samples already have covariates)\n")
    }
  }
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
exclude_cols <- c("core_id", "sample_id", "studyid", "study_id", "studysampid",
                 "subsampid", "subsample_id", "latitude", "longitude", "ecosystem",
                 "site", "stratum", "depth_cm_midpoint", "depth_cm", "carbon_stock_kg_m2",
                 "soc_harmonized", "bd_harmonized", "data_source", "depth_min", "depth_max",
                 "depth_top_cm", "depth_bottom_cm", "carbon_stock_30cm", "carbon_stock_50cm",
                 "carbon_stock_100cm", "core_depth", "core_depth_cm", "state", "estuary_id",
                 "estuary_type", "kgzone", "ecoregion", "grain_type",
                 "qa_pass", "qa_realistic", "qa_monotonic", ".geo", "system:index")

# Find numeric predictors
all_cols <- names(combined_data)
predictor_cols <- setdiff(all_cols, exclude_cols)
numeric_check <- sapply(combined_data[predictor_cols], is.numeric)
predictor_cols <- predictor_cols[numeric_check]

# Check data coverage for each predictor
# Keep only predictors with at least 80% non-NA values
if (length(predictor_cols) > 0) {
  na_pct <- sapply(combined_data[predictor_cols], function(x) sum(is.na(x)) / length(x))
  good_coverage <- na_pct < 0.2  # Less than 20% NA

  if (sum(good_coverage) > 0) {
    predictor_cols <- predictor_cols[good_coverage]
    cat(sprintf("✓ Found %d predictors with good coverage (>80%% non-NA):\n", length(predictor_cols)))

    # Show predictor categories
    gee_preds <- grep("^(gsw_|sg_|topo_|wc_)", predictor_cols, value = TRUE)
    local_preds <- setdiff(predictor_cols, gee_preds)

    if (length(gee_preds) > 0) {
      cat(sprintf("  - GEE covariates: %d\n", length(gee_preds)))
    }
    if (length(local_preds) > 0) {
      cat(sprintf("  - Local covariates: %d\n", length(local_preds)))
    }

    cat("\n  Predictors:\n")
    for (pred in predictor_cols) {
      na_count <- sum(is.na(combined_data[[pred]]))
      cat(sprintf("    - %s (%.1f%% complete)\n", pred, 100 * (1 - na_count/nrow(combined_data))))
    }
  } else {
    predictor_cols <- character(0)
  }
}

if (length(predictor_cols) == 0) {
  cat("\nWARNING: No predictor variables with sufficient coverage!\n")
  cat("Available columns:\n")
  print(names(combined_data))
  cat("\nCannot train models without predictors.\n")
  quit(save = "no", status = 1)
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
           !is.na(carbon_stock_kg_m2))

  # Only remove rows where ALL predictors are NA (keep rows with at least some data)
  has_any_predictor <- rowSums(!is.na(data_depth[, predictor_cols, drop = FALSE])) > 0
  data_depth <- data_depth[has_any_predictor, ]

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

  # Check predictor coverage at this depth
  pred_coverage <- colSums(!is.na(data_depth[, predictor_cols, drop = FALSE])) / nrow(data_depth)
  good_preds <- names(pred_coverage)[pred_coverage >= 0.5]  # At least 50% coverage

  if (length(good_preds) < 3) {
    cat("  SKIP: Not enough predictors with good coverage (< 3)\n")
    next
  }

  # Use only predictors with good coverage at this depth
  active_predictors <- good_preds

  cat(sprintf("  Using %d predictors with good coverage at this depth\n", length(active_predictors)))

  # Remove rows with NA in active predictors
  data_depth <- data_depth %>%
    drop_na(all_of(active_predictors))

  # Recount after dropping NAs
  n_samples_final <- nrow(data_depth)
  if (n_samples_final < 10) {
    cat(sprintf("  SKIP: Only %d samples remain after removing NAs\n", n_samples_final))
    next
  }

  if (use_global && "data_source" %in% names(data_depth)) {
    n_local_final <- sum(data_depth$data_source == "local")
    n_global_final <- sum(data_depth$data_source == "global")
    cat(sprintf("  After NA removal: Local=%d, Global=%d\n", n_local_final, n_global_final))
  }

  # Build formula
  formula_str <- paste("carbon_stock_kg_m2 ~", paste(active_predictors, collapse = " + "))
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
    n_samples = n_samples_final,
    n_predictors = length(active_predictors),
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
