# ============================================================================
# MODULE 11 TUTORIAL - EXECUTABLE SCRIPT
# ============================================================================
# Chemainus Estuary 3D Ecosystem & Hydrological Modeling
#
# This script walks through the complete Module 11 workflow
# Run sections sequentially by highlighting and pressing Ctrl+Enter (Cmd+Enter on Mac)
#
# Estimated time: 2-4 hours
# ============================================================================

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║   MODULE 11 TUTORIAL: CHEMAINUS ESTUARY                      ║\n")
cat("║   3D Ecosystem & Hydrological Modeling                       ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

# ============================================================================
# SETUP
# ============================================================================

# Check working directory
if (!file.exists("blue_carbon_config.R")) {
  cat("⚠️  Please set working directory to project root:\n")
  cat("   setwd('/path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon')\n\n")
  stop("Wrong working directory")
}

cat("✓ Working directory correct\n\n")

# ============================================================================
# PART 1: INSTALLATION (Run once)
# ============================================================================

cat("════════════════════════════════════════════════════════════════\n")
cat("PART 1: INSTALLATION\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Uncomment if packages not yet installed:
# source("00a_install_packages_3d_hydro.R")

# Load required packages
required_packages <- c("terra", "sf", "dplyr", "ggplot2",
                       "rayshader", "whitebox", "rgl", "plotly", "jsonlite")

cat("Loading packages...\n")
for (pkg in required_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
    cat(sprintf("  ✓ %s\n", pkg))
  } else {
    cat(sprintf("  ✗ %s NOT INSTALLED\n", pkg))
    cat("    Run: source('00a_install_packages_3d_hydro.R')\n")
  }
}

# Verify WhiteboxTools
if (requireNamespace("whitebox", quietly = TRUE)) {
  wbt_ver <- tryCatch({
    whitebox::wbt_version()
  }, error = function(e) {
    "Not installed"
  })

  cat(sprintf("\nWhiteboxTools: %s\n", wbt_ver))

  if (wbt_ver == "Not installed") {
    cat("  Installing WhiteboxTools...\n")
    whitebox::install_whitebox()
  }
}

cat("\n✓ Setup complete\n\n")
readline(prompt = "Press [Enter] to continue...")

# ============================================================================
# PART 2: DATA PREPARATION
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 2: DATA PREPARATION\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Check for required files
required_files <- c(
  dem = "data_raw/gee_covariates/elevation.tif",
  cores = "data_raw/field_cores.csv",
  carbon = "outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif"
)

data_status <- list()

cat("Checking required files:\n")
for (name in names(required_files)) {
  exists <- file.exists(required_files[[name]])
  cat(sprintf("  %s %s: %s\n",
              ifelse(exists, "✓", "✗"),
              name,
              required_files[[name]]))
  data_status[[name]] <- exists
}

# Download DEM if missing
if (!data_status$dem) {
  cat("\n⚠️  DEM not found. Downloading for Chemainus Estuary...\n")

  if (requireNamespace("elevatr", quietly = TRUE)) {
    # Chemainus Estuary bounding box
    bbox <- st_bbox(c(
      xmin = -123.75,
      ymin = 49.67,
      xmax = -123.70,
      ymax = 49.71
    ), crs = 4326)

    bbox_sf <- st_as_sfc(bbox)

    cat("  Downloading DEM from AWS Terrain Tiles...\n")
    cat("  (This may take a minute...)\n")

    dem_download <- elevatr::get_elev_raster(bbox_sf, z = 13, src = "aws")

    # Convert and save
    dem <- rast(dem_download)
    dir.create("data_raw/gee_covariates", recursive = TRUE, showWarnings = FALSE)
    writeRaster(dem, required_files$dem, overwrite = TRUE)

    cat("  ✓ DEM downloaded and saved\n")
    data_status$dem <- TRUE
  } else {
    cat("  ✗ elevatr package not available\n")
    cat("    Install: install.packages('elevatr')\n")
  }
}

# Load and visualize DEM
if (data_status$dem) {
  dem <- rast(required_files$dem)

  cat("\n────────────────────────────────────────\n")
  cat("DEM STATISTICS:\n")
  cat("────────────────────────────────────────\n")
  cat(sprintf("Resolution:  %.1f x %.1f meters\n", res(dem)[1], res(dem)[2]))
  cat(sprintf("Dimensions:  %d x %d cells\n", ncol(dem), nrow(dem)))
  cat(sprintf("Extent:      %.2f ha\n",
              ncol(dem) * nrow(dem) * res(dem)[1] * res(dem)[2] / 10000))
  cat(sprintf("Elevation:   %.2f to %.2f m\n",
              global(dem, "min", na.rm = TRUE)[[1]],
              global(dem, "max", na.rm = TRUE)[[1]]))
  cat("────────────────────────────────────────\n\n")

  # Quick visualization
  plot(dem, main = "Chemainus Estuary - Elevation (m CGVD2013)")

  # Add field cores if available
  if (data_status$cores) {
    cores <- read.csv(required_files$cores)
    if (all(c("longitude", "latitude") %in% names(cores))) {
      cores_sf <- st_as_sf(cores, coords = c("longitude", "latitude"), crs = 4326)
      cores_sf <- st_transform(cores_sf, crs(dem))
      plot(st_geometry(cores_sf), add = TRUE, pch = 21, bg = "red", cex = 1.5)
      cat(sprintf("✓ Plotted %d field core locations\n", nrow(cores)))
    }
  }
}

cat("\n")
readline(prompt = "Press [Enter] to continue...")

# ============================================================================
# PART 3: CHEMAINUS CONFIGURATION
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 3: SITE-SPECIFIC CONFIGURATION\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Chemainus Estuary parameters
# Source: Canadian Hydrographic Service, Pacific Climate Impacts Consortium

cat("Setting Chemainus Estuary parameters:\n\n")

# Tidal parameters (from CHS Station 7907)
CONFIG_TIDAL <- list(
  enable = TRUE,
  mhw_elevation = 2.35,      # Mean High Water (m CGVD2013)
  mhhw_elevation = 2.85,     # Mean Higher High Water
  tidal_range = 3.45,        # Mean tidal range
  slr_scenarios = c(
    0,      # Current
    0.28,   # 2050 low emissions (SSP1-2.6)
    0.46,   # 2050 high emissions (SSP5-8.5)
    0.98,   # 2100 low emissions
    1.63    # 2100 high emissions
  ),
  storm_surge = 1.2,         # 1:100 year event
  datum_offset = 0           # DEM in CGVD2013
)

cat("✓ Tidal parameters:\n")
cat(sprintf("    MHW: %.2f m\n", CONFIG_TIDAL$mhw_elevation))
cat(sprintf("    Tidal range: %.2f m\n", CONFIG_TIDAL$tidal_range))

# Sediment transport parameters
CONFIG_SEDIMENT <- list(
  enable = TRUE,
  method = "RUSLE",
  R_factor = 180,            # Rainfall erosivity (East VI)
  K_factor_default = 0.28,   # Sandy-loam coastal soils
  C_factor_by_stratum = list(
    "Upper Marsh" = 0.001,
    "Mid Marsh" = 0.002,
    "Lower Marsh" = 0.003,
    "Underwater Vegetation" = 0.0001,
    "Open Water" = 1.0
  ),
  P_factor = 1.0,
  deposition_model = TRUE
)

cat("✓ Sediment parameters:\n")
cat(sprintf("    R-factor: %d (moderate rainfall)\n", CONFIG_SEDIMENT$R_factor))
cat(sprintf("    K-factor: %.2f (sandy-loam)\n", CONFIG_SEDIMENT$K_factor_default))

# Riparian buffer parameters
CONFIG_BUFFER <- list(
  enable = TRUE,
  buffer_widths = c(15, 30, 50),  # BC Riparian Areas Regulation
  sediment_trap_efficiency = 0.75,
  nutrient_removal_rate = 0.60,
  carbon_sequestration_rate = 1.8  # From BC restoration studies
)

cat("✓ Buffer parameters:\n")
cat(sprintf("    Test widths: %s m\n", paste(CONFIG_BUFFER$buffer_widths, collapse = ", ")))
cat(sprintf("    C sequestration: %.1f Mg C/ha/year\n",
            CONFIG_BUFFER$carbon_sequestration_rate))

# Hydrological parameters
CONFIG_HYDRO <- list(
  flow_accumulation = TRUE,
  wetness_index = TRUE,
  stream_network = TRUE,
  watershed_delineation = FALSE,
  stream_threshold = 500,    # Lower for small estuaries
  slope_percent = TRUE
)

cat("✓ Hydrology parameters:\n")
cat(sprintf("    Stream threshold: %d cells\n", CONFIG_HYDRO$stream_threshold))

# 3D Visualization parameters
CONFIG_3D <- list(
  render_3d = TRUE,
  render_resolution = 1200,
  z_scale = 8,               # Higher for flat coastal sites
  water_detect = TRUE,
  save_snapshots = TRUE,
  create_animations = FALSE
)

cat("✓ 3D visualization:\n")
cat(sprintf("    Z-scale: %dx (vertical exaggeration)\n", CONFIG_3D$z_scale))
cat(sprintf("    Save snapshots: %s\n", CONFIG_3D$save_snapshots))

cat("\n✓ Configuration complete\n\n")
readline(prompt = "Press [Enter] to continue...")

# ============================================================================
# PART 4: RUN HYDROLOGICAL ANALYSIS
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 4: HYDROLOGICAL ANALYSIS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

cat("Running Module 11 core analysis...\n")
cat("(This will take 5-15 minutes)\n\n")

# Load configurations
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
}

# Create output directories
dirs <- c(
  "outputs/3d_models/renders",
  "outputs/hydrology",
  "outputs/sediment",
  "outputs/tidal",
  "outputs/riparian_buffers"
)

for (dir in dirs) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

cat("✓ Output directories created\n\n")

# Run Module 11
cat("────────────────────────────────────────\n")
cat("EXECUTING MODULE 11\n")
cat("────────────────────────────────────────\n")

tryCatch({
  source("11_3d_ecosystem_modeling.R")
  cat("\n✓✓✓ MODULE 11 COMPLETE!\n\n")
}, error = function(e) {
  cat(sprintf("\n✗ Error running Module 11: %s\n", e$message))
  cat("  Check that all required data files exist\n")
})

readline(prompt = "Press [Enter] to review outputs...")

# ============================================================================
# PART 5: REVIEW HYDROLOGICAL OUTPUTS
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 5: REVIEWING HYDROLOGICAL OUTPUTS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Load outputs
hydro_files <- c(
  flow = "outputs/hydrology/flow_accumulation.tif",
  twi = "outputs/hydrology/topographic_wetness_index.tif",
  streams = "outputs/hydrology/stream_network.tif"
)

if (all(file.exists(hydro_files))) {

  flow_accum <- rast(hydro_files$flow)
  twi <- rast(hydro_files$twi)
  streams <- rast(hydro_files$streams)

  # Visualize
  par(mfrow = c(2, 2))

  plot(dem, main = "Elevation (m)", col = terrain.colors(100))

  plot(log10(flow_accum + 1),
       main = "Flow Accumulation (log scale)",
       col = hcl.colors(100, "Blues", rev = TRUE))

  plot(twi,
       main = "Topographic Wetness Index",
       col = hcl.colors(100, "Spectral", rev = FALSE))

  plot(dem, main = "Stream Network", col = terrain.colors(100))
  plot(streams, add = TRUE, col = "blue", legend = FALSE)

  # Calculate statistics
  cat("────────────────────────────────────────\n")
  cat("HYDROLOGICAL METRICS:\n")
  cat("────────────────────────────────────────\n")

  stream_cells <- global(streams, "sum", na.rm = TRUE)[[1]]
  stream_length_km <- stream_cells * res(dem)[1] / 1000

  cat(sprintf("Stream network:    %.2f km\n", stream_length_km))
  cat(sprintf("Mean slope:        %.1f%%\n",
              global(rast("outputs/hydrology/slope.tif"), "mean", na.rm = TRUE)[[1]]))
  cat(sprintf("Mean TWI:          %.2f\n",
              global(twi, "mean", na.rm = TRUE)[[1]]))

  # High wetness areas
  twi_threshold <- global(twi, "quantile", probs = 0.75, na.rm = TRUE)[[1]]
  wet_areas <- twi > twi_threshold
  wet_area_ha <- global(wet_areas, "sum", na.rm = TRUE)[[1]] * res(dem)[1]^2 / 10000

  cat(sprintf("High wetness area: %.1f ha (TWI > %.2f)\n", wet_area_ha, twi_threshold))
  cat("────────────────────────────────────────\n\n")

  cat("💡 INTERPRETATION:\n")
  cat("   High wetness areas are priority sites for wetland restoration.\n")
  cat("   These areas have natural water accumulation and drainage.\n\n")

} else {
  cat("⚠️  Hydrological outputs not found\n")
  cat("   Module 11 may not have completed successfully\n\n")
}

readline(prompt = "Press [Enter] to continue...")

# ============================================================================
# PART 6: TIDAL FLOODING ANALYSIS
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 6: TIDAL FLOODING & SEA LEVEL RISE\n")
cat("════════════════════════════════════════════════════════════════\n\n")

# Load inundation summary
if (file.exists("outputs/tidal/inundation_summary.csv")) {

  inund_summary <- read.csv("outputs/tidal/inundation_summary.csv")

  cat("────────────────────────────────────────────────────────────────\n")
  cat("INUNDATION SCENARIOS:\n")
  cat("────────────────────────────────────────────────────────────────\n")

  print(inund_summary[, c("scenario", "water_level_m", "inundated_area_ha")])

  cat("\n")

  # Calculate changes
  baseline_area <- inund_summary$inundated_area_ha[1]

  cat("CHANGES FROM CURRENT (MHW):\n")
  for (i in 2:nrow(inund_summary)) {
    change_ha <- inund_summary$inundated_area_ha[i] - baseline_area
    change_pct <- (change_ha / baseline_area) * 100

    cat(sprintf("  %s: +%.1f ha (+%.0f%%)\n",
                inund_summary$scenario[i],
                change_ha,
                change_pct))
  }

  cat("\n💡 KEY FINDINGS:\n")

  # Find 2050 and 2100 scenarios
  slr_2050 <- inund_summary[grep("0p46", inund_summary$scenario), ]
  slr_2100 <- inund_summary[grep("1p63", inund_summary$scenario), ]

  if (nrow(slr_2050) > 0) {
    change_2050 <- slr_2050$inundated_area_ha - baseline_area
    cat(sprintf("   By 2050: +%.1f ha additional inundation\n", change_2050))
  }

  if (nrow(slr_2100) > 0) {
    change_2100 <- slr_2100$inundated_area_ha - baseline_area
    cat(sprintf("   By 2100: +%.1f ha additional inundation\n", change_2100))
  }

  cat("\n   → Design restoration to accommodate 2050 SLR scenario\n")
  cat("   → Monitor accretion rates to ensure marshes keep pace\n\n")

  # Visualize key scenarios
  par(mfrow = c(2, 2))

  plot(dem, main = "Elevation", col = terrain.colors(100))

  plot(rast("outputs/tidal/inundation_MHW.tif"),
       main = "Current MHW",
       col = c("gray90", "lightblue"))

  if (file.exists("outputs/tidal/inundation_SLR_0p46m.tif")) {
    plot(rast("outputs/tidal/inundation_SLR_0p46m.tif"),
         main = "2050 SLR (+0.46m)",
         col = c("gray90", "blue"))
  }

  if (file.exists("outputs/tidal/inundation_SLR_1p63m.tif")) {
    plot(rast("outputs/tidal/inundation_SLR_1p63m.tif"),
         main = "2100 SLR (+1.63m)",
         col = c("gray90", "darkblue"))
  }

} else {
  cat("⚠️  Tidal outputs not found\n\n")
}

readline(prompt = "Press [Enter] to continue...")

# ============================================================================
# PART 7: RIPARIAN BUFFER ANALYSIS
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 7: RIPARIAN BUFFER EFFECTIVENESS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

if (file.exists("outputs/riparian_buffers/buffer_effectiveness_summary.csv")) {

  buffer_results <- read.csv("outputs/riparian_buffers/buffer_effectiveness_summary.csv")

  cat("────────────────────────────────────────────────────────────────\n")
  cat("BUFFER EFFECTIVENESS:\n")
  cat("────────────────────────────────────────────────────────────────\n")

  print(buffer_results)

  cat("\n💡 INTERPRETATION:\n")

  # Find optimal buffer width (highest carbon:area ratio)
  if ("carbon_sequestration_mg_yr" %in% names(buffer_results)) {
    # Calculate efficiency (Mg C per meter of buffer width)
    buffer_results$efficiency <- buffer_results$carbon_sequestration_mg_yr /
                                  buffer_results$buffer_width_m

    optimal_idx <- which.max(buffer_results$efficiency)

    cat(sprintf("   Most efficient buffer: %dm\n",
                buffer_results$buffer_width_m[optimal_idx]))
    cat(sprintf("     - Sediment reduction: %.0f%%\n",
                buffer_results$reduction_pct[optimal_idx]))
    cat(sprintf("     - Carbon sequestration: %.1f Mg C/year\n",
                buffer_results$carbon_sequestration_mg_yr[optimal_idx]))
  }

  # BC Riparian Areas Regulation recommends 30m
  recommended_30m <- buffer_results[buffer_results$buffer_width_m == 30, ]
  if (nrow(recommended_30m) > 0) {
    cat(sprintf("\n   BC Regulation (30m buffer):\n"))
    cat(sprintf("     - Sediment trapped: %.0f tons/year\n",
                recommended_30m$sediment_trapped_tons_yr))
    cat(sprintf("     - Reduction: %.0f%%\n",
                recommended_30m$reduction_pct))
  }

  cat("\n")

  # Load and display effectiveness curve
  if (file.exists("outputs/riparian_buffers/buffer_effectiveness_curve.png")) {
    cat("✓ Effectiveness curve saved:\n")
    cat("  outputs/riparian_buffers/buffer_effectiveness_curve.png\n\n")
  }

} else {
  cat("⚠️  Buffer analysis outputs not found\n\n")
}

readline(prompt = "Press [Enter] to continue to restoration scenarios...")

# ============================================================================
# PART 8: RESTORATION SCENARIOS
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 8: RESTORATION SCENARIO MODELING\n")
cat("════════════════════════════════════════════════════════════════\n\n")

cat("Running Module 11b - Scenario Builder...\n")
cat("(This will take 10-20 minutes)\n\n")

tryCatch({
  source("11b_restoration_scenario_builder.R")
  cat("\n✓✓✓ SCENARIO BUILDER COMPLETE!\n\n")
}, error = function(e) {
  cat(sprintf("\n✗ Error running scenario builder: %s\n", e$message))
})

readline(prompt = "Press [Enter] to review scenarios...")

# ============================================================================
# PART 9: SCENARIO COMPARISON
# ============================================================================

cat("\n════════════════════════════════════════════════════════════════\n")
cat("PART 9: SCENARIO COMPARISON & RECOMMENDATIONS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

if (file.exists("outputs/restoration_scenarios/scenario_comparison_summary.csv")) {

  comparison <- read.csv("outputs/restoration_scenarios/scenario_comparison_summary.csv")

  cat("────────────────────────────────────────────────────────────────\n")
  cat("SCENARIO COMPARISON (10-YEAR PROJECTIONS):\n")
  cat("────────────────────────────────────────────────────────────────\n\n")

  print(comparison)

  cat("\n")

  # Rank scenarios
  if ("total_carbon_mg" %in% names(comparison)) {
    comparison$rank_carbon <- rank(-comparison$total_carbon_mg, na.last = TRUE)
  }

  if ("wetness_change" %in% names(comparison)) {
    comparison$rank_wetness <- rank(-comparison$wetness_change, na.last = TRUE)
  }

  if (all(c("rank_carbon", "rank_wetness") %in% names(comparison))) {
    comparison$rank_overall <- comparison$rank_carbon + comparison$rank_wetness
    comparison_ranked <- comparison[order(comparison$rank_overall), ]

    cat("────────────────────────────────────────────────────────────────\n")
    cat("RECOMMENDED SCENARIO:\n")
    cat("────────────────────────────────────────────────────────────────\n")
    cat(sprintf("  %s\n", comparison_ranked$scenario[1]))
    cat("────────────────────────────────────────────────────────────────\n")
    cat(sprintf("  Carbon gain:        %.1f Mg C/ha\n",
                comparison_ranked$carbon_change_mg_ha[1]))
    cat(sprintf("  Total carbon:       %.0f Mg C\n",
                comparison_ranked$total_carbon_mg[1]))
    cat(sprintf("  Wetness change:     %.2f (TWI)\n",
                comparison_ranked$wetness_change[1]))
    cat("────────────────────────────────────────────────────────────────\n\n")

    # Calculate carbon credit potential
    carbon_price <- 50  # $/tonne CO2e
    co2_factor <- 3.67

    credit_value <- comparison_ranked$total_carbon_mg[1] * co2_factor * carbon_price

    cat("💰 CARBON CREDIT POTENTIAL:\n")
    cat(sprintf("   Total credits: %.0f Mg CO2e\n",
                comparison_ranked$total_carbon_mg[1] * co2_factor))
    cat(sprintf("   Estimated value: $%.0f CAD\n", credit_value))
    cat(sprintf("   (at $%d/tonne CO2e)\n\n", carbon_price))
  }

} else {
  cat("⚠️  Scenario comparison not found\n\n")
}

readline(prompt = "Press [Enter] for final summary...")

# ============================================================================
# PART 10: FINAL SUMMARY & OUTPUTS
# ============================================================================

cat("\n╔═══════════════════════════════════════════════════════════════╗\n")
cat("║                    TUTORIAL COMPLETE!                         ║\n")
cat("╚═══════════════════════════════════════════════════════════════╝\n\n")

cat("✓ You have successfully completed the Module 11 tutorial!\n\n")

cat("────────────────────────────────────────────────────────────────\n")
cat("OUTPUTS GENERATED:\n")
cat("────────────────────────────────────────────────────────────────\n\n")

output_structure <- list(
  "Hydrological Analysis" = c(
    "outputs/hydrology/flow_accumulation.tif",
    "outputs/hydrology/topographic_wetness_index.tif",
    "outputs/hydrology/stream_network.tif"
  ),
  "Sediment Transport" = c(
    "outputs/sediment/soil_loss_rusle.tif",
    "outputs/sediment/deposition_potential.tif"
  ),
  "Tidal Flooding" = c(
    "outputs/tidal/inundation_MHW.tif",
    "outputs/tidal/inundation_SLR_*.tif",
    "outputs/tidal/inundation_summary.csv"
  ),
  "Riparian Buffers" = c(
    "outputs/riparian_buffers/buffer_effectiveness_summary.csv",
    "outputs/riparian_buffers/buffer_effectiveness_curve.png"
  ),
  "3D Visualizations" = c(
    "outputs/3d_models/renders/terrain_3d_view*.png"
  ),
  "Restoration Scenarios" = c(
    "outputs/restoration_scenarios/scenario_comparison_summary.csv",
    "outputs/restoration_scenarios/dems/*.tif",
    "outputs/restoration_scenarios/comparisons/*.tif"
  )
)

for (category in names(output_structure)) {
  cat(sprintf("📁 %s:\n", category))
  for (file in output_structure[[category]]) {
    cat(sprintf("   - %s\n", file))
  }
  cat("\n")
}

cat("────────────────────────────────────────────────────────────────\n")
cat("NEXT STEPS:\n")
cat("────────────────────────────────────────────────────────────────\n\n")

cat("1. 📊 Review outputs in outputs/ directory\n")
cat("2. 🗺️  Load rasters in QGIS for spatial analysis\n")
cat("3. 📝 Integrate results into VM0033 verification (Module 07)\n")
cat("4. 🎨 Create presentation materials from 3D visualizations\n")
cat("5. 💼 Share with stakeholders and project team\n\n")

cat("────────────────────────────────────────────────────────────────\n")
cat("RESOURCES:\n")
cat("────────────────────────────────────────────────────────────────\n\n")

cat("📖 Full documentation: MODULE_11_README.md\n")
cat("📖 Tutorial guide: TUTORIAL_Module11_Chemainus.md\n")
cat("📧 Support: [your-email]\n\n")

cat("🌊 Thank you for using Module 11! 🌱\n\n")

# Save session info
session_summary <- list(
  date = Sys.Date(),
  time = Sys.time(),
  r_version = R.version.string,
  packages = sapply(required_packages, function(p) {
    if (requireNamespace(p, quietly = TRUE)) {
      as.character(packageVersion(p))
    } else {
      "Not installed"
    }
  })
)

write_json(session_summary,
           "outputs/tutorial_session_info.json",
           pretty = TRUE, auto_unbox = TRUE)

cat("✓ Session info saved to: outputs/tutorial_session_info.json\n\n")
