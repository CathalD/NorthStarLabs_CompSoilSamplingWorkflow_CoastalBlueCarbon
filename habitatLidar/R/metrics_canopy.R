#' Canopy Structure Metrics Functions
#'
#' @name metrics_canopy
NULL

#' Calculate canopy height metrics
#'
#' Standard height statistics for forest characterization
#'
#' @param z Vector of height values (or LAS object)
#' @param dz Unused (for compatibility with lidR)
#' @param ... Additional arguments
#' @return List of height metrics
#' @export
metric_height <- function(z, dz = NULL, ...) {
  list(
    height_max = max(z),
    height_mean = mean(z),
    height_median = median(z),
    height_sd = sd(z),
    height_cv = sd(z) / mean(z),
    height_p25 = quantile(z, 0.25),
    height_p75 = quantile(z, 0.75),
    height_p95 = quantile(z, 0.95),
    height_p99 = quantile(z, 0.99)
  )
}

#' Calculate canopy cover percentage
#'
#' Proportion of points above a height threshold
#'
#' @param z Vector of height values
#' @param threshold Minimum height for canopy (default 2m)
#' @param ... Additional arguments
#' @return List with canopy cover metrics
#' @export
metric_canopy_cover <- function(z, threshold = 2, ...) {
  above_threshold <- z >= threshold
  total_returns <- length(z)

  list(
    canopy_cover_pct = sum(above_threshold) / total_returns * 100,
    canopy_points = sum(above_threshold),
    total_points = total_returns
  )
}

#' Calculate rumple index (canopy surface complexity)
#'
#' Ratio of canopy surface area to ground area. Higher values indicate
#' more complex, heterogeneous canopy structure.
#'
#' @param x X coordinates
#' @param y Y coordinates
#' @param z Z coordinates (heights)
#' @param ... Additional arguments
#' @return List with rumple index
#' @export
#' @references
#' Kane et al. (2010) "Examining conifer canopy structural complexity across
#' forest ages and elevations with LiDAR data" Can. J. For. Res. 40: 774-787
metric_rumple <- function(x, y, z, ...) {
  # Create 3D surface using Delaunay triangulation
  if (length(x) < 4) {
    return(list(rumple_index = NA))
  }

  tryCatch({
    # Create convex hull for ground area
    hull_points <- grDevices::chull(x, y)
    hull_coords <- cbind(x[hull_points], y[hull_points])
    ground_area <- geometry::polyarea(hull_coords[, 1], hull_coords[, 2])

    # Create 3D mesh of canopy surface
    points_3d <- cbind(x, y, z)
    mesh <- geometry::delaunayn(points_3d[, 1:2])

    # Calculate surface area of each triangle
    surface_area <- 0
    for (i in 1:nrow(mesh)) {
      idx <- mesh[i, ]
      p1 <- points_3d[idx[1], ]
      p2 <- points_3d[idx[2], ]
      p3 <- points_3d[idx[3], ]

      # Triangle area using cross product
      v1 <- p2 - p1
      v2 <- p3 - p1
      cross_prod <- c(
        v1[2] * v2[3] - v1[3] * v2[2],
        v1[3] * v2[1] - v1[1] * v2[3],
        v1[1] * v2[2] - v1[2] * v2[1]
      )
      surface_area <- surface_area + sqrt(sum(cross_prod^2)) / 2
    }

    rumple <- surface_area / ground_area

    list(
      rumple_index = rumple,
      surface_area = surface_area,
      ground_area = ground_area
    )
  }, error = function(e) {
    list(rumple_index = NA)
  })
}

#' Calculate vertical distribution ratio (VDR)
#'
#' Distribution of points across standard height strata
#'
#' @param z Vector of height values
#' @param breaks Height breaks (default: 0, 2, 8, 16, Inf)
#' @param ... Additional arguments
#' @return List with VDR metrics
#' @export
metric_vdr <- function(z, breaks = c(0, 2, 8, 16, Inf), ...) {
  bins <- create_height_bins(z, breaks)

  metrics <- list(
    vdr_ground_2m = as.numeric(bins[1]),
    vdr_2_8m = as.numeric(bins[2]),
    vdr_8_16m = if (length(bins) >= 3) as.numeric(bins[3]) else 0,
    vdr_16plus = if (length(bins) >= 4) as.numeric(bins[4]) else 0
  )

  return(metrics)
}

#' Calculate foliage height diversity (Shannon index)
#'
#' Shannon diversity index applied to vertical vegetation strata
#'
#' @param z Vector of height values
#' @param breaks Height breaks for strata
#' @param ... Additional arguments
#' @return List with diversity metrics
#' @export
#' @references
#' MacArthur & MacArthur (1961) "On bird species diversity" Ecology 42: 594-598
metric_fhd <- function(z, breaks = seq(0, max(z), by = 2), ...) {
  if (max(z) == 0) {
    return(list(fhd = 0))
  }

  # Ensure breaks cover full range
  if (max(breaks) < max(z)) {
    breaks <- c(breaks, max(z) + 1)
  }

  bins <- cut(z, breaks = breaks, include.lowest = TRUE)
  proportions <- prop.table(table(bins))
  proportions <- proportions[proportions > 0]

  fhd <- shannon_diversity(as.numeric(proportions))

  list(
    fhd = fhd,
    n_strata = length(proportions)
  )
}

#' Calculate canopy gap fraction by height layer
#'
#' @param z Vector of height values
#' @param height_layer Height of layer to assess (default 10m)
#' @param cell_size Grid cell size for gap detection (meters)
#' @param ... Additional arguments
#' @return List with gap metrics
#' @export
metric_gaps <- function(z, height_layer = 10, cell_size = 5, ...) {
  # Simplified version - in practice would use spatial binning
  above_layer <- sum(z >= height_layer)
  total <- length(z)

  list(
    gap_fraction = 1 - (above_layer / total),
    canopy_fraction = above_layer / total
  )
}

#' Calculate crown closure at multiple heights
#'
#' @param z Vector of height values
#' @param heights Vector of heights to calculate closure (default: 2, 5, 10m)
#' @param ... Additional arguments
#' @return List with closure at each height
#' @export
metric_crown_closure <- function(z, heights = c(2, 5, 10), ...) {
  metrics <- list()

  for (h in heights) {
    above_h <- sum(z >= h)
    closure <- above_h / length(z)
    metric_name <- sprintf("crown_closure_%dm", h)
    metrics[[metric_name]] <- closure
  }

  return(metrics)
}

#' Detect large trees (old-growth indicators)
#'
#' Identifies locations of exceptionally tall trees
#'
#' @param chm Canopy height model (SpatRaster)
#' @param thresholds Height thresholds (default: 25, 30, 35m)
#' @return List with count of large trees at each threshold
#' @export
metric_large_trees <- function(chm, thresholds = c(25, 30, 35)) {
  metrics <- list()

  for (threshold in thresholds) {
    # Find local maxima above threshold
    large_tree_mask <- chm >= threshold

    # Simple count (in practice would use proper local maxima detection)
    n_cells <- sum(terra::values(large_tree_mask), na.rm = TRUE)

    metric_name <- sprintf("large_trees_%dm", threshold)
    metrics[[metric_name]] <- n_cells
  }

  return(metrics)
}

#' Calculate structural complexity index
#'
#' Composite index combining height diversity, vertical distribution,
#' and canopy heterogeneity
#'
#' @param z Vector of height values
#' @param x X coordinates (optional, for rumple)
#' @param y Y coordinates (optional, for rumple)
#' @param ... Additional arguments
#' @return List with complexity metrics
#' @export
metric_structural_complexity <- function(z, x = NULL, y = NULL, ...) {
  # Height diversity component
  fhd_result <- metric_fhd(z)
  height_diversity <- fhd_result$fhd

  # Vertical distribution component
  vdr_result <- metric_vdr(z)
  # Evenness across strata
  vdr_values <- unlist(vdr_result)
  vertical_evenness <- 1 - abs(0.25 - mean(vdr_values))  # Deviation from uniform

  # Height variation component
  cv_height <- sd(z) / mean(z)

  # Rumple component (if coordinates available)
  if (!is.null(x) && !is.null(y)) {
    rumple_result <- metric_rumple(x, y, z)
    rumple <- ifelse(is.na(rumple_result$rumple_index), 1, rumple_result$rumple_index)
  } else {
    rumple <- 1
  }

  # Composite index (normalized 0-1, higher = more complex)
  sci <- (
    (height_diversity / 3) +  # FHD typically 0-3
    vertical_evenness +
    (min(cv_height, 1)) +
    (min((rumple - 1) / 2, 1))  # Rumple >1, normalize
  ) / 4

  list(
    structural_complexity_index = sci,
    height_diversity = height_diversity,
    vertical_evenness = vertical_evenness,
    height_cv = cv_height,
    rumple_contribution = if (!is.null(x)) rumple else NA
  )
}

#' Detect potential snags (standing dead trees)
#'
#' Identifies isolated tall points with low return density
#'
#' @param x X coordinates
#' @param y Y coordinates
#' @param z Z coordinates
#' @param return_number Return number
#' @param min_height Minimum height for snag (default 10m)
#' @param ... Additional arguments
#' @return List with snag metrics
#' @export
metric_snags <- function(x, y, z, return_number, min_height = 10, ...) {
  # Simple heuristic: tall single returns with sparse neighbors
  tall_points <- z >= min_height
  single_returns <- return_number == 1

  potential_snags <- tall_points & single_returns

  list(
    potential_snag_points = sum(potential_snags),
    snag_density_per_ha = sum(potential_snags) / (length(z) / 10000)  # Rough estimate
  )
}

#' Calculate canopy openness index
#'
#' Measure of canopy openness based on vertical point distribution
#'
#' @param z Vector of height values
#' @param canopy_threshold Minimum height for canopy (default 5m)
#' @param ... Additional arguments
#' @return List with openness metrics
#' @export
metric_openness <- function(z, canopy_threshold = 5, ...) {
  canopy_points <- sum(z >= canopy_threshold)
  understory_points <- sum(z < canopy_threshold & z >= 0.5)
  total_points <- length(z)

  openness <- 1 - (canopy_points / total_points)

  list(
    canopy_openness = openness,
    canopy_density = canopy_points / total_points,
    understory_to_canopy_ratio = safe_divide(understory_points, canopy_points, default = 0)
  )
}

#' Calculate all canopy metrics for a grid cell
#'
#' Wrapper function that calculates comprehensive canopy metrics
#'
#' @param x X coordinates
#' @param y Y coordinates
#' @param z Z coordinates (heights)
#' @param return_number Return number
#' @param ... Additional arguments
#' @return List with all canopy metrics
#' @export
calculate_canopy_metrics <- function(x, y, z, return_number, ...) {
  # Filter for valid heights (above ground)
  valid <- z >= 0.5  # Minimum vegetation height

  if (sum(valid) < 3) {
    return(list(
      sufficient_data = FALSE,
      n_points = length(z)
    ))
  }

  x_valid <- x[valid]
  y_valid <- y[valid]
  z_valid <- z[valid]
  return_valid <- return_number[valid]

  # Calculate all metric groups
  metrics <- c(
    list(sufficient_data = TRUE, n_points = length(z)),
    metric_height(z_valid),
    metric_canopy_cover(z_valid),
    metric_vdr(z_valid),
    metric_fhd(z_valid),
    metric_crown_closure(z_valid),
    metric_structural_complexity(z_valid, x_valid, y_valid),
    metric_openness(z_valid),
    metric_snags(x_valid, y_valid, z_valid, return_valid)
  )

  return(metrics)
}

#' Generate gridded canopy metrics
#'
#' Calculate canopy metrics across a regular grid
#'
#' @param las LAS object (height-normalized)
#' @param res Grid resolution in meters (default 20m)
#' @return SpatRaster stack with all metrics
#' @export
#' @examples
#' \dontrun{
#' metrics_raster <- generate_canopy_metrics_grid(las, res = 20)
#' terra::plot(metrics_raster[["height_max"]])
#' }
generate_canopy_metrics_grid <- function(las, res = 20) {
  logger::log_info("Calculating canopy metrics at {res}m resolution")

  # Use lidR's pixel_metrics for efficient grid calculation
  metrics <- lidR::pixel_metrics(
    las,
    ~calculate_canopy_metrics(X, Y, Z, ReturnNumber),
    res = res
  )

  logger::log_info("Canopy metrics calculated: {length(names(metrics))} layers")

  return(metrics)
}

#' Extract canopy metrics for areas of interest
#'
#' Summarize canopy metrics within polygons (e.g., habitat patches, plots)
#'
#' @param las LAS object
#' @param polygons sf object with polygons
#' @param id_field Field name for polygon IDs
#' @return Data frame with metrics per polygon
#' @export
extract_canopy_metrics_aoi <- function(las, polygons, id_field = "id") {
  logger::log_info("Extracting canopy metrics for {nrow(polygons)} polygons")

  results <- list()

  for (i in 1:nrow(polygons)) {
    poly <- polygons[i, ]
    poly_id <- poly[[id_field]]

    # Clip LAS to polygon
    las_clip <- lidR::clip_roi(las, poly)

    if (nrow(las_clip@data) < 10) {
      logger::log_warn("Polygon {poly_id}: insufficient points ({nrow(las_clip@data)})")
      next
    }

    # Calculate metrics
    metrics <- calculate_canopy_metrics(
      las_clip@data$X,
      las_clip@data$Y,
      las_clip@data$Z,
      las_clip@data$ReturnNumber
    )

    metrics$polygon_id <- poly_id
    metrics$area_m2 <- as.numeric(sf::st_area(poly))

    results[[i]] <- as.data.frame(metrics)
  }

  # Combine results
  results_df <- dplyr::bind_rows(results)

  logger::log_info("Metrics extracted for {nrow(results_df)} polygons")

  return(results_df)
}
