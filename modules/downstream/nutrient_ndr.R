# ============================================================================
# DOWNSTREAM IMPACTS: NUTRIENT EXPORT & DELIVERY RATIO (NDR)
# ============================================================================
# Purpose: Estimate nitrogen and phosphorus export and route to downstream POIs
#
# Inputs:
#   - Land cover / stratum rasters
#   - Flow routing outputs
#   - Catchment boundaries
#   - Nutrient export coefficients (from config)
#
# Outputs:
#   - N and P export maps (kg/ha/yr)
#   - N and P delivered loads to POIs (kg/yr)
#   - Nutrient reduction tables and maps
#
# Methods:
#   - Export coefficient approach
#   - Nutrient Delivery Ratio (NDR) routing
#   - Retention by vegetated buffers and wetlands
#
# Author: NorthStar Labs Blue Carbon Team
# Date: 2024-11
# ============================================================================

library(terra)
library(sf)
library(dplyr)
library(ggplot2)
library(tidyr)

source("blue_carbon_config.R")

cat("\n============================================\n")
cat("NUTRIENT EXPORT & DELIVERY ANALYSIS\n")
cat("============================================\n\n")

# Load base data
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

cat("1. Computing nutrient export coefficients...\n")

# Create export coefficient rasters
compute_nutrient_export <- function(nutrient, scenario_col) {
  export_raster <- dem * 0

  for (i in seq_along(VALID_STRATA)) {
    stratum_name <- VALID_STRATA[i]
    export_row <- which(NUTRIENT_EXPORT_COEFFICIENTS$stratum == stratum_name)

    if (length(export_row) > 0 && scenario_col %in% names(NUTRIENT_EXPORT_COEFFICIENTS)) {
      export_value <- NUTRIENT_EXPORT_COEFFICIENTS[export_row, scenario_col]
      export_raster[landcover == i] <- export_value
    }
  }

  return(export_raster)
}

# Nitrogen export
n_export_baseline <- compute_nutrient_export("N", "n_baseline")
n_export_project <- compute_nutrient_export("N", "n_project")

# Phosphorus export
p_export_baseline <- compute_nutrient_export("P", "p_baseline")
p_export_project <- compute_nutrient_export("P", "p_project")

cat("  Nutrient export coefficients assigned ✓\n\n")

# 2. Compute retention efficiency
cat("2. Computing nutrient retention...\n")

n_retention <- dem * 0
p_retention <- dem * 0

for (i in seq_along(VALID_STRATA)) {
  stratum_name <- VALID_STRATA[i]
  ret_row <- which(NUTRIENT_RETENTION$stratum == stratum_name)

  if (length(ret_row) > 0) {
    n_retention[landcover == i] <- NUTRIENT_RETENTION$n_retention_pct[ret_row] / 100
    p_retention[landcover == i] <- NUTRIENT_RETENTION$p_retention_pct[ret_row] / 100
  }
}

cat("  Retention efficiencies assigned ✓\n\n")

# 3. Compute NDR (delivery ratio to stream)
cat("3. Computing Nutrient Delivery Ratio (NDR)...\n")

cell_size <- res(dem)[1]
stream_threshold <- 1000
streams <- flow_acc > stream_threshold

d_up <- log10(flow_acc + 1)
dist_to_stream <- distance(streams)
d_dn <- log10(dist_to_stream / cell_size + 1)
ic <- d_up - d_dn

ndr <- 1 / (1 + exp((NDR_IC0 - ic) / NDR_K))
ndr[ndr < 0] <- 0
ndr[ndr > 1] <- 1

writeRaster(ndr, "outputs/downstream/nutrient_delivery_ratio.tif", overwrite = TRUE)
cat("  NDR computed (mean:", round(global(ndr, "mean", na.rm = TRUE)[1, 1], 3), ") ✓\n\n")

# 4. Compute delivered loads
cat("4. Computing delivered nutrient loads...\n")

cell_area_ha <- (res(dem)[1] * res(dem)[2]) / 10000

# Nitrogen delivered = export × (1 - retention) × NDR × area
n_delivered_baseline <- n_export_baseline * (1 - n_retention) * ndr * cell_area_ha
n_delivered_project <- n_export_project * (1 - n_retention) * ndr * cell_area_ha

# Phosphorus delivered
p_delivered_baseline <- p_export_baseline * (1 - p_retention) * ndr * cell_area_ha
p_delivered_project <- p_export_project * (1 - p_retention) * ndr * cell_area_ha

# Reductions
n_reduction <- n_delivered_baseline - n_delivered_project
p_reduction <- p_delivered_baseline - p_delivered_project

# Save rasters
writeRaster(n_delivered_baseline, "outputs/downstream/nitrogen_delivered_baseline.tif", overwrite = TRUE)
writeRaster(n_delivered_project, "outputs/downstream/nitrogen_delivered_project.tif", overwrite = TRUE)
writeRaster(n_reduction, "outputs/downstream/nitrogen_reduction.tif", overwrite = TRUE)

writeRaster(p_delivered_baseline, "outputs/downstream/phosphorus_delivered_baseline.tif", overwrite = TRUE)
writeRaster(p_delivered_project, "outputs/downstream/phosphorus_delivered_project.tif", overwrite = TRUE)
writeRaster(p_reduction, "outputs/downstream/phosphorus_reduction.tif", overwrite = TRUE)

cat("  Delivered nutrient loads computed ✓\n\n")

# 5. Aggregate by catchment
cat("5. Aggregating nutrient loads by catchment...\n")

results <- data.frame()

for (i in 1:nrow(catchments)) {
  poi_name <- catchments$poi_name[i]
  catchment_vect <- vect(catchments[i, ])

  # Extract N loads
  n_base_mask <- mask(crop(n_delivered_baseline, catchment_vect), catchment_vect)
  n_proj_mask <- mask(crop(n_delivered_project, catchment_vect), catchment_vect)

  n_load_baseline <- global(n_base_mask, "sum", na.rm = TRUE)[1, 1]
  n_load_project <- global(n_proj_mask, "sum", na.rm = TRUE)[1, 1]
  n_reduction_val <- n_load_baseline - n_load_project

  # Extract P loads
  p_base_mask <- mask(crop(p_delivered_baseline, catchment_vect), catchment_vect)
  p_proj_mask <- mask(crop(p_delivered_project, catchment_vect), catchment_vect)

  p_load_baseline <- global(p_base_mask, "sum", na.rm = TRUE)[1, 1]
  p_load_project <- global(p_proj_mask, "sum", na.rm = TRUE)[1, 1]
  p_reduction_val <- p_load_baseline - p_load_project

  results <- rbind(results, data.frame(
    poi_id = catchments$poi_id[i],
    poi_name = poi_name,
    receptor_type = catchments$receptor_type[i],
    n_load_baseline_kg_yr = n_load_baseline,
    n_load_project_kg_yr = n_load_project,
    n_reduction_kg_yr = n_reduction_val,
    n_reduction_pct = (n_reduction_val / n_load_baseline) * 100,
    p_load_baseline_kg_yr = p_load_baseline,
    p_load_project_kg_yr = p_load_project,
    p_reduction_kg_yr = p_reduction_val,
    p_reduction_pct = (p_reduction_val / p_load_baseline) * 100
  ))
}

results <- results %>% mutate(across(where(is.numeric), ~ round(.x, 2)))
write.csv(results, "outputs/downstream/tables/nutrient_reduction_by_poi.csv", row.names = FALSE)

cat("\n  Nutrient reduction summary:\n")
print(results %>% select(poi_name, n_reduction_kg_yr, p_reduction_kg_yr))
cat("\n")

# 6. Visualizations
cat("6. Creating visualization maps...\n")

png("outputs/downstream/maps/nitrogen_reduction_map.png",
    width = FIGURE_WIDTH, height = FIGURE_HEIGHT, units = "in", res = FIGURE_DPI)
plot(n_reduction, main = "Nitrogen Load Reduction (kg/yr)",
     col = hcl.colors(100, "Blues", rev = TRUE))
plot(st_geometry(catchments), add = TRUE, border = "darkblue", lwd = 2)
dev.off()

png("outputs/downstream/maps/phosphorus_reduction_map.png",
    width = FIGURE_WIDTH, height = FIGURE_HEIGHT, units = "in", res = FIGURE_DPI)
plot(p_reduction, main = "Phosphorus Load Reduction (kg/yr)",
     col = hcl.colors(100, "Greens", rev = TRUE))
plot(st_geometry(catchments), add = TRUE, border = "darkgreen", lwd = 2)
dev.off()

cat("  Maps saved ✓\n\n")

# Summary
cat("============================================\n")
cat("NUTRIENT ANALYSIS COMPLETE!\n")
cat("============================================\n\n")
cat("Total N reduction:", round(sum(results$n_reduction_kg_yr), 1), "kg/yr\n")
cat("Total P reduction:", round(sum(results$p_reduction_kg_yr), 1), "kg/yr\n\n")
