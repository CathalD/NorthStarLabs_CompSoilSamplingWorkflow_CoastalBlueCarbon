#' Species-Specific Habitat Suitability Models
#'
#' @name habitat_models
NULL

#' Calculate moose browse habitat suitability
#'
#' HSI based on browse availability, canopy closure, and thermal cover
#'
#' @param canopy_metrics Data frame with canopy metrics
#' @param understory_metrics Data frame with understory metrics
#' @param season Season: "winter" or "summer"
#' @return Vector of HSI scores (0-1)
#' @export
#' @references
#' Peek et al. (1982) "Moose habitat selection and use in north-central Idaho"
#' Journal of Wildlife Management 46(1): 145-153
hsi_moose_browse <- function(canopy_metrics, understory_metrics, season = "winter") {
  logger::log_info("Calculating moose browse habitat suitability ({season})")

  # Browse availability (most important for winter)
  # Optimal: 20-40% browse density
  browse_si <- sapply(understory_metrics$browse_density_pct, function(x) {
    normalize_hsi(x, optimal = 30, min_threshold = 10, max_threshold = 60)
  })

  # Canopy closure (provides thermal cover, browse production)
  # Optimal: 40-70% for winter, 30-60% for summer
  if (season == "winter") {
    canopy_optimal <- 55
    canopy_min <- 30
    canopy_max <- 80
  } else {
    canopy_optimal <- 45
    canopy_min <- 20
    canopy_max <- 70
  }

  canopy_si <- sapply(canopy_metrics$canopy_cover_pct, function(x) {
    normalize_hsi(x, optimal = canopy_optimal,
                 min_threshold = canopy_min, max_threshold = canopy_max)
  })

  # Understory openness (for movement)
  # Moose prefer some openness but not completely open
  openness_si <- sapply(understory_metrics$understory_openness, function(x) {
    normalize_hsi(x * 100, optimal = 50, min_threshold = 30, max_threshold = 80)
  })

  # Shrub layer (2-4m) - important for winter browse
  shrub_si <- sapply(understory_metrics$shrub_density_pct, function(x) {
    normalize_hsi(x, optimal = 25, min_threshold = 10, max_threshold = 50)
  })

  # Weighted composite HSI
  if (season == "winter") {
    # Winter: browse and thermal cover most important
    hsi <- (browse_si * 0.4 + canopy_si * 0.3 + shrub_si * 0.2 + openness_si * 0.1)
  } else {
    # Summer: more emphasis on browse diversity
    hsi <- (browse_si * 0.35 + canopy_si * 0.25 + shrub_si * 0.25 + openness_si * 0.15)
  }

  return(hsi)
}

#' Calculate caribou habitat suitability
#'
#' HSI for boreal/mountain caribou emphasizing old-growth structure and lichen
#'
#' @param canopy_metrics Data frame with canopy metrics
#' @param understory_metrics Data frame with understory metrics
#' @param habitat_type "boreal" or "mountain"
#' @param disturbance_distance Optional distance to disturbance (km)
#' @return Vector of HSI scores (0-1)
#' @export
#' @references
#' Apps et al. (2001) "Identifying habitat for threatened species using
#' resource selection functions" Landscape Ecology 16: 523-536
hsi_caribou <- function(canopy_metrics, understory_metrics,
                       habitat_type = "boreal", disturbance_distance = NULL) {
  logger::log_info("Calculating caribou habitat suitability ({habitat_type})")

  # Old-growth structure (critical for caribou)
  # Prefer tall, complex forests
  structure_si <- sapply(canopy_metrics$structural_complexity_index, function(x) {
    normalize_hsi(x, optimal = 0.7, min_threshold = 0.4, max_threshold = 1.0)
  })

  # Canopy height (taller = older)
  height_si <- sapply(canopy_metrics$height_mean, function(x) {
    if (habitat_type == "mountain") {
      normalize_hsi(x, optimal = 20, min_threshold = 12, max_threshold = 30)
    } else {
      normalize_hsi(x, optimal = 18, min_threshold = 10, max_threshold = 25)
    }
  })

  # Low understory density (lichen habitat - open understory)
  # Caribou prefer sparse understory for lichen growth
  understory_si <- sapply(understory_metrics$understory_density_pct, function(x) {
    # Lower is better for lichen
    normalize_hsi(100 - x, optimal = 70, min_threshold = 40, max_threshold = 90)
  })

  # Canopy openness (moderate openness for lichen)
  openness_si <- sapply(canopy_metrics$canopy_openness, function(x) {
    normalize_hsi(x * 100, optimal = 40, min_threshold = 20, max_threshold = 60)
  })

  # Disturbance avoidance (if distance provided)
  if (!is.null(disturbance_distance)) {
    # Caribou avoid areas within 5km of disturbance
    disturbance_si <- sapply(disturbance_distance, function(x) {
      ifelse(x < 1, 0,
             ifelse(x < 5, x / 5,
                    1))
    })
  } else {
    disturbance_si <- 1  # No disturbance penalty
  }

  # Composite HSI
  if (!is.null(disturbance_distance)) {
    hsi <- (structure_si * 0.3 + height_si * 0.25 + understory_si * 0.2 +
            openness_si * 0.15 + disturbance_si * 0.1)
  } else {
    hsi <- (structure_si * 0.35 + height_si * 0.3 + understory_si * 0.2 + openness_si * 0.15)
  }

  return(hsi)
}

#' Calculate deer habitat suitability
#'
#' HSI for white-tailed or mule deer
#'
#' @param canopy_metrics Data frame with canopy metrics
#' @param understory_metrics Data frame with understory metrics
#' @param species "white-tailed" or "mule"
#' @return Vector of HSI scores (0-1)
#' @export
hsi_deer <- function(canopy_metrics, understory_metrics, species = "white-tailed") {
  logger::log_info("Calculating {species} deer habitat suitability")

  # Browse (0.5-2.5m for deer)
  browse_si <- sapply(understory_metrics$browse_density_pct, function(x) {
    normalize_hsi(x, optimal = 25, min_threshold = 10, max_threshold = 50)
  })

  # Edge habitat preference (heterogeneity)
  # Deer prefer structural diversity
  diversity_si <- sapply(canopy_metrics$fhd, function(x) {
    normalize_hsi(x, optimal = 2.0, min_threshold = 1.0, max_threshold = 3.0)
  })

  # Canopy closure
  if (species == "white-tailed") {
    # White-tailed prefer denser cover
    canopy_si <- sapply(canopy_metrics$canopy_cover_pct, function(x) {
      normalize_hsi(x, optimal = 60, min_threshold = 40, max_threshold = 85)
    })
  } else {
    # Mule deer prefer more open habitat
    canopy_si <- sapply(canopy_metrics$canopy_cover_pct, function(x) {
      normalize_hsi(x, optimal = 45, min_threshold = 25, max_threshold = 70)
    })
  }

  # Understory for cover
  understory_si <- sapply(understory_metrics$understory_density_pct, function(x) {
    normalize_hsi(x, optimal = 30, min_threshold = 15, max_threshold = 60)
  })

  # Composite HSI
  hsi <- (browse_si * 0.35 + canopy_si * 0.25 + diversity_si * 0.25 + understory_si * 0.15)

  return(hsi)
}

#' Calculate bear habitat suitability
#'
#' HSI for black bear emphasizing berry habitat and cover
#'
#' @param canopy_metrics Data frame with canopy metrics
#' @param understory_metrics Data frame with understory metrics
#' @return Vector of HSI scores (0-1)
#' @export
hsi_bear <- function(canopy_metrics, understory_metrics) {
  logger::log_info("Calculating black bear habitat suitability")

  # Berry-producing shrub habitat (critical food source)
  berry_si <- understory_metrics$berry_habitat_suitability

  # Canopy closure (moderate for berry production)
  canopy_si <- sapply(canopy_metrics$canopy_cover_pct, function(x) {
    normalize_hsi(x, optimal = 50, min_threshold = 30, max_threshold = 70)
  })

  # Understory density (cover + food)
  understory_si <- sapply(understory_metrics$understory_density_pct, function(x) {
    normalize_hsi(x, optimal = 35, min_threshold = 20, max_threshold = 60)
  })

  # Structural complexity (varied habitat for foraging)
  complexity_si <- sapply(canopy_metrics$structural_complexity_index, function(x) {
    normalize_hsi(x, optimal = 0.6, min_threshold = 0.3, max_threshold = 0.9)
  })

  # Composite HSI
  hsi <- (berry_si * 0.4 + canopy_si * 0.25 + understory_si * 0.2 + complexity_si * 0.15)

  return(hsi)
}

#' Calculate riparian function score for salmon streams
#'
#' Assesses riparian habitat quality for salmon-bearing streams
#'
#' @param canopy_metrics Data frame with canopy metrics
#' @param tree_attributes Optional tree attributes for LWD recruitment
#' @param stream_width Stream width in meters
#' @return Vector of riparian function scores (0-1)
#' @export
#' @references
#' Gregory et al. (1991) "An ecosystem perspective of riparian zones"
#' BioScience 41(8): 540-551
riparian_function_salmon <- function(canopy_metrics, tree_attributes = NULL,
                                    stream_width = 10) {
  logger::log_info("Calculating riparian function score for salmon habitat")

  # Large trees for shade and LWD recruitment
  if (!is.null(tree_attributes)) {
    # Trees >30m within riparian zone
    large_trees_pct <- sum(tree_attributes$height >= 30) / nrow(tree_attributes) * 100
    lwd_si <- normalize_hsi(large_trees_pct, optimal = 20, min_threshold = 5, max_threshold = 40)
  } else {
    # Use canopy height as proxy
    lwd_si <- sapply(canopy_metrics$height_max, function(x) {
      normalize_hsi(x, optimal = 35, min_threshold = 20, max_threshold = 50)
    })
  }

  # Canopy cover for stream shading (temperature regulation)
  # Optimal: 50-80% cover over stream
  shade_si <- sapply(canopy_metrics$canopy_cover_pct, function(x) {
    normalize_hsi(x, optimal = 65, min_threshold = 40, max_threshold = 90)
  })

  # Structural complexity (habitat diversity)
  structure_si <- sapply(canopy_metrics$structural_complexity_index, function(x) {
    normalize_hsi(x, optimal = 0.7, min_threshold = 0.4, max_threshold = 1.0)
  })

  # Vertical diversity (multiple canopy layers)
  vertical_si <- sapply(canopy_metrics$fhd, function(x) {
    normalize_hsi(x, optimal = 2.5, min_threshold = 1.5, max_threshold = 3.5)
  })

  # Composite riparian function score
  if (!is.null(tree_attributes)) {
    score <- (lwd_si * 0.3 + shade_si * 0.35 + structure_si * 0.2 + vertical_si * 0.15)
  } else {
    score <- (lwd_si * 0.25 + shade_si * 0.4 + structure_si * 0.2 + vertical_si * 0.15)
  }

  return(score)
}

#' Calculate general wildlife structure index
#'
#' Overall habitat quality based on structural diversity
#'
#' @param canopy_metrics Data frame with canopy metrics
#' @param understory_metrics Data frame with understory metrics
#' @return Vector of wildlife structure scores (0-1)
#' @export
wildlife_structure_index <- function(canopy_metrics, understory_metrics) {
  logger::log_info("Calculating general wildlife structure index")

  # Vertical heterogeneity
  vertical_si <- sapply(canopy_metrics$fhd, function(x) {
    normalize_hsi(x, optimal = 2.5, min_threshold = 1.0, max_threshold = 3.5)
  })

  # Horizontal complexity
  horizontal_si <- sapply(canopy_metrics$rumple_index, function(x) {
    if (is.na(x)) return(0.5)  # Default if not available
    normalize_hsi(x, optimal = 2.0, min_threshold = 1.0, max_threshold = 4.0)
  })

  # Understory complexity
  understory_si <- sapply(understory_metrics$understory_complexity, function(x) {
    normalize_hsi(x, optimal = 0.7, min_threshold = 0.3, max_threshold = 1.0)
  })

  # Canopy variation
  canopy_var_si <- sapply(canopy_metrics$height_cv, function(x) {
    normalize_hsi(x, optimal = 0.5, min_threshold = 0.2, max_threshold = 1.0)
  })

  # Composite index
  wsi <- (vertical_si * 0.3 + horizontal_si * 0.25 +
          understory_si * 0.25 + canopy_var_si * 0.2)

  return(wsi)
}

#' Calculate habitat suitability for multiple species
#'
#' Wrapper function to calculate HSI for all target species
#'
#' @param las LAS object (height-normalized)
#' @param res Grid resolution for metrics (default 30m)
#' @param species_list Vector of species codes
#' @param output_dir Optional directory to save rasters
#' @return List of rasters with HSI for each species
#' @export
#' @examples
#' \dontrun{
#' hsi_results <- calculate_multispecies_hsi(
#'   las,
#'   species_list = c("moose", "caribou", "bear"),
#'   output_dir = "habitat_suitability/"
#' )
#' }
calculate_multispecies_hsi <- function(las, res = 30,
                                      species_list = c("moose", "caribou", "deer", "bear"),
                                      output_dir = NULL) {
  logger::log_info("Calculating habitat suitability for {length(species_list)} species")

  # Calculate canopy metrics
  logger::log_info("Calculating canopy metrics...")
  canopy_raster <- generate_canopy_metrics_grid(las, res = res)

  # Calculate understory metrics
  logger::log_info("Calculating understory metrics...")
  understory_raster <- generate_understory_metrics_grid(las, res = res)

  # Convert rasters to data frames for processing
  canopy_df <- as.data.frame(canopy_raster, xy = TRUE, na.rm = FALSE)
  understory_df <- as.data.frame(understory_raster, xy = TRUE, na.rm = FALSE)

  # Merge data frames
  metrics_df <- merge(canopy_df, understory_df, by = c("x", "y"))

  # Calculate HSI for each species
  hsi_list <- list()

  for (species in species_list) {
    logger::log_info("Calculating HSI for {species}")

    hsi_values <- switch(species,
      "moose" = hsi_moose_browse(metrics_df, metrics_df, season = "winter"),
      "caribou" = hsi_caribou(metrics_df, metrics_df, habitat_type = "boreal"),
      "deer" = hsi_deer(metrics_df, metrics_df, species = "white-tailed"),
      "bear" = hsi_bear(metrics_df, metrics_df),
      "wildlife_general" = wildlife_structure_index(metrics_df, metrics_df),
      {
        logger::log_warn("Unknown species: {species}")
        rep(NA, nrow(metrics_df))
      }
    )

    # Create raster from values
    hsi_df <- data.frame(
      x = metrics_df$x,
      y = metrics_df$y,
      hsi = hsi_values
    )

    # Convert to raster
    hsi_raster <- terra::rast(
      hsi_df,
      type = "xyz",
      crs = terra::crs(canopy_raster)
    )

    hsi_list[[species]] <- hsi_raster

    # Save if output directory specified
    if (!is.null(output_dir)) {
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
      }

      out_file <- file.path(output_dir, sprintf("hsi_%s.tif", species))
      terra::writeRaster(hsi_raster, out_file, overwrite = TRUE)
      logger::log_info("Saved HSI raster: {out_file}")
    }
  }

  logger::log_info("Multi-species HSI calculation complete")

  return(hsi_list)
}

#' Identify priority habitat areas
#'
#' Delineates high-quality habitat patches for conservation
#'
#' @param hsi_raster HSI raster for a species
#' @param threshold Minimum HSI for high quality (default 0.7)
#' @param min_patch_size Minimum patch size in hectares (default 1)
#' @return sf object with priority habitat polygons
#' @export
identify_priority_habitat <- function(hsi_raster, threshold = 0.7, min_patch_size = 1) {
  logger::log_info("Identifying priority habitat (HSI >= {threshold})")

  # Create binary raster
  high_quality <- hsi_raster >= threshold

  # Convert to polygons
  habitat_poly <- terra::as.polygons(high_quality, values = TRUE)

  # Filter to high-quality patches
  habitat_poly <- habitat_poly[habitat_poly[[1]] == 1, ]

  if (length(habitat_poly) == 0) {
    logger::log_warn("No habitat patches found above threshold")
    return(NULL)
  }

  # Convert to sf
  habitat_sf <- sf::st_as_sf(habitat_poly)

  # Calculate area and filter
  habitat_sf$area_ha <- as.numeric(sf::st_area(habitat_sf)) / 10000
  habitat_sf <- habitat_sf[habitat_sf$area_ha >= min_patch_size, ]

  # Add summary statistics
  hsi_values <- terra::extract(hsi_raster, habitat_poly, fun = mean, na.rm = TRUE)
  habitat_sf$mean_hsi <- hsi_values[, 2]

  logger::log_info("Identified {nrow(habitat_sf)} priority habitat patches")

  return(habitat_sf)
}

#' Generate habitat suitability summary report
#'
#' @param hsi_list List of HSI rasters by species
#' @param aoi Optional area of interest polygon
#' @return Data frame with habitat summary statistics
#' @export
summarize_habitat_suitability <- function(hsi_list, aoi = NULL) {
  logger::log_info("Summarizing habitat suitability for {length(hsi_list)} species")

  summary_list <- list()

  for (species in names(hsi_list)) {
    hsi <- hsi_list[[species]]

    if (!is.null(aoi)) {
      # Extract within AOI
      hsi_values <- terra::extract(hsi, aoi, na.rm = TRUE)[[2]]
    } else {
      # All values
      hsi_values <- terra::values(hsi, na.rm = TRUE)
    }

    # Calculate statistics
    summary_list[[species]] <- data.frame(
      species = species,
      mean_hsi = mean(hsi_values, na.rm = TRUE),
      median_hsi = median(hsi_values, na.rm = TRUE),
      sd_hsi = sd(hsi_values, na.rm = TRUE),
      high_quality_pct = sum(hsi_values >= 0.7, na.rm = TRUE) / length(hsi_values) * 100,
      moderate_quality_pct = sum(hsi_values >= 0.5 & hsi_values < 0.7, na.rm = TRUE) / length(hsi_values) * 100,
      low_quality_pct = sum(hsi_values < 0.5, na.rm = TRUE) / length(hsi_values) * 100,
      n_cells = length(hsi_values)
    )
  }

  summary_df <- dplyr::bind_rows(summary_list)

  return(as.data.frame(summary_df))
}
