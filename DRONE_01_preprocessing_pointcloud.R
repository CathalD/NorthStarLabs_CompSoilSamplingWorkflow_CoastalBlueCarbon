################################################################################
# DRONE WORKFLOW - PART 1: POINT CLOUD PREPROCESSING
################################################################################
# Purpose: Process drone LiDAR or photogrammetry point clouds for forest analysis
# Input: Raw point cloud (LAS/LAZ), DEM, flight metadata
# Output: Normalized CHM (Canopy Height Model), cleaned point cloud
# Compatible with: LiDAR (YellowScan, Velodyne) or SfM (Pix4D, Agisoft)
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

# Load configuration
source("forest_carbon_config.R")

# Required packages
required_packages <- c(
  "lidR",           # LiDAR processing (CORE)
  "terra",          # Raster processing
  "sf",             # Vector data
  "raster",         # Legacy raster (some lidR functions use it)
  "future",         # Parallel processing
  "ggplot2",        # Visualization
  "viridis",        # Color palettes
  "dplyr",          # Data manipulation
  "moments"         # Statistical moments
)

# Install if missing
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Input/Output Paths
INPUT_POINTCLOUD <- "data/drone/raw/pointcloud.laz"  # CHANGE THIS
INPUT_DEM <- "data/drone/raw/dem.tif"                # Optional: ground DEM
OUTPUT_DIR <- DIRECTORIES$drone_chm

# Create output directories
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(DIRECTORIES$drone_trees, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(DIRECTORIES$drone, "diagnostics"), recursive = TRUE, showWarnings = FALSE)

# Processing Parameters
PARAMS <- list(
  # Point cloud filtering
  outlier_removal_k = 10,           # Neighbors for outlier detection
  outlier_removal_m = 3.0,          # Standard deviations for outlier
  height_threshold_m = 1.3,         # Minimum tree height (breast height)
  max_height_m = 70,                # Maximum plausible tree height

  # Ground classification (if not pre-classified)
  ground_classification = list(
    algorithm = "pmf",              # Progressive Morphological Filter
    ws = c(3, 6, 12),              # Window sizes (meters)
    th = c(0.5, 1, 2)              # Height thresholds
  ),

  # CHM creation
  chm_resolution_m = 0.5,           # Output CHM resolution (0.5m = 50cm)
  chm_algorithm = "p2r",            # point-to-raster (fast) or "pitfree" (better)
  pitfree_subcircle = 0.2,         # For pitfree algorithm

  # Smoothing
  smoothing_window_m = 3,           # Median filter window size
  smoothing_algorithm = "median"    # "median" or "gaussian"
)

# Parallel processing
plan(multisession, workers = 4)  # Adjust based on CPU cores

# ==============================================================================
# STEP 1: READ AND INSPECT POINT CLOUD
# ==============================================================================

cat("\n=== STEP 1: Reading Point Cloud ===\n")

# Check if file exists
if (!file.exists(INPUT_POINTCLOUD)) {
  cat("ERROR: Point cloud file not found!\n")
  cat("Please update INPUT_POINTCLOUD path in script.\n")
  cat("Expected location:", INPUT_POINTCLOUD, "\n")
  cat("\nTo proceed with example, you can:\n")
  cat("1. Place your LAS/LAZ file in data/drone/raw/\n")
  cat("2. Or update INPUT_POINTCLOUD variable to your file location\n\n")

  cat("Creating example template...\n")
  # Skip to template creation
  EXAMPLE_MODE <- TRUE
} else {
  EXAMPLE_MODE <- FALSE

  # Read point cloud
  cat("Reading:", INPUT_POINTCLOUD, "\n")
  las <- readLAS(INPUT_POINTCLOUD)

  # Print summary
  cat("\nPoint Cloud Summary:\n")
  print(las)
  cat("\nExtent:\n")
  print(extent(las))
  cat("\nPoint Density:", density(las), "pts/m²\n")

  # Check if classified
  if (!"Classification" %in% names(las@data)) {
    cat("WARNING: Point cloud does not have classification field.\n")
    cat("Will attempt ground classification...\n")
    NEEDS_GROUND_CLASSIFICATION <- TRUE
  } else {
    ground_points <- sum(las@data$Classification == 2)
    cat("Ground points (Class 2):", ground_points, "\n")
    NEEDS_GROUND_CLASSIFICATION <- ground_points < 100
  }
}

# ==============================================================================
# STEP 2: QUALITY CONTROL AND FILTERING
# ==============================================================================

if (!EXAMPLE_MODE) {
  cat("\n=== STEP 2: Quality Control ===\n")

  # Remove duplicate points
  cat("Removing duplicate points...\n")
  las <- filter_duplicates(las)

  # Remove outliers (statistical outlier removal)
  cat("Removing outliers...\n")
  las <- classify_noise(
    las,
    sor(k = PARAMS$outlier_removal_k, m = PARAMS$outlier_removal_m)
  )
  las <- filter_poi(las, Classification != 18)  # Remove noise class

  # Filter by height (remove obviously bad points)
  n_before <- npoints(las)
  las <- filter_poi(las, Z >= -5 & Z <= PARAMS$max_height_m)
  n_after <- npoints(las)
  cat("Removed", n_before - n_after, "points with invalid heights\n")

  # Normalize point density (optional - for very large datasets)
  # las <- decimate_points(las, homogenize(density = 20, res = 5))

  cat("Clean point count:", npoints(las), "\n")
}

# ==============================================================================
# STEP 3: GROUND CLASSIFICATION (if needed)
# ==============================================================================

if (!EXAMPLE_MODE && NEEDS_GROUND_CLASSIFICATION) {
  cat("\n=== STEP 3: Ground Classification ===\n")

  # Progressive Morphological Filter (Zhang et al. 2003)
  cat("Classifying ground points using PMF algorithm...\n")

  las <- classify_ground(
    las,
    algorithm = pmf(
      ws = PARAMS$ground_classification$ws,
      th = PARAMS$ground_classification$th
    )
  )

  ground_points <- sum(las@data$Classification == 2)
  cat("Classified ground points:", ground_points, "\n")
  cat("Ground point percentage:", round(100 * ground_points / npoints(las), 1), "%\n")

  # Quality check: expect 5-20% ground points in forest
  if (ground_points / npoints(las) < 0.02) {
    cat("WARNING: Very few ground points detected. Check parameters.\n")
  }
}

# ==============================================================================
# STEP 4: NORMALIZE HEIGHTS (CREATE DTM AND NORMALIZE)
# ==============================================================================

if (!EXAMPLE_MODE) {
  cat("\n=== STEP 4: Height Normalization ===\n")

  # Method 1: If external DEM provided
  if (file.exists(INPUT_DEM)) {
    cat("Using external DEM for normalization...\n")
    dem <- rast(INPUT_DEM)
    las_norm <- normalize_height(las, dem)

  } else {
    # Method 2: Generate DTM from classified ground points
    cat("Generating DTM from ground points...\n")

    # Create Digital Terrain Model (DTM)
    dtm <- rasterize_terrain(
      las,
      res = 1,  # 1m resolution
      algorithm = tin()  # Triangulated Irregular Network
    )

    # Plot DTM for inspection
    dtm_plot <- ggplot() +
      geom_raster(data = as.data.frame(dtm, xy = TRUE), aes(x = x, y = y, fill = Z)) +
      scale_fill_viridis_c(name = "Elevation (m)") +
      coord_equal() +
      labs(title = "Digital Terrain Model (DTM)", x = "X", y = "Y") +
      theme_minimal()

    ggsave(
      file.path(DIRECTORIES$drone, "diagnostics/dtm.png"),
      dtm_plot,
      width = 10, height = 8, dpi = 300
    )

    cat("DTM saved to diagnostics/\n")

    # Normalize point cloud
    cat("Normalizing point cloud heights...\n")
    las_norm <- normalize_height(las, dtm)
  }

  # Filter normalized heights
  las_norm <- filter_poi(
    las_norm,
    Z >= 0 & Z <= PARAMS$max_height_m
  )

  # Statistics
  cat("\nNormalized Height Statistics:\n")
  cat("Mean:", round(mean(las_norm@data$Z), 2), "m\n")
  cat("Max:", round(max(las_norm@data$Z), 2), "m\n")
  cat("Std Dev:", round(sd(las_norm@data$Z), 2), "m\n")
}

# ==============================================================================
# STEP 5: CREATE CANOPY HEIGHT MODEL (CHM)
# ==============================================================================

if (!EXAMPLE_MODE) {
  cat("\n=== STEP 5: Creating Canopy Height Model ===\n")

  if (PARAMS$chm_algorithm == "p2r") {
    # Fast point-to-raster
    cat("Using point-to-raster algorithm (fast)...\n")
    chm <- rasterize_canopy(
      las_norm,
      res = PARAMS$chm_resolution_m,
      algorithm = p2r(subcircle = 0.15)
    )

  } else if (PARAMS$chm_algorithm == "pitfree") {
    # Pit-free algorithm (better quality, slower)
    cat("Using pit-free algorithm (high quality)...\n")
    chm <- rasterize_canopy(
      las_norm,
      res = PARAMS$chm_resolution_m,
      algorithm = pitfree(
        subcircle = PARAMS$pitfree_subcircle,
        max_edge = c(0, 1.5)
      )
    )
  }

  # Fill small gaps (< 5m²)
  cat("Filling small gaps...\n")
  chm <- terra::focal(
    chm,
    w = 3,
    fun = function(x) {
      if (all(is.na(x))) return(NA)
      else return(max(x, na.rm = TRUE))
    },
    na.policy = "omit"
  )

  # Smooth CHM to remove noise
  cat("Smoothing CHM...\n")
  if (PARAMS$smoothing_algorithm == "median") {
    chm_smooth <- terra::focal(
      chm,
      w = PARAMS$smoothing_window_m / PARAMS$chm_resolution_m,
      fun = median,
      na.rm = TRUE
    )
  } else {
    # Gaussian smoothing
    chm_smooth <- terra::focal(
      chm,
      w = PARAMS$smoothing_window_m / PARAMS$chm_resolution_m,
      fun = mean,
      na.rm = TRUE
    )
  }

  # CHM statistics
  cat("\nCHM Statistics:\n")
  cat("Mean height:", round(global(chm_smooth, "mean", na.rm = TRUE)[1,1], 2), "m\n")
  cat("Max height:", round(global(chm_smooth, "max", na.rm = TRUE)[1,1], 2), "m\n")
  cat("Resolution:", res(chm_smooth)[1], "m\n")
  cat("Extent:", as.vector(ext(chm_smooth)), "\n")

  # Save CHM
  chm_path <- file.path(OUTPUT_DIR, "chm_smoothed.tif")
  writeRaster(chm_smooth, chm_path, overwrite = TRUE)
  cat("\nCHM saved:", chm_path, "\n")

  # Save raw CHM too
  writeRaster(chm, file.path(OUTPUT_DIR, "chm_raw.tif"), overwrite = TRUE)

  # ==============================================================================
  # STEP 6: VISUALIZATION
  # ==============================================================================

  cat("\n=== STEP 6: Creating Visualizations ===\n")

  # CHM visualization
  chm_df <- as.data.frame(chm_smooth, xy = TRUE)
  names(chm_df)[3] <- "height"

  chm_plot <- ggplot(chm_df, aes(x = x, y = y, fill = height)) +
    geom_raster() +
    scale_fill_gradientn(
      colors = COLOR_SCHEMES$forest_height,
      name = "Height (m)",
      na.value = "transparent"
    ) +
    coord_equal() +
    labs(
      title = "Canopy Height Model (CHM)",
      subtitle = paste("Resolution:", PARAMS$chm_resolution_m, "m"),
      x = "Easting (m)",
      y = "Northing (m)"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(face = "bold", size = 14)
    )

  ggsave(
    file.path(DIRECTORIES$drone, "diagnostics/chm_visualization.png"),
    chm_plot,
    width = 12, height = 10, dpi = 300
  )

  # Height distribution histogram
  hist_plot <- ggplot(chm_df[!is.na(chm_df$height) & chm_df$height > 1.3, ],
                      aes(x = height)) +
    geom_histogram(binwidth = 1, fill = "#2E7D32", color = "white") +
    labs(
      title = "Canopy Height Distribution",
      subtitle = paste("Heights >", PARAMS$height_threshold_m, "m (breast height)"),
      x = "Height (m)",
      y = "Frequency (pixels)"
    ) +
    theme_minimal()

  ggsave(
    file.path(DIRECTORIES$drone, "diagnostics/height_distribution.png"),
    hist_plot,
    width = 10, height = 6, dpi = 300
  )

  cat("Visualizations saved to diagnostics/\n")

  # ==============================================================================
  # STEP 7: EXPORT PROCESSED DATA
  # ==============================================================================

  cat("\n=== STEP 7: Exporting Processed Data ===\n")

  # Save normalized point cloud (for tree segmentation)
  las_output <- file.path(DIRECTORIES$drone, "pointcloud_normalized.laz")
  writeLAS(las_norm, las_output)
  cat("Normalized point cloud:", las_output, "\n")

  # Create metrics summary
  metrics <- data.frame(
    metric = c(
      "Total Points",
      "Ground Points",
      "Vegetation Points",
      "Point Density (pts/m²)",
      "Area (ha)",
      "Mean Height (m)",
      "Max Height (m)",
      "CHM Resolution (m)"
    ),
    value = c(
      npoints(las_norm),
      sum(las_norm@data$Classification == 2),
      sum(las_norm@data$Z > PARAMS$height_threshold_m),
      round(density(las_norm), 1),
      round(area(las_norm) / 10000, 2),
      round(mean(las_norm@data$Z), 2),
      round(max(las_norm@data$Z), 2),
      PARAMS$chm_resolution_m
    )
  )

  write.csv(
    metrics,
    file.path(DIRECTORIES$drone, "diagnostics/processing_metrics.csv"),
    row.names = FALSE
  )

  print(metrics)
}

# ==============================================================================
# STEP 8: EXAMPLE TEMPLATE (if no data)
# ==============================================================================

if (EXAMPLE_MODE) {
  cat("\n=== Creating Example Template ===\n")

  # Create example CHM using simulated data
  set.seed(42)

  # Simulate a 200m x 200m forest
  x_coords <- seq(0, 200, by = 0.5)
  y_coords <- seq(0, 200, by = 0.5)
  grid <- expand.grid(x = x_coords, y = y_coords)

  # Simulate height with spatial autocorrelation
  grid$height <- 15 +  # Base height
    10 * sin(grid$x / 30) * cos(grid$y / 40) +  # Large-scale variation
    5 * rnorm(nrow(grid))  # Random noise

  # Add some "clearings"
  grid$height[grid$x > 80 & grid$x < 120 & grid$y > 80 & grid$y < 120] <- 2

  # Set minimum height
  grid$height[grid$height < 0] <- 0

  # Create raster
  chm_example <- rast(grid, type = "xyz")
  crs(chm_example) <- "EPSG:32610"

  # Save
  dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
  writeRaster(
    chm_example,
    file.path(OUTPUT_DIR, "chm_smoothed_EXAMPLE.tif"),
    overwrite = TRUE
  )

  cat("Example CHM created:", file.path(OUTPUT_DIR, "chm_smoothed_EXAMPLE.tif"), "\n")
  cat("\nTo use with real data:\n")
  cat("1. Update INPUT_POINTCLOUD path\n")
  cat("2. Re-run this script\n")

  chm_smooth <- chm_example  # For next script
}

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("DRONE PREPROCESSING COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Outputs:\n")
cat("  - CHM:", file.path(OUTPUT_DIR, "chm_smoothed.tif"), "\n")
cat("  - Normalized point cloud:", file.path(DIRECTORIES$drone, "pointcloud_normalized.laz"), "\n")
cat("  - Diagnostics:", file.path(DIRECTORIES$drone, "diagnostics/"), "\n\n")

cat("Next Step: Run DRONE_02_tree_segmentation.R\n\n")

# Save workspace for next script
save(
  chm_smooth,
  PARAMS,
  file = file.path(DIRECTORIES$drone, "preprocessing_workspace.RData")
)

cat("Workspace saved for tree segmentation step.\n")
