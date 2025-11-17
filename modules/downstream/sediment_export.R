# ============================================================================
# DOWNSTREAM IMPACTS: SEDIMENT EXPORT & DELIVERY
# ============================================================================
# Purpose: Estimate sediment export using RUSLE and route to POIs using NDR
#
# Inputs:
#   - DEM and flow routing outputs - outputs/downstream/
#   - Land cover / stratum rasters - data_raw/gee_strata/
#   - Catchment boundaries - outputs/downstream/catchments_by_poi.shp
#   - Rainfall erosivity data (optional) - data_raw/hydrology/rainfall_erosivity.tif
#   - Scenario masks (baseline vs project) - outputs/predictions/
#
# Outputs:
#   - Sediment loss per pixel (t/ha/yr) - outputs/downstream/sediment_loss_baseline.tif
#   - Sediment delivery to stream (t/yr) - outputs/downstream/sediment_delivered_baseline.tif
#   - Avoided sediment loads by POI - outputs/downstream/tables/sediment_reduction_by_poi.csv
#   - Sediment impact maps - outputs/downstream/maps/sediment_*.png
#
# Methods:
#   - RUSLE: A = R × K × LS × C × P
#   - Sediment Delivery Ratio (SDR) using NDR approach
#   - Before/after scenario comparison for impact attribution
#
# Author: NorthStar Labs Blue Carbon Team
# Date: 2024-11
# ============================================================================

library(terra)
library(sf)
library(dplyr)
library(ggplot2)

# Source configuration
source("blue_carbon_config.R")

# ============================================================================
# SETUP & VALIDATION
# ============================================================================

cat("\n============================================\n")
cat("SEDIMENT EXPORT & DELIVERY ANALYSIS\n")
cat("============================================\n\n")

if (!ENABLE_DOWNSTREAM_IMPACTS || !IMPACTS_ENABLED$sediment_loads) {
  stop("Sediment analysis is disabled. Enable in blue_carbon_config.R")
}

# Check prerequisites
required_files <- c(
  "outputs/downstream/flow_accumulation.tif",
  "outputs/downstream/catchments_by_poi.shp"
)

for (f in required_files) {
  if (!file.exists(f)) {
    stop(paste("Required file not found:", f, "\nRun delineate_catchments.R first"))
  }
}

# ============================================================================
# 1. LOAD BASE DATA
# ============================================================================

cat("1. Loading base data...\n")

# Load DEM and derivatives
dem <- rast("data_raw/hydrology/dem.tif")
if (st_crs(crs(dem, proj = TRUE))$epsg != PROCESSING_CRS) {
  dem <- project(dem, paste0("EPSG:", PROCESSING_CRS))
}

flow_acc <- rast("outputs/downstream/flow_accumulation.tif")
catchments <- st_read("outputs/downstream/catchments_by_poi.shp", quiet = TRUE)

# Load stratum/land cover raster
stratum_files <- list.files("data_raw/gee_strata", pattern = "\\.tif$", full.names = TRUE)
if (length(stratum_files) == 0) {
  stop("No stratum rasters found in data_raw/gee_strata/\nExport from GEE first")
}

# Create unified land cover raster
cat("  Creating unified land cover raster...\n")
landcover <- rast(stratum_files[1])
landcover[] <- 0  # Initialize

# Assign stratum codes
for (i in seq_along(VALID_STRATA)) {
  stratum_name <- VALID_STRATA[i]
  stratum_file <- gsub(" ", "_", tolower(stratum_name))
  stratum_path <- file.path("data_raw/gee_strata", paste0(stratum_file, ".tif"))

  if (file.exists(stratum_path)) {
    stratum_mask <- rast(stratum_path)
    landcover[stratum_mask == 1] <- i
  }
}

cat("  Base data loaded ✓\n\n")

# ============================================================================
# 2. COMPUTE RUSLE FACTORS
# ============================================================================

cat("2. Computing RUSLE factors...\n")

# ---- R Factor: Rainfall Erosivity ----
cat("  Computing R factor (rainfall erosivity)...\n")

r_factor_path <- "data_raw/hydrology/rainfall_erosivity.tif"
if (file.exists(r_factor_path)) {
  r_factor <- rast(r_factor_path)
  r_factor <- project(r_factor, dem, method = "bilinear")
  cat("    Using custom R factor raster\n")
} else {
  # Use default value
  r_factor <- dem * 0 + RUSLE_R_DEFAULT
  cat("    Using default R factor:", RUSLE_R_DEFAULT, "MJ mm/(ha h yr)\n")
}

# ---- K Factor: Soil Erodibility ----
cat("  Computing K factor (soil erodibility)...\n")

k_factor <- dem * 0
for (i in seq_along(VALID_STRATA)) {
  stratum_name <- VALID_STRATA[i]
  k_value <- RUSLE_K_FACTORS[[stratum_name]]
  if (!is.null(k_value)) {
    k_factor[landcover == i] <- k_value
  }
}
cat("    K factor assigned by stratum\n")

# ---- LS Factor: Slope Length-Steepness ----
cat("  Computing LS factor (topography)...\n")

# Calculate slope (degrees)
slope <- terrain(dem, "slope", unit = "degrees")

# Calculate flow accumulation in meters
cell_size <- res(dem)[1]
flow_length <- flow_acc * cell_size  # Approximate flow path length

# LS factor formula (Moore & Burch 1986, adapted for coastal wetlands)
# LS = (flow_length / 22.13)^m × (sin(slope) / 0.0896)^n
# where m = 0.4-0.6 (typically 0.5), n = 1.2-1.4 (typically 1.3)
m <- 0.5
n <- 1.3

slope_rad <- slope * pi / 180
ls_factor <- (flow_length / 22.13)^m * (sin(slope_rad) / 0.0896)^n

# Cap extreme values for coastal wetlands (typically low relief)
ls_factor[ls_factor > 20] <- 20
ls_factor[ls_factor < 0.01] <- 0.01

cat("    LS factor computed (range:", round(global(ls_factor, "min", na.rm = TRUE)[1, 1], 2),
    "to", round(global(ls_factor, "max", na.rm = TRUE)[1, 1], 2), ")\n")

# ---- P Factor: Support Practice ----
cat("  Setting P factor (support practice)...\n")
p_factor <- dem * 0 + RUSLE_P_DEFAULT
cat("    P factor:", RUSLE_P_DEFAULT, "(no mechanical erosion control)\n")

cat("  RUSLE factors complete ✓\n\n")

# ============================================================================
# 3. COMPUTE SEDIMENT LOSS FOR SCENARIOS
# ============================================================================

cat("3. Computing sediment loss for scenarios...\n")

compute_sediment_loss <- function(scenario_name, c_factor_col) {
  cat("  Scenario:", scenario_name, "\n")

  # Create C factor raster
  c_factor <- dem * 0

  for (i in seq_along(VALID_STRATA)) {
    stratum_name <- VALID_STRATA[i]

    # Find matching row in RUSLE_C_FACTORS
    c_row <- which(RUSLE_C_FACTORS$stratum == stratum_name)
    if (length(c_row) > 0 && c_factor_col %in% names(RUSLE_C_FACTORS)) {
      c_value <- RUSLE_C_FACTORS[c_row, c_factor_col]
      c_factor[landcover == i] <- c_value
    }
  }

  # RUSLE equation: A = R × K × LS × C × P (tonnes/ha/yr)
  sediment_loss <- r_factor * k_factor * ls_factor * c_factor * p_factor

  # Save sediment loss raster
  output_path <- paste0("outputs/downstream/sediment_loss_", scenario_name, ".tif")
  writeRaster(sediment_loss, output_path, overwrite = TRUE)

  cat("    Mean sediment loss:", round(global(sediment_loss, "mean", na.rm = TRUE)[1, 1], 2), "t/ha/yr\n")
  cat("    Saved:", output_path, "\n")

  return(sediment_loss)
}

# Compute for baseline and project scenarios
sediment_baseline <- compute_sediment_loss("baseline", "baseline")
sediment_project_y0 <- compute_sediment_loss("project_y0", "project_y0")
sediment_project_y5 <- compute_sediment_loss("project_y5", "project_y5")
sediment_project_y10 <- compute_sediment_loss("project_y10", "project_y10")

# Compute reduction
sediment_reduction_y5 <- sediment_baseline - sediment_project_y5
sediment_reduction_y10 <- sediment_baseline - sediment_project_y10

writeRaster(sediment_reduction_y5, "outputs/downstream/sediment_reduction_y5.tif", overwrite = TRUE)
writeRaster(sediment_reduction_y10, "outputs/downstream/sediment_reduction_y10.tif", overwrite = TRUE)

cat("\n")

# ============================================================================
# 4. COMPUTE SEDIMENT DELIVERY RATIO (SDR)
# ============================================================================

cat("4. Computing Sediment Delivery Ratio (SDR)...\n")

if (SEDIMENT_DELIVERY_METHOD == "ndr") {
  cat("  Using Nutrient Delivery Ratio (NDR) approach...\n")

  # Connectivity index (IC) based on upslope and downslope factors
  # IC = log10(D_up / D_dn)
  # where D_up = upslope contributing area, D_dn = downslope flow path to stream

  # Upslope factor: flow accumulation
  d_up <- log10(flow_acc + 1)

  # Downslope factor: distance to stream (inverse)
  # Create stream mask (high flow accumulation = stream)
  stream_threshold <- 1000  # cells
  streams <- flow_acc > stream_threshold

  # Distance to stream
  dist_to_stream <- distance(streams)
  d_dn <- log10(dist_to_stream / cell_size + 1)

  # Connectivity index
  ic <- d_up - d_dn

  # Sediment Delivery Ratio (SDR) using NDR formula
  # SDR = 1 / (1 + exp((IC0 - IC) / k))
  sdr <- 1 / (1 + exp((NDR_IC0 - ic) / NDR_K))

  # Cap SDR to [0, 1]
  sdr[sdr < 0] <- 0
  sdr[sdr > 1] <- 1

  cat("    Mean SDR:", round(global(sdr, "mean", na.rm = TRUE)[1, 1], 3), "\n")
  writeRaster(sdr, "outputs/downstream/sediment_delivery_ratio.tif", overwrite = TRUE)

} else if (SEDIMENT_DELIVERY_METHOD == "distance_decay") {
  # Simple distance-decay model
  dist_to_stream <- distance(streams)
  sdr <- exp(-dist_to_stream / 1000)  # Exponential decay with 1 km characteristic distance
  sdr[sdr < 0.01] <- 0.01

} else {
  # Default: uniform SDR
  sdr <- dem * 0 + 0.5
}

cat("  SDR computed ✓\n\n")

# ============================================================================
# 5. COMPUTE DELIVERED SEDIMENT LOAD
# ============================================================================

cat("5. Computing delivered sediment load...\n")

# Convert sediment loss (t/ha/yr) to total load (t/yr) per cell
cell_area_ha <- (res(dem)[1] * res(dem)[2]) / 10000

sediment_delivered_baseline <- sediment_baseline * sdr * cell_area_ha
sediment_delivered_project_y5 <- sediment_project_y5 * sdr * cell_area_ha
sediment_delivered_project_y10 <- sediment_project_y10 * sdr * cell_area_ha

writeRaster(sediment_delivered_baseline, "outputs/downstream/sediment_delivered_baseline.tif", overwrite = TRUE)
writeRaster(sediment_delivered_project_y5, "outputs/downstream/sediment_delivered_project_y5.tif", overwrite = TRUE)
writeRaster(sediment_delivered_project_y10, "outputs/downstream/sediment_delivered_project_y10.tif", overwrite = TRUE)

cat("  Delivered sediment rasters saved ✓\n\n")

# ============================================================================
# 6. AGGREGATE TO CATCHMENTS & POIs
# ============================================================================

cat("6. Aggregating sediment loads by catchment...\n")

results <- data.frame()

for (i in 1:nrow(catchments)) {
  poi_name <- catchments$poi_name[i]
  cat("  Processing:", poi_name, "\n")

  # Extract catchment
  catchment <- catchments[i, ]
  catchment_vect <- vect(catchment)

  # Crop and mask sediment rasters
  sed_base_crop <- crop(sediment_delivered_baseline, catchment_vect)
  sed_base_mask <- mask(sed_base_crop, catchment_vect)

  sed_y5_crop <- crop(sediment_delivered_project_y5, catchment_vect)
  sed_y5_mask <- mask(sed_y5_crop, catchment_vect)

  sed_y10_crop <- crop(sediment_delivered_project_y10, catchment_vect)
  sed_y10_mask <- mask(sed_y10_crop, catchment_vect)

  # Sum sediment loads (t/yr)
  load_baseline <- global(sed_base_mask, "sum", na.rm = TRUE)[1, 1]
  load_project_y5 <- global(sed_y5_mask, "sum", na.rm = TRUE)[1, 1]
  load_project_y10 <- global(sed_y10_mask, "sum", na.rm = TRUE)[1, 1]

  # Calculate reductions
  reduction_y5 <- load_baseline - load_project_y5
  reduction_y10 <- load_baseline - load_project_y10
  reduction_pct_y5 <- (reduction_y5 / load_baseline) * 100
  reduction_pct_y10 <- (reduction_y10 / load_baseline) * 100

  # Append results
  results <- rbind(results, data.frame(
    poi_id = catchment$poi_id,
    poi_name = poi_name,
    receptor_type = catchment$receptor_type,
    catchment_area_ha = catchment$area_ha,
    sediment_load_baseline_t_yr = load_baseline,
    sediment_load_project_y5_t_yr = load_project_y5,
    sediment_load_project_y10_t_yr = load_project_y10,
    sediment_reduction_y5_t_yr = reduction_y5,
    sediment_reduction_y10_t_yr = reduction_y10,
    sediment_reduction_y5_pct = reduction_pct_y5,
    sediment_reduction_y10_pct = reduction_pct_y10
  ))
}

# Round results
results <- results %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

# Save results
write.csv(results, "outputs/downstream/tables/sediment_reduction_by_poi.csv", row.names = FALSE)

cat("\n  Results summary:\n")
print(results %>% select(poi_name, sediment_reduction_y5_t_yr, sediment_reduction_y5_pct))
cat("\n")

# ============================================================================
# 7. VISUALIZE RESULTS
# ============================================================================

cat("7. Creating visualization maps...\n")

# Plot sediment reduction map (Y5)
png("outputs/downstream/maps/sediment_reduction_map_y5.png",
    width = FIGURE_WIDTH, height = FIGURE_HEIGHT, units = "in", res = FIGURE_DPI)

plot(sediment_reduction_y5,
     main = "Sediment Load Reduction (Baseline vs Project Year 5)",
     col = hcl.colors(100, "Reds", rev = TRUE),
     xlab = "Easting", ylab = "Northing")
plot(st_geometry(catchments), add = TRUE, border = "blue", lwd = 2)

dev.off()

cat("  Map saved: outputs/downstream/maps/sediment_reduction_map_y5.png\n")

# Bar chart of reductions by POI
png("outputs/downstream/maps/sediment_reduction_by_poi.png",
    width = 10, height = 6, units = "in", res = 300)

ggplot(results, aes(x = reorder(poi_name, sediment_reduction_y5_t_yr), y = sediment_reduction_y5_t_yr)) +
  geom_bar(stat = "identity", fill = "#2E86AB") +
  coord_flip() +
  labs(
    title = "Sediment Load Reduction by Receptor (Year 5)",
    x = "Point of Interest",
    y = "Sediment Reduction (tonnes/yr)"
  ) +
  theme_minimal() +
  theme(text = element_text(size = 12))

dev.off()

cat("  Chart saved: outputs/downstream/maps/sediment_reduction_by_poi.png\n\n")

# ============================================================================
# 8. EXPORT SUMMARY
# ============================================================================

cat("8. Exporting summary report...\n")

sink("outputs/downstream/sediment_analysis_summary.txt")
cat("============================================\n")
cat("SEDIMENT EXPORT & DELIVERY ANALYSIS\n")
cat("============================================\n\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("RUSLE Parameters:\n")
cat("  R factor:", RUSLE_R_DEFAULT, "MJ mm/(ha h yr)\n")
cat("  P factor:", RUSLE_P_DEFAULT, "\n")
cat("  Delivery method:", SEDIMENT_DELIVERY_METHOD, "\n\n")

cat("Sediment Load Reductions:\n")
cat("─────────────────────────────────────────\n")
for (i in 1:nrow(results)) {
  cat("\n", results$poi_name[i], "\n")
  cat("  Receptor type:", results$receptor_type[i], "\n")
  cat("  Catchment area:", results$catchment_area_ha[i], "ha\n")
  cat("  Baseline load:", results$sediment_load_baseline_t_yr[i], "t/yr\n")
  cat("  Year 5 reduction:", results$sediment_reduction_y5_t_yr[i], "t/yr (",
      results$sediment_reduction_y5_pct[i], "%)\n")
  cat("  Year 10 reduction:", results$sediment_reduction_y10_t_yr[i], "t/yr (",
      results$sediment_reduction_y10_pct[i], "%)\n")
}

cat("\n\nTotal Project Benefits:\n")
cat("  Total sediment avoided (Y5):", sum(results$sediment_reduction_y5_t_yr), "t/yr\n")
cat("  Total sediment avoided (Y10):", sum(results$sediment_reduction_y10_t_yr), "t/yr\n")

sink()

cat("  Summary saved ✓\n\n")

# ============================================================================
# COMPLETION
# ============================================================================

cat("============================================\n")
cat("SEDIMENT ANALYSIS COMPLETE!\n")
cat("============================================\n\n")

cat("Key findings:\n")
cat("  Total sediment reduction (Year 5):", round(sum(results$sediment_reduction_y5_t_yr), 1), "t/yr\n")
cat("  Total sediment reduction (Year 10):", round(sum(results$sediment_reduction_y10_t_yr), 1), "t/yr\n")
cat("  Equivalent to ~", round(sum(results$sediment_reduction_y5_t_yr) / 20, 0),
    "dump truck loads per year avoided\n\n")

cat("Next steps:\n")
cat("  1. Run nutrient analysis: source('modules/downstream/nutrient_ndr.R')\n")
cat("  2. Run hydrological analysis: source('modules/downstream/peakflow_cn.R')\n\n")
