# =============================================================================
# CLEANUP TEST DATA
# =============================================================================
#
# Removes test data and outputs to free up disk space after testing
#
# Options:
#   - Remove only test images (keep processed outputs for reference)
#   - Remove all test data including outputs
#   - Archive test results before cleaning
#
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  TEST DATA CLEANUP                                                   ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Paths to clean
TEST_IMAGE_DIR <- "data_input/images/test_bellus"
PROCESSED_DATA_DIR <- "data_processed"
OUTPUTS_DIR <- "outputs"

# Calculate sizes
get_dir_size <- function(path) {
  if (!dir.exists(path)) return(0)

  files <- list.files(path, recursive = TRUE, full.names = TRUE)
  if (length(files) == 0) return(0)

  total_size <- sum(file.size(files), na.rm = TRUE)
  return(total_size)
}

test_images_size <- get_dir_size(TEST_IMAGE_DIR)
processed_size <- get_dir_size(PROCESSED_DATA_DIR)
outputs_size <- get_dir_size(OUTPUTS_DIR)
total_size <- test_images_size + processed_size + outputs_size

# Display current disk usage
cat("Current disk usage:\n")
cat("  Test images:    ", round(test_images_size / 1024^2, 1), "MB\n")
cat("  Processed data: ", round(processed_size / 1024^2, 1), "MB\n")
cat("  Outputs:        ", round(outputs_size / 1024^2, 1), "MB\n")
cat("  Total:          ", round(total_size / 1024^2, 1), "MB\n\n")

# Cleanup options
cat("Cleanup options:\n")
cat("  1. Remove test images only (keep outputs for reference)\n")
cat("  2. Remove all test data (images + outputs)\n")
cat("  3. Archive outputs then remove all\n")
cat("  4. Cancel (no cleanup)\n\n")

if (interactive()) {
  choice <- readline(prompt = "Enter choice (1-4): ")
} else {
  cat("Running in non-interactive mode. No cleanup performed.\n")
  cat("To clean up, run this script interactively in R.\n\n")
  return(invisible(NULL))
}

# Execute cleanup
if (choice == "1") {
  # Remove test images only
  cat("\n📁 Removing test images...\n")

  if (dir.exists(TEST_IMAGE_DIR)) {
    unlink(TEST_IMAGE_DIR, recursive = TRUE)
    cat("   ✓ Removed:", TEST_IMAGE_DIR, "\n")
    cat("   Freed:", round(test_images_size / 1024^2, 1), "MB\n")
  } else {
    cat("   Test images directory not found\n")
  }

  cat("\n✓ Test images removed. Outputs preserved in:\n")
  cat("  -", PROCESSED_DATA_DIR, "\n")
  cat("  -", OUTPUTS_DIR, "\n\n")

} else if (choice == "2") {
  # Remove all test data
  cat("\n🗑️  Removing all test data...\n")

  response <- readline(prompt = "This will delete all outputs. Are you sure? (yes/no): ")

  if (tolower(response) == "yes") {
    if (dir.exists(TEST_IMAGE_DIR)) {
      unlink(TEST_IMAGE_DIR, recursive = TRUE)
      cat("   ✓ Removed:", TEST_IMAGE_DIR, "\n")
    }

    if (dir.exists(PROCESSED_DATA_DIR)) {
      unlink(PROCESSED_DATA_DIR, recursive = TRUE)
      cat("   ✓ Removed:", PROCESSED_DATA_DIR, "\n")
    }

    if (dir.exists(OUTPUTS_DIR)) {
      unlink(OUTPUTS_DIR, recursive = TRUE)
      cat("   ✓ Removed:", OUTPUTS_DIR, "\n")
    }

    cat("   Freed:", round(total_size / 1024^2, 1), "MB\n\n")
    cat("✓ All test data removed\n\n")

  } else {
    cat("\n❌ Cleanup cancelled\n\n")
  }

} else if (choice == "3") {
  # Archive then remove
  cat("\n📦 Archiving outputs...\n")

  # Create archive filename
  archive_name <- paste0("test_results_", format(Sys.Date(), "%Y%m%d"), ".tar.gz")

  tryCatch({
    # Create archive
    files_to_archive <- c()

    if (dir.exists(PROCESSED_DATA_DIR)) {
      files_to_archive <- c(files_to_archive, PROCESSED_DATA_DIR)
    }

    if (dir.exists(OUTPUTS_DIR)) {
      files_to_archive <- c(files_to_archive, OUTPUTS_DIR)
    }

    if (length(files_to_archive) > 0) {
      tar(archive_name, files = files_to_archive, compression = "gzip")
      archive_size <- file.size(archive_name)

      cat("   ✓ Created archive:", archive_name, "\n")
      cat("   Archive size:", round(archive_size / 1024^2, 1), "MB\n\n")

      # Now remove
      cat("🗑️  Removing test data...\n")

      if (dir.exists(TEST_IMAGE_DIR)) {
        unlink(TEST_IMAGE_DIR, recursive = TRUE)
        cat("   ✓ Removed:", TEST_IMAGE_DIR, "\n")
      }

      if (dir.exists(PROCESSED_DATA_DIR)) {
        unlink(PROCESSED_DATA_DIR, recursive = TRUE)
        cat("   ✓ Removed:", PROCESSED_DATA_DIR, "\n")
      }

      if (dir.exists(OUTPUTS_DIR)) {
        unlink(OUTPUTS_DIR, recursive = TRUE)
        cat("   ✓ Removed:", OUTPUTS_DIR, "\n")
      }

      cat("\n✓ Test data archived and removed\n")
      cat("  Archive:", archive_name, "\n")
      cat("  Freed:", round(total_size / 1024^2, 1), "MB\n\n")

    } else {
      cat("   No data to archive\n\n")
    }

  }, error = function(e) {
    cat("\n❌ Archive failed:", conditionMessage(e), "\n")
    cat("Cleanup cancelled to preserve data\n\n")
  })

} else {
  # Cancel
  cat("\n❌ Cleanup cancelled. No files removed.\n\n")
}

cat("Done.\n\n")
