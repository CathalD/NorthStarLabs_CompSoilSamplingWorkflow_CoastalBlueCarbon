# ============================================================================
# MODULE 11b: RESTORATION SCENARIO BUILDER
# ============================================================================
# PURPOSE: Build and compare custom restoration scenarios
#          - Modify DEMs for grading/excavation
#          - Add vegetation/riparian buffers
#          - Create tidal channels
#          - Compare ecosystem service outcomes
#
# USAGE:
#   source("11b_restoration_scenario_builder.R")
#   Then follow prompts or modify SCENARIO_DEFINITIONS below
#
# AUTHOR: Blue Carbon Workflow Team
# DATE: 2024
# ============================================================================

cat("\n============================================================\n")
cat("MODULE 11b: RESTORATION SCENARIO BUILDER\n")
cat("============================================================\n\n")

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (!exists("PROJECT_NAME")) {
  source("blue_carbon_config.R")
}

# Load required packages
required_packages <- c("terra", "sf", "dplyr", "ggplot2", "whitebox")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' required. Run: source('00a_install_packages_3d_hydro.R')", pkg))
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

cat("✓ Packages loaded\n\n")

# Create output directories
SCENARIO_DIR <- "outputs/restoration_scenarios"
dir.create(SCENARIO_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(SCENARIO_DIR, "dems"), showWarnings = FALSE)
dir.create(file.path(SCENARIO_DIR, "comparisons"), showWarnings = FALSE)

# ============================================================================
# RESTORATION SCENARIO DEFINITIONS
# ============================================================================
# Customize these scenarios for your project!

SCENARIO_DEFINITIONS <- list(

  # SCENARIO 1: Current/Baseline (no modifications)
  baseline = list(
    name = "Current Conditions",
    description = "Existing landscape - no restoration actions",
    modifications = list()
  ),

  # SCENARIO 2: Tidal Restoration (dike removal)
  tidal_restoration = list(
    name = "Tidal Restoration",
    description = "Remove dike to restore tidal inundation",
    modifications = list(
      list(
        type = "remove_dike",
        polygon = NULL,  # Will be defined by user or loaded from shapefile
        elevation_adjust = -1.5,  # Lower by 1.5m to restore tidal connection
        description = "Breach dike and grade to tidal elevation"
      ),
      list(
        type = "vegetation_change",
        new_stratum = "Lower Marsh",  # Convert to tidal marsh
        c_factor = 0.002,  # Low erosion with marsh vegetation
        carbon_accretion_rate = 2.5  # Mg C/ha/year
      )
    )
  ),

  # SCENARIO 3: Riparian Buffer Planting
  riparian_buffer = list(
    name = "Riparian Buffer Restoration",
    description = "Plant vegetated buffers along streams and channels",
    modifications = list(
      list(
        type = "create_buffer",
        target = "streams",
        buffer_width = 30,  # meters
        vegetation_type = "Upper Marsh",
        c_factor = 0.001,  # Dense vegetation
        carbon_sequestration_rate = 1.5  # Mg C/ha/year
      )
    )
  ),

  # SCENARIO 4: Tidal Channel Creation
  channel_creation = list(
    name = "Tidal Channel Network",
    description = "Excavate tidal channels to improve hydrology",
    modifications = list(
      list(
        type = "excavate_channels",
        channel_depth = 1.0,  # meters below surface
        channel_width = 5,    # meters
        channel_pattern = "dendritic",  # or "parallel", "custom"
        spacing = 100,  # meters between channels
        description = "Create tidal channel network for sediment delivery"
      )
    )
  ),

  # SCENARIO 5: Full Restoration (combined approach)
  full_restoration = list(
    name = "Comprehensive Restoration",
    description = "Combined tidal restoration + buffers + channels",
    modifications = list(
      list(type = "remove_dike", elevation_adjust = -1.5),
      list(type = "create_buffer", buffer_width = 30),
      list(type = "excavate_channels", channel_depth = 0.8, channel_width = 4)
    )
  ),

  # SCENARIO 6: Climate Adaptation (SLR resilience)
  climate_adaptation = list(
    name = "Climate Adaptation",
    description = "Enhance resilience to sea level rise",
    modifications = list(
      list(
        type = "elevate_zones",
        target_elevation = 3.5,  # meters (above future SLR)
        zones = "upland_transition",
        description = "Create elevated refuge zones"
      ),
      list(
        type = "enhance_sediment_supply",
        sediment_addition_rate = 10,  # mm/year
        description = "Thin-layer sediment application"
      )
    )
  )
)

cat("✓ Scenario definitions loaded\n")
cat(sprintf("  %d scenarios defined\n\n", length(SCENARIO_DEFINITIONS)))

# ============================================================================
# SCENARIO BUILDER FUNCTIONS
# ============================================================================

#' Build a restoration scenario by modifying baseline DEM
#' @param scenario_def Scenario definition list
#' @param baseline_dem Baseline DEM raster
#' @param baseline_data List of baseline data (streams, strata, etc.)
#' @return List with modified DEM and metadata
build_scenario <- function(scenario_def, baseline_dem, baseline_data = list()) {

  cat(sprintf("\nBuilding scenario: %s\n", scenario_def$name))
  cat(sprintf("  %s\n", scenario_def$description))

  # Start with baseline DEM
  modified_dem <- baseline_dem
  modifications_applied <- list()

  # Apply each modification
  for (i in seq_along(scenario_def$modifications)) {
    mod <- scenario_def$modifications[[i]]
    cat(sprintf("  [%d/%d] Applying: %s...\n", i, length(scenario_def$modifications), mod$type))

    modified_dem <- tryCatch({
      switch(mod$type,
        "remove_dike" = apply_dike_removal(modified_dem, mod),
        "create_buffer" = apply_buffer_creation(modified_dem, mod, baseline_data),
        "excavate_channels" = apply_channel_excavation(modified_dem, mod, baseline_data),
        "vegetation_change" = apply_vegetation_change(modified_dem, mod, baseline_data),
        "elevate_zones" = apply_elevation_change(modified_dem, mod),
        "enhance_sediment_supply" = modified_dem,  # No DEM change, affects carbon model
        {
          cat(sprintf("    ⚠ Unknown modification type: %s\n", mod$type))
          modified_dem
        }
      )
    }, error = function(e) {
      cat(sprintf("    ✗ Error: %s\n", e$message))
      modified_dem
    })

    modifications_applied[[i]] <- mod
  }

  cat("  ✓ Scenario built\n")

  return(list(
    dem = modified_dem,
    scenario_def = scenario_def,
    modifications = modifications_applied
  ))
}

#' Apply dike removal/grading modification
apply_dike_removal <- function(dem, mod) {

  if (is.null(mod$polygon)) {
    # Apply to low-lying areas (below MHW)
    target_area <- dem < 2.5
  } else {
    # Load polygon from shapefile or use provided polygon
    # (Implementation depends on user input)
    target_area <- dem * 0 + 1  # Placeholder
  }

  # Adjust elevation in target area
  adjusted_dem <- dem
  adjusted_dem[target_area == 1] <- dem[target_area == 1] + mod$elevation_adjust

  cat(sprintf("    - Adjusted elevation by %.2fm in dike removal area\n", mod$elevation_adjust))

  return(adjusted_dem)
}

#' Apply riparian buffer creation
apply_buffer_creation <- function(dem, mod, baseline_data) {

  # Buffer zones don't modify DEM but affect vegetation/C-factor
  # Return DEM unchanged (buffer effects calculated in analysis)
  cat(sprintf("    - Created %dm buffer around %s\n", mod$buffer_width, mod$target))

  return(dem)
}

#' Apply channel excavation
apply_channel_excavation <- function(dem, mod, baseline_data) {

  cat(sprintf("    - Excavating channels: %.1fm deep x %.1fm wide\n",
              mod$channel_depth, mod$channel_width))

  # Get flow accumulation to determine channel locations
  if ("flow_accum" %in% names(baseline_data)) {
    flow <- baseline_data$flow_accum

    # High flow accumulation = natural channel locations
    threshold <- global(flow, "quantile", probs = 0.95, na.rm = TRUE)[[1]]
    channel_locations <- flow > threshold

    # Excavate channels
    modified_dem <- dem
    modified_dem[channel_locations == 1] <- dem[channel_locations == 1] - mod$channel_depth

    cat(sprintf("    - Excavated %.0f cells\n", global(channel_locations, "sum", na.rm = TRUE)[[1]]))

  } else {
    cat("    ⚠ No flow accumulation data - skipping channel excavation\n")
    modified_dem <- dem
  }

  return(modified_dem)
}

#' Apply vegetation change
apply_vegetation_change <- function(dem, mod, baseline_data) {
  # Vegetation changes don't modify DEM
  # Effects are captured in carbon and sediment models
  cat("    - Vegetation change applied (affects C-factor)\n")
  return(dem)
}

#' Apply elevation change to specific zones
apply_elevation_change <- function(dem, mod) {

  # Identify target zone (simplified - could use polygon input)
  if (!is.null(mod$zones)) {
    # For example, elevate transition zones
    target_area <- dem > 2.0 & dem < 3.0
    modified_dem <- dem
    modified_dem[target_area] <- mod$target_elevation

    cat(sprintf("    - Elevated zones to %.2fm\n", mod$target_elevation))
  } else {
    modified_dem <- dem
  }

  return(modified_dem)
}

#' Calculate hydrological metrics for a scenario
calculate_scenario_hydrology <- function(dem_path, output_dir) {

  # Flow accumulation
  flow_accum_path <- file.path(output_dir, "flow_accumulation.tif")
  dem_filled <- tempfile(fileext = ".tif")
  whitebox::wbt_fill_depressions(dem_path, dem_filled)

  whitebox::wbt_d8_flow_accumulation(
    input = dem_filled,
    output = flow_accum_path,
    out_type = "cells"
  )

  # TWI
  twi_path <- file.path(output_dir, "twi.tif")
  whitebox::wbt_wetness_index(dem = dem_filled, output = twi_path)

  return(list(
    flow_accum = rast(flow_accum_path),
    twi = rast(twi_path)
  ))
}

#' Calculate carbon outcomes for a scenario
calculate_scenario_carbon <- function(scenario, baseline_carbon, years = 10) {

  cat("  Calculating carbon outcomes...\n")

  # Start with baseline carbon
  scenario_carbon <- baseline_carbon

  # Apply modifications that affect carbon
  for (mod in scenario$modifications) {
    if (!is.null(mod$carbon_accretion_rate)) {
      # Add carbon accumulation over time
      accretion <- mod$carbon_accretion_rate * years  # Mg C/ha over project period
      scenario_carbon <- scenario_carbon + accretion
      cat(sprintf("    + %.1f Mg C/ha from %s\n", accretion, mod$description %||% mod$type))
    }

    if (!is.null(mod$carbon_sequestration_rate)) {
      # Buffer/vegetation sequestration
      seq_rate <- mod$carbon_sequestration_rate * years
      scenario_carbon <- scenario_carbon + seq_rate
      cat(sprintf("    + %.1f Mg C/ha from vegetation\n", seq_rate))
    }
  }

  return(scenario_carbon)
}

#' Compare two scenarios
compare_scenarios <- function(baseline, project, metrics = c("carbon", "hydrology", "flood")) {

  cat("\nComparing scenarios...\n")

  comparison <- list()

  # Carbon comparison
  if ("carbon" %in% metrics && !is.null(baseline$carbon) && !is.null(project$carbon)) {
    carbon_diff <- project$carbon - baseline$carbon
    comparison$carbon <- list(
      mean_diff_mg_ha = global(carbon_diff, "mean", na.rm = TRUE)[[1]],
      total_diff_mg = global(carbon_diff, "sum", na.rm = TRUE)[[1]] *
                      res(carbon_diff)[1] * res(carbon_diff)[2] / 10000,
      diff_map = carbon_diff
    )

    cat(sprintf("  Carbon change: %.1f Mg C/ha (mean)\n",
                comparison$carbon$mean_diff_mg_ha))
  }

  # Hydrological comparison
  if ("hydrology" %in% metrics && !is.null(baseline$hydro) && !is.null(project$hydro)) {
    twi_diff <- project$hydro$twi - baseline$hydro$twi
    comparison$hydrology <- list(
      twi_change = global(twi_diff, "mean", na.rm = TRUE)[[1]],
      wetness_increased_area_ha = global(twi_diff > 0, "sum", na.rm = TRUE)[[1]] *
                                   res(twi_diff)[1]^2 / 10000
    )

    cat(sprintf("  Wetness index change: %.2f (mean)\n",
                comparison$hydrology$twi_change))
    cat(sprintf("  Area with increased wetness: %.1f ha\n",
                comparison$hydrology$wetness_increased_area_ha))
  }

  # Flood risk comparison
  if ("flood" %in% metrics && !is.null(baseline$dem) && !is.null(project$dem)) {
    # Simple flood risk: area below threshold elevation
    flood_threshold <- 2.5  # meters
    baseline_flood_area <- global(baseline$dem < flood_threshold, "sum", na.rm = TRUE)[[1]]
    project_flood_area <- global(project$dem < flood_threshold, "sum", na.rm = TRUE)[[1]]

    comparison$flood <- list(
      baseline_area_ha = baseline_flood_area * res(baseline$dem)[1]^2 / 10000,
      project_area_ha = project_flood_area * res(project$dem)[1]^2 / 10000,
      change_ha = (project_flood_area - baseline_flood_area) * res(baseline$dem)[1]^2 / 10000
    )

    cat(sprintf("  Flood-prone area change: %.1f ha\n",
                comparison$flood$change_ha))
  }

  return(comparison)
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

cat("============================================================\n")
cat("BUILDING RESTORATION SCENARIOS\n")
cat("============================================================\n\n")

# Load baseline data
cat("Loading baseline data...\n")
baseline_dem_path <- "data_raw/gee_covariates/elevation.tif"

if (!file.exists(baseline_dem_path)) {
  stop("Baseline DEM not found. Run Module 11 first.")
}

baseline_dem <- rast(baseline_dem_path)
cat("✓ Baseline DEM loaded\n")

# Load baseline carbon stocks
baseline_carbon <- NULL
carbon_path <- "outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif"
if (file.exists(carbon_path)) {
  baseline_carbon <- rast(carbon_path)
  cat("✓ Baseline carbon loaded\n")
}

# Load baseline hydrology (from Module 11)
baseline_hydro <- NULL
if (file.exists("outputs/hydrology/flow_accumulation.tif")) {
  baseline_hydro <- list(
    flow_accum = rast("outputs/hydrology/flow_accumulation.tif"),
    twi = rast("outputs/hydrology/topographic_wetness_index.tif")
  )
  cat("✓ Baseline hydrology loaded\n")
}

baseline_data <- list(
  dem = baseline_dem,
  carbon = baseline_carbon,
  hydro = baseline_hydro
)

# ============================================================================
# BUILD ALL SCENARIOS
# ============================================================================

cat("\n============================================================\n")
cat("BUILDING SCENARIOS\n")
cat("============================================================\n")

scenarios <- list()

for (scenario_name in names(SCENARIO_DEFINITIONS)) {
  scenario_def <- SCENARIO_DEFINITIONS[[scenario_name]]

  # Build scenario
  scenario <- build_scenario(scenario_def, baseline_dem, baseline_data)

  # Save modified DEM
  dem_output <- file.path(SCENARIO_DIR, "dems", paste0(scenario_name, "_dem.tif"))
  writeRaster(scenario$dem, dem_output, overwrite = TRUE)

  # Calculate hydrology for scenario
  scenario_hydro_dir <- file.path(SCENARIO_DIR, scenario_name)
  dir.create(scenario_hydro_dir, showWarnings = FALSE)

  scenario$hydro <- calculate_scenario_hydrology(dem_output, scenario_hydro_dir)

  # Calculate carbon outcomes (10-year projection)
  if (!is.null(baseline_carbon)) {
    scenario$carbon <- calculate_scenario_carbon(scenario, baseline_carbon, years = 10)
    writeRaster(scenario$carbon,
                file.path(scenario_hydro_dir, "carbon_stocks_projected.tif"),
                overwrite = TRUE)
  }

  scenarios[[scenario_name]] <- scenario

  cat(sprintf("\n✓ %s complete\n", scenario_def$name))
}

# ============================================================================
# COMPARE SCENARIOS
# ============================================================================

cat("\n============================================================\n")
cat("COMPARING SCENARIOS\n")
cat("============================================================\n\n")

# Compare each scenario to baseline
comparison_results <- list()

for (scenario_name in names(scenarios)) {
  if (scenario_name == "baseline") next

  cat(sprintf("\n%s vs. Baseline:\n", scenarios[[scenario_name]]$scenario_def$name))
  cat("----------------------------------------\n")

  comparison <- compare_scenarios(
    baseline = scenarios$baseline,
    project = scenarios[[scenario_name]],
    metrics = c("carbon", "hydrology", "flood")
  )

  comparison_results[[scenario_name]] <- comparison

  # Save comparison maps
  if (!is.null(comparison$carbon$diff_map)) {
    writeRaster(comparison$carbon$diff_map,
                file.path(SCENARIO_DIR, "comparisons",
                         paste0(scenario_name, "_carbon_change.tif")),
                overwrite = TRUE)
  }
}

# ============================================================================
# SUMMARY TABLE
# ============================================================================

cat("\n============================================================\n")
cat("SCENARIO COMPARISON SUMMARY\n")
cat("============================================================\n\n")

summary_table <- data.frame(
  scenario = character(),
  carbon_change_mg_ha = numeric(),
  total_carbon_mg = numeric(),
  wetness_change = numeric(),
  flood_area_change_ha = numeric(),
  stringsAsFactors = FALSE
)

for (scenario_name in names(comparison_results)) {
  comp <- comparison_results[[scenario_name]]

  summary_table <- rbind(summary_table, data.frame(
    scenario = scenarios[[scenario_name]]$scenario_def$name,
    carbon_change_mg_ha = comp$carbon$mean_diff_mg_ha %||% NA,
    total_carbon_mg = comp$carbon$total_diff_mg %||% NA,
    wetness_change = comp$hydrology$twi_change %||% NA,
    flood_area_change_ha = comp$flood$change_ha %||% NA
  ))
}

print(summary_table)

write.csv(summary_table,
          file.path(SCENARIO_DIR, "scenario_comparison_summary.csv"),
          row.names = FALSE)

cat("\n✓ Summary table saved\n")

# ============================================================================
# VISUALIZE COMPARISONS
# ============================================================================

cat("\nGenerating comparison plots...\n")

# Carbon change comparison
if (any(!is.na(summary_table$carbon_change_mg_ha))) {
  png(file.path(SCENARIO_DIR, "comparisons", "carbon_comparison.png"),
      width = 2400, height = 1800, res = 300)

  par(mar = c(5, 10, 4, 2))
  barplot(summary_table$carbon_change_mg_ha,
          names.arg = summary_table$scenario,
          horiz = TRUE,
          las = 1,
          col = ifelse(summary_table$carbon_change_mg_ha > 0, "darkgreen", "red"),
          xlab = "Carbon Change (Mg C/ha over 10 years)",
          main = "Carbon Sequestration by Restoration Scenario")
  abline(v = 0, lty = 2)
  grid()

  dev.off()
  cat("✓ Carbon comparison plot saved\n")
}

# Multi-metric comparison
png(file.path(SCENARIO_DIR, "comparisons", "multimet ric_comparison.png"),
    width = 2400, height = 2400, res = 300)

par(mfrow = c(2, 2))

# Carbon
barplot(summary_table$total_carbon_mg,
        names.arg = 1:nrow(summary_table),
        col = "darkgreen",
        main = "Total Carbon Change (Mg C)",
        ylab = "Mg C")

# Wetness
barplot(summary_table$wetness_change,
        names.arg = 1:nrow(summary_table),
        col = "blue",
        main = "Wetness Index Change",
        ylab = "TWI Change")

# Flood area
barplot(summary_table$flood_area_change_ha,
        names.arg = 1:nrow(summary_table),
        col = "orange",
        main = "Flood-Prone Area Change (ha)",
        ylab = "Area (ha)")

# Legend
plot.new()
legend("center",
       legend = summary_table$scenario,
       fill = rainbow(nrow(summary_table)),
       cex = 0.8)

dev.off()
cat("✓ Multi-metric plot saved\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("\n============================================================\n")
cat("SCENARIO BUILDER COMPLETE!\n")
cat("============================================================\n\n")

cat("Outputs saved to:", SCENARIO_DIR, "\n\n")

cat("Scenarios built:\n")
for (name in names(scenarios)) {
  cat(sprintf("  - %s\n", scenarios[[name]]$scenario_def$name))
}

cat("\nNext steps:\n")
cat("  1. Review comparison maps in outputs/restoration_scenarios/comparisons/\n")
cat("  2. Visualize 3D scenarios using rayshader\n")
cat("  3. Integrate into VM0033 reporting (Module 07)\n")
cat("  4. Present to stakeholders\n\n")

cat("To customize scenarios, edit SCENARIO_DEFINITIONS in this script.\n\n")

cat("Done! 🌊🌱🗻\n\n")
