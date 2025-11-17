# =============================================================================
# DRONE ORTHOMOSAIC TO ECOLOGICAL METRICS PIPELINE
# MAIN WRAPPER FUNCTION
# =============================================================================
#
# Purpose: Run complete pipeline with a single command
#
# Usage:
#   1. Configure settings in config/drone_config.R
#   2. Place drone images in data_input/images/
#   3. Run: source("drone_pipeline_main.R")
#
# This will execute all modules in sequence:
#   01 - ODM Orthomosaic Generation
#   02 - Vegetation Classification
#   03 - Tree/Shrub Detection
#   04 - Change Detection (if enabled)
#   05 - Summary Statistics
#   06 - Report Generation
#
# =============================================================================

# Clear environment (optional - comment out if you want to preserve variables)
# rm(list = ls())

# Set working directory to pipeline root (if needed)
if (basename(getwd()) != "drone_pipeline") {
  if (dir.exists("drone_pipeline")) {
    setwd("drone_pipeline")
  }
}

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  DRONE ORTHOMOSAIC TO ECOLOGICAL METRICS PIPELINE                    ║\n")
cat("║  Version 1.0                                                         ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# =============================================================================
# INITIALIZATION
# =============================================================================

cat("🚀 Initializing pipeline...\n\n")

# Load configuration
if (file.exists("config/drone_config.R")) {
  source("config/drone_config.R")
  cat("✓ Configuration loaded\n")
} else {
  stop("Configuration file not found. Please ensure config/drone_config.R exists.")
}

# Print configuration summary
if (exists("print_config_summary")) {
  print_config_summary()
}

# Validate configuration
if (exists("validate_config")) {
  validation_results <- validate_config()

  if (!validation_results$valid) {
    stop("Configuration validation failed. Please fix errors and try again.")
  }
}

# Track start time
pipeline_start_time <- Sys.time()

# Initialize results storage
pipeline_results <- list()

# =============================================================================
# MODULE EXECUTION
# =============================================================================

# User confirmation before starting
cat("\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("Ready to start processing pipeline.\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

if (interactive()) {
  response <- readline(prompt = "Continue? (y/n): ")
  if (tolower(response) != "y") {
    cat("Pipeline cancelled by user.\n")
    quit(save = "no")
  }
}

# -------------------------------------------------------------------------
# Module 01: ODM Orthomosaic Generation
# -------------------------------------------------------------------------
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  STEP 1/6: ORTHOMOSAIC GENERATION                                    ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")

tryCatch({
  source("R/01_odm_orthomosaic_generation.R")
  pipeline_results$module_01 <- run_odm_workflow()
  cat("\n✅ Module 01 completed successfully\n")
}, error = function(e) {
  cat("\n❌ Module 01 failed:", e$message, "\n")
  if (ERROR_HANDLING$stop_on_error) {
    stop("Pipeline halted due to error in Module 01")
  }
})

# -------------------------------------------------------------------------
# Module 02: Vegetation Classification
# -------------------------------------------------------------------------
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  STEP 2/6: VEGETATION CLASSIFICATION                                 ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")

tryCatch({
  source("R/02_vegetation_classification.R")
  pipeline_results$module_02 <- run_vegetation_classification()
  cat("\n✅ Module 02 completed successfully\n")
}, error = function(e) {
  cat("\n❌ Module 02 failed:", e$message, "\n")
  if (ERROR_HANDLING$stop_on_error) {
    stop("Pipeline halted due to error in Module 02")
  }
})

# -------------------------------------------------------------------------
# Module 03: Tree/Shrub Detection
# -------------------------------------------------------------------------
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  STEP 3/6: TREE/SHRUB DETECTION                                      ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")

tryCatch({
  source("R/03_tree_shrub_detection.R")
  pipeline_results$module_03 <- run_tree_detection()
  cat("\n✅ Module 03 completed successfully\n")
}, error = function(e) {
  cat("\n❌ Module 03 failed:", e$message, "\n")
  if (ERROR_HANDLING$stop_on_error) {
    stop("Pipeline halted due to error in Module 03")
  }
})

# -------------------------------------------------------------------------
# Module 04: Change Detection (if enabled)
# -------------------------------------------------------------------------
if (ENABLE_CHANGE_DETECTION) {
  cat("\n")
  cat("╔══════════════════════════════════════════════════════════════════════╗\n")
  cat("║  STEP 4/6: CHANGE DETECTION                                          ║\n")
  cat("╚══════════════════════════════════════════════════════════════════════╝\n")

  tryCatch({
    source("R/04_change_detection.R")
    pipeline_results$module_04 <- run_change_detection()
    cat("\n✅ Module 04 completed successfully\n")
  }, error = function(e) {
    cat("\n❌ Module 04 failed:", e$message, "\n")
    if (ERROR_HANDLING$stop_on_error) {
      stop("Pipeline halted due to error in Module 04")
    }
  })
} else {
  cat("\n⏭️  Skipping Module 04: Change Detection (disabled in config)\n")
}

# -------------------------------------------------------------------------
# Module 05: Summary Statistics
# -------------------------------------------------------------------------
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  STEP 5/6: SUMMARY STATISTICS                                        ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")

tryCatch({
  source("R/05_summary_statistics.R")
  pipeline_results$module_05 <- run_summary_statistics()
  cat("\n✅ Module 05 completed successfully\n")
}, error = function(e) {
  cat("\n❌ Module 05 failed:", e$message, "\n")
  if (ERROR_HANDLING$stop_on_error) {
    stop("Pipeline halted due to error in Module 05")
  }
})

# -------------------------------------------------------------------------
# Module 06: Report Generation
# -------------------------------------------------------------------------
cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  STEP 6/6: REPORT GENERATION                                         ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")

tryCatch({
  source("R/06_generate_report.R")
  pipeline_results$module_06 <- generate_drone_report()
  cat("\n✅ Module 06 completed successfully\n")
}, error = function(e) {
  cat("\n❌ Module 06 failed:", e$message, "\n")
  if (ERROR_HANDLING$stop_on_error) {
    stop("Pipeline halted due to error in Module 06")
  }
})

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================

pipeline_end_time <- Sys.time()
pipeline_duration <- difftime(pipeline_end_time, pipeline_start_time, units = "mins")

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  PIPELINE COMPLETED SUCCESSFULLY                                     ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

cat("⏱️  Processing Time:", round(pipeline_duration, 1), "minutes\n")
cat("📅 Completed:", format(pipeline_end_time, "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("📊 Results Summary:\n")
cat("═══════════════════════════════════════════════════════════════════════\n")

if (!is.null(pipeline_results$module_05)) {
  summary_data <- pipeline_results$module_05

  if (!is.null(summary_data$survey_area)) {
    cat("  Survey Area:", round(summary_data$survey_area$area_ha, 2), "hectares\n")
  }

  if (!is.null(summary_data$tree_statistics)) {
    cat("  Trees Detected:", summary_data$tree_statistics$total_trees, "\n")
    cat("  Tree Density:", round(summary_data$tree_statistics$tree_density_per_ha, 1), "per ha\n")
  }

  if (!is.null(summary_data$vegetation_classes)) {
    cat("  Vegetation Classes:", nrow(summary_data$vegetation_classes), "\n")
  }
}

cat("\n📂 Output Locations:\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("  Reports:     ", OUTPUT_DIRS$reports, "\n")
cat("  Shapefiles:  ", OUTPUT_DIRS$shapefiles, "\n")
cat("  CSV Tables:  ", OUTPUT_DIRS$csv, "\n")
cat("  GeoTIFFs:    ", OUTPUT_DIRS$geotiff, "\n")
cat("  Maps:        ", OUTPUT_DIRS$maps, "\n")

cat("\n📧 Next Steps:\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("  1. Review the PDF report in:", OUTPUT_DIRS$reports, "\n")
cat("  2. Open interactive map in web browser\n")
cat("  3. Share results with community partners\n")
cat("  4. Archive data for future monitoring\n")

cat("\n✨ Pipeline execution complete!\n\n")

# Save pipeline results
saveRDS(pipeline_results, file.path(OUTPUT_DIRS$reports, "pipeline_results.rds"))
cat("💾 Pipeline results saved to: ", file.path(OUTPUT_DIRS$reports, "pipeline_results.rds"), "\n\n")
