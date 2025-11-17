#' Individual Tree Detection and Segmentation Functions
#'
#' @name tree_detection
NULL

#' Detect tree tops using local maxima with variable window
#'
#' Implements Li et al. (2012) algorithm with variable window size based on height
#'
#' @param chm Canopy height model (SpatRaster)
#' @param ws Window size function or numeric value
#' @param hmin Minimum tree height (default 2m)
#' @return sf object with tree locations and heights
#' @export
#' @references
#' Li et al. (2012) "A New Method for Segmenting Individual Trees from the
#' Lidar Point Cloud" Photogrammetric Engineering & Remote Sensing 78(1): 75-84
#' @examples
#' \dontrun{
#' # Variable window: increases with tree height
#' ws <- function(x) { 0.05 * x + 0.5 }
#' trees <- detect_trees_lmf(chm, ws = ws, hmin = 5)
#' }
detect_trees_lmf <- function(chm, ws = 5, hmin = 2) {
  logger::log_info("Detecting trees using local maxima filter (hmin = {hmin}m)")

  # Detect tree tops
  ttops <- lidR::locate_trees(chm, lidR::lmf(ws = ws, hmin = hmin))

  logger::log_info("Detected {nrow(ttops)} tree tops")

  return(ttops)
}

#' Segment individual tree crowns using watershed algorithm
#'
#' Uses marker-controlled watershed segmentation (Silva et al. 2016)
#'
#' @param chm Canopy height model
#' @param ttops Tree tops (from detect_trees_lmf)
#' @param th_tree Minimum height for tree (default 2m)
#' @param th_seed Seed threshold
#' @param th_cr Crown radius threshold
#' @param max_cr Maximum crown radius
#' @return SpatRaster with tree IDs
#' @export
#' @references
#' Silva et al. (2016) "Imputation of Individual Longleaf Pine Tree Attributes
#' from Field and LiDAR Data" Canadian Journal of Remote Sensing 42(5): 554-573
segment_trees_watershed <- function(chm, ttops, th_tree = 2,
                                   th_seed = 0.45, th_cr = 0.55, max_cr = 10) {
  logger::log_info("Segmenting tree crowns using watershed algorithm")

  # Segment crowns
  crowns <- lidR::silva2016(chm, ttops,
                            th_tree = th_tree,
                            th_seed = th_seed,
                            th_cr = th_cr,
                            max_cr_factor = max_cr)()

  n_trees <- length(unique(terra::values(crowns))) - 1  # Exclude NA

  logger::log_info("Segmented {n_trees} tree crowns")

  return(crowns)
}

#' Segment trees using Dalponte method
#'
#' Alternative segmentation using region growing (Dalponte & Coomes 2016)
#'
#' @param chm Canopy height model
#' @param ttops Tree tops
#' @param th_tree Minimum tree height
#' @param th_seed Seed threshold
#' @param th_cr Crown radius threshold
#' @param max_cr Maximum crown diameter
#' @return SpatRaster with tree IDs
#' @export
#' @references
#' Dalponte & Coomes (2016) "Tree‐centric mapping of forest carbon density
#' from airborne laser scanning and hyperspectral data" Methods in Ecology
#' and Evolution 7(10): 1236-1245
segment_trees_dalponte <- function(chm, ttops, th_tree = 2,
                                  th_seed = 0.45, th_cr = 0.55, max_cr = 10) {
  logger::log_info("Segmenting tree crowns using Dalponte method")

  crowns <- lidR::dalponte2016(chm, ttops,
                               th_tree = th_tree,
                               th_seed = th_seed,
                               th_cr = th_cr,
                               max_cr_factor = max_cr,
                               ID = "treeID")()

  n_trees <- length(unique(terra::values(crowns))) - 1

  logger::log_info("Segmented {n_trees} tree crowns")

  return(crowns)
}

#' Extract attributes for each segmented tree
#'
#' Calculates comprehensive metrics for each individual tree
#'
#' @param las LAS object with tree IDs assigned
#' @param crowns Crown raster (optional, for crown metrics)
#' @param region Region code for DBH estimation
#' @return Data frame with tree attributes
#' @export
extract_tree_attributes <- function(las, crowns = NULL, region = "boreal") {
  logger::log_info("Extracting attributes for individual trees")

  # Check for treeID field
  if (!"treeID" %in% names(las@data)) {
    stop("LAS must have 'treeID' field. Run segment_trees_* first.")
  }

  # Calculate metrics per tree
  tree_metrics <- las@data %>%
    dplyr::filter(!is.na(treeID)) %>%
    dplyr::group_by(treeID) %>%
    dplyr::summarise(
      # Location
      x = mean(X),
      y = mean(Y),
      x_apex = X[which.max(Z)][1],
      y_apex = Y[which.max(Z)][1],

      # Height metrics
      height = max(Z),
      height_mean = mean(Z),
      crown_base_height = quantile(Z, 0.1),
      crown_depth = height - crown_base_height,

      # Point statistics
      n_points = dplyr::n(),
      point_density = dplyr::n() / (max(Z) - min(Z)),

      # Crown shape
      crown_diameter_x = max(X) - min(X),
      crown_diameter_y = max(Y) - min(Y),
      crown_diameter = mean(c(crown_diameter_x, crown_diameter_y)),

      # Intensity (if available)
      intensity_mean = if ("Intensity" %in% names(.)) mean(Intensity) else NA,
      intensity_sd = if ("Intensity" %in% names(.)) sd(Intensity) else NA,

      .groups = "drop"
    ) %>%
    dplyr::mutate(
      # Derived metrics
      crown_volume = (pi * (crown_diameter / 2)^2 * crown_depth) / 3,  # Cone approximation
      height_to_diameter = height / crown_diameter,
      crown_shape = dplyr::case_when(
        height_to_diameter > 2 ~ "Narrow",
        height_to_diameter > 1.2 ~ "Medium",
        TRUE ~ "Broad"
      ),

      # Asymmetry
      apex_offset_x = abs(x_apex - x),
      apex_offset_y = abs(y_apex - y),
      crown_asymmetry = sqrt(apex_offset_x^2 + apex_offset_y^2) / (crown_diameter / 2),

      # DBH estimation
      dbh_estimated = estimate_dbh(height, region = region)
    ) %>%
    as.data.frame()

  logger::log_info("Extracted attributes for {nrow(tree_metrics)} trees")

  return(tree_metrics)
}

#' Assign tree IDs to point cloud
#'
#' Assigns tree ID to each point based on crown segmentation
#'
#' @param las LAS object
#' @param crowns Crown segmentation raster
#' @return LAS object with treeID field added
#' @export
assign_tree_ids <- function(las, crowns) {
  logger::log_info("Assigning tree IDs to point cloud")

  # Extract crown IDs at each point location
  coords <- data.frame(x = las@data$X, y = las@data$Y)
  tree_ids <- terra::extract(crowns, coords, ID = FALSE)

  las@data$treeID <- tree_ids[, 1]

  n_assigned <- sum(!is.na(las@data$treeID))
  pct_assigned <- n_assigned / nrow(las@data) * 100

  logger::log_info("Assigned tree IDs to {n_assigned} points ({round(pct_assigned, 1)}%)")

  return(las)
}

#' Complete tree detection pipeline
#'
#' Runs full workflow: detection, segmentation, attribute extraction
#'
#' @param las LAS object (height-normalized)
#' @param chm Canopy height model (if NULL, will generate)
#' @param method Segmentation method: "watershed" or "dalponte"
#' @param ws Window size for tree detection
#' @param hmin Minimum tree height
#' @param region Region for DBH estimation
#' @return List with tree locations, attributes, and segmented LAS
#' @export
#' @examples
#' \dontrun{
#' # Variable window size based on tree height
#' ws_func <- function(x) { 0.05 * x + 1.0 }
#' result <- detect_segment_trees(las, method = "watershed", ws = ws_func, hmin = 5)
#'
#' trees_sf <- result$trees_sf
#' tree_attributes <- result$attributes
#' las_segmented <- result$las
#' }
detect_segment_trees <- function(las, chm = NULL, method = "watershed",
                                ws = 5, hmin = 2, region = "boreal") {
  logger::log_info("Starting tree detection and segmentation pipeline")

  # Generate CHM if not provided
  if (is.null(chm)) {
    logger::log_info("Generating CHM for tree detection")
    chm <- generate_chm(las, res = 0.5)
  }

  # Step 1: Detect tree tops
  ttops <- detect_trees_lmf(chm, ws = ws, hmin = hmin)

  # Step 2: Segment crowns
  if (method == "watershed") {
    crowns <- segment_trees_watershed(chm, ttops)
  } else if (method == "dalponte") {
    crowns <- segment_trees_dalponte(chm, ttops)
  } else {
    stop("Unknown method. Use 'watershed' or 'dalponte'")
  }

  # Step 3: Assign tree IDs to points
  las <- assign_tree_ids(las, crowns)

  # Step 4: Extract tree attributes
  attributes <- extract_tree_attributes(las, crowns, region = region)

  # Step 5: Create spatial features for trees
  trees_sf <- sf::st_as_sf(
    attributes,
    coords = c("x", "y"),
    crs = sf::st_crs(las)
  )

  logger::log_info("Tree detection pipeline complete: {nrow(attributes)} trees")

  return(list(
    trees_sf = trees_sf,
    attributes = attributes,
    crowns = crowns,
    las = las,
    ttops = ttops
  ))
}

#' Filter trees by size class
#'
#' @param tree_attributes Tree attributes data frame
#' @param size_class Size class: "sapling", "pole", "mature", "veteran", or custom min/max height
#' @return Filtered data frame
#' @export
filter_trees_by_size <- function(tree_attributes, size_class = "mature") {
  # Predefined size classes (Canadian standards)
  size_ranges <- list(
    sapling = c(2, 10),
    pole = c(10, 20),
    mature = c(20, 30),
    veteran = c(30, Inf)
  )

  if (size_class %in% names(size_ranges)) {
    range <- size_ranges[[size_class]]
    filtered <- tree_attributes %>%
      dplyr::filter(height >= range[1] & height < range[2])
  } else {
    stop("Unknown size_class. Use 'sapling', 'pole', 'mature', or 'veteran'")
  }

  logger::log_info("Filtered to {nrow(filtered)} {size_class} trees")

  return(filtered)
}

#' Calculate tree size distribution
#'
#' @param tree_attributes Tree attributes data frame
#' @param breaks Height breaks for size classes
#' @return Data frame with size distribution
#' @export
calculate_size_distribution <- function(tree_attributes,
                                       breaks = c(0, 10, 20, 30, 40, Inf)) {
  size_dist <- tree_attributes %>%
    dplyr::mutate(
      size_class = cut(height, breaks = breaks, include.lowest = TRUE)
    ) %>%
    dplyr::group_by(size_class) %>%
    dplyr::summarise(
      n_trees = dplyr::n(),
      mean_height = mean(height),
      mean_dbh = mean(dbh_estimated),
      total_volume = sum(crown_volume, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      proportion = n_trees / sum(n_trees)
    )

  return(as.data.frame(size_dist))
}

#' Identify old-growth indicator trees
#'
#' Trees meeting old-growth criteria (height, DBH, structure)
#'
#' @param tree_attributes Tree attributes data frame
#' @param height_threshold Minimum height for old growth (default 30m)
#' @param dbh_threshold Minimum DBH (default 50cm)
#' @return Filtered data frame of old-growth trees
#' @export
identify_old_growth_trees <- function(tree_attributes,
                                     height_threshold = 30,
                                     dbh_threshold = 50) {
  og_trees <- tree_attributes %>%
    dplyr::filter(
      height >= height_threshold |
      dbh_estimated >= dbh_threshold
    ) %>%
    dplyr::mutate(
      old_growth_indicator = TRUE
    )

  logger::log_info("Identified {nrow(og_trees)} old-growth indicator trees")

  return(as.data.frame(og_trees))
}

#' Calculate tree density and basal area
#'
#' @param tree_attributes Tree attributes data frame
#' @param area_ha Area in hectares
#' @return List with density and basal area metrics
#' @export
calculate_stand_metrics <- function(tree_attributes, area_ha) {
  # Trees per hectare
  tph <- nrow(tree_attributes) / area_ha

  # Basal area (m²/ha)
  # BA = π * (DBH/2)² for each tree
  tree_attributes$ba <- pi * (tree_attributes$dbh_estimated / 100 / 2)^2
  ba_ha <- sum(tree_attributes$ba) / area_ha

  # Volume (m³/ha) - using crown volume as proxy
  vol_ha <- sum(tree_attributes$crown_volume, na.rm = TRUE) / area_ha

  # Quadratic mean diameter
  qmd <- sqrt(mean(tree_attributes$dbh_estimated^2))

  list(
    trees_per_ha = tph,
    basal_area_m2_ha = ba_ha,
    volume_m3_ha = vol_ha,
    quadratic_mean_diameter_cm = qmd,
    mean_height_m = mean(tree_attributes$height),
    max_height_m = max(tree_attributes$height)
  )
}
