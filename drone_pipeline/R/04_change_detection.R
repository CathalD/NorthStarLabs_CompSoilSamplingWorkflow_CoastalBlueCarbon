# =============================================================================
# MODULE 04: CHANGE DETECTION (Multi-temporal Analysis)
# =============================================================================
#
# Purpose: Detect and quantify vegetation changes between two survey periods
#
# Inputs:
#   - Current survey orthomosaic, CHM, and classification
#   - Previous survey orthomosaic, CHM, and classification
#
# Outputs:
#   - NDVI change map
#   - Height change map
#   - Vegetation cover change statistics
#   - Change classification raster
#   - Change detection report
#
# Methods:
#   - Image co-registration
#   - Spectral change detection (NDVI differencing)
#   - Height change analysis (CHM differencing)
#   - Classification change matrix
#
# Runtime: 10-30 minutes
#
# References:
#   - Singh (1989). Digital change detection techniques using remotely-sensed data.
#   - Coppin et al. (2004). Digital change detection methods in ecosystem monitoring.
#
# =============================================================================

if (!require("pacman")) install.packages("pacman")
pacman::p_load(terra, sf, dplyr, ggplot2, viridis, RColorBrewer)

# Source configuration
if (!exists("PROJECT_NAME")) {
  if (file.exists("config/drone_config.R")) {
    source("config/drone_config.R")
  } else if (file.exists("../config/drone_config.R")) {
    source("../config/drone_config.R")
  }
}

#' Co-register two rasters to ensure perfect alignment
#'
#' @param current_raster Current period raster
#' @param previous_raster Previous period raster
#' @return List with co-registered rasters
coregister_rasters <- function(current_raster, previous_raster) {
  cat("🔄 Co-registering rasters...\n")

  # Resample previous to match current
  if (!compareGeom(current_raster, previous_raster, stopOnError = FALSE)) {
    cat("   Resampling previous raster to match current...\n")
    previous_aligned <- resample(previous_raster, current_raster, method = "bilinear")
  } else {
    previous_aligned <- previous_raster
  }

  cat("   ✓ Rasters aligned\n")

  return(list(current = current_raster, previous = previous_aligned))
}

#' Calculate NDVI change
calculate_ndvi_change <- function(current_ortho, previous_ortho) {
  cat("📊 Calculating NDVI change...\n")

  # Calculate NDVI for both periods (using Green as proxy for NIR in RGB imagery)
  current_ndvi <- (current_ortho[[2]] - current_ortho[[1]]) / (current_ortho[[2]] + current_ortho[[1]] + 0.00001)
  previous_ndvi <- (previous_ortho[[2]] - previous_ortho[[1]]) / (previous_ortho[[2]] + previous_ortho[[1]] + 0.00001)

  # Calculate change
  ndvi_change <- current_ndvi - previous_ndvi

  cat("   ✓ NDVI change calculated\n")

  return(ndvi_change)
}

#' Calculate height change from CHMs
calculate_height_change <- function(current_chm, previous_chm) {
  cat("📏 Calculating height change...\n")

  # Align rasters
  aligned <- coregister_rasters(current_chm, previous_chm)

  # Calculate change
  height_change <- aligned$current - aligned$previous

  cat("   ✓ Height change calculated\n")

  return(height_change)
}

#' Classify changes based on thresholds
classify_changes <- function(ndvi_change, height_change, thresholds = CHANGE_THRESHOLDS) {
  cat("🎯 Classifying changes...\n")

  # Initialize change classification raster
  change_class <- ndvi_change
  change_class[] <- 0  # Default: stable

  # Apply classification rules
  # 1 = Vegetation gain
  change_class[ndvi_change > thresholds$ndvi_change & height_change > thresholds$height_change] <- 1

  # 2 = Vegetation loss
  change_class[ndvi_change < -thresholds$ndvi_change & height_change < -thresholds$height_change] <- 2

  # 3 = Height increase only
  change_class[abs(ndvi_change) <= thresholds$ndvi_change & height_change > thresholds$height_change] <- 3

  # 4 = Height decrease only
  change_class[abs(ndvi_change) <= thresholds$ndvi_change & height_change < -thresholds$height_change] <- 4

  cat("   ✓ Changes classified\n")

  return(change_class)
}

#' Main change detection workflow
run_change_detection <- function(previous_ortho_path = NULL, previous_chm_path = NULL) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(" MODULE 04: CHANGE DETECTION\n")
  cat("═══════════════════════════════════════════════════════════════════════\n\n")

  if (!ENABLE_CHANGE_DETECTION) {
    cat("⚠️  Change detection is disabled in config\n")
    cat("   Set PREVIOUS_ORTHOMOSAIC path to enable\n\n")
    return(NULL)
  }

  # Load current survey data
  current_ortho <- rast(list.files(OUTPUT_DIRS$orthomosaics, pattern = "orthomosaic.*\\.tif$",
                                    full.names = TRUE, recursive = TRUE)[1])
  current_chm <- rast(file.path(OUTPUT_DIRS$tree_detections, "chm.tif"))

  # Load previous survey data
  previous_ortho <- rast(if(!is.null(previous_ortho_path)) previous_ortho_path else PREVIOUS_ORTHOMOSAIC)

  if (!is.null(previous_chm_path)) {
    previous_chm <- rast(previous_chm_path)
  } else {
    cat("⚠️  No previous CHM provided. Height change analysis skipped.\n")
    previous_chm <- NULL
  }

  # Calculate NDVI change
  ndvi_change <- calculate_ndvi_change(current_ortho, previous_ortho)

  # Calculate height change if CHMs available
  if (!is.null(previous_chm)) {
    height_change <- calculate_height_change(current_chm, previous_chm)

    # Classify changes
    change_classification <- classify_changes(ndvi_change, height_change)
  } else {
    height_change <- NULL
    change_classification <- NULL
  }

  # Save outputs
  change_dir <- OUTPUT_DIRS$change_detection
  dir.create(change_dir, recursive = TRUE, showWarnings = FALSE)

  writeRaster(ndvi_change, file.path(change_dir, "ndvi_change.tif"), overwrite = TRUE)
  cat("💾 Saved NDVI change map\n")

  if (!is.null(height_change)) {
    writeRaster(height_change, file.path(change_dir, "height_change.tif"), overwrite = TRUE)
    cat("💾 Saved height change map\n")
  }

  if (!is.null(change_classification)) {
    writeRaster(change_classification, file.path(change_dir, "change_classification.tif"), overwrite = TRUE)
    cat("💾 Saved change classification\n")

    # Calculate change statistics
    change_stats <- freq(change_classification)
    pixel_area <- prod(res(change_classification))
    change_stats$area_ha <- (change_stats$count * pixel_area) / 10000
    write.csv(change_stats, file.path(OUTPUT_DIRS$csv, "change_statistics.csv"), row.names = FALSE)
  }

  # Create visualization
  png(file.path(change_dir, "change_detection_map.png"), width = 12, height = 10, units = "in", res = 300)
  plot(change_classification,
       main = "Vegetation Change Classification",
       col = c("gray", "darkgreen", "red", "lightgreen", "orange"),
       axes = FALSE)
  legend("topright",
         legend = c("Stable", "Vegetation Gain", "Vegetation Loss", "Height Increase", "Height Decrease"),
         fill = c("gray", "darkgreen", "red", "lightgreen", "orange"),
         title = "Change Type")
  dev.off()

  cat("\n✅ Module 04 complete!\n\n")

  return(list(
    ndvi_change = ndvi_change,
    height_change = height_change,
    change_classification = change_classification
  ))
}

if (!interactive() || exists("RUN_MODULE_04")) {
  results <- run_change_detection()
}
