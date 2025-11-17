# ============================================================================
# DOWNSTREAM IMPACTS: CATCHMENT DELINEATION & FLOW ROUTING
# ============================================================================
# Purpose: Delineate upstream contributing areas for points of interest (POIs)
#          and create flow routing infrastructure for downstream impact modeling
#
# Inputs:
#   - Digital Elevation Model (DEM) - data_raw/hydrology/dem.tif
#   - Points of Interest (POIs) - data_raw/poi/points_of_interest.csv
#   - Restoration intervention map - outputs/predictions/restoration_mask.tif
#
# Outputs:
#   - Flow direction raster - outputs/downstream/flow_direction.tif
#   - Flow accumulation raster - outputs/downstream/flow_accumulation.tif
#   - Stream network shapefile - outputs/downstream/stream_network.shp
#   - Catchment polygons by POI - outputs/downstream/catchments_by_poi.shp
#   - Contributing area statistics - outputs/downstream/tables/catchment_stats.csv
#
# Methods:
#   - WhiteboxTools for hydrological processing (D8/D-infinity algorithms)
#   - Depression filling or breaching for realistic flow paths
#   - Snap pour points to high flow accumulation cells
#   - Delineate watersheds for each POI
#
# Author: NorthStar Labs Blue Carbon Team
# Date: 2024-11
# ============================================================================

# Load required packages
library(terra)
library(sf)
library(whitebox)  # WhiteboxTools R interface
library(dplyr)
library(tidyr)

# Source configuration
source("blue_carbon_config.R")

# ============================================================================
# SETUP & VALIDATION
# ============================================================================

cat("\n============================================\n")
cat("CATCHMENT DELINEATION & FLOW ROUTING\n")
cat("============================================\n\n")

# Check if downstream impacts are enabled
if (!ENABLE_DOWNSTREAM_IMPACTS) {
  stop("Downstream impact modeling is disabled. Set ENABLE_DOWNSTREAM_IMPACTS = TRUE in blue_carbon_config.R")
}

# Initialize WhiteboxTools
wbt_init()

# Check WhiteboxTools installation
if (!wbt_check_whitebox_exists()) {
  cat("Installing WhiteboxTools...\n")
  wbt_install()
}

cat("WhiteboxTools version:", wbt_version(), "\n\n")

# ============================================================================
# 1. LOAD & PREPARE DEM
# ============================================================================

cat("1. Loading and preparing DEM...\n")

# Check if DEM exists
dem_path <- "data_raw/hydrology/dem.tif"
if (!file.exists(dem_path)) {
  stop(paste0(
    "DEM not found at ", dem_path, "\n",
    "Please export DEM from Google Earth Engine using GEE_EXPORT_HYDROLOGY_DATA.js\n",
    "Supported sources: SRTM (30m), ALOS PALSAR (12.5m), or custom LiDAR DEM"
  ))
}

# Load DEM
dem <- rast(dem_path)
cat("  DEM resolution:", res(dem)[1], "m\n")
cat("  DEM extent:", as.vector(ext(dem)), "\n")
cat("  DEM CRS:", crs(dem, describe = TRUE)$name, "\n")

# Reproject to processing CRS if needed
if (st_crs(crs(dem, proj = TRUE))$epsg != PROCESSING_CRS) {
  cat("  Reprojecting DEM to EPSG:", PROCESSING_CRS, "...\n")
  dem <- project(dem, paste0("EPSG:", PROCESSING_CRS), method = "bilinear")
}

# Create temporary directory for WhiteboxTools
temp_dir <- "temp_hydro"
dir.create(temp_dir, showWarnings = FALSE, recursive = TRUE)

# Write DEM for WhiteboxTools
dem_wbt <- file.path(temp_dir, "dem.tif")
writeRaster(dem, dem_wbt, overwrite = TRUE)

cat("  DEM prepared ✓\n\n")

# ============================================================================
# 2. HYDROLOGICAL CONDITIONING
# ============================================================================

cat("2. Hydrological conditioning...\n")

# Fill depressions or breach to ensure continuous flow paths
dem_conditioned <- file.path(temp_dir, "dem_conditioned.tif")

if (FILL_DEPRESSIONS) {
  cat("  Filling depressions (sink removal)...\n")
  wbt_fill_depressions(
    dem = dem_wbt,
    output = dem_conditioned,
    fix_flats = TRUE
  )
} else {
  cat("  Breaching depressions (carving approach)...\n")
  wbt_breach_depressions(
    dem = dem_wbt,
    output = dem_conditioned,
    max_depth = 5.0,  # Maximum breach depth in DEM units
    max_length = 100  # Maximum breach length in cells
  )
}

cat("  Hydrological conditioning complete ✓\n\n")

# ============================================================================
# 3. FLOW DIRECTION & ACCUMULATION
# ============================================================================

cat("3. Computing flow direction and accumulation...\n")

flow_dir <- file.path(temp_dir, "flow_direction.tif")
flow_acc <- file.path(temp_dir, "flow_accumulation.tif")

if (FLOW_DIR_METHOD == "D8") {
  cat("  Using D8 flow direction algorithm...\n")

  # D8 pointer (flow direction)
  wbt_d8_pointer(
    dem = dem_conditioned,
    output = flow_dir
  )

  # D8 flow accumulation
  wbt_d8_flow_accumulation(
    input = dem_conditioned,
    output = flow_acc,
    out_type = "cells",  # Number of upstream cells
    log = FALSE
  )

} else if (FLOW_DIR_METHOD == "D-infinity") {
  cat("  Using D-infinity flow direction algorithm...\n")

  # D-infinity pointer
  wbt_d_inf_pointer(
    dem = dem_conditioned,
    output = flow_dir
  )

  # D-infinity flow accumulation
  wbt_d_inf_flow_accumulation(
    input = dem_conditioned,
    output = flow_acc,
    out_type = "cells"
  )

} else if (FLOW_DIR_METHOD == "MFD") {
  cat("  Using Multiple Flow Direction (MFD) algorithm...\n")

  # FD8 (multiple flow direction)
  wbt_fd8_pointer(
    dem = dem_conditioned,
    output = flow_dir
  )

  # FD8 flow accumulation
  wbt_fd8_flow_accumulation(
    dem = dem_conditioned,
    output = flow_acc,
    out_type = "cells"
  )
}

cat("  Flow routing complete ✓\n\n")

# ============================================================================
# 4. EXTRACT STREAM NETWORK
# ============================================================================

cat("4. Extracting stream network...\n")

# Convert stream threshold from hectares to cells
cell_area_m2 <- res(dem)[1] * res(dem)[2]
cell_area_ha <- cell_area_m2 / 10000
threshold_cells <- STREAM_THRESHOLD_HA / cell_area_ha

cat("  Stream initiation threshold:", STREAM_THRESHOLD_HA, "ha =", round(threshold_cells), "cells\n")

# Extract streams
streams_raster <- file.path(temp_dir, "streams.tif")
wbt_extract_streams(
  flow_accum = flow_acc,
  output = streams_raster,
  threshold = threshold_cells
)

# Vectorize streams
cat("  Vectorizing stream network...\n")
streams_vector <- file.path(temp_dir, "streams_vector.shp")
wbt_raster_streams_to_vector(
  streams = streams_raster,
  d8_pntr = flow_dir,
  output = streams_vector
)

# Load and save stream network
streams_sf <- st_read(streams_vector, quiet = TRUE)
streams_sf <- st_transform(streams_sf, PROCESSING_CRS)

# Calculate stream order
cat("  Calculating stream order (Strahler method)...\n")
stream_order <- file.path(temp_dir, "stream_order.tif")
wbt_strahler_stream_order(
  d8_pntr = flow_dir,
  streams = streams_raster,
  output = stream_order
)

# Add stream order to vector
stream_order_rast <- rast(stream_order)
streams_sf$stream_order <- extract(stream_order_rast, vect(streams_sf), fun = max, na.rm = TRUE)[, 2]

# Save stream network
st_write(streams_sf, "outputs/downstream/stream_network.shp", delete_dsn = TRUE, quiet = TRUE)
cat("  Stream network saved ✓\n")
cat("  Total stream length:", round(sum(st_length(streams_sf)) / 1000, 1), "km\n\n")

# ============================================================================
# 5. LOAD POINTS OF INTEREST (POIs)
# ============================================================================

cat("5. Loading points of interest (POIs)...\n")

if (!file.exists(POI_FILE)) {
  stop(paste0(
    "POI file not found at ", POI_FILE, "\n",
    "Please create a CSV file with columns: poi_id, poi_name, longitude, latitude, receptor_type, priority\n",
    "See template: data_raw/poi/points_of_interest_TEMPLATE.csv"
  ))
}

# Load POIs
poi <- read.csv(POI_FILE)

# Required columns
required_cols <- c("poi_id", "poi_name", "longitude", "latitude", "receptor_type")
missing_cols <- setdiff(required_cols, names(poi))
if (length(missing_cols) > 0) {
  stop(paste("Missing required columns in POI file:", paste(missing_cols, collapse = ", ")))
}

# Convert to sf object
poi_sf <- st_as_sf(poi, coords = c("longitude", "latitude"), crs = INPUT_CRS)
poi_sf <- st_transform(poi_sf, PROCESSING_CRS)

cat("  Loaded", nrow(poi_sf), "points of interest:\n")
for (i in 1:nrow(poi_sf)) {
  cat("    -", poi_sf$poi_name[i], "(", poi_sf$receptor_type[i], ")\n")
}
cat("\n")

# ============================================================================
# 6. SNAP POUR POINTS TO STREAM NETWORK
# ============================================================================

cat("6. Snapping pour points to high flow accumulation...\n")

# Load flow accumulation raster
flow_acc_rast <- rast(flow_acc)

# Snap distance (in meters)
snap_distance <- 500  # Maximum snap distance

# Initialize snapped points
poi_snapped <- poi_sf
coords_snapped <- matrix(NA, nrow = nrow(poi_sf), ncol = 2)

for (i in 1:nrow(poi_sf)) {
  # Extract flow accumulation values in buffer around POI
  poi_buffer <- st_buffer(poi_sf[i, ], snap_distance)
  flow_acc_crop <- crop(flow_acc_rast, vect(poi_buffer))
  flow_acc_mask <- mask(flow_acc_crop, vect(poi_buffer))

  # Find cell with maximum flow accumulation
  max_idx <- which.max(values(flow_acc_mask))
  if (length(max_idx) == 0) {
    warning(paste("Could not snap POI", poi_sf$poi_name[i], "- using original location"))
    coords_snapped[i, ] <- st_coordinates(poi_sf[i, ])
  } else {
    coords_snapped[i, ] <- xyFromCell(flow_acc_mask, max_idx)
  }

  # Calculate snap distance
  orig_coords <- st_coordinates(poi_sf[i, ])
  snap_dist <- sqrt(sum((coords_snapped[i, ] - orig_coords)^2))
  cat("  -", poi_sf$poi_name[i], "snapped", round(snap_dist), "m\n")
}

# Create snapped POI sf object
poi_snapped <- st_as_sf(
  data.frame(poi_sf, snap_distance_m = NA),
  coords = coords_snapped,
  crs = PROCESSING_CRS
)

# Save snapped POIs
st_write(poi_snapped, "outputs/downstream/poi_snapped.shp", delete_dsn = TRUE, quiet = TRUE)
cat("  Snapped POIs saved ✓\n\n")

# ============================================================================
# 7. DELINEATE WATERSHEDS FOR EACH POI
# ============================================================================

cat("7. Delineating watersheds for each POI...\n")

# Create pour points raster
pour_points_rast <- rasterize(vect(poi_snapped), dem, field = 1:nrow(poi_snapped))
pour_points_path <- file.path(temp_dir, "pour_points.tif")
writeRaster(pour_points_rast, pour_points_path, overwrite = TRUE)

# Delineate watersheds
watersheds_path <- file.path(temp_dir, "watersheds.tif")
wbt_watershed(
  d8_pntr = flow_dir,
  pour_pts = pour_points_path,
  output = watersheds_path
)

# Load watersheds raster
watersheds_rast <- rast(watersheds_path)

# Vectorize watersheds
watersheds_poly <- as.polygons(watersheds_rast)
watersheds_sf <- st_as_sf(watersheds_poly)
st_crs(watersheds_sf) <- PROCESSING_CRS

# Add POI attributes
watersheds_sf$poi_id <- poi_snapped$poi_id
watersheds_sf$poi_name <- poi_snapped$poi_name
watersheds_sf$receptor_type <- poi_snapped$receptor_type

# Calculate catchment statistics
watersheds_sf$area_ha <- as.numeric(st_area(watersheds_sf)) / 10000
watersheds_sf$perimeter_m <- as.numeric(st_length(st_cast(watersheds_sf, "MULTILINESTRING")))

cat("  Watershed statistics:\n")
for (i in 1:nrow(watersheds_sf)) {
  cat("    -", watersheds_sf$poi_name[i], ":",
      round(watersheds_sf$area_ha[i], 1), "ha\n")
}

# Save watersheds
st_write(watersheds_sf, "outputs/downstream/catchments_by_poi.shp", delete_dsn = TRUE, quiet = TRUE)
cat("  Watersheds saved ✓\n\n")

# ============================================================================
# 8. IDENTIFY RESTORATION AREAS WITHIN CATCHMENTS
# ============================================================================

cat("8. Identifying restoration areas within catchments...\n")

# Check if restoration mask exists
restoration_mask_path <- "outputs/predictions/restoration_mask.tif"
if (file.exists(restoration_mask_path)) {
  restoration_mask <- rast(restoration_mask_path)

  # Calculate restoration area by catchment
  watersheds_sf$restoration_area_ha <- NA

  for (i in 1:nrow(watersheds_sf)) {
    catchment_vect <- vect(watersheds_sf[i, ])
    restoration_crop <- crop(restoration_mask, catchment_vect)
    restoration_masked <- mask(restoration_crop, catchment_vect)

    # Sum restored cells
    restored_cells <- sum(values(restoration_masked) == 1, na.rm = TRUE)
    cell_area_ha <- res(restoration_masked)[1] * res(restoration_masked)[2] / 10000
    watersheds_sf$restoration_area_ha[i] <- restored_cells * cell_area_ha
  }

  watersheds_sf$restoration_pct <- (watersheds_sf$restoration_area_ha / watersheds_sf$area_ha) * 100

  cat("  Restoration coverage by catchment:\n")
  for (i in 1:nrow(watersheds_sf)) {
    cat("    -", watersheds_sf$poi_name[i], ":",
        round(watersheds_sf$restoration_area_ha[i], 1), "ha (",
        round(watersheds_sf$restoration_pct[i], 1), "%)\n")
  }

} else {
  cat("  No restoration mask found - skipping restoration area calculation\n")
  cat("  (Create restoration_mask.tif showing restored pixels = 1, other = 0)\n")
}

cat("\n")

# ============================================================================
# 9. SAVE FLOW ROUTING OUTPUTS
# ============================================================================

cat("9. Saving flow routing outputs...\n")

# Copy flow direction and accumulation to outputs
flow_dir_out <- "outputs/downstream/flow_direction.tif"
flow_acc_out <- "outputs/downstream/flow_accumulation.tif"

file.copy(flow_dir, flow_dir_out, overwrite = TRUE)
file.copy(flow_acc, flow_acc_out, overwrite = TRUE)

cat("  Flow direction saved ✓\n")
cat("  Flow accumulation saved ✓\n\n")

# ============================================================================
# 10. EXPORT SUMMARY STATISTICS
# ============================================================================

cat("10. Exporting summary statistics...\n")

# Create catchment statistics table
catchment_stats <- st_drop_geometry(watersheds_sf) %>%
  select(poi_id, poi_name, receptor_type, area_ha, perimeter_m,
         restoration_area_ha, restoration_pct)

write.csv(catchment_stats, "outputs/downstream/tables/catchment_stats.csv", row.names = FALSE)

# Create summary report
sink("outputs/downstream/catchment_delineation_summary.txt")
cat("============================================\n")
cat("CATCHMENT DELINEATION SUMMARY\n")
cat("============================================\n\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("DEM Information:\n")
cat("  Resolution:", res(dem)[1], "m\n")
cat("  Extent:", paste(as.vector(ext(dem)), collapse = ", "), "\n")
cat("  CRS: EPSG:", PROCESSING_CRS, "\n\n")

cat("Flow Routing:\n")
cat("  Method:", FLOW_DIR_METHOD, "\n")
cat("  Depression handling:", ifelse(FILL_DEPRESSIONS, "Fill", "Breach"), "\n")
cat("  Stream threshold:", STREAM_THRESHOLD_HA, "ha\n")
cat("  Total stream length:", round(sum(st_length(streams_sf)) / 1000, 1), "km\n\n")

cat("Points of Interest:\n")
for (i in 1:nrow(catchment_stats)) {
  cat("  ", i, ".", catchment_stats$poi_name[i], "\n")
  cat("      Type:", catchment_stats$receptor_type[i], "\n")
  cat("      Catchment area:", round(catchment_stats$area_ha[i], 1), "ha\n")
  if (!is.na(catchment_stats$restoration_area_ha[i])) {
    cat("      Restoration area:", round(catchment_stats$restoration_area_ha[i], 1),
        "ha (", round(catchment_stats$restoration_pct[i], 1), "%)\n")
  }
  cat("\n")
}
sink()

cat("  Summary statistics saved ✓\n\n")

# ============================================================================
# 11. CLEANUP
# ============================================================================

cat("11. Cleaning up temporary files...\n")

# Remove temporary directory
unlink(temp_dir, recursive = TRUE)

cat("  Cleanup complete ✓\n\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("============================================\n")
cat("CATCHMENT DELINEATION COMPLETE!\n")
cat("============================================\n\n")

cat("Output files:\n")
cat("  - outputs/downstream/flow_direction.tif\n")
cat("  - outputs/downstream/flow_accumulation.tif\n")
cat("  - outputs/downstream/stream_network.shp\n")
cat("  - outputs/downstream/catchments_by_poi.shp\n")
cat("  - outputs/downstream/poi_snapped.shp\n")
cat("  - outputs/downstream/tables/catchment_stats.csv\n")
cat("  - outputs/downstream/catchment_delineation_summary.txt\n\n")

cat("Next steps:\n")
cat("  1. Review catchment boundaries and snapped POI locations\n")
cat("  2. Run sediment export analysis: source('modules/downstream/sediment_export.R')\n")
cat("  3. Run nutrient routing: source('modules/downstream/nutrient_ndr.R')\n")
cat("  4. Run hydrological analysis: source('modules/downstream/peakflow_cn.R')\n\n")
