#!/usr/bin/env Rscript
# ============================================================================
# MASTER MMRV WORKFLOW RUNNER
# ============================================================================
# Orchestrates complete multi-ecosystem carbon MMRV workflow
# Supports: Coastal Blue Carbon, Forests, Grasslands, Wetlands, Arctic
# Features: Composite sampling toggle, modular execution, comprehensive logging
#
# Usage:
#   Rscript run_workflow.R
#   OR
#   source("run_workflow.R")
#
# Configuration: Edit config.R before running
# ============================================================================

# ============================================================================
# SETUP AND INITIALIZATION
# ============================================================================

cat("\n")
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║                                                                ║\n")
cat("║        GENERALIZED MMRV WORKFLOW FOR MULTIPLE ECOSYSTEMS       ║\n")
cat("║                                                                ║\n")
cat("║    Monitoring, Reporting, and Verification of Carbon Stocks   ║\n")
cat("║                                                                ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Start workflow timer
workflow_start_time <- Sys.time()

# Load configuration
cat("Loading configuration...\n")
if (!file.exists("config.R")) {
  stop("Configuration file 'config.R' not found. Please create it before running the workflow.")
}

source("config.R")

# Load utilities
cat("Loading utility functions...\n")
if (!file.exists("utils/mmrv_utils.R")) {
  warning("Utility functions not found. Creating utils directory...")
  dir.create("utils", showWarnings = FALSE)
}

if (file.exists("utils/mmrv_utils.R")) {
  source("utils/mmrv_utils.R")
}

# Load required packages
cat("Loading required packages...\n")
required_packages <- c("dplyr", "tidyr", "readr", "sf", "terra", "ggplot2")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("Installing missing package: %s\n", pkg))
    install.packages(pkg)
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

# Create logger
log_file <- file.path(DIR_LOGS, paste0("workflow_", SESSION_ID, ".log"))
ensure_dir(DIR_LOGS)
log_message <- create_logger(log_file)

log_message("=== MMRV WORKFLOW STARTED ===")
log_message(sprintf("Ecosystem Type: %s", ECOSYSTEM_TYPE))
log_message(sprintf("Composite Sampling: %s", COMPOSITE_SAMPLING))
log_message(sprintf("Project: %s", PROJECT_NAME))
log_message(sprintf("Session ID: %s", SESSION_ID))

# Print configuration summary
print_config_summary()

# ============================================================================
# VALIDATE CONFIGURATION
# ============================================================================

cat("\nValidating configuration...\n")
log_message("Validating configuration")

tryCatch({
  validate_ecosystem_config(ECOSYSTEM_TYPE)
  log_message("Configuration validation passed")
}, error = function(e) {
  log_message(sprintf("Configuration validation failed: %s", e$message), "ERROR")
  stop(e)
})

# ============================================================================
# CREATE OUTPUT DIRECTORIES
# ============================================================================

cat("Creating output directories...\n")
log_message("Creating output directory structure")

output_dirs <- c(
  DIR_OUTPUT,
  DIR_OUTPUT_PREDICTIONS,
  file.path(DIR_OUTPUT_PREDICTIONS, "rf"),
  file.path(DIR_OUTPUT_PREDICTIONS, "kriging"),
  file.path(DIR_OUTPUT_PREDICTIONS, "posterior"),
  DIR_OUTPUT_CARBON_STOCKS,
  DIR_OUTPUT_REPORTS,
  DIR_OUTPUT_MMRV,
  DIR_OUTPUT_MAPS,
  DIR_PROCESSED,
  DIR_DIAGNOSTICS,
  file.path(DIR_DIAGNOSTICS, "data_prep"),
  file.path(DIR_DIAGNOSTICS, "qaqc"),
  file.path(DIR_DIAGNOSTICS, "harmonization"),
  file.path(DIR_DIAGNOSTICS, "crossvalidation"),
  file.path(DIR_DIAGNOSTICS, "bayesian"),
  DIR_LOGS,
  DIR_TEMP
)

for (dir in output_dirs) {
  ensure_dir(dir)
}

log_message("Directory structure created successfully")

# ============================================================================
# WORKFLOW EXECUTION FLAGS
# ============================================================================

# Determine which modules to run based on configuration
run_modules <- list(
  data_prep = TRUE,  # Always run
  qc = TRUE,         # Always run
  depth_harmonization = TRUE,  # Always run
  kriging = ENABLE_MAPPING,
  rf = ENABLE_MAPPING && ENABLE_REMOTE_SENSING,
  bayesian = ENABLE_BAYESIAN,
  carbon_stocks = TRUE,  # Always run
  mmrv_reporting = TRUE,  # Always run
  standards_report = TRUE,  # Always run
  temporal = ENABLE_TEMPORAL_ANALYSIS,
  flux = ENABLE_FLUX_CALCULATIONS
)

log_message("Module execution plan:")
for (module in names(run_modules)) {
  status <- ifelse(run_modules[[module]], "ENABLED", "SKIPPED")
  log_message(sprintf("  %s: %s", module, status))
}

# ============================================================================
# PART 0: SETUP (OPTIONAL)
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("PART 0: SETUP AND PREREQUISITES\n")
cat("════════════════════════════════════════════════════════════════\n")

# Check if setup scripts need to be run
if (!file.exists(file.path(DIR_PROCESSED, "setup_complete.flag"))) {
  cat("\nFirst-time setup detected. Running setup scripts...\n")

  # Install packages if needed
  if (file.exists("00a_install_packages_v2.R")) {
    cat("Installing required packages...\n")
    log_message("Running package installation")
    source("00a_install_packages_v2.R")
  }

  # Setup directories
  if (file.exists("00b_setup_directories.R")) {
    cat("Setting up directory structure...\n")
    log_message("Running directory setup")
    source("00b_setup_directories.R")
  }

  # Mark setup as complete
  writeLines("Setup completed", file.path(DIR_PROCESSED, "setup_complete.flag"))
  log_message("Setup completed successfully")
} else {
  cat("Setup already completed. Skipping...\n")
}

# Bayesian prior setup (if enabled)
if (ENABLE_BAYESIAN && file.exists("00c_bayesian_prior_setup_bluecarbon.R")) {
  cat("\nSetting up Bayesian priors...\n")
  log_message("Running Bayesian prior setup")
  tryCatch({
    source("00c_bayesian_prior_setup_bluecarbon.R")
    log_message("Bayesian prior setup completed")
  }, error = function(e) {
    log_message(sprintf("Bayesian prior setup failed: %s", e$message), "WARNING")
    cat("  WARNING: Bayesian prior setup failed. Continuing without Bayesian analysis.\n")
    run_modules$bayesian <- FALSE
  })
}

# ============================================================================
# PART 1: DATA INGESTION AND PREPARATION
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("PART 1: DATA INGESTION AND PREPARATION\n")
cat("════════════════════════════════════════════════════════════════\n")

if (run_modules$data_prep) {
  cat("\n[Module 01] Data Preparation\n")
  log_message("Starting Module 01: Data Preparation")

  tryCatch({
    source("01_data_prep_bluecarbon.R")
    log_message("Module 01 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 01 failed: %s", e$message), "ERROR")
    stop("Critical error in data preparation. Workflow terminated.")
  })
} else {
  cat("\n[Module 01] SKIPPED\n")
}

# Exploratory analysis (optional)
if (file.exists("02_exploratory_analysis_bluecarbon.R") && ENABLE_INVENTORY) {
  cat("\n[Module 02] Exploratory Analysis\n")
  log_message("Starting Module 02: Exploratory Analysis")

  tryCatch({
    source("02_exploratory_analysis_bluecarbon.R")
    log_message("Module 02 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 02 failed: %s", e$message), "WARNING")
    cat("  WARNING: Exploratory analysis failed. Continuing workflow.\n")
  })
}

# ============================================================================
# PART 2: DEPTH HARMONIZATION
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("PART 2: DEPTH HARMONIZATION\n")
cat("════════════════════════════════════════════════════════════════\n")

if (run_modules$depth_harmonization) {
  cat("\n[Module 03] Depth Harmonization\n")
  log_message("Starting Module 03: Depth Harmonization")

  tryCatch({
    source("03_depth_harmonization_bluecarbon.R")
    log_message("Module 03 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 03 failed: %s", e$message), "ERROR")
    stop("Critical error in depth harmonization. Workflow terminated.")
  })
} else {
  cat("\n[Module 03] SKIPPED\n")
}

# ============================================================================
# PART 3: SPATIAL PREDICTIONS
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("PART 3: SPATIAL PREDICTIONS\n")
cat("════════════════════════════════════════════════════════════════\n")

# Kriging predictions
if (run_modules$kriging) {
  cat("\n[Module 04] Kriging Predictions\n")
  log_message("Starting Module 04: Kriging Predictions")

  tryCatch({
    source("04_raster_predictions_kriging_bluecarbon.R")
    log_message("Module 04 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 04 failed: %s", e$message), "WARNING")
    cat("  WARNING: Kriging predictions failed. Continuing workflow.\n")
  })
} else {
  cat("\n[Module 04] SKIPPED - Kriging disabled\n")
}

# Random Forest predictions
if (run_modules$rf) {
  cat("\n[Module 05] Random Forest Predictions\n")
  log_message("Starting Module 05: Random Forest Predictions")

  tryCatch({
    source("05_raster_predictions_rf_bluecarbon.R")
    log_message("Module 05 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 05 failed: %s", e$message), "WARNING")
    cat("  WARNING: Random Forest predictions failed. Continuing workflow.\n")
  })
} else {
  cat("\n[Module 05] SKIPPED - Random Forest disabled\n")
}

# ============================================================================
# PART 4: BAYESIAN ANALYSIS (OPTIONAL)
# ============================================================================

if (run_modules$bayesian) {
  cat("\n")
  cat("════════════════════════════════════════════════════════════════\n")
  cat("PART 4: BAYESIAN POSTERIOR ESTIMATION\n")
  cat("════════════════════════════════════════════════════════════════\n")

  cat("\n[Module 06c] Bayesian Posterior Estimation\n")
  log_message("Starting Module 06c: Bayesian Posterior Estimation")

  tryCatch({
    source("06c_bayesian_posterior_estimation_bluecarbon.R")
    log_message("Module 06c completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 06c failed: %s", e$message), "WARNING")
    cat("  WARNING: Bayesian analysis failed. Continuing with non-Bayesian results.\n")
  })
}

# ============================================================================
# PART 5: CARBON STOCK CALCULATION
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("PART 5: CARBON STOCK CALCULATION\n")
cat("════════════════════════════════════════════════════════════════\n")

if (run_modules$carbon_stocks) {
  cat("\n[Module 06] Carbon Stock Calculation\n")
  log_message("Starting Module 06: Carbon Stock Calculation")

  tryCatch({
    source("06_carbon_stock_calculation_bluecarbon.R")
    log_message("Module 06 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 06 failed: %s", e$message), "ERROR")
    stop("Critical error in carbon stock calculation. Workflow terminated.")
  })
} else {
  cat("\n[Module 06] SKIPPED\n")
}

# ============================================================================
# PART 6: REPORTING AND VERIFICATION
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("PART 6: REPORTING AND VERIFICATION\n")
cat("════════════════════════════════════════════════════════════════\n")

# MMRV Reporting
if (run_modules$mmrv_reporting) {
  cat("\n[Module 07] MMRV Reporting\n")
  log_message("Starting Module 07: MMRV Reporting")

  tryCatch({
    source("07_mmrv_reporting_bluecarbon.R")
    log_message("Module 07 completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 07 failed: %s", e$message), "WARNING")
    cat("  WARNING: MMRV reporting failed. Continuing workflow.\n")
  })
} else {
  cat("\n[Module 07] SKIPPED\n")
}

# Standards Compliance Report
if (run_modules$standards_report) {
  cat("\n[Module 07b] Comprehensive Standards Report\n")
  log_message("Starting Module 07b: Standards Compliance Report")

  tryCatch({
    source("07b_comprehensive_standards_report.R")
    log_message("Module 07b completed successfully")
  }, error = function(e) {
    log_message(sprintf("Module 07b failed: %s", e$message), "WARNING")
    cat("  WARNING: Standards report failed. Continuing workflow.\n")
  })
} else {
  cat("\n[Module 07b] SKIPPED\n")
}

# ============================================================================
# PART 7: TEMPORAL ANALYSIS (OPTIONAL)
# ============================================================================

if (run_modules$temporal) {
  cat("\n")
  cat("════════════════════════════════════════════════════════════════\n")
  cat("PART 7: TEMPORAL ANALYSIS\n")
  cat("════════════════════════════════════════════════════════════════\n")

  # Temporal harmonization
  if (file.exists("08_temporal_data_harmonization.R")) {
    cat("\n[Module 08] Temporal Data Harmonization\n")
    log_message("Starting Module 08: Temporal Harmonization")

    tryCatch({
      source("08_temporal_data_harmonization.R")
      log_message("Module 08 completed successfully")
    }, error = function(e) {
      log_message(sprintf("Module 08 failed: %s", e$message), "WARNING")
      cat("  WARNING: Temporal harmonization failed.\n")
    })
  }

  # Temporal change analysis
  if (file.exists("09_additionality_temporal_analysis.R")) {
    cat("\n[Module 09] Temporal Change Analysis\n")
    log_message("Starting Module 09: Temporal Analysis")

    tryCatch({
      source("09_additionality_temporal_analysis.R")
      log_message("Module 09 completed successfully")
    }, error = function(e) {
      log_message(sprintf("Module 09 failed: %s", e$message), "WARNING")
      cat("  WARNING: Temporal analysis failed.\n")
    })
  }

  # Final verification
  if (file.exists("10_vm0033_final_verification.R")) {
    cat("\n[Module 10] Final Verification\n")
    log_message("Starting Module 10: Final Verification")

    tryCatch({
      source("10_vm0033_final_verification.R")
      log_message("Module 10 completed successfully")
    }, error = function(e) {
      log_message(sprintf("Module 10 failed: %s", e$message), "WARNING")
      cat("  WARNING: Final verification failed.\n")
    })
  }
}

# ============================================================================
# WORKFLOW COMPLETION
# ============================================================================

workflow_end_time <- Sys.time()
workflow_duration <- difftime(workflow_end_time, workflow_start_time, units = "mins")

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("                  WORKFLOW COMPLETED SUCCESSFULLY                \n")
cat("════════════════════════════════════════════════════════════════\n")
cat("\n")
cat(sprintf("Total execution time: %.2f minutes\n", as.numeric(workflow_duration)))
cat(sprintf("Session ID: %s\n", SESSION_ID))
cat(sprintf("Log file: %s\n", log_file))
cat("\n")

log_message("=== MMRV WORKFLOW COMPLETED SUCCESSFULLY ===")
log_message(sprintf("Total execution time: %.2f minutes", as.numeric(workflow_duration)))

# ============================================================================
# OUTPUT SUMMARY
# ============================================================================

cat("════════════════════════════════════════════════════════════════\n")
cat("OUTPUT SUMMARY\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("\n")
cat("Key outputs generated:\n")
cat(sprintf("  • Processed data: %s/\n", DIR_PROCESSED))
cat(sprintf("  • Carbon stocks: %s/\n", DIR_OUTPUT_CARBON_STOCKS))
cat(sprintf("  • Reports: %s/\n", DIR_OUTPUT_REPORTS))
cat(sprintf("  • MMRV reports: %s/\n", DIR_OUTPUT_MMRV))
if (ENABLE_MAPPING) {
  cat(sprintf("  • Predictions: %s/\n", DIR_OUTPUT_PREDICTIONS))
  cat(sprintf("  • Maps: %s/\n", DIR_OUTPUT_MAPS))
}
cat(sprintf("  • Diagnostics: %s/\n", DIR_DIAGNOSTICS))
cat(sprintf("  • Logs: %s\n", log_file))
cat("\n")

# Print next steps
cat("════════════════════════════════════════════════════════════════\n")
cat("NEXT STEPS\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("\n")
cat("1. Review the comprehensive standards report:\n")
cat(sprintf("   %s/comprehensive_standards_report.html\n", DIR_OUTPUT_REPORTS))
cat("\n")
cat("2. Check MMRV verification package:\n")
cat(sprintf("   %s/vm0033_verification_package.html\n", DIR_OUTPUT_MMRV))
cat("\n")
cat("3. Review carbon stock results:\n")
cat(sprintf("   %s/\n", DIR_OUTPUT_CARBON_STOCKS))
cat("\n")
cat("4. Examine diagnostics for any issues:\n")
cat(sprintf("   %s/\n", DIR_DIAGNOSTICS))
cat("\n")

# Create workflow summary file
summary_file <- file.path(DIR_OUTPUT, paste0("workflow_summary_", SESSION_ID, ".txt"))
sink(summary_file)
cat("MMRV WORKFLOW SUMMARY\n")
cat("=====================\n\n")
cat(sprintf("Ecosystem Type: %s\n", ECOSYSTEM_TYPE))
cat(sprintf("Composite Sampling: %s\n", COMPOSITE_SAMPLING))
cat(sprintf("Project Name: %s\n", PROJECT_NAME))
cat(sprintf("Scenario: %s\n", PROJECT_SCENARIO))
cat(sprintf("Monitoring Year: %d\n", MONITORING_YEAR))
cat(sprintf("Session ID: %s\n", SESSION_ID))
cat(sprintf("Start Time: %s\n", workflow_start_time))
cat(sprintf("End Time: %s\n", workflow_end_time))
cat(sprintf("Duration: %.2f minutes\n", as.numeric(workflow_duration)))
cat("\nModules Executed:\n")
for (module in names(run_modules)) {
  if (run_modules[[module]]) {
    cat(sprintf("  ✓ %s\n", module))
  } else {
    cat(sprintf("  ✗ %s (skipped)\n", module))
  }
}
sink()

cat(sprintf("Workflow summary saved to: %s\n", summary_file))
cat("\n")
cat("Thank you for using the Generalized MMRV Workflow!\n")
cat("\n")

# ============================================================================
# END OF WORKFLOW
# ============================================================================
