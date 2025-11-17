# ============================================================================
# ARCTIC / SUBARCTIC ECOSYSTEM PARAMETERS
# ============================================================================
# Ecosystem: Tundra, permafrost wetlands, boreal peatlands
# Standards: Adapted VM0036, IPCC Wetlands Supplement, Permafrost Carbon Network
# Geographic Focus: Arctic and subarctic regions with permafrost
# Carbon Pools: Active layer + permafrost organic carbon (0-100+ cm)
# ============================================================================

# ============================================================================
# ECOSYSTEM METADATA
# ============================================================================

ECOSYSTEM_NAME <- "Arctic and Subarctic"
ECOSYSTEM_DESCRIPTION <- "Tundra, permafrost wetlands, and ice-affected ecosystems"
ECOSYSTEM_STANDARDS <- c("VM0036_Adapted", "IPCC_Wetlands", "Permafrost_Carbon_Network")

# ============================================================================
# STRATIFICATION
# ============================================================================

# Valid ecosystem strata
VALID_STRATA <- c(
  "Polygonal Tundra",      # Ice-wedge polygon complexes
  "Palsa",                 # Permafrost peat mounds
  "Thermokarst Fen",       # Thawed/subsided areas
  "Tussock Tundra",        # Sedge tussock-dominated
  "Shrub Tundra",          # Increasing shrub cover
  "Wet Sedge Tundra",      # Low-lying saturated areas
  "Continuous Permafrost", # Deep permafrost
  "Discontinuous Permafrost" # Patchy permafrost
)

# Stratum colors for plotting
STRATUM_COLORS <- c(
  "Polygonal Tundra" = "#E1F5FE",
  "Palsa" = "#B3E5FC",
  "Thermokarst Fen" = "#81D4FA",
  "Tussock Tundra" = "#4FC3F7",
  "Shrub Tundra" = "#29B6F6",
  "Wet Sedge Tundra" = "#03A9F4",
  "Continuous Permafrost" = "#0288D1",
  "Discontinuous Permafrost" = "#0277BD"
)

# Stratum descriptions
STRATUM_DESCRIPTIONS <- c(
  "Polygonal Tundra" = "Ice-wedge polygon terrain",
  "Palsa" = "Permafrost peat mounds elevated above wetlands",
  "Thermokarst Fen" = "Thawed and subsided permafrost wetlands",
  "Tussock Tundra" = "Sedge tussock-dominated tundra",
  "Shrub Tundra" = "Shrub-expanding tundra (climate-driven)",
  "Wet Sedge Tundra" = "Saturated low-lying tundra",
  "Continuous Permafrost" = "Deep continuous permafrost zone",
  "Discontinuous Permafrost" = "Patchy discontinuous permafrost"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# Arctic-specific depth intervals (cm)
# Divided by active layer and permafrost boundary
DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 50),
  depth_bottom = c(15, 50, 100),
  depth_midpoint = c(7.5, 32.5, 75),
  thickness_cm = c(15, 35, 50),
  layer_name = c("Active Layer Surface", "Active Layer Deep", "Permafrost Transition")
)

# Depth midpoints for harmonization
STANDARD_DEPTHS <- c(7.5, 32.5, 75)

# Maximum core depth (limited by permafrost)
MAX_CORE_DEPTH <- 100  # Often cannot sample deeper due to ice

# Active layer depth (highly variable, measured separately)
TYPICAL_ACTIVE_LAYER_DEPTH <- 50  # cm (highly site-specific)

# Key depth intervals for reporting
REPORTING_DEPTHS <- list(
  active_layer = c(0, 50),          # Above permafrost (thaws seasonally)
  permafrost_transition = c(50, 100), # Transition zone
  permafrost = c(100, 300)          # Permanently frozen (if accessible)
)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Values in g/cm³ - Arctic soils variable (mineral vs. organic)

BD_DEFAULTS <- list(
  "Polygonal Tundra" = 0.8,          # Mixed organic-mineral
  "Palsa" = 0.15,                    # Low, peat-dominated
  "Thermokarst Fen" = 0.12,          # Very low, waterlogged peat
  "Tussock Tundra" = 0.6,            # Moderate, organic-rich
  "Shrub Tundra" = 0.7,
  "Wet Sedge Tundra" = 0.5,
  "Continuous Permafrost" = 0.9,     # More mineral
  "Discontinuous Permafrost" = 0.8
)

# Bulk density valid ranges
BD_MIN <- 0.05  # Very low for organic tundra soils
BD_MAX <- 2.0   # High for mineral tundra soils

# ============================================================================
# SOIL ORGANIC CARBON RANGES
# ============================================================================

# SOC thresholds (g/kg)
SOC_MIN <- 0
SOC_MAX <- 550  # Can be very high in peat-dominated areas

# Expected SOC ranges by stratum (g/kg)
SOC_EXPECTED_RANGES <- list(
  "Polygonal Tundra" = c(50, 250),
  "Palsa" = c(300, 500),             # High, peat
  "Thermokarst Fen" = c(350, 550),   # Very high
  "Tussock Tundra" = c(100, 300),
  "Shrub Tundra" = c(80, 250),
  "Wet Sedge Tundra" = c(150, 400),
  "Continuous Permafrost" = c(30, 200),
  "Discontinuous Permafrost" = c(40, 220)
)

# ============================================================================
# PERMAFROST PARAMETERS
# ============================================================================

# Active layer depth ranges by stratum (cm)
ACTIVE_LAYER_DEPTH <- list(
  "Polygonal Tundra" = c(30, 60),
  "Palsa" = c(40, 70),
  "Thermokarst Fen" = c(60, 100),    # Deeper, thawing
  "Tussock Tundra" = c(35, 65),
  "Shrub Tundra" = c(40, 80),        # Deepening with shrubs
  "Wet Sedge Tundra" = c(25, 50),
  "Continuous Permafrost" = c(25, 50),
  "Discontinuous Permafrost" = c(50, 100)
)

# Permafrost classification
PERMAFROST_ZONES <- c(
  "Continuous" = ">90% permafrost coverage",
  "Discontinuous" = "50-90% coverage",
  "Sporadic" = "10-50% coverage",
  "Isolated" = "<10% coverage"
)

# Ground ice content (% by volume)
GROUND_ICE_CONTENT <- list(
  "Polygonal Tundra" = 30,
  "Palsa" = 20,
  "Thermokarst Fen" = 10,  # Ice has melted
  "Tussock Tundra" = 25,
  "Shrub Tundra" = 20,
  "Wet Sedge Tundra" = 15,
  "Continuous Permafrost" = 40,
  "Discontinuous Permafrost" = 25
)

# ============================================================================
# CARBON FRACTION VALUES
# ============================================================================

# Default carbon fraction
CARBON_FRACTION_DEFAULT <- 0.50

# ============================================================================
# STANDARDS COMPLIANCE
# ============================================================================

# Adapted VM0036 requirements (no formal Arctic protocol yet)
VM0036_MIN_PLOTS <- 4               # Higher due to spatial variability
VM0036_TARGET_PRECISION <- 25       # Relaxed due to high variability
VM0036_CV_THRESHOLD <- 40           # Higher variability expected
VM0036_ASSUMED_CV <- 50             # Very high spatial variability
VM0036_MONITORING_FREQUENCY <- 3    # More frequent due to rapid changes

# Alias for compatibility
VM0033_MIN_CORES <- VM0036_MIN_PLOTS
VM0033_TARGET_PRECISION <- VM0036_TARGET_PRECISION
VM0033_CV_THRESHOLD <- VM0036_CV_THRESHOLD
VM0033_ASSUMED_CV <- VM0036_ASSUMED_CV
VM0033_MONITORING_FREQUENCY <- VM0036_MONITORING_FREQUENCY

# ============================================================================
# EMISSION FACTORS (for flux calculations)
# ============================================================================

# CO2 emission factors by stratum (kg CO2-C ha⁻¹ yr⁻¹)
# Highly dependent on thaw status
CO2_EMISSION_FACTORS <- list(
  "Polygonal Tundra" = -30,          # Small sink
  "Palsa" = -40,                     # Sink when frozen
  "Thermokarst Fen" = 50,            # SOURCE when thawed
  "Tussock Tundra" = -20,
  "Shrub Tundra" = -25,
  "Wet Sedge Tundra" = 0,
  "Continuous Permafrost" = -35,
  "Discontinuous Permafrost" = -10
)

# CH4 emission factors by stratum (kg CH4-C ha⁻¹ yr⁻¹)
# Arctic wetlands are major methane sources
CH4_EMISSION_FACTORS <- list(
  "Polygonal Tundra" = 15,
  "Palsa" = 5,                       # Low, drier
  "Thermokarst Fen" = 60,            # VERY HIGH when thawed
  "Tussock Tundra" = 10,
  "Shrub Tundra" = 8,
  "Wet Sedge Tundra" = 40,
  "Continuous Permafrost" = 12,
  "Discontinuous Permafrost" = 20
)

# N2O emission factors (kg N2O-N ha⁻¹ yr⁻¹)
# Generally low in Arctic
N2O_EMISSION_FACTORS <- list(
  "Polygonal Tundra" = 0.1,
  "Palsa" = 0.05,
  "Thermokarst Fen" = 0.3,
  "Tussock Tundra" = 0.1,
  "Shrub Tundra" = 0.15,
  "Wet Sedge Tundra" = 0.2,
  "Continuous Permafrost" = 0.05,
  "Discontinuous Permafrost" = 0.1
)

# ============================================================================
# CLIMATE PARAMETERS
# ============================================================================

# Thawing degree days (TDD) - affects active layer depth
TDD_TYPICAL <- 800  # degree-days above 0°C

# Freezing degree days (FDD)
FDD_TYPICAL <- 3500  # degree-days below 0°C

# Mean annual air temperature (°C)
MAAT_TYPICAL <- -8

# ============================================================================
# UNCERTAINTY ASSUMPTIONS
# ============================================================================

# Measurement uncertainty (%)
MEASUREMENT_UNCERTAINTY_SOC <- 15   # Higher due to ice, sampling difficulty
MEASUREMENT_UNCERTAINTY_BD <- 25    # Very difficult with ice
MEASUREMENT_UNCERTAINTY_DEPTH <- 10 # Active layer highly variable

# Spatial uncertainty inflation factor
SPATIAL_UNCERTAINTY_FACTOR <- 1.8   # Very high spatial variability

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

# Interpolation method
INTERPOLATION_METHOD <- "equal_area_spline"

# Spline smoothing parameters
SPLINE_SPAR_HR <- 0.4
SPLINE_SPAR_COMPOSITE <- 0.6
SPLINE_SPAR_AUTO <- NULL

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- TRUE   # Complex depth profiles
MAX_INCREASE_THRESHOLD <- 40    # High variability

# ============================================================================
# MONITORING FREQUENCY
# ============================================================================

MONITORING_FREQUENCY_BASELINE <- 1  # Annual due to rapid changes
MONITORING_FREQUENCY_VERIFICATION <- 3  # Every 3 years (faster than other ecosystems)
MONITORING_FREQUENCY_RESEARCH <- 1

# Active layer monitoring frequency (per year)
ACTIVE_LAYER_MONITORING_FREQUENCY <- 4  # Quarterly or seasonal

# ============================================================================
# ECOSYSTEM-SPECIFIC NOTES
# ============================================================================

ECOSYSTEM_NOTES <- "
Arctic/Subarctic carbon characteristics:
  - Enormous carbon stocks (especially in permafrost)
  - Active layer (seasonal thaw) vs. permafrost (permanently frozen)
  - Permafrost thaw releases ancient carbon (climate feedback)
  - Very high spatial variability (microtopography effects)
  - Extreme seasonal dynamics
  - Difficult field access (short field season, remote)
  - Ground ice complicates sampling and carbon accounting
  - Thermokarst = catastrophic carbon release

Key considerations:
  - Measure active layer depth at each sample point
  - Document ground ice content (affects carbon stocks)
  - Sample in late summer (maximum thaw)
  - Use thawing degree days to predict active layer depth
  - Account for both CO2 and CH4 (CH4 radiative forcing important)
  - Monitor permafrost thaw progression
  - Consider abrupt thaw (thermokarst) vs. gradual thaw
  - Specialized coring equipment needed for frozen soils
  - Climate change impacts are rapid and severe
"

# ============================================================================
# LITERATURE REFERENCES
# ============================================================================

ECOSYSTEM_REFERENCES <- list(
  methodology = "VCS VM0036 adapted for permafrost systems",
  guidance = "IPCC 2013 Wetlands Supplement Chapter 7 - Rewetted organic soils",
  network = "Permafrost Carbon Network - Data Synthesis",
  canadian = "Canadian Cryospheric Information Network (CCIN)",
  technical = "Hugelius et al. (2014) - Northern Circumpolar Soil Carbon Database"
)
