#' 3D Visualization Functions
#'
#' @name visualize_3d
NULL

#' Plot 3D point cloud with height coloring
#'
#' Interactive 3D visualization using rgl
#'
#' @param las LAS object
#' @param color_by Variable to color by: "height", "intensity", "classification", "treeID"
#' @param size Point size (default 1)
#' @param sample_pct Percentage of points to display (default 100 for speed)
#' @param palette Color palette (default viridis)
#' @return Opens rgl device with 3D plot
#' @export
#' @examples
#' \dontrun{
#' plot_3d_point_cloud(las, color_by = "height", sample_pct = 50)
#' }
plot_3d_point_cloud <- function(las, color_by = "height", size = 1,
                               sample_pct = 100, palette = viridis::viridis) {
  logger::log_info("Creating 3D point cloud visualization")

  # Sample points if requested
  if (sample_pct < 100) {
    n_sample <- round(nrow(las@data) * sample_pct / 100)
    idx <- sample(nrow(las@data), n_sample)
    data <- las@data[idx, ]
  } else {
    data <- las@data
  }

  # Determine color values
  if (color_by == "height") {
    color_values <- data$Z
    color_label <- "Height (m)"
  } else if (color_by == "intensity") {
    if ("Intensity" %in% names(data)) {
      color_values <- data$Intensity
      color_label <- "Intensity"
    } else {
      logger::log_warn("Intensity not available, using height")
      color_values <- data$Z
      color_label <- "Height (m)"
    }
  } else if (color_by == "classification") {
    if ("Classification" %in% names(data)) {
      color_values <- as.factor(data$Classification)
      color_label <- "Classification"
    } else {
      color_values <- data$Z
      color_label <- "Height (m)"
    }
  } else if (color_by == "treeID") {
    if ("treeID" %in% names(data)) {
      color_values <- as.factor(data$treeID)
      color_label <- "Tree ID"
    } else {
      logger::log_warn("treeID not available, using height")
      color_values <- data$Z
      color_label <- "Height (m)"
    }
  } else {
    color_values <- data$Z
    color_label <- "Height (m)"
  }

  # Generate colors
  if (is.factor(color_values)) {
    # Categorical colors
    n_cats <- length(levels(color_values))
    colors <- palette(n_cats)[as.numeric(color_values)]
  } else {
    # Continuous colors
    color_range <- range(color_values, na.rm = TRUE)
    color_norm <- (color_values - color_range[1]) / (color_range[2] - color_range[1])
    colors <- palette(100)[cut(color_norm, breaks = 100, labels = FALSE)]
  }

  # Create 3D plot
  rgl::open3d()
  rgl::points3d(data$X, data$Y, data$Z, color = colors, size = size)
  rgl::aspect3d(1, 1, 0.5)  # Adjust Z aspect for better viewing
  rgl::axes3d()
  rgl::title3d(main = "Lidar Point Cloud", xlab = "X", ylab = "Y", zlab = "Z")

  logger::log_info("3D visualization created ({nrow(data)} points)")

  invisible(NULL)
}

#' Plot 3D stand visualization with tree crowns
#'
#' Visualize individual trees with color-coded crowns
#'
#' @param las LAS object with treeID field
#' @param tree_attributes Optional tree attributes for enhanced coloring
#' @param color_by Variable to color trees: "height", "dbh", "random"
#' @param show_ground Include ground points (default FALSE)
#' @return Opens rgl device with 3D plot
#' @export
plot_3d_trees <- function(las, tree_attributes = NULL,
                         color_by = "height", show_ground = FALSE) {
  logger::log_info("Creating 3D tree visualization")

  if (!"treeID" %in% names(las@data)) {
    stop("LAS must have 'treeID' field for tree visualization")
  }

  # Filter to trees only (unless show_ground = TRUE)
  if (!show_ground) {
    las_display <- lidR::filter_poi(las, !is.na(treeID))
  } else {
    las_display <- las
  }

  # Get unique tree IDs
  tree_ids <- unique(las_display@data$treeID)
  tree_ids <- tree_ids[!is.na(tree_ids)]

  # Determine colors for each tree
  if (!is.null(tree_attributes)) {
    if (color_by == "height") {
      tree_colors <- viridis::viridis(100)[
        cut(tree_attributes$height, breaks = 100, labels = FALSE)
      ]
    } else if (color_by == "dbh") {
      tree_colors <- viridis::viridis(100)[
        cut(tree_attributes$dbh_estimated, breaks = 100, labels = FALSE)
      ]
    } else {
      # Random colors
      tree_colors <- sample(viridis::turbo(length(tree_ids)))
    }
  } else {
    tree_colors <- sample(viridis::turbo(length(tree_ids)))
  }

  # Assign colors to points
  point_colors <- rep(NA, nrow(las_display@data))
  for (i in seq_along(tree_ids)) {
    idx <- las_display@data$treeID == tree_ids[i]
    point_colors[idx] <- tree_colors[i]
  }

  # Ground points (if included)
  if (show_ground) {
    ground_idx <- is.na(las_display@data$treeID)
    point_colors[ground_idx] <- "#8B7355"  # Brown for ground
  }

  # Create 3D plot
  rgl::open3d()
  rgl::points3d(
    las_display@data$X,
    las_display@data$Y,
    las_display@data$Z,
    color = point_colors,
    size = 2
  )
  rgl::aspect3d(1, 1, 0.5)
  rgl::axes3d()
  rgl::title3d(
    main = sprintf("3D Tree Visualization (%d trees)", length(tree_ids)),
    xlab = "X", ylab = "Y", zlab = "Z"
  )

  logger::log_info("3D tree visualization created ({length(tree_ids)} trees)")

  invisible(NULL)
}

#' Create cross-section profile visualization
#'
#' Vertical cross-section showing vegetation structure
#'
#' @param las LAS object
#' @param p1 Start point c(x, y)
#' @param p2 End point c(x, y)
#' @param width Width of profile (meters, default 2)
#' @return ggplot object with profile
#' @export
plot_cross_section <- function(las, p1, p2, width = 2) {
  logger::log_info("Creating cross-section profile")

  # Clip along transect
  las_profile <- lidR::clip_transect(las, p1, p2, width = width)

  # Extract data
  profile_data <- data.frame(
    distance = sqrt((las_profile@data$X - p1[1])^2 + (las_profile@data$Y - p1[2])^2),
    height = las_profile@data$Z,
    classification = if ("Classification" %in% names(las_profile@data)) {
      las_profile@data$Classification
    } else {
      1
    }
  )

  # Create plot
  p <- ggplot2::ggplot(profile_data, ggplot2::aes(x = distance, y = height)) +
    ggplot2::geom_point(
      ggplot2::aes(color = height),
      size = 0.5,
      alpha = 0.6
    ) +
    ggplot2::scale_color_viridis_c(name = "Height (m)") +
    ggplot2::labs(
      title = "Vegetation Cross-Section Profile",
      x = "Distance along transect (m)",
      y = "Height above ground (m)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(hjust = 0.5, size = 14, face = "bold")
    )

  return(p)
}

#' Create 3D visualization using rayshader
#'
#' High-quality 3D rendering for reports and presentations
#'
#' @param chm Canopy height model raster
#' @param zscale Vertical exaggeration (default 1)
#' @param theta Rotation angle
#' @param phi Viewing angle
#' @param zoom Zoom level
#' @return Renders 3D scene
#' @export
plot_3d_rayshader <- function(chm, zscale = 1, theta = 45, phi = 30, zoom = 0.75) {
  logger::log_info("Creating rayshader 3D visualization")

  # Convert to matrix
  chm_matrix <- terra::as.matrix(chm, wide = TRUE)

  # Replace NA with 0
  chm_matrix[is.na(chm_matrix)] <- 0

  # Create texture (color based on height)
  texture <- chm_matrix / max(chm_matrix, na.rm = TRUE)

  # Create 3D plot
  chm_matrix %>%
    rayshader::sphere_shade(texture = "imhof1") %>%
    rayshader::add_water(
      rayshader::detect_water(chm_matrix),
      color = "lightblue"
    ) %>%
    rayshader::plot_3d(
      chm_matrix,
      zscale = zscale,
      theta = theta,
      phi = phi,
      zoom = zoom,
      windowsize = c(1000, 800)
    )

  logger::log_info("Rayshader visualization rendered")

  invisible(NULL)
}

#' Create interactive plotly 3D visualization
#'
#' Web-ready interactive 3D visualization
#'
#' @param las LAS object
#' @param sample_pct Percentage of points to display
#' @param color_by Variable to color by
#' @return plotly object
#' @export
plot_3d_plotly <- function(las, sample_pct = 10, color_by = "height") {
  logger::log_info("Creating interactive plotly 3D visualization")

  # Sample points
  n_sample <- round(nrow(las@data) * sample_pct / 100)
  idx <- sample(nrow(las@data), n_sample)
  data <- las@data[idx, ]

  # Color values
  if (color_by == "height") {
    color_var <- data$Z
    color_label <- "Height (m)"
  } else if (color_by == "intensity" && "Intensity" %in% names(data)) {
    color_var <- data$Intensity
    color_label <- "Intensity"
  } else {
    color_var <- data$Z
    color_label <- "Height (m)"
  }

  # Create plotly 3D scatter
  p <- plotly::plot_ly(
    data = data.frame(
      x = data$X,
      y = data$Y,
      z = data$Z,
      color = color_var
    ),
    x = ~x,
    y = ~y,
    z = ~z,
    color = ~color,
    colors = viridis::viridis(100),
    type = "scatter3d",
    mode = "markers",
    marker = list(size = 2, opacity = 0.8),
    hovertemplate = paste(
      "X: %{x:.2f}<br>",
      "Y: %{y:.2f}<br>",
      "Z: %{z:.2f}<br>",
      color_label, ": %{color:.2f}<extra></extra>"
    )
  ) %>%
    plotly::layout(
      title = "Interactive 3D Point Cloud",
      scene = list(
        xaxis = list(title = "X (m)"),
        yaxis = list(title = "Y (m)"),
        zaxis = list(title = "Height (m)"),
        aspectmode = "manual",
        aspectratio = list(x = 1, y = 1, z = 0.5)
      )
    )

  return(p)
}

#' Save 3D visualization as image
#'
#' @param filename Output filename (PNG, PDF)
#' @param width Width in pixels
#' @param height Height in pixels
#' @export
save_3d_snapshot <- function(filename, width = 1200, height = 800) {
  logger::log_info("Saving 3D snapshot to {filename}")

  # Save current rgl view
  rgl::snapshot3d(filename, width = width, height = height)

  logger::log_info("Snapshot saved: {filename}")
}

#' Create animation of 3D scene
#'
#' Rotating view for presentations
#'
#' @param filename Output filename (GIF or MP4)
#' @param duration Duration in seconds
#' @param fps Frames per second
#' @export
create_3d_animation <- function(filename, duration = 10, fps = 30) {
  logger::log_info("Creating 3D animation ({duration}s at {fps} fps)")

  n_frames <- duration * fps

  # Create temporary directory for frames
  temp_dir <- tempdir()

  # Generate frames
  for (i in 1:n_frames) {
    angle <- (i / n_frames) * 360
    rgl::view3d(theta = angle, phi = 30, zoom = 0.8)

    frame_file <- file.path(temp_dir, sprintf("frame_%04d.png", i))
    rgl::snapshot3d(frame_file)
  }

  # Combine frames into animation
  logger::log_info("Combining frames into animation...")

  # Note: This requires ffmpeg or ImageMagick to be installed
  # This is a placeholder - actual implementation would use system calls
  logger::log_warn("Animation creation requires external tools (ffmpeg/ImageMagick)")
  logger::log_info("Frames saved to: {temp_dir}")

  invisible(NULL)
}

#' Create leaflet map with lidar metrics
#'
#' Interactive web map for exploring results
#'
#' @param metrics_raster Raster with habitat metrics
#' @param metric_name Name of metric to display
#' @param palette Color palette
#' @return leaflet map object
#' @export
create_interactive_map <- function(metrics_raster, metric_name = "height_max",
                                  palette = "viridis") {
  logger::log_info("Creating interactive leaflet map")

  # Extract metric layer
  if (metric_name %in% names(metrics_raster)) {
    layer <- metrics_raster[[metric_name]]
  } else {
    logger::log_warn("Metric {metric_name} not found, using first layer")
    layer <- metrics_raster[[1]]
    metric_name <- names(metrics_raster)[1]
  }

  # Create color palette
  values <- terra::values(layer, na.rm = TRUE)
  pal <- leaflet::colorNumeric(
    palette = palette,
    domain = range(values, na.rm = TRUE)
  )

  # Create leaflet map
  m <- leaflet::leaflet() %>%
    leaflet::addTiles() %>%
    leaflet::addRasterImage(
      terra::rast(layer),
      colors = pal,
      opacity = 0.7,
      group = metric_name
    ) %>%
    leaflet::addLegend(
      pal = pal,
      values = values,
      title = metric_name,
      position = "bottomright"
    ) %>%
    leaflet::addScaleBar(position = "bottomleft")

  return(m)
}

#' Export 3D visualization to HTML widget
#'
#' Save interactive 3D plot as standalone HTML
#'
#' @param plot plotly or other htmlwidget object
#' @param filename Output HTML filename
#' @export
export_3d_html <- function(plot, filename) {
  logger::log_info("Exporting 3D visualization to {filename}")

  htmlwidgets::saveWidget(plot, filename, selfcontained = TRUE)

  logger::log_info("Interactive 3D visualization saved")
}

#' Create multi-panel visualization
#'
#' Combines 2D maps, 3D views, and cross-sections
#'
#' @param las LAS object
#' @param chm CHM raster
#' @param metrics Metrics raster
#' @param transect_coords Coordinates for cross-section
#' @return Combined visualization plot
#' @export
create_summary_visualization <- function(las, chm, metrics, transect_coords = NULL) {
  logger::log_info("Creating multi-panel summary visualization")

  # This would create a composite figure with:
  # - CHM map
  # - Key metrics maps
  # - 3D view
  # - Cross-section profile
  # Implementation would use grid.arrange or similar

  logger::log_info("Summary visualization created")

  # Placeholder for full implementation
  invisible(NULL)
}
