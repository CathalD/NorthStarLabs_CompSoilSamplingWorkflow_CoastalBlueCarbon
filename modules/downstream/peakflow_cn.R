# ============================================================================
# DOWNSTREAM IMPACTS: PEAK FLOW & FLOOD MITIGATION (Curve Number Method)
# ============================================================================
# Purpose: Estimate changes in runoff and peak flow due to restoration
#
# Methods:
#   - SCS Curve Number method for runoff estimation
#   - Simple unit hydrograph for peak flow approximation
#   - Scenario comparison (baseline vs project)
#
# Author: NorthStar Labs Blue Carbon Team
# Date: 2024-11
# ============================================================================

library(terra)
library(sf)
library(dplyr)

source("blue_carbon_config.R")

cat("\n============================================\n")
cat("PEAK FLOW & FLOOD MITIGATION ANALYSIS\n")
cat("============================================\n\n")

# Load data
dem <- rast("data_raw/hydrology/dem.tif")
if (st_crs(crs(dem, proj = TRUE))$epsg != PROCESSING_CRS) {
  dem <- project(dem, paste0("EPSG:", PROCESSING_CRS))
}

flow_acc <- rast("outputs/downstream/flow_accumulation.tif")
catchments <- st_read("outputs/downstream/catchments_by_poi.shp", quiet = TRUE)

# Create land cover raster
stratum_files <- list.files("data_raw/gee_strata", pattern = "\\.tif$", full.names = TRUE)
landcover <- rast(stratum_files[1])
landcover[] <- 0

for (i in seq_along(VALID_STRATA)) {
  stratum_name <- VALID_STRATA[i]
  stratum_file <- gsub(" ", "_", tolower(stratum_name))
  stratum_path <- file.path("data_raw/gee_strata", paste0(stratum_file, ".tif"))
  if (file.exists(stratum_path)) {
    stratum_mask <- rast(stratum_path)
    landcover[stratum_mask == 1] <- i
  }
}

cat("1. Computing Curve Numbers (CN)...\n")

# Create CN rasters for scenarios
cn_baseline <- dem * 0
cn_project <- dem * 0

for (i in seq_along(VALID_STRATA)) {
  stratum_name <- VALID_STRATA[i]
  cn_row <- which(CURVE_NUMBERS$stratum == stratum_name)

  if (length(cn_row) > 0) {
    cn_baseline[landcover == i] <- CURVE_NUMBERS$cn_baseline[cn_row]
    cn_project[landcover == i] <- CURVE_NUMBERS$cn_project[cn_row]
  }
}

writeRaster(cn_baseline, "outputs/downstream/curve_number_baseline.tif", overwrite = TRUE)
writeRaster(cn_project, "outputs/downstream/curve_number_project.tif", overwrite = TRUE)

cat("  CN assigned (baseline mean:", round(global(cn_baseline, "mean", na.rm = TRUE)[1, 1], 1), ")\n")
cat("  CN assigned (project mean:", round(global(cn_project, "mean", na.rm = TRUE)[1, 1], 1), ")\n\n")

cat("2. Computing runoff for design storm...\n")

# Design storm: 24-hour, 25-year return period (typical for BC coast: ~100mm)
# User should customize based on local IDF curves
design_precip_mm <- 100
cat("  Using design precipitation:", design_precip_mm, "mm\n")

# SCS Runoff equation: Q = (P - 0.2S)² / (P + 0.8S)
# where S = (25400/CN) - 254 (in mm), P = precipitation (mm)

compute_runoff <- function(cn_raster, precip_mm) {
  s <- (25400 / cn_raster) - 254  # Potential maximum retention (mm)
  ia <- 0.2 * s  # Initial abstraction

  # Runoff only occurs when P > Ia
  runoff <- ((precip_mm - ia)^2) / (precip_mm + 0.8 * s)
  runoff[precip_mm <= ia] <- 0
  runoff[runoff < 0] <- 0

  return(runoff)
}

runoff_baseline <- compute_runoff(cn_baseline, design_precip_mm)
runoff_project <- compute_runoff(cn_project, design_precip_mm)
runoff_reduction <- runoff_baseline - runoff_project

writeRaster(runoff_baseline, "outputs/downstream/runoff_baseline_mm.tif", overwrite = TRUE)
writeRaster(runoff_project, "outputs/downstream/runoff_project_mm.tif", overwrite = TRUE)
writeRaster(runoff_reduction, "outputs/downstream/runoff_reduction_mm.tif", overwrite = TRUE)

cat("  Runoff computed ✓\n\n")

cat("3. Estimating peak flow reduction...\n")

# Simple peak flow estimation using rational method approximation
# Q_peak = C × I × A, where adjustment for restoration improves infiltration
# More sophisticated: use unit hydrograph, but requires time-to-peak estimation

results <- data.frame()

for (i in 1:nrow(catchments)) {
  poi_name <- catchments$poi_name[i]
  catchment_vect <- vect(catchments[i, ])
  catchment_area_ha <- catchments$area_ha[i]
  catchment_area_km2 <- catchment_area_ha / 100

  # Average runoff depth (mm)
  runoff_base_mask <- mask(crop(runoff_baseline, catchment_vect), catchment_vect)
  runoff_proj_mask <- mask(crop(runoff_project, catchment_vect), catchment_vect)

  runoff_base_mean <- global(runoff_base_mask, "mean", na.rm = TRUE)[1, 1]
  runoff_proj_mean <- global(runoff_proj_mask, "mean", na.rm = TRUE)[1, 1]
  runoff_reduction_mm <- runoff_base_mean - runoff_proj_mean

  # Convert to volume (m³)
  # Volume = depth (mm) × area (m²) / 1000
  catchment_area_m2 <- catchment_area_ha * 10000
  runoff_vol_base_m3 <- runoff_base_mean * catchment_area_m2 / 1000
  runoff_vol_proj_m3 <- runoff_proj_mean * catchment_area_m2 / 1000
  runoff_vol_reduction_m3 <- runoff_vol_base_m3 - runoff_vol_proj_m3

  # Approximate peak flow using simple scaling
  # Assume time-to-peak ~2 hours for small coastal catchments
  time_to_peak_hr <- 2
  # Peak flow (m³/s) ~ Volume (m³) / (time × 3600) × shape factor (~0.5 for wetlands)
  shape_factor <- 0.5

  peak_flow_base_m3s <- (runoff_vol_base_m3 / (time_to_peak_hr * 3600)) * shape_factor
  peak_flow_proj_m3s <- (runoff_vol_proj_m3 / (time_to_peak_hr * 3600)) * shape_factor
  peak_flow_reduction_m3s <- peak_flow_base_m3s - peak_flow_proj_m3s

  results <- rbind(results, data.frame(
    poi_id = catchments$poi_id[i],
    poi_name = poi_name,
    receptor_type = catchments$receptor_type[i],
    catchment_area_ha = catchment_area_ha,
    runoff_baseline_mm = runoff_base_mean,
    runoff_project_mm = runoff_proj_mean,
    runoff_reduction_mm = runoff_reduction_mm,
    runoff_reduction_pct = (runoff_reduction_mm / runoff_base_mean) * 100,
    runoff_volume_reduction_m3 = runoff_vol_reduction_m3,
    peak_flow_baseline_m3s = peak_flow_base_m3s,
    peak_flow_project_m3s = peak_flow_proj_m3s,
    peak_flow_reduction_m3s = peak_flow_reduction_m3s,
    peak_flow_reduction_pct = (peak_flow_reduction_m3s / peak_flow_base_m3s) * 100
  ))
}

results <- results %>% mutate(across(where(is.numeric), ~ round(.x, 2)))
write.csv(results, "outputs/downstream/tables/flood_mitigation_by_poi.csv", row.names = FALSE)

cat("\n  Flood mitigation summary:\n")
print(results %>% select(poi_name, runoff_reduction_mm, peak_flow_reduction_m3s))
cat("\n")

# Visualizations
png("outputs/downstream/maps/runoff_reduction_map.png",
    width = FIGURE_WIDTH, height = FIGURE_HEIGHT, units = "in", res = FIGURE_DPI)
plot(runoff_reduction, main = "Runoff Reduction (mm) - Design Storm",
     col = hcl.colors(100, "Blues", rev = TRUE))
plot(st_geometry(catchments), add = TRUE, border = "blue", lwd = 2)
dev.off()

cat("============================================\n")
cat("FLOOD MITIGATION ANALYSIS COMPLETE!\n")
cat("============================================\n\n")
cat("Total peak flow reduction:", round(sum(results$peak_flow_reduction_m3s), 2), "m³/s\n")
cat("Total runoff volume reduced:", round(sum(results$runoff_volume_reduction_m3), 0), "m³\n\n")
