# ============================================================================
# BLUE CARBON PROJECT CONFIGURATION
# ============================================================================
# Edit these parameters for your specific project
# This file is sourced by analysis modules

# ============================================================================
# PROJECT METADATA (VM0033 Required)
# ============================================================================

PROJECT_NAME <- "BC_Coastal_BlueCarbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED
MONITORING_YEAR <- 2024

# Project location (for documentation)
PROJECT_LOCATION <- "Chemainus Estuary, British Columbia, Canada"
PROJECT_DESCRIPTION <- "Blue carbon monitoring for carbon credit development - VM0033 compliant assessment of coastal salt marsh and eelgrass restoration"

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
  "Upper Marsh",           # Infrequent flooding, salt-tolerant shrubs
  "Mid Marsh",             # Regular inundation, mixed halophytes (HIGHEST C sequestration)
  "Lower Marsh",           # Daily tides, dense Spartina (HIGHEST burial rates)
  "Underwater Vegetation", # Subtidal seagrass beds
  "Open Water"            # Tidal channels, lagoons
)

# Stratum colors for plotting (match GEE tool)
STRATUM_COLORS <- c(
  "Upper Marsh" = "#FFFF99",
  "Mid Marsh" = "#99FF99",
  "Lower Marsh" = "#33CC33",
  "Underwater Vegetation" = "#0066CC",
  "Open Water" = "#000099"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# VM0033 standard depth intervals (cm) - depth midpoints for harmonization
# These correspond to VM0033 depth layers: 0-15, 15-30, 30-50, 50-100 cm
VM0033_DEPTH_MIDPOINTS <- c(7.5, 22.5, 40, 75)

# VM0033 depth intervals (cm) - for mass-weighted aggregation
VM0033_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30, 50),
  depth_bottom = c(15, 30, 50, 100),
  depth_midpoint = c(7.5, 22.5, 40, 75),
  thickness_cm = c(15, 15, 20, 50)
)

# Standard depths for harmonization (VM0033 midpoints are default)
STANDARD_DEPTHS <- VM0033_DEPTH_MIDPOINTS

# Fine-scale depth intervals (optional, for detailed analysis)
FINE_SCALE_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100)

# Maximum core depth (cm)
MAX_CORE_DEPTH <- 100

# Key depth intervals for reporting (cm)
REPORTING_DEPTHS <- list(
  surface = c(0, 30),      # Top 30 cm (most active layer)
  subsurface = c(30, 100)  # 30-100 cm (long-term storage)
)

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
# Values in g/cm³ based on literature for BC coastal ecosystems

BD_DEFAULTS <- list(
  "Upper Marsh" = 0.8,              # Lower density, more organic matter
  "Mid Marsh" = 1.0,                # Moderate density
  "Lower Marsh" = 1.2,              # Higher density, more mineral content
  "Underwater Vegetation" = 0.6,    # Lowest density, high organic content
  "Open Water" = 1.0                # Moderate, mostly mineral
)

# ============================================================================
# QUALITY CONTROL THRESHOLDS
# ============================================================================

# Soil Organic Carbon (SOC) thresholds (g/kg)
QC_SOC_MIN <- 0      # Minimum valid SOC
QC_SOC_MAX <- 500    # Maximum valid SOC (adjust for your ecosystem)

# Bulk Density thresholds (g/cm³)
QC_BD_MIN <- 0.1     # Minimum valid bulk density
QC_BD_MAX <- 3.0     # Maximum valid bulk density

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH

# Coordinate validity (decimal degrees for WGS84)
QC_LON_MIN <- -180
QC_LON_MAX <- 180
QC_LAT_MIN <- -90
QC_LAT_MAX <- 90

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
# TEMPORAL MONITORING & ADDITIONALITY PARAMETERS
# ============================================================================

# Valid scenario types for VM0033 (expanded for restoration chronosequence)
# Core scenarios:
# - BASELINE: Pre-restoration or current degraded condition (t0)
# - DEGRADED: Heavily degraded/lost ecosystem (lower bound)
# - DISTURBED: Moderately impacted ecosystem
# - REFERENCE: Natural healthy ecosystem (upper bound target)
# - CONTROL: No-intervention control site (tracks natural variation)
# Restoration trajectory scenarios:
# - PROJECT_Y0: Immediately post-restoration
# - PROJECT_Y1: 1 year post-restoration
# - PROJECT_Y5: 5 years post-restoration (VM0033 first verification)
# - PROJECT_Y10: 10 years post-restoration (VM0033 second verification)
# - PROJECT_Y15: 15+ years post-restoration
# - PROJECT: Generic project scenario (when year not specified)
VALID_SCENARIOS <- c("BASELINE", "DEGRADED", "DISTURBED", "REFERENCE", "CONTROL",
                     "PROJECT", "PROJECT_Y0", "PROJECT_Y1", "PROJECT_Y5",
                     "PROJECT_Y10", "PROJECT_Y15", "CUSTOM")

# Scenario hierarchy for modeling (relative carbon stock levels)
# Used by Module 08A to model missing scenarios from available data
SCENARIO_CARBON_LEVELS <- c(
  DEGRADED = 1.0,
  DISTURBED = 2.0,
  BASELINE = 3.0,
  PROJECT_Y0 = 3.0,
  PROJECT_Y1 = 4.0,
  PROJECT_Y5 = 6.0,
  PROJECT_Y10 = 8.0,
  PROJECT_Y15 = 9.5,
  REFERENCE = 10.0
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
# SCENARIO MODELING PARAMETERS (Module 08A)
# ============================================================================

# Enable scenario modeling (generate synthetic scenarios from reference trajectories)
SCENARIO_MODELING_ENABLED <- TRUE

# Canadian literature database for BC Coast ecosystems
CANADIAN_LITERATURE_DB <- "canadian_bluecarbon_parameters.csv"

# Scenario modeling configuration file
SCENARIO_CONFIG_FILE <- "scenario_modeling_config.csv"

# Recovery model types for reference trajectory method
# - "exponential": Fast initial recovery, slowing over time (most common)
# - "linear": Constant accumulation rate
# - "logistic": S-shaped curve with inflection point
# - "asymptotic": Approaches target asymptotically
RECOVERY_MODEL_TYPE <- "exponential"

# Uncertainty inflation for modeled scenarios (%)
# Adds additional uncertainty to account for modeling assumptions
MODELING_UNCERTAINTY_BUFFER <- 10  # percent

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
# DOWNSTREAM IMPACT MODELING PARAMETERS (Part 5 - Optional)
# ============================================================================

# Enable downstream impact modeling
ENABLE_DOWNSTREAM_IMPACTS <- FALSE  # Set to TRUE to enable Part 5

# Priority impacts to model (set to TRUE to enable each)
IMPACTS_ENABLED <- list(
  nutrient_loads = TRUE,        # Nitrogen and phosphorus export
  sediment_loads = TRUE,        # Sediment and turbidity reduction
  peak_flow = TRUE,             # Flood mitigation
  baseflow = TRUE,              # Groundwater recharge / dry-season flows
  contaminants = FALSE,         # Heavy metals, PFAS (if data available)
  habitat_connectivity = TRUE,  # Biodiversity spillover
  ecosystem_services = TRUE     # Aggregated co-benefits valuation
)

# Hydrological modeling approach
HYDRO_MODEL_TYPE <- "semi_empirical"  # Options: "semi_empirical" (NDR/RUSLE), "process_based" (SWAT), "hybrid"

# Points of Interest (POI) - downstream receptors to assess
# Users should create data_raw/poi/points_of_interest.csv with columns:
# poi_id, poi_name, longitude, latitude, receptor_type, priority
POI_FILE <- "data_raw/poi/points_of_interest.csv"

# Receptor types for prioritization
RECEPTOR_TYPES <- c(
  "community_water_intake",
  "fish_habitat",
  "shellfish_area",
  "recreation_site",
  "agricultural_intake",
  "drinking_water_source"
)

# ============================================================================
# SEDIMENT MODELING (RUSLE-based)
# ============================================================================

# RUSLE parameters - Revised Universal Soil Loss Equation
RUSLE_ENABLED <- TRUE

# Rainfall erosivity factor (R) - MJ mm/(ha h yr)
# For BC Coast, typical range: 300-800
# Can be calculated from CHIRPS/ERA5 precipitation data
RUSLE_R_DEFAULT <- 500  # Conservative estimate for BC coastal

# Soil erodibility (K factor) by stratum - Mg ha h/(ha MJ mm)
# Values from literature for coastal wetland soils
RUSLE_K_FACTORS <- list(
  "Upper Marsh" = 0.15,              # Lower erodibility, vegetated
  "Mid Marsh" = 0.20,                # Moderate erodibility
  "Lower Marsh" = 0.25,              # Higher erodibility, tidal action
  "Underwater Vegetation" = 0.10,    # Low erodibility, stabilized
  "Open Water" = 0.30                # High erodibility, unvegetated
)

# Cover-management factor (C) - dimensionless (0-1)
# Pre-restoration vs Post-restoration scenarios
RUSLE_C_FACTORS <- data.frame(
  stratum = c("Upper Marsh", "Mid Marsh", "Lower Marsh", "Underwater Vegetation", "Open Water"),
  baseline = c(0.30, 0.35, 0.40, 0.20, 0.80),      # Degraded condition
  project_y0 = c(0.25, 0.30, 0.35, 0.15, 0.70),    # Immediate post-restoration
  project_y5 = c(0.10, 0.12, 0.15, 0.08, 0.50),    # 5 years post-restoration
  project_y10 = c(0.05, 0.08, 0.10, 0.05, 0.30)    # Mature restoration
)

# Support practice factor (P) - dimensionless (0-1)
RUSLE_P_DEFAULT <- 1.0  # No mechanical erosion control (natural wetlands)

# Sediment delivery ratio approach
SEDIMENT_DELIVERY_METHOD <- "ndr"  # Options: "ndr" (nutrient delivery ratio), "distance_decay", "icm"

# NDR calibration parameters
NDR_K <- 2.0          # Calibration parameter (typical range: 1-3)
NDR_IC0 <- 0.5        # Connectivity index threshold
NDR_MAX_DISTANCE <- 5000  # Maximum travel distance (m)

# ============================================================================
# NUTRIENT MODELING (Export coefficient + NDR)
# ============================================================================

# Nutrient export coefficients by landcover (kg/ha/yr)
# Sources: Canadian literature, IPCC Wetlands Supplement
NUTRIENT_EXPORT_COEFFICIENTS <- data.frame(
  stratum = c("Upper Marsh", "Mid Marsh", "Lower Marsh", "Underwater Vegetation", "Open Water"),
  # Nitrogen export (kg N/ha/yr)
  n_baseline = c(8.0, 10.0, 12.0, 6.0, 15.0),
  n_project = c(3.0, 4.0, 5.0, 2.0, 8.0),
  # Phosphorus export (kg P/ha/yr)
  p_baseline = c(1.2, 1.5, 1.8, 0.8, 2.5),
  p_project = c(0.4, 0.5, 0.6, 0.3, 1.0)
)

# Nutrient retention efficiency by stratum (%)
# How much nutrient is retained vs. exported downstream
NUTRIENT_RETENTION <- data.frame(
  stratum = c("Upper Marsh", "Mid Marsh", "Lower Marsh", "Underwater Vegetation", "Open Water"),
  n_retention_pct = c(60, 70, 65, 80, 20),  # N retention
  p_retention_pct = c(70, 80, 75, 85, 30)   # P retention
)

# ============================================================================
# HYDROLOGICAL MODELING (Curve Number Method)
# ============================================================================

# Curve Number (CN) by stratum and hydrologic soil group
# For coastal wetlands, typically group C or D (slow infiltration)
# CN values: 0-100 (higher = more runoff)
CURVE_NUMBERS <- data.frame(
  stratum = c("Upper Marsh", "Mid Marsh", "Lower Marsh", "Underwater Vegetation", "Open Water"),
  cn_baseline = c(85, 88, 90, 92, 98),   # Degraded condition (higher runoff)
  cn_project = c(75, 78, 80, 85, 98)     # Restored condition (better infiltration)
)

# Hydrologic soil group distribution (if not mapped)
DEFAULT_HSG <- "C"  # Options: A, B, C, D

# ============================================================================
# FLOW ROUTING & CATCHMENT DELINEATION
# ============================================================================

# DEM source and resolution
DEM_SOURCE <- "SRTM"  # Options: "SRTM" (30m), "ALOS" (12.5m), "LIDAR" (1-5m custom)
DEM_RESOLUTION <- 30  # meters

# Flow direction algorithm
FLOW_DIR_METHOD <- "D8"  # Options: "D8" (single flow), "D-infinity" (multiple flow), "MFD"

# Minimum catchment area for stream initiation (hectares)
STREAM_THRESHOLD_HA <- 5

# Depression filling approach
FILL_DEPRESSIONS <- TRUE  # TRUE = fill sinks, FALSE = breach depressions

# ============================================================================
# CAUSAL INFERENCE & ATTRIBUTION (BACI / Synthetic Control)
# ============================================================================

# Enable empirical attribution analysis
ENABLE_CAUSAL_INFERENCE <- TRUE

# BACI design parameters
BACI_ENABLED <- TRUE
BACI_CONTROL_BUFFER <- 2000  # Minimum distance for control sites (m)
BACI_BEFORE_YEARS <- 3       # Minimum years before intervention
BACI_AFTER_YEARS <- 3        # Minimum years after intervention

# Synthetic control parameters
SYNTHETIC_CONTROL_ENABLED <- TRUE
SYNTH_DONOR_POOL_MIN <- 10   # Minimum number of control pixels/sites
SYNTH_MATCH_COVARIATES <- c("elevation", "slope", "ndvi", "distance_to_water")

# Matching approach for difference-in-differences
MATCHING_METHOD <- "propensity_score"  # Options: "exact", "propensity_score", "genetic"
MATCHING_CALIPER <- 0.2  # Maximum difference for matching (in standard deviations)

# ============================================================================
# HABITAT CONNECTIVITY & BIODIVERSITY
# ============================================================================

# Enable habitat connectivity analysis
ENABLE_CONNECTIVITY <- TRUE

# Connectivity model type
CONNECTIVITY_MODEL <- "graph"  # Options: "graph" (network analysis), "circuitscape" (resistance), "least_cost"

# Target species/guilds for connectivity analysis
FOCAL_SPECIES <- c(
  "salmon",           # Anadromous fish (requires riparian corridors)
  "shorebirds",       # Migratory birds (requires intertidal habitat)
  "pollinators",      # Insects (requires floral resources)
  "marsh_specialists" # Resident marsh birds (requires emergent vegetation)
)

# Dispersal distances by species (meters)
DISPERSAL_DISTANCES <- list(
  salmon = 50000,           # Long-distance migrants
  shorebirds = 10000,       # Regional movement
  pollinators = 500,        # Local dispersal
  marsh_specialists = 2000  # Medium-range dispersal
)

# Habitat quality thresholds (NDVI or custom habitat suitability index)
HABITAT_QUALITY_MIN <- 0.4  # Minimum NDVI for suitable habitat

# Resistance values by landcover (for circuit theory / least-cost path)
RESISTANCE_VALUES <- data.frame(
  stratum = c("Upper Marsh", "Mid Marsh", "Lower Marsh", "Underwater Vegetation", "Open Water"),
  salmon = c(10, 5, 1, 1, 1),              # Low resistance in aquatic habitats
  shorebirds = c(5, 3, 1, 8, 10),          # Prefer intertidal zones
  pollinators = c(1, 2, 5, 10, 10),        # Prefer upland marsh
  marsh_specialists = c(3, 1, 2, 8, 10)    # Prefer emergent vegetation
)

# ============================================================================
# ECOSYSTEM SERVICE VALUATION (Co-benefits)
# ============================================================================

# Enable economic valuation of co-benefits
ENABLE_VALUATION <- TRUE

# Unit values for avoided costs / benefits (CAD$ per unit per year)
ECOSYSTEM_SERVICE_VALUES <- list(
  # Water quality
  sediment_reduction_per_tonne = 50,        # Avoided dredging/treatment costs ($/tonne)
  nitrogen_reduction_per_kg = 15,           # Avoided eutrophication damage ($/kg N)
  phosphorus_reduction_per_kg = 50,         # Avoided eutrophication damage ($/kg P)

  # Flood mitigation
  flood_damage_avoided_per_m3 = 2.5,        # Avoided flood damage ($/m³ peak flow reduced)

  # Fisheries
  salmon_habitat_value_per_ha = 5000,       # Enhanced fish habitat ($/ha/yr)
  shellfish_value_per_ha = 8000,            # Shellfish growing area ($/ha/yr)

  # Recreation
  recreation_value_per_ha = 500,            # Recreation/tourism ($/ha/yr)

  # Biodiversity (non-use value)
  biodiversity_value_per_ha = 300           # Existence/bequest value ($/ha/yr)
)

# Discount rate for multi-year benefits (%)
DISCOUNT_RATE <- 0.03  # 3% (standard for environmental projects)

# Time horizon for benefit accounting (years)
VALUATION_HORIZON <- 30  # VM0033 project crediting period

# ============================================================================
# UNCERTAINTY PROPAGATION
# ============================================================================

# Monte Carlo simulation parameters
MC_ITERATIONS <- 1000  # Number of Monte Carlo runs
MC_SEED <- 42          # Random seed for reproducibility

# Parameter uncertainty distributions
# For each parameter, specify distribution type and parameters
UNCERTAINTY_DISTRIBUTIONS <- list(
  # RUSLE R factor: normal distribution (mean, sd)
  rusle_r = list(type = "normal", mean = 500, sd = 100),

  # Sediment delivery ratio: beta distribution (shape1, shape2)
  delivery_ratio = list(type = "beta", shape1 = 2, shape2 = 5),

  # Nutrient export coefficients: lognormal (meanlog, sdlog)
  nutrient_export = list(type = "lognormal", meanlog = 0, sdlog = 0.3),

  # Curve number: normal with bounds [40, 98]
  curve_number = list(type = "normal_bounded", mean = 85, sd = 5, min = 40, max = 98)
)

# Sensitivity analysis - which parameters to vary
SENSITIVITY_PARAMS <- c(
  "rusle_r", "rusle_k", "rusle_c", "delivery_ratio",
  "nutrient_export_n", "nutrient_export_p",
  "curve_number", "retention_efficiency"
)

# Confidence intervals to report
CI_LEVELS <- c(0.50, 0.80, 0.95)  # 50%, 80%, 95% confidence intervals

# ============================================================================
# REPORTING & VISUALIZATION
# ============================================================================

# Impact metrics to include in summary report
REPORT_METRICS <- c(
  "sediment_load_reduction_t_yr",
  "nitrogen_load_reduction_kg_yr",
  "phosphorus_load_reduction_kg_yr",
  "peak_flow_reduction_m3_s",
  "baseflow_increase_m3_s",
  "habitat_area_improved_ha",
  "connectivity_index_change",
  "total_cobenefits_value_cad"
)

# Spatial output resolution for maps (meters)
OUTPUT_MAP_RESOLUTION <- 30

# Export formats
EXPORT_FORMATS <- c("csv", "xlsx", "geotiff", "shapefile", "html")

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

