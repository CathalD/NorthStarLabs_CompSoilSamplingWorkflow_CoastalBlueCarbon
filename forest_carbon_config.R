################################################################################
# FOREST CARBON MONITORING - CONFIGURATION FILE
################################################################################
# Purpose: Central configuration for forest, bog, and fen carbon assessment
# Ecosystems: Boreal/temperate forests, peatlands (bogs, fens)
# Region: Canada (adaptable)
# Author: NorthStar Labs
# Date: 2025-11-17
################################################################################

# ==============================================================================
# 1. PROJECT METADATA
# ==============================================================================

PROJECT <- list(
  name = "Canadian Forest Carbon Monitoring",
  region = "Canada - Boreal and Temperate",
  start_date = "2025",
  coordinate_system = "EPSG:3005",  # BC Albers (change to your region)
  utm_zone = "EPSG:32610"  # UTM Zone 10N (for metric calculations)
)

# ==============================================================================
# 2. ECOSYSTEM DEFINITIONS
# ==============================================================================

FOREST_ECOSYSTEMS <- list(

  # Forest Types
  boreal_conifer = list(
    name = "Boreal Coniferous Forest",
    dominant_species = c("Picea glauca", "Picea mariana", "Pinus contorta", "Abies balsamea"),
    typical_carbon_stock_MgC_ha = 120,  # Aboveground + belowground
    typical_height_m = 15,
    root_shoot_ratio = 0.24,  # IPCC default for boreal conifers
    color = "#2E7D32"
  ),

  boreal_mixed = list(
    name = "Boreal Mixed Forest",
    dominant_species = c("Populus tremuloides", "Betula papyrifera", "Picea spp."),
    typical_carbon_stock_MgC_ha = 100,
    typical_height_m = 18,
    root_shoot_ratio = 0.23,
    color = "#558B2F"
  ),

  temperate_conifer = list(
    name = "Temperate Coniferous Forest",
    dominant_species = c("Pseudotsuga menziesii", "Thuja plicata", "Tsuga heterophylla"),
    typical_carbon_stock_MgC_ha = 250,
    typical_height_m = 35,
    root_shoot_ratio = 0.20,
    color = "#1B5E20"
  ),

  temperate_deciduous = list(
    name = "Temperate Deciduous Forest",
    dominant_species = c("Acer saccharum", "Quercus rubra", "Fagus grandifolia"),
    typical_carbon_stock_MgC_ha = 140,
    typical_height_m = 25,
    root_shoot_ratio = 0.24,
    color = "#689F38"
  ),

  # Peatland Types
  bog = list(
    name = "Ombrotrophic Bog",
    vegetation = c("Sphagnum spp.", "Picea mariana", "Ericaceous shrubs"),
    typical_carbon_stock_MgC_ha = 850,  # Mostly soil carbon (deep peat)
    peat_depth_m = 3.5,
    bulk_density_range = c(0.05, 0.15),  # g/cm³
    carbon_content_percent = 45,
    color = "#D84315"
  ),

  fen = list(
    name = "Minerotrophic Fen",
    vegetation = c("Carex spp.", "Sphagnum spp.", "Larix laricina"),
    typical_carbon_stock_MgC_ha = 650,
    peat_depth_m = 2.5,
    bulk_density_range = c(0.08, 0.20),
    carbon_content_percent = 42,
    color = "#F57C00"
  ),

  treed_peatland = list(
    name = "Treed Peatland",
    vegetation = c("Picea mariana", "Larix laricina", "Sphagnum spp."),
    typical_carbon_stock_MgC_ha = 950,  # High soil + moderate tree biomass
    peat_depth_m = 3.0,
    bulk_density_range = c(0.06, 0.18),
    carbon_content_percent = 44,
    tree_density_stems_ha = 800,
    color = "#E65100"
  )
)

# ==============================================================================
# 3. CANADIAN TREE SPECIES ALLOMETRIC EQUATIONS
# ==============================================================================
# Format: AGB (kg) = exp(a + b * ln(DBH)) where DBH in cm
# Sources: Lambert et al. 2005, Ung et al. 2008, Lambert & Ung 2012

ALLOMETRIC_EQUATIONS <- list(

  # Boreal Conifers
  Picea_glauca = list(
    common_name = "White Spruce",
    equation = "exp(-2.0336 + 2.3263 * log(DBH))",
    a = -2.0336, b = 2.3263,
    reference = "Lambert et al. 2005",
    region = "Boreal",
    DBH_range_cm = c(1, 60)
  ),

  Picea_mariana = list(
    common_name = "Black Spruce",
    equation = "exp(-2.1364 + 2.3233 * log(DBH))",
    a = -2.1364, b = 2.3233,
    reference = "Lambert et al. 2005",
    region = "Boreal",
    DBH_range_cm = c(1, 50)
  ),

  Pinus_contorta = list(
    common_name = "Lodgepole Pine",
    equation = "exp(-2.1765 + 2.3849 * log(DBH))",
    a = -2.1765, b = 2.3849,
    reference = "Lambert et al. 2005",
    region = "Boreal/Montane",
    DBH_range_cm = c(1, 55)
  ),

  Abies_balsamea = list(
    common_name = "Balsam Fir",
    equation = "exp(-2.1364 + 2.3480 * log(DBH))",
    a = -2.1364, b = 2.3480,
    reference = "Lambert et al. 2005",
    region = "Boreal",
    DBH_range_cm = c(1, 50)
  ),

  # Boreal Deciduous
  Populus_tremuloides = list(
    common_name = "Trembling Aspen",
    equation = "exp(-2.2250 + 2.2560 * log(DBH))",
    a = -2.2250, b = 2.2560,
    reference = "Lambert et al. 2005",
    region = "Boreal",
    DBH_range_cm = c(1, 60)
  ),

  Betula_papyrifera = list(
    common_name = "Paper Birch",
    equation = "exp(-2.5497 + 2.5186 * log(DBH))",
    a = -2.5497, b = 2.5186,
    reference = "Lambert et al. 2005",
    region = "Boreal",
    DBH_range_cm = c(1, 55)
  ),

  # Temperate Conifers (Pacific Coast)
  Pseudotsuga_menziesii = list(
    common_name = "Douglas Fir",
    equation = "exp(-2.2304 + 2.4435 * log(DBH))",
    a = -2.2304, b = 2.4435,
    reference = "Ung et al. 2008",
    region = "Pacific/Montane",
    DBH_range_cm = c(1, 100)
  ),

  Thuja_plicata = list(
    common_name = "Western Red Cedar",
    equation = "exp(-2.0080 + 2.3236 * log(DBH))",
    a = -2.0080, b = 2.3236,
    reference = "Ung et al. 2008",
    region = "Pacific",
    DBH_range_cm = c(1, 120)
  ),

  Tsuga_heterophylla = list(
    common_name = "Western Hemlock",
    equation = "exp(-2.3480 + 2.4486 * log(DBH))",
    a = -2.3480, b = 2.4486,
    reference = "Ung et al. 2008",
    region = "Pacific",
    DBH_range_cm = c(1, 90)
  ),

  # Temperate Deciduous (Eastern)
  Acer_saccharum = list(
    common_name = "Sugar Maple",
    equation = "exp(-2.0470 + 2.3852 * log(DBH))",
    a = -2.0470, b = 2.3852,
    reference = "Ung et al. 2008",
    region = "Temperate Deciduous",
    DBH_range_cm = c(1, 70)
  )
)

# Generic equation for unknown species (conservative)
GENERIC_ALLOMETRIC <- list(
  a = -2.134,
  b = 2.330,
  reference = "Pan-Canadian average (Lambert et al. 2005)"
)

# ==============================================================================
# 4. BIOMASS CARBON CONVERSION FACTORS
# ==============================================================================

CARBON_FACTORS <- list(
  biomass_to_carbon = 0.5,  # Standard: 50% of dry biomass is carbon
  root_shoot_ratios = list(
    boreal_conifer = 0.24,
    boreal_deciduous = 0.23,
    temperate_conifer = 0.20,
    temperate_deciduous = 0.24,
    peatland_trees = 0.28  # Slightly higher for peatland trees
  ),
  peat_carbon_fraction = 0.50  # Organic matter to carbon (varies 0.45-0.55)
)

# ==============================================================================
# 5. DRONE SPECIFICATIONS & PARAMETERS
# ==============================================================================

DRONE_PARAMS <- list(

  # Flight Planning
  flight_altitude_m = 100,
  overlap_forward = 0.80,  # 80% forward overlap
  overlap_side = 0.70,     # 70% side overlap
  ground_resolution_cm = 3,  # Target GSD for RGB

  # Sensor Types
  sensors = list(
    RGB = list(
      type = "RGB Camera",
      purpose = "Photogrammetry, orthomosaics, canopy height models",
      recommended = "DJI Zenmuse P1 (45 MP), Phantom 4 RTK"
    ),

    Multispectral = list(
      type = "Multispectral (5-band)",
      purpose = "Vegetation indices, species classification, health",
      bands = c("Blue", "Green", "Red", "Red Edge", "NIR"),
      recommended = "MicaSense RedEdge-MX, DJI P4 Multispectral"
    ),

    LiDAR = list(
      type = "UAV LiDAR",
      purpose = "Canopy penetration, precise terrain, understory",
      point_density_pts_m2 = 100,
      recommended = "YellowScan Surveyor, Velodyne Puck"
    )
  ),

  # Processing Software
  software = list(
    photogrammetry = c("Agisoft Metashape", "Pix4Dmapper", "OpenDroneMap (free)"),
    lidar = c("LAStools", "PDAL", "lidR (R package)"),
    tree_segmentation = c("lidR (R)", "ForestTools (R)", "itcSegment")
  ),

  # Output Products
  outputs = c(
    "Digital Elevation Model (DEM)",
    "Digital Surface Model (DSM)",
    "Canopy Height Model (CHM)",
    "Orthomosaic RGB",
    "Point Cloud (LAZ/LAS)",
    "Individual Tree Crowns (shapefile)",
    "Tree Attributes (CSV)"
  )
)

# ==============================================================================
# 6. SAMPLING DESIGN PARAMETERS
# ==============================================================================

SAMPLING_DESIGN <- list(

  # Plot Types
  plot_types = list(
    fixed_area = list(
      radius_m = c(11.28, 17.84),  # 400 m², 1000 m² circular plots
      area_m2 = c(400, 1000),
      best_for = "Uniform stands, young forests, drones"
    ),

    variable_radius = list(
      BAF = c(2, 4),  # Basal Area Factor (m²/ha per tree)
      best_for = "Variable density, traditional forestry"
    ),

    peatland = list(
      plot_size_m2 = 100,  # 10m x 10m
      core_locations = 3,  # Minimum cores per plot
      depth_cm = 300,      # Target depth for peat
      best_for = "Soil carbon assessment"
    )
  ),

  # Sample Size Calculation
  target_precision = 0.10,  # ±10% of mean (95% CI)
  confidence_level = 0.95,
  expected_CV = 0.30,  # Coefficient of variation (conservative)

  # Stratification
  stratification = list(
    method = "environmental",
    variables = c("forest_type", "stand_age", "canopy_cover", "topography"),
    minimum_plots_per_stratum = 10
  )
)

# ==============================================================================
# 7. REMOTE SENSING PARAMETERS
# ==============================================================================

REMOTE_SENSING <- list(

  # GEDI (LiDAR from Space)
  GEDI = list(
    product = "GEDI02_A",  # Elevation and height metrics
    version = "002",
    footprint_diameter_m = 25,
    variables = c("rh98", "rh95", "rh75", "rh50", "cover"),  # Relative heights
    quality_flag_threshold = 1,  # Only high-quality shots
    date_range = c("2019-04-01", "2024-12-31"),
    download_source = "https://search.earthdata.nasa.gov/"
  ),

  # Sentinel-2 (Optical)
  Sentinel2 = list(
    collection = "COPERNICUS/S2_SR",  # Surface Reflectance
    cloud_cover_max = 20,  # Maximum cloud cover %
    date_range_summer = c("06-01", "09-15"),  # Peak season
    bands = list(
      vegetation = c("B8", "B4", "B3", "B2"),  # NIR, Red, Green, Blue
      indices = c("NDVI", "EVI", "NDMI", "SAVI")
    ),
    resolution_m = 10
  ),

  # Landsat 8/9
  Landsat = list(
    collection = "LANDSAT/LC08/C02/T1_L2",
    cloud_cover_max = 20,
    bands = c("SR_B5", "SR_B4", "SR_B3"),  # NIR, Red, Green
    resolution_m = 30
  ),

  # Terrain
  DEM = list(
    source = "USGS/SRTMGL1_003",  # SRTM 30m
    derived_variables = c("elevation", "slope", "aspect", "TWI", "TPI")
  )
)

# ==============================================================================
# 8. GEDI-BASED BIOMASS MODELS
# ==============================================================================
# Based on Duncanson et al. 2022, Potapov et al. 2021

GEDI_BIOMASS_MODELS <- list(

  boreal = list(
    # AGB (Mg/ha) = f(RH98, canopy cover, Landfire EVT)
    model = "log(AGB) ~ a + b * RH98 + c * cover + d * RH98 * cover",
    coefficients = list(a = 2.13, b = 0.036, c = 0.015, d = 0.0003),
    RMSE_MgC_ha = 35,
    reference = "Duncanson et al. 2022 - Boreal"
  ),

  temperate = list(
    model = "log(AGB) ~ a + b * RH98 + c * cover",
    coefficients = list(a = 2.58, b = 0.042, c = 0.012),
    RMSE_MgC_ha = 45,
    reference = "Duncanson et al. 2022 - Temperate"
  ),

  # Generic relationship (simpler)
  generic = list(
    model = "AGB_MgHa = 0.55 * RH98^1.2",  # Power function
    reference = "Simplified from literature"
  )
)

# ==============================================================================
# 9. QA/QC THRESHOLDS
# ==============================================================================

QC_THRESHOLDS <- list(

  # Forest Metrics
  tree_height_m = c(1.3, 70),        # Min/max plausible heights
  DBH_cm = c(1, 150),                # Min/max DBH
  crown_diameter_m = c(1, 30),       # Crown extent
  biomass_kg_tree = c(0.5, 15000),   # Individual tree biomass
  carbon_stock_MgC_ha = c(5, 400),   # Stand-level carbon

  # Peatland Metrics
  peat_depth_cm = c(30, 1200),       # Minimum 30 cm to classify as peatland
  bulk_density_g_cm3 = c(0.03, 0.40), # Peat bulk density
  carbon_percent = c(30, 60),        # Organic carbon content

  # Spatial Metrics
  duplicate_distance_m = 5,          # Flag if trees <5m apart
  plot_minimum_trees = 3             # Minimum trees for valid plot
)

# ==============================================================================
# 10. OUTPUT DIRECTORY STRUCTURE
# ==============================================================================

DIRECTORIES <- list(
  base = "outputs/forest_carbon",

  drone = "outputs/forest_carbon/drone",
  drone_chm = "outputs/forest_carbon/drone/canopy_height_models",
  drone_trees = "outputs/forest_carbon/drone/individual_trees",
  drone_biomass = "outputs/forest_carbon/drone/biomass_maps",

  sampling = "outputs/forest_carbon/sampling",
  sampling_design = "outputs/forest_carbon/sampling/plot_designs",
  sampling_field = "outputs/forest_carbon/sampling/field_data",

  remote_sensing = "outputs/forest_carbon/remote_sensing",
  gedi = "outputs/forest_carbon/remote_sensing/gedi",
  sentinel2 = "outputs/forest_carbon/remote_sensing/sentinel2",
  carbon_maps = "outputs/forest_carbon/remote_sensing/carbon_maps_3d",

  reports = "outputs/forest_carbon/reports",

  diagnostics = "outputs/forest_carbon/diagnostics"
)

# ==============================================================================
# 11. COLOR SCHEMES FOR MAPPING
# ==============================================================================

COLOR_SCHEMES <- list(

  carbon_stock = c(
    "#FFFFCC",  # Low (< 50 Mg C/ha)
    "#A1DAB4",  # Medium-low (50-100)
    "#41B6C4",  # Medium (100-150)
    "#2C7FB8",  # Medium-high (150-200)
    "#253494"   # High (> 200)
  ),

  forest_height = c(
    "#FFF7BC",  # 0-5 m
    "#FED976",  # 5-10 m
    "#FEB24C",  # 10-20 m
    "#FC4E2A",  # 20-30 m
    "#B10026"   # > 30 m
  ),

  ecosystem_type = c(
    boreal_conifer = "#2E7D32",
    boreal_mixed = "#558B2F",
    temperate_conifer = "#1B5E20",
    temperate_deciduous = "#689F38",
    bog = "#D84315",
    fen = "#F57C00",
    treed_peatland = "#E65100"
  )
)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Calculate biomass from DBH using allometric equation
calculate_biomass <- function(DBH_cm, species_code) {
  if (species_code %in% names(ALLOMETRIC_EQUATIONS)) {
    eq <- ALLOMETRIC_EQUATIONS[[species_code]]
    AGB_kg <- exp(eq$a + eq$b * log(DBH_cm))
  } else {
    # Use generic equation
    AGB_kg <- exp(GENERIC_ALLOMETRIC$a + GENERIC_ALLOMETRIC$b * log(DBH_cm))
  }
  return(AGB_kg)
}

# Convert biomass to carbon
biomass_to_carbon <- function(AGB_kg, ecosystem_type = "boreal_conifer") {
  # Get root:shoot ratio
  rs_ratio <- CARBON_FACTORS$root_shoot_ratios[[ecosystem_type]]

  # Total biomass
  total_biomass_kg <- AGB_kg * (1 + rs_ratio)

  # Convert to carbon
  carbon_kg <- total_biomass_kg * CARBON_FACTORS$biomass_to_carbon

  return(carbon_kg)
}

# Print configuration summary
print_config_summary <- function() {
  cat("\n=== FOREST CARBON MONITORING CONFIGURATION ===\n")
  cat("Project:", PROJECT$name, "\n")
  cat("Region:", PROJECT$region, "\n")
  cat("Coordinate System:", PROJECT$coordinate_system, "\n\n")

  cat("Ecosystems Configured:", length(FOREST_ECOSYSTEMS), "\n")
  for (eco in names(FOREST_ECOSYSTEMS)) {
    cat("  -", FOREST_ECOSYSTEMS[[eco]]$name, "\n")
  }

  cat("\nAllometric Equations:", length(ALLOMETRIC_EQUATIONS), "species\n")
  cat("Drone Sensors:", length(DRONE_PARAMS$sensors), "types\n")
  cat("Sampling Plot Types:", length(SAMPLING_DESIGN$plot_types), "\n")
  cat("\n==============================================\n\n")
}

# ==============================================================================
# END OF CONFIGURATION
# ==============================================================================

cat("Forest Carbon Configuration Loaded Successfully!\n")
cat("Run print_config_summary() to view settings.\n")
