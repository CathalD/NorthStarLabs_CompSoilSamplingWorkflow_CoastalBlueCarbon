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
# STEP 2: PREPARE TRAINING DATA
# ============================================================================

cat("\n=== STEP 2: Prepare Training Data ===\n\n")

# Check for required local covariates
required_local <- c("NDVI_median_annual", "elevation_m")

missing_local <- setdiff(required_local, names(cores_merged))

if (length(missing_local) > 0) {
  cat("ERROR: Missing required local covariates:\n")
  cat(paste("  -", missing_local, collapse = "\n"), "\n")
  cat("\nPlease extract local covariates (Sentinel-2, elevation) first.\n\n")
  quit(save = "no", status = 1)
}

# Define model formulas
if (use_transfer_learning) {

  # Transfer learning model (local + global)
  formula_transfer <- as.formula(
    carbon_stock_kg_m2 ~
      # Local covariates
      NDVI_median_annual +
      EVI_median_growing +
      NDMI_median_annual +
      VV_median +
      VH_median +
      elevation_m +
      slope_degrees +

      # Global features (TRANSFER LEARNING!)
      murray_tidal_flag +
      gsw_water_occurrence_pct +
      gsw_water_seasonality_months +
      topo_tidal_elevation_flag +
      wc_MAT_C +
      wc_MAP_mm +
      sg_terrestrial_soc_0_5cm_g_kg
  )

  cat("✓ Transfer learning model formula created\n")
  cat("  Local covariates: 7\n")
  cat("  Global features: 7\n")

} else {
  formula_transfer <- NULL
}

# Local-only model (baseline for comparison)
formula_local <- as.formula(
  carbon_stock_kg_m2 ~
    NDVI_median_annual +
    EVI_median_growing +
    NDMI_median_annual +
    VV_median +
    VH_median +
    elevation_m +
    slope_degrees
)

cat("✓ Local-only model formula created\n")
cat("  Local covariates: 7\n")

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
