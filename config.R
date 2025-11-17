# ============================================================================
# GENERALIZED MMRV WORKFLOW CONFIGURATION
# ============================================================================
# Multi-Ecosystem Carbon Monitoring, Reporting, and Verification
# Supports: Coastal Blue Carbon, Forests, Grasslands, Wetlands/Peatlands,
#           Arctic/Subarctic ecosystems
#
# Version: 2.0 - Generalized Framework
# Last Updated: 2025-01-17
# ============================================================================

# ============================================================================
# ECOSYSTEM SELECTION
# ============================================================================

# Select your ecosystem type
# Options: "coastal_blue_carbon", "forests", "grasslands",
#          "wetlands_peatlands", "arctic_subarctic"
ECOSYSTEM_TYPE <- "coastal_blue_carbon"

# ============================================================================
# COMPOSITE SAMPLING TOGGLE
# ============================================================================

# Enable/disable composite soil sampling
# TRUE  = Use composite sampling pipeline (combine multiple subsamples)
# FALSE = Process samples individually (retain same output structure)
COMPOSITE_SAMPLING <- TRUE

# Composite sampling method (when COMPOSITE_SAMPLING = TRUE)
# Options: "paired", "unpaired", "mixed"
COMPOSITE_METHOD <- "paired"

# ============================================================================
# PROJECT METADATA
# ============================================================================

PROJECT_NAME <- "Multi_Ecosystem_MMRV_2025"
PROJECT_SCENARIO <- "PROJECT"  # Options: BASELINE, PROJECT, CONTROL, DEGRADED
MONITORING_YEAR <- 2025

# Project location (for documentation)
PROJECT_LOCATION <- "Update with your project location"
PROJECT_DESCRIPTION <- "Multi-ecosystem carbon stock assessment and MMRV"

# ============================================================================
# COORDINATE SYSTEMS
# ============================================================================

# Input CRS (usually WGS84 for GPS data)
INPUT_CRS <- 4326  # EPSG:4326 (WGS84)

# Processing CRS (projected, equal-area for accurate calculations)
# Common options:
#   - 3347: Canada Albers Equal Area (good for all Canada)
#   - 3005: NAD83 / BC Albers (optimized for British Columbia)
#   - 32610: WGS 84 / UTM zone 10N (BC coast)
#   - 5070: NAD83 / Conus Albers (Continental US)
#   - 3857: Web Mercator (global web mapping)
PROCESSING_CRS <- 3347

# ============================================================================
# OPTIONAL MODULES
# ============================================================================

# Enable/disable optional workflow components
ENABLE_FLUX_CALCULATIONS <- TRUE
ENABLE_MAPPING <- TRUE
ENABLE_INVENTORY <- TRUE
ENABLE_REMOTE_SENSING <- FALSE
ENABLE_BAYESIAN <- FALSE  # Requires GEE prior maps
ENABLE_TEMPORAL_ANALYSIS <- FALSE
ENABLE_UNCERTAINTY_ANALYSIS <- TRUE
ENABLE_ICVCM_CCP_ASSESSMENT <- TRUE  # ICVCM Core Carbon Principles compliance

# ============================================================================
# FILE PATHS
# ============================================================================

# Input directories
DIR_RAW <- "data_raw"
DIR_RAW_CORES <- file.path(DIR_RAW, "core_samples.csv")
DIR_RAW_LOCATIONS <- file.path(DIR_RAW, "core_locations.csv")
DIR_RAW_GEE <- file.path(DIR_RAW, "gee_covariates")
DIR_RAW_STRATA <- file.path(DIR_RAW, "gee_strata")

# Output directories
DIR_OUTPUT <- "outputs"
DIR_OUTPUT_PREDICTIONS <- file.path(DIR_OUTPUT, "predictions")
DIR_OUTPUT_CARBON_STOCKS <- file.path(DIR_OUTPUT, "carbon_stocks")
DIR_OUTPUT_REPORTS <- file.path(DIR_OUTPUT, "reports")
DIR_OUTPUT_MMRV <- file.path(DIR_OUTPUT, "mmrv_reports")
DIR_OUTPUT_MAPS <- file.path(DIR_OUTPUT, "maps")

# Processed data directories
DIR_PROCESSED <- "data_processed"
DIR_DIAGNOSTICS <- "diagnostics"
DIR_LOGS <- "logs"

# Temporary directories
DIR_TEMP <- "temp"

# Bayesian prior directory (optional)
DIR_BAYESIAN_PRIOR <- "data_prior"

# ============================================================================
# LOAD ECOSYSTEM-SPECIFIC PARAMETERS
# ============================================================================

# Source ecosystem configuration files
ECOSYSTEM_CONFIG_DIR <- "ecosystems"

# Build ecosystem config file path
ecosystem_config_file <- file.path(
  ECOSYSTEM_CONFIG_DIR,
  paste0(ECOSYSTEM_TYPE, "_params.R")
)

# Load ecosystem-specific parameters
if (file.exists(ecosystem_config_file)) {
  source(ecosystem_config_file)
  if (interactive()) {
    cat(sprintf("✓ Loaded ecosystem parameters: %s\n", ECOSYSTEM_TYPE))
  }
} else {
  stop(sprintf(
    "Ecosystem configuration file not found: %s\nAvailable ecosystems: %s",
    ecosystem_config_file,
    paste(
      gsub("_params.R", "", list.files(ECOSYSTEM_CONFIG_DIR, pattern = "_params.R")),
      collapse = ", "
    )
  ))
}

# ============================================================================
# GENERAL QUALITY CONTROL THRESHOLDS
# ============================================================================

# Coordinate validity (decimal degrees for WGS84)
QC_LON_MIN <- -180
QC_LON_MAX <- 180
QC_LAT_MIN <- -90
QC_LAT_MAX <- 90

# ============================================================================
# CONFIDENCE LEVELS AND STATISTICAL PARAMETERS
# ============================================================================

# Confidence level for uncertainty estimation
CONFIDENCE_LEVEL <- 0.95

# Bootstrap parameters for uncertainty quantification
BOOTSTRAP_ITERATIONS <- 100
BOOTSTRAP_SEED <- 42

# Cross-validation parameters
CV_FOLDS <- 3
CV_SEED <- 42

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
RF_NTREE <- 500                    # Number of trees
RF_MTRY <- NULL                    # NULL = automatic (sqrt of predictors)
RF_MIN_NODE_SIZE <- 5              # Minimum node size
RF_IMPORTANCE <- "permutation"     # Variable importance method

# Area of Applicability (AOA) parameters
ENABLE_AOA <- TRUE
AOA_THRESHOLD <- "default"  # "default" or numeric value

# ============================================================================
# REPORTING PARAMETERS
# ============================================================================

# Figure dimensions for saving (inches)
FIGURE_WIDTH <- 10
FIGURE_HEIGHT <- 6
FIGURE_DPI <- 300

# Table formatting
TABLE_DIGITS <- 2  # Decimal places for tables

# ============================================================================
# TEMPORAL MONITORING PARAMETERS
# ============================================================================

# Valid scenario types (expandable)
VALID_SCENARIOS <- c(
  "BASELINE", "DEGRADED", "DISTURBED", "REFERENCE", "CONTROL",
  "PROJECT", "PROJECT_Y0", "PROJECT_Y1", "PROJECT_Y5",
  "PROJECT_Y10", "PROJECT_Y15", "CUSTOM"
)

# Monitoring frequency (years)
MONITORING_FREQUENCY <- 5

# Minimum years for temporal change analysis
MIN_YEARS_FOR_CHANGE <- 3

# Additionality test confidence level
ADDITIONALITY_CONFIDENCE <- 0.95

# Conservative approach for additionality calculations
ADDITIONALITY_METHOD <- "lower_bound"  # Options: "mean", "lower_bound", "conservative"

# ============================================================================
# SCENARIO MODELING PARAMETERS
# ============================================================================

# Enable scenario modeling
SCENARIO_MODELING_ENABLED <- FALSE

# Recovery model type
RECOVERY_MODEL_TYPE <- "exponential"  # Options: "exponential", "linear", "logistic", "asymptotic"

# Uncertainty inflation for modeled scenarios (%)
MODELING_UNCERTAINTY_BUFFER <- 10

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

#' Get ecosystem-specific parameter with fallback
#'
#' @param param_name Name of parameter to retrieve
#' @param default Default value if parameter not found
#' @return Parameter value or default
get_ecosystem_param <- function(param_name, default = NULL) {
  if (exists(param_name, envir = .GlobalEnv)) {
    return(get(param_name, envir = .GlobalEnv))
  } else if (!is.null(default)) {
    return(default)
  } else {
    stop(sprintf("Required parameter '%s' not found in ecosystem configuration", param_name))
  }
}

#' Create standardized output filename
#'
#' @param module Module name (e.g., "carbon_stocks")
#' @param file_type File type (e.g., "csv", "rds", "tif")
#' @param suffix Optional suffix
#' @return Standardized filename
create_output_filename <- function(module, file_type, suffix = NULL) {
  base_name <- paste0(
    module, "_",
    ECOSYSTEM_TYPE,
    ifelse(COMPOSITE_SAMPLING, "_composite", "_individual")
  )

  if (!is.null(suffix)) {
    base_name <- paste0(base_name, "_", suffix)
  }

  return(paste0(base_name, ".", file_type))
}

# ============================================================================
# SESSION TRACKING
# ============================================================================

SESSION_START <- Sys.time()
SESSION_ID <- format(SESSION_START, "%Y%m%d_%H%M%S")

# ============================================================================
# CONFIGURATION VALIDATION
# ============================================================================

#' Validate configuration settings
validate_config <- function() {
  issues <- character(0)

  # Check ecosystem type
  valid_ecosystems <- c(
    "coastal_blue_carbon", "forests", "grasslands",
    "wetlands_peatlands", "arctic_subarctic"
  )
  if (!ECOSYSTEM_TYPE %in% valid_ecosystems) {
    issues <- c(issues, sprintf(
      "Invalid ECOSYSTEM_TYPE: %s. Must be one of: %s",
      ECOSYSTEM_TYPE, paste(valid_ecosystems, collapse = ", ")
    ))
  }

  # Check composite sampling method
  if (COMPOSITE_SAMPLING) {
    valid_methods <- c("paired", "unpaired", "mixed")
    if (!COMPOSITE_METHOD %in% valid_methods) {
      issues <- c(issues, sprintf(
        "Invalid COMPOSITE_METHOD: %s. Must be one of: %s",
        COMPOSITE_METHOD, paste(valid_methods, collapse = ", ")
      ))
    }
  }

  # Check required directories exist
  required_dirs <- c(DIR_RAW, DIR_OUTPUT, DIR_PROCESSED)
  for (dir in required_dirs) {
    if (!dir.exists(dir)) {
      issues <- c(issues, sprintf("Required directory does not exist: %s", dir))
    }
  }

  # Report issues
  if (length(issues) > 0) {
    warning("Configuration validation issues detected:\n  ",
            paste(issues, collapse = "\n  "))
    return(FALSE)
  }

  return(TRUE)
}

# Run validation if interactive
if (interactive()) {
  config_valid <- validate_config()
  if (config_valid) {
    cat("\n")
    cat("╔════════════════════════════════════════════════════════════════╗\n")
    cat("║     GENERALIZED MMRV WORKFLOW CONFIGURATION LOADED            ║\n")
    cat("╚════════════════════════════════════════════════════════════════╝\n")
    cat("\n")
    cat(sprintf("  Ecosystem Type:       %s\n", ECOSYSTEM_TYPE))
    cat(sprintf("  Composite Sampling:   %s\n", ifelse(COMPOSITE_SAMPLING, "ENABLED", "DISABLED")))
    if (COMPOSITE_SAMPLING) {
      cat(sprintf("  Composite Method:     %s\n", COMPOSITE_METHOD))
    }
    cat(sprintf("  Project Name:         %s\n", PROJECT_NAME))
    cat(sprintf("  Scenario:             %s\n", PROJECT_SCENARIO))
    cat(sprintf("  Monitoring Year:      %d\n", MONITORING_YEAR))
    cat(sprintf("  Session ID:           %s\n", SESSION_ID))
    cat("\n")
    cat("  Optional Modules:\n")
    cat(sprintf("    Flux Calculations:  %s\n", ifelse(ENABLE_FLUX_CALCULATIONS, "✓", "✗")))
    cat(sprintf("    Mapping:            %s\n", ifelse(ENABLE_MAPPING, "✓", "✗")))
    cat(sprintf("    Inventory:          %s\n", ifelse(ENABLE_INVENTORY, "✓", "✗")))
    cat(sprintf("    Remote Sensing:     %s\n", ifelse(ENABLE_REMOTE_SENSING, "✓", "✗")))
    cat(sprintf("    Bayesian Analysis:  %s\n", ifelse(ENABLE_BAYESIAN, "✓", "✗")))
    cat(sprintf("    Temporal Analysis:  %s\n", ifelse(ENABLE_TEMPORAL_ANALYSIS, "✓", "✗")))
    cat("\n")
    cat("  ✓ Configuration validation passed\n")
    cat("\n")
  }
}

# ============================================================================
# END OF CONFIGURATION
# ============================================================================
