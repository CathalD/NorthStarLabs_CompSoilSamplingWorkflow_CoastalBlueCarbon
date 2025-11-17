#' Data Preprocessing and Quality Control Functions
#'
#' @name preprocess
NULL

#' Create catalog of lidar tiles with summary information
#'
#' Generates a comprehensive catalog of all lidar tiles in a directory with
#' extent, point density, and quality metrics
#'
#' @param folder Path to folder containing .las or .laz files
#' @param output_file Optional path to save catalog as shapefile
#' @return sf object with tile information
#' @export
#' @examples
#' \dontrun{
#' catalog <- create_tile_catalog("path/to/lidar/tiles")
#' plot(catalog["point_density"])
#' }
create_tile_catalog <- function(folder, output_file = NULL) {
  logger::log_info("Creating lidar tile catalog for: {folder}")

  # Create LAScatalog
  ctg <- lidR::readLAScatalog(folder)

  # Extract summary information
  tile_info <- data.frame(
    filename = basename(ctg@data$filename),
    path = ctg@data$filename,
    min_x = ctg@data$Min.X,
    max_x = ctg@data$Max.X,
    min_y = ctg@data$Min.Y,
    max_y = ctg@data$Max.Y,
    min_z = ctg@data$Min.Z,
    max_z = ctg@data$Max.Z,
    num_points = ctg@data$Number.of.point.records,
    stringsAsFactors = FALSE
  )

  # Calculate area and point density
  tile_info$area_m2 <- (tile_info$max_x - tile_info$min_x) *
                       (tile_info$max_y - tile_info$min_y)
  tile_info$point_density <- tile_info$num_points / tile_info$area_m2

  # Create polygons for each tile
  tile_polygons <- lapply(1:nrow(tile_info), function(i) {
    coords <- matrix(c(
      tile_info$min_x[i], tile_info$min_y[i],
      tile_info$max_x[i], tile_info$min_y[i],
      tile_info$max_x[i], tile_info$max_y[i],
      tile_info$min_x[i], tile_info$max_y[i],
      tile_info$min_x[i], tile_info$min_y[i]
    ), ncol = 2, byrow = TRUE)

    sf::st_polygon(list(coords))
  })

  # Create sf object
  tile_sf <- sf::st_sf(
    tile_info,
    geometry = sf::st_sfc(tile_polygons, crs = sf::st_crs(ctg))
  )

  # Save if output file specified
  if (!is.null(output_file)) {
    sf::st_write(tile_sf, output_file, delete_dsn = TRUE)
    logger::log_info("Catalog saved to: {output_file}")
  }

  logger::log_info("Catalog created: {nrow(tile_sf)} tiles, total {sum(tile_info$num_points)} points")

  return(tile_sf)
}

#' Classify ground points using CSF algorithm
#'
#' Implements Cloth Simulation Filter (Zhang et al. 2016) for ground classification
#'
#' @param las LAS object
#' @param cloth_resolution Grid resolution for cloth (default 0.5m)
#' @param rigidness Rigidness of cloth (1=steep, 2=relief, 3=flat)
#' @param iterations Maximum iterations
#' @param classification_threshold Height threshold for ground classification
#' @return LAS object with updated classification
#' @export
#' @references
#' Zhang et al. (2016) "An Easy-to-Use Airborne LiDAR Data Filtering Method
#' Based on Cloth Simulation" Remote Sensing 8(6): 501
classify_ground_csf <- function(las, cloth_resolution = 0.5, rigidness = 2,
                               iterations = 500, classification_threshold = 0.5) {

  logger::log_info("Classifying ground points using CSF algorithm")

  # Apply CSF algorithm
  las <- lidR::classify_ground(las, algorithm = lidR::csf(
    sloop_smooth = TRUE,
    class_threshold = classification_threshold,
    cloth_resolution = cloth_resolution,
    rigidness = rigidness,
    iterations = iterations
  ))

  ground_pct <- sum(las@data$Classification == 2) / nrow(las@data) * 100
  logger::log_info("Ground points: {round(ground_pct, 1)}% of total")

  return(las)
}

#' Classify ground points using PMF algorithm
#'
#' Implements Progressive Morphological Filter (Zhang et al. 2003)
#'
#' @param las LAS object
#' @param ws Window size(s) for morphological operations
#' @param th Elevation threshold(s)
#' @return LAS object with updated classification
#' @export
#' @references
#' Zhang et al. (2003) "A progressive morphological filter for removing
#' nonground measurements from airborne LIDAR data" IEEE TGRS 41(4): 872-882
classify_ground_pmf <- function(las, ws = c(3, 5, 10, 15, 20), th = c(0.5, 1, 1.5, 2, 2.5)) {

  logger::log_info("Classifying ground points using PMF algorithm")

  las <- lidR::classify_ground(las, algorithm = lidR::pmf(
    ws = ws,
    th = th
  ))

  ground_pct <- sum(las@data$Classification == 2) / nrow(las@data) * 100
  logger::log_info("Ground points: {round(ground_pct, 1)}% of total")

  return(las)
}

#' Remove noise and outliers from point cloud
#'
#' Implements statistical outlier removal based on local point density
#'
#' @param las LAS object
#' @param method Method for outlier detection: "sor" (statistical outlier removal)
#'   or "isolated" (isolated voxel filter)
#' @param k Number of neighbors for SOR (default 10)
#' @param m Multiplier for std dev threshold (default 3)
#' @return LAS object with outliers removed
#' @export
remove_noise <- function(las, method = "sor", k = 10, m = 3) {

  logger::log_info("Removing noise using {method} method")
  n_before <- nrow(las@data)

  if (method == "sor") {
    # Statistical Outlier Removal
    las <- lidR::classify_noise(las, lidR::sor(k = k, m = m))

  } else if (method == "isolated") {
    # Isolated voxel filter
    las <- lidR::classify_noise(las, lidR::ivf(res = 5, n = 6))

  } else {
    stop("Unknown noise removal method. Use 'sor' or 'isolated'")
  }

  # Remove classified noise points (class 18)
  las <- lidR::filter_poi(las, Classification != 18)

  n_removed <- n_before - nrow(las@data)
  pct_removed <- n_removed / n_before * 100

  logger::log_info("Removed {n_removed} noise points ({round(pct_removed, 2)}%)")

  return(las)
}

#' Generate digital terrain model (DTM)
#'
#' Creates a DTM from ground-classified points
#'
#' @param las LAS object with ground classification
#' @param res Resolution in meters (default 1m)
#' @param algorithm Algorithm for DTM generation: "tin", "knnidw", or "kriging"
#' @return SpatRaster DTM
#' @export
generate_dtm <- function(las, res = 1, algorithm = "tin") {

  logger::log_info("Generating DTM at {res}m resolution using {algorithm}")

  # Check for ground points
  n_ground <- sum(las@data$Classification == 2)
  if (n_ground == 0) {
    stop("No ground points found. Run classify_ground_* first.")
  }

  # Select algorithm
  alg <- switch(algorithm,
    "tin" = lidR::tin(),
    "knnidw" = lidR::knnidw(k = 10, p = 2),
    "kriging" = lidR::kriging(k = 40),
    stop("Unknown algorithm. Use 'tin', 'knnidw', or 'kriging'")
  )

  # Generate DTM
  dtm <- lidR::rasterize_terrain(las, res = res, algorithm = alg)

  logger::log_info("DTM generated: {paste(dim(dtm), collapse = 'x')} pixels")

  return(dtm)
}

#' Normalize point cloud heights
#'
#' Subtracts DTM from point cloud Z values to get height above ground
#'
#' @param las LAS object
#' @param dtm Optional DTM raster (if NULL, will generate from las)
#' @param algorithm Algorithm for normalization (default "tin")
#' @return LAS object with normalized Z values
#' @export
normalize_height <- function(las, dtm = NULL, algorithm = "tin") {

  logger::log_info("Normalizing point cloud heights")

  if (is.null(dtm)) {
    # Generate DTM on the fly
    las <- lidR::normalize_height(las, algorithm = lidR::tin())
  } else {
    # Use provided DTM
    las <- lidR::normalize_height(las, algorithm = dtm)
  }

  logger::log_info("Height normalization complete. Max height: {round(max(las@data$Z), 1)}m")

  return(las)
}

#' Generate canopy height model (CHM)
#'
#' Creates a raster of maximum vegetation height
#'
#' @param las LAS object (should be height-normalized)
#' @param res Resolution in meters (default 0.5m for detailed analysis)
#' @param algorithm Algorithm: "p2r" (point-to-raster) or "pitfree" (pit-free)
#' @return SpatRaster CHM
#' @export
generate_chm <- function(las, res = 0.5, algorithm = "p2r") {

  logger::log_info("Generating CHM at {res}m resolution")

  if (algorithm == "p2r") {
    chm <- lidR::rasterize_canopy(las, res = res, algorithm = lidR::p2r())

  } else if (algorithm == "pitfree") {
    chm <- lidR::rasterize_canopy(las, res = res, algorithm = lidR::pitfree())

  } else {
    stop("Unknown algorithm. Use 'p2r' or 'pitfree'")
  }

  logger::log_info("CHM generated: max height {round(max(terra::values(chm), na.rm = TRUE), 1)}m")

  return(chm)
}

#' Comprehensive quality control report
#'
#' Generates a detailed quality assessment of lidar data
#'
#' @param las LAS object
#' @param return_report If TRUE, returns report as list; if FALSE, prints to console
#' @return List with quality metrics or prints report
#' @export
quality_control_report <- function(las, return_report = TRUE) {

  logger::log_info("Generating quality control report")

  # Basic statistics
  bbox <- sf::st_bbox(las)
  area_m2 <- (bbox["xmax"] - bbox["xmin"]) * (bbox["ymax"] - bbox["ymin"])

  report <- list(
    # Spatial extent
    extent = list(
      xmin = bbox["xmin"],
      xmax = bbox["xmax"],
      ymin = bbox["ymin"],
      ymax = bbox["ymax"],
      area_m2 = as.numeric(area_m2),
      area_formatted = format_area(area_m2)
    ),

    # Point statistics
    points = list(
      total_points = nrow(las@data),
      point_density = nrow(las@data) / as.numeric(area_m2),
      returns = table(las@data$ReturnNumber),
      multiple_returns_pct = sum(las@data$ReturnNumber > 1) / nrow(las@data) * 100
    ),

    # Height statistics
    height = list(
      min = min(las@data$Z),
      max = max(las@data$Z),
      mean = mean(las@data$Z),
      median = median(las@data$Z),
      sd = sd(las@data$Z)
    ),

    # Classification
    classification = list(
      classes = table(las@data$Classification),
      ground_pct = sum(las@data$Classification == 2) / nrow(las@data) * 100,
      vegetation_pct = sum(las@data$Classification %in% c(3, 4, 5)) / nrow(las@data) * 100
    ),

    # Intensity (if available)
    intensity = if ("Intensity" %in% names(las@data)) {
      list(
        min = min(las@data$Intensity),
        max = max(las@data$Intensity),
        mean = mean(las@data$Intensity),
        median = median(las@data$Intensity)
      )
    } else {
      "Not available"
    },

    # Edge quality
    edge_quality = detect_edge_artifacts(las),

    # CRS
    crs = sf::st_crs(las)$input
  )

  if (!return_report) {
    # Print formatted report
    cat("\n========================================\n")
    cat("   LIDAR QUALITY CONTROL REPORT\n")
    cat("========================================\n\n")

    cat("SPATIAL EXTENT:\n")
    cat(sprintf("  Area: %s\n", report$extent$area_formatted))
    cat(sprintf("  Bounds: X[%.1f, %.1f], Y[%.1f, %.1f]\n",
                report$extent$xmin, report$extent$xmax,
                report$extent$ymin, report$extent$ymax))
    cat(sprintf("  CRS: %s\n\n", report$crs))

    cat("POINT STATISTICS:\n")
    cat(sprintf("  Total points: %s\n", format(report$points$total_points, big.mark = ",")))
    cat(sprintf("  Point density: %.2f pts/m²\n", report$points$point_density))
    cat(sprintf("  Multiple returns: %.1f%%\n\n", report$points$multiple_returns_pct))

    cat("HEIGHT STATISTICS:\n")
    cat(sprintf("  Range: %.2f - %.2f m\n", report$height$min, report$height$max))
    cat(sprintf("  Mean: %.2f m (SD: %.2f)\n", report$height$mean, report$height$sd))
    cat(sprintf("  Median: %.2f m\n\n", report$height$median))

    cat("CLASSIFICATION:\n")
    cat(sprintf("  Ground points: %.1f%%\n", report$classification$ground_pct))
    cat(sprintf("  Vegetation points: %.1f%%\n\n", report$classification$vegetation_pct))

    cat("EDGE QUALITY:\n")
    cat(sprintf("  Edge/Center density ratio: %.2f\n", report$edge_quality$density_ratio))
    cat(sprintf("  Status: %s\n", report$edge_quality$recommendation))

    cat("\n========================================\n\n")

  } else {
    return(report)
  }
}

#' Complete preprocessing pipeline
#'
#' Runs all preprocessing steps in sequence: noise removal, ground classification,
#' normalization, and quality control
#'
#' @param las LAS object or path to LAS file
#' @param ground_method Ground classification method: "csf" or "pmf"
#' @param noise_method Noise removal method: "sor" or "isolated"
#' @param output_dir Optional directory to save processed LAS file
#' @return List with processed LAS, DTM, CHM, and quality report
#' @export
#' @examples
#' \dontrun{
#' result <- preprocess_lidar("path/to/tile.las", output_dir = "processed/")
#' las_clean <- result$las
#' qc_report <- result$quality_report
#' }
preprocess_lidar <- function(las, ground_method = "csf", noise_method = "sor",
                            output_dir = NULL) {

  logger::log_info("Starting complete preprocessing pipeline")

  # Read LAS if path provided
  if (is.character(las)) {
    logger::log_info("Reading LAS file: {las}")
    las <- lidR::readLAS(las)
  }

  # Step 1: Validate CRS
  las <- validate_crs(las)

  # Step 2: Remove noise
  las <- remove_noise(las, method = noise_method)

  # Step 3: Classify ground
  if (ground_method == "csf") {
    las <- classify_ground_csf(las)
  } else if (ground_method == "pmf") {
    las <- classify_ground_pmf(las)
  } else {
    stop("Unknown ground_method. Use 'csf' or 'pmf'")
  }

  # Step 4: Generate DTM
  dtm <- generate_dtm(las, res = 1)

  # Step 5: Normalize heights
  las <- normalize_height(las, dtm = dtm)

  # Step 6: Generate CHM
  chm <- generate_chm(las, res = 0.5)

  # Step 7: Quality control
  qc_report <- quality_control_report(las, return_report = TRUE)

  # Save if output directory specified
  if (!is.null(output_dir)) {
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    # Save normalized LAS
    las_file <- file.path(output_dir, "normalized.las")
    lidR::writeLAS(las, las_file)
    logger::log_info("Saved normalized LAS: {las_file}")

    # Save DTM
    dtm_file <- file.path(output_dir, "dtm.tif")
    terra::writeRaster(dtm, dtm_file, overwrite = TRUE)
    logger::log_info("Saved DTM: {dtm_file}")

    # Save CHM
    chm_file <- file.path(output_dir, "chm.tif")
    terra::writeRaster(chm, chm_file, overwrite = TRUE)
    logger::log_info("Saved CHM: {chm_file}")
  }

  logger::log_info("Preprocessing pipeline complete")

  return(list(
    las = las,
    dtm = dtm,
    chm = chm,
    quality_report = qc_report
  ))
}
