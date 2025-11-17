# ============================================================================
# CANADIAN FOREST CARBON PROJECT CONFIGURATION
# ============================================================================
# Edit these parameters for your specific project
# This file is sourced by analysis modules
# Adapted from coastal blue carbon workflow for forest carbon accounting

# ============================================================================
# PROJECT METADATA
# ============================================================================

PROJECT_NAME <- "Canadian_Forest_Carbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED, HARVESTED, REGENERATING, AFFORESTATION
MONITORING_YEAR <- 2024

# Project location (for documentation)
PROJECT_LOCATION <- "British Columbia, Canada"
PROJECT_DESCRIPTION <- "Forest soil carbon monitoring for improved forest management and afforestation verification. Compliant with VCS VM0012 (IFM), VM0042 (ARR), Canadian Forest Service Carbon Accounting Framework, and IPCC Guidelines for National GHG Inventories (AFOLU)"

# ============================================================================
# ECOSYSTEM STRATIFICATION
# ============================================================================

# Valid forest strata (must match forest inventory classification)
#
# FILE NAMING CONVENTION:
#   Module 05 auto-detects GEE stratum masks using this pattern:
#   "Stratum Name" → stratum_name.tif in data_raw/gee_strata/
#
# Examples:
#   "Boreal Black Spruce"   → boreal_black_spruce.tif
#   "Temperate Conifer"     → temperate_conifer.tif
#   "Coastal Rainforest"    → coastal_rainforest.tif
#
# CUSTOMIZATION OPTIONS:
#   1. Simple: Edit VALID_STRATA below and export GEE masks with matching names
#   2. Advanced: Create stratum_definitions.csv in project root for custom file names
#      and optional metadata (see stratum_definitions_EXAMPLE.csv template)
#
# See README section "Customizing Ecosystem Strata" for full details.
#
VALID_STRATA <- c(
  "Boreal Black Spruce",    # Organic-rich soils, slow decomposition, permafrost influence
  "Boreal Mixedwood",       # Aspen-white spruce mix, moderate SOC
  "Temperate Conifer",      # Douglas-fir, western hemlock, cedar (high productivity)
  "Temperate Deciduous",    # Sugar maple, oak, basswood (nutrient-rich soils)
  "Coastal Rainforest",     # Very high SOC, wet climate, thick LFH layers
  "Recently Harvested",     # <10 years post-harvest, soil compaction effects
  "Regenerating Forest",    # 10-40 years post-disturbance, rebuilding carbon stocks
  "Afforestation Site"      # Formerly non-forest (agriculture/grassland), low initial SOC
)

# Stratum colors for plotting (forestry palette)
STRATUM_COLORS <- c(
  "Boreal Black Spruce" = "#1a472a",     # Dark green
  "Boreal Mixedwood" = "#98d98e",        # Light green-yellow
  "Temperate Conifer" = "#2d6a4f",       # Forest green
  "Temperate Deciduous" = "#95d5b2",     # Pale green
  "Coastal Rainforest" = "#081c15",      # Very dark green
  "Recently Harvested" = "#d4a373",      # Brown
  "Regenerating Forest" = "#b5e48c",     # Young green
  "Afforestation Site" = "#f4e285"       # Pale yellow
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# FOREST SOIL DEPTH INTERVALS
# Forest soils are reported in two components:
#   1. LFH layer (organic forest floor) - measured separately
#   2. Mineral soil (0-100 cm) - standard depth intervals

# LFH Layer Configuration (organic forest floor)
# L = Litter layer (fresh, recognizable organic matter)
# F = Fermentation layer (partially decomposed)
# H = Humus layer (well-decomposed, dark organic matter)
MEASURE_LFH_LAYER <- TRUE  # Set to FALSE if only measuring mineral soil
LFH_MAX_THICKNESS <- 50    # Maximum expected LFH thickness (cm) - adjust for ecosystem

# Standard depth intervals for MINERAL SOIL (cm)
# Based on Canadian Forest Service and IPCC forest soil guidelines
# Midpoints represent the center of each depth interval
STANDARD_DEPTH_MIDPOINTS <- c(7.5, 22.5, 40, 75)

# Standard depth intervals (cm) - for mass-weighted aggregation
STANDARD_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30, 50),
  depth_bottom = c(15, 30, 50, 100),
  depth_midpoint = c(7.5, 22.5, 40, 75),
  thickness_cm = c(15, 15, 20, 50),
  horizon = c("A", "A/B", "B", "B/C")  # Typical soil horizons
)

# Standard depths for harmonization
STANDARD_DEPTHS <- STANDARD_DEPTH_MIDPOINTS

# Fine-scale depth intervals (optional, for detailed analysis)
FINE_SCALE_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100)

# Maximum mineral soil core depth (cm)
MAX_CORE_DEPTH <- 100

# Key depth intervals for reporting (cm)
REPORTING_DEPTHS <- list(
  lfh_layer = c(NA, NA),        # Measured separately (variable thickness)
  surface_mineral = c(0, 30),   # Top 30 cm mineral soil (most active layer)
  subsurface_mineral = c(30, 100) # 30-100 cm mineral soil (long-term storage)
)

# Depth intervals aligned with Canadian Forest Inventory reporting
# Standard: 0-15, 15-30, 30-50, 50-100 cm mineral + LFH layer
CFI_REPORTING_DEPTHS <- c(15, 30, 50, 100)

# ============================================================================
# COORDINATE SYSTEMS
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# Change this for your region:
PROCESSING_CRS <- 3347 # Canada Albers Equal Area (good for all Canada)
# Other options:
#   - 3005:  EPSG:3005 (NAD83 / BC Albers) - OPTIMIZED FOR BC
#   - 3347: Canada Albers Equal Area (good for all Canada)
#   - 32610: WGS 84 / UTM zone 10N (BC coast - Chemainus area)
#   - 32611: WGS 84 / UTM zone 11N (BC interior)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Use these when bulk density is not measured
# Values in g/cm³ based on Canadian Forest Service data and literature

# MINERAL SOIL bulk density defaults (g/cm³)
BD_DEFAULTS <- list(
  "Boreal Black Spruce" = 0.7,      # Organic-rich soils, high water table
  "Boreal Mixedwood" = 0.9,         # Moderate organic content
  "Temperate Conifer" = 1.0,        # Well-drained, moderate density
  "Temperate Deciduous" = 1.1,      # Higher mineralization, nutrient cycling
  "Coastal Rainforest" = 0.8,       # High precipitation, thick organic layers
  "Recently Harvested" = 1.3,       # Soil compaction from machinery
  "Regenerating Forest" = 1.1,      # Recovering from disturbance
  "Afforestation Site" = 1.2        # Former agricultural soil (compacted)
)

# LFH LAYER bulk density defaults (g/cm³)
# Separate from mineral soil - measured by volume-based sampling
LFH_BD_DEFAULTS <- list(
  L_layer = 0.08,   # Fresh litter (needles, leaves)
  F_layer = 0.15,   # Partially decomposed
  H_layer = 0.25,   # Well-decomposed humus
  LFH_composite = 0.15  # Average for undifferentiated LFH sampling
)

# Stratum-specific LFH bulk density (if available from regional studies)
LFH_BD_BY_STRATUM <- list(
  "Boreal Black Spruce" = 0.12,     # Very low decomposition rate
  "Boreal Mixedwood" = 0.15,        # Moderate
  "Temperate Conifer" = 0.18,       # Faster decomposition
  "Temperate Deciduous" = 0.22,     # High nutrient cycling
  "Coastal Rainforest" = 0.20,      # Thick but well-decomposed
  "Recently Harvested" = 0.10,      # Sparse, disturbed
  "Regenerating Forest" = 0.14,     # Accumulating
  "Afforestation Site" = 0.08       # Minimal forest floor
)

# ============================================================================
# QUALITY CONTROL THRESHOLDS
# ============================================================================

# MINERAL SOIL Organic Carbon (SOC) thresholds (g/kg)
QC_SOC_MIN <- 10     # Minimum valid SOC for mineral forest soils
QC_SOC_MAX <- 200    # Maximum valid SOC for mineral soils (higher values indicate organic horizon)

# LFH LAYER Organic Carbon thresholds (g/kg)
QC_LFH_SOC_MIN <- 250   # Minimum SOC for organic forest floor
QC_LFH_SOC_MAX <- 550   # Maximum SOC for LFH layer

# MINERAL SOIL Bulk Density thresholds (g/cm³)
QC_BD_MIN <- 0.4     # Minimum valid bulk density (very organic-rich mineral soils)
QC_BD_MAX <- 1.5     # Maximum valid bulk density (compacted or sandy soils)

# LFH LAYER Bulk Density thresholds (g/cm³)
QC_LFH_BD_MIN <- 0.05   # Minimum LFH bulk density (fresh litter)
QC_LFH_BD_MAX <- 0.50   # Maximum LFH bulk density (well-decomposed humus)

# Coarse Fragment Content thresholds (% volume >2mm)
QC_COARSE_FRAG_MIN <- 0     # Minimum coarse fragment content
QC_COARSE_FRAG_MAX <- 80    # Maximum coarse fragment content (very rocky soils)

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH

# LFH Layer thickness thresholds (cm)
QC_LFH_THICKNESS_MIN <- 0.5   # Minimum measurable LFH thickness
QC_LFH_THICKNESS_MAX <- 50    # Maximum expected LFH thickness

# Coordinate validity for Canada (decimal degrees WGS84)
QC_LON_MIN <- -141   # Western Canada (Yukon border)
QC_LON_MAX <- -52    # Eastern Canada (Newfoundland)
QC_LAT_MIN <- 41     # Southern Canada (Lake Erie)
QC_LAT_MAX <- 83     # Northern Canada (High Arctic)

# ============================================================================
# FOREST CARBON SAMPLING REQUIREMENTS
# ============================================================================
# Based on VCS VM0012 (IFM), VM0042 (A/R), IPCC Guidelines, and Canadian protocols

# Minimum cores per stratum
# VM0012/VM0042 and Canadian protocols typically require more samples than VM0033
# due to higher spatial variability in forest soils
FOREST_MIN_CORES <- 5  # Minimum per stratum (increased from wetland standard)

# Target precision (acceptable range: 10-20% relative error at 95% CI)
# IPCC Good Practice Guidance recommends ≤20% for Tier 3 methods
FOREST_TARGET_PRECISION <- 15  # percent (stricter than wetlands due to credit value)

# Target CV threshold (higher CV = higher uncertainty)
# Forest soils typically show CV of 20-50% depending on disturbance history
FOREST_CV_THRESHOLD <- 40  # percent (higher than wetlands due to natural variability)

# Assumed CV for sample size calculation (conservative estimate)
# Used when planning sampling design without prior data
FOREST_ASSUMED_CV <- 35  # percent

# Monitoring frequency (years between verifications)
# VM0012: Every 5 years during first 20 years, then every 10 years
# VM0042: Every 5 years until crediting period end
FOREST_MONITORING_FREQUENCY <- 5  # years

# Additional forest-specific requirements
FOREST_MIN_PLOTS_PER_PROJECT <- 15  # Minimum total plots across all strata
FOREST_SPATIAL_DISTRIBUTION_REQUIREMENT <- "systematic"  # or "random", "stratified_random"

# ============================================================================
# TEMPORAL MONITORING & ADDITIONALITY PARAMETERS
# ============================================================================

# Valid scenario types for forest carbon projects
# Core scenarios:
# - BASELINE: Business-as-usual forest management (conventional harvest)
# - DEGRADED: Recently harvested or severely disturbed
# - REFERENCE: Old-growth or undisturbed mature forest (upper bound)
# - CONTROL: Control plots (similar conditions, no intervention)
#
# Improved Forest Management (IFM) scenarios:
# - IFM_EXTENDED_ROTATION: Longer rotation periods
# - IFM_REDUCED_IMPACT: Reduced-impact logging practices
# - IFM_NO_HARVEST: Conversion to protected area
#
# Afforestation/Reforestation (A/R) trajectory scenarios:
# - AR_Y0: Immediately post-planting (former agricultural/grassland)
# - AR_Y5: 5 years post-planting (establishment phase)
# - AR_Y10: 10 years (early growth)
# - AR_Y20: 20 years (canopy closure, significant SOC accumulation)
# - AR_Y40: 40+ years (approaching mature forest conditions)
#
# Post-harvest recovery:
# - HARVEST_Y0: Immediately post-harvest
# - REGEN_Y5: 5 years regeneration
# - REGEN_Y10: 10 years regeneration
# - REGEN_Y20: 20 years regeneration
#
VALID_SCENARIOS <- c("BASELINE", "DEGRADED", "REFERENCE", "CONTROL",
                     "IFM_EXTENDED_ROTATION", "IFM_REDUCED_IMPACT", "IFM_NO_HARVEST",
                     "AR_Y0", "AR_Y5", "AR_Y10", "AR_Y20", "AR_Y40",
                     "HARVEST_Y0", "REGEN_Y5", "REGEN_Y10", "REGEN_Y20",
                     "PROJECT", "CUSTOM")

# Scenario hierarchy for modeling (relative carbon stock levels)
# Used by Module 08A to model missing scenarios from available data
# Scale: 1.0 (lowest SOC) to 10.0 (highest SOC - old-growth reference)
SCENARIO_CARBON_LEVELS <- c(
  DEGRADED = 1.0,
  HARVEST_Y0 = 1.5,
  AR_Y0 = 2.0,
  BASELINE = 4.0,
  AR_Y5 = 3.0,
  REGEN_Y5 = 3.5,
  AR_Y10 = 4.5,
  REGEN_Y10 = 5.0,
  IFM_EXTENDED_ROTATION = 6.0,
  AR_Y20 = 6.5,
  REGEN_Y20 = 7.0,
  IFM_REDUCED_IMPACT = 7.5,
  AR_Y40 = 8.5,
  IFM_NO_HARVEST = 9.0,
  REFERENCE = 10.0
)

# Minimum years for temporal change analysis
MIN_YEARS_FOR_CHANGE <- 5  # Forest SOC changes are slower than wetlands

# Additionality test confidence level
ADDITIONALITY_CONFIDENCE <- 0.95  # 95% CI for statistical tests

# Conservative approach for additionality calculations
ADDITIONALITY_METHOD <- "lower_bound"  # Options: "mean", "lower_bound", "conservative"
# - "mean": Use mean difference between project and baseline
# - "lower_bound": Use 95% CI lower bound of difference (most conservative, VCS recommended)
# - "conservative": Use mean - 1SD (moderately conservative)

# ============================================================================
# SCENARIO MODELING PARAMETERS (Module 08A)
# ============================================================================

# Enable scenario modeling (generate synthetic scenarios from reference trajectories)
SCENARIO_MODELING_ENABLED <- TRUE

# Canadian forest carbon literature database
# Contains reference values from CBM-CFS3, NFI, and published studies
CANADIAN_LITERATURE_DB <- "canadian_forest_carbon_parameters.csv"

# Scenario modeling configuration file
SCENARIO_CONFIG_FILE <- "scenario_modeling_config.csv"

# Recovery/accumulation model types for forest trajectory modeling
# - "exponential": Fast initial accumulation, asymptotic approach (common for A/R)
# - "linear": Constant accumulation rate (simplified IFM)
# - "logistic": S-shaped curve with inflection point (realistic for forest growth)
# - "asymptotic": Approaches reference condition asymptotically
# - "cbm_based": Use CBM-CFS3 growth curves if available
RECOVERY_MODEL_TYPE <- "logistic"  # Logistic is most realistic for forest SOC

# Uncertainty inflation for modeled scenarios (%)
# Adds additional uncertainty to account for modeling assumptions
# Forest systems have higher uncertainty than wetlands due to disturbance variability
MODELING_UNCERTAINTY_BUFFER <- 15  # percent (increased from wetland default)

# Spatial resolution for modeled scenario rasters (if generating spatial outputs)
# Aligned with Canadian Forest Inventory pixel size
MODELED_RASTER_RESOLUTION <- 30  # meters (Landsat-based forest inventory)

# ============================================================================
# BAYESIAN PRIOR PARAMETERS (Part 4 - Optional)
# ============================================================================

# Enable Bayesian workflow (requires GEE prior maps)
USE_BAYESIAN <- FALSE  # Set to TRUE to enable Part 4

# Prior data directory
BAYESIAN_PRIOR_DIR <- "data_prior"

# GEE Data Sources for Canadian Forests
# SoilGrids 250m - Global soil organic carbon maps (0-100 cm depth intervals)
GEE_SOILGRIDS_ASSET <- "projects/soilgrids-isric/soc_mean"
GEE_SOILGRIDS_UNCERTAINTY <- "projects/soilgrids-isric/soc_uncertainty"

# Sothe et al. 2022 - BC Forest biomass and soil carbon maps (30m resolution)
# Published GEE assets for BC forests
GEE_SOTHE_FOREST_BIOMASS <- "projects/sat-io/open-datasets/CA_FOREST_BIOMASS_2020/AGB"
GEE_SOTHE_SOIL_CARBON <- "projects/sat-io/open-datasets/CA_FOREST_BIOMASS_2020/SOC"
GEE_SOTHE_OTHER_BIOMASS <- "projects/sat-io/open-datasets/CA_FOREST_BIOMASS_2020/BGB"

# Canadian National Forest Inventory (NFI) - if available as GEE asset
GEE_NFI_SOIL_CARBON <- ""  # User to provide if available

# CanSIS (Canadian Soil Information Service) - if available as GEE asset
GEE_CANSIS_SOC <- ""  # User to provide if available

# Prior resolution (will be resampled to PREDICTION_RESOLUTION)
PRIOR_RESOLUTION <- 30  # meters (Sothe et al. 2022 native resolution for BC forests)

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
  cat("Canadian Forest Carbon configuration loaded ✓
")
  cat(sprintf("  Project: %s
", PROJECT_NAME))
  cat(sprintf("  Location: %s
", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s
", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d
", MONITORING_YEAR))
  cat(sprintf("  Forest strata defined: %d
", length(VALID_STRATA)))
  cat(sprintf("  LFH layer measurement: %s
", ifelse(MEASURE_LFH_LAYER, "ENABLED", "DISABLED")))
  cat(sprintf("  Session ID: %s
", SESSION_ID))
}

