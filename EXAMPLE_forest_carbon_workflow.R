# ============================================================================
# EXAMPLE WORKFLOW: Canadian Forest Carbon Monitoring
# ============================================================================
# This script demonstrates the complete workflow for forest soil carbon
# assessment adapted for Canadian forest ecosystems
#
# PROJECT EXAMPLE:
#   - Afforestation project in British Columbia
#   - Former agricultural land converted to mixed conifer forest
#   - Compliance with VCS VM0042 (A/R) and BC Forest Carbon Offset Protocol
#   - Soil carbon monitoring (LFH layer + mineral soil 0-100 cm)
#
# WORKFLOW STEPS:
#   1. Setup and configuration
#   2. Data preparation and quality control
#   3. LFH layer processing (forest floor)
#   4. Coarse fragment corrections
#   5. Depth harmonization
#   6. Spatial prediction (Random Forest)
#   7. Carbon stock aggregation
#   8. Standards compliance checking
#
# REQUIREMENTS:
#   - Field data: core_locations.csv, core_samples.csv, lfh_samples.csv
#   - Optional: Spatial covariates (forest age, species, elevation, etc.)
#
# USAGE:
#   1. Update blue_carbon_config.R with your project details
#   2. Prepare input data files (see templates)
#   3. Run this script section by section
# ============================================================================

# Clear workspace
rm(list = ls())

# Set working directory (adjust to your project location)
# setwd("/path/to/your/forest/carbon/project")

cat("\n")
cat("============================================================\n")
cat("CANADIAN FOREST CARBON MONITORING WORKFLOW\n")
cat("============================================================\n\n")

# ============================================================================
# STEP 0: SETUP AND CONFIGURATION
# ============================================================================

cat("STEP 0: Loading Configuration\n")
cat("------------------------------------------------------------\n")

# Load configuration file
source("blue_carbon_config.R")

# Display project information
cat(sprintf("\nProject: %s\n", PROJECT_NAME))
cat(sprintf("Location: %s\n", PROJECT_LOCATION))
cat(sprintf("Scenario: %s\n", PROJECT_SCENARIO))
cat(sprintf("Monitoring Year: %d\n", MONITORING_YEAR))
cat(sprintf("\nForest Strata (%d total):\n", length(VALID_STRATA)))
for (i in seq_along(VALID_STRATA)) {
  cat(sprintf("  %d. %s\n", i, VALID_STRATA[i]))
}
cat(sprintf("\nLFH Layer Measurement: %s\n", ifelse(MEASURE_LFH_LAYER, "ENABLED", "DISABLED")))
cat(sprintf("Coarse Fragment Correction: ENABLED\n"))
cat(sprintf("Target Precision: %d%% at 95%% CI\n", FOREST_TARGET_PRECISION))
cat(sprintf("Minimum Cores per Stratum: %d\n", FOREST_MIN_CORES))

cat("\n✓ Configuration loaded successfully\n")

# ============================================================================
# STEP 1: DATA PREPARATION AND QUALITY CONTROL
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 1: Data Preparation and Quality Control\n")
cat("============================================================\n\n")

# Check if input files exist
required_files <- c(
  "data_raw/core_locations.csv",
  "data_raw/core_samples.csv"
)

optional_files <- c(
  "data_raw/lfh_samples.csv"
)

cat("Checking for required input files...\n")
for (file in required_files) {
  if (file.exists(file)) {
    cat(sprintf("  ✓ Found: %s\n", file))
  } else {
    cat(sprintf("  ✗ MISSING: %s\n", file))
    stop(sprintf("Required file not found: %s\nPlease create this file before proceeding.", file))
  }
}

cat("\nChecking for optional input files...\n")
for (file in optional_files) {
  if (file.exists(file)) {
    cat(sprintf("  ✓ Found: %s\n", file))
  } else {
    cat(sprintf("  ⚠ Not found: %s (optional)\n", file))
  }
}

# Run Module 01: Data Preparation
cat("\nRunning Module 01: Data Preparation...\n")
source("01_data_prep_bluecarbon.R")

# Run Module 02: Exploratory Analysis and QC
cat("\nRunning Module 02: Exploratory Analysis and Quality Control...\n")
source("02_exploratory_analysis_bluecarbon.R")

cat("\n✓ Data preparation and QC complete\n")
cat("  → Check diagnostics/data_prep/ and diagnostics/qaqc/ for results\n")

# ============================================================================
# STEP 1B: COARSE FRAGMENT CORRECTIONS (Forest-Specific)
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 1B: Coarse Fragment Corrections\n")
cat("============================================================\n\n")

cat("Forest soils often contain significant coarse fragments (stones, gravel).\n")
cat("These must be excluded from carbon stock calculations.\n\n")

# Load coarse fragment correction module
source("01b_coarse_fragment_corrections.R")

# Load prepared core data
cores <- readRDS("data_processed/cores_prepared_bluecarbon.rds")

# Apply coarse fragment corrections
# Specify cf_type based on your data:
#   - "volume" if you measured % volume directly
#   - "mass" if you measured % mass (will be converted to volume)
#   - "class" if you used visual estimates (e.g., "15-35%", "common")

cores_cf_corrected <- apply_coarse_fragment_corrections(
  cores,
  cf_type = "volume",  # Change based on your data
  create_plots = TRUE
)

# Save corrected data
saveRDS(cores_cf_corrected, "data_processed/cores_cf_corrected.rds")

cat("\n✓ Coarse fragment corrections applied\n")
cat("  → Check diagnostics/coarse_fragments/ for results\n")

# ============================================================================
# STEP 2: DEPTH HARMONIZATION
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 2: Depth Harmonization\n")
cat("============================================================\n\n")

cat("Harmonizing variable-depth samples to standard depth intervals:\n")
cat(sprintf("  - %s cm (midpoints)\n", paste(STANDARD_DEPTHS, collapse = ", ")))
cat(sprintf("  - Method: %s\n", INTERPOLATION_METHOD))

# Run Module 03: Depth Harmonization
source("03_depth_harmonization_bluecarbon.R")

cat("\n✓ Depth harmonization complete\n")
cat("  → Check outputs/plots/by_stratum/ for spline fit quality\n")

# ============================================================================
# STEP 3: LFH LAYER PROCESSING (Forest-Specific)
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 3: LFH Layer Processing (Organic Forest Floor)\n")
cat("============================================================\n\n")

if (MEASURE_LFH_LAYER) {
  cat("Processing LFH layer (Litter-Fermentation-Humus) carbon stocks...\n\n")

  # Load LFH processing module
  source("03b_lfh_layer_processing.R")

  # Process LFH data
  lfh_result <- process_lfh_layer(
    lfh_file = "data_raw/lfh_samples.csv",
    locations_file = "data_raw/core_locations.csv",
    output_dir = "data_processed",
    diagnostics_dir = "diagnostics/lfh_layer"
  )

  if (!is.null(lfh_result)) {
    cat("\n✓ LFH layer processing complete\n")
    cat(sprintf("  → LFH stocks: %.1f to %.1f Mg C/ha across strata\n",
                min(lfh_result$summary$mean_stock_Mg_ha),
                max(lfh_result$summary$mean_stock_Mg_ha)))
    cat("  → Check diagnostics/lfh_layer/ for results\n")
  }

} else {
  cat("⚠ LFH layer measurement is DISABLED in configuration\n")
  cat("  To enable: Set MEASURE_LFH_LAYER <- TRUE in blue_carbon_config.R\n")
}

# ============================================================================
# STEP 4: SPATIAL PREDICTION
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 4: Spatial Prediction (Random Forest)\n")
cat("============================================================\n\n")

cat("Generating wall-to-wall carbon stock maps using Random Forest...\n")
cat("This requires spatial covariates:\n")
cat("  - Forest age (years since disturbance)\n")
cat("  - Species composition (% conifer/deciduous)\n")
cat("  - Site productivity (site index)\n")
cat("  - Elevation, slope, aspect\n")
cat("  - Climate variables (MAT, MAP)\n")
cat("  - Soil drainage class\n\n")

# Check for covariates
if (dir.exists("covariates") && length(list.files("covariates", pattern = "\\.tif$", recursive = TRUE)) > 0) {
  cat("✓ Spatial covariates found\n\n")

  # Run Module 05: Random Forest Predictions
  source("05_raster_predictions_rf_bluecarbon.R")

  cat("\n✓ Spatial prediction complete\n")
  cat("  → Check outputs/predictions/rf/ for carbon stock maps\n")

} else {
  cat("⚠ No spatial covariates found in covariates/ directory\n")
  cat("  You can:\n")
  cat("    1. Skip spatial modeling (use field data summaries only)\n")
  cat("    2. Prepare covariate rasters and re-run this step\n")
  cat("    3. Use kriging instead (Module 04) - no covariates needed\n\n")

  # Option: Run kriging instead
  run_kriging <- readline(prompt = "Run kriging instead? (y/n): ")
  if (tolower(run_kriging) == "y") {
    source("04_raster_predictions_kriging_bluecarbon.R")
    cat("\n✓ Kriging prediction complete\n")
    cat("  → Check outputs/predictions/kriging/ for carbon stock maps\n")
  } else {
    cat("  Skipping spatial prediction - will use field data summaries only\n")
  }
}

# ============================================================================
# STEP 5: CARBON STOCK AGGREGATION
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 5: Carbon Stock Aggregation\n")
cat("============================================================\n\n")

cat("Aggregating depth-specific carbon stocks to total soil profile...\n")
cat(sprintf("  - Mineral soil: 0-100 cm (depth intervals: %s)\n",
            paste(CFI_REPORTING_DEPTHS, collapse = ", ")))
if (MEASURE_LFH_LAYER) {
  cat("  - LFH layer: Reported separately\n")
}
cat("  - Conservative estimates: 95% CI lower bound\n\n")

# Run Module 06: Carbon Stock Calculation
source("06_carbon_stock_calculation_bluecarbon.R")

cat("\n✓ Carbon stock aggregation complete\n")
cat("  → Check outputs/carbon_stocks/ for summary tables and maps\n")

# ============================================================================
# STEP 6: STANDARDS COMPLIANCE CHECKING
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("STEP 6: Standards Compliance Checking\n")
cat("============================================================\n\n")

cat("Checking compliance with forest carbon standards:\n")
cat("  - VCS VM0012 (Improved Forest Management)\n")
cat("  - VCS VM0042 (Afforestation/Reforestation)\n")
cat("  - IPCC AFOLU Guidelines (Tier 3)\n")
cat("  - Canadian Forest Service Framework\n")
cat("  - BC Forest Carbon Offset Protocol\n\n")

# Run Module 07B: Forest Carbon Standards Compliance
source("07b_forest_carbon_standards_compliance.R")

cat("\n✓ Standards compliance check complete\n")
cat("  → Check outputs/reports/ for:\n")
cat("     - standards_compliance_summary.csv\n")
cat("     - recommendations_action_plan.csv\n")

# ============================================================================
# WORKFLOW COMPLETE
# ============================================================================

cat("\n\n")
cat("============================================================\n")
cat("WORKFLOW COMPLETE!\n")
cat("============================================================\n\n")

cat("Summary of outputs:\n")
cat("  📁 data_processed/        - Processed field data\n")
cat("  📁 outputs/predictions/   - Carbon stock maps\n")
cat("  📁 outputs/carbon_stocks/ - Summary tables and aggregated stocks\n")
cat("  📁 outputs/reports/       - Compliance reports and recommendations\n")
cat("  📁 diagnostics/           - QC reports and diagnostic plots\n\n")

cat("Next steps:\n")
cat("  1. Review compliance summary and action plan\n")
cat("  2. Address any failing criteria (see recommendations_action_plan.csv)\n")
cat("  3. Generate final verification report for carbon credit project\n")
cat("  4. Plan next monitoring campaign (every %d years)\n", FOREST_MONITORING_FREQUENCY)

# Load and display key results
if (file.exists("outputs/carbon_stocks/carbon_stocks_by_stratum_rf.csv")) {
  stocks <- read.csv("outputs/carbon_stocks/carbon_stocks_by_stratum_rf.csv")

  cat("\n")
  cat("------------------------------------------------------------\n")
  cat("KEY RESULTS: Carbon Stocks by Forest Type\n")
  cat("------------------------------------------------------------\n\n")

  results_summary <- stocks %>%
    filter(stratum != "ALL") %>%
    select(stratum, n_pixels, mean_stock_0_100_Mg_ha, conservative_stock_0_100_Mg_ha, cv_pct) %>%
    mutate(across(where(is.numeric), ~round(.x, 1)))

  print(results_summary, row.names = FALSE)

  total_row <- stocks %>% filter(stratum == "ALL")
  if (nrow(total_row) > 0) {
    cat("\n")
    cat(sprintf("TOTAL PROJECT AREA ESTIMATE:\n"))
    cat(sprintf("  Mean Stock: %.1f Mg C/ha\n", total_row$mean_stock_0_100_Mg_ha))
    cat(sprintf("  Conservative Stock: %.1f Mg C/ha\n", total_row$conservative_stock_0_100_Mg_ha))
    cat(sprintf("  Coefficient of Variation: %.1f%%\n", total_row$cv_pct))
  }
}

# LFH summary
if (file.exists("data_processed/lfh_stocks_by_stratum.csv")) {
  lfh_stocks <- read.csv("data_processed/lfh_stocks_by_stratum.csv")

  cat("\n")
  cat("------------------------------------------------------------\n")
  cat("LFH LAYER (Forest Floor) Carbon Stocks\n")
  cat("------------------------------------------------------------\n\n")

  lfh_summary <- lfh_stocks %>%
    select(stratum, n_samples, mean_thickness_cm, mean_stock_Mg_ha, conservative_stock_Mg_ha) %>%
    mutate(across(where(is.numeric), ~round(.x, 1)))

  print(lfh_summary, row.names = FALSE)
}

cat("\n\n")
cat("============================================================\n")
cat(sprintf("Session completed: %s\n", Sys.time()))
cat("============================================================\n\n")

# ============================================================================
# OPTIONAL: Generate Custom Report
# ============================================================================

# Uncomment to generate a custom HTML report with all results
# rmarkdown::render(
#   "forest_carbon_report_template.Rmd",
#   output_file = sprintf("Forest_Carbon_Report_%s.html", PROJECT_NAME),
#   output_dir = "outputs/reports"
# )
