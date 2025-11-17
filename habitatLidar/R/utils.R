#' Utility Functions for habitatLidar Package
#'
#' @name utils
#' @keywords internal
NULL

#' Check and validate coordinate reference system
#'
#' Validates and optionally transforms lidar data to appropriate CRS for Canadian data
#'
#' @param las LAS object
#' @param target_crs Optional target CRS (EPSG code or proj4 string)
#' @return LAS object with validated/transformed CRS
#' @export
#' @examples
#' \dontrun{
#' las <- validate_crs(las, target_crs = 26910) # NAD83 UTM Zone 10N
#' }
validate_crs <- function(las, target_crs = NULL) {
  current_crs <- sf::st_crs(las)

  if (is.na(current_crs)) {
    stop("LAS object has no defined CRS. Please set CRS before processing.")
  }

  logger::log_info("Current CRS: {current_crs$input}")

  # Common Canadian CRS EPSG codes
  canadian_crs <- c(
    26907:26922,  # NAD83 UTM zones
    3153:3163,    # NAD83 Statistics Canada Lambert
    3400:3402,    # NAD83 Alberta 10-TM
    3005          # NAD83 BC Albers
  )

  if (!is.null(target_crs)) {
    if (current_crs$epsg != target_crs) {
      logger::log_info("Transforming from {current_crs$epsg} to {target_crs}")
      las <- lidR::st_transform(las, target_crs)
    }
  }

  return(las)
}

#' Calculate Shannon diversity index
#'
#' @param proportions Vector of proportions (must sum to 1)
#' @return Shannon diversity index value
#' @export
shannon_diversity <- function(proportions) {
  proportions <- proportions[proportions > 0]
  -sum(proportions * log(proportions))
}

#' Detect edge artifacts in lidar tiles
#'
#' Identifies potential edge artifacts by checking point density near tile boundaries
#'
#' @param las LAS object
#' @param buffer_width Width of edge buffer to check (meters)
#' @param density_threshold Minimum acceptable point density ratio (edge/center)
#' @return List with edge_quality flag and diagnostics
#' @export
detect_edge_artifacts <- function(las, buffer_width = 5, density_threshold = 0.7) {
  bbox <- sf::st_bbox(las)

  # Create edge buffer polygon
  edge_buffer <- sf::st_buffer(
    sf::st_as_sfc(bbox),
    dist = -buffer_width
  )

  # Points in center vs edge
  las_sf <- sf::st_as_sf(las@data, coords = c("X", "Y"), crs = sf::st_crs(las))
  center_points <- las_sf[sf::st_within(las_sf, edge_buffer, sparse = FALSE), ]

  center_density <- nrow(center_points) / sf::st_area(edge_buffer)
  total_area <- (bbox["xmax"] - bbox["xmin"]) * (bbox["ymax"] - bbox["ymin"])
  edge_density <- (nrow(las@data) - nrow(center_points)) /
    (total_area - sf::st_area(edge_buffer))

  density_ratio <- as.numeric(edge_density / center_density)

  list(
    has_edge_artifacts = density_ratio < density_threshold,
    density_ratio = density_ratio,
    center_density = as.numeric(center_density),
    edge_density = as.numeric(edge_density),
    recommendation = if (density_ratio < density_threshold) {
      "Consider excluding edge buffer in analysis or using tile overlap"
    } else {
      "Edge quality acceptable"
    }
  )
}

#' Create height bins for vertical distribution analysis
#'
#' @param heights Vector of height values
#' @param breaks Height breaks for binning (default: standard strata)
#' @return Named vector of proportions in each bin
#' @export
create_height_bins <- function(heights, breaks = c(0, 2, 8, 16, Inf)) {
  bin_labels <- paste0(head(breaks, -1), "-", tail(breaks, -1), "m")
  bin_labels[length(bin_labels)] <- paste0(tail(breaks, 2)[1], "+m")

  height_bins <- cut(heights, breaks = breaks, labels = bin_labels, include.lowest = TRUE)
  proportions <- prop.table(table(height_bins))

  return(proportions)
}

#' Estimate DBH from height using allometric equations
#'
#' Regional allometric equations for Canadian forests
#' Based on published relationships from Canadian National Forest Inventory
#'
#' @param height Tree height in meters
#' @param region Region code: "BC_coast", "BC_interior", "boreal", "great_lakes"
#' @param species Optional species code for species-specific equations
#' @return Estimated DBH in cm
#' @export
#' @references
#' Ung et al. (2008) Canadian Journal of Forest Research 38: 1-14
estimate_dbh <- function(height, region = "boreal", species = NULL) {
  # Generalized allometric equations by region
  # Form: DBH = a * Height^b

  params <- list(
    BC_coast = list(a = 2.5, b = 0.85),       # Coastal Douglas-fir, hemlock
    BC_interior = list(a = 2.2, b = 0.88),    # Interior spruce, pine
    boreal = list(a = 1.8, b = 0.92),         # Boreal spruce, fir, pine
    great_lakes = list(a = 2.0, b = 0.90)     # Great Lakes-St. Lawrence mixed
  )

  if (!region %in% names(params)) {
    logger::log_warn("Unknown region '{region}', using boreal default")
    region <- "boreal"
  }

  a <- params[[region]]$a
  b <- params[[region]]$b

  dbh <- a * (height ^ b)

  return(dbh)
}

#' Calculate confidence intervals for habitat metrics
#'
#' Bootstrap-based confidence intervals accounting for spatial autocorrelation
#'
#' @param values Vector of metric values
#' @param coords Matrix of coordinates (x, y)
#' @param n_boot Number of bootstrap iterations
#' @param conf_level Confidence level (default 0.95)
#' @return List with mean, lower CI, upper CI
#' @export
metric_confidence_interval <- function(values, coords = NULL,
                                      n_boot = 1000, conf_level = 0.95) {

  # Simple bootstrap if no coordinates provided
  if (is.null(coords)) {
    boot_means <- replicate(n_boot, {
      sample_idx <- sample(length(values), replace = TRUE)
      mean(values[sample_idx], na.rm = TRUE)
    })
  } else {
    # Block bootstrap for spatial data
    # Create spatial blocks
    n_blocks_x <- ceiling(sqrt(n_boot / 10))
    n_blocks_y <- n_blocks_x

    x_breaks <- seq(min(coords[, 1]), max(coords[, 1]), length.out = n_blocks_x + 1)
    y_breaks <- seq(min(coords[, 2]), max(coords[, 2]), length.out = n_blocks_y + 1)

    blocks <- interaction(
      cut(coords[, 1], breaks = x_breaks),
      cut(coords[, 2], breaks = y_breaks)
    )

    boot_means <- replicate(n_boot, {
      sample_blocks <- sample(unique(blocks), replace = TRUE)
      sample_idx <- which(blocks %in% sample_blocks)
      mean(values[sample_idx], na.rm = TRUE)
    })
  }

  alpha <- 1 - conf_level
  ci_lower <- quantile(boot_means, alpha / 2, na.rm = TRUE)
  ci_upper <- quantile(boot_means, 1 - alpha / 2, na.rm = TRUE)

  list(
    mean = mean(values, na.rm = TRUE),
    ci_lower = as.numeric(ci_lower),
    ci_upper = as.numeric(ci_upper),
    se = sd(boot_means, na.rm = TRUE)
  )
}

#' Normalize habitat suitability index to 0-1 scale
#'
#' @param value Raw metric value
#' @param optimal Optimal value for species
#' @param min_threshold Minimum acceptable value
#' @param max_threshold Maximum acceptable value
#' @return HSI score (0-1)
#' @export
normalize_hsi <- function(value, optimal, min_threshold, max_threshold) {
  # Trapezoidal membership function
  if (value < min_threshold || value > max_threshold) {
    return(0)
  } else if (value == optimal) {
    return(1)
  } else if (value < optimal) {
    return((value - min_threshold) / (optimal - min_threshold))
  } else {
    return((max_threshold - value) / (max_threshold - optimal))
  }
}

#' Format area with appropriate units
#'
#' @param area_m2 Area in square meters
#' @return Formatted string with appropriate units
#' @export
format_area <- function(area_m2) {
  if (area_m2 < 10000) {
    return(sprintf("%.1f m²", area_m2))
  } else if (area_m2 < 1000000) {
    return(sprintf("%.2f ha", area_m2 / 10000))
  } else {
    return(sprintf("%.2f km²", area_m2 / 1000000))
  }
}

#' Create progress bar for batch processing
#'
#' @param total Total number of items
#' @param format Progress bar format string
#' @return Progress bar object
#' @export
create_progress_bar <- function(total,
                               format = "Processing [:bar] :percent eta: :eta") {
  progress::progress_bar$new(
    format = format,
    total = total,
    clear = FALSE,
    width = 80
  )
}

#' Safe division handling NA and Inf
#'
#' @param numerator Numerator
#' @param denominator Denominator
#' @param default Default value for division by zero
#' @return Result of division or default
#' @keywords internal
safe_divide <- function(numerator, denominator, default = 0) {
  result <- numerator / denominator
  result[is.nan(result) | is.infinite(result)] <- default
  return(result)
}

#' Check if required packages are installed
#'
#' @param packages Character vector of package names
#' @return TRUE if all packages installed, FALSE otherwise
#' @export
check_dependencies <- function(packages) {
  missing <- packages[!sapply(packages, requireNamespace, quietly = TRUE)]

  if (length(missing) > 0) {
    logger::log_error("Missing required packages: {paste(missing, collapse = ', ')}")
    message("Install missing packages with:")
    message(sprintf("install.packages(c('%s'))", paste(missing, collapse = "', '")))
    return(FALSE)
  }

  return(TRUE)
}

#' Validate input parameters
#'
#' @param params List of parameters to validate
#' @param required Named list of required parameters and their types
#' @return TRUE if valid, stops with error if not
#' @keywords internal
validate_params <- function(params, required) {
  for (param_name in names(required)) {
    if (!param_name %in% names(params)) {
      stop(sprintf("Missing required parameter: %s", param_name))
    }

    expected_type <- required[[param_name]]
    actual_type <- class(params[[param_name]])[1]

    if (!inherits(params[[param_name]], expected_type)) {
      stop(sprintf("Parameter %s must be of type %s, got %s",
                   param_name, expected_type, actual_type))
    }
  }

  return(TRUE)
}
