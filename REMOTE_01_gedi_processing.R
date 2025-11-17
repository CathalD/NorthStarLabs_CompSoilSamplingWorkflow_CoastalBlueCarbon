################################################################################
# REMOTE SENSING - PART 1: GEDI DATA PROCESSING
################################################################################
# Purpose: Process GEDI LiDAR data and integrate with Sentinel-2
# Input: Exports from Google Earth Engine (GEE_FOREST_GEDI_SENTINEL2.js)
# Output: Cleaned GEDI data, biomass models, validation metrics
# Methods: GEDI quality filtering, regression modeling, spatial interpolation
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

source("forest_carbon_config.R")

required_packages <- c(
  "terra",
  "sf",
  "dplyr",
  "ggplot2",
  "viridis",
  "tidyr",
  "caret",        # Machine learning
  "randomForest", # Random forest regression
  "gstat",        # Kriging
  "car",          # Regression diagnostics
  "corrplot",     # Correlation plots
  "gridExtra"     # Multiple plots
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Input Data Paths (from Google Earth Engine exports)
DATA_PATHS <- list(
  gedi_composite = "data/gee_exports/GEDI_Composite.tif",
  sentinel2 = "data/gee_exports/Sentinel2_Summer_Composite.tif",
  terrain = "data/gee_exports/Terrain_Derivatives.tif",
  biomass = "data/gee_exports/Biomass_Carbon_Stock.tif",
  feature_stack = "data/gee_exports/Forest_Carbon_Feature_Stack.tif",
  gedi_footprints = "data/gee_exports/GEDI_Footprints_with_Sentinel2.csv"
)

# Output Directory
OUTPUT_DIR <- DIRECTORIES$gedi
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUTPUT_DIR, "models"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUTPUT_DIR, "validation"), recursive = TRUE, showWarnings = FALSE)

# Processing Parameters
PROCESSING <- list(
  # GEDI quality filters
  min_canopy_height_m = 2,
  max_canopy_height_m = 60,
  min_canopy_cover = 0.1,  # 10%

  # Biomass model calibration
  calibration_method = "random_forest",  # "random_forest", "linear", or "gam"
  use_field_data = FALSE,  # Set TRUE if you have field plots

  # Validation
  validation_split = 0.3,  # 30% for validation
  cross_validation_folds = 5
)

# ==============================================================================
# STEP 1: LOAD RASTER DATA
# ==============================================================================

cat("\n=== STEP 1: Loading Raster Data ===\n")

# Check which files exist
rasters_loaded <- list()

for (name in names(DATA_PATHS)) {
  path <- DATA_PATHS[[name]]

  if (file.exists(path) && grepl("\\.tif$", path)) {
    rasters_loaded[[name]] <- rast(path)
    cat("  ✓ Loaded:", name, "\n")
  } else if (file.exists(path)) {
    cat("  ✓ Found CSV:", name, "\n")
  } else {
    cat("  ✗ Missing:", name, "\n")
    cat("    Expected:", path, "\n")
  }
}

# If no data, create synthetic example
if (length(rasters_loaded) == 0) {
  cat("\nNo GEE exports found. Creating synthetic example...\n")
  cat("→ Run GEE_FOREST_GEDI_SENTINEL2.js first and download exports to data/gee_exports/\n\n")

  # Create example data
  set.seed(42)

  # Template raster
  template <- rast(
    extent = c(0, 10000, 0, 10000),
    resolution = 30,
    crs = PROJECT$coordinate_system
  )

  # Synthetic GEDI heights
  gedi_rh98 <- template
  values(gedi_rh98) <- 5 + 20 * runif(ncell(template)) +
                       10 * sin(xFromCell(template, 1:ncell(template)) / 1000)
  names(gedi_rh98) <- "rh98"

  # Synthetic NDVI
  ndvi <- template
  values(ndvi) <- 0.4 + 0.4 * (values(gedi_rh98) / 30) + rnorm(ncell(template), 0, 0.05)
  names(ndvi) <- "NDVI"

  # Synthetic biomass (correlated with height)
  biomass <- template
  values(biomass) <- exp(2.3 + 0.038 * values(gedi_rh98) + rnorm(ncell(template), 0, 0.1))
  names(biomass) <- "AGB_Mg_ha"

  # Stack
  feature_stack <- c(gedi_rh98, ndvi, biomass)
  rasters_loaded$feature_stack <- feature_stack

  cat("Created synthetic data for demonstration\n")
  EXAMPLE_MODE <- TRUE

} else {
  EXAMPLE_MODE <- FALSE
}

# ==============================================================================
# STEP 2: LOAD GEDI FOOTPRINT DATA (POINTS)
# ==============================================================================

cat("\n=== STEP 2: Loading GEDI Footprints ===\n")

if (file.exists(DATA_PATHS$gedi_footprints)) {

  gedi_points <- read.csv(DATA_PATHS$gedi_footprints)
  cat("Loaded", nrow(gedi_points), "GEDI footprints\n")

  # Convert to spatial
  if (".geo" %in% names(gedi_points)) {
    # Parse GEE geometry format
    cat("Parsing GEE geometry format...\n")
    # This is complex - simpler to just use raster for now
    USE_POINTS <- FALSE
  } else if (all(c("longitude", "latitude") %in% names(gedi_points))) {
    gedi_sf <- st_as_sf(
      gedi_points,
      coords = c("longitude", "latitude"),
      crs = 4326
    )
    gedi_sf <- st_transform(gedi_sf, PROJECT$coordinate_system)
    USE_POINTS <- TRUE
    cat("Converted to spatial points\n")
  } else {
    USE_POINTS <- FALSE
  }

} else {

  cat("No GEDI footprint CSV found. Using raster data only.\n")
  USE_POINTS <- FALSE

  # Extract points from raster for modeling
  if ("feature_stack" %in% names(rasters_loaded)) {
    cat("Sampling points from raster...\n")

    # Sample 1000 random points
    gedi_points_sampled <- as.data.frame(
      rasters_loaded$feature_stack,
      xy = TRUE,
      na.rm = TRUE
    )

    # Subsample for efficiency
    if (nrow(gedi_points_sampled) > 5000) {
      set.seed(123)
      gedi_points_sampled <- gedi_points_sampled[sample(1:nrow(gedi_points_sampled), 5000), ]
    }

    gedi_points <- gedi_points_sampled
    cat("Sampled", nrow(gedi_points), "points from raster\n")
  }
}

# ==============================================================================
# STEP 3: QUALITY CONTROL
# ==============================================================================

cat("\n=== STEP 3: Quality Control ===\n")

if (exists("gedi_points") && nrow(gedi_points) > 0) {

  n_before <- nrow(gedi_points)

  # Filter by height
  if ("rh98" %in% names(gedi_points)) {
    gedi_points <- gedi_points %>%
      filter(
        rh98 >= PROCESSING$min_canopy_height_m,
        rh98 <= PROCESSING$max_canopy_height_m
      )
  }

  # Filter by canopy cover
  if ("cover" %in% names(gedi_points)) {
    gedi_points <- gedi_points %>%
      filter(cover >= PROCESSING$min_canopy_cover)
  }

  # Remove NAs
  gedi_points <- na.omit(gedi_points)

  n_after <- nrow(gedi_points)

  cat("Points before QC:", n_before, "\n")
  cat("Points after QC:", n_after, "\n")
  cat("Removed:", n_before - n_after, "points\n")

  # Summary statistics
  if ("rh98" %in% names(gedi_points)) {
    cat("\nGEDI Height Statistics:\n")
    cat("  Mean RH98:", round(mean(gedi_points$rh98), 2), "m\n")
    cat("  Std Dev:", round(sd(gedi_points$rh98), 2), "m\n")
    cat("  Range:", round(min(gedi_points$rh98), 1), "-",
        round(max(gedi_points$rh98), 1), "m\n")
  }
}

# ==============================================================================
# STEP 4: EXPLORATORY ANALYSIS
# ==============================================================================

cat("\n=== STEP 4: Exploratory Analysis ===\n")

if (exists("gedi_points") && nrow(gedi_points) > 100) {

  # Select numeric columns
  numeric_cols <- sapply(gedi_points, is.numeric)
  gedi_numeric <- gedi_points[, numeric_cols]

  # Remove x, y coordinates for correlation
  gedi_numeric <- gedi_numeric[, !names(gedi_numeric) %in% c("x", "y", "longitude", "latitude")]

  if (ncol(gedi_numeric) >= 2) {

    # Correlation matrix
    cor_matrix <- cor(gedi_numeric, use = "complete.obs")

    # Plot correlation
    png(file.path(OUTPUT_DIR, "validation/correlation_matrix.png"),
        width = 10, height = 10, units = "in", res = 300)
    corrplot(
      cor_matrix,
      method = "color",
      type = "upper",
      tl.col = "black",
      tl.srt = 45,
      addCoef.col = "black",
      number.cex = 0.7,
      title = "Variable Correlations",
      mar = c(0, 0, 2, 0)
    )
    dev.off()

    cat("Correlation matrix saved\n")

    # Scatterplot: Height vs NDVI
    if (all(c("rh98", "NDVI") %in% names(gedi_points))) {

      plot1 <- ggplot(gedi_points, aes(x = rh98, y = NDVI)) +
        geom_hex(bins = 50) +
        geom_smooth(method = "loess", color = "red", se = TRUE) +
        scale_fill_viridis_c() +
        labs(
          title = "GEDI Canopy Height vs. Sentinel-2 NDVI",
          x = "Canopy Height RH98 (m)",
          y = "NDVI",
          fill = "Count"
        ) +
        theme_minimal()

      ggsave(
        file.path(OUTPUT_DIR, "validation/height_ndvi_relationship.png"),
        plot1, width = 8, height = 6, dpi = 300
      )
    }
  }
}

# ==============================================================================
# STEP 5: BIOMASS MODEL DEVELOPMENT
# ==============================================================================

cat("\n=== STEP 5: Developing Biomass Model ===\n")

if (exists("gedi_points") && "rh98" %in% names(gedi_points)) {

  # Check if we have biomass data (from GEE or field)
  if ("AGB_Mg_ha" %in% names(gedi_points)) {
    # Use existing biomass estimates

    cat("Using biomass estimates from GEE...\n")

    # Split data
    set.seed(123)
    train_index <- sample(1:nrow(gedi_points), 0.7 * nrow(gedi_points))
    train_data <- gedi_points[train_index, ]
    test_data <- gedi_points[-train_index, ]

    # Predictors
    predictor_vars <- c("rh98", "rh95", "rh75", "rh50", "cover", "NDVI", "EVI")
    predictor_vars <- predictor_vars[predictor_vars %in% names(train_data)]

    cat("Predictors:", paste(predictor_vars, collapse = ", "), "\n")

    # Random Forest Model
    if (PROCESSING$calibration_method == "random_forest") {

      cat("\nTraining Random Forest model...\n")

      rf_formula <- as.formula(paste("AGB_Mg_ha ~", paste(predictor_vars, collapse = " + ")))

      rf_model <- randomForest(
        rf_formula,
        data = train_data,
        ntree = 500,
        mtry = floor(sqrt(length(predictor_vars))),
        importance = TRUE
      )

      # Predictions
      train_data$predicted <- predict(rf_model, train_data)
      test_data$predicted <- predict(rf_model, test_data)

      # Variable importance
      importance_df <- data.frame(
        variable = rownames(importance(rf_model)),
        importance = importance(rf_model)[, "%IncMSE"]
      ) %>% arrange(desc(importance))

      print(importance_df)

      # Save model
      saveRDS(rf_model, file.path(OUTPUT_DIR, "models/biomass_rf_model.rds"))
      write.csv(importance_df, file.path(OUTPUT_DIR, "models/variable_importance.csv"), row.names = FALSE)

      cat("Model saved\n")

    } else if (PROCESSING$calibration_method == "linear") {

      # Linear regression
      cat("\nTraining linear regression model...\n")

      lm_formula <- as.formula(paste("AGB_Mg_ha ~", paste(predictor_vars, collapse = " + ")))
      lm_model <- lm(lm_formula, data = train_data)

      train_data$predicted <- predict(lm_model, train_data)
      test_data$predicted <- predict(lm_model, test_data)

      # Summary
      print(summary(lm_model))

      saveRDS(lm_model, file.path(OUTPUT_DIR, "models/biomass_lm_model.rds"))
    }

    # ===========================================================================
    # STEP 6: MODEL VALIDATION
    # ===========================================================================

    cat("\n=== STEP 6: Model Validation ===\n")

    # Calculate metrics
    calc_metrics <- function(observed, predicted) {
      data.frame(
        RMSE = sqrt(mean((observed - predicted)^2)),
        MAE = mean(abs(observed - predicted)),
        R2 = cor(observed, predicted)^2,
        Bias = mean(predicted - observed),
        RMSE_percent = 100 * sqrt(mean((observed - predicted)^2)) / mean(observed)
      )
    }

    metrics_train <- calc_metrics(train_data$AGB_Mg_ha, train_data$predicted)
    metrics_test <- calc_metrics(test_data$AGB_Mg_ha, test_data$predicted)

    cat("\nTraining Set Performance:\n")
    print(metrics_train)

    cat("\nTest Set Performance:\n")
    print(metrics_test)

    # Validation plot
    plot_validation <- ggplot(test_data, aes(x = AGB_Mg_ha, y = predicted)) +
      geom_point(alpha = 0.5, color = "#2E7D32") +
      geom_abline(slope = 1, intercept = 0, color = "red", linetype = "dashed", size = 1) +
      geom_smooth(method = "lm", color = "blue", se = TRUE) +
      labs(
        title = "Biomass Model Validation",
        subtitle = paste0("R² = ", round(metrics_test$R2, 3),
                         ", RMSE = ", round(metrics_test$RMSE, 1), " Mg/ha"),
        x = "Observed Biomass (Mg/ha)",
        y = "Predicted Biomass (Mg/ha)"
      ) +
      theme_minimal() +
      coord_equal()

    ggsave(
      file.path(OUTPUT_DIR, "validation/biomass_validation.png"),
      plot_validation, width = 8, height = 7, dpi = 300
    )

    # Residual plot
    test_data$residual <- test_data$predicted - test_data$AGB_Mg_ha

    plot_residuals <- ggplot(test_data, aes(x = predicted, y = residual)) +
      geom_point(alpha = 0.5, color = "#2E7D32") +
      geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
      geom_smooth(method = "loess", color = "blue", se = TRUE) +
      labs(
        title = "Residual Plot",
        x = "Predicted Biomass (Mg/ha)",
        y = "Residual (Predicted - Observed)"
      ) +
      theme_minimal()

    ggsave(
      file.path(OUTPUT_DIR, "validation/residual_plot.png"),
      plot_residuals, width = 8, height = 6, dpi = 300
    )

    # Save validation results
    validation_summary <- rbind(
      data.frame(Dataset = "Training", metrics_train),
      data.frame(Dataset = "Test", metrics_test)
    )

    write.csv(
      validation_summary,
      file.path(OUTPUT_DIR, "validation/model_performance.csv"),
      row.names = FALSE
    )

    cat("\nValidation plots and metrics saved\n")
  }
}

# ==============================================================================
# STEP 7: UNCERTAINTY ANALYSIS
# ==============================================================================

cat("\n=== STEP 7: Uncertainty Analysis ===\n")

if (exists("test_data") && "predicted" %in% names(test_data)) {

  # Calculate prediction intervals (95%)
  prediction_sd <- sd(test_data$residual, na.rm = TRUE)

  uncertainty_summary <- data.frame(
    metric = c(
      "Model RMSE (Mg/ha)",
      "Mean Absolute Error (Mg/ha)",
      "Relative Error (%)",
      "95% Prediction Interval (Mg/ha)",
      "Model R²"
    ),
    value = c(
      round(metrics_test$RMSE, 1),
      round(metrics_test$MAE, 1),
      round(metrics_test$RMSE_percent, 1),
      paste("±", round(1.96 * prediction_sd, 1)),
      round(metrics_test$R2, 3)
    )
  )

  print(uncertainty_summary)

  write.csv(
    uncertainty_summary,
    file.path(OUTPUT_DIR, "validation/uncertainty_summary.csv"),
    row.names = FALSE
  )
}

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("GEDI DATA PROCESSING COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

if (!EXAMPLE_MODE && exists("metrics_test")) {
  cat("Model Performance:\n")
  cat("  R² =", round(metrics_test$R2, 3), "\n")
  cat("  RMSE =", round(metrics_test$RMSE, 1), "Mg/ha\n")
  cat("  Relative Error =", round(metrics_test$RMSE_percent, 1), "%\n\n")
}

cat("Outputs:\n")
cat("  - Biomass model:", file.path(OUTPUT_DIR, "models/"), "\n")
cat("  - Validation plots:", file.path(OUTPUT_DIR, "validation/"), "\n")
cat("  - Performance metrics:", file.path(OUTPUT_DIR, "validation/model_performance.csv"), "\n\n")

cat("Next Step: Run REMOTE_02_3d_carbon_mapping.R\n\n")

# Save workspace
if (exists("rf_model") || exists("lm_model")) {
  save(
    gedi_points,
    test_data,
    metrics_test,
    file = file.path(OUTPUT_DIR, "gedi_processing_workspace.RData")
  )
  cat("Workspace saved for 3D mapping\n")
}
