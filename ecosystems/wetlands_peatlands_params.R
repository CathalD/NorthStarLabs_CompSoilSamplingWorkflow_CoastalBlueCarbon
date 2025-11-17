# ============================================================================
# WETLANDS / PEATLANDS ECOSYSTEM PARAMETERS
# ============================================================================
# Ecosystem: Bogs, fens, swamps, marshes (non-tidal freshwater)
# Standards: VCS VM0036, IPCC Wetlands Supplement
# Geographic Focus: Freshwater wetlands and peatlands
# Carbon Pools: Peat organic carbon (0-300 cm depth - much deeper than other ecosystems)
# ============================================================================

# ============================================================================
# ECOSYSTEM METADATA
# ============================================================================

ECOSYSTEM_NAME <- "Wetlands and Peatlands"
ECOSYSTEM_DESCRIPTION <- "Bogs, fens, swamps, and freshwater marshes"
ECOSYSTEM_STANDARDS <- c("VM0036", "IPCC_Wetlands", "Canadian_Peatland_Protocol")

# ============================================================================
# STRATIFICATION
# ============================================================================

# Valid ecosystem strata
VALID_STRATA <- c(
  "Ombrotrophic Bog",     # Rain-fed, acidic, Sphagnum-dominated
  "Minerotrophic Fen",    # Groundwater-fed, less acidic
  "Treed Peatland",       # Forested bog or fen
  "Poor Fen",             # Low nutrient availability
  "Rich Fen",             # High nutrient availability
  "Swamp",                # Mineral wetland with trees/shrubs
  "Marsh"                 # Emergent vegetation, shallow water
)

# Stratum colors for plotting
STRATUM_COLORS <- c(
  "Ombrotrophic Bog" = "#6D4C41",
  "Minerotrophic Fen" = "#A1887F",
  "Treed Peatland" = "#4E342E",
  "Poor Fen" = "#8D6E63",
  "Rich Fen" = "#BCAAA4",
  "Swamp" = "#5D4037",
  "Marsh" = "#795548"
)

# Stratum descriptions
STRATUM_DESCRIPTIONS <- c(
  "Ombrotrophic Bog" = "Rain-fed acidic peatland, Sphagnum-dominated",
  "Minerotrophic Fen" = "Groundwater-fed peatland, less acidic",
  "Treed Peatland" = "Forested bog or fen with tree cover",
  "Poor Fen" = "Nutrient-poor minerotrophic peatland",
  "Rich Fen" = "Nutrient-rich minerotrophic peatland",
  "Swamp" = "Mineral wetland with woody vegetation",
  "Marsh" = "Emergent herbaceous wetland"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# Peatland-specific depth intervals (cm)
# MUCH DEEPER than other ecosystems - peatlands can be several meters deep
DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 30, 100, 200),
  depth_bottom = c(30, 100, 200, 300),
  depth_midpoint = c(15, 65, 150, 250),
  thickness_cm = c(30, 70, 100, 100),
  layer_name = c("Acrotelm", "Upper Catotelm", "Mid Catotelm", "Deep Catotelm")
)

# Depth midpoints for harmonization
STANDARD_DEPTHS <- c(15, 65, 150, 250)

# Maximum core depth
MAX_CORE_DEPTH <- 300  # Much deeper than other ecosystems

# Key depth intervals for reporting
REPORTING_DEPTHS <- list(
  acrotelm = c(0, 30),         # Active upper layer (oxic)
  upper_catotelm = c(30, 100), # Permanently saturated (anoxic)
  deep_peat = c(100, 300)      # Deep carbon storage
)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Values in g/cm³ - peatlands have VERY LOW bulk density

BD_DEFAULTS <- list(
  "Ombrotrophic Bog" = 0.10,       # Very low, mostly organic
  "Minerotrophic Fen" = 0.15,      # Slightly higher, some mineral input
  "Treed Peatland" = 0.12,
  "Poor Fen" = 0.13,
  "Rich Fen" = 0.18,               # Higher mineral content
  "Swamp" = 0.25,                  # More mineral soil
  "Marsh" = 0.20
)

# Bulk density valid ranges
BD_MIN <- 0.03  # Very low for fibric peat
BD_MAX <- 0.50  # Upper limit for organic soils

# ============================================================================
# SOIL ORGANIC CARBON RANGES
# ============================================================================

# SOC thresholds (g/kg)
# Peatlands have VERY HIGH SOC (almost pure organic matter)
SOC_MIN <- 100   # Minimum for organic soil classification
SOC_MAX <- 600   # Can be nearly 100% organic matter

# Expected SOC ranges by stratum (g/kg)
SOC_EXPECTED_RANGES <- list(
  "Ombrotrophic Bog" = c(400, 550),      # Very high, mostly Sphagnum
  "Minerotrophic Fen" = c(300, 500),
  "Treed Peatland" = c(350, 520),
  "Poor Fen" = c(320, 480),
  "Rich Fen" = c(250, 450),              # Some mineral content
  "Swamp" = c(150, 350),                 # Mineral wetland
  "Marsh" = c(100, 300)
)

# ============================================================================
# PEAT CLASSIFICATION (von Post scale)
# ============================================================================

# von Post decomposition scale (H1-H10)
VON_POST_SCALE <- c(
  "H1" = "Undecomposed (fibric)",
  "H2-H3" = "Slightly decomposed",
  "H4-H6" = "Moderately decomposed (hemic)",
  "H7-H9" = "Highly decomposed (sapric)",
  "H10" = "Completely decomposed"
)

# Bulk density by von Post class (g/cm³)
BD_BY_VON_POST <- list(
  "H1" = 0.05,
  "H2-H3" = 0.08,
  "H4-H6" = 0.12,
  "H7-H9" = 0.18,
  "H10" = 0.25
)

# ============================================================================
# CARBON FRACTION VALUES
# ============================================================================

# Default carbon fraction
CARBON_FRACTION_DEFAULT <- 0.52  # Peat is ~52% carbon (IPCC default)

# ============================================================================
# STANDARDS COMPLIANCE
# ============================================================================

# VM0036 requirements
VM0036_MIN_PLOTS <- 3
VM0036_TARGET_PRECISION <- 20   # percent
VM0036_CV_THRESHOLD <- 30       # percent
VM0036_ASSUMED_CV <- 35         # percent
VM0036_MONITORING_FREQUENCY <- 5  # years

# Peat depth measurement requirements
MIN_PEAT_DEPTH_MEASUREMENTS <- 10  # Per stratum

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
# Pristine peatlands are carbon sinks (negative emissions)
CO2_EMISSION_FACTORS <- list(
  "Ombrotrophic Bog" = -50,        # Strong sink
  "Minerotrophic Fen" = -80,       # Strongest sink
  "Treed Peatland" = -40,
  "Poor Fen" = -60,
  "Rich Fen" = -70,
  "Swamp" = -30,
  "Marsh" = -20
)

# CH4 emission factors by stratum (kg CH4-C ha⁻¹ yr⁻¹)
# Peatlands are significant methane sources
CH4_EMISSION_FACTORS <- list(
  "Ombrotrophic Bog" = 20,
  "Minerotrophic Fen" = 40,        # Higher than bogs
  "Treed Peatland" = 15,
  "Poor Fen" = 30,
  "Rich Fen" = 50,                 # Highest emissions
  "Swamp" = 35,
  "Marsh" = 45
)

# N2O emission factors (kg N2O-N ha⁻¹ yr⁻¹)
# Generally low in pristine peatlands
N2O_EMISSION_FACTORS <- list(
  "Ombrotrophic Bog" = 0.1,
  "Minerotrophic Fen" = 0.3,
  "Treed Peatland" = 0.2,
  "Poor Fen" = 0.2,
  "Rich Fen" = 0.5,
  "Swamp" = 0.4,
  "Marsh" = 0.6
)

# ============================================================================
# WATER TABLE PARAMETERS
# ============================================================================

# Critical water table depths (cm below surface)
WATER_TABLE_CRITICAL <- list(
  optimal = -10,          # Optimal for carbon accumulation
  threshold = -30,        # Below this, decomposition increases
  drainage_impact = -50   # Significant carbon losses
)

# ============================================================================
# UNCERTAINTY ASSUMPTIONS
# ============================================================================

# Measurement uncertainty (%)
MEASUREMENT_UNCERTAINTY_SOC <- 10   # Higher for peat
MEASUREMENT_UNCERTAINTY_BD <- 20    # Very high - difficult to measure
MEASUREMENT_UNCERTAINTY_DEPTH <- 5

# Spatial uncertainty inflation factor
SPATIAL_UNCERTAINTY_FACTOR <- 1.3

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

# Interpolation method
INTERPOLATION_METHOD <- "equal_area_spline"

# Spline smoothing parameters
SPLINE_SPAR_HR <- 0.5           # More smoothing for deep peat profiles
SPLINE_SPAR_COMPOSITE <- 0.7
SPLINE_SPAR_AUTO <- NULL

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- TRUE   # Peat properties can vary with depth
MAX_INCREASE_THRESHOLD <- 30    # Allow more variation

# ============================================================================
# MONITORING FREQUENCY
# ============================================================================

MONITORING_FREQUENCY_BASELINE <- 1
MONITORING_FREQUENCY_VERIFICATION <- 5
MONITORING_FREQUENCY_RESEARCH <- 1

# Water table monitoring frequency (per year)
WATER_TABLE_MONITORING_FREQUENCY <- 12  # Monthly

# ============================================================================
# ECOSYSTEM-SPECIFIC NOTES
# ============================================================================

ECOSYSTEM_NOTES <- "
Peatland carbon characteristics:
  - VERY high carbon stocks (can exceed 1000 Mg C/ha)
  - Deep carbon storage (often 2-5 meters depth)
  - Very low bulk density (0.05-0.3 g/cm³)
  - High organic matter content (>30% by weight for organic soils)
  - Water table position is critical for carbon balance
  - Net carbon sink when pristine, source when drained
  - Significant methane emissions (offset carbon sink benefit)
  - Slow carbon accumulation rates (20-50 g C m⁻² yr⁻¹)

Key considerations:
  - Measure peat depth at multiple points (high spatial variability)
  - Document water table depth (critical for carbon dynamics)
  - Use von Post scale to classify peat decomposition
  - Account for both CO2 sink and CH4 source
  - Avoid compacting samples (low bulk density)
  - Consider GHG fluxes, not just carbon stocks
  - Drainage has severe impacts - monitor water management
  - Coring requires specialized equipment for deep peat
"

# ============================================================================
# LITERATURE REFERENCES
# ============================================================================

ECOSYSTEM_REFERENCES <- list(
  methodology = "VCS VM0036 - Wetlands Restoration and Conservation",
  guidance = "IPCC 2013 Supplement to 2006 Guidelines: Wetlands",
  canadian = "Canadian Peatland Restoration and Conservation Protocol",
  technical = "Canadian Sphagnum Peat Moss Association - Best Practices"
)
