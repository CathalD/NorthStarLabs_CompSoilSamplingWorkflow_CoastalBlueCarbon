# ============================================================================
# GRASSLANDS ECOSYSTEM PARAMETERS
# ============================================================================
# Ecosystem: Prairies, rangelands, improved pastures
# Standards: VCS VM0026, VM0032, Alberta TIER offsets, IPCC Grassland Guidelines
# Geographic Focus: Prairie and grassland regions
# Carbon Pools: Soil organic carbon (0-50 cm depth, emphasis on 0-30 cm)
# ============================================================================

# ============================================================================
# ECOSYSTEM METADATA
# ============================================================================

ECOSYSTEM_NAME <- "Grasslands"
ECOSYSTEM_DESCRIPTION <- "Prairie, rangeland, and improved pasture ecosystems"
ECOSYSTEM_STANDARDS <- c("VM0026", "VM0032", "Alberta_TIER", "IPCC_Grassland")

# ============================================================================
# STRATIFICATION
# ============================================================================

# Valid ecosystem strata
VALID_STRATA <- c(
  "Native Prairie",        # Native mixed-grass or tallgrass prairie
  "Improved Pasture",      # Managed, fertilized pasture
  "Degraded Grassland",    # Overgrazed or degraded
  "Restored Grassland",    # Recently restored from cropland
  "Riparian Grassland",    # Along water courses
  "Shrub-Grass Mix"        # Transition to woody vegetation
)

# Stratum colors for plotting
STRATUM_COLORS <- c(
  "Native Prairie" = "#8BC34A",
  "Improved Pasture" = "#CDDC39",
  "Degraded Grassland" = "#FFC107",
  "Restored Grassland" = "#4CAF50",
  "Riparian Grassland" = "#009688",
  "Shrub-Grass Mix" = "#795548"
)

# Stratum descriptions
STRATUM_DESCRIPTIONS <- c(
  "Native Prairie" = "Native mixed-grass or tallgrass prairie",
  "Improved Pasture" = "Managed, fertilized pasture with improved species",
  "Degraded Grassland" = "Overgrazed or otherwise degraded grassland",
  "Restored Grassland" = "Grassland restored from cropland",
  "Riparian Grassland" = "Grassland along watercourses",
  "Shrub-Grass Mix" = "Transitional grassland-shrubland"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# Grassland-specific depth intervals (cm)
# Shallower than blue carbon, focused on root zone
DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30),
  depth_bottom = c(15, 30, 50),
  depth_midpoint = c(7.5, 22.5, 40),
  thickness_cm = c(15, 15, 20),
  layer_name = c("Surface", "Subsurface", "Deep")
)

# Depth midpoints for harmonization
STANDARD_DEPTHS <- c(7.5, 22.5, 40)

# Maximum core depth
MAX_CORE_DEPTH <- 50

# Key depth intervals for reporting
REPORTING_DEPTHS <- list(
  surface = c(0, 15),      # Top 15 cm (most active)
  subsurface = c(15, 30),  # 15-30 cm
  deep = c(30, 50)         # Deep storage
)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Values in g/cm³ - grasslands typically have moderate BD

BD_DEFAULTS <- list(
  "Native Prairie" = 1.1,         # Moderate, well-structured
  "Improved Pasture" = 1.2,       # Slightly compacted
  "Degraded Grassland" = 1.3,     # Compacted from overgrazing
  "Restored Grassland" = 1.15,    # Recovering structure
  "Riparian Grassland" = 1.0,     # Lower, more organic
  "Shrub-Grass Mix" = 1.05        # Similar to native prairie
)

# Bulk density valid ranges
BD_MIN <- 0.5
BD_MAX <- 2.0

# ============================================================================
# SOIL ORGANIC CARBON RANGES
# ============================================================================

# SOC thresholds (g/kg)
SOC_MIN <- 0
SOC_MAX <- 200  # Grasslands moderate SOC

# Expected SOC ranges by stratum (g/kg)
SOC_EXPECTED_RANGES <- list(
  "Native Prairie" = c(20, 100),
  "Improved Pasture" = c(15, 80),
  "Degraded Grassland" = c(5, 50),
  "Restored Grassland" = c(10, 70),
  "Riparian Grassland" = c(25, 120),
  "Shrub-Grass Mix" = c(20, 90)
)

# ============================================================================
# CARBON FRACTION VALUES
# ============================================================================

# Default carbon fraction
CARBON_FRACTION_DEFAULT <- 0.5  # 50% of organic matter is carbon

# ============================================================================
# STANDARDS COMPLIANCE
# ============================================================================

# VM0026 requirements
VM0026_MIN_PLOTS <- 4           # Minimum plots per stratum (higher than forests)
VM0026_TARGET_PRECISION <- 20   # percent
VM0026_CV_THRESHOLD <- 35       # percent (high spatial variability)
VM0026_ASSUMED_CV <- 40         # percent
VM0026_MONITORING_FREQUENCY <- 5  # years

# Alberta TIER requirements
TIER_MIN_SAMPLES <- 5
TIER_TARGET_PRECISION <- 20

# Alias for compatibility
VM0033_MIN_CORES <- VM0026_MIN_PLOTS
VM0033_TARGET_PRECISION <- VM0026_TARGET_PRECISION
VM0033_CV_THRESHOLD <- VM0026_CV_THRESHOLD
VM0033_ASSUMED_CV <- VM0026_ASSUMED_CV
VM0033_MONITORING_FREQUENCY <- VM0026_MONITORING_FREQUENCY

# ============================================================================
# EMISSION FACTORS (for flux calculations)
# ============================================================================

# N2O emission factors by stratum (kg N2O-N ha⁻¹ yr⁻¹)
# Based on IPCC Tier 1 defaults with adjustments
N2O_EMISSION_FACTORS <- list(
  "Native Prairie" = 0.5,
  "Improved Pasture" = 1.5,      # Higher due to fertilization
  "Degraded Grassland" = 0.3,
  "Restored Grassland" = 0.8,
  "Riparian Grassland" = 1.0,
  "Shrub-Grass Mix" = 0.4
)

# CH4 emission factors by stratum (kg CH4-C ha⁻¹ yr⁻¹)
# Grazed grasslands can emit or uptake depending on management
CH4_EMISSION_FACTORS <- list(
  "Native Prairie" = -1,          # Slight sink
  "Improved Pasture" = 5,         # Source due to livestock
  "Degraded Grassland" = 2,
  "Restored Grassland" = 0,
  "Riparian Grassland" = 3,
  "Shrub-Grass Mix" = -0.5
)

# Grazing intensity factors (Animal Unit Months per hectare)
GRAZING_INTENSITY <- list(
  "Native Prairie" = 2.5,
  "Improved Pasture" = 6,
  "Degraded Grassland" = 8,       # Overgrazed
  "Restored Grassland" = 3,
  "Riparian Grassland" = 4,
  "Shrub-Grass Mix" = 2
)

# ============================================================================
# UNCERTAINTY ASSUMPTIONS
# ============================================================================

# Measurement uncertainty (%)
MEASUREMENT_UNCERTAINTY_SOC <- 5
MEASUREMENT_UNCERTAINTY_BD <- 12
MEASUREMENT_UNCERTAINTY_DEPTH <- 2

# Spatial uncertainty inflation factor
SPATIAL_UNCERTAINTY_FACTOR <- 1.4  # High spatial variability in grasslands

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

# Interpolation method
INTERPOLATION_METHOD <- "equal_area_spline"

# Spline smoothing parameters
SPLINE_SPAR_HR <- 0.3
SPLINE_SPAR_COMPOSITE <- 0.5
SPLINE_SPAR_AUTO <- NULL

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- FALSE  # SOC decreases with depth
MAX_INCREASE_THRESHOLD <- 10

# ============================================================================
# MONITORING FREQUENCY
# ============================================================================

MONITORING_FREQUENCY_BASELINE <- 1
MONITORING_FREQUENCY_VERIFICATION <- 5
MONITORING_FREQUENCY_RESEARCH <- 2

# ============================================================================
# MANAGEMENT FACTORS
# ============================================================================

# Grazing management categories
GRAZING_MANAGEMENT <- c(
  "Continuous" = "Year-round continuous grazing",
  "Rotational" = "Managed rotational grazing",
  "Seasonal" = "Seasonal grazing (summer only)",
  "Deferred" = "Deferred rotation",
  "None" = "No grazing (conservation)"
)

# Fertilization rates (kg N ha⁻¹ yr⁻¹)
FERTILIZATION_RATES <- list(
  "Native Prairie" = 0,
  "Improved Pasture" = 80,
  "Degraded Grassland" = 0,
  "Restored Grassland" = 20,
  "Riparian Grassland" = 10,
  "Shrub-Grass Mix" = 0
)

# ============================================================================
# ECOSYSTEM-SPECIFIC NOTES
# ============================================================================

ECOSYSTEM_NOTES <- "
Grassland soil carbon characteristics:
  - Most carbon in top 30 cm (root-dominated)
  - Strong influence of grazing management on carbon stocks
  - High spatial variability (microsite effects)
  - Sensitive to land use history (cultivation, grazing)
  - Root biomass is major carbon input
  - Slower carbon accumulation than blue carbon

Key considerations:
  - Document grazing history and intensity
  - Sample to at least 30 cm (50 cm for comprehensive assessment)
  - Account for land use history (native vs. restored vs. improved)
  - Consider soil texture effects (clay protects carbon)
  - Fertilization affects both stocks and emissions
  - Seasonal timing of sampling important (avoid frozen soils)
"

# ============================================================================
# LITERATURE REFERENCES
# ============================================================================

ECOSYSTEM_REFERENCES <- list(
  methodology = "VCS VM0026 - Avoided Grassland Conversion",
  guidance = "IPCC 2019 Refinement to 2006 Guidelines - Chapter 6 Grassland",
  canadian = "Alberta TIER Offset Protocol - Conservation Cropping",
  regional = "Canadian Prairies Carbon Atlas"
)
