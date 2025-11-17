# ============================================================================
# MODULE 11: DOWNSTREAM IMPACTS & WIDER CO-BENEFITS
# ============================================================================
# Purpose: Comprehensive downstream impact assessment including:
#   - Hydrological routing & catchment delineation
#   - Sediment export reduction (RUSLE + NDR)
#   - Nutrient load reduction (N, P export coefficients + NDR)
#   - Flood mitigation / peak flow reduction (Curve Number method)
#   - Uncertainty propagation & sensitivity analysis
#   - Co-benefits valuation
#
# This module extends the Blue Carbon MRV workflow to quantify broader
# restoration benefits beyond carbon sequestration, supporting comprehensive
# impact reporting and ecosystem service valuation.
#
# Prerequisites:
#   - Completed carbon stock analysis (Modules 01-06)
#   - DEM and hydrology data (from GEE: GEE_EXPORT_HYDROLOGY_DATA.js)
#   - Points of Interest defined (data_raw/poi/points_of_interest.csv)
#   - Restoration mask created (outputs/predictions/restoration_mask.tif)
#
# Execution order:
#   1. Catchment delineation & flow routing
#   2. Sediment export analysis
#   3. Nutrient delivery analysis
#   4. Hydrological analysis (flood mitigation)
#   5. Uncertainty propagation
#   6. Co-benefits valuation & summary reporting
#
# Author: NorthStar Labs Blue Carbon Team
# Date: 2024-11
# VM0033 Compliance: Extended impact metrics for comprehensive MRV
# ============================================================================

# Load configuration
source("blue_carbon_config.R")

# ============================================================================
# HEADER & VALIDATION
# ============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("  MODULE 11: DOWNSTREAM IMPACTS & WIDER CO-BENEFITS ANALYSIS\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("\n")
cat("Project:", PROJECT_NAME, "\n")
cat("Location:", PROJECT_LOCATION, "\n")
cat("Scenario:", PROJECT_SCENARIO, "\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("\n")

# Check if downstream impacts are enabled
if (!ENABLE_DOWNSTREAM_IMPACTS) {
  cat("⚠ Downstream impact modeling is DISABLED in configuration.\n")
  cat("  To enable, set ENABLE_DOWNSTREAM_IMPACTS = TRUE in blue_carbon_config.R\n\n")
  stop("Module 11 requires downstream impacts to be enabled.")
}

cat("✓ Downstream impact modeling is ENABLED\n\n")

# Check prerequisites
cat("Checking prerequisites...\n")

prerequisite_files <- list(
  "DEM" = "data_raw/hydrology/dem.tif",
  "POI file" = POI_FILE,
  "Stratum masks" = "data_raw/gee_strata/"
)

all_present <- TRUE
for (item_name in names(prerequisite_files)) {
  item_path <- prerequisite_files[[item_name]]
  if (file.exists(item_path) || dir.exists(item_path)) {
    cat("  ✓", item_name, "\n")
  } else {
    cat("  ✗", item_name, "NOT FOUND:", item_path, "\n")
    all_present <- FALSE
  }
}

if (!all_present) {
  cat("\n⚠ Missing prerequisite data. Please:\n")
  cat("  1. Export DEM from GEE using GEE_EXPORT_HYDROLOGY_DATA.js\n")
  cat("  2. Create points_of_interest.csv (see template in data_raw/poi/)\n")
  cat("  3. Ensure stratum masks exist from Module 00A\n\n")
  stop("Prerequisites not met.")
}

cat("  All prerequisites present ✓\n\n")

# Display enabled impact types
cat("Impact types to analyze:\n")
for (impact_name in names(IMPACTS_ENABLED)) {
  status <- if (IMPACTS_ENABLED[[impact_name]]) "✓ ENABLED" else "  disabled"
  cat(" ", status, "-", impact_name, "\n")
}
cat("\n")

# ============================================================================
# EXECUTION WORKFLOW
# ============================================================================

cat("═══════════════════════════════════════════════════════════════\n")
cat("STARTING DOWNSTREAM IMPACT ANALYSIS WORKFLOW\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

start_time <- Sys.time()

# --------------------------------------------------------------------------
# STEP 1: CATCHMENT DELINEATION & FLOW ROUTING
# --------------------------------------------------------------------------

cat("\n")
cat("────────────────────────────────────────────────────────────────\n")
cat("STEP 1: CATCHMENT DELINEATION & FLOW ROUTING\n")
cat("────────────────────────────────────────────────────────────────\n\n")

step_start <- Sys.time()

tryCatch({
  source("modules/downstream/delineate_catchments.R")
  cat("\n✓ Step 1 completed in", round(difftime(Sys.time(), step_start, units = "mins"), 1), "minutes\n")
}, error = function(e) {
  cat("\n✗ Step 1 FAILED:", conditionMessage(e), "\n")
  stop("Cannot proceed without catchment delineation.")
})

# --------------------------------------------------------------------------
# STEP 2: SEDIMENT EXPORT ANALYSIS
# --------------------------------------------------------------------------

if (IMPACTS_ENABLED$sediment_loads) {
  cat("\n")
  cat("────────────────────────────────────────────────────────────────\n")
  cat("STEP 2: SEDIMENT EXPORT & DELIVERY\n")
  cat("────────────────────────────────────────────────────────────────\n\n")

  step_start <- Sys.time()

  tryCatch({
    source("modules/downstream/sediment_export.R")
    cat("\n✓ Step 2 completed in", round(difftime(Sys.time(), step_start, units = "mins"), 1), "minutes\n")
  }, error = function(e) {
    cat("\n✗ Step 2 WARNING:", conditionMessage(e), "\n")
    cat("  Continuing with remaining analyses...\n")
  })
} else {
  cat("\n⊘ Skipping sediment analysis (disabled)\n")
}

# --------------------------------------------------------------------------
# STEP 3: NUTRIENT DELIVERY ANALYSIS
# --------------------------------------------------------------------------

if (IMPACTS_ENABLED$nutrient_loads) {
  cat("\n")
  cat("────────────────────────────────────────────────────────────────\n")
  cat("STEP 3: NUTRIENT EXPORT & DELIVERY (N, P)\n")
  cat("────────────────────────────────────────────────────────────────\n\n")

  step_start <- Sys.time()

  tryCatch({
    source("modules/downstream/nutrient_ndr.R")
    cat("\n✓ Step 3 completed in", round(difftime(Sys.time(), step_start, units = "mins"), 1), "minutes\n")
  }, error = function(e) {
    cat("\n✗ Step 3 WARNING:", conditionMessage(e), "\n")
    cat("  Continuing with remaining analyses...\n")
  })
} else {
  cat("\n⊘ Skipping nutrient analysis (disabled)\n")
}

# --------------------------------------------------------------------------
# STEP 4: HYDROLOGICAL ANALYSIS (FLOOD MITIGATION)
# --------------------------------------------------------------------------

if (IMPACTS_ENABLED$peak_flow) {
  cat("\n")
  cat("────────────────────────────────────────────────────────────────\n")
  cat("STEP 4: HYDROLOGICAL ANALYSIS & FLOOD MITIGATION\n")
  cat("────────────────────────────────────────────────────────────────\n\n")

  step_start <- Sys.time()

  tryCatch({
    source("modules/downstream/peakflow_cn.R")
    cat("\n✓ Step 4 completed in", round(difftime(Sys.time(), step_start, units = "mins"), 1), "minutes\n")
  }, error = function(e) {
    cat("\n✗ Step 4 WARNING:", conditionMessage(e), "\n")
    cat("  Continuing with remaining analyses...\n")
  })
} else {
  cat("\n⊘ Skipping hydrological analysis (disabled)\n")
}

# --------------------------------------------------------------------------
# STEP 5: UNCERTAINTY PROPAGATION
# --------------------------------------------------------------------------

cat("\n")
cat("────────────────────────────────────────────────────────────────\n")
cat("STEP 5: UNCERTAINTY PROPAGATION & SENSITIVITY ANALYSIS\n")
cat("────────────────────────────────────────────────────────────────\n\n")

step_start <- Sys.time()

# Check if we have results to propagate uncertainty for
results_exist <- file.exists("outputs/downstream/tables/sediment_reduction_by_poi.csv") ||
                 file.exists("outputs/downstream/tables/nutrient_reduction_by_poi.csv") ||
                 file.exists("outputs/downstream/tables/flood_mitigation_by_poi.csv")

if (results_exist) {
  tryCatch({
    source("modules/downstream/uncertainty.R")
    cat("\n✓ Step 5 completed in", round(difftime(Sys.time(), step_start, units = "mins"), 1), "minutes\n")
  }, error = function(e) {
    cat("\n✗ Step 5 WARNING:", conditionMessage(e), "\n")
    cat("  Proceeding without uncertainty analysis...\n")
  })
} else {
  cat("⊘ No impact results found - skipping uncertainty analysis\n")
}

# --------------------------------------------------------------------------
# STEP 6: CO-BENEFITS VALUATION
# --------------------------------------------------------------------------

if (IMPACTS_ENABLED$ecosystem_services && ENABLE_VALUATION) {
  cat("\n")
  cat("────────────────────────────────────────────────────────────────\n")
  cat("STEP 6: ECOSYSTEM SERVICE VALUATION\n")
  cat("────────────────────────────────────────────────────────────────\n\n")

  step_start <- Sys.time()

  # Simple co-benefits valuation
  library(dplyr)

  valuation_results <- data.frame()

  # Load impact results if available
  if (file.exists("outputs/downstream/tables/sediment_reduction_by_poi.csv")) {
    sediment_data <- read.csv("outputs/downstream/tables/sediment_reduction_by_poi.csv")

    sediment_value <- sum(sediment_data$sediment_reduction_y5_t_yr, na.rm = TRUE) *
                     ECOSYSTEM_SERVICE_VALUES$sediment_reduction_per_tonne

    valuation_results <- rbind(valuation_results, data.frame(
      service = "Sediment reduction (water quality)",
      annual_value_cad = sediment_value,
      units = "$ / yr"
    ))
  }

  if (file.exists("outputs/downstream/tables/nutrient_reduction_by_poi.csv")) {
    nutrient_data <- read.csv("outputs/downstream/tables/nutrient_reduction_by_poi.csv")

    n_value <- sum(nutrient_data$n_reduction_kg_yr, na.rm = TRUE) *
               ECOSYSTEM_SERVICE_VALUES$nitrogen_reduction_per_kg

    p_value <- sum(nutrient_data$p_reduction_kg_yr, na.rm = TRUE) *
               ECOSYSTEM_SERVICE_VALUES$phosphorus_reduction_per_kg

    valuation_results <- rbind(valuation_results, data.frame(
      service = c("Nitrogen reduction (eutrophication avoided)", "Phosphorus reduction (eutrophication avoided)"),
      annual_value_cad = c(n_value, p_value),
      units = "$ / yr"
    ))
  }

  if (file.exists("outputs/downstream/tables/flood_mitigation_by_poi.csv")) {
    flood_data <- read.csv("outputs/downstream/tables/flood_mitigation_by_poi.csv")

    flood_value <- sum(flood_data$peak_flow_reduction_m3s, na.rm = TRUE) *
                   ECOSYSTEM_SERVICE_VALUES$flood_damage_avoided_per_m3

    valuation_results <- rbind(valuation_results, data.frame(
      service = "Flood damage avoided",
      annual_value_cad = flood_value,
      units = "$ / yr"
    ))
  }

  # Calculate NPV over project lifetime
  valuation_results$npv_30yr_cad <- valuation_results$annual_value_cad *
    ((1 - (1 + DISCOUNT_RATE)^(-VALUATION_HORIZON)) / DISCOUNT_RATE)

  valuation_results <- valuation_results %>%
    mutate(across(where(is.numeric), ~ round(.x, 0)))

  write.csv(valuation_results, "outputs/downstream/tables/ecosystem_service_valuation.csv", row.names = FALSE)

  cat("\nEcosystem Service Valuation Summary:\n")
  cat("────────────────────────────────────────────────────────────────\n")
  print(valuation_results)
  cat("\n")
  cat("Total Annual Value: $", format(sum(valuation_results$annual_value_cad), big.mark = ","), "CAD/yr\n", sep = "")
  cat("Total NPV (30 years @ ", DISCOUNT_RATE * 100, "% discount): $",
      format(sum(valuation_results$npv_30yr_cad), big.mark = ","), "CAD\n\n", sep = "")

  cat("✓ Step 6 completed in", round(difftime(Sys.time(), step_start, units = "mins"), 1), "minutes\n")

} else {
  cat("\n⊘ Skipping ecosystem service valuation (disabled)\n")
}

# ============================================================================
# FINAL SUMMARY & REPORTING
# ============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════\n")
cat("DOWNSTREAM IMPACT ANALYSIS COMPLETE!\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

total_time <- difftime(Sys.time(), start_time, units = "mins")
cat("Total execution time:", round(total_time, 1), "minutes\n\n")

cat("Output Summary:\n")
cat("────────────────────────────────────────────────────────────────\n")

output_files <- list(
  "Catchment delineation" = "outputs/downstream/catchments_by_poi.shp",
  "Flow routing" = "outputs/downstream/flow_accumulation.tif",
  "Sediment analysis" = "outputs/downstream/tables/sediment_reduction_by_poi.csv",
  "Nutrient analysis" = "outputs/downstream/tables/nutrient_reduction_by_poi.csv",
  "Flood mitigation" = "outputs/downstream/tables/flood_mitigation_by_poi.csv",
  "Uncertainty analysis" = "outputs/downstream/tables/uncertainty_intervals_by_metric.csv",
  "Service valuation" = "outputs/downstream/tables/ecosystem_service_valuation.csv"
)

for (output_name in names(output_files)) {
  output_path <- output_files[[output_name]]
  if (file.exists(output_path)) {
    cat("  ✓", output_name, "\n")
  } else {
    cat("  ⊘", output_name, "(not generated)\n")
  }
}

cat("\n")
cat("Key Outputs Directory:\n")
cat("  outputs/downstream/\n")
cat("    ├── tables/          # CSV summary tables\n")
cat("    ├── maps/            # Visualization maps (PNG)\n")
cat("    ├── *.tif            # Raster outputs\n")
cat("    └── *.shp            # Vector outputs\n\n")

cat("Next Steps:\n")
cat("  1. Review catchment boundaries and impact estimates\n")
cat("  2. Validate results against field observations (if available)\n")
cat("  3. Incorporate uncertainty bounds into MRV reporting\n")
cat("  4. Run Module 07b for comprehensive standards compliance\n")
cat("  5. Consider additional analyses:\n")
cat("     - BACI attribution (modules/downstream/attribution_baci.R)\n")
cat("     - Habitat connectivity (modules/downstream/habitat_connectivity.R)\n\n")

cat("═══════════════════════════════════════════════════════════════\n\n")
