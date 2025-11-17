# =============================================================================
# MODULE 01: OPENDRONEMAP ORTHOMOSAIC GENERATION
# =============================================================================
#
# Purpose: Generate georeferenced orthomosaics, DSM, and point clouds from
#          raw geotagged drone images using OpenDroneMap (ODM)
#
# Inputs:
#   - Raw geotagged drone images (JPG with EXIF GPS data)
#   - Optional: Ground Control Points (GCP) CSV file
#
# Outputs:
#   - Georeferenced orthomosaic (GeoTIFF)
#   - Digital Surface Model - DSM (GeoTIFF)
#   - Point cloud (LAZ format)
#   - Quality assessment report
#
# Methods:
#   - Structure from Motion (SfM) photogrammetry via OpenDroneMap
#   - Multi-View Stereo (MVS) dense reconstruction
#   - Bundle adjustment for geometric accuracy
#
# Runtime: 10 minutes to several hours (depends on image count and quality settings)
#
# References:
#   - OpenDroneMap: https://www.opendronemap.org/
#   - Westoby et al. (2012). 'Structure-from-Motion' photogrammetry:
#     A low-cost, effective tool for geoscience applications.
#     Geomorphology, 179, 300-314.
#
# =============================================================================

# Load required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  terra,      # Raster data handling
  sf,         # Vector data handling
  exifr,      # EXIF metadata extraction
  dplyr,      # Data manipulation
  glue,       # String formatting
  fs,         # File system operations
  jsonlite,   # JSON handling
  progress    # Progress bars
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
    stop("Configuration file not found. Please ensure drone_config.R exists.")
  }
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#' Extract EXIF metadata from drone images
#'
#' @param image_dir Path to directory containing images
#' @return Data frame with EXIF metadata
extract_image_metadata <- function(image_dir) {
  cat("📷 Extracting EXIF metadata from images...\n")

  # Find all image files
  image_files <- list.files(
    image_dir,
    pattern = "\\.(jpg|jpeg|JPG|JPEG)$",
    full.names = TRUE,
    recursive = FALSE
  )

  if (length(image_files) == 0) {
    stop("No image files found in: ", image_dir)
  }

  cat("   Found", length(image_files), "images\n")

  # Extract EXIF data
  tryCatch({
    exif_data <- read_exif(image_files)

    # Check for GPS coordinates
    if (!all(c("GPSLatitude", "GPSLongitude") %in% names(exif_data))) {
      warning("GPS coordinates not found in EXIF data. Images may not be geotagged.")
      has_gps <- FALSE
    } else {
      # Count images with valid GPS
      n_with_gps <- sum(!is.na(exif_data$GPSLatitude) & !is.na(exif_data$GPSLongitude))
      cat("   ", n_with_gps, "/", length(image_files), "images have GPS coordinates\n")
      has_gps <- n_with_gps > 0
    }

    # Extract key metadata
    metadata_summary <- data.frame(
      file = basename(image_files),
      path = image_files,
      latitude = if(has_gps) exif_data$GPSLatitude else NA,
      longitude = if(has_gps) exif_data$GPSLongitude else NA,
      altitude = if("GPSAltitude" %in% names(exif_data)) exif_data$GPSAltitude else NA,
      datetime = exif_data$DateTimeOriginal,
      camera_make = exif_data$Make,
      camera_model = exif_data$Model,
      focal_length = exif_data$FocalLength,
      image_width = exif_data$ImageWidth,
      image_height = exif_data$ImageHeight,
      stringsAsFactors = FALSE
    )

    return(list(
      metadata = metadata_summary,
      has_gps = has_gps,
      n_images = length(image_files)
    ))

  }, error = function(e) {
    stop("Failed to extract EXIF metadata: ", e$message,
         "\nEnsure ExifTool is installed: https://exiftool.org/")
  })
}

#' Calculate image overlap and coverage
#'
#' @param metadata EXIF metadata data frame
#' @return List with overlap statistics
calculate_image_overlap <- function(metadata) {
  cat("📊 Calculating image overlap and coverage...\n")

  if (!all(c("latitude", "longitude", "altitude") %in% names(metadata))) {
    warning("Insufficient GPS data to calculate overlap")
    return(list(estimated_overlap = NA, coverage_area = NA))
  }

  # Remove images without GPS
  valid_gps <- metadata[!is.na(metadata$latitude) & !is.na(metadata$longitude), ]

  if (nrow(valid_gps) < 2) {
    warning("Less than 2 images with GPS data")
    return(list(estimated_overlap = NA, coverage_area = NA))
  }

  # Estimate Ground Sampling Distance (GSD)
  # Formula: GSD (cm) = (sensor_width_mm × altitude_mm × 100) / (focal_length_mm × image_width_pixels)
  # For DJI Mavic (typical): sensor_width ~13mm, focal_length ~24mm

  # Use median altitude
  median_altitude <- median(valid_gps$altitude, na.rm = TRUE)

  # Estimate footprint dimensions (assuming DJI typical specs)
  # This is approximate - actual values depend on camera specs
  footprint_width <- median_altitude * 0.7  # meters
  footprint_height <- median_altitude * 0.5  # meters

  # Calculate distances between consecutive images
  coords <- cbind(valid_gps$longitude, valid_gps$latitude)
  distances <- rep(NA, nrow(coords) - 1)

  for (i in 1:(nrow(coords) - 1)) {
    # Simple Euclidean distance (approximate for small areas)
    # For production, use geosphere::distHaversine() for accuracy
    distances[i] <- sqrt(
      (coords[i+1, 1] - coords[i, 1])^2 +
      (coords[i+1, 2] - coords[i, 2])^2
    ) * 111320  # Convert degrees to meters (approximate at mid-latitudes)
  }

  # Estimate overlap
  median_distance <- median(distances, na.rm = TRUE)
  estimated_overlap <- (1 - median_distance / footprint_width) * 100

  # Estimate survey area using convex hull
  if (nrow(valid_gps) >= 3) {
    coords_sf <- st_as_sf(valid_gps, coords = c("longitude", "latitude"), crs = 4326)
    hull <- st_convex_hull(st_union(coords_sf))
    # Transform to projected CRS for area calculation
    hull_projected <- st_transform(hull, crs = 3857)  # Web Mercator
    coverage_area_m2 <- as.numeric(st_area(hull_projected))
    coverage_area_ha <- coverage_area_m2 / 10000
  } else {
    coverage_area_ha <- NA
  }

  cat("   Estimated overlap:", round(estimated_overlap, 1), "%\n")
  cat("   Estimated coverage:", round(coverage_area_ha, 2), "hectares\n")

  return(list(
    estimated_overlap = estimated_overlap,
    coverage_area_ha = coverage_area_ha,
    n_images = nrow(valid_gps),
    median_altitude = median_altitude,
    median_distance = median_distance
  ))
}

#' Perform quality checks on input images
#'
#' @param metadata EXIF metadata data frame
#' @param quality_checks List of quality check thresholds
#' @return List with check results and warnings
perform_quality_checks <- function(metadata, quality_checks = ODM_QUALITY_CHECKS) {
  cat("🔍 Performing quality checks...\n")

  checks <- list(
    pass = TRUE,
    warnings = c(),
    errors = c()
  )

  # Check 1: Minimum number of images
  if (nrow(metadata) < quality_checks$min_images) {
    checks$errors <- c(checks$errors,
                       glue("Only {nrow(metadata)} images found. ",
                            "Minimum recommended: {quality_checks$min_images}"))
    checks$pass <- FALSE
  }

  # Check 2: GPS data availability
  n_with_gps <- sum(!is.na(metadata$latitude) & !is.na(metadata$longitude))
  gps_percent <- (n_with_gps / nrow(metadata)) * 100

  if (gps_percent < 100) {
    checks$warnings <- c(checks$warnings,
                         glue("Only {gps_percent}% of images have GPS data"))
  }

  if (gps_percent == 0) {
    checks$errors <- c(checks$errors,
                       "No images have GPS coordinates. Geotagging required.")
    checks$pass <- FALSE
  }

  # Check 3: Image overlap
  overlap_stats <- calculate_image_overlap(metadata)

  if (!is.na(overlap_stats$estimated_overlap)) {
    if (overlap_stats$estimated_overlap < quality_checks$min_overlap) {
      checks$warnings <- c(checks$warnings,
                           glue("Estimated overlap ({round(overlap_stats$estimated_overlap, 1)}%) ",
                                "is below recommended minimum ({quality_checks$min_overlap}%)"))
    }
  }

  # Check 4: Camera consistency
  unique_cameras <- unique(paste(metadata$camera_make, metadata$camera_model))
  if (length(unique_cameras) > 1) {
    checks$warnings <- c(checks$warnings,
                         glue("Multiple camera models detected: {paste(unique_cameras, collapse=', ')}"))
  }

  # Check 5: GCP availability warning
  if (quality_checks$alert_if_no_gcp && is.null(GCP_FILE)) {
    checks$warnings <- c(checks$warnings,
                         "No Ground Control Points provided. Absolute accuracy may be lower.")
  }

  # Report results
  if (checks$pass) {
    cat("   ✅ All critical checks passed\n")
  } else {
    cat("   ❌ Critical errors found\n")
  }

  if (length(checks$warnings) > 0) {
    cat("   ⚠️ ", length(checks$warnings), "warnings\n")
  }

  return(c(checks, overlap_stats = list(overlap_stats)))
}

#' Generate ODM command for Docker
#'
#' @param project_dir Project directory path
#' @param params ODM parameters list
#' @return ODM command string
generate_odm_command <- function(project_dir, params = ODM_PARAMS) {
  cat("⚙️  Generating OpenDroneMap command...\n")

  # Base command for Docker
  cmd <- "docker run -ti --rm"

  # Mount volumes
  cmd <- paste(cmd, "-v", glue("{project_dir}:/datasets/project"))

  # ODM image
  cmd <- paste(cmd, "opendronemap/odm")

  # Project name
  cmd <- paste(cmd, "--project-path /datasets project")

  # Add parameters
  if (!is.null(params$feature_quality)) {
    cmd <- paste(cmd, "--feature-quality", params$feature_quality)
  }

  if (!is.null(params$min_num_features)) {
    cmd <- paste(cmd, "--min-num-features", params$min_num_features)
  }

  if (!is.null(params$pc_quality)) {
    cmd <- paste(cmd, "--pc-quality", params$pc_quality)
  }

  if (!is.null(params$mesh_octree_depth)) {
    cmd <- paste(cmd, "--mesh-octree-depth", params$mesh_octree_depth)
  }

  if (!is.null(params$orthophoto_resolution)) {
    cmd <- paste(cmd, "--orthophoto-resolution", params$orthophoto_resolution)
  }

  if (params$dsm) {
    cmd <- paste(cmd, "--dsm")
  }

  if (params$dtm) {
    cmd <- paste(cmd, "--dtm")
  }

  if (params$use_gcp && !is.null(GCP_FILE) && file.exists(GCP_FILE)) {
    cmd <- paste(cmd, "--gcp", GCP_FILE)
  }

  if (!is.null(params$crop)) {
    cmd <- paste(cmd, "--crop", params$crop)
  }

  cat("   ODM command generated\n")

  return(cmd)
}

#' Run OpenDroneMap processing
#'
#' @param image_dir Directory with images
#' @param output_dir Output directory
#' @param use_docker Use Docker version of ODM
#' @return List with processing results
run_odm_processing <- function(image_dir, output_dir, use_docker = TRUE) {
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════════════╗\n")
  cat("║  RUNNING OPENDRONEMAP - ORTHOMOSAIC GENERATION                       ║\n")
  cat("╚══════════════════════════════════════════════════════════════════════╝\n")
  cat("\n")

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Copy images to ODM project structure
  odm_project_dir <- file.path(output_dir, "odm_project")
  odm_images_dir <- file.path(odm_project_dir, "images")

  if (!dir.exists(odm_images_dir)) {
    dir.create(odm_images_dir, recursive = TRUE)
  }

  cat("📁 Copying images to ODM project directory...\n")
  image_files <- list.files(image_dir, pattern = "\\.(jpg|jpeg|JPG|JPEG)$",
                            full.names = TRUE)
  file.copy(image_files, odm_images_dir)
  cat("   Copied", length(image_files), "images\n")

  # Copy GCP file if provided
  if (!is.null(GCP_FILE) && file.exists(GCP_FILE)) {
    file.copy(GCP_FILE, file.path(odm_project_dir, "gcp_list.txt"))
    cat("   Copied GCP file\n")
  }

  # Generate and run ODM command
  odm_cmd <- generate_odm_command(odm_project_dir, ODM_PARAMS)

  cat("\n🚀 Starting OpenDroneMap processing...\n")
  cat("   This may take 10 minutes to several hours depending on:\n")
  cat("   - Number of images\n")
  cat("   - Image resolution\n")
  cat("   - Quality settings\n")
  cat("   - Computer performance\n\n")

  cat("ODM Command:\n")
  cat(odm_cmd, "\n\n")

  # Note: In production, you would actually run the command here
  # For this template, we'll simulate the process
  cat("⚠️  Note: To run ODM, execute the command above in your terminal\n")
  cat("   Or uncomment the system() call below in the code\n\n")

  # Uncomment to actually run ODM:
  # system(odm_cmd)

  cat("📋 Expected ODM outputs:\n")
  cat("   - odm_orthophoto/odm_orthophoto.tif (Orthomosaic)\n")
  cat("   - odm_dem/dsm.tif (Digital Surface Model)\n")
  cat("   - odm_georeferencing/odm_georeferenced_model.laz (Point cloud)\n")

  return(list(
    project_dir = odm_project_dir,
    command = odm_cmd,
    expected_outputs = list(
      orthomosaic = file.path(odm_project_dir, "odm_orthophoto/odm_orthophoto.tif"),
      dsm = file.path(odm_project_dir, "odm_dem/dsm.tif"),
      point_cloud = file.path(odm_project_dir, "odm_georeferencing/odm_georeferenced_model.laz")
    )
  ))
}

#' Validate ODM outputs
#'
#' @param odm_outputs Expected output paths
#' @return Validation results
validate_odm_outputs <- function(odm_outputs) {
  cat("\n✅ Validating ODM outputs...\n")

  results <- list(
    orthomosaic_exists = file.exists(odm_outputs$orthomosaic),
    dsm_exists = file.exists(odm_outputs$dsm),
    point_cloud_exists = file.exists(odm_outputs$point_cloud),
    all_valid = FALSE
  )

  if (results$orthomosaic_exists) {
    cat("   ✓ Orthomosaic generated\n")

    # Check raster properties
    ortho <- rast(odm_outputs$orthomosaic)
    cat("     - Dimensions:", paste(dim(ortho), collapse = " x "), "\n")
    cat("     - Resolution:", paste(round(res(ortho), 4), collapse = " x "), "\n")
    cat("     - CRS:", crs(ortho, describe = TRUE)$name, "\n")
    cat("     - Extent:", paste(round(as.vector(ext(ortho)), 2), collapse = ", "), "\n")
  } else {
    cat("   ✗ Orthomosaic not found\n")
  }

  if (results$dsm_exists) {
    cat("   ✓ DSM generated\n")
  } else {
    cat("   ✗ DSM not found\n")
  }

  if (results$point_cloud_exists) {
    cat("   ✓ Point cloud generated\n")
  } else {
    cat("   ⚠️  Point cloud not found (optional)\n")
  }

  results$all_valid <- results$orthomosaic_exists && results$dsm_exists

  return(results)
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================

#' Main function to run complete ODM workflow
#'
#' @export
run_odm_workflow <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(" MODULE 01: OPENDRONEMAP ORTHOMOSAIC GENERATION\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("\n")

  # Validate configuration
  if (exists("validate_config")) {
    validate_config()
  }

  # Extract image metadata
  metadata_results <- extract_image_metadata(IMAGE_DIR)

  # Perform quality checks
  quality_results <- perform_quality_checks(metadata_results$metadata)

  # Display warnings
  if (length(quality_results$warnings) > 0) {
    cat("\n⚠️  WARNINGS:\n")
    for (w in quality_results$warnings) {
      cat("   •", w, "\n")
    }
  }

  # Display errors
  if (length(quality_results$errors) > 0) {
    cat("\n❌ ERRORS:\n")
    for (e in quality_results$errors) {
      cat("   •", e, "\n")
    }

    if (!quality_results$pass) {
      stop("Quality checks failed. Please address errors above.")
    }
  }

  # Save quality report
  quality_report_path <- "outputs/reports/01_odm_quality_report.txt"
  dir.create(dirname(quality_report_path), recursive = TRUE, showWarnings = FALSE)

  sink(quality_report_path)
  cat("OpenDroneMap Quality Assessment Report\n")
  cat("Generated:", as.character(Sys.time()), "\n")
  cat("Project:", PROJECT_NAME, "\n\n")
  cat("=" , rep("=", 70), "\n\n", sep = "")
  cat("IMAGE SUMMARY\n")
  cat("  Total images:", metadata_results$n_images, "\n")
  cat("  Images with GPS:", sum(!is.na(metadata_results$metadata$latitude)), "\n")
  cat("  Camera:", unique(paste(metadata_results$metadata$camera_make,
                                 metadata_results$metadata$camera_model))[1], "\n\n")
  if (!is.na(quality_results$overlap_stats$estimated_overlap)) {
    cat("COVERAGE\n")
    cat("  Estimated overlap:", round(quality_results$overlap_stats$estimated_overlap, 1), "%\n")
    cat("  Coverage area:", round(quality_results$overlap_stats$coverage_area_ha, 2), "ha\n")
    cat("  Median altitude:", round(quality_results$overlap_stats$median_altitude, 1), "m\n\n")
  }
  sink()

  cat("\n📄 Quality report saved to:", quality_report_path, "\n")

  # Run ODM processing
  odm_results <- run_odm_processing(
    image_dir = IMAGE_DIR,
    output_dir = OUTPUT_DIRS$orthomosaics
  )

  # Save ODM configuration
  config_path <- file.path(odm_results$project_dir, "processing_config.json")
  write_json(
    list(
      project_name = PROJECT_NAME,
      survey_date = SURVEY_DATE,
      location = LOCATION_NAME,
      n_images = metadata_results$n_images,
      odm_params = ODM_PARAMS,
      processing_date = as.character(Sys.time())
    ),
    config_path,
    pretty = TRUE
  )

  cat("\n✅ Module 01 complete!\n")
  cat("\nNext step: Run Module 02 (Vegetation Classification)\n")
  cat("   source('R/02_vegetation_classification.R')\n\n")

  return(list(
    metadata = metadata_results,
    quality = quality_results,
    odm_results = odm_results
  ))
}

# =============================================================================
# RUN MODULE (if sourced directly)
# =============================================================================

if (!interactive() || exists("RUN_MODULE_01")) {
  results <- run_odm_workflow()
}
