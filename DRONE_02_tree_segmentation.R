################################################################################
# DRONE WORKFLOW - PART 2: TREE SEGMENTATION & MEASUREMENT
################################################################################
# Purpose: Detect individual trees, delineate crowns, measure attributes
# Input: CHM from DRONE_01, normalized point cloud
# Output: Individual tree locations, crown polygons, height/diameter measurements
# Methods: Watershed segmentation, local maxima detection
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

source("forest_carbon_config.R")

# Required packages
required_packages <- c(
  "lidR",
  "ForestTools",  # Tree detection and crown delineation
  "terra",
  "sf",
  "dplyr",
  "ggplot2",
  "viridis",
  "raster"  # ForestTools dependency
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

# Load outputs from previous step
workspace_file <- file.path(DIRECTORIES$drone, "preprocessing_workspace.RData")

if (file.exists(workspace_file)) {
  load(workspace_file)
  cat("Loaded CHM from preprocessing step\n")
} else {
  # Try to load CHM directly
  chm_path <- file.path(DIRECTORIES$drone_chm, "chm_smoothed.tif")
  if (!file.exists(chm_path)) {
    chm_path <- file.path(DIRECTORIES$drone_chm, "chm_smoothed_EXAMPLE.tif")
  }

  if (file.exists(chm_path)) {
    chm_smooth <- rast(chm_path)
    cat("Loaded CHM from:", chm_path, "\n")
  } else {
    stop("ERROR: No CHM found. Run DRONE_01_preprocessing_pointcloud.R first!")
  }
}

# Tree Detection Parameters
TREE_DETECTION <- list(

  # Local maxima detection
  window_function = "variable",  # "fixed" or "variable"

  # For variable window (adapts to tree height)
  # Formula: window_radius = a + b * height
  # Taller trees = wider search window
  variable_window = list(
    a = 2.5,    # Minimum window radius (m)
    b = 0.08    # Increase per meter of height
  ),

  # For fixed window
  fixed_window_size = 5,  # meters

  # Tree height thresholds
  min_height_m = 2.0,     # Minimum to be considered a tree
  max_height_m = 65,      # Maximum plausible height

  # Crown delineation
  crown_method = "watershed",  # "watershed" or "dalponte2016"

  # Watershed parameters
  watershed = list(
    tolerance = 0.1,      # Minimum height difference for peaks
    ext = 1               # Extension factor
  ),

  # Dalponte2016 (alternative - uses point cloud)
  dalponte = list(
    th_tree = 2.0,        # Minimum tree height
    th_seed = 0.45,       # Seeding threshold
    th_cr = 0.55,         # Crown threshold
    max_cr = 10           # Maximum crown diameter
  ),

  # Post-processing filters
  min_crown_area_m2 = 2,   # Minimum crown area
  max_crown_area_m2 = 500  # Maximum crown area
)

# ==============================================================================
# STEP 1: VARIABLE WINDOW FUNCTION
# ==============================================================================

cat("\n=== STEP 1: Setting Up Tree Detection ===\n")

# Create variable window function
# This adapts the search window size based on tree height
# Taller trees have wider crowns, so need bigger windows

lin_window <- function(height) {
  # Returns window radius in meters
  radius <- TREE_DETECTION$variable_window$a +
            TREE_DETECTION$variable_window$b * height

  # Ensure minimum radius
  radius[radius < 1] <- 1

  return(radius)
}

# Visualize window function
height_seq <- seq(2, 40, by = 1)
window_seq <- sapply(height_seq, lin_window)

window_plot <- ggplot(data.frame(height = height_seq, window = window_seq),
                      aes(x = height, y = window)) +
  geom_line(color = "#2E7D32", size = 1.2) +
  geom_point(color = "#1B5E20", size = 2) +
  labs(
    title = "Variable Window Size for Tree Detection",
    subtitle = paste("Formula: radius =", TREE_DETECTION$variable_window$a,
                    "+", TREE_DETECTION$variable_window$b, "× height"),
    x = "Tree Height (m)",
    y = "Search Window Radius (m)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(face = "bold"))

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/window_function.png"),
  window_plot,
  width = 8, height = 6, dpi = 300
)

cat("Window function: radius =", TREE_DETECTION$variable_window$a, "+",
    TREE_DETECTION$variable_window$b, "× height\n")

# ==============================================================================
# STEP 2: DETECT TREE TOPS (LOCAL MAXIMA)
# ==============================================================================

cat("\n=== STEP 2: Detecting Tree Tops ===\n")

# Convert terra to raster for ForestTools compatibility
chm_raster <- raster(chm_smooth)

# Detect local maxima (tree tops)
cat("Running local maxima detection...\n")

if (TREE_DETECTION$window_function == "variable") {
  treetops <- ForestTools::vwf(
    CHM = chm_raster,
    winFun = lin_window,
    minHeight = TREE_DETECTION$min_height_m
  )
} else {
  # Fixed window
  treetops <- ForestTools::vwf(
    CHM = chm_raster,
    winFun = function(x) TREE_DETECTION$fixed_window_size,
    minHeight = TREE_DETECTION$min_height_m
  )
}

# Convert to sf object
treetops_sf <- st_as_sf(treetops)

# Filter by height
treetops_sf <- treetops_sf %>%
  filter(
    height >= TREE_DETECTION$min_height_m,
    height <= TREE_DETECTION$max_height_m
  )

cat("Detected", nrow(treetops_sf), "tree tops\n")
cat("Height range:", round(min(treetops_sf$height), 1), "-",
    round(max(treetops_sf$height), 1), "m\n")

# Statistics
cat("\nTree Height Statistics:\n")
cat("Mean:", round(mean(treetops_sf$height), 2), "m\n")
cat("Median:", round(median(treetops_sf$height), 2), "m\n")
cat("Std Dev:", round(sd(treetops_sf$height), 2), "m\n")

# ==============================================================================
# STEP 3: DELINEATE TREE CROWNS
# ==============================================================================

cat("\n=== STEP 3: Delineating Tree Crowns ===\n")

if (TREE_DETECTION$crown_method == "watershed") {

  cat("Using watershed segmentation...\n")

  # Watershed segmentation
  crowns <- ForestTools::mcws(
    treetops = treetops,
    CHM = chm_raster,
    minHeight = TREE_DETECTION$min_height_m,
    format = "polygons"
  )

} else {
  # Dalponte 2016 method (requires point cloud)
  cat("Using Dalponte 2016 method (requires point cloud)...\n")

  # Check if normalized point cloud exists
  las_path <- file.path(DIRECTORIES$drone, "pointcloud_normalized.laz")

  if (file.exists(las_path)) {
    las <- readLAS(las_path)

    crowns <- lidR::dalponte2016(
      las,
      chm_raster,
      treetops
    )()

    # Convert to polygons
    crowns <- st_as_sf(stars::st_as_stars(crowns), merge = TRUE)

  } else {
    cat("WARNING: Point cloud not found. Falling back to watershed.\n")

    crowns <- ForestTools::mcws(
      treetops = treetops,
      CHM = chm_raster,
      minHeight = TREE_DETECTION$min_height_m,
      format = "polygons"
    )
  }
}

# Convert to sf
crowns_sf <- st_as_sf(crowns)

cat("Delineated", nrow(crowns_sf), "tree crowns\n")

# ==============================================================================
# STEP 4: CALCULATE CROWN METRICS
# ==============================================================================

cat("\n=== STEP 4: Calculating Crown Metrics ===\n")

# Calculate crown area
crowns_sf$crown_area_m2 <- as.numeric(st_area(crowns_sf))

# Calculate crown diameter (assume circular)
crowns_sf$crown_diameter_m <- 2 * sqrt(crowns_sf$crown_area_m2 / pi)

# Filter by crown area
cat("Filtering crowns by area...\n")
n_before <- nrow(crowns_sf)

crowns_sf <- crowns_sf %>%
  filter(
    crown_area_m2 >= TREE_DETECTION$min_crown_area_m2,
    crown_area_m2 <= TREE_DETECTION$max_crown_area_m2
  )

n_after <- nrow(crowns_sf)
cat("Removed", n_before - n_after, "crowns with invalid areas\n")
cat("Final tree count:", n_after, "\n")

# Add unique tree ID
crowns_sf$tree_id <- 1:nrow(crowns_sf)

# Extract height from treetops and join
crowns_sf <- crowns_sf %>%
  mutate(
    x = st_coordinates(st_centroid(geometry))[,1],
    y = st_coordinates(st_centroid(geometry))[,2]
  )

# Get height from CHM at crown center
crown_heights <- terra::extract(
  chm_smooth,
  vect(st_centroid(crowns_sf)),
  ID = FALSE
)

crowns_sf$height_m <- crown_heights[,1]

# Summary statistics
cat("\nCrown Metrics Summary:\n")
cat("Mean crown area:", round(mean(crowns_sf$crown_area_m2), 1), "m²\n")
cat("Mean crown diameter:", round(mean(crowns_sf$crown_diameter_m), 2), "m\n")
cat("Mean tree height:", round(mean(crowns_sf$height_m, na.rm = TRUE), 2), "m\n")

# ==============================================================================
# STEP 5: QUALITY CONTROL
# ==============================================================================

cat("\n=== STEP 5: Quality Control ===\n")

# Check for spatial duplicates
duplicate_threshold <- 2  # meters
coords <- st_coordinates(st_centroid(crowns_sf))
dist_matrix <- as.matrix(dist(coords))
diag(dist_matrix) <- NA

duplicates <- which(apply(dist_matrix, 1, function(x) any(x < duplicate_threshold, na.rm = TRUE)))

if (length(duplicates) > 0) {
  cat("WARNING: Found", length(duplicates), "potential duplicate trees (<2m apart)\n")
  cat("Consider adjusting window function or minimum height.\n")
}

# Flag outliers
crowns_sf$qc_flag <- ""

# Height outliers (> 3 SD from mean)
height_mean <- mean(crowns_sf$height_m, na.rm = TRUE)
height_sd <- sd(crowns_sf$height_m, na.rm = TRUE)
crowns_sf$qc_flag[crowns_sf$height_m > height_mean + 3 * height_sd] <-
  paste0(crowns_sf$qc_flag[crowns_sf$height_m > height_mean + 3 * height_sd], "HEIGHT_OUTLIER;")

# Crown area outliers
area_mean <- mean(crowns_sf$crown_area_m2)
area_sd <- sd(crowns_sf$crown_area_m2)
crowns_sf$qc_flag[crowns_sf$crown_area_m2 > area_mean + 3 * area_sd] <-
  paste0(crowns_sf$qc_flag[crowns_sf$crown_area_m2 > area_mean + 3 * area_sd], "AREA_OUTLIER;")

# Missing height
crowns_sf$qc_flag[is.na(crowns_sf$height_m)] <- paste0(crowns_sf$qc_flag[is.na(crowns_sf$height_m)], "NO_HEIGHT;")

flagged <- sum(crowns_sf$qc_flag != "")
cat("Flagged", flagged, "trees for QC review\n")

# ==============================================================================
# STEP 6: CALCULATE TREE DENSITY
# ==============================================================================

cat("\n=== STEP 6: Calculating Stand Metrics ===\n")

# Get study area
study_area_m2 <- as.numeric(st_area(st_as_sfc(st_bbox(crowns_sf))))
study_area_ha <- study_area_m2 / 10000

# Tree density
tree_density_ha <- nrow(crowns_sf) / study_area_ha

# Canopy cover (% of area covered by crowns)
total_crown_area <- sum(crowns_sf$crown_area_m2)
canopy_cover_pct <- 100 * total_crown_area / study_area_m2

# Basal area approximation (using crown diameter as proxy)
# BA ≈ 0.4 * crown_area (rough approximation for closed canopy)
crowns_sf$basal_area_m2 <- crowns_sf$crown_area_m2 * 0.4
total_BA_ha <- sum(crowns_sf$basal_area_m2) / study_area_ha

cat("\nStand-Level Metrics:\n")
cat("Study area:", round(study_area_ha, 2), "ha\n")
cat("Tree density:", round(tree_density_ha, 0), "trees/ha\n")
cat("Canopy cover:", round(canopy_cover_pct, 1), "%\n")
cat("Estimated basal area:", round(total_BA_ha, 1), "m²/ha\n")

# ==============================================================================
# STEP 7: VISUALIZATION
# ==============================================================================

cat("\n=== STEP 7: Creating Visualizations ===\n")

# Plot 1: CHM with tree tops
chm_df <- as.data.frame(chm_smooth, xy = TRUE)
names(chm_df)[3] <- "height"

treetops_coords <- st_coordinates(treetops_sf)

plot1 <- ggplot() +
  geom_raster(data = chm_df, aes(x = x, y = y, fill = height)) +
  scale_fill_gradientn(
    colors = COLOR_SCHEMES$forest_height,
    name = "Height (m)",
    na.value = "transparent"
  ) +
  geom_point(
    data = data.frame(x = treetops_coords[,1], y = treetops_coords[,2]),
    aes(x = x, y = y),
    color = "red", size = 0.5, alpha = 0.6
  ) +
  coord_equal() +
  labs(
    title = "Detected Tree Tops",
    subtitle = paste(nrow(treetops_sf), "trees detected"),
    x = "Easting (m)", y = "Northing (m)"
  ) +
  theme_minimal()

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/tree_tops.png"),
  plot1, width = 12, height = 10, dpi = 300
)

# Plot 2: Crown delineation
plot2 <- ggplot() +
  geom_raster(data = chm_df, aes(x = x, y = y, fill = height), alpha = 0.6) +
  scale_fill_gradientn(
    colors = COLOR_SCHEMES$forest_height,
    name = "Height (m)",
    na.value = "transparent"
  ) +
  geom_sf(data = crowns_sf, fill = NA, color = "red", size = 0.3, alpha = 0.8) +
  coord_sf() +
  labs(
    title = "Delineated Tree Crowns",
    subtitle = paste(nrow(crowns_sf), "crowns"),
    x = "Easting (m)", y = "Northing (m)"
  ) +
  theme_minimal()

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/tree_crowns.png"),
  plot2, width = 12, height = 10, dpi = 300
)

# Plot 3: Height distribution by crown size
plot3 <- ggplot(crowns_sf, aes(x = crown_diameter_m, y = height_m)) +
  geom_point(alpha = 0.5, color = "#2E7D32") +
  geom_smooth(method = "lm", color = "#1B5E20", se = TRUE) +
  labs(
    title = "Tree Height vs. Crown Diameter",
    x = "Crown Diameter (m)",
    y = "Height (m)"
  ) +
  theme_minimal()

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/height_diameter_relationship.png"),
  plot3, width = 8, height = 6, dpi = 300
)

cat("Visualizations saved!\n")

# ==============================================================================
# STEP 8: EXPORT RESULTS
# ==============================================================================

cat("\n=== STEP 8: Exporting Results ===\n")

# Prepare final dataset
trees_final <- crowns_sf %>%
  st_drop_geometry() %>%
  select(
    tree_id,
    x, y,
    height_m,
    crown_area_m2,
    crown_diameter_m,
    basal_area_m2,
    qc_flag
  ) %>%
  as.data.frame()

# Save CSV
csv_path <- file.path(DIRECTORIES$drone_trees, "individual_trees.csv")
write.csv(trees_final, csv_path, row.names = FALSE)
cat("Tree attributes saved:", csv_path, "\n")

# Save shapefiles
crowns_export <- crowns_sf %>%
  select(tree_id, height_m, crown_area_m2, crown_diameter_m, qc_flag)

st_write(
  crowns_export,
  file.path(DIRECTORIES$drone_trees, "tree_crowns.shp"),
  delete_dsn = TRUE,
  quiet = TRUE
)

treetops_export <- treetops_sf %>%
  mutate(tree_id = 1:n()) %>%
  select(tree_id, height)

st_write(
  treetops_export,
  file.path(DIRECTORIES$drone_trees, "tree_tops.shp"),
  delete_dsn = TRUE,
  quiet = TRUE
)

cat("Shapefiles saved to:", DIRECTORIES$drone_trees, "\n")

# Save stand summary
stand_summary <- data.frame(
  metric = c(
    "Study Area (ha)",
    "Total Trees",
    "Tree Density (trees/ha)",
    "Mean Height (m)",
    "Mean Crown Diameter (m)",
    "Canopy Cover (%)",
    "Estimated Basal Area (m²/ha)",
    "Trees Flagged for QC"
  ),
  value = c(
    round(study_area_ha, 2),
    nrow(crowns_sf),
    round(tree_density_ha, 0),
    round(mean(crowns_sf$height_m, na.rm = TRUE), 2),
    round(mean(crowns_sf$crown_diameter_m), 2),
    round(canopy_cover_pct, 1),
    round(total_BA_ha, 1),
    flagged
  )
)

write.csv(
  stand_summary,
  file.path(DIRECTORIES$drone, "diagnostics/stand_summary.csv"),
  row.names = FALSE
)

print(stand_summary)

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("TREE SEGMENTATION COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Outputs:\n")
cat("  - Tree attributes (CSV):", csv_path, "\n")
cat("  - Tree crowns (shapefile):", file.path(DIRECTORIES$drone_trees, "tree_crowns.shp"), "\n")
cat("  - Tree tops (shapefile):", file.path(DIRECTORIES$drone_trees, "tree_tops.shp"), "\n")
cat("  - Stand summary:", file.path(DIRECTORIES$drone, "diagnostics/stand_summary.csv"), "\n\n")

cat("Next Step: Run DRONE_03_biomass_calculation.R\n\n")

# Save workspace
save(
  trees_final,
  crowns_sf,
  stand_summary,
  file = file.path(DIRECTORIES$drone, "segmentation_workspace.RData")
)
