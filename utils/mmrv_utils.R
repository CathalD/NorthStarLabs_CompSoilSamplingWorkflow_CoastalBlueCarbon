# ============================================================================
# GENERALIZED MMRV UTILITY FUNCTIONS
# ============================================================================
# Shared utility functions for multi-ecosystem MMRV workflow
# Version: 2.0
# ============================================================================

# ============================================================================
# ECOSYSTEM PARAMETER UTILITIES
# ============================================================================

#' Get ecosystem parameter with fallback to default
#'
#' @param param_name Name of the parameter to retrieve
#' @param default Default value if parameter not found
#' @param required Logical, throw error if parameter not found (default: FALSE)
#' @return Parameter value
#' @export
get_param <- function(param_name, default = NULL, required = FALSE) {
  if (exists(param_name, envir = .GlobalEnv)) {
    return(get(param_name, envir = .GlobalEnv))
  } else if (!is.null(default)) {
    return(default)
  } else if (required) {
    stop(sprintf("Required parameter '%s' not found in configuration", param_name))
  } else {
    return(NULL)
  }
}

#' Validate ecosystem configuration
#'
#' @param ecosystem_type Type of ecosystem
#' @return Logical, TRUE if valid
#' @export
validate_ecosystem_config <- function(ecosystem_type) {
  required_params <- c(
    "ECOSYSTEM_NAME",
    "VALID_STRATA",
    "DEPTH_INTERVALS",
    "STANDARD_DEPTHS",
    "BD_DEFAULTS",
    "SOC_MIN",
    "SOC_MAX"
  )

  missing <- character(0)
  for (param in required_params) {
    if (!exists(param, envir = .GlobalEnv)) {
      missing <- c(missing, param)
    }
  }

  if (length(missing) > 0) {
    stop(sprintf(
      "Ecosystem configuration incomplete for '%s'. Missing parameters: %s",
      ecosystem_type,
      paste(missing, collapse = ", ")
    ))
  }

  return(TRUE)
}

# ============================================================================
# COMPOSITE SAMPLING UTILITIES
# ============================================================================

#' Process samples based on composite sampling setting
#'
#' @param samples Data frame of soil samples
#' @param composite_enabled Logical, use composite sampling
#' @param method Composite method ("paired", "unpaired", "mixed")
#' @return Processed data frame
#' @export
process_sampling_mode <- function(samples, composite_enabled = TRUE, method = "paired") {
  if (!composite_enabled) {
    # Individual sample mode - add unique sample IDs
    samples <- samples %>%
      mutate(sample_id = paste(core_id, depth_top_cm, depth_bottom_cm, sep = "_"))

    if (!"core_type" %in% colnames(samples)) {
      samples$core_type <- "Individual"
    }

    message("Processing in INDIVIDUAL SAMPLE mode")
  } else {
    # Composite sampling mode
    if (!"core_type" %in% colnames(samples)) {
      samples$core_type <- method
    }

    message(sprintf("Processing in COMPOSITE SAMPLING mode (method: %s)", method))
  }

  return(samples)
}

#' Aggregate composite samples
#'
#' @param samples Data frame with individual subsamples
#' @param group_vars Variables to group by (e.g., c("core_id", "depth_top_cm"))
#' @return Aggregated composite samples
#' @export
aggregate_composite_samples <- function(samples, group_vars = c("core_id", "depth_top_cm", "depth_bottom_cm")) {
  samples %>%
    group_by(across(all_of(group_vars))) %>%
    summarise(
      soc_g_kg = mean(soc_g_kg, na.rm = TRUE),
      bd_g_cm3 = mean(bd_g_cm3, na.rm = TRUE),
      n_subsamples = n(),
      soc_sd = sd(soc_g_kg, na.rm = TRUE),
      bd_sd = sd(bd_g_cm3, na.rm = TRUE),
      .groups = "drop"
    )
}

# ============================================================================
# CARBON STOCK CALCULATION UTILITIES
# ============================================================================

#' Calculate carbon stock from SOC and bulk density
#'
#' @param soc_g_kg Soil organic carbon (g/kg)
#' @param bd_g_cm3 Bulk density (g/cm³)
#' @param depth_cm Layer thickness (cm)
#' @return Carbon stock (kg/m²)
#' @export
calculate_carbon_stock <- function(soc_g_kg, bd_g_cm3, depth_cm) {
  # Formula: C stock (kg/m²) = SOC (g/kg) × BD (g/cm³) × depth (cm) / 1000
  carbon_stock <- (soc_g_kg * bd_g_cm3 * depth_cm) / 1000
  return(carbon_stock)
}

#' Calculate carbon stock with uncertainty
#'
#' @param soc_g_kg SOC (g/kg)
#' @param soc_se SOC standard error
#' @param bd_g_cm3 Bulk density (g/cm³)
#' @param bd_se BD standard error
#' @param depth_cm Depth (cm)
#' @return List with mean, se, and cv
#' @export
calculate_carbon_stock_with_uncertainty <- function(soc_g_kg, soc_se, bd_g_cm3, bd_se, depth_cm) {
  # Mean carbon stock
  mean_stock <- calculate_carbon_stock(soc_g_kg, bd_g_cm3, depth_cm)

  # Uncertainty propagation (assuming independence)
  cv_soc <- soc_se / soc_g_kg
  cv_bd <- bd_se / bd_g_cm3
  cv_combined <- sqrt(cv_soc^2 + cv_bd^2)

  se_stock <- mean_stock * cv_combined

  return(list(
    mean = mean_stock,
    se = se_stock,
    cv = cv_combined
  ))
}

#' Aggregate carbon stocks across depth intervals
#'
#' @param stocks Data frame with depth-specific stocks
#' @param depth_intervals Depth interval specifications
#' @return Aggregated total stock
#' @export
aggregate_depth_stocks <- function(stocks, depth_intervals = NULL) {
  if (is.null(depth_intervals)) {
    depth_intervals <- get_param("DEPTH_INTERVALS", required = TRUE)
  }

  # Mass-weighted aggregation
  stocks %>%
    left_join(depth_intervals, by = c("depth_top_cm" = "depth_top", "depth_bottom_cm" = "depth_bottom")) %>%
    summarise(
      total_stock = sum(carbon_stock_kg_m2 * thickness_cm / sum(thickness_cm), na.rm = TRUE),
      total_uncertainty = sqrt(sum((carbon_stock_se * thickness_cm / sum(thickness_cm))^2, na.rm = TRUE))
    )
}

# ============================================================================
# DEPTH HARMONIZATION UTILITIES
# ============================================================================

#' Get standard depths for current ecosystem
#'
#' @return Vector of standard depth midpoints
#' @export
get_standard_depths <- function() {
  depths <- get_param("STANDARD_DEPTHS", required = TRUE)
  return(depths)
}

#' Determine if sample requires depth harmonization
#'
#' @param sample_depths Vector of sample depth midpoints
#' @param standard_depths Vector of standard depths
#' @param tolerance Tolerance for matching (cm)
#' @return Logical
#' @export
needs_harmonization <- function(sample_depths, standard_depths = NULL, tolerance = 2) {
  if (is.null(standard_depths)) {
    standard_depths <- get_standard_depths()
  }

  # Check if sample depths match standard depths within tolerance
  all_match <- all(sapply(sample_depths, function(d) {
    any(abs(standard_depths - d) < tolerance)
  }))

  return(!all_match)
}

# ============================================================================
# QUALITY CONTROL UTILITIES
# ============================================================================

#' Flag outliers using Tukey's method
#'
#' @param x Numeric vector
#' @param k Multiplier for IQR (default: 1.5)
#' @return Logical vector of outlier flags
#' @export
flag_outliers_tukey <- function(x, k = 1.5) {
  q <- quantile(x, c(0.25, 0.75), na.rm = TRUE)
  iqr <- q[2] - q[1]
  lower <- q[1] - k * iqr
  upper <- q[2] + k * iqr
  return(x < lower | x > upper)
}

#' Validate SOC values
#'
#' @param soc_g_kg SOC values (g/kg)
#' @param stratum Optional stratum for stratum-specific ranges
#' @return Logical vector of valid flags
#' @export
validate_soc <- function(soc_g_kg, stratum = NULL) {
  soc_min <- get_param("SOC_MIN", default = 0)
  soc_max <- get_param("SOC_MAX", default = 600)

  valid <- soc_g_kg >= soc_min & soc_g_kg <= soc_max

  # Check stratum-specific ranges if available
  if (!is.null(stratum)) {
    soc_ranges <- get_param("SOC_EXPECTED_RANGES")
    if (!is.null(soc_ranges)) {
      for (i in seq_along(soc_g_kg)) {
        if (!is.na(stratum[i]) && stratum[i] %in% names(soc_ranges)) {
          range <- soc_ranges[[stratum[i]]]
          if (soc_g_kg[i] < range[1] || soc_g_kg[i] > range[2]) {
            valid[i] <- FALSE
          }
        }
      }
    }
  }

  return(valid)
}

#' Validate bulk density values
#'
#' @param bd_g_cm3 BD values (g/cm³)
#' @return Logical vector of valid flags
#' @export
validate_bd <- function(bd_g_cm3) {
  bd_min <- get_param("BD_MIN", default = 0.1)
  bd_max <- get_param("BD_MAX", default = 3.0)

  valid <- bd_g_cm3 >= bd_min & bd_g_cm3 <= bd_max
  return(valid)
}

# ============================================================================
# STATISTICAL UTILITIES
# ============================================================================

#' Calculate conservative estimate (lower bound of confidence interval)
#'
#' @param mean Mean value
#' @param se Standard error
#' @param n Sample size
#' @param conf_level Confidence level (default: 0.95)
#' @return Conservative estimate
#' @export
calculate_conservative_estimate <- function(mean, se, n, conf_level = 0.95) {
  t_value <- qt(conf_level + (1 - conf_level) / 2, df = n - 1)
  conservative <- mean - t_value * se
  return(pmax(conservative, 0))  # Don't allow negative
}

#' Calculate required sample size for target precision
#'
#' @param cv Coefficient of variation (%)
#' @param target_precision Target precision (% relative error)
#' @param conf_level Confidence level
#' @return Required sample size
#' @export
calculate_required_n <- function(cv, target_precision, conf_level = 0.95) {
  z_value <- qnorm(conf_level + (1 - conf_level) / 2)
  n <- ceiling((z_value * cv / target_precision)^2)
  return(n)
}

# ============================================================================
# FILE MANAGEMENT UTILITIES
# ============================================================================

#' Create standardized output path
#'
#' @param dir Output directory
#' @param module Module name
#' @param file_type File extension
#' @param suffix Optional suffix
#' @return Full file path
#' @export
create_output_path <- function(dir, module, file_type, suffix = NULL) {
  ecosystem <- get_param("ECOSYSTEM_TYPE", default = "unknown")
  composite <- get_param("COMPOSITE_SAMPLING", default = FALSE)

  base_name <- paste0(
    module, "_",
    ecosystem,
    ifelse(composite, "_composite", "_individual")
  )

  if (!is.null(suffix)) {
    base_name <- paste0(base_name, "_", suffix)
  }

  filename <- paste0(base_name, ".", file_type)
  return(file.path(dir, filename))
}

#' Ensure directory exists
#'
#' @param dir_path Directory path
#' @param recursive Create parent directories if needed
#' @export
ensure_dir <- function(dir_path, recursive = TRUE) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = recursive, showWarnings = FALSE)
  }
}

# ============================================================================
# LOGGING UTILITIES
# ============================================================================

#' Create standardized log message function
#'
#' @param log_file Path to log file
#' @return Log function
#' @export
create_logger <- function(log_file = NULL) {
  if (is.null(log_file)) {
    log_dir <- get_param("DIR_LOGS", default = "logs")
    ensure_dir(log_dir)
    log_file <- file.path(log_dir, paste0("mmrv_", Sys.Date(), ".log"))
  }

  function(msg, level = "INFO") {
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
    cat(log_entry, "\n")
    cat(log_entry, "\n", file = log_file, append = TRUE)
  }
}

# ============================================================================
# DATA VALIDATION UTILITIES
# ============================================================================

#' Validate required columns in data frame
#'
#' @param df Data frame to validate
#' @param required_cols Required column names
#' @param data_name Name of dataset (for error messages)
#' @export
validate_required_columns <- function(df, required_cols, data_name = "data") {
  missing_cols <- setdiff(required_cols, colnames(df))

  if (length(missing_cols) > 0) {
    stop(sprintf(
      "%s is missing required columns: %s",
      data_name,
      paste(missing_cols, collapse = ", ")
    ))
  }

  return(TRUE)
}

#' Check for NA values in critical columns
#'
#' @param df Data frame
#' @param critical_cols Column names to check
#' @return Data frame with NA summary
#' @export
check_na_values <- function(df, critical_cols) {
  na_summary <- sapply(df[critical_cols], function(x) sum(is.na(x)))
  na_df <- data.frame(
    column = names(na_summary),
    n_missing = as.numeric(na_summary),
    pct_missing = round(as.numeric(na_summary) / nrow(df) * 100, 2)
  )

  return(na_df)
}

# ============================================================================
# UNIT CONVERSION UTILITIES
# ============================================================================

#' Convert carbon stock units
#'
#' @param value Numeric value
#' @param from Source unit
#' @param to Target unit
#' @return Converted value
#' @export
convert_carbon_units <- function(value, from, to) {
  conversions <- list(
    # Mass per area
    "kg_m2_to_Mg_ha" = 10,
    "Mg_ha_to_kg_m2" = 0.1,
    "g_m2_to_kg_m2" = 0.001,
    "kg_m2_to_g_m2" = 1000,

    # Concentration
    "g_kg_to_pct" = 0.1,
    "pct_to_g_kg" = 10,
    "g_kg_to_mg_g" = 1,
    "mg_g_to_g_kg" = 1,

    # Bulk density
    "g_cm3_to_kg_m3" = 1000,
    "kg_m3_to_g_cm3" = 0.001
  )

  key <- paste(from, "to", to, sep = "_")

  if (key %in% names(conversions)) {
    return(value * conversions[[key]])
  } else {
    stop(sprintf("Unknown conversion: %s to %s", from, to))
  }
}

# ============================================================================
# SPATIAL UTILITIES
# ============================================================================

#' Transform coordinates to processing CRS
#'
#' @param data Data frame with longitude and latitude
#' @param input_crs Input CRS (default from config)
#' @param output_crs Output CRS (default from config)
#' @return Transformed data with x and y coordinates
#' @export
transform_coordinates <- function(data, input_crs = NULL, output_crs = NULL) {
  if (is.null(input_crs)) {
    input_crs <- get_param("INPUT_CRS", default = 4326)
  }
  if (is.null(output_crs)) {
    output_crs <- get_param("PROCESSING_CRS", default = 3347)
  }

  # Convert to sf object
  data_sf <- sf::st_as_sf(data,
    coords = c("longitude", "latitude"),
    crs = input_crs
  )

  # Transform to processing CRS
  data_transformed <- sf::st_transform(data_sf, crs = output_crs)

  # Extract coordinates
  coords <- sf::st_coordinates(data_transformed)
  data$x <- coords[, 1]
  data$y <- coords[, 2]

  return(data)
}

# ============================================================================
# REPORTING UTILITIES
# ============================================================================

#' Create summary statistics table
#'
#' @param data Data frame
#' @param group_var Grouping variable (e.g., "stratum")
#' @param value_vars Variables to summarize
#' @return Summary table
#' @export
create_summary_table <- function(data, group_var, value_vars) {
  data %>%
    group_by(across(all_of(group_var))) %>%
    summarise(
      across(
        all_of(value_vars),
        list(
          n = ~ sum(!is.na(.)),
          mean = ~ mean(., na.rm = TRUE),
          sd = ~ sd(., na.rm = TRUE),
          se = ~ sd(., na.rm = TRUE) / sqrt(sum(!is.na(.))),
          min = ~ min(., na.rm = TRUE),
          max = ~ max(., na.rm = TRUE)
        ),
        .names = "{.col}_{.fn}"
      ),
      .groups = "drop"
    )
}

# ============================================================================
# WORKFLOW CONTROL UTILITIES
# ============================================================================

#' Check if module should run based on configuration
#'
#' @param module_name Name of module
#' @return Logical
#' @export
should_run_module <- function(module_name) {
  module_flags <- list(
    "flux" = "ENABLE_FLUX_CALCULATIONS",
    "mapping" = "ENABLE_MAPPING",
    "inventory" = "ENABLE_INVENTORY",
    "remote_sensing" = "ENABLE_REMOTE_SENSING",
    "bayesian" = "ENABLE_BAYESIAN",
    "temporal" = "ENABLE_TEMPORAL_ANALYSIS",
    "uncertainty" = "ENABLE_UNCERTAINTY_ANALYSIS"
  )

  if (module_name %in% names(module_flags)) {
    flag <- module_flags[[module_name]]
    return(get_param(flag, default = TRUE))
  }

  # Default: run module if not in list
  return(TRUE)
}

# ============================================================================
# PRINT CONFIGURATION SUMMARY
# ============================================================================

#' Print workflow configuration summary
#'
#' @export
print_config_summary <- function() {
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════════╗\n")
  cat("║           MMRV WORKFLOW CONFIGURATION SUMMARY                 ║\n")
  cat("╚════════════════════════════════════════════════════════════════╝\n")
  cat("\n")
  cat(sprintf("Ecosystem:           %s\n", get_param("ECOSYSTEM_NAME", "Unknown")))
  cat(sprintf("Ecosystem Type:      %s\n", get_param("ECOSYSTEM_TYPE", "unknown")))
  cat(sprintf("Composite Sampling:  %s\n", ifelse(get_param("COMPOSITE_SAMPLING", FALSE), "ENABLED", "DISABLED")))
  cat(sprintf("Project:             %s\n", get_param("PROJECT_NAME", "Unknown")))
  cat(sprintf("Scenario:            %s\n", get_param("PROJECT_SCENARIO", "Unknown")))
  cat(sprintf("Monitoring Year:     %d\n", get_param("MONITORING_YEAR", 0)))
  cat("\n")
}

# ============================================================================
# END OF UTILITY FUNCTIONS
# ============================================================================
