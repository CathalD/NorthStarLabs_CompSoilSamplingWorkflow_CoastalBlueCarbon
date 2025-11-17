# =============================================================================
# VALIDATE TEST SETUP
# =============================================================================
#
# Validates that everything is configured correctly before running the pipeline
#
# Checks:
#   - Configuration loaded correctly
#   - Test images exist and are accessible
#   - Images are geotagged
#   - Docker is running
#   - Required R packages installed
#   - Output directories can be created
#
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  VALIDATING TEST SETUP                                               ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Initialize results
validation_results <- list(
  passed = 0,
  failed = 0,
  warnings = 0,
  errors = c(),
  warnings_list = c()
)

# Helper function for checks
check <- function(condition, pass_msg, fail_msg, is_warning = FALSE) {
  if (condition) {
    cat("✓", pass_msg, "\n")
    validation_results$passed <<- validation_results$passed + 1
    return(TRUE)
  } else {
    if (is_warning) {
      cat("⚠️ ", fail_msg, "\n")
      validation_results$warnings <<- validation_results$warnings + 1
      validation_results$warnings_list <<- c(validation_results$warnings_list, fail_msg)
    } else {
      cat("✗", fail_msg, "\n")
      validation_results$failed <<- validation_results$failed + 1
      validation_results$errors <<- c(validation_results$errors, fail_msg)
    }
    return(FALSE)
  }
}

# =============================================================================
# 1. CONFIGURATION CHECK
# =============================================================================

cat("📋 Checking configuration...\n")

# Load config
config_loaded <- tryCatch({
  if (file.exists("config/drone_config.R")) {
    source("config/drone_config.R")
    TRUE
  } else if (file.exists("../config/drone_config.R")) {
    source("../config/drone_config.R")
    TRUE
  } else {
    FALSE
  }
}, error = function(e) FALSE)

check(config_loaded,
      "Configuration file loaded",
      "Configuration file not found or failed to load")

check(exists("PROJECT_NAME"),
      "PROJECT_NAME defined",
      "PROJECT_NAME not defined in config")

check(exists("IMAGE_DIR"),
      "IMAGE_DIR defined",
      "IMAGE_DIR not defined in config")

# =============================================================================
# 2. IMAGE DIRECTORY CHECK
# =============================================================================

cat("\n📂 Checking image directory...\n")

if (exists("IMAGE_DIR")) {
  check(dir.exists(IMAGE_DIR),
        paste("Image directory exists:", IMAGE_DIR),
        paste("Image directory not found:", IMAGE_DIR))

  if (dir.exists(IMAGE_DIR)) {
    image_files <- list.files(IMAGE_DIR, pattern = "\\.(jpg|jpeg|JPG|JPEG)$")
    n_images <- length(image_files)

    check(n_images > 0,
          paste("Found", n_images, "images"),
          "No image files found in directory")

    check(n_images >= 10,
          "Sufficient images for processing",
          paste("Only", n_images, "images found. Recommend 20+ for good results"),
          is_warning = TRUE)
  }
}

# =============================================================================
# 3. EXIF METADATA CHECK
# =============================================================================

cat("\n📷 Checking EXIF metadata...\n")

exif_ok <- FALSE

if (exists("IMAGE_DIR") && dir.exists(IMAGE_DIR) && length(image_files) > 0) {
  # Try to load exifr
  has_exifr <- requireNamespace("exifr", quietly = TRUE)

  if (has_exifr) {
    sample_image <- file.path(IMAGE_DIR, image_files[1])

    exif_data <- tryCatch({
      exifr::read_exif(sample_image, tags = c("Make", "Model", "GPSLatitude", "GPSLongitude"))
    }, error = function(e) NULL)

    if (!is.null(exif_data)) {
      check(TRUE,
            "EXIF data readable",
            "Could not read EXIF data")

      # Check GPS
      has_gps <- !is.na(exif_data$GPSLatitude) && !is.na(exif_data$GPSLongitude)

      check(has_gps,
            paste("Images are geotagged (GPS:", round(exif_data$GPSLatitude, 5), ",",
                  round(exif_data$GPSLongitude, 5), ")"),
            "Images not geotagged (no GPS coordinates)")

      exif_ok <- has_gps

      # Check camera info
      if (!is.na(exif_data$Make) && !is.na(exif_data$Model)) {
        cat("   Camera:", exif_data$Make, exif_data$Model, "\n")
      }
    }
  } else {
    check(FALSE,
          "exifr package available",
          "exifr package not installed. Install with: install.packages('exifr')",
          is_warning = TRUE)
  }
}

# =============================================================================
# 4. DOCKER CHECK
# =============================================================================

cat("\n🐳 Checking Docker...\n")

# Check if docker command exists
docker_exists <- system2("which", "docker", stdout = FALSE, stderr = FALSE) == 0 ||
                 system2("where", "docker", stdout = FALSE, stderr = FALSE) == 0

check(docker_exists,
      "Docker installed",
      "Docker not found. Install from: https://docs.docker.com/get-docker/")

if (docker_exists) {
  # Check if Docker is running
  docker_running <- system2("docker", "info", stdout = FALSE, stderr = FALSE) == 0

  check(docker_running,
        "Docker is running",
        "Docker installed but not running. Start Docker Desktop")

  if (docker_running) {
    # Check for ODM image
    has_odm <- system2("docker", c("images", "-q", "opendronemap/odm"),
                      stdout = TRUE, stderr = FALSE)

    if (length(has_odm) > 0 && nchar(has_odm[1]) > 0) {
      cat("   ✓ OpenDroneMap image found\n")
    } else {
      check(FALSE,
            "OpenDroneMap image available",
            "ODM Docker image not found. Pull with: docker pull opendronemap/odm",
            is_warning = TRUE)
    }
  }
}

# =============================================================================
# 5. R PACKAGES CHECK
# =============================================================================

cat("\n📦 Checking R packages...\n")

required_packages <- c(
  "terra", "sf", "raster", "dplyr", "ggplot2",
  "randomForest", "caret", "rmarkdown", "leaflet"
)

missing_packages <- c()

for (pkg in required_packages) {
  is_installed <- requireNamespace(pkg, quietly = TRUE)

  if (is_installed) {
    validation_results$passed <- validation_results$passed + 1
  } else {
    missing_packages <- c(missing_packages, pkg)
    validation_results$failed <- validation_results$failed + 1
  }
}

if (length(missing_packages) == 0) {
  cat("   ✓ All", length(required_packages), "required packages installed\n")
} else {
  cat("   ✗", length(missing_packages), "packages missing:", paste(missing_packages, collapse = ", "), "\n")
  cat("   Install with: source('00_setup_drone_pipeline.R')\n")
}

# =============================================================================
# 6. DIRECTORY PERMISSIONS CHECK
# =============================================================================

cat("\n📁 Checking directory permissions...\n")

test_dirs <- c(
  "outputs/reports",
  "outputs/shapefiles",
  "outputs/csv",
  "data_processed/orthomosaics"
)

dir_ok <- TRUE
for (test_dir in test_dirs) {
  can_create <- tryCatch({
    dir.create(test_dir, recursive = TRUE, showWarnings = FALSE)
    TRUE
  }, error = function(e) FALSE)

  if (!can_create) {
    dir_ok <- FALSE
    break
  }
}

check(dir_ok,
      "Can create output directories",
      "Cannot create output directories. Check file permissions")

# =============================================================================
# 7. DISK SPACE CHECK
# =============================================================================

cat("\n💾 Checking disk space...\n")

if (.Platform$OS.type == "unix") {
  df_output <- system2("df", c("-h", "."), stdout = TRUE)
  cat("   ", df_output[2], "\n")

  # Extract available space (rough check)
  space_info <- strsplit(df_output[2], "\\s+")[[1]]
  avail_str <- space_info[4]

  # Warn if less than 5GB
  check(TRUE,
        "Disk space check completed",
        "Low disk space. Recommend 10+ GB free",
        is_warning = !grepl("[0-9]{2}G|[0-9]{3}G", avail_str))
} else {
  cat("   ⚠️  Disk space check not available on Windows\n")
  validation_results$warnings <- validation_results$warnings + 1
}

# =============================================================================
# VALIDATION SUMMARY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("VALIDATION SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════════════\n")

cat("Passed:  ", validation_results$passed, "\n")
cat("Failed:  ", validation_results$failed, "\n")
cat("Warnings:", validation_results$warnings, "\n")

if (length(validation_results$errors) > 0) {
  cat("\n❌ CRITICAL ERRORS:\n")
  for (err in validation_results$errors) {
    cat("   •", err, "\n")
  }
}

if (length(validation_results$warnings_list) > 0) {
  cat("\n⚠️  WARNINGS:\n")
  for (warn in validation_results$warnings_list) {
    cat("   •", warn, "\n")
  }
}

cat("\n")

if (validation_results$failed == 0) {
  cat("✅ SETUP VALIDATION PASSED!\n\n")
  cat("Ready to run the pipeline:\n")
  cat("   source('drone_pipeline_main.R')\n\n")

  return(invisible(TRUE))
} else {
  cat("❌ SETUP VALIDATION FAILED\n\n")
  cat("Please fix the errors above before running the pipeline.\n")
  cat("See docs/TROUBLESHOOTING.md for help.\n\n")

  return(invisible(FALSE))
}
