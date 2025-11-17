################################################################################
# SAMPLING DESIGN - PART 2: PLOT DESIGN & OPTIMIZATION
################################################################################
# Purpose: Generate optimized plot locations for field sampling
# Input: Stratification map from SAMPLING_01
# Output: Plot locations (GPS coordinates), field data sheets, maps
# Methods: Stratified random sampling, systematic sampling, spatially balanced
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

source("forest_carbon_config.R")

required_packages <- c(
  "terra", "sf", "dplyr", "ggplot2", "viridis",
  "sp", "spsample",  # Spatial sampling
  "BalancedSampling",  # Spatially balanced sampling
  "openxlsx"  # Excel export for field sheets
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Load stratification results
workspace_file <- file.path(DIRECTORIES$sampling, "stratification_workspace.RData")

if (file.exists(workspace_file)) {
  load(workspace_file)
  cat("Loaded stratification data\n")
} else {
  stop("ERROR: Stratification workspace not found. Run SAMPLING_01 first!")
}

# Plot Design Parameters
PLOT_DESIGN <- list(
  # Sampling method
  # "stratified_random" - Random within each stratum (most common)
  # "systematic" - Regular grid
  # "spatially_balanced" - Cube method (Grafström & Tillé)
  method = "stratified_random",

  # Plot type from config
  plot_type = "fixed_area",  # or "variable_radius" or "peatland"

  # Fixed area plot parameters
  plot_radius_m = 11.28,  # 400 m² circular plot
  plot_area_m2 = 400,

  # Buffer from boundaries (m)
  edge_buffer_m = 50,

  # Minimum distance between plots (m)
  min_distance_m = 100,

  # Oversample percentage (in case plots are inaccessible)
  oversample_pct = 0.20,  # 20% extra plots

  # Peatland-specific (if applicable)
  peatland_plot_config = list(
    plot_size_m = 10,  # 10m x 10m square
    core_locations_per_plot = 3,  # Soil cores per plot
    core_depth_cm = 300
  )
)

# Field Data Collection
FIELD_CONFIG <- list(
  # Tree measurements
  dbh_threshold_cm = 5,  # Minimum DBH to measure

  # Data to collect per plot
  plot_data = c(
    "GPS coordinates (lat/lon)",
    "Slope (%)",
    "Aspect (degrees)",
    "Canopy cover (%)",
    "Dominant species",
    "Stand age class"
  ),

  # Tree data per plot
  tree_data = c(
    "Tree ID",
    "Species",
    "DBH (cm)",
    "Height (m) - subsample",
    "Crown class (dominant/codominant/intermediate/suppressed)"
  ),

  # Peatland data (if applicable)
  peatland_data = c(
    "Vegetation type",
    "Water table depth (cm)",
    "Peat depth (cm) - probe",
    "Core locations (3 per plot)",
    "Core samples (0-30, 30-100, 100-200, 200-300 cm)"
  )
)

# ==============================================================================
# STEP 1: CALCULATE SAMPLE SIZES
# ==============================================================================

cat("\n=== STEP 1: Finalizing Sample Sizes ===\n")

# Get recommended plots from stratification
sample_design <- stratum_stats %>%
  mutate(
    # Add oversampling
    plots_with_oversample = ceiling(recommended_plots * (1 + PLOT_DESIGN$oversample_pct)),

    # Calculate total
    total_recommended = recommended_plots,
    total_to_generate = plots_with_oversample
  ) %>%
  select(stratum, stratum_name, area_ha, total_recommended, total_to_generate)

print(sample_design)

cat("\nTotal plots (recommended):", sum(sample_design$total_recommended), "\n")
cat("Total plots (with oversample):", sum(sample_design$total_to_generate), "\n")

# ==============================================================================
# STEP 2: APPLY EDGE BUFFER
# ==============================================================================

cat("\n=== STEP 2: Applying Edge Buffer ===\n")

# Buffer study area inward to avoid edge plots
study_boundary_buffered <- st_buffer(study_boundary, -PLOT_DESIGN$edge_buffer_m)

# Mask stratification raster
strata_raster_buffered <- mask(strata_raster, vect(study_boundary_buffered))

cat("Applied", PLOT_DESIGN$edge_buffer_m, "m buffer from boundaries\n")

# ==============================================================================
# STEP 3: GENERATE PLOT LOCATIONS
# ==============================================================================

cat("\n=== STEP 3: Generating Plot Locations ===\n")

all_plots <- data.frame()

for (i in 1:nrow(sample_design)) {

  stratum_id <- sample_design$stratum[i]
  n_plots <- sample_design$total_to_generate[i]

  cat("\nStratum", stratum_id, "(", sample_design$stratum_name[i], "):",
      n_plots, "plots\n")

  # Extract stratum polygon
  stratum_poly <- strata_sf %>% filter(stratum == stratum_id)

  # Apply buffer
  stratum_poly_buffered <- st_intersection(
    stratum_poly,
    study_boundary_buffered
  )

  if (nrow(stratum_poly_buffered) == 0 || st_area(stratum_poly_buffered) < 1000) {
    cat("  WARNING: Stratum too small after buffering. Skipping.\n")
    next
  }

  # Convert to sp for spsample (legacy but reliable)
  stratum_sp <- as(stratum_poly_buffered, "Spatial")

  # Generate samples
  if (PLOT_DESIGN$method == "stratified_random") {

    # Simple random sampling within stratum
    set.seed(123 + stratum_id)  # Reproducible but different per stratum

    tryCatch({
      sample_points_sp <- spsample(
        stratum_sp,
        n = n_plots,
        type = "random"
      )

      # Convert to sf
      sample_points <- st_as_sf(sample_points_sp)
      st_crs(sample_points) <- st_crs(stratum_poly)

    }, error = function(e) {
      cat("  ERROR in sampling:", e$message, "\n")
      sample_points <- st_sf(geometry = st_sfc(crs = st_crs(stratum_poly)))
    })

  } else if (PLOT_DESIGN$method == "systematic") {

    # Regular grid
    sample_points_sp <- spsample(
      stratum_sp,
      n = n_plots,
      type = "regular"
    )
    sample_points <- st_as_sf(sample_points_sp)
    st_crs(sample_points) <- st_crs(stratum_poly)

  } else if (PLOT_DESIGN$method == "spatially_balanced") {

    # Local pivotal method (spatially balanced)
    # Ensures good spatial spread

    # Get candidate points
    candidate_sp <- spsample(stratum_sp, n = n_plots * 10, type = "regular")
    candidate_coords <- coordinates(candidate_sp)

    # Spatially balanced sample
    inclusion_probs <- rep(n_plots / nrow(candidate_coords), nrow(candidate_coords))

    set.seed(123 + stratum_id)
    selected_indices <- BalancedSampling::lpm1(inclusion_probs, candidate_coords)

    sample_points <- st_as_sf(
      data.frame(candidate_coords[selected_indices == 1, ]),
      coords = c("x1", "x2"),
      crs = st_crs(stratum_poly)
    )
  }

  # Add stratum information
  if (nrow(sample_points) > 0) {
    sample_points$stratum <- stratum_id
    sample_points$stratum_name <- sample_design$stratum_name[i]
    sample_points$plot_id <- paste0("S", stratum_id, "_P", 1:nrow(sample_points))
    sample_points$is_primary <- 1:nrow(sample_points) <= sample_design$total_recommended[i]

    all_plots <- rbind(all_plots, sample_points)

    cat("  Generated", nrow(sample_points), "plot locations\n")
  }
}

cat("\nTotal plots generated:", nrow(all_plots), "\n")
cat("Primary plots:", sum(all_plots$is_primary), "\n")
cat("Oversample plots:", sum(!all_plots$is_primary), "\n")

# ==============================================================================
# STEP 4: ENFORCE MINIMUM DISTANCE
# ==============================================================================

cat("\n=== STEP 4: Enforcing Minimum Distance Between Plots ===\n")

# Calculate distance matrix
coords <- st_coordinates(all_plots)
dist_matrix <- as.matrix(dist(coords))
diag(dist_matrix) <- Inf  # Ignore self-distance

# Find plots that are too close
too_close <- which(apply(dist_matrix, 1, min) < PLOT_DESIGN$min_distance_m)

if (length(too_close) > 0) {
  cat("Found", length(too_close), "plots <", PLOT_DESIGN$min_distance_m, "m apart\n")

  # Preferentially remove oversample plots
  to_remove <- intersect(too_close, which(!all_plots$is_primary))

  if (length(to_remove) > 0) {
    all_plots <- all_plots[-to_remove, ]
    cat("Removed", length(to_remove), "oversample plots to maintain spacing\n")
  } else {
    cat("WARNING: Some primary plots are too close. Review manually.\n")
  }
}

# Reindex plot IDs
all_plots <- all_plots %>%
  group_by(stratum) %>%
  mutate(plot_id = paste0("S", stratum, "_P", row_number())) %>%
  ungroup()

# ==============================================================================
# STEP 5: EXTRACT ENVIRONMENTAL DATA
# ==============================================================================

cat("\n=== STEP 5: Extracting Environmental Data for Plots ===\n")

# Load environmental layers if available
if (exists("env_stack")) {

  # Extract values at plot locations
  env_values <- terra::extract(
    env_stack,
    vect(all_plots),
    ID = FALSE
  )

  # Add to plots dataframe
  all_plots <- cbind(all_plots, env_values)

  cat("Extracted environmental covariates for", nrow(all_plots), "plots\n")
}

# ==============================================================================
# STEP 6: ADD GPS COORDINATES
# ==============================================================================

cat("\n=== STEP 6: Converting to GPS Coordinates ===\n")

# Transform to WGS84 (lat/lon) for GPS
all_plots_latlon <- st_transform(all_plots, crs = 4326)

# Extract coordinates
latlon_coords <- st_coordinates(all_plots_latlon)
all_plots$longitude <- latlon_coords[, 1]
all_plots$latitude <- latlon_coords[, 2]

# Extract projected coordinates
proj_coords <- st_coordinates(all_plots)
all_plots$easting <- proj_coords[, 1]
all_plots$northing <- proj_coords[, 2]

cat("Added GPS coordinates (WGS84) and projected coordinates\n")

# ==============================================================================
# STEP 7: CREATE FIELD DATA SHEETS
# ==============================================================================

cat("\n=== STEP 7: Creating Field Data Sheets ===\n")

# Prepare plot data sheet
plot_sheet <- all_plots %>%
  st_drop_geometry() %>%
  select(
    plot_id, stratum_name, is_primary,
    latitude, longitude, easting, northing,
    any_of(names(env_stack))
  ) %>%
  mutate(
    # Add empty columns for field data
    date_sampled = "",
    crew = "",
    slope_percent = "",
    aspect_deg = "",
    canopy_cover_pct = "",
    dominant_species = "",
    stand_age_class = "",
    notes = ""
  )

# Create tree data template
tree_sheet_template <- data.frame(
  plot_id = rep(all_plots$plot_id, each = 20),  # 20 rows per plot
  tree_number = rep(1:20, nrow(all_plots)),
  species = "",
  dbh_cm = "",
  height_m = "",
  crown_class = "",
  notes = ""
)

# Create Excel workbook
wb <- createWorkbook()

# Sheet 1: Plot locations
addWorksheet(wb, "Plot_Locations")
writeData(wb, "Plot_Locations", plot_sheet)

# Sheet 2: Tree data template
addWorksheet(wb, "Tree_Data_Template")
writeData(wb, "Tree_Data_Template", tree_sheet_template)

# Sheet 3: Instructions
instructions <- data.frame(
  Section = c("Plot Setup", "Tree Measurements", "Peatland", "Data Entry"),
  Instructions = c(
    paste("Navigate to plot center using GPS. Mark with stake. Establish",
          PLOT_DESIGN$plot_radius_m, "m radius plot."),
    paste("Measure all trees >=", FIELD_CONFIG$dbh_threshold_cm,
          "cm DBH. Record species, DBH, and crown class for all trees. Measure height for 5 representative trees per plot."),
    paste("For peatland plots: Probe peat depth at plot center. Collect soil cores at 3 locations (center, N, S) to",
          PLOT_DESIGN$peatland_plot_config$core_depth_cm, "cm or mineral soil."),
    "Enter data in Excel sheets. Keep original datasheets as backup. Submit within 48 hours."
  )
)

addWorksheet(wb, "Instructions")
writeData(wb, "Instructions", instructions)

# Save workbook
field_sheet_path <- file.path(DIRECTORIES$sampling_design, "field_data_sheets.xlsx")
saveWorkbook(wb, field_sheet_path, overwrite = TRUE)

cat("Field data sheets saved:", field_sheet_path, "\n")

# ==============================================================================
# STEP 8: VISUALIZATION
# ==============================================================================

cat("\n=== STEP 8: Creating Maps ===\n")

# Load stratification raster for background
strata_df <- as.data.frame(strata_raster, xy = TRUE, na.rm = TRUE)

# Plot 1: All plots on stratification map
plot1 <- ggplot() +
  geom_raster(data = strata_df, aes(x = x, y = y, fill = factor(stratum)), alpha = 0.5) +
  geom_sf(data = study_boundary, fill = NA, color = "black", size = 1) +
  geom_sf(data = all_plots[all_plots$is_primary, ], color = "red", size = 3, shape = 19) +
  geom_sf(data = all_plots[!all_plots$is_primary, ], color = "orange", size = 2, shape = 1) +
  scale_fill_brewer(palette = "Set1", name = "Stratum") +
  labs(
    title = "Plot Locations",
    subtitle = paste(sum(all_plots$is_primary), "primary plots +",
                    sum(!all_plots$is_primary), "oversample"),
    x = "Easting", y = "Northing"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

ggsave(
  file.path(DIRECTORIES$sampling_design, "plot_locations_map.png"),
  plot1, width = 14, height = 10, dpi = 300
)

# Plot 2: Individual maps per stratum (for field crews)
for (s in unique(all_plots$stratum)) {

  stratum_plots <- all_plots %>% filter(stratum == s)
  stratum_name <- unique(stratum_plots$stratum_name)

  # Subset stratification for this stratum
  stratum_bbox <- st_bbox(stratum_plots)
  stratum_bbox_buffered <- stratum_bbox + c(-500, -500, 500, 500)

  plot_stratum <- ggplot() +
    geom_raster(
      data = strata_df %>% filter(stratum == s),
      aes(x = x, y = y),
      fill = "#E8F5E9",
      alpha = 0.5
    ) +
    geom_sf(data = stratum_plots, aes(color = is_primary), size = 4) +
    geom_sf_text(data = stratum_plots, aes(label = plot_id),
                 nudge_y = 50, size = 3, fontface = "bold") +
    scale_color_manual(
      values = c("TRUE" = "red", "FALSE" = "orange"),
      labels = c("TRUE" = "Primary", "FALSE" = "Oversample"),
      name = "Plot Type"
    ) +
    coord_sf(xlim = stratum_bbox_buffered[c(1, 3)],
             ylim = stratum_bbox_buffered[c(2, 4)]) +
    labs(
      title = paste("Field Map -", stratum_name),
      subtitle = paste("Stratum", s, ":", nrow(stratum_plots), "plots"),
      x = "Easting", y = "Northing"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(DIRECTORIES$sampling_design, paste0("field_map_stratum_", s, ".png")),
    plot_stratum, width = 12, height = 10, dpi = 300
  )
}

cat("Maps created for", length(unique(all_plots$stratum)), "strata\n")

# ==============================================================================
# STEP 9: EXPORT FILES
# ==============================================================================

cat("\n=== STEP 9: Exporting Plot Data ===\n")

# Export as shapefile
st_write(
  all_plots,
  file.path(DIRECTORIES$sampling_design, "plot_locations.shp"),
  delete_dsn = TRUE,
  quiet = TRUE
)

# Export as CSV
all_plots_csv <- all_plots %>%
  st_drop_geometry() %>%
  select(
    plot_id, stratum, stratum_name, is_primary,
    latitude, longitude, easting, northing,
    everything()
  )

write.csv(
  all_plots_csv,
  file.path(DIRECTORIES$sampling_design, "plot_locations.csv"),
  row.names = FALSE
)

# Export as KML (for Google Earth)
st_write(
  all_plots,
  file.path(DIRECTORIES$sampling_design, "plot_locations.kml"),
  driver = "kml",
  delete_dsn = TRUE,
  quiet = TRUE
)

# Export as GPX (for handheld GPS)
# Simple conversion
all_plots_gpx <- all_plots_latlon %>%
  mutate(
    name = plot_id,
    desc = paste(stratum_name, if_else(is_primary, "PRIMARY", "OVERSAMPLE"))
  ) %>%
  select(name, desc)

st_write(
  all_plots_gpx,
  file.path(DIRECTORIES$sampling_design, "plot_locations.gpx"),
  driver = "GPX",
  delete_dsn = TRUE,
  quiet = TRUE
)

cat("Plot locations exported in multiple formats:\n")
cat("  - Shapefile (.shp)\n")
cat("  - CSV (.csv)\n")
cat("  - KML (.kml) - for Google Earth\n")
cat("  - GPX (.gpx) - for GPS devices\n")

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("PLOT DESIGN & OPTIMIZATION COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Summary:\n")
cat("  Total plots:", nrow(all_plots), "\n")
cat("  Primary plots:", sum(all_plots$is_primary), "\n")
cat("  Oversample plots:", sum(!all_plots$is_primary), "\n")
cat("  Plot radius:", PLOT_DESIGN$plot_radius_m, "m\n")
cat("  Plot area:", PLOT_DESIGN$plot_area_m2, "m²\n\n")

cat("Key Outputs:\n")
cat("  - Field data sheets:", field_sheet_path, "\n")
cat("  - Plot locations (shapefile):", file.path(DIRECTORIES$sampling_design, "plot_locations.shp"), "\n")
cat("  - Plot locations (CSV):", file.path(DIRECTORIES$sampling_design, "plot_locations.csv"), "\n")
cat("  - Plot locations (GPX for GPS):", file.path(DIRECTORIES$sampling_design, "plot_locations.gpx"), "\n")
cat("  - Field maps:", file.path(DIRECTORIES$sampling_design, "field_map_stratum_*.png"), "\n\n")

cat("READY FOR FIELD WORK!\n")
cat("Load GPX file to handheld GPS and use field data sheets for data collection.\n\n")
