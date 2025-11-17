# ============================================================================
# FOREST ECOSYSTEM PARAMETERS
# ============================================================================
# Ecosystem: Boreal, temperate, coastal rainforests
# Standards: VCS VM0012, VM0042, IPCC AFOLU Guidelines
# Geographic Focus: Forest lands (adaptable globally)
# Carbon Pools: Soil organic carbon (LFH + 0-30 cm mineral soil)
# ============================================================================

# ============================================================================
# ECOSYSTEM METADATA
# ============================================================================

ECOSYSTEM_NAME <- "Forests"
ECOSYSTEM_DESCRIPTION <- "Boreal, temperate, and coastal forest ecosystems"
ECOSYSTEM_STANDARDS <- c("VM0012", "VM0042", "IPCC_AFOLU", "CFI")

# ============================================================================
# STRATIFICATION
# ============================================================================

# Valid ecosystem strata
VALID_STRATA <- c(
  "Boreal Spruce",      # Black/white spruce dominated
  "Coastal Rainforest", # High biomass, temperate rainforest
  "Mixedwood",          # Mixed conifer-deciduous
  "Aspen-Dominated",    # Deciduous dominated
  "Pine-Dominated",     # Lodgepole/jack pine
  "Recently Harvested", # Post-harvest regeneration
  "Old Growth"          # Mature, undisturbed forest
)

# Stratum colors for plotting
STRATUM_COLORS <- c(
  "Boreal Spruce" = "#1B5E20",
  "Coastal Rainforest" = "#004D40",
  "Mixedwood" = "#558B2F",
  "Aspen-Dominated" = "#9CCC65",
  "Pine-Dominated" = "#33691E",
  "Recently Harvested" = "#FFA726",
  "Old Growth" = "#1A237E"
)

# Stratum descriptions
STRATUM_DESCRIPTIONS <- c(
  "Boreal Spruce" = "Black or white spruce dominated boreal forest",
  "Coastal Rainforest" = "High biomass temperate rainforest",
  "Mixedwood" = "Mixed conifer and deciduous forest",
  "Aspen-Dominated" = "Deciduous aspen-dominated stands",
  "Pine-Dominated" = "Lodgepole or jack pine dominated",
  "Recently Harvested" = "Recently harvested or disturbed areas",
  "Old Growth" = "Mature, undisturbed old-growth forest"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# Forest-specific depth intervals (cm)
# Includes organic (LFH) layer + mineral soil
DEPTH_INTERVALS <- data.frame(
  depth_top = c(-5, 0, 15),      # -5 to 0 is LFH layer (negative = above mineral soil)
  depth_bottom = c(0, 15, 30),
  depth_midpoint = c(-2.5, 7.5, 22.5),
  thickness_cm = c(5, 15, 15),
  layer_name = c("LFH Organic", "Surface Mineral", "Subsurface Mineral")
)

# Depth midpoints for harmonization
STANDARD_DEPTHS <- c(-2.5, 7.5, 22.5)  # LFH, 0-15cm, 15-30cm

# Maximum core depth (mineral soil only)
MAX_CORE_DEPTH <- 30

# Key depth intervals for reporting
REPORTING_DEPTHS <- list(
  organic = c(-5, 0),    # LFH layer
  mineral = c(0, 30)     # Mineral soil
)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Values in g/cm³ - forests typically have lower BD than blue carbon

BD_DEFAULTS <- list(
  "Boreal Spruce" = 0.6,      # Low BD, high organic matter
  "Coastal Rainforest" = 0.7,
  "Mixedwood" = 0.8,
  "Aspen-Dominated" = 0.9,
  "Pine-Dominated" = 0.75,
  "Recently Harvested" = 1.0,  # More compacted
  "Old Growth" = 0.5           # Very high organic content
)

# Bulk density valid ranges
BD_MIN <- 0.1
BD_MAX <- 2.0  # Lower max than blue carbon

# ============================================================================
# SOIL ORGANIC CARBON RANGES
# ============================================================================

# SOC thresholds (g/kg)
SOC_MIN <- 0
SOC_MAX <- 300  # Forests typically lower than coastal wetlands

# Expected SOC ranges by stratum (g/kg)
SOC_EXPECTED_RANGES <- list(
  "Boreal Spruce" = c(30, 150),
  "Coastal Rainforest" = c(40, 180),
  "Mixedwood" = c(25, 120),
  "Aspen-Dominated" = c(20, 100),
  "Pine-Dominated" = c(15, 90),
  "Recently Harvested" = c(10, 80),
  "Old Growth" = c(50, 200)
)

# ============================================================================
# CARBON FRACTION VALUES
# ============================================================================

# Default carbon fraction (if SOC not directly measured)
# Forests: organic matter to carbon conversion
CARBON_FRACTION_DEFAULT <- 0.5  # 50% of organic matter is carbon (IPCC default)

# ============================================================================
# STANDARDS COMPLIANCE
# ============================================================================

# VM0012/VM0042 requirements
VM0012_MIN_PLOTS <- 3           # Minimum plots per stratum
VM0012_TARGET_PRECISION <- 20   # percent
VM0012_CV_THRESHOLD <- 30       # percent
VM0012_ASSUMED_CV <- 40         # Higher variability in forests
VM0012_MONITORING_FREQUENCY <- 5  # years

# Alias for compatibility with main workflow
VM0033_MIN_CORES <- VM0012_MIN_PLOTS
VM0033_TARGET_PRECISION <- VM0012_TARGET_PRECISION
VM0033_CV_THRESHOLD <- VM0012_CV_THRESHOLD
VM0033_ASSUMED_CV <- VM0012_ASSUMED_CV
VM0033_MONITORING_FREQUENCY <- VM0012_MONITORING_FREQUENCY

# ============================================================================
# EMISSION FACTORS (for flux calculations)
# ============================================================================

# N2O emission factors by stratum (kg N2O-N ha⁻¹ yr⁻¹)
N2O_EMISSION_FACTORS <- list(
  "Boreal Spruce" = 0.3,
  "Coastal Rainforest" = 0.5,
  "Mixedwood" = 0.4,
  "Aspen-Dominated" = 0.6,
  "Pine-Dominated" = 0.3,
  "Recently Harvested" = 0.8,
  "Old Growth" = 0.2
)

# Soil respiration rates (kg CO2-C ha⁻¹ yr⁻¹)
SOIL_RESPIRATION_RATES <- list(
  "Boreal Spruce" = 2000,
  "Coastal Rainforest" = 3500,
  "Mixedwood" = 2800,
  "Aspen-Dominated" = 3000,
  "Pine-Dominated" = 2200,
  "Recently Harvested" = 1500,
  "Old Growth" = 2500
)

# CH4 uptake (negative = sink) (kg CH4-C ha⁻¹ yr⁻¹)
CH4_EMISSION_FACTORS <- list(
  "Boreal Spruce" = -2,
  "Coastal Rainforest" = -3,
  "Mixedwood" = -2.5,
  "Aspen-Dominated" = -2,
  "Pine-Dominated" = -1.5,
  "Recently Harvested" = -1,
  "Old Growth" = -2
)

# ============================================================================
# UNCERTAINTY ASSUMPTIONS
# ============================================================================

# Measurement uncertainty (%)
MEASUREMENT_UNCERTAINTY_SOC <- 5
MEASUREMENT_UNCERTAINTY_BD <- 15    # Higher for forest soils (coarse fragments)
MEASUREMENT_UNCERTAINTY_DEPTH <- 3

# Spatial uncertainty inflation factor
SPATIAL_UNCERTAINTY_FACTOR <- 1.5  # Higher spatial variability than blue carbon

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

# Interpolation method
INTERPOLATION_METHOD <- "equal_area_spline"

# Spline smoothing parameters
SPLINE_SPAR_HR <- 0.4           # More smoothing for forest soils
SPLINE_SPAR_COMPOSITE <- 0.6
SPLINE_SPAR_AUTO <- NULL

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- FALSE  # SOC should decrease with depth in forests
MAX_INCREASE_THRESHOLD <- 10    # Stricter than blue carbon

# ============================================================================
# MONITORING FREQUENCY
# ============================================================================

MONITORING_FREQUENCY_BASELINE <- 1
MONITORING_FREQUENCY_VERIFICATION <- 5
MONITORING_FREQUENCY_RESEARCH <- 1

# ============================================================================
# ECOSYSTEM-SPECIFIC NOTES
# ============================================================================

ECOSYSTEM_NOTES <- "
Forest soil carbon characteristics:
  - Distinct organic (LFH) and mineral soil layers
  - Carbon decreases with depth (unlike some blue carbon systems)
  - Coarse fragments can be significant (adjust for volume)
  - Root biomass contribution important
  - Lower bulk density than mineral soils
  - High spatial variability (topography, tree species effects)

Key considerations:
  - Separate LFH and mineral soil in sampling and analysis
  - Account for coarse fragment content (>2mm)
  - Consider tree species effects on soil properties
  - Sample depth typically shallower (0-30cm) than blue carbon
  - Fire history and disturbance regime important
"

# ============================================================================
# LITERATURE REFERENCES
# ============================================================================

ECOSYSTEM_REFERENCES <- list(
  methodology = "VCS VM0012 - Improved Forest Management",
  guidance = "IPCC 2006 AFOLU Guidelines",
  canadian = "Canadian Forest Inventory - NFI Protocols",
  research = "Soil Carbon in Canadian Forests (Natural Resources Canada)"
)
