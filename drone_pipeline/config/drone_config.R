# =============================================================================
# DRONE ORTHOMOSAIC TO ECOLOGICAL METRICS PIPELINE
# Configuration File
# =============================================================================
#
# This file contains all user-adjustable parameters for the drone processing
# pipeline. Edit values below according to your project needs.
#
# For Indigenous community projects in Canada, this workflow provides
# scientifically defensible ecological metrics from drone imagery.
#
# =============================================================================

# =============================================================================
# PROJECT METADATA
# =============================================================================

PROJECT_NAME <- "Example_Drone_Survey"
SURVEY_DATE <- "2024-01-15"
LOCATION_NAME <- "Traditional Berry Harvesting Area"
SURVEY_PURPOSE <- "Baseline vegetation mapping for restoration monitoring"
COMMUNITY_NAME <- "Example Indigenous Community"
SURVEYOR_NAME <- "John Doe"

# =============================================================================
# INPUT PATHS
# =============================================================================

# Path to raw geotagged drone images (JPG with EXIF data)
IMAGE_DIR <- "data_input/images"

# Optional: Path to Ground Control Points (GCP) CSV file
# Format: gcp_id, latitude, longitude, elevation_m
# Set to NULL if no GCPs available
GCP_FILE <- NULL  # "data_input/gcp/ground_control_points.csv"

# Optional: Path to training samples for classification (shapefile)
# Set to NULL for unsupervised classification
TRAINING_SAMPLES <- NULL  # "data_input/training/training_polygons.shp"

# For multi-temporal analysis: path to previous survey orthomosaic
PREVIOUS_ORTHOMOSAIC <- NULL  # "data_input/previous_surveys/2023_orthomosaic.tif"

# =============================================================================
# COORDINATE REFERENCE SYSTEM (CRS)
# =============================================================================

# Output CRS (EPSG code)
# Default: EPSG:4326 (WGS84 lat/long)
# Canadian examples:
#   - EPSG:3005 (BC Albers)
#   - EPSG:3157 (NAD83(CSRS) / UTM zone 10N)
#   - EPSG:3153 (NAD83(CSRS) / UTM zone 7N)
OUTPUT_CRS <- "EPSG:4326"

# =============================================================================
# OPENDRONEMAP (ODM) SETTINGS
# =============================================================================

# Path to ODM executable (if installed locally)
# Set to "docker" to use Docker version
# Set to "webodm" to use WebODM API
ODM_PATH <- "docker"

# ODM processing parameters
ODM_PARAMS <- list(
  # Feature quality for matching (ultra, high, medium, low, lowest)
  feature_quality = "high",

  # Minimum number of features per image
  min_num_features = 10000,

  # Use OpenSfM for dense matching
  use_opensfm_dense = TRUE,

  # Point cloud quality (ultra, high, medium, low, lowest)
  pc_quality = "medium",

  # Mesh octree depth (increase for more detail, but slower)
  mesh_octree_depth = 11,

  # Generate Digital Surface Model (DSM)
  dsm = TRUE,

  # Generate Digital Terrain Model (DTM)
  dtm = FALSE,  # Usually not needed for vegetation

  # Orthophoto resolution (cm/pixel) - NULL for auto
  orthophoto_resolution = 2,  # 2 cm GSD

  # Use GCPs if available
  use_gcp = !is.null(GCP_FILE),

  # Auto boundary detection
  auto_boundary = TRUE,

  # Crop orthophoto to survey area
  crop = 2  # 2m buffer
)

# Quality checking thresholds
ODM_QUALITY_CHECKS <- list(
  min_images = 10,           # Minimum images required
  min_overlap = 60,          # Minimum overlap percentage
  max_gsd = 5,               # Maximum ground sampling distance (cm)
  alert_if_no_gcp = TRUE     # Warn if no GCPs provided
)

# =============================================================================
# VEGETATION CLASSIFICATION SETTINGS
# =============================================================================

# Classification method: "supervised" or "unsupervised"
CLASSIFICATION_METHOD <- "unsupervised"  # Change to "supervised" if training data available

# Number of classes for unsupervised classification (k-means)
N_CLASSES_UNSUPERVISED <- 5

# Class names for supervised classification (must match training data)
CLASS_NAMES <- c(
  "Forest_Woodland",
  "Shrubland",
  "Herbaceous_Vegetation",
  "Bare_Ground_Rock",
  "Water"
)

# Spectral indices to calculate
SPECTRAL_INDICES <- c(
  "NDVI",  # Normalized Difference Vegetation Index
  "ExG",   # Excess Green
  "VARI",  # Visible Atmospherically Resistant Index
  "GLI"    # Green Leaf Index
)

# Random Forest parameters (for supervised classification)
RF_PARAMS <- list(
  ntree = 500,           # Number of trees
  mtry = NULL,           # Number of variables at each split (NULL = auto)
  importance = TRUE,     # Calculate variable importance
  nodesize = 5,          # Minimum node size
  seed = 42              # Random seed for reproducibility
)

# Accuracy assessment (if training data provided)
VALIDATION_SPLIT <- 0.3  # 30% for validation

# =============================================================================
# TREE/SHRUB DETECTION SETTINGS
# =============================================================================

# Minimum vegetation height threshold (meters)
MIN_TREE_HEIGHT <- 2.0

# Maximum vegetation height (meters) - for filtering errors
MAX_TREE_HEIGHT <- 50.0

# Tree detection method: "watershed" or "local_maxima"
TREE_DETECTION_METHOD <- "watershed"

# Watershed segmentation parameters
WATERSHED_PARAMS <- list(
  tolerance = 0.5,       # Tolerance for local maxima detection
  ext = 2                # Neighborhood size for smoothing
)

# Local maxima parameters
LOCAL_MAXIMA_PARAMS <- list(
  ws = 5,                # Window size (odd number)
  hmin = MIN_TREE_HEIGHT # Minimum height
)

# Crown delineation
CROWN_PARAMS <- list(
  min_crown_area = 1,    # Minimum crown area (m²)
  max_crown_area = 100   # Maximum crown area (m²)
)

# =============================================================================
# CHANGE DETECTION SETTINGS (Multi-temporal)
# =============================================================================

# Enable change detection (requires PREVIOUS_ORTHOMOSAIC)
ENABLE_CHANGE_DETECTION <- !is.null(PREVIOUS_ORTHOMOSAIC)

# Change detection thresholds
CHANGE_THRESHOLDS <- list(
  ndvi_change = 0.15,      # NDVI change threshold
  height_change = 0.5,     # Height change threshold (m)
  cover_change = 10        # Vegetation cover change (%)
)

# Change classification
CHANGE_CLASSES <- c(
  "Vegetation_Gain",
  "Vegetation_Loss",
  "Height_Increase",
  "Height_Decrease",
  "Stable"
)

# =============================================================================
# SUMMARY STATISTICS SETTINGS
# =============================================================================

# Area unit for reporting (ha or acres)
AREA_UNIT <- "hectares"

# Statistics to calculate
SUMMARY_STATS <- list(
  total_area = TRUE,
  vegetation_cover_by_class = TRUE,
  tree_density = TRUE,
  mean_vegetation_height = TRUE,
  max_vegetation_height = TRUE,
  change_statistics = ENABLE_CHANGE_DETECTION
)

# =============================================================================
# REPORT GENERATION SETTINGS
# =============================================================================

# Report format (PDF, HTML, or both)
REPORT_FORMAT <- c("PDF", "HTML")

# Report language (for plain language descriptions)
REPORT_LANGUAGE <- "english"  # Future: "cree", "ojibwe", etc.

# Include interactive map in HTML report
INCLUDE_INTERACTIVE_MAP <- TRUE

# Map layers to include
MAP_LAYERS <- list(
  orthomosaic = TRUE,
  classification = TRUE,
  tree_locations = TRUE,
  change_map = ENABLE_CHANGE_DETECTION,
  survey_boundary = TRUE
)

# Report sections to include
REPORT_SECTIONS <- list(
  executive_summary = TRUE,
  methodology = TRUE,
  survey_metadata = TRUE,
  orthomosaic_overview = TRUE,
  classification_results = TRUE,
  tree_detection_results = TRUE,
  change_detection_results = ENABLE_CHANGE_DETECTION,
  summary_statistics = TRUE,
  recommendations = TRUE,
  appendix_technical = TRUE
)

# Professional formatting
REPORT_FORMATTING <- list(
  title_page = TRUE,
  table_of_contents = TRUE,
  page_numbers = TRUE,
  figure_captions = TRUE,
  table_captions = TRUE,
  north_arrow = TRUE,
  scale_bar = TRUE,
  logo_path = NULL  # Path to community/organization logo
)

# =============================================================================
# PERFORMANCE SETTINGS
# =============================================================================

# Maximum number of cores for parallel processing
# NULL = use all available cores minus 1
MAX_CORES <- NULL

# Memory management
MEMORY_SETTINGS <- list(
  max_ram_gb = 8,              # Maximum RAM to use (GB)
  downsample_large_rasters = TRUE,  # Downsample if memory constrained
  downsample_factor = 2,       # Factor for downsampling
  use_temp_files = TRUE        # Use temporary files for large objects
)

# Processing extent (for testing on subset)
# NULL = process entire survey area
# c(xmin, xmax, ymin, ymax) = crop to bounding box
PROCESSING_EXTENT <- NULL

# =============================================================================
# OUTPUT SETTINGS
# =============================================================================

# Output file formats
OUTPUT_FORMATS <- list(
  geotiff_compression = "LZW",  # Compression for GeoTIFFs
  shapefile_encoding = "UTF-8", # Character encoding
  csv_decimal = ".",            # Decimal separator
  csv_separator = ","           # Column separator
)

# Output file naming convention
# Options: "timestamp", "survey_date", "custom"
FILE_NAMING <- "survey_date"
CUSTOM_PREFIX <- NULL  # Use if FILE_NAMING = "custom"

# Outputs to generate
GENERATE_OUTPUTS <- list(
  orthomosaic_geotiff = TRUE,
  dsm_geotiff = TRUE,
  chm_geotiff = TRUE,
  classification_geotiff = TRUE,
  tree_locations_shapefile = TRUE,
  tree_locations_csv = TRUE,
  tree_metrics_csv = TRUE,
  change_map_geotiff = ENABLE_CHANGE_DETECTION,
  change_areas_shapefile = ENABLE_CHANGE_DETECTION,
  survey_boundary_shapefile = TRUE,
  summary_statistics_csv = TRUE,
  interactive_html_map = INCLUDE_INTERACTIVE_MAP,
  pdf_report = "PDF" %in% REPORT_FORMAT,
  html_report = "HTML" %in% REPORT_FORMAT
)

# =============================================================================
# SCIENTIFIC RIGOR SETTINGS
# =============================================================================

# Include uncertainty metrics
INCLUDE_UNCERTAINTY <- TRUE

# Validation against known standards (if test data available)
VALIDATION_DATA <- NULL  # Path to validation dataset

# Citation style for methods
CITATION_STYLE <- "APA"  # APA, MLA, or Chicago

# Document assumptions in report
DOCUMENT_ASSUMPTIONS <- TRUE

# Document limitations in report
DOCUMENT_LIMITATIONS <- TRUE

# =============================================================================
# BONUS FEATURES (Optional)
# =============================================================================

# Integration with Google Earth Engine for regional context
GEE_INTEGRATION <- FALSE
GEE_SENTINEL2_DATE <- NULL  # Date for Sentinel-2 comparison

# Species-specific models (requires additional data)
SPECIES_MODELS <- FALSE
TARGET_SPECIES <- NULL

# Habitat suitability scoring
HABITAT_SUITABILITY <- FALSE
WILDLIFE_SPECIES <- NULL  # c("grizzly_bear", "woodland_caribou")

# Carbon stock estimation from tree metrics
CARBON_ESTIMATION <- FALSE
ALLOMETRIC_EQUATIONS <- NULL  # Path to species-specific equations

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

# Verbose logging
VERBOSE <- TRUE

# Save intermediate outputs for debugging
SAVE_INTERMEDIATE <- FALSE

# Error handling behavior
ERROR_HANDLING <- list(
  stop_on_error = FALSE,      # Continue processing if non-critical error
  log_errors = TRUE,          # Log errors to file
  error_log_path = "outputs/error_log.txt"
)

# =============================================================================
# VALIDATION AND WARNINGS
# =============================================================================

# Check configuration validity
validate_config <- function() {
  errors <- c()
  warnings <- c()

  # Check required paths exist
  if (!dir.exists(IMAGE_DIR)) {
    errors <- c(errors, paste("Image directory does not exist:", IMAGE_DIR))
  }

  # Check for minimum images
  if (dir.exists(IMAGE_DIR)) {
    n_images <- length(list.files(IMAGE_DIR, pattern = "\\.(jpg|jpeg|JPG|JPEG)$"))
    if (n_images < ODM_QUALITY_CHECKS$min_images) {
      warnings <- c(warnings,
                    paste("Only", n_images, "images found. Minimum recommended:",
                          ODM_QUALITY_CHECKS$min_images))
    }
  }

  # Check GCP file if specified
  if (!is.null(GCP_FILE) && !file.exists(GCP_FILE)) {
    errors <- c(errors, paste("GCP file does not exist:", GCP_FILE))
  }

  # Check training samples if supervised classification
  if (CLASSIFICATION_METHOD == "supervised" && is.null(TRAINING_SAMPLES)) {
    errors <- c(errors, "Supervised classification requires TRAINING_SAMPLES path")
  }

  # Check previous orthomosaic for change detection
  if (ENABLE_CHANGE_DETECTION && !file.exists(PREVIOUS_ORTHOMOSAIC)) {
    errors <- c(errors, paste("Previous orthomosaic not found:", PREVIOUS_ORTHOMOSAIC))
  }

  # Report results
  if (length(errors) > 0) {
    cat("\n❌ CONFIGURATION ERRORS:\n")
    for (e in errors) cat("  •", e, "\n")
    stop("Configuration validation failed. Please fix errors above.")
  }

  if (length(warnings) > 0) {
    cat("\n⚠️  CONFIGURATION WARNINGS:\n")
    for (w in warnings) cat("  •", w, "\n")
  }

  cat("\n✅ Configuration validated successfully!\n\n")

  return(list(valid = TRUE, errors = errors, warnings = warnings))
}

# =============================================================================
# AUTO-GENERATED PATHS (DO NOT EDIT)
# =============================================================================

# These paths are automatically generated based on above settings
OUTPUT_DIRS <- list(
  orthomosaics = "data_processed/orthomosaics",
  dsm = "data_processed/dsm",
  point_clouds = "data_processed/point_clouds",
  classifications = "data_processed/classifications",
  tree_detections = "data_processed/tree_detections",
  change_detection = "data_processed/change_detection",
  geotiff = "outputs/geotiff",
  shapefiles = "outputs/shapefiles",
  csv = "outputs/csv",
  reports = "outputs/reports",
  maps = "outputs/maps"
)

# =============================================================================
# SESSION INFO (Auto-populated at runtime)
# =============================================================================

CONFIG_VERSION <- "1.0.0"
CONFIG_DATE <- Sys.Date()

# Print configuration summary
print_config_summary <- function() {
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════════════╗\n")
  cat("║  DRONE ORTHOMOSAIC TO ECOLOGICAL METRICS PIPELINE                    ║\n")
  cat("║  Configuration Summary                                               ║\n")
  cat("╚══════════════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  cat("📋 PROJECT INFORMATION\n")
  cat("   Name:", PROJECT_NAME, "\n")
  cat("   Date:", SURVEY_DATE, "\n")
  cat("   Location:", LOCATION_NAME, "\n")
  cat("   Purpose:", SURVEY_PURPOSE, "\n")
  cat("\n")
  cat("📂 INPUT DATA\n")
  cat("   Images:", IMAGE_DIR, "\n")
  if (dir.exists(IMAGE_DIR)) {
    n_img <- length(list.files(IMAGE_DIR, pattern = "\\.(jpg|jpeg|JPG|JPEG)$"))
    cat("   Image count:", n_img, "\n")
  }
  cat("   GCPs:", ifelse(is.null(GCP_FILE), "Not provided", GCP_FILE), "\n")
  cat("   Training data:", ifelse(is.null(TRAINING_SAMPLES), "Not provided", TRAINING_SAMPLES), "\n")
  cat("\n")
  cat("⚙️  PROCESSING SETTINGS\n")
  cat("   Classification:", CLASSIFICATION_METHOD, "\n")
  cat("   Tree detection:", TREE_DETECTION_METHOD, "\n")
  cat("   Change detection:", ifelse(ENABLE_CHANGE_DETECTION, "Enabled", "Disabled"), "\n")
  cat("   Min tree height:", MIN_TREE_HEIGHT, "m\n")
  cat("\n")
  cat("📊 OUTPUT FORMATS\n")
  cat("   Report:", paste(REPORT_FORMAT, collapse = ", "), "\n")
  cat("   Interactive map:", ifelse(INCLUDE_INTERACTIVE_MAP, "Yes", "No"), "\n")
  cat("   CRS:", OUTPUT_CRS, "\n")
  cat("\n")
}

# Print configuration on load
if (interactive() && VERBOSE) {
  print_config_summary()
}
