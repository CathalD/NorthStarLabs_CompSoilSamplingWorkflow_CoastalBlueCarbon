#' Understory Vegetation Metrics Functions
#'
#' Functions for characterizing understory vegetation structure,
#' critical for browse habitat and wildlife movement
#'
#' @name metrics_understory
NULL

#' Calculate understory density metrics
#'
#' Point density in the understory layer (critical for browse habitat)
#'
#' @param z Vector of height values
#' @param min_height Minimum height for understory (default 0.5m)
#' @param max_height Maximum height for understory (default 4m)
#' @param ... Additional arguments
#' @return List with understory density metrics
#' @export
metric_understory_density <- function(z, min_height = 0.5, max_height = 4, ...) {
  understory_points <- z >= min_height & z <= max_height
  total_points <- length(z)

  list(
    understory_density_pct = sum(understory_points) / total_points * 100,
    understory_points = sum(understory_points),
    points_per_m2 = sum(understory_points) / (total_points / 4)  # Assuming ~4 pts/m²
  )
}

#' Calculate understory cover percentage
#'
#' Proportion of area with understory vegetation
#'
#' @param z Vector of height values
#' @param x X coordinates (optional, for spatial analysis)
#' @param y Y coordinates (optional, for spatial analysis)
#' @param min_height Minimum height (default 0.5m)
#' @param max_height Maximum height (default 4m)
#' @param ... Additional arguments
#' @return List with cover metrics
#' @export
metric_understory_cover <- function(z, x = NULL, y = NULL,
                                   min_height = 0.5, max_height = 4, ...) {
  understory <- z >= min_height & z <= max_height

  cover_pct <- sum(understory) / length(z) * 100

  list(
    understory_cover_pct = cover_pct,
    has_understory = cover_pct > 10  # Threshold for presence
  )
}

#' Calculate shrub layer structure
#'
#' Characterizes the 2-8m height class important for various wildlife species
#'
#' @param z Vector of height values
#' @param min_height Minimum shrub height (default 2m)
#' @param max_height Maximum shrub height (default 8m)
#' @param ... Additional arguments
#' @return List with shrub layer metrics
#' @export
metric_shrub_layer <- function(z, min_height = 2, max_height = 8, ...) {
  shrub_points <- z >= min_height & z <= max_height
  canopy_points <- z > max_height
  total_points <- length(z)

  list(
    shrub_density_pct = sum(shrub_points) / total_points * 100,
    shrub_to_canopy_ratio = safe_divide(sum(shrub_points), sum(canopy_points)),
    shrub_height_mean = if (sum(shrub_points) > 0) mean(z[shrub_points]) else 0,
    shrub_height_max = if (sum(shrub_points) > 0) max(z[shrub_points]) else 0
  )
}

#' Calculate browse layer metrics (moose, deer)
#'
#' Specific metrics for browse-height vegetation (typically 0.5-3m)
#'
#' @param z Vector of height values
#' @param species Target species: "moose", "deer", "caribou"
#' @param ... Additional arguments
#' @return List with browse metrics
#' @export
metric_browse <- function(z, species = "moose", ...) {
  # Species-specific browse height ranges
  browse_range <- switch(species,
    "moose" = c(0.5, 3.5),
    "deer" = c(0.5, 2.5),
    "caribou" = c(0.2, 1.5),  # Lichen and low vegetation
    c(0.5, 3.0)  # Default
  )

  browse_points <- z >= browse_range[1] & z <= browse_range[2]
  total_points <- length(z)

  list(
    browse_density_pct = sum(browse_points) / total_points * 100,
    browse_points = sum(browse_points),
    browse_height_mean = if (sum(browse_points) > 0) mean(z[browse_points]) else 0,
    optimal_browse_presence = sum(browse_points) / total_points > 0.15,  # 15% threshold
    species = species
  )
}

#' Calculate understory openness
#'
#' Measure of how open the understory is for wildlife movement
#'
#' @param z Vector of height values
#' @param movement_height Maximum height for movement corridor (default 2m)
#' @param ... Additional arguments
#' @return List with openness metrics
#' @export
metric_understory_openness <- function(z, movement_height = 2, ...) {
  ground_to_movement <- z < movement_height
  total_points <- length(z)

  openness <- sum(ground_to_movement) / total_points

  list(
    understory_openness = openness,
    movement_difficulty = 1 - openness,
    passable = openness > 0.6  # >60% open considered passable
  )
}

#' Identify berry-producing shrub habitat
#'
#' Metrics for habitat that may support berry-producing shrubs
#' Important for bear and small mammal habitat
#'
#' @param z Vector of height values
#' @param canopy_cover Canopy closure above (0-1)
#' @param ... Additional arguments
#' @return List with berry habitat metrics
#' @export
metric_berry_habitat <- function(z, canopy_cover = NULL, ...) {
  # Berry shrubs typically 0.5-2.5m with moderate canopy opening
  berry_height <- z >= 0.5 & z <= 2.5
  berry_density <- sum(berry_height) / length(z)

  # Optimal canopy cover for berry production: 30-60%
  if (!is.null(canopy_cover)) {
    canopy_suitable <- canopy_cover >= 0.30 & canopy_cover <= 0.60
    suitability <- berry_density * ifelse(canopy_suitable, 1, 0.5)
  } else {
    suitability <- berry_density
  }

  list(
    berry_height_density = berry_density,
    berry_habitat_suitability = suitability,
    optimal_structure = berry_density > 0.2 & suitability > 0.2
  )
}

#' Calculate vertical layering in understory
#'
#' Identifies distinct vegetation layers in the understory
#'
#' @param z Vector of height values
#' @param ... Additional arguments
#' @return List with layering metrics
#' @export
metric_understory_layers <- function(z, ...) {
  # Define layers
  ground <- sum(z >= 0 & z < 0.5)
  low <- sum(z >= 0.5 & z < 1.5)
  mid <- sum(z >= 1.5 & z < 3.0)
  tall_shrub <- sum(z >= 3.0 & z < 5.0)
  total <- length(z)

  # Calculate proportions
  props <- c(ground, low, mid, tall_shrub) / total

  # Layer diversity (Shannon)
  diversity <- shannon_diversity(props[props > 0])

  list(
    layer_ground_pct = props[1] * 100,
    layer_low_pct = props[2] * 100,
    layer_mid_pct = props[3] * 100,
    layer_tall_shrub_pct = props[4] * 100,
    layer_diversity = diversity,
    n_layers_present = sum(props > 0.05)  # Layers with >5% cover
  )
}

#' Detect regeneration patches
#'
#' Identifies areas with dense young vegetation (1-5m)
#' Important for browse habitat and post-disturbance recovery
#'
#' @param z Vector of height values
#' @param x X coordinates (optional)
#' @param y Y coordinates (optional)
#' @param ... Additional arguments
#' @return List with regeneration metrics
#' @export
metric_regeneration <- function(z, x = NULL, y = NULL, ...) {
  regen_height <- z >= 1 & z <= 5
  regen_density <- sum(regen_height) / length(z)

  list(
    regeneration_density_pct = regen_density * 100,
    regeneration_present = regen_density > 0.15,
    regeneration_height_mean = if (sum(regen_height) > 0) mean(z[regen_height]) else 0,
    regeneration_height_max = if (sum(regen_height) > 0) max(z[regen_height]) else 0
  )
}

#' Calculate thermal cover quality
#'
#' Assesses understory structure for providing thermal cover to wildlife
#' Combination of canopy closure and understory density
#'
#' @param z Vector of height values
#' @param canopy_height Mean canopy height
#' @param ... Additional arguments
#' @return List with thermal cover metrics
#' @export
metric_thermal_cover <- function(z, canopy_height = NULL, ...) {
  # Understory 0.5-4m
  understory <- z >= 0.5 & z <= 4
  understory_density <- sum(understory) / length(z)

  # Mid-story 4-15m
  midstory <- z > 4 & z <= 15
  midstory_density <- sum(midstory) / length(z)

  # Thermal cover score: combination of layers
  # Good thermal cover has both understory and midstory/canopy
  thermal_score <- (understory_density + midstory_density) / 2

  list(
    thermal_cover_score = thermal_score,
    thermal_cover_quality = case_when(
      thermal_score >= 0.5 ~ "High",
      thermal_score >= 0.3 ~ "Moderate",
      thermal_score >= 0.15 ~ "Low",
      TRUE ~ "Poor"
    ),
    understory_component = understory_density,
    midstory_component = midstory_density
  )
}

#' Calculate understory complexity index
#'
#' Composite measure of understory structural diversity
#'
#' @param z Vector of height values
#' @param x X coordinates (optional)
#' @param y Y coordinates (optional)
#' @param ... Additional arguments
#' @return List with complexity metrics
#' @export
metric_understory_complexity <- function(z, x = NULL, y = NULL, ...) {
  # Filter to understory heights
  understory_z <- z[z >= 0.5 & z <= 4]

  if (length(understory_z) < 10) {
    return(list(
      understory_complexity = 0,
      sufficient_data = FALSE
    ))
  }

  # Height diversity within understory
  height_cv <- sd(understory_z) / mean(understory_z)

  # Layer diversity
  layer_metrics <- metric_understory_layers(z)
  layer_diversity <- layer_metrics$layer_diversity

  # Density variation (if spatial data available)
  if (!is.null(x) && !is.null(y)) {
    # Simple spatial variation metric
    spatial_cv <- 0.5  # Placeholder - would need proper spatial analysis
  } else {
    spatial_cv <- 0
  }

  # Composite complexity
  complexity <- (
    min(height_cv, 1) +
    min(layer_diversity / 2, 1) +
    spatial_cv
  ) / 3

  list(
    understory_complexity = complexity,
    height_variation = height_cv,
    layer_diversity_component = layer_diversity,
    sufficient_data = TRUE
  )
}

#' Calculate all understory metrics
#'
#' Wrapper function for comprehensive understory assessment
#'
#' @param x X coordinates
#' @param y Y coordinates
#' @param z Z coordinates (heights)
#' @param species Target species for browse assessment
#' @param ... Additional arguments
#' @return List with all understory metrics
#' @export
calculate_understory_metrics <- function(x, y, z, species = "moose", ...) {
  if (length(z) < 5) {
    return(list(
      sufficient_data = FALSE,
      n_points = length(z)
    ))
  }

  # Calculate canopy cover for context
  canopy_cover <- sum(z >= 5) / length(z)

  metrics <- c(
    list(sufficient_data = TRUE, n_points = length(z)),
    metric_understory_density(z),
    metric_understory_cover(z, x, y),
    metric_shrub_layer(z),
    metric_browse(z, species),
    metric_understory_openness(z),
    metric_berry_habitat(z, canopy_cover),
    metric_understory_layers(z),
    metric_regeneration(z, x, y),
    metric_thermal_cover(z),
    metric_understory_complexity(z, x, y)
  )

  return(metrics)
}

#' Generate gridded understory metrics
#'
#' Calculate understory metrics across a regular grid
#'
#' @param las LAS object (height-normalized)
#' @param res Grid resolution in meters (default 10m for understory)
#' @param species Target species for browse metrics
#' @return SpatRaster stack with all metrics
#' @export
#' @examples
#' \dontrun{
#' understory_raster <- generate_understory_metrics_grid(las, res = 10, species = "moose")
#' terra::plot(understory_raster[["browse_density_pct"]])
#' }
generate_understory_metrics_grid <- function(las, res = 10, species = "moose") {
  logger::log_info("Calculating understory metrics at {res}m resolution for {species}")

  metrics <- lidR::pixel_metrics(
    las,
    ~calculate_understory_metrics(X, Y, Z, species = species),
    res = res
  )

  logger::log_info("Understory metrics calculated: {length(names(metrics))} layers")

  return(metrics)
}

#' Identify browse patches
#'
#' Delineates contiguous areas with high browse availability
#'
#' @param browse_raster Raster of browse density
#' @param threshold Minimum browse density for patch (default 20%)
#' @param min_size Minimum patch size in m² (default 100)
#' @return sf object with browse patches
#' @export
identify_browse_patches <- function(browse_raster, threshold = 20, min_size = 100) {
  logger::log_info("Identifying browse patches (threshold: {threshold}%, min size: {min_size}m²)")

  # Create binary raster
  browse_binary <- browse_raster >= threshold

  # Convert to polygons
  browse_poly <- terra::as.polygons(browse_binary, values = TRUE)

  # Filter to patches with value = 1 (high browse)
  browse_poly <- browse_poly[browse_poly[[1]] == 1, ]

  # Convert to sf
  browse_sf <- sf::st_as_sf(browse_poly)

  # Calculate area and filter
  browse_sf$area_m2 <- as.numeric(sf::st_area(browse_sf))
  browse_sf <- browse_sf[browse_sf$area_m2 >= min_size, ]

  logger::log_info("Identified {nrow(browse_sf)} browse patches")

  return(browse_sf)
}

#' Case-when helper function
#'
#' @param ... Conditions and values
#' @return Matched value
#' @keywords internal
case_when <- function(...) {
  dots <- list(...)
  n <- length(dots)

  for (i in seq(1, n, 2)) {
    if (i == n) {  # TRUE condition (default)
      return(dots[[i]])
    }

    if (dots[[i]]) {
      return(dots[[i + 1]])
    }
  }

  return(NA)
}
