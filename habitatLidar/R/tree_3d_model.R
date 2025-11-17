#' 3D Tree Crown Modeling Functions
#'
#' Functions for reconstructing and analyzing 3D tree crown models
#'
#' @name tree_3d_model
NULL

#' Extract points for a single tree
#'
#' @param las LAS object with treeID field
#' @param tree_id ID of tree to extract
#' @return LAS object with points from single tree
#' @export
extract_tree_points <- function(las, tree_id) {
  if (!"treeID" %in% names(las@data)) {
    stop("LAS must have 'treeID' field")
  }

  tree_las <- lidR::filter_poi(las, treeID == tree_id)

  if (nrow(tree_las@data) == 0) {
    stop("No points found for tree ID: ", tree_id)
  }

  return(tree_las)
}

#' Calculate 3D convex hull for tree crown
#'
#' @param tree_points Matrix or data frame with X, Y, Z coordinates
#' @return List with hull volume, surface area, and vertices
#' @export
calculate_convex_hull_3d <- function(tree_points) {
  if (nrow(tree_points) < 4) {
    return(list(
      volume = NA,
      surface_area = NA,
      n_points = nrow(tree_points)
    ))
  }

  tryCatch({
    # Compute 3D convex hull
    hull <- geometry::convhulln(tree_points, options = "FA")

    list(
      volume = hull$vol,
      surface_area = hull$area,
      n_points = nrow(tree_points),
      n_facets = nrow(hull$hull)
    )
  }, error = function(e) {
    logger::log_warn("Convex hull calculation failed: {e$message}")
    list(
      volume = NA,
      surface_area = NA,
      n_points = nrow(tree_points)
    )
  })
}

#' Calculate 3D alpha shape for tree crown
#'
#' More detailed crown representation than convex hull
#'
#' @param tree_points Matrix or data frame with X, Y, Z coordinates
#' @param alpha Alpha parameter (smaller = more detail, default: auto)
#' @return List with alpha shape metrics
#' @export
calculate_alpha_shape_3d <- function(tree_points, alpha = NULL) {
  if (nrow(tree_points) < 10) {
    return(list(
      volume = NA,
      surface_area = NA,
      message = "Insufficient points for alpha shape"
    ))
  }

  tryCatch({
    # Auto-calculate alpha if not provided
    if (is.null(alpha)) {
      # Use median nearest neighbor distance
      distances <- as.matrix(dist(tree_points))
      diag(distances) <- Inf
      nn_dist <- apply(distances, 1, min)
      alpha <- median(nn_dist) * 2
    }

    # Calculate alpha shape
    ashape <- alphashape3d::ashape3d(
      as.matrix(tree_points),
      alpha = alpha
    )

    # Extract volume
    vol <- alphashape3d::volume_ashape3d(ashape)

    list(
      volume = vol,
      alpha = alpha,
      n_points = nrow(tree_points),
      success = TRUE
    )
  }, error = function(e) {
    logger::log_warn("Alpha shape calculation failed: {e$message}")
    list(
      volume = NA,
      alpha = alpha,
      success = FALSE
    )
  })
}

#' Calculate crown porosity and density
#'
#' Ratio of actual volume to convex hull volume
#'
#' @param las LAS object for single tree
#' @param voxel_size Size of voxels for crown analysis (default 0.5m)
#' @return List with porosity metrics
#' @export
calculate_crown_porosity <- function(las, voxel_size = 0.5) {
  points <- as.matrix(las@data[, c("X", "Y", "Z")])

  # Convex hull volume
  hull <- calculate_convex_hull_3d(points)

  if (is.na(hull$volume)) {
    return(list(porosity = NA, solidity = NA))
  }

  # Voxelize point cloud
  voxels <- floor(points / voxel_size)
  unique_voxels <- unique(voxels)
  occupied_volume <- nrow(unique_voxels) * (voxel_size^3)

  # Porosity metrics
  solidity <- occupied_volume / hull$volume
  porosity <- 1 - solidity

  list(
    porosity = porosity,
    solidity = solidity,
    occupied_volume = occupied_volume,
    convex_hull_volume = hull$volume,
    voxel_size = voxel_size,
    n_occupied_voxels = nrow(unique_voxels)
  )
}

#' Calculate crown asymmetry in 3D
#'
#' Measures deviation from vertical symmetry
#'
#' @param tree_points Matrix with X, Y, Z coordinates
#' @return List with asymmetry metrics
#' @export
calculate_crown_asymmetry <- function(tree_points) {
  # Centroid
  centroid <- colMeans(tree_points)

  # Apex (highest point)
  apex_idx <- which.max(tree_points[, 3])
  apex <- tree_points[apex_idx, ]

  # Horizontal offset of apex from centroid
  horizontal_offset <- sqrt((apex[1] - centroid[1])^2 + (apex[2] - centroid[2])^2)

  # Average crown radius
  radii <- sqrt((tree_points[, 1] - centroid[1])^2 + (tree_points[, 2] - centroid[2])^2)
  mean_radius <- mean(radii)

  # Asymmetry index (0 = perfect symmetry, 1 = highly asymmetric)
  asymmetry <- horizontal_offset / mean_radius

  # Directional asymmetry
  direction <- atan2(apex[2] - centroid[2], apex[1] - centroid[1]) * 180 / pi

  list(
    asymmetry_index = asymmetry,
    horizontal_offset = horizontal_offset,
    lean_direction_deg = direction,
    mean_crown_radius = mean_radius
  )
}

#' Analyze vertical crown structure
#'
#' Examines how crown width varies with height
#'
#' @param tree_points Matrix with X, Y, Z coordinates
#' @param n_layers Number of height layers to analyze (default 10)
#' @return Data frame with crown width by height
#' @export
analyze_vertical_crown_profile <- function(tree_points, n_layers = 10) {
  z_range <- range(tree_points[, 3])
  z_breaks <- seq(z_range[1], z_range[2], length.out = n_layers + 1)

  profile <- data.frame()

  for (i in 1:n_layers) {
    layer_points <- tree_points[
      tree_points[, 3] >= z_breaks[i] & tree_points[, 3] < z_breaks[i + 1],
    ]

    if (nrow(layer_points) < 3) next

    # Centroid of layer
    centroid <- colMeans(layer_points)

    # Crown width in this layer
    radii <- sqrt(
      (layer_points[, 1] - centroid[1])^2 +
      (layer_points[, 2] - centroid[2])^2
    )

    profile <- rbind(profile, data.frame(
      layer = i,
      height_min = z_breaks[i],
      height_max = z_breaks[i + 1],
      height_mid = mean(c(z_breaks[i], z_breaks[i + 1])),
      crown_width = mean(radii) * 2,
      crown_width_max = max(radii) * 2,
      n_points = nrow(layer_points)
    ))
  }

  return(profile)
}

#' Generate 3D crown model for export
#'
#' Creates mesh representation suitable for export to 3D formats
#'
#' @param las LAS object for single tree
#' @param method Method: "convex_hull" or "alpha_shape"
#' @param alpha Alpha parameter for alpha shape
#' @return 3D mesh object
#' @export
generate_crown_mesh <- function(las, method = "convex_hull", alpha = NULL) {
  points <- as.matrix(las@data[, c("X", "Y", "Z")])

  if (method == "convex_hull") {
    # Generate convex hull mesh
    hull <- geometry::convhulln(points, options = "FA")

    mesh <- list(
      vertices = points[unique(as.vector(hull$hull)), ],
      faces = hull$hull,
      method = "convex_hull"
    )

  } else if (method == "alpha_shape") {
    # Generate alpha shape
    if (is.null(alpha)) {
      distances <- as.matrix(dist(points))
      diag(distances) <- Inf
      alpha <- median(apply(distances, 1, min)) * 2
    }

    ashape <- alphashape3d::ashape3d(points, alpha = alpha)

    mesh <- list(
      ashape = ashape,
      method = "alpha_shape",
      alpha = alpha
    )

  } else {
    stop("Unknown method. Use 'convex_hull' or 'alpha_shape'")
  }

  return(mesh)
}

#' Export tree crown to 3D file format
#'
#' @param mesh 3D mesh object
#' @param filename Output filename (.obj or .ply)
#' @param tree_id Tree ID for labeling
#' @export
export_crown_3d <- function(mesh, filename, tree_id = NULL) {
  file_ext <- tools::file_ext(filename)

  if (file_ext == "obj") {
    # Export to OBJ format
    if (mesh$method == "convex_hull") {
      # Write OBJ file manually
      con <- file(filename, "w")

      # Write vertices
      writeLines("# Tree crown mesh", con)
      if (!is.null(tree_id)) {
        writeLines(sprintf("# Tree ID: %s", tree_id), con)
      }
      writeLines("", con)

      for (i in 1:nrow(mesh$vertices)) {
        writeLines(sprintf("v %.6f %.6f %.6f",
                          mesh$vertices[i, 1],
                          mesh$vertices[i, 2],
                          mesh$vertices[i, 3]), con)
      }

      writeLines("", con)

      # Write faces
      for (i in 1:nrow(mesh$faces)) {
        writeLines(sprintf("f %d %d %d",
                          mesh$faces[i, 1],
                          mesh$faces[i, 2],
                          mesh$faces[i, 3]), con)
      }

      close(con)
      logger::log_info("Exported crown mesh to {filename}")

    } else {
      logger::log_warn("OBJ export for alpha shapes not yet implemented")
    }

  } else if (file_ext == "ply") {
    logger::log_warn("PLY export not yet implemented")

  } else {
    stop("Unsupported file format. Use .obj or .ply")
  }
}

#' Calculate comprehensive 3D crown metrics
#'
#' @param las LAS object for single tree (or with treeID)
#' @param tree_id Optional tree ID if las contains multiple trees
#' @param voxel_size Voxel size for porosity calculation
#' @return List with all 3D metrics
#' @export
calculate_3d_crown_metrics <- function(las, tree_id = NULL, voxel_size = 0.5) {
  # Extract tree points if needed
  if (!is.null(tree_id)) {
    las <- extract_tree_points(las, tree_id)
  }

  points <- as.matrix(las@data[, c("X", "Y", "Z")])

  # Convex hull metrics
  hull <- calculate_convex_hull_3d(points)

  # Alpha shape metrics
  ashape <- calculate_alpha_shape_3d(points)

  # Porosity
  porosity <- calculate_crown_porosity(las, voxel_size)

  # Asymmetry
  asymmetry <- calculate_crown_asymmetry(points)

  # Vertical profile
  v_profile <- analyze_vertical_crown_profile(points)

  # Combine all metrics
  metrics <- c(
    list(tree_id = tree_id),
    hull,
    list(
      alpha_volume = ashape$volume,
      alpha_value = ashape$alpha
    ),
    porosity,
    asymmetry,
    list(
      crown_depth = max(points[, 3]) - min(points[, 3]),
      n_vertical_layers = nrow(v_profile),
      max_crown_width = max(v_profile$crown_width_max, na.rm = TRUE)
    )
  )

  return(metrics)
}

#' Batch process 3D metrics for all trees
#'
#' @param las LAS object with treeID field
#' @param tree_ids Optional vector of specific tree IDs to process
#' @param voxel_size Voxel size for analysis
#' @param parallel Use parallel processing (default TRUE)
#' @return Data frame with 3D metrics for all trees
#' @export
#' @examples
#' \dontrun{
#' crown_metrics_3d <- batch_calculate_crown_metrics(las_segmented)
#' # Trees with high porosity (open crowns)
#' open_crowns <- crown_metrics_3d[crown_metrics_3d$porosity > 0.7, ]
#' }
batch_calculate_crown_metrics <- function(las, tree_ids = NULL,
                                         voxel_size = 0.5, parallel = TRUE) {
  if (!"treeID" %in% names(las@data)) {
    stop("LAS must have 'treeID' field")
  }

  if (is.null(tree_ids)) {
    tree_ids <- unique(las@data$treeID)
    tree_ids <- tree_ids[!is.na(tree_ids)]
  }

  logger::log_info("Calculating 3D metrics for {length(tree_ids)} trees")

  if (parallel) {
    future::plan(future::multisession)

    results <- future.apply::future_lapply(tree_ids, function(tid) {
      tryCatch({
        calculate_3d_crown_metrics(las, tree_id = tid, voxel_size = voxel_size)
      }, error = function(e) {
        logger::log_warn("Failed to process tree {tid}: {e$message}")
        NULL
      })
    }, future.seed = TRUE)

    future::plan(future::sequential)

  } else {
    results <- lapply(tree_ids, function(tid) {
      tryCatch({
        calculate_3d_crown_metrics(las, tree_id = tid, voxel_size = voxel_size)
      }, error = function(e) {
        logger::log_warn("Failed to process tree {tid}: {e$message}")
        NULL
      })
    })
  }

  # Combine results
  results <- results[!sapply(results, is.null)]
  results_df <- dplyr::bind_rows(results)

  logger::log_info("Calculated 3D metrics for {nrow(results_df)} trees")

  return(as.data.frame(results_df))
}

#' Voxelize point cloud for 3D analysis
#'
#' @param las LAS object
#' @param voxel_size Voxel size in meters
#' @return Data frame with voxel coordinates and point counts
#' @export
voxelize_point_cloud <- function(las, voxel_size = 1) {
  logger::log_info("Voxelizing point cloud (voxel size: {voxel_size}m)")

  voxel_coords <- las@data %>%
    dplyr::mutate(
      voxel_x = floor(X / voxel_size),
      voxel_y = floor(Y / voxel_size),
      voxel_z = floor(Z / voxel_size)
    ) %>%
    dplyr::group_by(voxel_x, voxel_y, voxel_z) %>%
    dplyr::summarise(
      n_points = dplyr::n(),
      mean_height = mean(Z),
      mean_intensity = if ("Intensity" %in% names(.)) mean(Intensity) else NA,
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      # Convert back to real coordinates (voxel center)
      x = (voxel_x + 0.5) * voxel_size,
      y = (voxel_y + 0.5) * voxel_size,
      z = (voxel_z + 0.5) * voxel_size
    )

  logger::log_info("Created {nrow(voxel_coords)} occupied voxels")

  return(as.data.frame(voxel_coords))
}

#' Generate 3D understory density map
#'
#' Voxel-based understory structure for 3D visualization
#'
#' @param las LAS object
#' @param voxel_size Voxel size (default 1m)
#' @param height_range Height range for understory (default c(0.5, 4))
#' @return Data frame with understory voxels
#' @export
generate_understory_3d <- function(las, voxel_size = 1, height_range = c(0.5, 4)) {
  logger::log_info("Generating 3D understory density map")

  # Filter to understory heights
  las_understory <- lidR::filter_poi(
    las,
    Z >= height_range[1] & Z <= height_range[2]
  )

  # Voxelize
  voxels <- voxelize_point_cloud(las_understory, voxel_size)

  # Calculate density metric
  voxels$density_class <- cut(
    voxels$n_points,
    breaks = c(0, 5, 20, 50, Inf),
    labels = c("Low", "Medium", "High", "Very High")
  )

  logger::log_info("Generated {nrow(voxels)} understory voxels")

  return(voxels)
}
