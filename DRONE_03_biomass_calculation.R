################################################################################
# DRONE WORKFLOW - PART 3: BIOMASS & CARBON CALCULATION
################################################################################
# Purpose: Calculate tree-level and stand-level biomass and carbon stocks
# Input: Individual tree measurements from DRONE_02
# Output: Biomass maps, carbon stock estimates, uncertainty quantification
# Methods: Allometric equations, height-diameter relationships
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

source("forest_carbon_config.R")

required_packages <- c("terra", "sf", "dplyr", "ggplot2", "viridis", "tidyr")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# ==============================================================================
# LOAD DATA
# ==============================================================================

cat("\n=== Loading Tree Data ===\n")

# Load from previous step
workspace_file <- file.path(DIRECTORIES$drone, "segmentation_workspace.RData")

if (file.exists(workspace_file)) {
  load(workspace_file)
  cat("Loaded", nrow(trees_final), "trees from segmentation\n")
} else {
  # Try loading CSV directly
  csv_path <- file.path(DIRECTORIES$drone_trees, "individual_trees.csv")
  if (file.exists(csv_path)) {
    trees_final <- read.csv(csv_path)
    cat("Loaded", nrow(trees_final), "trees from CSV\n")
  } else {
    stop("ERROR: No tree data found. Run DRONE_02 first!")
  }
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Species Assignment (user needs to specify or use classification)
SPECIES_ASSIGNMENT <- list(
  # Default species for entire stand
  default_species = "Picea_glauca",  # White spruce

  # OR: Assign by spatial zones (not implemented - would need species classification)
  # zones = list(
  #   zone1 = list(bounds = c(xmin, xmax, ymin, ymax), species = "Picea_mariana"),
  #   zone2 = list(bounds = c(...), species = "Pinus_contorta")
  # )

  # Ecosystem type for root:shoot ratio
  ecosystem_type = "boreal_conifer"
)

# Biomass Calculation Method
BIOMASS_METHOD <- list(
  # Primary method: Height-based allometric equations
  use_height_allometry = TRUE,

  # If DBH measurements available (from field calibration)
  use_dbh_allometry = FALSE,
  height_dbh_model = "power",  # "power" or "linear"

  # Height-DBH relationship parameters (from regional data or calibration)
  # DBH = a * Height^b  (power model)
  # OR DBH = a + b * Height (linear model)
  height_dbh_coefficients = list(
    a = 2.5,   # Boreal conifer typical
    b = 0.65   # Exponent (power) or slope (linear)
  ),

  # Uncertainty estimation
  calculate_uncertainty = TRUE,
  bootstrap_iterations = 100  # For uncertainty propagation
)

# ==============================================================================
# STEP 1: ASSIGN SPECIES
# ==============================================================================

cat("\n=== STEP 1: Species Assignment ===\n")

# Simple approach: assign default species to all trees
trees_final$species <- SPECIES_ASSIGNMENT$default_species

cat("Assigned species:", SPECIES_ASSIGNMENT$default_species, "to all trees\n")
cat("(Note: For mixed stands, use multispectral classification or field validation)\n")

# ==============================================================================
# STEP 2: ESTIMATE DBH FROM HEIGHT
# ==============================================================================

cat("\n=== STEP 2: Estimating DBH from Height ===\n")

if (BIOMASS_METHOD$use_height_allometry) {

  cat("Using height-DBH relationship...\n")

  if (BIOMASS_METHOD$height_dbh_model == "power") {
    # Power model: DBH = a * H^b
    trees_final$DBH_cm <- BIOMASS_METHOD$height_dbh_coefficients$a *
                          (trees_final$height_m ^ BIOMASS_METHOD$height_dbh_coefficients$b)

    cat("Model: DBH =", BIOMASS_METHOD$height_dbh_coefficients$a,
        "× Height^", BIOMASS_METHOD$height_dbh_coefficients$b, "\n")

  } else {
    # Linear model: DBH = a + b * H
    trees_final$DBH_cm <- BIOMASS_METHOD$height_dbh_coefficients$a +
                          BIOMASS_METHOD$height_dbh_coefficients$b * trees_final$height_m

    cat("Model: DBH =", BIOMASS_METHOD$height_dbh_coefficients$a,
        "+", BIOMASS_METHOD$height_dbh_coefficients$b, "× Height\n")
  }

  # Filter unrealistic values
  trees_final$DBH_cm[trees_final$DBH_cm < 1] <- 1
  trees_final$DBH_cm[trees_final$DBH_cm > 150] <- 150

  cat("DBH range:", round(min(trees_final$DBH_cm), 1), "-",
      round(max(trees_final$DBH_cm), 1), "cm\n")
  cat("Mean DBH:", round(mean(trees_final$DBH_cm), 1), "cm\n")
}

# ==============================================================================
# STEP 3: CALCULATE ABOVEGROUND BIOMASS
# ==============================================================================

cat("\n=== STEP 3: Calculating Aboveground Biomass ===\n")

# Apply allometric equations
trees_final$AGB_kg <- sapply(1:nrow(trees_final), function(i) {
  species <- trees_final$species[i]
  DBH <- trees_final$DBH_cm[i]

  # Get equation coefficients
  if (species %in% names(ALLOMETRIC_EQUATIONS)) {
    eq <- ALLOMETRIC_EQUATIONS[[species]]
    AGB <- exp(eq$a + eq$b * log(DBH))
  } else {
    # Generic equation
    AGB <- exp(GENERIC_ALLOMETRIC$a + GENERIC_ALLOMETRIC$b * log(DBH))
  }

  return(AGB)
})

cat("Calculated AGB for", nrow(trees_final), "trees\n")
cat("AGB range:", round(min(trees_final$AGB_kg), 1), "-",
    round(max(trees_final$AGB_kg), 0), "kg/tree\n")
cat("Mean AGB:", round(mean(trees_final$AGB_kg), 1), "kg/tree\n")
cat("Total AGB:", round(sum(trees_final$AGB_kg) / 1000, 1), "Mg\n")

# ==============================================================================
# STEP 4: CALCULATE BELOWGROUND BIOMASS (ROOTS)
# ==============================================================================

cat("\n=== STEP 4: Calculating Belowground Biomass ===\n")

# Get root:shoot ratio for ecosystem
rs_ratio <- CARBON_FACTORS$root_shoot_ratios[[SPECIES_ASSIGNMENT$ecosystem_type]]

trees_final$BGB_kg <- trees_final$AGB_kg * rs_ratio

cat("Root:shoot ratio:", rs_ratio, "\n")
cat("Mean BGB:", round(mean(trees_final$BGB_kg), 1), "kg/tree\n")
cat("Total BGB:", round(sum(trees_final$BGB_kg) / 1000, 1), "Mg\n")

# Total biomass
trees_final$total_biomass_kg <- trees_final$AGB_kg + trees_final$BGB_kg

cat("Total biomass:", round(sum(trees_final$total_biomass_kg) / 1000, 1), "Mg\n")

# ==============================================================================
# STEP 5: CONVERT TO CARBON
# ==============================================================================

cat("\n=== STEP 5: Converting Biomass to Carbon ===\n")

# Carbon is ~50% of dry biomass
trees_final$carbon_kg <- trees_final$total_biomass_kg * CARBON_FACTORS$biomass_to_carbon

cat("Conversion factor:", CARBON_FACTORS$biomass_to_carbon, "\n")
cat("Mean carbon per tree:", round(mean(trees_final$carbon_kg), 1), "kg C\n")
cat("Total carbon:", round(sum(trees_final$carbon_kg) / 1000, 1), "Mg C\n")

# ==============================================================================
# STEP 6: CALCULATE STAND-LEVEL CARBON STOCKS
# ==============================================================================

cat("\n=== STEP 6: Stand-Level Carbon Stocks ===\n")

# Get study area from previous analysis
if (exists("stand_summary")) {
  study_area_ha <- stand_summary$value[stand_summary$metric == "Study Area (ha)"]
} else {
  # Calculate from tree extent
  bbox <- c(
    xmin = min(trees_final$x), xmax = max(trees_final$x),
    ymin = min(trees_final$y), ymax = max(trees_final$y)
  )
  study_area_m2 <- (bbox["xmax"] - bbox["xmin"]) * (bbox["ymax"] - bbox["ymin"])
  study_area_ha <- study_area_m2 / 10000
}

# Carbon stock per hectare
total_carbon_Mg <- sum(trees_final$carbon_kg) / 1000
carbon_stock_MgC_ha <- total_carbon_Mg / study_area_ha

cat("\nStudy area:", round(study_area_ha, 2), "ha\n")
cat("Total carbon stock:", round(total_carbon_Mg, 2), "Mg C\n")
cat("Carbon stock density:", round(carbon_stock_MgC_ha, 1), "Mg C/ha\n")

# Compare to typical values
ecosystem_typical <- FOREST_ECOSYSTEMS[[SPECIES_ASSIGNMENT$ecosystem_type]]$typical_carbon_stock_MgC_ha
cat("\nComparison to typical", FOREST_ECOSYSTEMS[[SPECIES_ASSIGNMENT$ecosystem_type]]$name, ":\n")
cat("This stand:", round(carbon_stock_MgC_ha, 1), "Mg C/ha\n")
cat("Typical:", ecosystem_typical, "Mg C/ha\n")
cat("Difference:", round(carbon_stock_MgC_ha - ecosystem_typical, 1), "Mg C/ha",
    "(", round(100 * (carbon_stock_MgC_ha - ecosystem_typical) / ecosystem_typical, 0), "%)\n")

# ==============================================================================
# STEP 7: UNCERTAINTY ESTIMATION
# ==============================================================================

if (BIOMASS_METHOD$calculate_uncertainty) {

  cat("\n=== STEP 7: Uncertainty Estimation ===\n")

  # Sources of uncertainty:
  # 1. Allometric equation error (typically ±15-30%)
  # 2. Height measurement error (±5-10%)
  # 3. Sampling error (if this is a sample plot)

  # Allometric equation RMSE (typical values)
  allometric_RMSE_percent <- 20  # ±20% typical for regional equations

  # Height measurement error
  height_error_percent <- 5  # ±5% for drone photogrammetry

  # Propagate uncertainty using simple error propagation
  # Total error ≈ sqrt(error1² + error2² + ...)
  total_error_percent <- sqrt(
    allometric_RMSE_percent^2 +
    height_error_percent^2
  )

  # Calculate confidence interval (assuming normal distribution)
  carbon_stock_SE <- carbon_stock_MgC_ha * (total_error_percent / 100)
  carbon_stock_CI95_lower <- carbon_stock_MgC_ha - 1.96 * carbon_stock_SE
  carbon_stock_CI95_upper <- carbon_stock_MgC_ha + 1.96 * carbon_stock_SE

  cat("Uncertainty sources:\n")
  cat("  Allometric equations: ±", allometric_RMSE_percent, "%\n")
  cat("  Height measurement: ±", height_error_percent, "%\n")
  cat("  Combined uncertainty: ±", round(total_error_percent, 1), "%\n\n")

  cat("Carbon Stock: ", round(carbon_stock_MgC_ha, 1), " Mg C/ha\n", sep = "")
  cat("95% CI: [", round(carbon_stock_CI95_lower, 1), ", ",
      round(carbon_stock_CI95_upper, 1), "] Mg C/ha\n", sep = "")
  cat("Standard Error: ±", round(carbon_stock_SE, 1), " Mg C/ha\n")
}

# ==============================================================================
# STEP 8: CREATE SPATIAL CARBON MAP
# ==============================================================================

cat("\n=== STEP 8: Creating Spatial Carbon Map ===\n")

# Convert trees to spatial points
trees_sf <- st_as_sf(
  trees_final,
  coords = c("x", "y"),
  crs = PROJECT$coordinate_system
)

# Create raster grid
bbox <- st_bbox(trees_sf)
grid_resolution <- 10  # 10m grid cells

# Create template raster
template <- rast(
  extent = c(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]),
  resolution = grid_resolution,
  crs = PROJECT$coordinate_system
)

# Rasterize carbon stocks (sum carbon per cell)
carbon_raster <- rasterize(
  vect(trees_sf),
  template,
  field = "carbon_kg",
  fun = sum,
  background = 0
)

# Convert to Mg C/ha
cell_area_ha <- (grid_resolution^2) / 10000
carbon_raster_MgC_ha <- carbon_raster / 1000 / cell_area_ha

# Save raster
writeRaster(
  carbon_raster_MgC_ha,
  file.path(DIRECTORIES$drone_biomass, "carbon_stock_map.tif"),
  overwrite = TRUE
)

cat("Carbon map saved:", file.path(DIRECTORIES$drone_biomass, "carbon_stock_map.tif"), "\n")

# ==============================================================================
# STEP 9: VISUALIZATION
# ==============================================================================

cat("\n=== STEP 9: Creating Visualizations ===\n")

# Plot 1: Biomass distribution
plot1 <- ggplot(trees_final, aes(x = AGB_kg)) +
  geom_histogram(binwidth = 50, fill = "#2E7D32", color = "white") +
  geom_vline(xintercept = mean(trees_final$AGB_kg), color = "red",
             linetype = "dashed", size = 1) +
  labs(
    title = "Tree-Level Aboveground Biomass Distribution",
    x = "Aboveground Biomass (kg/tree)",
    y = "Frequency",
    caption = paste("Mean =", round(mean(trees_final$AGB_kg), 1), "kg")
  ) +
  theme_minimal()

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/biomass_distribution.png"),
  plot1, width = 10, height = 6, dpi = 300
)

# Plot 2: Carbon vs. Height
plot2 <- ggplot(trees_final, aes(x = height_m, y = carbon_kg)) +
  geom_point(alpha = 0.5, color = "#2E7D32") +
  geom_smooth(method = "loess", color = "#1B5E20", se = TRUE) +
  labs(
    title = "Carbon Stock vs. Tree Height",
    x = "Tree Height (m)",
    y = "Carbon Stock (kg C/tree)"
  ) +
  theme_minimal()

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/carbon_height_relationship.png"),
  plot2, width = 8, height = 6, dpi = 300
)

# Plot 3: Spatial carbon map
carbon_df <- as.data.frame(carbon_raster_MgC_ha, xy = TRUE)
names(carbon_df)[3] <- "carbon_MgC_ha"

plot3 <- ggplot(carbon_df[carbon_df$carbon_MgC_ha > 0, ],
                aes(x = x, y = y, fill = carbon_MgC_ha)) +
  geom_raster() +
  scale_fill_gradientn(
    colors = COLOR_SCHEMES$carbon_stock,
    name = "Carbon Stock\n(Mg C/ha)",
    na.value = "transparent",
    limits = c(0, max(carbon_df$carbon_MgC_ha, na.rm = TRUE))
  ) +
  coord_equal() +
  labs(
    title = "Spatial Distribution of Carbon Stocks",
    subtitle = paste("Grid resolution:", grid_resolution, "m"),
    x = "Easting (m)", y = "Northing (m)"
  ) +
  theme_minimal() +
  theme(legend.position = "right")

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/carbon_map.png"),
  plot3, width = 12, height = 10, dpi = 300
)

# Plot 4: Carbon components
carbon_components <- data.frame(
  component = c("Aboveground Biomass", "Belowground Biomass (Roots)"),
  carbon_Mg = c(
    sum(trees_final$AGB_kg) * 0.5 / 1000,
    sum(trees_final$BGB_kg) * 0.5 / 1000
  )
)

plot4 <- ggplot(carbon_components, aes(x = component, y = carbon_Mg, fill = component)) +
  geom_bar(stat = "identity", color = "black") +
  scale_fill_manual(values = c("#2E7D32", "#558B2F")) +
  labs(
    title = "Carbon Stock by Component",
    x = "", y = "Carbon Stock (Mg C)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(
  file.path(DIRECTORIES$drone, "diagnostics/carbon_components.png"),
  plot4, width = 8, height = 6, dpi = 300
)

cat("Visualizations saved!\n")

# ==============================================================================
# STEP 10: EXPORT RESULTS
# ==============================================================================

cat("\n=== STEP 10: Exporting Results ===\n")

# Tree-level results
trees_export <- trees_final %>%
  select(
    tree_id, x, y,
    species,
    height_m, DBH_cm,
    crown_area_m2, crown_diameter_m,
    AGB_kg, BGB_kg, total_biomass_kg, carbon_kg,
    qc_flag
  )

write.csv(
  trees_export,
  file.path(DIRECTORIES$drone_biomass, "tree_carbon_stocks.csv"),
  row.names = FALSE
)

cat("Tree-level carbon stocks saved\n")

# Stand-level summary
stand_carbon_summary <- data.frame(
  metric = c(
    "Study Area (ha)",
    "Total Trees",
    "Total Aboveground Biomass (Mg)",
    "Total Belowground Biomass (Mg)",
    "Total Biomass (Mg)",
    "Total Carbon Stock (Mg C)",
    "Carbon Stock Density (Mg C/ha)",
    "95% CI Lower (Mg C/ha)",
    "95% CI Upper (Mg C/ha)",
    "Relative Uncertainty (%)",
    "Mean Tree Carbon (kg C/tree)",
    "Dominant Species"
  ),
  value = c(
    round(study_area_ha, 2),
    nrow(trees_final),
    round(sum(trees_final$AGB_kg) / 1000, 2),
    round(sum(trees_final$BGB_kg) / 1000, 2),
    round(sum(trees_final$total_biomass_kg) / 1000, 2),
    round(total_carbon_Mg, 2),
    round(carbon_stock_MgC_ha, 1),
    if (exists("carbon_stock_CI95_lower")) round(carbon_stock_CI95_lower, 1) else NA,
    if (exists("carbon_stock_CI95_upper")) round(carbon_stock_CI95_upper, 1) else NA,
    if (exists("total_error_percent")) round(total_error_percent, 1) else NA,
    round(mean(trees_final$carbon_kg), 1),
    SPECIES_ASSIGNMENT$default_species
  )
)

write.csv(
  stand_carbon_summary,
  file.path(DIRECTORIES$drone_biomass, "stand_carbon_summary.csv"),
  row.names = FALSE
)

print(stand_carbon_summary)

# Save shapefile with carbon data
trees_carbon_sf <- st_as_sf(
  trees_export,
  coords = c("x", "y"),
  crs = PROJECT$coordinate_system
)

st_write(
  trees_carbon_sf,
  file.path(DIRECTORIES$drone_biomass, "trees_carbon.shp"),
  delete_dsn = TRUE,
  quiet = TRUE
)

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("BIOMASS & CARBON CALCULATION COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

cat("KEY RESULTS:\n")
cat("  Carbon Stock:", round(carbon_stock_MgC_ha, 1), "Mg C/ha\n")
if (exists("total_error_percent")) {
  cat("  Uncertainty: ±", round(total_error_percent, 1), "%\n")
}
cat("  Total Carbon:", round(total_carbon_Mg, 2), "Mg C\n")
cat("  Study Area:", round(study_area_ha, 2), "ha\n\n")

cat("Outputs:\n")
cat("  - Tree carbon stocks:", file.path(DIRECTORIES$drone_biomass, "tree_carbon_stocks.csv"), "\n")
cat("  - Stand summary:", file.path(DIRECTORIES$drone_biomass, "stand_carbon_summary.csv"), "\n")
cat("  - Carbon map:", file.path(DIRECTORIES$drone_biomass, "carbon_stock_map.tif"), "\n")
cat("  - Shapefile:", file.path(DIRECTORIES$drone_biomass, "trees_carbon.shp"), "\n\n")

cat("DRONE WORKFLOW COMPLETE!\n")
cat("Proceed to sampling design or remote sensing workflows.\n\n")
