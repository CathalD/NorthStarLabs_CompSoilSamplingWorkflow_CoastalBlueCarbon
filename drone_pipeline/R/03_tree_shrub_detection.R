# =============================================================================
# MODULE 03: INDIVIDUAL TREE/SHRUB DETECTION
# =============================================================================
#
# Purpose: Detect and delineate individual trees and shrubs from Canopy Height
#          Model (CHM), extract tree metrics (height, crown area, location)
#
# Inputs:
#   - Digital Surface Model (DSM) from Module 01
#   - Optional: Digital Terrain Model (DTM) for CHM generation
#   - Classification raster from Module 02 (optional, for filtering)
#
# Outputs:
#   - Canopy Height Model (CHM)
#   - Tree locations (shapefile and CSV with lat/long)
#   - Tree metrics (height, crown area, coordinates)
#   - Crown delineation polygons (shapefile)
#   - Summary statistics
#
# Methods:
#   - CHM generation from DSM (or DSM-DTM if DTM available)
#   - Watershed segmentation (Dalponte & Coomes, 2016)
#   - Local maxima detection (ForestTools package)
#   - Crown delineation using marker-controlled watershed
#
# Runtime: 5-20 minutes (depending on area size and tree density)
#
# References:
#   - Dalponte & Coomes (2016). Tree-centric mapping of forest carbon density
#     from airborne laser scanning and hyperspectral data. Methods in Ecology
#     and Evolution, 7(10), 1236-1245.
#   - Popescu & Wynne (2004). Seeing the trees in the forest. Photogrammetric
#     Engineering & Remote Sensing, 70(5), 589-604.
#
# =============================================================================

# Load required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  terra,          # Raster processing
  sf,             # Vector data
  lidR,           # LiDAR and point cloud processing (includes CHM tools)
  ForestTools,    # Tree detection and segmentation
  dplyr,          # Data manipulation
  ggplot2,        # Visualization
  viridis,        # Color scales
  progress,       # Progress bars
  spatstat        # Spatial point patterns (optional)
)

# =============================================================================
# CONFIGURATION
# =============================================================================

# Source configuration file
if (!exists("PROJECT_NAME")) {
  if (file.exists("config/drone_config.R")) {
    source("config/drone_config.R")
  } else if (file.exists("../config/drone_config.R")) {
    source("../config/drone_config.R")
  } else {
    stop("Configuration file not found.")
  }
}

# =============================================================================
# CHM GENERATION
# =============================================================================

#' Generate Canopy Height Model (CHM) from DSM
#'
#' If DTM is available: CHM = DSM - DTM
#' If DTM not available: Use DSM directly (assumes relatively flat terrain)
#'
#' @param dsm_path Path to Digital Surface Model
#' @param dtm_path Path to Digital Terrain Model (optional)
#' @return CHM as SpatRaster
generate_chm <- function(dsm_path, dtm_path = NULL) {
  cat("🏔️  Generating Canopy Height Model (CHM)...\n")

  # Load DSM
  dsm <- rast(dsm_path)
  cat("   Loaded DSM:", dsm_path, "\n")

  if (!is.null(dtm_path) && file.exists(dtm_path)) {
    cat("   Loading DTM:", dtm_path, "\n")
    dtm <- rast(dtm_path)

    # Ensure same extent and resolution
    if (!compareGeom(dsm, dtm, stopOnError = FALSE)) {
      cat("   Resampling DTM to match DSM...\n")
      dtm <- resample(dtm, dsm, method = "bilinear")
    }

    # Calculate CHM
    cat("   Calculating CHM = DSM - DTM...\n")
    chm <- dsm - dtm

  } else {
    cat("   ⚠️  No DTM provided. Using DSM as CHM proxy.\n")
    cat("   Note: This assumes relatively flat terrain. For accurate height\n")
    cat("         measurements on sloped terrain, DTM is recommended.\n")

    # Use DSM directly, but normalize to minimum elevation
    min_elev <- global(dsm, "min", na.rm = TRUE)[1, 1]
    chm <- dsm - min_elev
  }

  # Apply height filters
  cat("   Applying height filters...\n")
  cat("     Min height:", MIN_TREE_HEIGHT, "m\n")
  cat("     Max height:", MAX_TREE_HEIGHT, "m\n")

  # Set values outside range to NA
  chm[chm < MIN_TREE_HEIGHT] <- NA
  chm[chm > MAX_TREE_HEIGHT] <- NA

  # Smooth CHM to reduce noise
  cat("   Smoothing CHM (focal filter)...\n")
  chm_smooth <- focal(chm, w = 3, fun = "mean", na.rm = TRUE)

  cat("   ✓ CHM generated\n")

  # Print CHM statistics
  chm_stats <- global(chm_smooth, c("min", "max", "mean", "sd"), na.rm = TRUE)
  cat("\n   CHM Statistics:\n")
  cat("     Min height:", round(chm_stats$min, 2), "m\n")
  cat("     Max height:", round(chm_stats$max, 2), "m\n")
  cat("     Mean height:", round(chm_stats$mean, 2), "m\n")
  cat("     SD:", round(chm_stats$sd, 2), "m\n\n")

  return(chm_smooth)
}

# =============================================================================
# TREE DETECTION
# =============================================================================

#' Detect tree tops using local maxima method
#'
#' @param chm Canopy Height Model (SpatRaster)
#' @param ws Window size (or function) for local maxima detection
#' @return SF points with tree locations
detect_trees_local_maxima <- function(chm, ws = LOCAL_MAXIMA_PARAMS$ws) {
  cat("🌲 Detecting tree tops using local maxima method...\n")

  # Convert terra to raster for ForestTools compatibility
  chm_raster <- raster::raster(chm)

  # Variable window size function (larger windows for taller trees)
  # ws = a + b * height
  lin_window <- function(x) {
    if (x < 2) return(3)
    if (x < 10) return(3 + 0.15 * x)
    return(5)
  }

  # Detect tree tops
  cat("   Searching for local maxima...\n")

  tryCatch({
    tree_tops <- ForestTools::vwf(
      CHM = chm_raster,
      winFun = lin_window,
      minHeight = MIN_TREE_HEIGHT
    )

    # Convert to sf
    tree_tops_sf <- st_as_sf(tree_tops)

    cat("   ✓ Detected", nrow(tree_tops_sf), "trees\n")

    return(tree_tops_sf)

  }, error = function(e) {
    stop("Tree detection failed: ", e$message)
  })
}

#' Detect trees using watershed segmentation
#'
#' @param chm Canopy Height Model
#' @param tree_tops SF points with seed locations
#' @param tolerance Tolerance parameter for segmentation
#' @return SF polygons with crown delineations
detect_trees_watershed <- function(chm, tree_tops = NULL, tolerance = WATERSHED_PARAMS$tolerance) {
  cat("🌲 Performing watershed segmentation...\n")

  # If no tree tops provided, detect them first
  if (is.null(tree_tops)) {
    tree_tops <- detect_trees_local_maxima(chm)
  }

  # Convert to raster for ForestTools
  chm_raster <- raster::raster(chm)

  # Perform watershed segmentation
  cat("   Running marker-controlled watershed...\n")

  crowns <- ForestTools::mcws(
    treetops = as(tree_tops, "Spatial"),
    CHM = chm_raster,
    minHeight = MIN_TREE_HEIGHT,
    format = "polygons"
  )

  # Convert to sf
  crowns_sf <- st_as_sf(crowns)

  cat("   ✓ Delineated", nrow(crowns_sf), "crowns\n")

  return(crowns_sf)
}

# =============================================================================
# TREE METRICS CALCULATION
# =============================================================================

#' Calculate tree-level metrics
#'
#' @param tree_tops SF points with tree locations
#' @param crowns SF polygons with crown boundaries (optional)
#' @param chm Canopy Height Model
#' @return Data frame with tree metrics
calculate_tree_metrics <- function(tree_tops, crowns = NULL, chm) {
  cat("📏 Calculating tree metrics...\n")

  # Extract height at tree top locations
  tree_tops$height <- terra::extract(chm, vect(tree_tops))[, 2]

  # Get coordinates
  coords <- st_coordinates(tree_tops)
  tree_tops$x_coord <- coords[, 1]
  tree_tops$y_coord <- coords[, 2]

  # Convert to lat/long if in projected CRS
  if (st_is_longlat(tree_tops)) {
    tree_tops$longitude <- coords[, 1]
    tree_tops$latitude <- coords[, 2]
  } else {
    coords_latlong <- st_transform(tree_tops, crs = 4326)
    coords_ll <- st_coordinates(coords_latlong)
    tree_tops$longitude <- coords_ll[, 1]
    tree_tops$latitude <- coords_ll[, 2]
  }

  # If crowns available, calculate crown metrics
  if (!is.null(crowns)) {
    cat("   Calculating crown metrics...\n")

    # Calculate crown area
    crowns$crown_area_m2 <- as.numeric(st_area(crowns))

    # Match trees to crowns (spatial join)
    tree_crown_join <- st_join(tree_tops, crowns, join = st_intersects)

    # Add crown area to tree metrics
    tree_tops$crown_area_m2 <- tree_crown_join$crown_area_m2

    # Estimate crown diameter (assuming circular crown)
    tree_tops$crown_diameter_m <- 2 * sqrt(tree_tops$crown_area_m2 / pi)

  } else {
    tree_tops$crown_area_m2 <- NA
    tree_tops$crown_diameter_m <- NA
  }

  # Add tree ID
  tree_tops$tree_id <- 1:nrow(tree_tops)

  # Filter by crown size constraints (if applicable)
  if (!is.null(crowns)) {
    valid_trees <- tree_tops$crown_area_m2 >= CROWN_PARAMS$min_crown_area &
                   tree_tops$crown_area_m2 <= CROWN_PARAMS$max_crown_area

    n_filtered <- sum(!valid_trees, na.rm = TRUE)
    if (n_filtered > 0) {
      cat("   Filtered", n_filtered, "trees with invalid crown size\n")
      tree_tops <- tree_tops[valid_trees, ]
    }
  }

  cat("   ✓ Calculated metrics for", nrow(tree_tops), "trees\n")

  return(tree_tops)
}

# =============================================================================
# SUMMARY STATISTICS
# =============================================================================

#' Calculate summary statistics for detected trees
#'
#' @param tree_metrics SF object or data frame with tree metrics
#' @param survey_area_ha Survey area in hectares (optional)
#' @return List with summary statistics
calculate_tree_summary_stats <- function(tree_metrics, survey_area_ha = NULL) {
  cat("📊 Calculating summary statistics...\n")

  # Convert to data frame if sf
  if (inherits(tree_metrics, "sf")) {
    metrics_df <- st_drop_geometry(tree_metrics)
  } else {
    metrics_df <- tree_metrics
  }

  # Basic statistics
  stats <- list(
    total_trees = nrow(metrics_df),
    mean_height_m = mean(metrics_df$height, na.rm = TRUE),
    sd_height_m = sd(metrics_df$height, na.rm = TRUE),
    min_height_m = min(metrics_df$height, na.rm = TRUE),
    max_height_m = max(metrics_df$height, na.rm = TRUE),
    median_height_m = median(metrics_df$height, na.rm = TRUE)
  )

  # Crown statistics (if available)
  if ("crown_area_m2" %in% names(metrics_df)) {
    stats$mean_crown_area_m2 <- mean(metrics_df$crown_area_m2, na.rm = TRUE)
    stats$total_crown_cover_m2 <- sum(metrics_df$crown_area_m2, na.rm = TRUE)
    stats$total_crown_cover_ha <- stats$total_crown_cover_m2 / 10000
  }

  # Density (if survey area provided)
  if (!is.null(survey_area_ha)) {
    stats$survey_area_ha <- survey_area_ha
    stats$tree_density_per_ha <- stats$total_trees / survey_area_ha

    if ("crown_area_m2" %in% names(metrics_df)) {
      stats$canopy_cover_percent <- (stats$total_crown_cover_ha / survey_area_ha) * 100
    }
  }

  # Height classes
  stats$height_classes <- table(cut(
    metrics_df$height,
    breaks = c(0, 2, 5, 10, 15, 20, Inf),
    labels = c("<2m", "2-5m", "5-10m", "10-15m", "15-20m", ">20m")
  ))

  # Print summary
  cat("\n   Tree Detection Summary:\n")
  cat("   ═══════════════════════════════════════════\n")
  cat("   Total trees detected:", stats$total_trees, "\n")
  cat("   Height range:", round(stats$min_height_m, 1), "-", round(stats$max_height_m, 1), "m\n")
  cat("   Mean height:", round(stats$mean_height_m, 1), "±", round(stats$sd_height_m, 1), "m\n")

  if (!is.null(survey_area_ha)) {
    cat("   Tree density:", round(stats$tree_density_per_ha, 1), "trees/ha\n")

    if ("crown_area_m2" %in% names(metrics_df)) {
      cat("   Canopy cover:", round(stats$canopy_cover_percent, 1), "%\n")
    }
  }

  cat("\n   Height distribution:\n")
  print(stats$height_classes)
  cat("\n")

  return(stats)
}

# =============================================================================
# VISUALIZATION
# =============================================================================

#' Plot CHM with detected trees
#'
#' @param chm Canopy Height Model
#' @param tree_tops SF points with tree locations
#' @param output_path Path to save plot
plot_chm_with_trees <- function(chm, tree_tops, output_path = NULL) {
  cat("📊 Creating CHM visualization with tree locations...\n")

  if (!is.null(output_path)) {
    png(output_path, width = 12, height = 10, units = "in", res = 300)
  }

  # Plot CHM
  plot(chm,
       main = "Canopy Height Model with Detected Trees",
       col = terrain.colors(100),
       axes = FALSE)

  # Add tree locations
  points(vect(tree_tops), col = "red", pch = 20, cex = 0.5)

  # Add legend
  legend("topright",
         legend = c("Tree tops", paste("n =", nrow(tree_tops))),
         col = c("red", NA),
         pch = c(20, NA),
         bg = "white")

  if (!is.null(output_path)) {
    dev.off()
    cat("   ✓ Saved to:", output_path, "\n")
  }
}

#' Plot tree height distribution
#'
#' @param tree_metrics Tree metrics data frame
#' @param output_path Path to save plot
plot_tree_height_distribution <- function(tree_metrics, output_path = NULL) {
  cat("📊 Creating tree height distribution plot...\n")

  # Convert to data frame if sf
  if (inherits(tree_metrics, "sf")) {
    metrics_df <- st_drop_geometry(tree_metrics)
  } else {
    metrics_df <- tree_metrics
  }

  p <- ggplot(metrics_df, aes(x = height)) +
    geom_histogram(bins = 30, fill = "forestgreen", color = "black", alpha = 0.7) +
    geom_vline(aes(xintercept = mean(height)), color = "red", linetype = "dashed", size = 1) +
    labs(
      title = "Tree Height Distribution",
      x = "Height (m)",
      y = "Count",
      caption = paste("Mean height:", round(mean(metrics_df$height, na.rm = TRUE), 1), "m")
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      axis.text = element_text(size = 12),
      axis.title = element_text(size = 14)
    )

  if (!is.null(output_path)) {
    ggsave(output_path, p, width = 10, height = 6, dpi = 300)
    cat("   ✓ Saved to:", output_path, "\n")
  } else {
    print(p)
  }

  return(p)
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================

#' Run complete tree detection workflow
#'
#' @param dsm_path Path to DSM (if NULL, will search in output directories)
#' @param dtm_path Path to DTM (optional)
#' @export
run_tree_detection <- function(dsm_path = NULL, dtm_path = NULL) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(" MODULE 03: TREE/SHRUB DETECTION\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("\n")

  # Find DSM if not provided
  if (is.null(dsm_path)) {
    dsm_files <- list.files(
      OUTPUT_DIRS$dsm,
      pattern = "dsm.*\\.tif$",
      full.names = TRUE,
      recursive = TRUE
    )

    if (length(dsm_files) == 0) {
      stop("No DSM found. Please run Module 01 first or provide dsm_path.")
    }

    dsm_path <- dsm_files[1]
  }

  cat("📂 Using DSM:", dsm_path, "\n\n")

  # Generate CHM
  chm <- generate_chm(dsm_path, dtm_path)

  # Save CHM
  chm_path <- file.path(OUTPUT_DIRS$tree_detections, "chm.tif")
  dir.create(OUTPUT_DIRS$tree_detections, recursive = TRUE, showWarnings = FALSE)
  writeRaster(chm, chm_path, overwrite = TRUE)
  cat("💾 Saved CHM:", chm_path, "\n\n")

  # Detect trees based on method
  if (TREE_DETECTION_METHOD == "watershed") {
    cat("🎯 Using WATERSHED segmentation method\n\n")

    # First detect tree tops
    tree_tops <- detect_trees_local_maxima(chm)

    # Then perform watershed segmentation
    crowns <- detect_trees_watershed(chm, tree_tops)

    # Calculate metrics
    tree_metrics <- calculate_tree_metrics(tree_tops, crowns, chm)

  } else {  # local_maxima
    cat("🎯 Using LOCAL MAXIMA method\n\n")

    # Detect tree tops only
    tree_tops <- detect_trees_local_maxima(chm)

    # Calculate metrics without crown delineation
    tree_metrics <- calculate_tree_metrics(tree_tops, NULL, chm)

    crowns <- NULL
  }

  # Calculate survey area (from CHM extent)
  chm_area_m2 <- prod(dim(chm)[1:2]) * prod(res(chm))
  survey_area_ha <- chm_area_m2 / 10000

  # Calculate summary statistics
  summary_stats <- calculate_tree_summary_stats(tree_metrics, survey_area_ha)

  # Save tree locations (shapefile)
  trees_shapefile <- file.path(OUTPUT_DIRS$shapefiles, "tree_locations.shp")
  dir.create(OUTPUT_DIRS$shapefiles, recursive = TRUE, showWarnings = FALSE)
  st_write(tree_metrics, trees_shapefile, delete_dsn = TRUE, quiet = TRUE)
  cat("💾 Saved tree locations shapefile:", trees_shapefile, "\n")

  # Save tree metrics (CSV)
  metrics_csv <- file.path(OUTPUT_DIRS$csv, "tree_metrics.csv")
  dir.create(OUTPUT_DIRS$csv, recursive = TRUE, showWarnings = FALSE)
  write.csv(st_drop_geometry(tree_metrics), metrics_csv, row.names = FALSE)
  cat("💾 Saved tree metrics CSV:", metrics_csv, "\n")

  # Save crown polygons if available
  if (!is.null(crowns)) {
    crowns_shapefile <- file.path(OUTPUT_DIRS$shapefiles, "tree_crowns.shp")
    st_write(crowns, crowns_shapefile, delete_dsn = TRUE, quiet = TRUE)
    cat("💾 Saved crown polygons:", crowns_shapefile, "\n")
  }

  # Save summary statistics
  summary_list <- as.data.frame(summary_stats[!names(summary_stats) %in% "height_classes"])
  write.csv(summary_list, file.path(OUTPUT_DIRS$csv, "tree_summary_statistics.csv"), row.names = FALSE)

  # Create visualizations
  cat("\n📊 Creating visualizations...\n")

  plot_chm_with_trees(
    chm,
    tree_metrics,
    file.path(OUTPUT_DIRS$tree_detections, "chm_with_trees.png")
  )

  plot_tree_height_distribution(
    tree_metrics,
    file.path(OUTPUT_DIRS$tree_detections, "tree_height_distribution.png")
  )

  cat("\n✅ Module 03 complete!\n")
  cat("\nNext step: Run Module 04 (Change Detection) if multi-temporal data available\n")
  cat("   source('R/04_change_detection.R')\n")
  cat("\nOr skip to Module 05 (Summary Statistics)\n")
  cat("   source('R/05_summary_statistics.R')\n\n")

  return(list(
    chm = chm,
    tree_metrics = tree_metrics,
    crowns = crowns,
    summary_stats = summary_stats
  ))
}

# =============================================================================
# RUN MODULE (if sourced directly)
# =============================================================================

if (!interactive() || exists("RUN_MODULE_03")) {
  results <- run_tree_detection()
}
