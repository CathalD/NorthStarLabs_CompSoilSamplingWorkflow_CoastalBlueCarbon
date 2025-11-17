# ============================================================================
# CANADIAN PEATLAND CARBON ASSESSMENT CONFIGURATION
# ============================================================================
# Edit these parameters for your specific project
# This file is sourced by analysis modules

# ============================================================================
# PROJECT METADATA (VM0036 & CaMP Framework Compatible)
# ============================================================================

PROJECT_NAME <- "Canadian_Peatland_Carbon_2024"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED, RESTORED
MONITORING_YEAR <- 2024

# Project location (for documentation)
PROJECT_LOCATION <- "Canadian Boreal/Temperate Region"
PROJECT_DESCRIPTION <- "Peatland carbon stock assessment and restoration verification - VM0036 (Rewetting Drained Temperate Peatlands) compliant assessment for carbon credit development and peatland restoration MRV"

# ============================================================================
# ECOSYSTEM STRATIFICATION
# ============================================================================

# Valid ecosystem strata (must match GEE stratification tool)
#
# PEATLAND & WETLAND CLASSIFICATION:
#   Based on Canadian Wetland Classification System (CWCS) and
#   Environment and Climate Change Canada (ECCC) classification
#
# FILE NAMING CONVENTION:
#   Module 05 auto-detects GEE stratum masks using this pattern:
#   "Stratum Name" → stratum_name.tif in data_raw/gee_strata/
#
# Examples:
#   "Ombrotrophic Bog"  → ombrotrophic_bog.tif
#   "Minerotrophic Fen" → minerotrophic_fen.tif
#   "Treed Peatland"    → treed_peatland.tif
#
# CUSTOMIZATION OPTIONS:
#   1. Simple: Edit VALID_STRATA below and export GEE masks with matching names
#   2. Advanced: Create stratum_definitions.csv in project root for custom file names
#      and optional metadata (see stratum_definitions_EXAMPLE.csv template)
#
# See README section "Customizing Ecosystem Strata" for full details.
#
VALID_STRATA <- c(
  "Ombrotrophic Bog",      # Rain-fed, Sphagnum-dominated, acidic (pH 3.5-4.5), HIGH C stocks
  "Minerotrophic Fen",     # Groundwater-fed, sedge/brown moss, neutral pH, MODERATE C stocks
  "Treed Peatland",        # Black spruce/tamarack on peat, variable water table
  "Marsh",                 # Mineral wetland, emergent vegetation, seasonally flooded
  "Swamp",                 # Wooded wetland, mineral or shallow peat, periodic flooding
  "Restored Peatland",     # Rewetted, recovering vegetation and hydrology
  "Drained Peatland"       # Degraded baseline, lowered water table, oxidizing peat
)

# Stratum colors for plotting (match GEE tool)
STRATUM_COLORS <- c(
  "Ombrotrophic Bog" = "#8B4513",       # Brown (peat)
  "Minerotrophic Fen" = "#9ACD32",      # Yellow-green (sedges)
  "Treed Peatland" = "#228B22",         # Forest green
  "Marsh" = "#87CEEB",                  # Sky blue
  "Swamp" = "#2F4F4F",                  # Dark slate (wooded wetland)
  "Restored Peatland" = "#98FB98",      # Pale green (recovering)
  "Drained Peatland" = "#CD853F"        # Peru (degraded)
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# PEATLAND DEPTH INTERVALS (CaMP & VM0036 Framework)
# Peatlands require deeper sampling to capture full peat profile (often 2-5+ meters)
#
# Key peat layers:
#   - Acrotelm (0-30 cm): Active layer, aerobic, high decomposition, living roots
#   - Catotelm (30+ cm): Permanently saturated, anaerobic, slow decomposition, long-term C storage
#
# Standard depth midpoints for harmonization (peatland-specific)
STANDARD_DEPTHS <- c(15, 50, 100, 150, 200, 250)  # Midpoints in cm

# Peatland depth intervals (cm) - for mass-weighted aggregation
# Based on CaMP (Canadian Model for Peatlands) and VM0036 guidance
PEATLAND_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 30, 100, 200),
  depth_bottom = c(30, 100, 200, 300),
  depth_midpoint = c(15, 65, 150, 250),
  thickness_cm = c(30, 70, 100, 100),
  layer_name = c("Acrotelm (Active)", "Shallow Catotelm", "Deep Catotelm", "Very Deep Peat")
)

# VM0036 standard depth intervals (for verification compatibility)
# VM0036 uses 0-30 cm and 30-100 cm for GHG emission calculations
VM0036_DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 30),
  depth_bottom = c(30, 100),
  depth_midpoint = c(15, 65),
  thickness_cm = c(30, 70)
)

# Fine-scale depth intervals (optional, for detailed stratigraphy)
FINE_SCALE_DEPTHS <- c(0, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 125, 150, 175, 200, 250, 300)

# Maximum core depth (cm) - typically depth to mineral soil for peatlands
MAX_CORE_DEPTH <- 300

# Key depth intervals for reporting (cm)
REPORTING_DEPTHS <- list(
  acrotelm = c(0, 30),         # Active layer (aerobic, high turnover)
  shallow_catotelm = c(30, 100),   # Upper permanent saturated zone (VM0036 key layer)
  deep_catotelm = c(100, 200),     # Deep peat storage
  very_deep = c(200, 300),         # Very deep peat (if present)
  full_profile = c(0, 300)         # Total peat depth to mineral soil
)

# ============================================================================
# COORDINATE SYSTEMS
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# Default for pan-Canadian projects:
PROCESSING_CRS <- 3347  # EPSG:3347 - Canada Albers Equal Area (recommended for national-scale)

# Provincial/Regional alternatives:
#   - 3005:  EPSG:3005 (NAD83 / BC Albers) - British Columbia
#   - 2958:  EPSG:2958 (NAD83 / Alberta 10-TM) - Alberta
#   - 2957:  EPSG:2957 (NAD83 / Alberta 3TM) - Alberta (alternative)
#   - 32618: EPSG:32618 (WGS 84 / UTM zone 18N) - Eastern Canada (ON/QC)
#   - 32619: EPSG:32619 (WGS 84 / UTM zone 19N) - Eastern Canada (Atlantic)
#   - 32620: EPSG:32620 (WGS 84 / UTM zone 20N) - Eastern Canada (NL)
#   - 3978:  EPSG:3978 (NAD83 / Canada Atlas Lambert) - National mapping

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Use these when bulk density is not measured
# Values in g/cm³ based on Canadian peatland literature (CaMP, PERG database)
#
# IMPORTANT: Peat has MUCH LOWER bulk density than mineral soil (0.05-0.6 g/cm³)
# BD typically increases with depth due to compression and decomposition
#
# Peat classification by von Post scale:
#   - Fibric (H1-H4): 0.05-0.12 g/cm³ (little decomposed, identifiable plant remains)
#   - Hemic (H5-H6): 0.10-0.18 g/cm³ (moderately decomposed)
#   - Sapric (H7-H10): 0.15-0.30 g/cm³ (highly decomposed, amorphous)

BD_DEFAULTS <- list(
  "Ombrotrophic Bog" = 0.08,        # Fibric Sphagnum peat, very low density
  "Minerotrophic Fen" = 0.12,       # Hemic sedge peat, moderate decomposition
  "Treed Peatland" = 0.15,          # Mixed fibric-hemic with woody debris
  "Marsh" = 0.40,                   # Mineral wetland soil, higher density
  "Swamp" = 0.50,                   # Mineral or shallow peat, high density
  "Restored Peatland" = 0.10,       # Recovering peat, variable decomposition
  "Drained Peatland" = 0.20         # Compacted, oxidized peat (degraded)
)

# Depth-dependent bulk density adjustment (optional)
# Peat BD typically increases ~0.01-0.02 g/cm³ per meter depth
BD_DEPTH_GRADIENT <- 0.015  # g/cm³ per 100 cm depth (conservative estimate)

# ============================================================================
# QUALITY CONTROL THRESHOLDS
# ============================================================================

# PEATLAND-SPECIFIC QC THRESHOLDS
# Organic soils (peat) are defined as >17% organic matter (≈100 g/kg SOC)
# Canadian peatlands typically have 300-550 g/kg SOC (30-55% organic carbon)

# Soil Organic Carbon (SOC) thresholds (g/kg)
QC_SOC_MIN <- 100    # Minimum for organic soil classification (approx. 17% OM)
QC_SOC_MAX <- 600    # Maximum realistic SOC for peat (allow up to 60% carbon)
QC_SOC_MIN_PEAT <- 150  # Minimum for true peat (conservative threshold)
QC_SOC_TYPICAL_PEAT <- c(300, 550)  # Typical range for Canadian peat

# Bulk Density thresholds (g/cm³) - PEATLAND-SPECIFIC
QC_BD_MIN <- 0.05    # Minimum valid bulk density (fibric Sphagnum peat)
QC_BD_MAX <- 0.60    # Maximum valid bulk density for peat (sapric/compacted)
QC_BD_MINERAL_MIN <- 0.60  # If BD > 0.6, likely mineral soil (flagged for review)

# Depth thresholds (cm)
QC_DEPTH_MIN <- 0
QC_DEPTH_MAX <- MAX_CORE_DEPTH  # 300 cm for peatlands

# Peat depth to mineral soil (cm)
QC_MIN_PEAT_DEPTH <- 40   # Minimum depth to qualify as peatland (Canadian standard)
QC_TYPICAL_PEAT_DEPTH <- c(100, 300)  # Typical peat depth range

# pH thresholds (peatland-specific)
QC_PH_MIN <- 3.0     # Extremely acidic bog lower limit
QC_PH_MAX <- 8.0     # Rich fen upper limit
QC_PH_BOG <- c(3.5, 4.5)      # Typical bog range (ombrotrophic)
QC_PH_FEN <- c(5.0, 7.5)      # Typical fen range (minerotrophic)

# Water table depth (cm below surface, negative = above surface)
QC_WT_MIN <- -50     # Water table above surface (flooded)
QC_WT_MAX <- 200     # Deep water table (heavily drained)
QC_WT_INTACT <- c(-10, 10)    # Intact peatland range (at or near surface)
QC_WT_DEGRADED <- c(30, 100)  # Drained peatland threshold

# von Post humification scale (H1-H10)
QC_VON_POST_MIN <- 1   # H1 (undecomposed)
QC_VON_POST_MAX <- 10  # H10 (completely decomposed)

# Coordinate validity (decimal degrees for WGS84)
# Canada latitudes: ~42°N to 83°N, Longitudes: ~-141°W to -52°W
QC_LON_MIN <- -145
QC_LON_MAX <- -50
QC_LAT_MIN <- 40
QC_LAT_MAX <- 85

# ============================================================================
# VM0036 SAMPLING REQUIREMENTS & CANADIAN PEATLAND MRV STANDARDS
# ============================================================================
# VM0036: Methodology for Rewetting Drained Temperate Peatlands (Verra)
# Applicable to Canadian boreal and temperate peatland restoration/rewetting projects
#
# Also aligned with:
# - CaMP (Canadian Model for Peatlands) - NRCan framework
# - IPCC 2013 Wetlands Supplement
# - Environment and Climate Change Canada (ECCC) protocols

# Minimum cores per stratum (VM0036 requirement)
VM0036_MIN_CORES <- 5  # Minimum 5 cores per stratum (more stringent than VM0033)

# Target precision (VM0036 acceptable range: 10-20% relative error at 95% CI)
VM0036_TARGET_PRECISION <- 15  # percent (more stringent for peatlands)

# Target CV threshold (peatlands can have high spatial variability)
VM0036_CV_THRESHOLD <- 40  # percent (allow higher CV for heterogeneous peatlands)

# Assumed CV for sample size calculation (conservative estimate)
VM0036_ASSUMED_CV <- 35  # percent (peatlands typically more variable than coastal)

# Monitoring frequency (years)
VM0036_MONITORING_FREQUENCY <- 5  # Verify every 5 years post-restoration

# Stratification requirements
VM0036_MIN_AREA_FOR_STRATUM <- 0.5  # hectares (minimum area to justify separate stratum)

# Water table monitoring requirements (critical for peatland MRV)
VM0036_WT_MONITORING_POINTS <- 3    # Minimum water table monitoring points per stratum
VM0036_WT_MONITORING_FREQ <- 12     # Monthly monitoring (12 times per year)
VM0036_WT_REWETTING_TARGET <- 10    # Target: water table within 10 cm of surface

# ============================================================================
# TEMPORAL MONITORING & ADDITIONALITY PARAMETERS
# ============================================================================

# Valid scenario types for VM0036 (peatland restoration/rewetting trajectory)
# Core scenarios:
# - BASELINE: Pre-restoration or current drained condition (with-project scenario)
# - DEGRADED: Heavily drained/extracted peatland (lower bound)
# - DRAINED: Actively drained peatland (baseline scenario for VM0036)
# - INTACT: Natural pristine peatland (reference condition)
# - REFERENCE: Healthy peatland ecosystem (upper bound target)
# - CONTROL: No-intervention control site (tracks natural variation)
# Restoration/rewetting trajectory scenarios:
# - PROJECT_Y0: Immediately post-rewetting (ditches blocked/filled)
# - PROJECT_Y1: 1 year post-rewetting
# - PROJECT_Y5: 5 years post-rewetting (VM0036 first verification)
# - PROJECT_Y10: 10 years post-rewetting (VM0036 second verification)
# - PROJECT_Y20: 20+ years post-rewetting (mature restored peatland)
# - PROJECT: Generic project scenario (when year not specified)
VALID_SCENARIOS <- c("BASELINE", "DEGRADED", "DRAINED", "INTACT", "REFERENCE", "CONTROL",
                     "PROJECT", "PROJECT_Y0", "PROJECT_Y1", "PROJECT_Y5",
                     "PROJECT_Y10", "PROJECT_Y20", "CUSTOM")

# Scenario hierarchy for modeling (relative carbon stock levels)
# Used by Module 08A to model missing scenarios from available data
# Note: Peatland carbon stocks change slowly; restoration focuses on stopping losses
#       and recovering water table rather than rapid C accumulation
SCENARIO_CARBON_LEVELS <- c(
  DEGRADED = 5.0,      # Heavily drained/extracted, significant C loss
  DRAINED = 6.5,       # Actively drained baseline (ongoing oxidation)
  BASELINE = 6.5,      # Same as drained
  PROJECT_Y0 = 6.5,    # Immediately post-rewetting (no stock change yet)
  PROJECT_Y1 = 7.0,    # 1 year: oxidation slows, water table rising
  PROJECT_Y5 = 8.0,    # 5 years: reduced emissions, vegetation recovery
  PROJECT_Y10 = 9.0,   # 10 years: approaching intact condition
  PROJECT_Y20 = 9.8,   # 20+ years: near-intact carbon balance
  INTACT = 10.0,       # Pristine peatland (reference)
  REFERENCE = 10.0     # Same as intact
)

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

# Canadian peatland literature database (CaMP, PERG, published studies)
CANADIAN_LITERATURE_DB <- "canadian_peatland_parameters.csv"

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
  cat("Canadian Peatland Carbon Assessment configuration loaded ✓
")
  cat(sprintf("  Project: %s
", PROJECT_NAME))
  cat(sprintf("  Location: %s
", PROJECT_LOCATION))
  cat(sprintf("  Scenario: %s
", PROJECT_SCENARIO))
  cat(sprintf("  Monitoring year: %d
", MONITORING_YEAR))
  cat(sprintf("  Framework: VM0036 (Peatland Rewetting) + CaMP
"))
  cat(sprintf("  Session ID: %s
", SESSION_ID))
}

