# ============================================================================
# COASTAL BLUE CARBON ECOSYSTEM PARAMETERS
# ============================================================================
# Ecosystem: Coastal tidal wetlands, salt marshes, seagrass beds, mangroves
# Standards: VM0033 (Verra), ORRAA, IPCC Wetlands Supplement
# Geographic Focus: Coastal zones (adaptable globally)
# Carbon Pools: Soil organic carbon (0-100 cm depth)
# ============================================================================

# ============================================================================
# ECOSYSTEM METADATA
# ============================================================================

ECOSYSTEM_NAME <- "Coastal Blue Carbon"
ECOSYSTEM_DESCRIPTION <- "Tidal wetlands, salt marshes, seagrass beds, and mangroves"
ECOSYSTEM_STANDARDS <- c("VM0033", "ORRAA", "IPCC_Wetlands")

# ============================================================================
# STRATIFICATION
# ============================================================================

# Valid ecosystem strata
VALID_STRATA <- c(
  "Upper Marsh",           # Infrequent flooding, salt-tolerant shrubs
  "Mid Marsh",             # Regular inundation, mixed halophytes
  "Lower Marsh",           # Daily tides, dense Spartina
  "Underwater Vegetation", # Subtidal seagrass beds
  "Open Water"            # Tidal channels, lagoons
)

# Stratum colors for plotting
STRATUM_COLORS <- c(
  "Upper Marsh" = "#FFFF99",
  "Mid Marsh" = "#99FF99",
  "Lower Marsh" = "#33CC33",
  "Underwater Vegetation" = "#0066CC",
  "Open Water" = "#000099"
)

# Stratum descriptions
STRATUM_DESCRIPTIONS <- c(
  "Upper Marsh" = "Infrequently flooded, salt-tolerant vegetation",
  "Mid Marsh" = "Regularly inundated, highest C sequestration",
  "Lower Marsh" = "Daily tidal inundation, highest burial rates",
  "Underwater Vegetation" = "Subtidal seagrass meadows",
  "Open Water" = "Tidal channels and open water"
)

# ============================================================================
# DEPTH CONFIGURATION
# ============================================================================

# Standard depth intervals (cm) - VM0033 compliant
DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30, 50),
  depth_bottom = c(15, 30, 50, 100),
  depth_midpoint = c(7.5, 22.5, 40, 75),
  thickness_cm = c(15, 15, 20, 50),
  layer_name = c("Surface", "Shallow subsurface", "Mid subsurface", "Deep subsurface")
)

# Depth midpoints for harmonization
STANDARD_DEPTHS <- c(7.5, 22.5, 40, 75)

# Maximum core depth
MAX_CORE_DEPTH <- 100

# Key depth intervals for reporting
REPORTING_DEPTHS <- list(
  surface = c(0, 30),      # Top 30 cm (most active layer)
  subsurface = c(30, 100)  # 30-100 cm (long-term storage)
)

# ============================================================================
# BULK DENSITY DEFAULTS BY STRATUM
# ============================================================================
# Values in g/cm³ based on literature for coastal ecosystems

BD_DEFAULTS <- list(
  "Upper Marsh" = 0.8,              # Lower density, more organic matter
  "Mid Marsh" = 1.0,                # Moderate density
  "Lower Marsh" = 1.2,              # Higher density, more mineral content
  "Underwater Vegetation" = 0.6,    # Lowest density, high organic content
  "Open Water" = 1.0                # Moderate, mostly mineral
)

# Bulk density valid ranges
BD_MIN <- 0.1
BD_MAX <- 3.0

# ============================================================================
# SOIL ORGANIC CARBON RANGES
# ============================================================================

# SOC thresholds (g/kg)
SOC_MIN <- 0
SOC_MAX <- 500  # Coastal wetlands can have very high SOC

# Expected SOC ranges by stratum (g/kg) - for QC flagging
SOC_EXPECTED_RANGES <- list(
  "Upper Marsh" = c(20, 150),
  "Mid Marsh" = c(30, 200),
  "Lower Marsh" = c(25, 180),
  "Underwater Vegetation" = c(15, 120),
  "Open Water" = c(10, 100)
)

# ============================================================================
# CARBON FRACTION VALUES
# ============================================================================

# Default carbon fraction (if not measured)
# Coastal wetlands: typically use SOC directly
CARBON_FRACTION_DEFAULT <- NULL  # Not applicable for blue carbon (use SOC)

# ============================================================================
# STANDARDS COMPLIANCE
# ============================================================================

# VM0033 requirements
VM0033_MIN_CORES <- 3
VM0033_TARGET_PRECISION <- 20  # percent relative error at 95% CI
VM0033_CV_THRESHOLD <- 30      # percent coefficient of variation
VM0033_ASSUMED_CV <- 30        # percent for sample size calculation
VM0033_MONITORING_FREQUENCY <- 5  # years

# ============================================================================
# EMISSION FACTORS (for flux calculations)
# ============================================================================

# CH4 emission factors by stratum (kg CH4-C ha⁻¹ yr⁻¹)
# Based on IPCC Wetlands Supplement 2013
CH4_EMISSION_FACTORS <- list(
  "Upper Marsh" = 10,
  "Mid Marsh" = 15,
  "Lower Marsh" = 20,
  "Underwater Vegetation" = 5,
  "Open Water" = 25
)

# N2O emission factors by stratum (kg N2O-N ha⁻¹ yr⁻¹)
N2O_EMISSION_FACTORS <- list(
  "Upper Marsh" = 0.5,
  "Mid Marsh" = 0.7,
  "Lower Marsh" = 0.9,
  "Underwater Vegetation" = 0.3,
  "Open Water" = 0.2
)

# ============================================================================
# UNCERTAINTY ASSUMPTIONS
# ============================================================================

# Measurement uncertainty (%)
MEASUREMENT_UNCERTAINTY_SOC <- 5     # SOC analytical uncertainty
MEASUREMENT_UNCERTAINTY_BD <- 10     # Bulk density measurement uncertainty
MEASUREMENT_UNCERTAINTY_DEPTH <- 2   # Depth measurement uncertainty

# Spatial uncertainty inflation factor
SPATIAL_UNCERTAINTY_FACTOR <- 1.2

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS
# ============================================================================

# Interpolation method
INTERPOLATION_METHOD <- "equal_area_spline"  # VM0033 recommended

# Spline smoothing parameters
SPLINE_SPAR_HR <- 0.3           # High-resolution cores
SPLINE_SPAR_COMPOSITE <- 0.5    # Composite cores
SPLINE_SPAR_AUTO <- NULL        # Automatic cross-validation

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- TRUE   # Allow slight SOC increases with depth
MAX_INCREASE_THRESHOLD <- 20    # Maximum % increase between adjacent depths

# ============================================================================
# MONITORING FREQUENCY
# ============================================================================

# Monitoring intervals for different assessment types
MONITORING_FREQUENCY_BASELINE <- 1       # Annual for first 3 years
MONITORING_FREQUENCY_VERIFICATION <- 5   # Every 5 years post-verification
MONITORING_FREQUENCY_RESEARCH <- 1       # Annual for research

# ============================================================================
# ECOSYSTEM-SPECIFIC NOTES
# ============================================================================

ECOSYSTEM_NOTES <- "
Coastal blue carbon ecosystems are characterized by:
  - High carbon sequestration rates (100-1500 g C m⁻² yr⁻¹)
  - Deep carbon storage (often >1m depth)
  - Tidal inundation affecting decomposition rates
  - High spatial heterogeneity
  - Sediment accretion as key process
  - Vulnerability to sea level rise and erosion

Key considerations:
  - Use VM0033 methodology for carbon credit development
  - Account for tidal regime in sampling design
  - Consider both autochthonous and allochthonous carbon sources
  - Monitor sediment accretion rates
  - Assess blue carbon vs. blue CO2 (respiratory losses)
"

# ============================================================================
# LITERATURE REFERENCES
# ============================================================================

ECOSYSTEM_REFERENCES <- list(
  methodology = "Verra VM0033 v2.0 - Tidal Wetland and Seagrass Restoration",
  guidance = "ORRAA High Quality Blue Carbon Principles and Guidance (2021)",
  ipcc = "IPCC 2013 Supplement to 2006 Guidelines: Wetlands",
  canadian = "Canadian Blue Carbon Network - Regional Guidance"
)
