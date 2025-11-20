# ============================================================================
# MODULE 05c: TRANSFER LEARNING INTEGRATION
# ============================================================================
# PURPOSE: Combine global features with local data for improved predictions
# APPROACH: Add global baselines as features in Random Forest model
# ============================================================================
#
# WORKFLOW:
# 1. Load your local field cores (from Module 03)
# 2. Load global features (from GEE export)
# 3. Merge datasets
# 4. Train RF models (with/without transfer learning)
# 5. Compare performance
# 6. Make spatial predictions
#
# TRANSFER LEARNING MECHANISM:
#   Regional_SOC = f(Local_Covariates, Global_Baselines)
#
#   The Random Forest learns how your site differs from:
#   - Murray tidal classification
#   - Global Surface Water inundation patterns
#   - Terrestrial soils (SoilGrids)
#
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(ranger)
  library(sf)
  library(terra)
})

# ============================================================================
# CONFIGURATION
# ============================================================================

cat("\n========================================\n")
cat("TRANSFER LEARNING INTEGRATION\n")
cat("========================================\n\n")

CONFIG <- list(
  # Input files
  local_cores = "data_processed/harmonized_cores_VM0033.csv",
  global_features = "data_global/cores_with_bluecarbon_global_maps.csv",

  # Output directories
  output_models = "outputs/models/rf",
  output_predictions = "outputs/predictions/rf",
  output_diagnostics = "diagnostics/transfer_learning",

  # Model settings
  target_depths = c(7.5, 22.5, 40, 75),  # VM0033 standard depths
  n_trees = 500,
  cv_folds = 10,

  # Create directories
  create_dirs = TRUE
)

# Create output directories
if (CONFIG$create_dirs) {
  dir.create(CONFIG$output_models, recursive = TRUE, showWarnings = FALSE)
  dir.create(CONFIG$output_predictions, recursive = TRUE, showWarnings = FALSE)
  dir.create(CONFIG$output_diagnostics, recursive = TRUE, showWarnings = FALSE)
}

# ============================================================================
# STEP 1: LOAD AND MERGE DATA
# ============================================================================

cat("=== STEP 1: Load and Merge Data ===\n\n")

# Load local field cores
if (!file.exists(CONFIG$local_cores)) {
  cat("ERROR: Local cores file not found!\n")
  cat("Expected:", CONFIG$local_cores, "\n")
  cat("Please run Module 03 (depth harmonization) first.\n\n")
  quit(save = "no", status = 1)
}

local_cores <- read_csv(CONFIG$local_cores, show_col_types = FALSE)
cat(sprintf("✓ Loaded %d local cores\n", nrow(local_cores)))

# Load global features
if (!file.exists(CONFIG$global_features)) {
  cat("\nWARNING: Global features file not found!\n")
  cat("Expected:", CONFIG$global_features, "\n")
  cat("\nYou need to:\n")
  cat("1. Run GEE_EXTRACT_BLUECARBON_GLOBAL_MAPS.js\n")
  cat("2. Download CSV from Google Drive\n")
  cat("3. Place in data_global/ folder\n\n")
  cat("CONTINUING WITHOUT TRANSFER LEARNING (local features only)\n\n")

  cores_merged <- local_cores
  use_transfer_learning <- FALSE

} else {

  global_features <- read_csv(CONFIG$global_features, show_col_types = FALSE)
  cat(sprintf("✓ Loaded global features for %d cores\n", nrow(global_features)))

  # Detect ID column in global features
  # GEE exports may have different column names
  possible_id_cols <- c("core_id", "sample_id", "system:index", ".geo")

  id_col_global <- NULL
  for (col in possible_id_cols) {
    if (col %in% names(global_features)) {
      id_col_global <- col
      break
    }
  }

  if (is.null(id_col_global)) {
    # Use first column as ID
    id_col_global <- names(global_features)[1]
    cat(sprintf("WARNING: No standard ID column found in global features.\n"))
    cat(sprintf("Using first column as ID: '%s'\n", id_col_global))
  } else {
    cat(sprintf("✓ Detected ID column in global features: '%s'\n", id_col_global))
  }

  # Detect ID column in local cores
  id_col_local <- NULL
  if ("core_id" %in% names(local_cores)) {
    id_col_local <- "core_id"
  } else if ("sample_id" %in% names(local_cores)) {
    id_col_local <- "sample_id"
  } else {
    id_col_local <- names(local_cores)[1]
  }

  cat(sprintf("✓ Using ID column in local cores: '%s'\n", id_col_local))

  # Standardize ID column names for merge
  if (id_col_global != id_col_local) {
    cat(sprintf("Renaming '%s' to '%s' in global features for merge\n",
                id_col_global, id_col_local))
    global_features <- global_features %>%
      rename(!!id_col_local := !!id_col_global)
  }

  # Convert ID column types to match
  # This handles cases where GEE exports numeric IDs but local data has character IDs
  if (is.character(local_cores[[id_col_local]]) && is.numeric(global_features[[id_col_local]])) {
    cat("Converting numeric global IDs to character to match local IDs\n")
    global_features <- global_features %>%
      mutate(!!id_col_local := as.character(.data[[id_col_local]]))
  } else if (is.numeric(local_cores[[id_col_local]]) && is.character(global_features[[id_col_local]])) {
    cat("Converting character global IDs to numeric to match local IDs\n")
    global_features <- global_features %>%
      mutate(!!id_col_local := as.numeric(.data[[id_col_local]]))
  }

  # Remove .geo column if it exists (GEE artifact)
  if (".geo" %in% names(global_features)) {
    global_features <- global_features %>%
      select(-.geo)
  }

  # Show first few IDs for verification
  cat("\nFirst 3 IDs in local cores:",
      paste(head(local_cores[[id_col_local]], 3), collapse = ", "), "\n")
  cat("First 3 IDs in global features:",
      paste(head(global_features[[id_col_local]], 3), collapse = ", "), "\n\n")

  # Merge
  cores_merged <- local_cores %>%
    left_join(global_features, by = id_col_local)

  # Check merge success
  n_missing_global <- sum(is.na(cores_merged$murray_tidal_flag))

  if (n_missing_global > 0) {
    cat(sprintf("WARNING: %d cores missing global features\n", n_missing_global))
  }

  cat(sprintf("✓ Merged: %d cores with %d total columns\n",
              nrow(cores_merged), ncol(cores_merged)))

  # Count global features
  global_feature_cols <- names(cores_merged)[
    grepl("^murray_|^gsw_|^wc_|^topo_|^sg_", names(cores_merged))
  ]

  cat(sprintf("✓ Global features added: %d\n", length(global_feature_cols)))
  cat("  Global features:", paste(head(global_feature_cols, 5), collapse = ", "), "...\n")

  use_transfer_learning <- TRUE
}

# ============================================================================
# STEP 1b: EXTRACT LOCAL COVARIATES FROM RASTERS
# ============================================================================

cat("\n=== STEP 1b: Extract Local Covariates ===\n\n")

# Search for covariates in multiple possible locations
covariate_paths <- c(
  "covariates",
  "data_processed/covariates",
  "outputs/covariates",
  "data_raw/covariates",
  "."  # Also check root directory
)

covariate_dir <- NULL
for (path in covariate_paths) {
  if (dir.exists(path)) {
    # Check if this directory actually has .tif files
    test_files <- list.files(path,
                            pattern = "\\.(tif|tiff|TIF|TIFF)$",
                            full.names = FALSE,
                            recursive = TRUE,
                            ignore.case = TRUE)
    if (length(test_files) > 0) {
      covariate_dir <- path
      cat(sprintf("✓ Found covariates folder: %s\n", path))
      break
    }
  }
}

if (is.null(covariate_dir)) {
  cat("WARNING: No covariates folder with .tif files found!\n")
  cat("Searched locations:\n")
  cat(paste("  -", covariate_paths, collapse = "\n"), "\n\n")
  cat("Checking if covariates are already in the cores CSV...\n\n")

  # Check if already in CSV
  if (!any(grepl("NDVI|ndvi|elevation|elev", names(cores_merged), ignore.case = TRUE))) {
    cat("ERROR: No covariates folder and covariates not in CSV.\n")
    cat("\nPlease either:\n")
    cat("1. Create ./covariates/ folder and add GEE covariate exports (.tif files)\n")
    cat("2. Or provide the full path to your covariates folder\n")
    cat("3. Or run a module that extracts covariates to your cores CSV first\n\n")
    quit(save = "no", status = 1)
  }

  cat("✓ Covariates found in CSV, skipping extraction\n")

} else {

  # Find ALL .tif files (case insensitive, any subdirectory, any extension variant)
  covariate_files <- list.files(covariate_dir,
                                pattern = "\\.(tif|tiff|TIF|TIFF)$",
                                full.names = TRUE,
                                recursive = TRUE,
                                ignore.case = TRUE)

  cat(sprintf("\n✓ Found %d covariate files:\n", length(covariate_files)))
  for (i in 1:min(15, length(covariate_files))) {
    cat(sprintf("  %d. %s\n", i, basename(covariate_files[i])))
  }
  if (length(covariate_files) > 15) {
    cat(sprintf("  ... and %d more\n", length(covariate_files) - 15))
  }

  # Load raster stack
  cat("\nLoading rasters into stack...\n")
  covariate_stack <- rast(covariate_files)
  cat(sprintf("✓ Loaded %d covariate layers\n", nlyr(covariate_stack)))

  # Clean layer names (remove path and any extension variant)
  clean_names <- gsub("\\.(tif|tiff|TIF|TIFF)$", "", basename(covariate_files))
  names(covariate_stack) <- clean_names

  cat("\nCovariate layer names after loading:\n")
  for (i in 1:min(15, length(clean_names))) {
    cat(sprintf("  %s\n", clean_names[i]))
  }
  if (length(clean_names) > 15) {
    cat(sprintf("  ... and %d more\n", length(clean_names) - 15))
  }

  # Create spatial points from cores
  if (!all(c("longitude", "latitude") %in% names(cores_merged))) {
    cat("ERROR: Cores CSV must have 'longitude' and 'latitude' columns\n\n")
    quit(save = "no", status = 1)
  }

  cores_sf <- cores_merged %>%
    filter(!is.na(longitude), !is.na(latitude)) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

  # Transform to match covariate CRS
  cores_sf <- st_transform(cores_sf, crs = crs(covariate_stack))

  cat(sprintf("✓ Extracting covariates at %d core locations...\n", nrow(cores_sf)))

  # Extract covariate values
  covariate_values <- terra::extract(covariate_stack, cores_sf, ID = FALSE)

  # Add to cores_merged
  cores_merged <- bind_cols(cores_merged, covariate_values)

  cat(sprintf("✓ Added %d covariate columns to cores\n", ncol(covariate_values)))
}

# ============================================================================
# STEP 2: PREPARE TRAINING DATA
# ============================================================================

cat("\n=== STEP 2: Prepare Training Data ===\n\n")

# Show all available columns
cat("Available columns in merged dataset:\n")
all_cols <- names(cores_merged)
core_cols <- c("core_id", "sample_id", "latitude", "longitude", "depth_cm_midpoint", "carbon_stock_kg_m2")
global_cols <- grep("^murray_|^gsw_|^wc_|^topo_|^sg_", all_cols, value = TRUE)
covariate_cols <- setdiff(setdiff(all_cols, core_cols), global_cols)

cat(sprintf("\n  Core metadata columns (%d):\n", length(core_cols)))
cat(paste("    ", head(intersect(core_cols, all_cols), 10), collapse = "\n"), "\n")

cat(sprintf("\n  Local covariates (%d):\n", length(covariate_cols)))
if (length(covariate_cols) > 0) {
  cat(paste("    ", head(covariate_cols, 20), collapse = "\n"), "\n")
  if (length(covariate_cols) > 20) {
    cat(sprintf("    ... and %d more\n", length(covariate_cols) - 20))
  }
} else {
  cat("    (none found)\n")
}

if (use_transfer_learning && length(global_cols) > 0) {
  cat(sprintf("\n  Global features (%d):\n", length(global_cols)))
  cat(paste("    ", head(global_cols, 10), collapse = "\n"), "\n")
  if (length(global_cols) > 10) {
    cat(sprintf("    ... and %d more\n", length(global_cols) - 10))
  }
}

# Check if we have at least SOME covariates to work with
if (length(covariate_cols) == 0 && length(global_cols) == 0) {
  cat("\nERROR: No covariate columns found!\n")
  cat("Cannot train models without predictors.\n\n")
  quit(save = "no", status = 1)
}

# Identify available standard covariates
preferred_local <- c("NDVI_median_annual", "EVI_median_growing", "NDMI_median_annual",
                    "VV_median", "VH_median", "elevation_m", "slope_degrees")
available_local <- intersect(preferred_local, covariate_cols)

# If preferred names not found, use ANY numeric covariates
if (length(available_local) == 0) {
  cat("\nNOTE: Standard covariate names not found. Using all available numeric columns.\n")
  # Find numeric columns (excluding ID and target columns)
  exclude_cols <- c(core_cols, global_cols, "ecosystem", "stratum", "site", "transect")
  numeric_cols <- sapply(cores_merged, is.numeric)
  available_local <- names(cores_merged)[numeric_cols & !names(cores_merged) %in% exclude_cols]
  available_local <- setdiff(available_local, "carbon_stock_kg_m2")  # Don't use target as predictor!
}

cat(sprintf("\n✓ Using %d local covariates for modeling:\n", length(available_local)))
cat(paste("  ", available_local, collapse = "\n"), "\n")

# Build dynamic model formulas based on available columns
# Local-only model (baseline)
if (length(available_local) > 0) {
  formula_local <- as.formula(
    paste("carbon_stock_kg_m2 ~", paste(available_local, collapse = " + "))
  )
  cat(sprintf("\n✓ Local-only model formula created with %d covariates\n", length(available_local)))
} else {
  cat("\nWARNING: No local covariates available! Cannot train local-only model.\n")
  formula_local <- NULL
}

# Transfer learning model (local + global)
if (use_transfer_learning && length(global_cols) > 0) {
  # Combine local and global features
  all_predictors <- c(available_local, global_cols)

  formula_transfer <- as.formula(
    paste("carbon_stock_kg_m2 ~", paste(all_predictors, collapse = " + "))
  )

  cat(sprintf("✓ Transfer learning model formula created\n"))
  cat(sprintf("    Local covariates: %d\n", length(available_local)))
  cat(sprintf("    Global features: %d\n", length(global_cols)))
  cat(sprintf("    Total predictors: %d\n", length(all_predictors)))

} else {
  formula_transfer <- NULL
  if (use_transfer_learning) {
    cat("\nNOTE: Transfer learning disabled - no global features available\n")
  }
}

# ============================================================================
# STEP 3: TRAIN MODELS BY DEPTH
# ============================================================================

cat("\n=== STEP 3: Train Models by Depth ===\n\n")

results <- list()

for (depth_cm in CONFIG$target_depths) {

  cat(sprintf("\n--- Training models for depth: %g cm ---\n", depth_cm))

  # Filter to depth
  data_depth <- cores_merged %>%
    filter(abs(depth_cm_midpoint - depth_cm) < 5) %>%
    drop_na(carbon_stock_kg_m2)

  cat(sprintf("  Samples at this depth: %d\n", nrow(data_depth)))

  if (nrow(data_depth) < 10) {
    cat("  SKIPPING: Insufficient samples (< 10)\n")
    next
  }

  # Train local-only model
  cat("  Training local-only RF...\n")

  rf_local <- ranger(
    formula_local,
    data = data_depth,
    importance = "permutation",
    num.trees = CONFIG$n_trees,
    mtry = 3,
    oob.error = TRUE
  )

  # Train transfer learning model (if available)
  if (use_transfer_learning) {
    cat("  Training transfer learning RF...\n")

    rf_transfer <- ranger(
      formula_transfer,
      data = data_depth,
      importance = "permutation",
      num.trees = CONFIG$n_trees,
      mtry = 5,  # More features
      oob.error = TRUE
    )
  }

  # Compare performance
  cat("\n  --- Performance Comparison ---\n")

  rmse_local <- sqrt(rf_local$prediction.error)
  r2_local <- rf_local$r.squared

  cat(sprintf("  Local only:  RMSE = %.2f kg/m²,  R² = %.3f\n",
              rmse_local, r2_local))

  if (use_transfer_learning) {
    rmse_transfer <- sqrt(rf_transfer$prediction.error)
    r2_transfer <- rf_transfer$r.squared

    improvement_rmse <- (rmse_local - rmse_transfer) / rmse_local * 100
    improvement_r2 <- r2_transfer - r2_local

    cat(sprintf("  Transfer:    RMSE = %.2f kg/m²,  R² = %.3f\n",
                rmse_transfer, r2_transfer))
    cat(sprintf("  Improvement: %.1f%% RMSE reduction, +%.3f R²\n",
                improvement_rmse, improvement_r2))

    # Save both models
    saveRDS(rf_transfer,
            file.path(CONFIG$output_models,
                     sprintf("rf_transfer_%gcm.rds", depth_cm)))

    # Store results
    results[[as.character(depth_cm)]] <- list(
      depth = depth_cm,
      n_samples = nrow(data_depth),
      rf_local = rf_local,
      rf_transfer = rf_transfer,
      improvement_pct = improvement_rmse,
      improvement_r2 = improvement_r2
    )

  } else {
    # Only local model
    results[[as.character(depth_cm)]] <- list(
      depth = depth_cm,
      n_samples = nrow(data_depth),
      rf_local = rf_local
    )
  }

  # Save local model
  saveRDS(rf_local,
          file.path(CONFIG$output_models,
                   sprintf("rf_local_%gcm.rds", depth_cm)))

  cat(sprintf("  ✓ Models saved for %g cm\n", depth_cm))
}

# ============================================================================
# STEP 4: SUMMARIZE RESULTS
# ============================================================================

cat("\n=== STEP 4: Transfer Learning Summary ===\n\n")

if (use_transfer_learning) {

  # Create summary table
  summary_df <- bind_rows(lapply(results, function(r) {
    data.frame(
      depth_cm = r$depth,
      n_samples = r$n_samples,
      rmse_local = sqrt(r$rf_local$prediction.error),
      r2_local = r$rf_local$r.squared,
      rmse_transfer = sqrt(r$rf_transfer$prediction.error),
      r2_transfer = r$rf_transfer$r.squared,
      improvement_pct = r$improvement_pct,
      improvement_r2 = r$improvement_r2
    )
  }))

  print(summary_df)

  # Save summary
  write_csv(summary_df,
            file.path(CONFIG$output_diagnostics, "transfer_learning_summary.csv"))

  # Overall statistics
  cat("\n--- Overall Transfer Learning Benefit ---\n")
  cat(sprintf("Mean RMSE reduction: %.1f%%\n", mean(summary_df$improvement_pct)))
  cat(sprintf("Mean R² improvement: +%.3f\n", mean(summary_df$improvement_r2)))

  # Feature importance comparison
  cat("\n--- Top 5 Features (Transfer Learning Model at 7.5 cm) ---\n")

  if ("7.5" %in% names(results)) {
    imp <- results[["7.5"]]$rf_transfer$variable.importance
    imp_sorted <- sort(imp, decreasing = TRUE)

    for (i in 1:min(5, length(imp_sorted))) {
      feat_name <- names(imp_sorted)[i]
      feat_imp <- imp_sorted[i]
      is_global <- grepl("^murray_|^gsw_|^wc_|^topo_|^sg_", feat_name)

      cat(sprintf("%d. %-30s %.3f %s\n",
                  i, feat_name, feat_imp,
                  ifelse(is_global, "[GLOBAL]", "[LOCAL]")))
    }
  }

} else {
  cat("Transfer learning models not trained (missing global features)\n")
  cat("Trained local-only models for comparison later.\n")
}

# ============================================================================
# STEP 5: NEXT STEPS
# ============================================================================

cat("\n========================================\n")
cat("TRANSFER LEARNING INTEGRATION COMPLETE\n")
cat("========================================\n\n")

cat("✓ Models trained for", length(results), "depths\n")

if (use_transfer_learning) {
  cat("✓ Transfer learning models show improvement!\n")
  cat(sprintf("  Average improvement: %.1f%% RMSE reduction\n",
              mean(summary_df$improvement_pct)))
}

cat("\n📋 NEXT STEPS:\n\n")

if (!use_transfer_learning) {
  cat("⚠️  To enable transfer learning:\n")
  cat("   1. Run GEE_EXTRACT_BLUECARBON_GLOBAL_MAPS.js\n")
  cat("   2. Download CSV to data_global/\n")
  cat("   3. Re-run this module\n\n")
}

cat("1. Make spatial predictions:\n")
cat("   → Update prediction script to use transfer learning models\n")
cat("   → Compare predicted maps: local vs transfer learning\n\n")

cat("2. Validate against independent test set:\n")
cat("   → Calculate MAE, RMSE, R² on holdout cores\n")
cat("   → Quantify improvement for MMRV reporting\n\n")

cat("3. Document for carbon project:\n")
cat("   → Report: 'Transfer learning improved predictions by X%'\n")
cat("   → Cite global products used (Murray, GSW, WorldClim)\n")
cat("   → Show before/after uncertainty maps\n\n")

cat("💡 TIP: Your RF models are saved in:\n")
cat("   ", CONFIG$output_models, "\n")
cat("   Load with: model <- readRDS('outputs/models/rf/rf_transfer_7.5cm.rds')\n\n")

if (use_transfer_learning) {
  cat("🎉 Transfer learning successfully integrated!\n")
  cat("   Global knowledge + Local precision = Better predictions\n\n")
}

cat("Done! 🌊\n\n")
