# =============================================================================
# CREATE TEST CONFIGURATION
# =============================================================================
#
# Creates an optimized configuration file for testing with the Bellus dataset
#
# This configuration is tuned for fast processing while maintaining quality
#
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  CREATING TEST CONFIGURATION                                         ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Check if test images exist
test_image_dir <- "data_input/images/test_bellus"

if (!dir.exists(test_image_dir)) {
  cat("⚠️  Test image directory not found:", test_image_dir, "\n")
  cat("   Run download_test_data.R first\n\n")

  response <- readline(prompt = "Create config anyway? (y/n): ")

  if (tolower(response) != "y") {
    cat("\nCancelled.\n\n")
    return(invisible(NULL))
  }
}

# Configuration content
config_content <- '# =============================================================================
# DRONE PIPELINE - TEST CONFIGURATION
# =============================================================================
#
# Optimized configuration for testing with the Bellus sample dataset
# This config uses faster settings while maintaining reasonable quality
#
# Dataset: OpenDroneMap Bellus sample (77 images, ~1.8 hectares)
# Expected processing time: 30-45 minutes
#
# =============================================================================

# =============================================================================
# PROJECT METADATA
# =============================================================================

PROJECT_NAME <- "Test_Bellus_Dataset"
SURVEY_DATE <- "2023-08-15"
LOCATION_NAME <- "Bellus Park - Test Area"
SURVEY_PURPOSE <- "Pipeline testing and validation"
COMMUNITY_NAME <- "Test User"
SURVEYOR_NAME <- Sys.info()["user"]

# =============================================================================
# INPUT PATHS
# =============================================================================

IMAGE_DIR <- "data_input/images/test_bellus"
GCP_FILE <- NULL  # Bellus dataset has no GCPs
TRAINING_SAMPLES <- NULL  # Using unsupervised classification
PREVIOUS_ORTHOMOSAIC <- NULL

# =============================================================================
# COORDINATE REFERENCE SYSTEM
# =============================================================================

OUTPUT_CRS <- "EPSG:32610"  # UTM Zone 10N (appropriate for Bellus location)

# =============================================================================
# OPENDRONEMAP SETTINGS (Optimized for speed)
# =============================================================================

ODM_PATH <- "docker"

ODM_PARAMS <- list(
  feature_quality = "medium",      # Faster than "high"
  min_num_features = 8000,
  use_opensfm_dense = TRUE,
  pc_quality = "medium",           # Faster than "high"
  mesh_octree_depth = 10,          # Slightly lower for speed
  dsm = TRUE,
  dtm = FALSE,
  orthophoto_resolution = 3,       # 3 cm GSD (good balance)
  use_gcp = FALSE,
  auto_boundary = TRUE,
  crop = 2
)

ODM_QUALITY_CHECKS <- list(
  min_images = 10,
  min_overlap = 60,
  max_gsd = 5,
  alert_if_no_gcp = FALSE  # We know test data has no GCPs
)

# =============================================================================
# VEGETATION CLASSIFICATION
# =============================================================================

CLASSIFICATION_METHOD <- "unsupervised"
N_CLASSES_UNSUPERVISED <- 5

CLASS_NAMES <- c(
  "Bare_Ground_Paths",
  "Herbaceous",
  "Shrubland",
  "Tree_Canopy",
  "Shadow_Water"
)

SPECTRAL_INDICES <- c("NDVI", "ExG", "VARI", "GLI")

RF_PARAMS <- list(
  ntree = 300,          # Reduced from 500 for speed
  mtry = NULL,
  importance = TRUE,
  nodesize = 5,
  seed = 42
)

VALIDATION_SPLIT <- 0.3

# =============================================================================
# TREE/SHRUB DETECTION
# =============================================================================

MIN_TREE_HEIGHT <- 2.0
MAX_TREE_HEIGHT <- 30.0
TREE_DETECTION_METHOD <- "watershed"

WATERSHED_PARAMS <- list(
  tolerance = 0.5,
  ext = 2
)

LOCAL_MAXIMA_PARAMS <- list(
  ws = 5,
  hmin = MIN_TREE_HEIGHT
)

CROWN_PARAMS <- list(
  min_crown_area = 1,
  max_crown_area = 100
)

# =============================================================================
# CHANGE DETECTION
# =============================================================================

ENABLE_CHANGE_DETECTION <- FALSE  # No previous survey for test

CHANGE_THRESHOLDS <- list(
  ndvi_change = 0.15,
  height_change = 0.5,
  cover_change = 10
)

CHANGE_CLASSES <- c(
  "Vegetation_Gain",
  "Vegetation_Loss",
  "Height_Increase",
  "Height_Decrease",
  "Stable"
)

# =============================================================================
# SUMMARY STATISTICS
# =============================================================================

AREA_UNIT <- "hectares"

SUMMARY_STATS <- list(
  total_area = TRUE,
  vegetation_cover_by_class = TRUE,
  tree_density = TRUE,
  mean_vegetation_height = TRUE,
  max_vegetation_height = TRUE,
  change_statistics = ENABLE_CHANGE_DETECTION
)

# =============================================================================
# REPORT GENERATION
# =============================================================================

REPORT_FORMAT <- c("PDF", "HTML")
REPORT_LANGUAGE <- "english"
INCLUDE_INTERACTIVE_MAP <- TRUE

MAP_LAYERS <- list(
  orthomosaic = TRUE,
  classification = TRUE,
  tree_locations = TRUE,
  change_map = ENABLE_CHANGE_DETECTION,
  survey_boundary = TRUE
)

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

REPORT_FORMATTING <- list(
  title_page = TRUE,
  table_of_contents = TRUE,
  page_numbers = TRUE,
  figure_captions = TRUE,
  table_captions = TRUE,
  north_arrow = TRUE,
  scale_bar = TRUE,
  logo_path = NULL
)

# =============================================================================
# PERFORMANCE SETTINGS
# =============================================================================

MAX_CORES <- NULL  # Use all available minus 1

MEMORY_SETTINGS <- list(
  max_ram_gb = 8,
  downsample_large_rasters = FALSE,  # Test dataset is small enough
  downsample_factor = 2,
  use_temp_files = TRUE
)

PROCESSING_EXTENT <- NULL  # Process entire area

# =============================================================================
# OUTPUT SETTINGS
# =============================================================================

OUTPUT_FORMATS <- list(
  geotiff_compression = "LZW",
  shapefile_encoding = "UTF-8",
  csv_decimal = ".",
  csv_separator = ","
)

FILE_NAMING <- "survey_date"
CUSTOM_PREFIX <- NULL

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
# SCIENTIFIC RIGOR
# =============================================================================

INCLUDE_UNCERTAINTY <- TRUE
VALIDATION_DATA <- NULL
CITATION_STYLE <- "APA"
DOCUMENT_ASSUMPTIONS <- TRUE
DOCUMENT_LIMITATIONS <- TRUE

# =============================================================================
# BONUS FEATURES
# =============================================================================

GEE_INTEGRATION <- FALSE
GEE_SENTINEL2_DATE <- NULL
SPECIES_MODELS <- FALSE
TARGET_SPECIES <- NULL
HABITAT_SUITABILITY <- FALSE
WILDLIFE_SPECIES <- NULL
CARBON_ESTIMATION <- FALSE
ALLOMETRIC_EQUATIONS <- NULL

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

VERBOSE <- TRUE
SAVE_INTERMEDIATE <- FALSE

ERROR_HANDLING <- list(
  stop_on_error = FALSE,
  log_errors = TRUE,
  error_log_path = "outputs/error_log.txt"
)

# =============================================================================
# AUTO-GENERATED PATHS
# =============================================================================

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
# SESSION INFO
# =============================================================================

CONFIG_VERSION <- "1.0.0-TEST"
CONFIG_DATE <- Sys.Date()

# Print configuration summary
print_config_summary <- function() {
  cat("\\n")
  cat("╔══════════════════════════════════════════════════════════════════════╗\\n")
  cat("║  TEST CONFIGURATION SUMMARY                                          ║\\n")
  cat("╚══════════════════════════════════════════════════════════════════════╝\\n")
  cat("\\n")
  cat("📋 PROJECT: ", PROJECT_NAME, "\\n")
  cat("📂 IMAGES:  ", IMAGE_DIR, "\\n")
  cat("⚙️  METHOD:  ", CLASSIFICATION_METHOD, "classification\\n")
  cat("🌲 TREES:   ", TREE_DETECTION_METHOD, "detection\\n")
  cat("📊 OUTPUTS: ", paste(REPORT_FORMAT, collapse = ", "), "\\n")
  cat("\\n")
}

# Validation function
validate_config <- function() {
  errors <- c()
  warnings <- c()

  if (!dir.exists(IMAGE_DIR)) {
    errors <- c(errors, paste("Image directory does not exist:", IMAGE_DIR))
  } else {
    n_images <- length(list.files(IMAGE_DIR, pattern = "\\\\.(jpg|jpeg|JPG|JPEG)$"))
    if (n_images == 0) {
      errors <- c(errors, "No images found in IMAGE_DIR")
    }
  }

  if (length(errors) > 0) {
    cat("\\n❌ CONFIGURATION ERRORS:\\n")
    for (e in errors) cat("  •", e, "\\n")
    stop("Configuration validation failed")
  }

  if (length(warnings) > 0) {
    cat("\\n⚠️  WARNINGS:\\n")
    for (w in warnings) cat("  •", w, "\\n")
  }

  cat("\\n✅ Test configuration validated!\\n\\n")

  return(list(valid = TRUE, errors = errors, warnings = warnings))
}

if (interactive() && VERBOSE) {
  print_config_summary()
}
'

# Write configuration file
config_path <- "config/drone_config.R"

# Backup existing config if present
if (file.exists(config_path)) {
  backup_path <- paste0(config_path, ".backup_", format(Sys.time(), "%Y%m%d_%H%M%S"))
  file.copy(config_path, backup_path)
  cat("✓ Backed up existing config to:", backup_path, "\n")
}

# Write new test config
writeLines(config_content, config_path)

cat("✓ Created test configuration:", config_path, "\n")
cat("\nTest configuration created successfully!\n\n")

cat("Next steps:\n")
cat("1. Review config: config/drone_config.R\n")
cat("2. Validate setup: source('tests/validate_test_setup.R')\n")
cat("3. Run pipeline: source('drone_pipeline_main.R')\n\n")
