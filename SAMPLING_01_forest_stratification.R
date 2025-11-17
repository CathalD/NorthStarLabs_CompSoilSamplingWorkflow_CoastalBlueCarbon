################################################################################
# SAMPLING DESIGN - PART 1: FOREST STRATIFICATION
################################################################################
# Purpose: Stratify forest area into homogeneous units for efficient sampling
# Input: Study area boundary, environmental layers (from GEE or local)
# Output: Stratification map, stratum definitions, recommended sample sizes
# Methods: Unsupervised classification, expert delineation, hybrid approach
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

source("forest_carbon_config.R")

required_packages <- c(
  "terra",
  "sf",
  "dplyr",
  "ggplot2",
  "viridis",
  "cluster",      # K-means clustering
  "factoextra",   # Cluster visualization
  "rasterVis",    # Raster visualization
  "RColorBrewer"
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

# Study Area
STUDY_AREA <- list(
  # Path to study area boundary (shapefile or drawn polygon)
  boundary_path = "data/study_area/boundary.shp",  # UPDATE THIS

  # OR: Define bounding box manually
  bbox = c(xmin = 500000, xmax = 520000, ymin = 5500000, ymax = 5520000),

  # Coordinate system
  crs = PROJECT$coordinate_system
)

# Environmental Layers for Stratification
# These can come from:
# 1. Google Earth Engine exports (run GEE script first)
# 2. Local raster files
# 3. National datasets (e.g., CanVec, NTDB)

ENV_LAYERS <- list(
  # Path to directory containing environmental rasters
  data_dir = "data/environmental_layers",

  # Expected layers (update paths as needed)
  layers = list(
    dem = "elevation.tif",
    canopy_height = "canopy_height_gedi.tif",
    ndvi = "ndvi_summer_median.tif",
    slope = "slope.tif",
    twi = "topographic_wetness_index.tif",
    forest_cover = "forest_cover_percent.tif"
  )
)

# Stratification Parameters
STRATIFICATION <- list(
  # Method: "kmeans", "manual", "hybrid"
  method = "kmeans",

  # Number of strata (for k-means)
  n_strata = 5,

  # Variables to use for clustering (subset of env layers)
  clustering_variables = c("canopy_height", "ndvi", "slope", "twi"),

  # Normalize variables before clustering?
  normalize = TRUE,

  # Minimum stratum size (ha)
  min_stratum_size_ha = 10,

  # Stratum names (optional - for manual or post-hoc labeling)
  stratum_names = c(
    "High Density Mature Forest",
    "Medium Density Mixed Forest",
    "Low Density Open Forest",
    "Peatland/Wetland",
    "Recently Harvested/Regenerating"
  )
)

# ==============================================================================
# STEP 1: LOAD OR CREATE STUDY AREA
# ==============================================================================

cat("\n=== STEP 1: Loading Study Area ===\n")

if (file.exists(STUDY_AREA$boundary_path)) {
  # Load from shapefile
  study_boundary <- st_read(STUDY_AREA$boundary_path, quiet = TRUE)
  study_boundary <- st_transform(study_boundary, STUDY_AREA$crs)

  cat("Loaded study area from:", STUDY_AREA$boundary_path, "\n")

} else {
  cat("Study area shapefile not found. Creating from bounding box...\n")

  # Create from bounding box
  bbox_poly <- st_as_sfc(st_bbox(STUDY_AREA$bbox, crs = st_crs(STUDY_AREA$crs)))
  study_boundary <- st_sf(id = 1, geometry = bbox_poly)

  cat("Created study area from bounding box\n")
}

# Calculate area
study_area_m2 <- as.numeric(st_area(study_boundary))
study_area_ha <- study_area_m2 / 10000

cat("Study area:", round(study_area_ha, 1), "ha\n")

# ==============================================================================
# STEP 2: LOAD ENVIRONMENTAL LAYERS
# ==============================================================================

cat("\n=== STEP 2: Loading Environmental Layers ===\n")

# Check if layers exist
available_layers <- list()
missing_layers <- character()

for (layer_name in names(ENV_LAYERS$layers)) {
  layer_path <- file.path(ENV_LAYERS$data_dir, ENV_LAYERS$layers[[layer_name]])

  if (file.exists(layer_path)) {
    available_layers[[layer_name]] <- rast(layer_path)
    cat("  ✓ Loaded:", layer_name, "\n")
  } else {
    missing_layers <- c(missing_layers, layer_name)
    cat("  ✗ Missing:", layer_name, "\n")
  }
}

# If no layers available, create synthetic example
if (length(available_layers) == 0) {
  cat("\nNo environmental layers found. Creating synthetic example...\n")

  # Create example rasters
  bbox_ext <- ext(st_bbox(study_boundary))
  template <- rast(
    extent = bbox_ext,
    resolution = 30,  # 30m resolution
    crs = STUDY_AREA$crs
  )

  set.seed(42)

  # Synthetic canopy height (0-40m)
  canopy_height <- template
  values(canopy_height) <- 5 + 25 * runif(ncell(template)) +
                           10 * sin(xFromCell(template, 1:ncell(template)) / 1000)
  names(canopy_height) <- "canopy_height"

  # Synthetic NDVI (0.3-0.9)
  ndvi <- template
  values(ndvi) <- 0.3 + 0.6 * runif(ncell(template))
  names(ndvi) <- "ndvi"

  # Synthetic slope (0-30 degrees)
  slope <- template
  values(slope) <- 30 * runif(ncell(template))^2
  names(slope) <- "slope"

  # Synthetic TWI (wetness index)
  twi <- template
  values(twi) <- 3 + 7 * runif(ncell(template))
  names(twi) <- "twi"

  available_layers <- list(
    canopy_height = canopy_height,
    ndvi = ndvi,
    slope = slope,
    twi = twi
  )

  cat("Created synthetic environmental layers for demonstration\n")
  cat("→ Replace with real data from Google Earth Engine exports\n")
}

# Stack layers
env_stack <- rast(available_layers)

# Crop and mask to study area
env_stack <- crop(env_stack, vect(study_boundary))
env_stack <- mask(env_stack, vect(study_boundary))

cat("\nEnvironmental stack created with", nlyr(env_stack), "layers\n")
cat("Resolution:", res(env_stack)[1], "m\n")
cat("Extent:", as.vector(ext(env_stack)), "\n")

# ==============================================================================
# STEP 3: PREPARE DATA FOR CLUSTERING
# ==============================================================================

cat("\n=== STEP 3: Preparing Data for Stratification ===\n")

# Select variables for clustering
clustering_vars <- STRATIFICATION$clustering_variables

# Check which variables are available
available_vars <- clustering_vars[clustering_vars %in% names(env_stack)]
missing_vars <- clustering_vars[!clustering_vars %in% names(env_stack)]

if (length(missing_vars) > 0) {
  cat("WARNING: Missing clustering variables:", paste(missing_vars, collapse = ", "), "\n")
  cat("Using available variables:", paste(available_vars, collapse = ", "), "\n")
  clustering_vars <- available_vars
}

# Subset stack
cluster_stack <- env_stack[[clustering_vars]]

# Convert to data frame (remove NAs)
cluster_df <- as.data.frame(cluster_stack, xy = TRUE, na.rm = TRUE)

cat("Prepared", nrow(cluster_df), "pixels for clustering\n")
cat("Variables:", paste(clustering_vars, collapse = ", "), "\n")

# Normalize if requested
if (STRATIFICATION$normalize) {
  cat("Normalizing variables...\n")

  for (var in clustering_vars) {
    cluster_df[[paste0(var, "_scaled")]] <- scale(cluster_df[[var]])
  }

  clustering_data <- cluster_df[, paste0(clustering_vars, "_scaled")]
} else {
  clustering_data <- cluster_df[, clustering_vars]
}

# ==============================================================================
# STEP 4: K-MEANS CLUSTERING
# ==============================================================================

if (STRATIFICATION$method == "kmeans") {

  cat("\n=== STEP 4: K-Means Clustering ===\n")

  # Determine optimal number of clusters (if not specified)
  if (is.null(STRATIFICATION$n_strata)) {
    cat("Determining optimal number of clusters...\n")

    # Elbow method
    set.seed(123)
    wss <- sapply(2:10, function(k) {
      kmeans(clustering_data, centers = k, nstart = 25)$tot.withinss
    })

    # Plot elbow
    elbow_plot <- ggplot(data.frame(k = 2:10, wss = wss), aes(x = k, y = wss)) +
      geom_line() +
      geom_point(size = 3) +
      labs(title = "Elbow Method for Optimal K",
           x = "Number of Clusters",
           y = "Total Within-Cluster Sum of Squares") +
      theme_minimal()

    ggsave(
      file.path(DIRECTORIES$sampling_design, "elbow_plot.png"),
      elbow_plot, width = 8, height = 6
    )

    cat("Elbow plot saved. Review and set STRATIFICATION$n_strata manually.\n")
    STRATIFICATION$n_strata <- 5  # Default
  }

  # Run k-means
  cat("Running k-means with", STRATIFICATION$n_strata, "clusters...\n")
  set.seed(123)

  kmeans_result <- kmeans(
    clustering_data,
    centers = STRATIFICATION$n_strata,
    nstart = 25,
    iter.max = 100
  )

  # Add cluster assignments
  cluster_df$stratum <- kmeans_result$cluster

  cat("Clustering complete!\n")
  cat("Between-cluster variance:", round(kmeans_result$betweenss / kmeans_result$totss * 100, 1), "%\n")

} else if (STRATIFICATION$method == "manual") {

  cat("\n=== STEP 4: Manual Stratification ===\n")
  cat("Manual stratification requires user-defined rules.\n")
  cat("Example: stratify by canopy height thresholds\n")

  # Example manual stratification
  if ("canopy_height" %in% names(cluster_df)) {
    cluster_df$stratum <- cut(
      cluster_df$canopy_height,
      breaks = c(0, 5, 10, 20, 30, 100),
      labels = 1:5,
      include.lowest = TRUE
    )
    cluster_df$stratum <- as.numeric(cluster_df$stratum)
  }
}

# ==============================================================================
# STEP 5: CREATE STRATIFICATION RASTER
# ==============================================================================

cat("\n=== STEP 5: Creating Stratification Map ===\n")

# Create raster template
strata_raster <- rast(cluster_stack[[1]])
values(strata_raster) <- NA

# Assign cluster values
cell_coords <- cellFromXY(strata_raster, cluster_df[, c("x", "y")])
values(strata_raster)[cell_coords] <- cluster_df$stratum

names(strata_raster) <- "stratum"

# Save raster
dir.create(DIRECTORIES$sampling_design, recursive = TRUE, showWarnings = FALSE)
writeRaster(
  strata_raster,
  file.path(DIRECTORIES$sampling_design, "stratification_map.tif"),
  overwrite = TRUE
)

cat("Stratification map saved\n")

# ==============================================================================
# STEP 6: CALCULATE STRATUM STATISTICS
# ==============================================================================

cat("\n=== STEP 6: Calculating Stratum Statistics ===\n")

# Calculate area per stratum
pixel_area_m2 <- res(strata_raster)[1] * res(strata_raster)[2]

stratum_stats <- cluster_df %>%
  group_by(stratum) %>%
  summarise(
    n_pixels = n(),
    area_ha = n() * pixel_area_m2 / 10000,
    proportion = n() / nrow(cluster_df),

    # Mean environmental variables
    mean_canopy_height = if ("canopy_height" %in% names(.)) mean(canopy_height, na.rm = TRUE) else NA,
    mean_ndvi = if ("ndvi" %in% names(.)) mean(ndvi, na.rm = TRUE) else NA,
    mean_slope = if ("slope" %in% names(.)) mean(slope, na.rm = TRUE) else NA,
    mean_twi = if ("twi" %in% names(.)) mean(twi, na.rm = TRUE) else NA,

    # Standard deviations (for sample size calculation)
    sd_canopy_height = if ("canopy_height" %in% names(.)) sd(canopy_height, na.rm = TRUE) else NA
  ) %>%
  mutate(
    stratum_name = if (length(STRATIFICATION$stratum_names) >= n()) {
      STRATIFICATION$stratum_names[stratum]
    } else {
      paste("Stratum", stratum)
    }
  ) %>%
  arrange(desc(area_ha))

print(stratum_stats)

# Filter small strata
small_strata <- stratum_stats %>%
  filter(area_ha < STRATIFICATION$min_stratum_size_ha)

if (nrow(small_strata) > 0) {
  cat("\nWARNING:", nrow(small_strata), "strata are smaller than minimum size (",
      STRATIFICATION$min_stratum_size_ha, "ha)\n")
  cat("Consider reducing number of strata or merging small strata.\n")
}

# ==============================================================================
# STEP 7: RECOMMEND SAMPLE SIZES
# ==============================================================================

cat("\n=== STEP 7: Calculating Recommended Sample Sizes ===\n")

# Use Neyman allocation for stratified sampling
# n_h = n * (N_h * S_h) / sum(N_h * S_h)
# where n_h = sample size in stratum h
#       N_h = total area of stratum h
#       S_h = standard deviation in stratum h

# Calculate total sample size needed for target precision
# n = (sum(N_h * S_h))^2 / (N^2 * D + sum(N_h * S_h^2))
# where D = (target_error^2) / (z^2)

target_precision <- SAMPLING_DESIGN$target_precision  # ±10%
z_score <- qnorm(1 - (1 - SAMPLING_DESIGN$confidence_level) / 2)  # 1.96 for 95%

# Use canopy height SD as proxy for carbon variability
# (or use expected CV from config)

stratum_stats <- stratum_stats %>%
  mutate(
    # If SD not available, use CV from config
    sd_proxy = ifelse(
      is.na(sd_canopy_height),
      mean_canopy_height * SAMPLING_DESIGN$expected_CV,
      sd_canopy_height
    ),

    # Neyman allocation
    neyman_weight = area_ha * sd_proxy
  )

# Total sample size (simplified Cochran formula)
total_variance <- sum(stratum_stats$neyman_weight)
n_total <- ceiling((total_variance / study_area_ha)^2 / (target_precision^2))

# Ensure minimum plots per stratum
n_total <- max(n_total, STRATIFICATION$n_strata * SAMPLING_DESIGN$stratification$minimum_plots_per_stratum)

cat("\nTarget precision:", target_precision * 100, "%\n")
cat("Confidence level:", SAMPLING_DESIGN$confidence_level * 100, "%\n")
cat("Recommended total sample size:", n_total, "plots\n\n")

# Allocate to strata
stratum_stats <- stratum_stats %>%
  mutate(
    recommended_plots = pmax(
      ceiling(n_total * neyman_weight / sum(neyman_weight)),
      SAMPLING_DESIGN$stratification$minimum_plots_per_stratum
    )
  )

cat("Recommended plots per stratum:\n")
print(stratum_stats[, c("stratum", "stratum_name", "area_ha", "recommended_plots")])

# ==============================================================================
# STEP 8: VISUALIZATION
# ==============================================================================

cat("\n=== STEP 8: Creating Visualizations ===\n")

# Plot 1: Stratification map
strata_df <- as.data.frame(strata_raster, xy = TRUE, na.rm = TRUE)

strata_colors <- RColorBrewer::brewer.pal(
  min(STRATIFICATION$n_strata, 9),
  "Set1"
)

plot1 <- ggplot() +
  geom_raster(data = strata_df, aes(x = x, y = y, fill = factor(stratum))) +
  geom_sf(data = study_boundary, fill = NA, color = "black", size = 1) +
  scale_fill_manual(
    values = strata_colors,
    name = "Stratum",
    labels = STRATIFICATION$stratum_names[1:STRATIFICATION$n_strata]
  ) +
  coord_sf() +
  labs(
    title = "Forest Stratification Map",
    subtitle = paste(STRATIFICATION$n_strata, "strata based on environmental variables"),
    x = "Easting", y = "Northing"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

ggsave(
  file.path(DIRECTORIES$sampling_design, "stratification_map.png"),
  plot1, width = 12, height = 10, dpi = 300
)

# Plot 2: Stratum areas
plot2 <- ggplot(stratum_stats, aes(x = reorder(stratum_name, -area_ha), y = area_ha, fill = factor(stratum))) +
  geom_bar(stat = "identity", color = "black") +
  scale_fill_manual(values = strata_colors) +
  labs(
    title = "Stratum Areas",
    x = "", y = "Area (ha)"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none"
  )

ggsave(
  file.path(DIRECTORIES$sampling_design, "stratum_areas.png"),
  plot2, width = 10, height = 6, dpi = 300
)

# Plot 3: Sample allocation
plot3 <- ggplot(stratum_stats, aes(x = reorder(stratum_name, -recommended_plots),
                                    y = recommended_plots, fill = factor(stratum))) +
  geom_bar(stat = "identity", color = "black") +
  geom_text(aes(label = recommended_plots), vjust = -0.5) +
  scale_fill_manual(values = strata_colors) +
  labs(
    title = "Recommended Sample Allocation",
    subtitle = paste("Total:", sum(stratum_stats$recommended_plots), "plots"),
    x = "", y = "Number of Plots"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none"
  )

ggsave(
  file.path(DIRECTORIES$sampling_design, "sample_allocation.png"),
  plot3, width = 10, height = 6, dpi = 300
)

cat("Visualizations saved!\n")

# ==============================================================================
# STEP 9: EXPORT RESULTS
# ==============================================================================

cat("\n=== STEP 9: Exporting Results ===\n")

# Save stratum statistics
write.csv(
  stratum_stats,
  file.path(DIRECTORIES$sampling_design, "stratum_statistics.csv"),
  row.names = FALSE
)

# Save stratification as shapefile (polygonize)
strata_polygons <- as.polygons(strata_raster)
strata_sf <- st_as_sf(strata_polygons)

# Join with statistics
strata_sf <- strata_sf %>%
  left_join(
    stratum_stats %>% select(stratum, stratum_name, area_ha, recommended_plots),
    by = "stratum"
  )

st_write(
  strata_sf,
  file.path(DIRECTORIES$sampling_design, "strata_polygons.shp"),
  delete_dsn = TRUE,
  quiet = TRUE
)

cat("Stratification results saved!\n")

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("FOREST STRATIFICATION COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Summary:\n")
cat("  Study area:", round(study_area_ha, 1), "ha\n")
cat("  Number of strata:", STRATIFICATION$n_strata, "\n")
cat("  Recommended total plots:", sum(stratum_stats$recommended_plots), "\n")
cat("  Stratification method:", STRATIFICATION$method, "\n\n")

cat("Outputs:\n")
cat("  - Stratification map:", file.path(DIRECTORIES$sampling_design, "stratification_map.tif"), "\n")
cat("  - Stratum polygons:", file.path(DIRECTORIES$sampling_design, "strata_polygons.shp"), "\n")
cat("  - Statistics:", file.path(DIRECTORIES$sampling_design, "stratum_statistics.csv"), "\n\n")

cat("Next Step: Run SAMPLING_02_plot_design_optimization.R\n\n")

# Save workspace
save(
  strata_raster,
  stratum_stats,
  strata_sf,
  study_boundary,
  file = file.path(DIRECTORIES$sampling, "stratification_workspace.RData")
)
