# =============================================================================
# TEST DATA DOWNLOAD SCRIPT
# =============================================================================
#
# Downloads OpenDroneMap "Bellus" sample dataset for testing the pipeline
#
# Dataset details:
#   - 77 drone images
#   - Geotagged with GPS coordinates
#   - Small park area (~1.8 hectares)
#   - Size: ~450 MB
#
# Runtime: 5-10 minutes (depending on internet speed)
#
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  DOWNLOADING TEST DATASET                                           ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Load required packages
if (!require("utils")) install.packages("utils")
if (!require("tools")) install.packages("tools")

# Configuration
TEST_DATA_URL <- "https://github.com/OpenDroneMap/odm_data_bellus/archive/refs/heads/master.zip"
DOWNLOAD_DIR <- "data_input/images"
TEST_FOLDER <- "test_bellus"
DOWNLOAD_FILE <- "bellus_dataset.zip"

# Create directories
dir.create(DOWNLOAD_DIR, recursive = TRUE, showWarnings = FALSE)
download_path <- file.path(DOWNLOAD_DIR, DOWNLOAD_FILE)
extract_path <- file.path(DOWNLOAD_DIR, TEST_FOLDER)

# Check if already downloaded
if (dir.exists(extract_path)) {
  n_images <- length(list.files(extract_path, pattern = "\\.(jpg|jpeg|JPG|JPEG)$"))

  if (n_images > 70) {
    cat("✓ Test dataset already exists\n")
    cat("  Location:", extract_path, "\n")
    cat("  Images found:", n_images, "\n\n")

    response <- readline(prompt = "Re-download? (y/n): ")
    if (tolower(response) != "y") {
      cat("\nUsing existing test data. Run validate_test_setup.R to verify.\n\n")
      return(invisible(NULL))
    }

    # Clean up existing
    unlink(extract_path, recursive = TRUE)
  }
}

cat("📥 Downloading test dataset...\n")
cat("   Source: OpenDroneMap sample data\n")
cat("   Size: ~450 MB\n")
cat("   This may take 5-10 minutes...\n\n")

# Download with progress
tryCatch({
  download.file(
    url = TEST_DATA_URL,
    destfile = download_path,
    mode = "wb",
    method = "auto"
  )

  cat("\n✓ Download complete\n")

}, error = function(e) {
  cat("\n❌ Download failed:", conditionMessage(e), "\n")
  cat("\nTroubleshooting:\n")
  cat("1. Check internet connection\n")
  cat("2. Try manual download from:\n")
  cat("   https://github.com/OpenDroneMap/odm_data_bellus\n")
  cat("3. Extract to:", extract_path, "\n\n")
  stop("Download failed")
})

# Extract ZIP file
cat("\n📦 Extracting images...\n")

tryCatch({
  # Create extraction directory
  dir.create(extract_path, recursive = TRUE, showWarnings = FALSE)

  # Extract
  unzip(download_path, exdir = DOWNLOAD_DIR)

  # Find extracted folder (might have different name)
  extracted_folders <- list.dirs(DOWNLOAD_DIR, recursive = FALSE, full.names = FALSE)
  bellus_folder <- grep("bellus|odm_data", extracted_folders, ignore.case = TRUE, value = TRUE)

  if (length(bellus_folder) == 0) {
    stop("Could not find extracted dataset folder")
  }

  # Move images to correct location
  image_source <- file.path(DOWNLOAD_DIR, bellus_folder[1], "images")

  if (!dir.exists(image_source)) {
    # Try direct in folder
    image_source <- file.path(DOWNLOAD_DIR, bellus_folder[1])
  }

  # Copy image files
  image_files <- list.files(image_source, pattern = "\\.(jpg|jpeg|JPG|JPEG)$", full.names = TRUE)

  if (length(image_files) == 0) {
    stop("No image files found in extracted dataset")
  }

  file.copy(image_files, extract_path)

  cat("   Extracted", length(image_files), "images\n")

  # Clean up
  unlink(file.path(DOWNLOAD_DIR, bellus_folder[1]), recursive = TRUE)
  unlink(download_path)

  cat("   ✓ Extraction complete\n")

}, error = function(e) {
  cat("\n❌ Extraction failed:", conditionMessage(e), "\n")
  cat("\nTry manual extraction:\n")
  cat("1. Extract", download_path, "\n")
  cat("2. Copy JPG files to:", extract_path, "\n\n")
  stop("Extraction failed")
})

# Verify download
cat("\n✅ Verifying download...\n")

image_files <- list.files(extract_path, pattern = "\\.(jpg|jpeg|JPG|JPEG)$")
n_images <- length(image_files)

if (n_images < 70) {
  warning("Expected ~77 images but found ", n_images)
  cat("\n⚠️  Fewer images than expected. Dataset may be incomplete.\n")
} else {
  cat("   ✓ Found", n_images, "images\n")
}

# Check sample image has EXIF data
if (requireNamespace("exifr", quietly = TRUE)) {
  cat("\n📷 Checking EXIF metadata...\n")

  sample_image <- file.path(extract_path, image_files[1])

  tryCatch({
    exif <- exifr::read_exif(sample_image, tags = c("GPSLatitude", "GPSLongitude"))

    if (!is.na(exif$GPSLatitude) && !is.na(exif$GPSLongitude)) {
      cat("   ✓ Images are geotagged\n")
      cat("   Sample GPS:", round(exif$GPSLatitude, 5), ",", round(exif$GPSLongitude, 5), "\n")
    } else {
      cat("   ⚠️  GPS data not found in EXIF\n")
    }
  }, error = function(e) {
    cat("   ⚠️  Could not read EXIF data\n")
  })
}

# Print summary
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  DOWNLOAD COMPLETE                                                   ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")
cat("Test dataset location:", extract_path, "\n")
cat("Number of images:", n_images, "\n")
cat("\n")
cat("Next steps:\n")
cat("1. Run: source('tests/create_test_config.R')\n")
cat("2. Run: source('tests/validate_test_setup.R')\n")
cat("3. Run: source('drone_pipeline_main.R')\n")
cat("\n")

cat("✨ Ready to test the pipeline!\n\n")
