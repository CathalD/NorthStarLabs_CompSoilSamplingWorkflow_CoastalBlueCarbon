# ============================================================================
# MODULE 11: 3D ECOSYSTEM & HYDROLOGICAL MODELING
# ============================================================================
# PURPOSE: Integrate 3D visualization with hydrological modeling for
#          restoration scenario planning
#
# CAPABILITIES:
#   1. 3D terrain visualization with carbon stocks
#   2. Hydrological modeling (flow, wetness, runoff)
#   3. Sediment transport and deposition
#   4. Tidal flooding scenarios under sea level rise
#   5. Riparian buffer effectiveness analysis
#   6. Restoration scenario comparison
#
# INPUTS:
#   - DEM/elevation raster
#   - Carbon stock predictions (from Module 05/06)
#   - Environmental covariates (from GEE)
#   - Tidal/bathymetry data (optional)
#
# OUTPUTS:
#   - outputs/3d_models/ - 3D visualizations and animations
#   - outputs/hydrology/ - Flow, wetness, and sediment maps
#   - outputs/scenarios/ - Before/after restoration comparisons
#
# USAGE:
#   source("11_3d_ecosystem_modeling.R")
#
# AUTHOR: Blue Carbon Workflow Team
# DATE: 2024
# ============================================================================

cat("\n============================================================\n")
cat("MODULE 11: 3D ECOSYSTEM & HYDROLOGICAL MODELING\n")
cat("============================================================\n\n")

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (!exists("PROJECT_NAME")) {
  source("blue_carbon_config.R")
}

# Load required packages
cat("Loading required packages...\n")

required_packages <- c(
  "terra", "sf", "dplyr", "ggplot2",
  "rayshader", "whitebox", "rgl", "plotly"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required but not installed. Run: source('00a_install_packages_3d_hydro.R')", pkg))
  }
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}

# Optional packages (with graceful degradation)
optional_packages <- c("rayrender", "av", "EcoHydRology", "TideHarmonics", "elevatr")
for (pkg in optional_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  }
}

cat("✓ Packages loaded\n\n")

# ============================================================================
# CONFIGURATION - MODULE 11 SPECIFIC
# ============================================================================

# 3D Visualization parameters
CONFIG_3D <- list(
  render_3d = TRUE,              # Enable 3D rendering (set FALSE if no display)
  render_resolution = 1000,      # Resolution for 3D rendering (pixels)
  z_scale = 5,                   # Vertical exaggeration (5 = 5x height)
  water_detect = TRUE,           # Auto-detect water bodies
  save_snapshots = TRUE,         # Save 3D views as images
  create_animations = FALSE,     # Create flythrough animations (slow)
  animation_fps = 30             # Frames per second for videos
)

# Hydrological modeling parameters
CONFIG_HYDRO <- list(
  flow_accumulation = TRUE,      # Calculate flow accumulation
  wetness_index = TRUE,          # Calculate Topographic Wetness Index (TWI)
  stream_network = TRUE,         # Extract stream/channel network
  watershed_delineation = FALSE, # Delineate watersheds (set pour point)
  stream_threshold = 1000,       # Flow accumulation threshold for streams (cells)
  slope_percent = TRUE           # Calculate slope in percent (vs. degrees)
)

# Sediment transport parameters
CONFIG_SEDIMENT <- list(
  enable = TRUE,                 # Enable sediment modeling
  method = "RUSLE",              # RUSLE (Revised Universal Soil Loss Equation)
  R_factor = 150,                # Rainfall erosivity (MJ·mm/ha·h·year) - BC Coast typical
  K_factor_default = 0.25,       # Soil erodibility (use soil map if available)
  C_factor_by_stratum = list(    # Cover management factor by ecosystem
    "Upper Marsh" = 0.001,       # Dense vegetation = minimal erosion
    "Mid Marsh" = 0.002,
    "Lower Marsh" = 0.003,
    "Underwater Vegetation" = 0.0001,
    "Open Water" = 1.0           # No cover = max erosion
  ),
  P_factor = 1.0,                # Support practice (1 = no conservation measures)
  deposition_model = TRUE        # Model sediment deposition in wetlands
)

# Tidal/Sea Level Rise parameters
CONFIG_TIDAL <- list(
  enable = TRUE,                 # Enable tidal flooding analysis
  mhw_elevation = 2.5,           # Mean High Water elevation (m above datum)
  mhhw_elevation = 3.0,          # Mean Higher High Water (m)
  slr_scenarios = c(0, 0.5, 1.0, 1.5, 2.0),  # Sea level rise scenarios (meters)
  tidal_range = 3.5,             # Mean tidal range (meters) - typical for BC
  storm_surge = 1.0,             # Design storm surge (meters)
  datum_offset = 0               # Offset to convert DEM to tidal datum (if needed)
)

# Riparian buffer analysis parameters
CONFIG_BUFFER <- list(
  enable = TRUE,                 # Enable riparian buffer analysis
  buffer_widths = c(10, 20, 30, 50, 100),  # Test buffer widths (meters)
  sediment_trap_efficiency = 0.70,  # % sediment trapped per 10m buffer
  nutrient_removal_rate = 0.50,     # % nutrient removal rate
  carbon_sequestration_rate = 1.5   # Mg C/ha/year in restored buffer
)

# Restoration scenario parameters
CONFIG_SCENARIOS <- list(
  baseline_name = "Current",           # Baseline scenario name
  project_scenarios = c(               # Project scenarios to model
    "Tidal_Restoration",               # Remove dikes, restore tidal flow
    "Riparian_Buffer",                 # Add vegetated buffers
    "Channel_Creation",                # Create tidal channels
    "Full_Restoration"                 # Combined approach
  ),
  compare_carbon = TRUE,               # Compare carbon stocks across scenarios
  compare_hydrology = TRUE,            # Compare flow patterns
  compare_flood_risk = TRUE            # Compare flood mitigation
)

# Output directories
DIRS_3D <- list(
  base = "outputs/3d_models",
  renders = "outputs/3d_models/renders",
  animations = "outputs/3d_models/animations",
  hydro = "outputs/hydrology",
  sediment = "outputs/sediment",
  tidal = "outputs/tidal",
  buffers = "outputs/riparian_buffers",
  scenarios = "outputs/restoration_scenarios"
)

# Create directories
for (dir in DIRS_3D) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

cat("✓ Configuration loaded\n\n")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Normalize raster to 0-1 range for visualization
#' @param r terra raster
#' @return Normalized raster
normalize_raster <- function(r) {
  r_min <- global(r, "min", na.rm = TRUE)[[1]]
  r_max <- global(r, "max", na.rm = TRUE)[[1]]
  (r - r_min) / (r_max - r_min)
}

#' Convert terra raster to matrix for rayshader
#' @param r terra raster
#' @return Matrix
raster_to_matrix <- function(r) {
  # Transpose and flip for correct orientation
  m <- as.matrix(r, wide = TRUE)
  m <- t(m)
  m <- m[nrow(m):1, ]
  return(m)
}

#' Calculate Topographic Wetness Index (TWI)
#' Uses whitebox tools
#' @param dem DEM raster path
#' @param output Output path for TWI
calculate_twi <- function(dem_path, output_path) {
  cat("  Calculating Topographic Wetness Index...\n")

  # Fill depressions
  dem_filled <- tempfile(fileext = ".tif")
  whitebox::wbt_fill_depressions(dem_path, dem_filled)

  # Calculate TWI
  whitebox::wbt_wetness_index(
    dem = dem_filled,
    output = output_path
  )

  return(rast(output_path))
}

#' Calculate flow accumulation
#' @param dem DEM raster path
#' @param output Output path
calculate_flow_accumulation <- function(dem_path, output_path) {
  cat("  Calculating flow accumulation...\n")

  # Fill depressions
  dem_filled <- tempfile(fileext = ".tif")
  whitebox::wbt_fill_depressions(dem_path, dem_filled)

  # D8 flow pointer
  d8_pointer <- tempfile(fileext = ".tif")
  whitebox::wbt_d8_pointer(dem_filled, d8_pointer)

  # Flow accumulation
  whitebox::wbt_d8_flow_accumulation(
    input = dem_filled,
    output = output_path,
    out_type = "cells"
  )

  return(rast(output_path))
}

#' Extract stream network from flow accumulation
#' @param flow_accum Flow accumulation raster
#' @param threshold Minimum flow accumulation for streams (cells)
#' @return Stream raster (binary)
extract_streams <- function(flow_accum, threshold = 1000) {
  cat(sprintf("  Extracting streams (threshold: %d cells)...\n", threshold))
  streams <- flow_accum >= threshold
  names(streams) <- "streams"
  return(streams)
}

#' Calculate RUSLE soil loss
#' @param slope Slope raster (percent)
#' @param flow_accum Flow accumulation raster
#' @param R_factor Rainfall erosivity
#' @param K_factor Soil erodibility
#' @param C_factor Cover management
#' @param P_factor Support practice
#' @return Soil loss raster (tons/ha/year)
calculate_rusle <- function(slope, flow_accum, R_factor, K_factor, C_factor, P_factor) {
  cat("  Calculating RUSLE soil loss...\n")

  # LS factor (slope length and steepness)
  # Simplified: LS = (flow_accum * cell_size / 22.13)^0.4 * (sin(slope) / 0.0896)^1.3
  cell_size <- res(slope)[1]
  slope_rad <- slope * pi / 180  # Convert to radians

  L_factor <- (flow_accum * cell_size / 22.13)^0.4
  S_factor <- (sin(slope_rad) / 0.0896)^1.3
  LS_factor <- L_factor * S_factor

  # RUSLE equation: A = R × K × LS × C × P
  soil_loss <- R_factor * K_factor * LS_factor * C_factor * P_factor

  names(soil_loss) <- "soil_loss_ton_ha_yr"
  return(soil_loss)
}

#' Model tidal inundation
#' @param dem DEM raster
#' @param water_level Water level to test (m)
#' @param datum_offset Offset to tidal datum
#' @return Binary inundation raster
model_tidal_inundation <- function(dem, water_level, datum_offset = 0) {
  inundated <- (dem + datum_offset) <= water_level
  names(inundated) <- paste0("inundation_", water_level, "m")
  return(inundated)
}

#' Calculate riparian buffer effectiveness
#' @param streams Stream network raster
#' @param buffer_width Buffer width (meters)
#' @param sediment_input Sediment input raster
#' @param trap_efficiency Sediment trapping efficiency
#' @return Sediment reduction raster
calculate_buffer_effectiveness <- function(streams, buffer_width, sediment_input,
                                          trap_efficiency = 0.70) {
  cat(sprintf("  Analyzing %dm riparian buffer...\n", buffer_width))

  # Create buffer zone
  buffer_temp <- tempfile(fileext = ".tif")
  writeRaster(streams, buffer_temp, overwrite = TRUE)

  buffer_dist <- tempfile(fileext = ".tif")
  whitebox::wbt_euclidean_distance(buffer_temp, buffer_dist)
  buffer_zone <- rast(buffer_dist) <= buffer_width

  # Calculate sediment trapped in buffer
  sediment_trapped <- sediment_input * buffer_zone * trap_efficiency
  sediment_remaining <- sediment_input - sediment_trapped

  names(sediment_trapped) <- paste0("sediment_trapped_", buffer_width, "m")
  names(sediment_remaining) <- paste0("sediment_remaining_", buffer_width, "m")

  return(list(
    trapped = sediment_trapped,
    remaining = sediment_remaining,
    reduction_pct = global(sediment_trapped, "sum", na.rm = TRUE)[[1]] /
                    global(sediment_input, "sum", na.rm = TRUE)[[1]] * 100
  ))
}

cat("✓ Helper functions loaded\n\n")

# ============================================================================
# 1. LOAD INPUT DATA
# ============================================================================

cat("============================================================\n")
cat("1. LOADING INPUT DATA\n")
cat("============================================================\n\n")

# Load DEM (elevation)
cat("Loading elevation data...\n")
dem_path <- "data_raw/gee_covariates/elevation.tif"

if (!file.exists(dem_path)) {
  cat("✗ DEM not found at:", dem_path, "\n")
  cat("  Attempting to download DEM using elevatr...\n")

  # Try to fetch DEM if we have site coordinates
  if (file.exists("data_raw/field_cores.csv")) {
    cores <- read.csv("data_raw/field_cores.csv")
    bbox <- st_bbox(st_as_sf(cores, coords = c("longitude", "latitude"), crs = 4326))

    # Fetch elevation
    if (requireNamespace("elevatr", quietly = TRUE)) {
      dem_elevatr <- elevatr::get_elev_raster(
        locations = st_as_sf(as(bbox, "Spatial")),
        z = 13,  # Zoom level
        clip = "bbox"
      )
      dem <- rast(dem_elevatr)
      writeRaster(dem, dem_path, overwrite = TRUE)
      cat("✓ DEM downloaded and saved\n")
    } else {
      stop("Cannot fetch DEM - please provide elevation.tif or install elevatr package")
    }
  } else {
    stop("No DEM found and no coordinates available to fetch one")
  }
} else {
  dem <- rast(dem_path)
  cat("✓ DEM loaded\n")
}

# Project to processing CRS if needed
if (crs(dem, describe = TRUE)$code != PROCESSING_CRS) {
  cat("  Reprojecting DEM to EPSG:", PROCESSING_CRS, "...\n")
  dem <- project(dem, paste0("EPSG:", PROCESSING_CRS), method = "bilinear")
}

cat(sprintf("  Resolution: %.1f x %.1f meters\n", res(dem)[1], res(dem)[2]))
cat(sprintf("  Extent: %.0f x %.0f cells\n", ncol(dem), nrow(dem)))
cat(sprintf("  Elevation range: %.2f to %.2f meters\n",
            global(dem, "min", na.rm = TRUE)[[1]],
            global(dem, "max", na.rm = TRUE)[[1]]))

# Load carbon stock predictions (from Module 05 or 06)
cat("\nLoading carbon stock predictions...\n")
carbon_paths <- list(
  rf = "outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif",
  kriging = "outputs/predictions/kriging/carbon_stock_kriging_total_0_100cm.tif"
)

carbon_stock <- NULL
for (method in names(carbon_paths)) {
  if (file.exists(carbon_paths[[method]])) {
    carbon_stock <- rast(carbon_paths[[method]])
    cat(sprintf("✓ Carbon stocks loaded (%s method)\n", method))
    break
  }
}

if (is.null(carbon_stock)) {
  cat("⚠ No carbon stock predictions found - will skip carbon overlays\n")
  cat("  Expected at: outputs/predictions/rf/ or outputs/predictions/kriging/\n")
}

# Load ecosystem stratification
cat("\nLoading ecosystem strata...\n")
strata_path <- "outputs/spatial/ecosystem_strata.tif"

if (file.exists(strata_path)) {
  strata <- rast(strata_path)
  cat("✓ Strata loaded\n")
} else {
  cat("⚠ Strata map not found - will skip stratum-specific analysis\n")
  strata <- NULL
}

# Load environmental covariates
cat("\nLoading environmental covariates...\n")
covariates <- list()

covariate_files <- c(
  "slope" = "data_raw/gee_covariates/slope.tif",
  "ndvi" = "data_raw/gee_covariates/sentinel2_ndvi.tif",
  "ndwi" = "data_raw/gee_covariates/sentinel2_ndwi.tif"
)

for (name in names(covariate_files)) {
  if (file.exists(covariate_files[[name]])) {
    covariates[[name]] <- rast(covariate_files[[name]])
    cat(sprintf("  ✓ %s\n", name))
  }
}

if (length(covariates) == 0) {
  cat("⚠ No covariates loaded - some analyses may be limited\n")
}

cat("\n✓ Data loading complete\n\n")

# ============================================================================
# 2. HYDROLOGICAL MODELING
# ============================================================================

cat("============================================================\n")
cat("2. HYDROLOGICAL MODELING\n")
cat("============================================================\n\n")

if (CONFIG_HYDRO$flow_accumulation || CONFIG_HYDRO$wetness_index) {

  # Save DEM to temp file for whitebox
  dem_temp <- file.path(DIRS_3D$hydro, "dem_temp.tif")
  writeRaster(dem, dem_temp, overwrite = TRUE)

  # Calculate slope if not already loaded
  if (!"slope" %in% names(covariates)) {
    cat("Calculating slope...\n")
    slope_temp <- file.path(DIRS_3D$hydro, "slope.tif")
    whitebox::wbt_slope(
      dem = dem_temp,
      output = slope_temp,
      units = ifelse(CONFIG_HYDRO$slope_percent, "percent", "degrees")
    )
    covariates$slope <- rast(slope_temp)
    cat("✓ Slope calculated\n")
  }

  # Flow accumulation
  if (CONFIG_HYDRO$flow_accumulation) {
    flow_accum_path <- file.path(DIRS_3D$hydro, "flow_accumulation.tif")
    flow_accum <- calculate_flow_accumulation(dem_temp, flow_accum_path)
    cat("✓ Flow accumulation calculated\n")

    # Extract stream network
    if (CONFIG_HYDRO$stream_network) {
      streams <- extract_streams(flow_accum, CONFIG_HYDRO$stream_threshold)
      streams_path <- file.path(DIRS_3D$hydro, "stream_network.tif")
      writeRaster(streams, streams_path, overwrite = TRUE)
      cat("✓ Stream network extracted\n")
    }
  }

  # Topographic Wetness Index
  if (CONFIG_HYDRO$wetness_index) {
    twi_path <- file.path(DIRS_3D$hydro, "topographic_wetness_index.tif")
    twi <- calculate_twi(dem_temp, twi_path)
    cat("✓ Topographic Wetness Index calculated\n")

    # High wetness areas are potential restoration sites
    wet_areas <- twi > global(twi, "quantile", probs = 0.75, na.rm = TRUE)[[1]]
    writeRaster(wet_areas, file.path(DIRS_3D$hydro, "high_wetness_areas.tif"),
                overwrite = TRUE)
  }

} else {
  cat("Hydrological modeling disabled in CONFIG_HYDRO\n")
}

cat("\n✓ Hydrological modeling complete\n\n")

# ============================================================================
# 3. SEDIMENT TRANSPORT MODELING
# ============================================================================

cat("============================================================\n")
cat("3. SEDIMENT TRANSPORT MODELING\n")
cat("============================================================\n\n")

if (CONFIG_SEDIMENT$enable && exists("flow_accum") && exists("covariates")) {

  # Get C-factor (cover management) by stratum
  if (!is.null(strata)) {
    C_factor <- strata
    for (stratum_name in names(CONFIG_SEDIMENT$C_factor_by_stratum)) {
      stratum_val <- which(VALID_STRATA == stratum_name)
      C_factor[strata == stratum_val] <- CONFIG_SEDIMENT$C_factor_by_stratum[[stratum_name]]
    }
    cat("✓ C-factor map created from ecosystem strata\n")
  } else {
    # Use default C-factor
    C_factor <- dem * 0 + 0.01  # Assume low erosion with vegetation
    cat("⚠ Using default C-factor (no strata map available)\n")
  }

  # Calculate RUSLE
  soil_loss <- calculate_rusle(
    slope = covariates$slope,
    flow_accum = flow_accum,
    R_factor = CONFIG_SEDIMENT$R_factor,
    K_factor = CONFIG_SEDIMENT$K_factor_default,
    C_factor = C_factor,
    P_factor = CONFIG_SEDIMENT$P_factor
  )

  writeRaster(soil_loss, file.path(DIRS_3D$sediment, "soil_loss_rusle.tif"),
              overwrite = TRUE)

  cat(sprintf("✓ RUSLE soil loss calculated\n"))
  cat(sprintf("  Mean soil loss: %.2f tons/ha/year\n",
              global(soil_loss, "mean", na.rm = TRUE)[[1]]))
  cat(sprintf("  Max soil loss: %.2f tons/ha/year\n",
              global(soil_loss, "max", na.rm = TRUE)[[1]]))

  # Sediment deposition model (simplified)
  # Wetlands trap sediment - use TWI as proxy for deposition potential
  if (exists("twi")) {
    deposition_potential <- normalize_raster(twi) * soil_loss
    names(deposition_potential) <- "sediment_deposition_potential"
    writeRaster(deposition_potential,
                file.path(DIRS_3D$sediment, "deposition_potential.tif"),
                overwrite = TRUE)
    cat("✓ Sediment deposition potential mapped\n")
  }

} else {
  cat("Sediment modeling disabled or missing required data\n")
}

cat("\n✓ Sediment modeling complete\n\n")

# ============================================================================
# 4. TIDAL FLOODING & SEA LEVEL RISE
# ============================================================================

cat("============================================================\n")
cat("4. TIDAL FLOODING & SEA LEVEL RISE SCENARIOS\n")
cat("============================================================\n\n")

if (CONFIG_TIDAL$enable) {

  inundation_maps <- list()
  inundation_areas <- data.frame(
    scenario = character(),
    water_level_m = numeric(),
    inundated_area_ha = numeric(),
    stringsAsFactors = FALSE
  )

  # Current sea level scenarios
  tidal_levels <- c(
    MHW = CONFIG_TIDAL$mhw_elevation,
    MHHW = CONFIG_TIDAL$mhhw_elevation,
    Storm = CONFIG_TIDAL$mhhw_elevation + CONFIG_TIDAL$storm_surge
  )

  cat("Current tidal scenarios:\n")
  for (scenario in names(tidal_levels)) {
    level <- tidal_levels[[scenario]]
    inundation <- model_tidal_inundation(dem, level, CONFIG_TIDAL$datum_offset)
    inundation_maps[[scenario]] <- inundation

    area_ha <- global(inundation, "sum", na.rm = TRUE)[[1]] *
               res(dem)[1] * res(dem)[2] / 10000

    cat(sprintf("  %s (%.2fm): %.2f ha inundated\n", scenario, level, area_ha))

    writeRaster(inundation,
                file.path(DIRS_3D$tidal, paste0("inundation_", scenario, ".tif")),
                overwrite = TRUE)

    inundation_areas <- rbind(inundation_areas, data.frame(
      scenario = scenario,
      water_level_m = level,
      inundated_area_ha = area_ha
    ))
  }

  # Sea level rise scenarios
  cat("\nSea level rise scenarios:\n")
  for (slr in CONFIG_TIDAL$slr_scenarios) {
    if (slr == 0) next

    scenario_name <- paste0("SLR_", gsub("\\.", "p", slr), "m")
    level <- CONFIG_TIDAL$mhhw_elevation + slr

    inundation <- model_tidal_inundation(dem, level, CONFIG_TIDAL$datum_offset)
    inundation_maps[[scenario_name]] <- inundation

    area_ha <- global(inundation, "sum", na.rm = TRUE)[[1]] *
               res(dem)[1] * res(dem)[2] / 10000

    cat(sprintf("  +%.1fm SLR: %.2f ha inundated (+%.1f%% from current)\n",
                slr, area_ha,
                (area_ha / inundation_areas$inundated_area_ha[1] - 1) * 100))

    writeRaster(inundation,
                file.path(DIRS_3D$tidal, paste0("inundation_", scenario_name, ".tif")),
                overwrite = TRUE)

    inundation_areas <- rbind(inundation_areas, data.frame(
      scenario = scenario_name,
      water_level_m = level,
      inundated_area_ha = area_ha
    ))
  }

  # Save summary
  write.csv(inundation_areas,
            file.path(DIRS_3D$tidal, "inundation_summary.csv"),
            row.names = FALSE)

  # Carbon at risk from sea level rise
  if (!is.null(carbon_stock)) {
    cat("\nCarbon stocks at risk from inundation:\n")
    for (i in 1:nrow(inundation_areas)) {
      inund_map <- inundation_maps[[inundation_areas$scenario[i]]]
      carbon_at_risk <- mask(carbon_stock, inund_map, maskvalues = 0)
      total_carbon_mg <- global(carbon_at_risk, "sum", na.rm = TRUE)[[1]] *
                         res(carbon_stock)[1] * res(carbon_stock)[2] / 10000

      cat(sprintf("  %s: %.0f Mg C at risk\n",
                  inundation_areas$scenario[i], total_carbon_mg))
    }
  }

} else {
  cat("Tidal modeling disabled in CONFIG_TIDAL\n")
}

cat("\n✓ Tidal flooding analysis complete\n\n")

# ============================================================================
# 5. RIPARIAN BUFFER ANALYSIS
# ============================================================================

cat("============================================================\n")
cat("5. RIPARIAN BUFFER ANALYSIS\n")
cat("============================================================\n\n")

if (CONFIG_BUFFER$enable && exists("streams") && exists("soil_loss")) {

  buffer_results <- data.frame(
    buffer_width_m = numeric(),
    sediment_trapped_tons_yr = numeric(),
    reduction_pct = numeric(),
    carbon_sequestration_mg_yr = numeric(),
    stringsAsFactors = FALSE
  )

  cat("Analyzing riparian buffer scenarios:\n\n")

  for (width in CONFIG_BUFFER$buffer_widths) {
    result <- calculate_buffer_effectiveness(
      streams = streams,
      buffer_width = width,
      sediment_input = soil_loss,
      trap_efficiency = CONFIG_BUFFER$sediment_trap_efficiency
    )

    # Calculate total sediment trapped
    cell_area_ha <- res(soil_loss)[1] * res(soil_loss)[2] / 10000
    sediment_trapped_total <- global(result$trapped, "sum", na.rm = TRUE)[[1]] * cell_area_ha

    # Calculate buffer area and carbon sequestration
    buffer_area_ha <- global(result$trapped > 0, "sum", na.rm = TRUE)[[1]] * cell_area_ha
    carbon_seq_mg <- buffer_area_ha * CONFIG_BUFFER$carbon_sequestration_rate

    cat(sprintf("  %dm buffer:\n", width))
    cat(sprintf("    - Sediment trapped: %.0f tons/year (%.1f%% reduction)\n",
                sediment_trapped_total, result$reduction_pct))
    cat(sprintf("    - Buffer area: %.2f ha\n", buffer_area_ha))
    cat(sprintf("    - Carbon sequestration: %.1f Mg C/year\n\n", carbon_seq_mg))

    buffer_results <- rbind(buffer_results, data.frame(
      buffer_width_m = width,
      sediment_trapped_tons_yr = sediment_trapped_total,
      reduction_pct = result$reduction_pct,
      carbon_sequestration_mg_yr = carbon_seq_mg
    ))

    # Save maps
    writeRaster(result$trapped,
                file.path(DIRS_3D$buffers, paste0("sediment_trapped_", width, "m.tif")),
                overwrite = TRUE)
  }

  write.csv(buffer_results,
            file.path(DIRS_3D$buffers, "buffer_effectiveness_summary.csv"),
            row.names = FALSE)

  # Plot buffer effectiveness
  png(file.path(DIRS_3D$buffers, "buffer_effectiveness_curve.png"),
      width = 2400, height = 1800, res = 300)
  par(mfrow = c(1, 2))

  plot(buffer_results$buffer_width_m, buffer_results$reduction_pct,
       type = "b", pch = 19, col = "darkgreen",
       xlab = "Buffer Width (m)", ylab = "Sediment Reduction (%)",
       main = "Riparian Buffer Effectiveness",
       ylim = c(0, 100))
  grid()

  plot(buffer_results$buffer_width_m, buffer_results$carbon_sequestration_mg_yr,
       type = "b", pch = 19, col = "darkblue",
       xlab = "Buffer Width (m)", ylab = "Carbon Sequestration (Mg C/year)",
       main = "Carbon Benefits")
  grid()

  dev.off()

  cat("✓ Buffer effectiveness plots saved\n")

} else {
  cat("Riparian buffer analysis disabled or missing required data\n")
}

cat("\n✓ Riparian buffer analysis complete\n\n")

# ============================================================================
# 6. 3D VISUALIZATION
# ============================================================================

cat("============================================================\n")
cat("6. 3D VISUALIZATION\n")
cat("============================================================\n\n")

if (CONFIG_3D$render_3d) {

  cat("Preparing 3D terrain model...\n")

  # Convert DEM to matrix
  elev_matrix <- raster_to_matrix(dem)

  # Create base hillshade
  cat("  Generating hillshade...\n")
  elev_matrix %>%
    sphere_shade(texture = "desert") %>%
    add_shadow(ray_shade(elev_matrix, zscale = CONFIG_3D$z_scale), 0.5) ->
    base_map

  if (CONFIG_3D$save_snapshots) {
    # Render 2D map
    png(file.path(DIRS_3D$renders, "terrain_2d.png"),
        width = 2400, height = 2400, res = 300)
    plot_map(base_map)
    dev.off()
    cat("✓ 2D terrain map saved\n")
  }

  # Add carbon stock overlay
  if (!is.null(carbon_stock)) {
    cat("  Adding carbon stock overlay...\n")

    # Resample carbon to match DEM
    carbon_resampled <- resample(carbon_stock, dem, method = "bilinear")
    carbon_matrix <- raster_to_matrix(carbon_resampled)

    # Normalize for color overlay
    carbon_norm <- (carbon_matrix - min(carbon_matrix, na.rm = TRUE)) /
                   (max(carbon_matrix, na.rm = TRUE) - min(carbon_matrix, na.rm = TRUE))

    # Create color overlay (blue = low carbon, green = high carbon)
    carbon_colors <- array(0, dim = c(nrow(carbon_norm), ncol(carbon_norm), 3))
    carbon_colors[,,1] <- 0          # Red channel
    carbon_colors[,,2] <- carbon_norm  # Green channel
    carbon_colors[,,3] <- 1 - carbon_norm  # Blue channel

    base_map %>%
      add_overlay(carbon_colors, alphalayer = 0.5) ->
      carbon_map

    if (CONFIG_3D$save_snapshots) {
      png(file.path(DIRS_3D$renders, "carbon_stocks_2d.png"),
          width = 2400, height = 2400, res = 300)
      plot_map(carbon_map)
      dev.off()
      cat("✓ Carbon stock overlay saved\n")
    }
  } else {
    carbon_map <- base_map
  }

  # Render 3D
  cat("  Rendering 3D model...\n")
  cat("  (This may take a minute...)\n")

  tryCatch({
    plot_3d(
      carbon_map,
      elev_matrix,
      zscale = CONFIG_3D$z_scale,
      fov = 0,
      theta = 45,
      phi = 45,
      windowsize = c(1200, 900),
      zoom = 0.75,
      water = CONFIG_3D$water_detect,
      waterdepth = 0,
      wateralpha = 0.5,
      watercolor = "lightblue",
      waterlinecolor = "white",
      waterlinealpha = 0.5
    )

    # Save snapshot
    if (CONFIG_3D$save_snapshots) {
      render_snapshot(
        filename = file.path(DIRS_3D$renders, "terrain_3d_view1.png"),
        clear = FALSE
      )

      # Rotate and save another view
      render_camera(theta = 135, phi = 30, zoom = 0.6)
      render_snapshot(
        filename = file.path(DIRS_3D$renders, "terrain_3d_view2.png"),
        clear = FALSE
      )

      cat("✓ 3D snapshots saved\n")
    }

    # Close 3D window
    rgl::rgl.close()

  }, error = function(e) {
    cat(sprintf("⚠ 3D rendering failed: %s\n", e$message))
    cat("  Set CONFIG_3D$render_3d = FALSE to skip 3D rendering\n")
  })

} else {
  cat("3D rendering disabled in CONFIG_3D\n")
}

cat("\n✓ 3D visualization complete\n\n")

# ============================================================================
# 7. GENERATE SUMMARY REPORT
# ============================================================================

cat("============================================================\n")
cat("7. GENERATING SUMMARY REPORT\n")
cat("============================================================\n\n")

report <- list(
  project = PROJECT_NAME,
  location = PROJECT_LOCATION,
  date = Sys.Date(),

  dem_stats = list(
    resolution_m = res(dem)[1],
    extent_ha = (ncol(dem) * res(dem)[1]) * (nrow(dem) * res(dem)[2]) / 10000,
    min_elevation = global(dem, "min", na.rm = TRUE)[[1]],
    max_elevation = global(dem, "max", na.rm = TRUE)[[1]],
    relief = global(dem, "max", na.rm = TRUE)[[1]] - global(dem, "min", na.rm = TRUE)[[1]]
  ),

  hydrology = if (exists("flow_accum")) list(
    stream_length_km = global(streams, "sum", na.rm = TRUE)[[1]] * res(dem)[1] / 1000,
    mean_slope_pct = global(covariates$slope, "mean", na.rm = TRUE)[[1]],
    high_wetness_area_ha = if(exists("wet_areas"))
      global(wet_areas, "sum", na.rm = TRUE)[[1]] * res(dem)[1]^2 / 10000 else NA
  ) else NULL,

  sediment = if (exists("soil_loss")) list(
    mean_soil_loss_ton_ha_yr = global(soil_loss, "mean", na.rm = TRUE)[[1]],
    total_soil_loss_ton_yr = global(soil_loss, "sum", na.rm = TRUE)[[1]] *
                              res(soil_loss)[1]^2 / 10000
  ) else NULL,

  tidal = if (CONFIG_TIDAL$enable && exists("inundation_areas"))
    inundation_areas else NULL,

  buffers = if (CONFIG_BUFFER$enable && exists("buffer_results"))
    buffer_results else NULL
)

# Save report as JSON
report_json <- jsonlite::toJSON(report, pretty = TRUE, auto_unbox = TRUE)
writeLines(report_json, file.path(DIRS_3D$base, "module11_summary.json"))

# Save as CSV tables
if (!is.null(report$tidal)) {
  write.csv(report$tidal,
            file.path(DIRS_3D$base, "tidal_summary.csv"),
            row.names = FALSE)
}

if (!is.null(report$buffers)) {
  write.csv(report$buffers,
            file.path(DIRS_3D$base, "buffer_summary.csv"),
            row.names = FALSE)
}

cat("✓ Summary report saved\n\n")

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================

cat("============================================================\n")
cat("MODULE 11 COMPLETE!\n")
cat("============================================================\n\n")

cat("Outputs saved to:\n")
cat(sprintf("  - 3D models: %s\n", DIRS_3D$renders))
cat(sprintf("  - Hydrology: %s\n", DIRS_3D$hydro))
cat(sprintf("  - Sediment: %s\n", DIRS_3D$sediment))
cat(sprintf("  - Tidal: %s\n", DIRS_3D$tidal))
cat(sprintf("  - Buffers: %s\n", DIRS_3D$buffers))

cat("\nKey outputs:\n")
if (exists("twi")) cat("  ✓ Topographic Wetness Index\n")
if (exists("flow_accum")) cat("  ✓ Flow accumulation & stream network\n")
if (exists("soil_loss")) cat("  ✓ RUSLE soil loss estimates\n")
if (exists("inundation_maps")) cat(sprintf("  ✓ %d tidal inundation scenarios\n", length(inundation_maps)))
if (exists("buffer_results")) cat(sprintf("  ✓ %d riparian buffer scenarios\n", nrow(buffer_results)))

cat("\nNext steps:\n")
cat("  1. Review outputs in outputs/3d_models/\n")
cat("  2. Run Module 11b to build custom restoration scenarios\n")
cat("  3. Integrate results into VM0033 reporting (Module 07)\n\n")

cat("Done! 🌊🗻🌱\n\n")
