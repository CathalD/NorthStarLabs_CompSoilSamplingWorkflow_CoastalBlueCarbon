# ============================================================================
# TEMPLATE: NEW ECOSYSTEM PARAMETERS
# ============================================================================
# Copy this file and customize for your ecosystem type
# Filename format: ecosystems/{ecosystem_type}_params.R
# Example: ecosystems/mangroves_params.R
# ============================================================================

# ============================================================================
# ECOSYSTEM METADATA
# ============================================================================

ECOSYSTEM_NAME <- "Your Ecosystem Name Here"
ECOSYSTEM_DESCRIPTION <- "Brief description of the ecosystem"
ECOSYSTEM_STANDARDS <- c("VM0XXX", "IPCC", "Other_Standards")

# ============================================================================
# STRATIFICATION
# ============================================================================

# Define your ecosystem strata (vegetation types, disturbance classes, etc.)
VALID_STRATA <- c(
  "Stratum 1 Name",
  "Stratum 2 Name",
  "Stratum 3 Name"
  # Add as many as needed
)

# Colors for plotting (hex codes)
STRATUM_COLORS <- c(
  "Stratum 1 Name" = "#HEXCODE",
  "Stratum 2 Name" = "#HEXCODE",
  "Stratum 3 Name" = "#HEXCODE"
)

# Optional: Stratum descriptions
STRATUM_DESCRIPTIONS <- c(
  "Stratum 1 Name" = "Description of stratum 1",
  "Stratum 2 Name" = "Description of stratum 2",
  "Stratum 3 Name" = "Description of stratum 3"
)

# ============================================================================
# DEPTH CONFIGURATION (REQUIRED)
# ============================================================================

# Define depth intervals appropriate for your ecosystem
# Example depths shown - adjust for your ecosystem
DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30),           # Top of each layer (cm)
  depth_bottom = c(15, 30, 50),       # Bottom of each layer (cm)
  depth_midpoint = c(7.5, 22.5, 40),  # Midpoint for interpolation
  thickness_cm = c(15, 15, 20),       # Layer thickness
  layer_name = c("Surface", "Subsurface", "Deep")  # Optional names
)

# Depth midpoints for harmonization (must match depth_midpoint above)
STANDARD_DEPTHS <- c(7.5, 22.5, 40)

# Maximum sampling depth for your ecosystem (cm)
MAX_CORE_DEPTH <- 50

# Optional: Depth intervals for reporting
REPORTING_DEPTHS <- list(
  surface = c(0, 15),
  subsurface = c(15, 50)
)

# ============================================================================
# BULK DENSITY DEFAULTS (REQUIRED)
# ============================================================================

# Default bulk density values (g/cm³) for each stratum
# Use when bulk density is not measured in field
BD_DEFAULTS <- list(
  "Stratum 1 Name" = 1.0,
  "Stratum 2 Name" = 1.1,
  "Stratum 3 Name" = 1.2
)

# Valid bulk density ranges for QC (g/cm³)
BD_MIN <- 0.1
BD_MAX <- 2.0

# ============================================================================
# SOIL ORGANIC CARBON RANGES (REQUIRED)
# ============================================================================

# Overall SOC thresholds (g/kg)
SOC_MIN <- 0
SOC_MAX <- 300

# Expected SOC ranges by stratum (g/kg) - for QA/QC flagging
SOC_EXPECTED_RANGES <- list(
  "Stratum 1 Name" = c(10, 100),
  "Stratum 2 Name" = c(15, 120),
  "Stratum 3 Name" = c(20, 150)
)

# ============================================================================
# CARBON FRACTION VALUES (OPTIONAL)
# ============================================================================

# Default carbon fraction if not using SOC directly
# Set to NULL if SOC is measured directly
CARBON_FRACTION_DEFAULT <- 0.5  # 50% of organic matter is carbon (IPCC default)

# ============================================================================
# STANDARDS COMPLIANCE (REQUIRED)
# ============================================================================

# Minimum samples per stratum
VM0033_MIN_CORES <- 3  # Adjust to your methodology

# Target precision (% relative error at 95% CI)
VM0033_TARGET_PRECISION <- 20

# CV threshold (%)
VM0033_CV_THRESHOLD <- 30

# Assumed CV for sample size calculation (%)
VM0033_ASSUMED_CV <- 30

# Monitoring frequency (years)
VM0033_MONITORING_FREQUENCY <- 5

# Note: These are aliased as VM0033 for compatibility
# Adjust variable names to match your methodology if needed

# ============================================================================
# EMISSION FACTORS (OPTIONAL - for flux calculations)
# ============================================================================

# CH4 emission factors by stratum (kg CH4-C ha⁻¹ yr⁻¹)
CH4_EMISSION_FACTORS <- list(
  "Stratum 1 Name" = 5,
  "Stratum 2 Name" = 10,
  "Stratum 3 Name" = 15
)

# N2O emission factors by stratum (kg N2O-N ha⁻¹ yr⁻¹)
N2O_EMISSION_FACTORS <- list(
  "Stratum 1 Name" = 0.5,
  "Stratum 2 Name" = 0.7,
  "Stratum 3 Name" = 0.9
)

# CO2 emission factors (if applicable)
CO2_EMISSION_FACTORS <- list(
  "Stratum 1 Name" = 100,
  "Stratum 2 Name" = 150,
  "Stratum 3 Name" = 200
)

# ============================================================================
# UNCERTAINTY ASSUMPTIONS (OPTIONAL)
# ============================================================================

# Measurement uncertainty (%)
MEASUREMENT_UNCERTAINTY_SOC <- 5
MEASUREMENT_UNCERTAINTY_BD <- 10
MEASUREMENT_UNCERTAINTY_DEPTH <- 2

# Spatial uncertainty inflation factor
SPATIAL_UNCERTAINTY_FACTOR <- 1.2

# ============================================================================
# DEPTH HARMONIZATION PARAMETERS (OPTIONAL)
# ============================================================================

# Interpolation method
INTERPOLATION_METHOD <- "equal_area_spline"

# Spline smoothing parameters
SPLINE_SPAR_HR <- 0.3
SPLINE_SPAR_COMPOSITE <- 0.5
SPLINE_SPAR_AUTO <- NULL

# Monotonicity parameters
ALLOW_DEPTH_INCREASES <- FALSE  # TRUE if SOC can increase with depth
MAX_INCREASE_THRESHOLD <- 10    # Maximum % increase allowed

# ============================================================================
# MONITORING FREQUENCY (OPTIONAL)
# ============================================================================

MONITORING_FREQUENCY_BASELINE <- 1
MONITORING_FREQUENCY_VERIFICATION <- 5
MONITORING_FREQUENCY_RESEARCH <- 1

# ============================================================================
# ECOSYSTEM-SPECIFIC NOTES (OPTIONAL)
# ============================================================================

ECOSYSTEM_NOTES <- "
Add notes about your ecosystem here:
  - Key characteristics
  - Sampling considerations
  - Common issues
  - Important references
"

# ============================================================================
# LITERATURE REFERENCES (OPTIONAL)
# ============================================================================

ECOSYSTEM_REFERENCES <- list(
  methodology = "Primary methodology reference",
  guidance = "Guidance documents",
  technical = "Technical papers",
  regional = "Regional studies"
)

# ============================================================================
# CUSTOM PARAMETERS (ADD AS NEEDED)
# ============================================================================

# Add any ecosystem-specific parameters here
# Examples:
#   - Fire return intervals (forests)
#   - Grazing intensity (grasslands)
#   - Water table depth (wetlands)
#   - Active layer depth (permafrost)
#   - Tidal regime (coastal)

# YOUR_CUSTOM_PARAMETER <- value

# ============================================================================
# END OF TEMPLATE
# ============================================================================

# CHECKLIST FOR NEW ECOSYSTEM PARAMETERS:
# [ ] ECOSYSTEM_NAME defined
# [ ] VALID_STRATA defined (at least 1 stratum)
# [ ] DEPTH_INTERVALS defined (at least 1 layer)
# [ ] STANDARD_DEPTHS defined
# [ ] MAX_CORE_DEPTH defined
# [ ] BD_DEFAULTS defined for all strata
# [ ] SOC_MIN and SOC_MAX defined
# [ ] VM0033_MIN_CORES defined
# [ ] VM0033_TARGET_PRECISION defined
# [ ] Tested with run_workflow.R
