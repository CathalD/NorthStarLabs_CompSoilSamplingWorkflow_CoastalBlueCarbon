# ============================================================================
# ARCTIC PERMAFROST WETLAND CARBON MONITORING CONFIGURATION
# ============================================================================
# Adapted from coastal blue carbon workflow for Canadian Arctic/Subarctic ecosystems
# Edit these parameters for your specific project
# This file is sourced by analysis modules

# ============================================================================
# PROJECT METADATA (Adapted VM0033/VM0036)
# ============================================================================

PROJECT_NAME <- "Arctic_Permafrost_Wetlands_2024"
PROJECT_SCENARIO <- "BASELINE"  # Options: BASELINE, PROJECT, DEGRADING, INTACT, THERMOKARST
MONITORING_YEAR <- 2024

# Project location (for documentation)
PROJECT_LOCATION <- "Canadian Arctic and Subarctic, Northwest Territories/Yukon/Nunavut"
PROJECT_DESCRIPTION <- "Arctic permafrost wetland carbon monitoring for climate vulnerability assessment - Permafrost thaw tracking and carbon stock quantification in polygonal tundra, peatlands, and thermokarst features"

# Ecosystem type
ECOSYSTEM_TYPE <- "ARCTIC_PERMAFROST_WETLANDS"  # NEW: Arctic-specific identifier

# ============================================================================
# ECOSYSTEM STRATIFICATION
# ============================================================================

# Valid ecosystem strata (must match GEE stratification tool)
#
# FILE NAMING CONVENTION:
#   Module 05 auto-detects GEE stratum masks using this pattern:
#   "Stratum Name" → stratum_name.tif in data_raw/gee_strata/
#
# Examples:
#   "Upper Marsh"           → upper_marsh.tif
#   "Underwater Vegetation" → underwater_vegetation.tif
#   "Emerging Marsh"        → emerging_marsh.tif
#
# CUSTOMIZATION OPTIONS:
#   1. Simple: Edit VALID_STRATA below and export GEE masks with matching names
#   2. Advanced: Create stratum_definitions.csv in project root for custom file names
#      and optional metadata (see stratum_definitions_EXAMPLE.csv template)
#
# See README section "Customizing Ecosystem Strata" for full details.
#
VALID_STRATA <- c(
  "Polygonal Tundra - Wet Center",    # Ice-wedge polygon centers, high water table
  "Polygonal Tundra - Dry Rim",       # Elevated polygon rims, better drainage
  "Palsa Peatland",                   # Permafrost peat mounds, elevated, dry
  "Thermokarst Fen",                  # Collapsed permafrost, wet, decomposed peat
  "Subarctic Fen",                    # Permafrost-free minerotrophic wetland
  "Tundra Pond Margin",               # Emergent vegetation around thermokarst ponds
  "Intact Permafrost Peatland",       # Reference site, stable permafrost
  "Degrading Permafrost Peatland",    # Active thaw, subsidence, altered hydrology
  "Polygon Center - Vegetated",       # Low-center polygons with sedge/moss
  "Bare Mineral Tundra"               # Exposed mineral soil, minimal organics
)

# Stratum colors for plotting (Arctic landscape classification)
STRATUM_COLORS <- c(
  "Polygonal Tundra - Wet Center" = "#99CCFF",      # Light blue - wet
  "Polygonal Tundra - Dry Rim" = "#FFCC99",         # Tan - dry elevated
  "Palsa Peatland" = "#CC9966",                     # Brown - peat mounds
  "Thermokarst Fen" = "#006699",                    # Dark blue - very wet
  "Subarctic Fen" = "#66CC99",                      # Green-blue - minerotrophic
  "Tundra Pond Margin" = "#3399CC",                 # Blue - aquatic edge
  "Intact Permafrost Peatland" = "#999966",         # Olive - stable
  "Degrading Permafrost Peatland" = "#CC6633",      # Orange-red - degrading
  "Polygon Center - Vegetated" = "#99FF99",         # Light green - vegetated
  "Bare Mineral Tundra" = "#CCCCCC"                 # Gray - mineral
)

# ============================================================================
# DEPTH CONFIGURATION - ARCTIC PERMAFROST ADAPTED
# ============================================================================

# PERMAFROST-SPECIFIC DEPTH PARAMETERS
# Active layer depth (cm) - highly variable across sites and years
# This is the maximum seasonal thaw depth
ACTIVE_LAYER_DEPTH_MIN <- 30    # Minimum expected active layer (shallow permafrost sites)
ACTIVE_LAYER_DEPTH_MAX <- 150   # Maximum expected active layer (degrading sites)
ACTIVE_LAYER_DEPTH_TYPICAL <- 70  # Typical/reference active layer depth

# Permafrost table depth (cm) - depth to permanently frozen soil
# Note: Permafrost table = Active layer depth at end of thaw season
PERMAFROST_TABLE_DEPTH <- NULL  # Set to NULL for site-specific measurement, or default value

# VM0033/VM0036 adapted depth intervals (cm) - adjusted for Arctic active layer
# For shallow active layer sites (<70 cm), use shallower harmonization depths
VM0033_DEPTH_MIDPOINTS <- c(7.5, 22.5, 40, 75)  # Standard depths when active layer >100cm

# Arctic-adapted depth intervals for shallow active layer sites
ARCTIC_SHALLOW_DEPTH_MIDPOINTS <- c(7.5, 15, 30)  # For active layer 30-70 cm
ARCTIC_DEEP_DEPTH_MIDPOINTS <- c(7.5, 22.5, 40, 75, 125, 175)  # For deep cores >150 cm

# VM0033 depth intervals (cm) - for mass-weighted aggregation
VM0033_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30, 50),
  depth_bottom = c(15, 30, 50, 100),
  depth_midpoint = c(7.5, 22.5, 40, 75),
  thickness_cm = c(15, 15, 20, 50)
)

# Arctic permafrost depth intervals (0-300 cm for permafrost cores)
ARCTIC_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30, 50, 100, 150, 200),
  depth_bottom = c(15, 30, 50, 100, 150, 200, 300),
  depth_midpoint = c(7.5, 22.5, 40, 75, 125, 175, 250),
  thickness_cm = c(15, 15, 20, 50, 50, 50, 100),
  layer_type = c("active", "active", "active/transition", "active/transition",
                 "transition/permafrost", "permafrost", "permafrost")
)

# Standard depths for harmonization (use Arctic or VM0033 based on site)
STANDARD_DEPTHS <- VM0033_DEPTH_MIDPOINTS  # Override per-site based on active layer depth

# Fine-scale depth intervals (optional, for detailed analysis)
FINE_SCALE_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 125, 150, 200, 250, 300)

# Maximum core depth (cm) - extended for permafrost
MAX_CORE_DEPTH <- 300  # Increased from 100 cm for permafrost cores

# Key depth intervals for reporting (cm) - Arctic-specific
REPORTING_DEPTHS <- list(
  surface = c(0, 15),           # Surface organic layer
  active_layer = c(0, 70),      # Typical active layer (seasonally thawed)
  transition = c(50, 150),      # Transition zone near permafrost table
  upper_permafrost = c(100, 200),  # Upper permafrost (vulnerable carbon)
  deep_permafrost = c(200, 300)    # Deep permafrost (ancient carbon)
)

# Ground ice content parameters (volume %)
GROUND_ICE_CONTENT_TYPICAL <- 40  # Typical ground ice content (% volume)
GROUND_ICE_CONTENT_MIN <- 10      # Minimum expected
GROUND_ICE_CONTENT_MAX <- 80      # Maximum expected (ice-rich permafrost)

# ============================================================================
# COORDINATE SYSTEMS
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# Arctic-optimized projections:
PROCESSING_CRS <- 3573  # EPSG:3573 - WGS 84 / North Pole LAEA Canada (RECOMMENDED FOR ARCTIC)
# Other Arctic/Canada options:
#   - 3573: WGS 84 / North Pole LAEA Canada - BEST FOR ARCTIC/SUBARCTIC
#   - 3347: Canada Albers Equal Area (good for all Canada, less accurate at high latitudes)
#   - 3979: NAD83(CSRS) / Canada Atlas Lambert (modern Canadian reference)
#   - 32607-32616: WGS 84 / UTM zones (for specific longitude ranges)
#   - 3005: NAD83 / BC Albers (BC only)
# For specific Arctic regions:
#   - NWT/Nunavut: EPSG:3573 or appropriate UTM zone
#   - Yukon: EPSG:3573 or UTM zone 7-8N
#   - Alaska border: EPSG:3572 (NAD83 Alaska Albers)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM - ARCTIC PERMAFROST WETLANDS
# ============================================================================
# Use these when bulk density is not measured
# Values in g/cm³ based on Arctic permafrost literature
# NOTE: Frozen samples require thawed bulk density correction (ground ice content)

BD_DEFAULTS <- list(
  "Polygonal Tundra - Wet Center" = 0.15,     # Very low - organic-rich, water-saturated
  "Polygonal Tundra - Dry Rim" = 0.20,        # Low-moderate - better drained, some mineral
  "Palsa Peatland" = 0.10,                    # Very low - fibric peat, elevated
  "Thermokarst Fen" = 0.20,                   # Low-moderate - decomposed peat, wet
  "Subarctic Fen" = 0.12,                     # Low - moderately decomposed peat
  "Tundra Pond Margin" = 0.18,                # Low-moderate - transitional organic/mineral
  "Intact Permafrost Peatland" = 0.12,        # Low - stable organic accumulation
  "Degrading Permafrost Peatland" = 0.16,     # Low-moderate - subsidence, compaction
  "Polygon Center - Vegetated" = 0.14,        # Low - sedge/moss peat
  "Bare Mineral Tundra" = 1.20                # High - exposed mineral soil
)

# Bulk density correction factors for frozen samples
# Frozen BD includes ice - apply correction to get organic/mineral BD
BD_FROZEN_CORRECTION_ENABLED <- TRUE  # Set to TRUE to apply ground ice corrections
BD_ICE_DENSITY <- 0.92  # g/cm³ - density of ice

# ============================================================================
# QUALITY CONTROL THRESHOLDS - ARCTIC PERMAFROST ADAPTED
# ============================================================================

# Soil Organic Carbon (SOC) thresholds (g/kg)
QC_SOC_MIN <- 0        # Minimum valid SOC
QC_SOC_MAX <- 600      # Increased for Arctic peatlands (very high organic content)
QC_SOC_PERMAFROST_MAX <- 800  # Higher threshold for ancient permafrost carbon

# Bulk Density thresholds (g/cm³)
QC_BD_MIN <- 0.05      # Lower minimum for fibric peat
QC_BD_MAX <- 2.0       # Lower maximum (less compacted than coastal soils)

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH  # 300 cm for permafrost cores

# Active layer depth thresholds (cm) - site-specific QC
QC_ACTIVE_LAYER_MIN <- 20   # Minimum realistic active layer depth
QC_ACTIVE_LAYER_MAX <- 200  # Maximum realistic active layer depth (degrading permafrost)

# Ground ice content thresholds (% volume)
QC_GROUND_ICE_MIN <- 0    # Minimum ground ice content
QC_GROUND_ICE_MAX <- 90   # Maximum ground ice content (ice-rich permafrost)

# Coordinate validity (decimal degrees for WGS84)
# Arctic Canada latitude range: approximately 60°N to 83°N
QC_LON_MIN <- -180
QC_LON_MAX <- 180
QC_LAT_MIN <- 60   # Southern limit of Arctic/Subarctic Canada
QC_LAT_MAX <- 83   # Northern limit of Canadian land mass

# ============================================================================
# VM0033 SAMPLING REQUIREMENTS
# ============================================================================

# Minimum cores per stratum (VM0033 requirement)
VM0033_MIN_CORES <- 3

# Target precision (VM0033 acceptable range: 10-20% relative error at 95% CI)
VM0033_TARGET_PRECISION <- 20  # percent

# Target CV threshold (higher CV = higher uncertainty)
VM0033_CV_THRESHOLD <- 30  # percent

# Assumed CV for sample size calculation (conservative estimate)
VM0033_ASSUMED_CV <- 30  # percent

# ============================================================================
# TEMPORAL MONITORING & PERMAFROST THAW SCENARIOS
# ============================================================================

# Valid scenario types for Arctic permafrost monitoring (adapted from VM0033/VM0036)
# Core scenarios:
# - INTACT: Intact permafrost with stable active layer (reference condition)
# - BASELINE: Current permafrost condition (monitoring baseline)
# - DEGRADING: Active permafrost degradation (thawing, subsidence)
# - THERMOKARST: Advanced thermokarst features (collapsed permafrost)
# - REFERENCE: Stable natural permafrost ecosystem (upper bound)
# - CONTROL: No-intervention control site (tracks natural variation)
# Permafrost thaw trajectory scenarios:
# - THAW_Y0: Initial thaw detection
# - THAW_Y5: 5 years post-thaw initiation (first verification)
# - THAW_Y10: 10 years post-thaw (second verification)
# - THAW_Y15: 15+ years post-thaw (advanced degradation)
# - STABILIZED: Post-thaw stabilization (new equilibrium)
VALID_SCENARIOS <- c("INTACT", "BASELINE", "DEGRADING", "THERMOKARST", "REFERENCE",
                     "CONTROL", "THAW_Y0", "THAW_Y5", "THAW_Y10", "THAW_Y15",
                     "STABILIZED", "CUSTOM")

# Scenario hierarchy for modeling (relative carbon vulnerability)
# Used by Module 08A to model missing scenarios from available data
# Lower values = higher carbon stocks (intact permafrost)
# Higher values = lower carbon stocks BUT potentially higher emissions
SCENARIO_CARBON_LEVELS <- c(
  INTACT = 10.0,           # Highest carbon storage, lowest vulnerability
  REFERENCE = 10.0,        # Stable natural condition
  BASELINE = 9.0,          # Current monitored condition
  THAW_Y0 = 8.0,          # Initial thaw - carbon still stored
  DEGRADING = 7.0,        # Active degradation - some carbon loss
  THAW_Y5 = 6.0,          # 5 years thaw - moderate carbon loss
  THAW_Y10 = 5.0,         # 10 years thaw - significant loss
  THERMOKARST = 4.0,      # Advanced collapse - major carbon loss
  THAW_Y15 = 3.5,         # Advanced degradation
  STABILIZED = 3.0        # New equilibrium (lower carbon state)
)

# Permafrost vulnerability metrics
# Used for climate scenario modeling
PERMAFROST_VULNERABILITY_LEVELS <- c(
  INTACT = "low",
  BASELINE = "low-moderate",
  DEGRADING = "high",
  THERMOKARST = "very_high",
  STABILIZED = "moderate"
)

# Minimum monitoring frequency (years) - VM0033 typically requires verification every 5 years
VM0033_MONITORING_FREQUENCY <- 5

# Minimum years for temporal change analysis
MIN_YEARS_FOR_CHANGE <- 3  # At least 3 years to establish trend

# Additionality test confidence level
ADDITIONALITY_CONFIDENCE <- 0.95  # 95% CI for statistical tests

# Conservative approach for additionality calculations
ADDITIONALITY_METHOD <- "lower_bound"  # Options: "mean", "lower_bound", "conservative"
# - "mean": Use mean difference between project and baseline
# - "lower_bound": Use 95% CI lower bound of difference (most conservative, VM0033 recommended)
# - "conservative": Use mean - 1SD (moderately conservative)

# ============================================================================
# SCENARIO MODELING PARAMETERS (Module 08A) - ARCTIC PERMAFROST ADAPTED
# ============================================================================

# Enable scenario modeling (generate synthetic scenarios from reference trajectories)
SCENARIO_MODELING_ENABLED <- TRUE

# Canadian Arctic permafrost literature database
CANADIAN_LITERATURE_DB <- "canadian_arctic_permafrost_parameters.csv"

# Scenario modeling configuration file
SCENARIO_CONFIG_FILE <- "arctic_permafrost_scenario_config.csv"

# Thaw/degradation model types for permafrost trajectory modeling
# - "exponential": Fast initial thaw, slowing as new equilibrium approaches
# - "linear": Constant degradation rate (climate-driven)
# - "logistic": S-shaped curve with tipping point (common for thermokarst)
# - "threshold": Abrupt transition at critical threshold (ice-wedge collapse)
PERMAFROST_THAW_MODEL_TYPE <- "logistic"  # Most appropriate for permafrost dynamics

# Active layer deepening rate (cm/year)
# Used for temporal projections under climate change scenarios
ACTIVE_LAYER_DEEPENING_RATE <- 1.5  # cm/year (typical for moderate warming)
ACTIVE_LAYER_DEEPENING_RATE_HIGH <- 3.0  # cm/year (high warming scenario)

# Uncertainty inflation for modeled scenarios (%)
# Adds additional uncertainty to account for modeling assumptions
MODELING_UNCERTAINTY_BUFFER <- 20  # percent (higher for permafrost due to complexity)

# Spatial resolution for modeled scenario rasters (if generating spatial outputs)
MODELED_RASTER_RESOLUTION <- 30  # meters

# ============================================================================
# BAYESIAN PRIOR PARAMETERS (Part 4 - Optional)
# ============================================================================

# Enable Bayesian workflow (requires GEE prior maps)
USE_BAYESIAN <- FALSE  # Set to TRUE to enable Part 4

# Prior data directory
BAYESIAN_PRIOR_DIR <- "data_prior"

# GEE Data Sources (BC Coast)
# SoilGrids 250m - Global soil organic carbon maps
GEE_SOILGRIDS_ASSET <- "projects/soilgrids-isric/soc_mean"
GEE_SOILGRIDS_UNCERTAINTY <- "projects/soilgrids-isric/soc_uncertainty"

# Sothe et al. 2022 - BC Forest biomass and soil carbon
# Users should input their specific GEE asset paths here:
GEE_SOTHE_FOREST_BIOMASS <- ""  # User to provide
GEE_SOTHE_SOIL_CARBON <- ""     # User to provide
GEE_SOTHE_OTHER_BIOMASS <- ""   # User to provide

# Prior resolution (will be resampled to PREDICTION_RESOLUTION)
PRIOR_RESOLUTION <- 250  # meters (SoilGrids native resolution)

# Bayesian sampling design (Neyman allocation)
USE_NEYMAN_SAMPLING <- TRUE  # Enable optimal allocation based on prior uncertainty
NEYMAN_STRATA <- 3           # Number of uncertainty strata (low/med/high)
NEYMAN_BUFFER_SAMPLES <- 1.2 # Oversample by 20% to account for inaccessible locations

# Uncertainty strata thresholds (coefficient of variation %)
UNCERTAINTY_LOW_THRESHOLD <- 10    # CV < 10% = low uncertainty
UNCERTAINTY_HIGH_THRESHOLD <- 30   # CV > 30% = high uncertainty
# Medium uncertainty = between thresholds

# Bayesian posterior weighting
# How to weight prior vs field data based on sample size
BAYESIAN_WEIGHT_METHOD <- "sqrt_samples"  # Options: "sqrt_samples", "linear", "fixed"
BAYESIAN_FIXED_WEIGHT <- 0.5              # Only used if method = "fixed"
BAYESIAN_TARGET_SAMPLES <- 30             # Target sample size for full field weight

# Precision adjustment
# Inflate prior uncertainty to account for potential bias/mismatch
PRIOR_UNCERTAINTY_INFLATION <- 1.2  # Multiply prior SE by this factor (conservative)

# Information gain threshold
# Minimum posterior uncertainty reduction to declare "informative prior"
MIN_INFORMATION_GAIN_PCT <- 20  # At least 20% uncertainty reduction

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

# Interpolation method: "equal_area_spline", "smoothing_spline", "linear", "all"
INTERPOLATION_METHOD <- "equal_area_spline"  # VM0033 recommended default

# Spline smoothing parameters by core type
SPLINE_SPAR_HR <- 0.3           # Less smoothing for high-resolution cores
SPLINE_SPAR_COMPOSITE <- 0.5    # More smoothing for composite cores
SPLINE_SPAR_AUTO <- NULL        # NULL = automatic cross-validation

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- TRUE   # Allow slight SOC increases with depth (common in some ecosystems)
MAX_INCREASE_THRESHOLD <- 20    # Maximum % increase allowed between adjacent depths

# ============================================================================
# UNCERTAINTY PARAMETERS
# ============================================================================

# Confidence level for uncertainty estimation (VM0033 requires 95%)
CONFIDENCE_LEVEL <- 0.95

# Bootstrap parameters for spline uncertainty
BOOTSTRAP_ITERATIONS <- 100
BOOTSTRAP_SEED <- 42

# Cross-validation parameters
CV_FOLDS <- 3           # Number of folds for spatial CV (reduced for small datasets)
CV_SEED <- 42           # Random seed for reproducibility

# ============================================================================
# SPATIAL MODELING PARAMETERS
# ============================================================================

# Prediction resolution (meters)
KRIGING_CELL_SIZE <- 10
RF_CELL_SIZE <- 10

# Kriging parameters
KRIGING_MAX_DISTANCE <- 5000  # Maximum distance for variogram (meters)
KRIGING_CUTOFF <- NULL        # NULL = automatic
KRIGING_WIDTH <- 100          # Lag width for variogram (meters)

# Random Forest parameters
RF_NTREE <- 500              # Number of trees
RF_MTRY <- NULL              # NULL = automatic (sqrt of predictors)
RF_MIN_NODE_SIZE <- 5        # Minimum node size
RF_IMPORTANCE <- "permutation"  # Variable importance method

# ============================================================================
# AREA OF APPLICABILITY (AOA) PARAMETERS
# ============================================================================

# Enable AOA analysis (requires CAST package)
ENABLE_AOA <- TRUE

# AOA threshold (dissimilarity index)
AOA_THRESHOLD <- "default"  # "default" or numeric value

# ============================================================================
# REPORT GENERATION PARAMETERS
# ============================================================================

# Figure dimensions for saving (inches)
FIGURE_WIDTH <- 10
FIGURE_HEIGHT <- 6
FIGURE_DPI <- 300

# Table formatting
TABLE_DIGITS <- 2  # Decimal places for tables

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

#' Convert between carbon stock units
#'
#' @param value Numeric value to convert
#' @param from Source unit (kg_m2, Mg_ha, g_kg, pct)
#' @param to Target unit
#' @return Converted value
#' @examples
#' convert_units(1, "kg_m2", "Mg_ha")  # Returns 10
#' convert_units(10, "Mg_ha", "kg_m2") # Returns 1
convert_units <- function(value, from, to) {
  conversions <- list(
    "kg_m2_to_Mg_ha" = 10,
    "Mg_ha_to_kg_m2" = 0.1,
    "g_kg_to_pct" = 0.1,
    "pct_to_g_kg" = 10
  )

  key <- paste(from, "to", to, sep = "_")
  if (key %in% names(conversions)) {
    return(value * conversions[[key]])
  } else {
    stop(sprintf("Unknown conversion: %s to %s", from, to))
  }
}

# ============================================================================
# ARCTIC PERMAFROST-SPECIFIC PARAMETERS
# ============================================================================

# Permafrost monitoring variables (required for field data collection)
PERMAFROST_MONITORING_VARS <- c(
  "active_layer_depth_cm",        # Measured thaw depth (end of season)
  "permafrost_table_depth_cm",    # Depth to frozen layer
  "ground_ice_content_pct",       # Ground ice volume percentage
  "thaw_settlement_cm",           # Subsidence from ice melt
  "soil_temp_surface_C",          # Surface soil temperature
  "soil_temp_10cm_C",             # 10 cm depth temperature
  "soil_temp_50cm_C",             # 50 cm depth temperature (if accessible)
  "vegetation_type",              # Sedge/moss/shrub dominance
  "microtopography_type",         # Polygon/palsa/fen classification
  "thermokarst_feature",          # Type of thermokarst (pond/trough/etc.)
  "water_track_proximity_m"       # Distance to water track
)

# Climate and site variables
CLIMATE_MONITORING_VARS <- c(
  "mean_annual_temp_C",           # Mean annual air temperature
  "mean_annual_ground_temp_C",    # Mean annual ground temperature (MAGT)
  "thaw_degree_days",             # Cumulative thaw degree days
  "freeze_degree_days",           # Cumulative freeze degree days
  "snow_depth_cm",                # Snow depth (affects ground insulation)
  "snow_duration_days"            # Days with snow cover
)

# Verification standards for Arctic permafrost carbon
# Primary: No specific Verra methodology yet - adapted from VM0036 (peatlands)
VERIFICATION_STANDARDS <- list(
  primary = "VM0036_adapted",     # Verra VM0036 Peatlands (adapted for permafrost)
  secondary = c(
    "IPCC_Wetlands_Supplement",   # IPCC 2013 Wetlands Supplement
    "CALM_protocols",             # Circumpolar Active Layer Monitoring
    "CCIN_standards",             # Canadian Cryospheric Information Network
    "Arctic_Council_guidelines"   # Arctic Council carbon monitoring
  )
)

# Canadian Arctic data sources and networks
CANADIAN_DATA_SOURCES <- list(
  permafrost_database = "Canadian Permafrost Database (NRCan)",
  active_layer_monitoring = "CALM Network Canada (Circumpolar Active Layer Monitoring)",
  terrestrial_ecosystem = "NTED (Northern Terrestrial Ecosystem Database)",
  soil_database = "CanSIS Northern Profiles",
  permafrost_maps = "GSC Permafrost Distribution Maps",
  climate_data = "Environment Canada Arctic Climate Stations",
  remote_sensing = "NASA Carbon Monitoring System + ESA Permafrost CCI"
)

# Climate vulnerability metrics for reporting
CLIMATE_VULNERABILITY_METRICS <- list(
  permafrost_thaw_trajectory = TRUE,         # Model future thaw under climate scenarios
  vulnerable_carbon_pool = TRUE,             # Quantify top 1m of permafrost carbon
  active_layer_deepening_rate = TRUE,        # Calculate inter-annual deepening
  thermokarst_expansion_rate = TRUE,         # Track spatial expansion of thermokarst
  cmip6_comparison = TRUE                    # Compare to CMIP6 permafrost projections
)

# Depth harmonization notes for permafrost
PERMAFROST_DEPTH_HARMONIZATION_NOTES <- list(
  no_spline_through_frozen = TRUE,           # Cannot interpolate through frozen layer
  active_layer_varies_temporally = TRUE,     # Active layer depth changes year-to-year
  harmonize_active_layer_only = TRUE,        # Only harmonize within active layer
  report_permafrost_separately = TRUE,       # Report permafrost carbon as separate pool
  frozen_sample_correction = TRUE            # Apply ground ice corrections
)

# Spatial covariates for Arctic (GEE extraction)
ARCTIC_SPATIAL_COVARIATES <- c(
  "active_layer_thickness_modeled",   # From climate-based models
  "mean_annual_ground_temp",          # MAGT maps
  "permafrost_probability",           # IPA permafrost distribution
  "permafrost_extent",                # Continuous/discontinuous zones
  "terrain_ruggedness",               # TRI (affects thermokarst)
  "snow_duration",                    # Days with snow cover
  "aspect",                           # Affects thaw rates
  "ndwi",                             # Normalized difference water index
  "landform_classification",          # Polygon/palsa/fen from DEM
  "elevation",                        # Elevation above sea level
  "slope"                             # Slope gradient
)

# Special field protocols for Arctic
ARCTIC_FIELD_PROTOCOLS <- list(
  sampling_season = "late_summer",    # July-August (maximum thaw)
  frozen_core_handling = TRUE,        # Special frozen sample protocols
  active_layer_measurement = "frost_probe",  # Frost probe or thaw tube
  ground_ice_measurement = "gravimetric",    # Gravimetric method
  temporal_frequency = "annual",      # Annual monitoring for MMRV
  helicopter_access = TRUE            # Remote logistics consideration
)

# Emissions factors for permafrost thaw (optional - for full GHG accounting)
EMISSIONS_FACTORS_ENABLED <- FALSE   # Set TRUE to include CH4 and N2O
CH4_EMISSION_FACTOR_THERMOKARST <- 5.0  # g CH4-C m-2 yr-1 (thermokarst features)
CH4_GWP100 <- 28                     # Global warming potential (100-year, AR6)
N2O_GWP100 <- 265                    # Global warming potential (100-year, AR6)

# ============================================================================
# SESSION TRACKING
# ============================================================================

# Session tracking for reproducibility and unique output naming
SESSION_START <- Sys.time()
SESSION_ID <- format(SESSION_START, "%Y%m%d_%H%M%S")

# ============================================================================
# END OF CONFIGURATION
# ============================================================================

# Print confirmation when loaded
if (interactive()) {
  cat("Blue Carbon configuration loaded ✓
")
  cat(sprintf("  Project: %s
", PROJECT_NAME))
  cat(sprintf("  Location: %s
", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s
", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d
", MONITORING_YEAR))
  cat(sprintf("  Session ID: %s
", SESSION_ID))
}

