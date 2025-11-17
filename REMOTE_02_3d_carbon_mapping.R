################################################################################
# REMOTE SENSING - PART 2: 3D CARBON MAPPING
################################################################################
# Purpose: Create 3D visualizations and spatially-explicit carbon stock maps
# Input: GEDI composite, biomass model from REMOTE_01
# Output: 3D carbon maps, interactive visualizations, summary reports
# Methods: 3D raster stacking, rayshader visualization, spatial analysis
################################################################################

# ==============================================================================
# SETUP
# ==============================================================================

source("forest_carbon_config.R")

required_packages <- c(
  "terra",
  "sf",
  "dplyr",
  "ggplot2",
  "viridis",
  "rayshader",    # 3D visualization
  "rgl",          # 3D graphics
  "plotly",       # Interactive plots
  "htmlwidgets",  # Save interactive plots
  "rasterVis"     # Raster visualization
)

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Input Data Paths
DATA_PATHS <- list(
  gedi_composite = "data/gee_exports/GEDI_Composite.tif",
  biomass = "data/gee_exports/Biomass_Carbon_Stock.tif",
  feature_stack = "data/gee_exports/Forest_Carbon_Feature_Stack.tif",
  terrain = "data/gee_exports/Terrain_Derivatives.tif"
)

# Output Directory
OUTPUT_DIR <- DIRECTORIES$carbon_maps
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# 3D Visualization Parameters
VIS_3D <- list(
  # Vertical exaggeration for 3D plots
  z_scale = 3,  # Exaggerate height by 3x for visibility

  # Resolution for 3D rendering (downsample for speed)
  render_resolution = 100,  # meters (higher = faster but less detail)

  # Camera angles
  camera_theta = 45,   # Rotation angle
  camera_phi = 30,     # Elevation angle
  camera_zoom = 0.7,

  # Rendering quality
  render_quality = "medium",  # "low", "medium", "high"

  # Color palettes
  carbon_palette = COLOR_SCHEMES$carbon_stock,
  height_palette = COLOR_SCHEMES$forest_height
)

# ==============================================================================
# STEP 1: LOAD DATA
# ==============================================================================

cat("\n=== STEP 1: Loading Spatial Data ===\n")

# Try loading rasters
rasters_loaded <- list()

for (name in names(DATA_PATHS)) {
  path <- DATA_PATHS[[name]]

  if (file.exists(path)) {
    rasters_loaded[[name]] <- rast(path)
    cat("  ✓ Loaded:", name, "\n")
  } else {
    cat("  ✗ Missing:", name, "\n")
  }
}

# Create synthetic data if nothing loaded
if (length(rasters_loaded) == 0) {
  cat("\nNo rasters found. Creating synthetic example...\n")

  # Create example landscape
  set.seed(42)

  template <- rast(
    extent = c(0, 5000, 0, 5000),
    resolution = 30,
    crs = PROJECT$coordinate_system
  )

  # Synthetic elevation (terrain)
  x <- xFromCell(template, 1:ncell(template))
  y <- yFromCell(template, 1:ncell(template))

  elevation <- template
  values(elevation) <- 500 +
    200 * sin(x / 500) * cos(y / 600) +
    100 * sin(x / 200) +
    50 * rnorm(ncell(template))
  names(elevation) <- "elevation"

  # Synthetic canopy height (correlated with elevation negatively - valleys have taller trees)
  canopy_height <- template
  values(canopy_height) <- pmax(0, 25 - 0.02 * (values(elevation) - 500) +
                               10 * sin(x / 800) + 5 * rnorm(ncell(template)))
  names(canopy_height) <- "rh98"

  # Synthetic carbon stocks (function of height)
  carbon <- template
  values(carbon) <- pmax(10, 50 + 5 * values(canopy_height) + 20 * rnorm(ncell(template)))
  names(carbon) <- "Carbon_Mg_ha"

  # Stack
  rasters_loaded$terrain <- elevation
  rasters_loaded$gedi_composite <- canopy_height
  rasters_loaded$biomass <- carbon

  cat("Created synthetic 3D landscape\n")
  EXAMPLE_MODE <- TRUE

} else {
  EXAMPLE_MODE <- FALSE
}

# Extract individual layers
if ("terrain" %in% names(rasters_loaded)) {
  if ("elevation" %in% names(rasters_loaded$terrain)) {
    elevation <- rasters_loaded$terrain[["elevation"]]
  } else {
    elevation <- rasters_loaded$terrain[[1]]
  }
} else {
  elevation <- NULL
}

if ("gedi_composite" %in% names(rasters_loaded)) {
  if ("rh98" %in% names(rasters_loaded$gedi_composite)) {
    canopy_height <- rasters_loaded$gedi_composite[["rh98"]]
  } else {
    canopy_height <- rasters_loaded$gedi_composite[[1]]
  }
} else {
  canopy_height <- NULL
}

if ("biomass" %in% names(rasters_loaded)) {
  if ("Carbon_Mg_ha" %in% names(rasters_loaded$biomass)) {
    carbon_stock <- rasters_loaded$biomass[["Carbon_Mg_ha"]]
  } else {
    carbon_stock <- rasters_loaded$biomass[[1]]
  }
} else {
  carbon_stock <- NULL
}

# ==============================================================================
# STEP 2: CALCULATE FOREST STRUCTURE METRICS
# ==============================================================================

cat("\n=== STEP 2: Calculating Forest Structure Metrics ===\n")

if (!is.null(canopy_height) && !is.null(elevation)) {

  # Digital Surface Model (DSM) = Elevation + Canopy Height
  dsm <- elevation + canopy_height
  names(dsm) <- "DSM"

  cat("Created Digital Surface Model (DSM)\n")

  # Canopy roughness (standard deviation in 3x3 window)
  canopy_roughness <- focal(
    canopy_height,
    w = 3,
    fun = sd,
    na.rm = TRUE
  )
  names(canopy_roughness) <- "canopy_roughness"

  cat("Calculated canopy roughness\n")

  # Stack all layers
  forest_3d <- c(elevation, canopy_height, dsm, canopy_roughness)

  if (!is.null(carbon_stock)) {
    forest_3d <- c(forest_3d, carbon_stock)
  }

  cat("Combined", nlyr(forest_3d), "layers into 3D stack\n")

} else {
  cat("WARNING: Missing elevation or canopy height. Skipping structure metrics.\n")
  forest_3d <- NULL
}

# ==============================================================================
# STEP 3: SPATIAL STATISTICS
# ==============================================================================

cat("\n=== STEP 3: Calculating Spatial Statistics ===\n")

if (!is.null(carbon_stock)) {

  # Calculate zonal statistics
  carbon_stats <- data.frame(
    metric = c(
      "Mean Carbon Stock (Mg C/ha)",
      "Median Carbon Stock (Mg C/ha)",
      "Std Dev (Mg C/ha)",
      "Min (Mg C/ha)",
      "Max (Mg C/ha)",
      "Total Area (ha)",
      "Total Carbon Stock (Mg C)",
      "Mean Canopy Height (m)"
    ),
    value = c(
      round(global(carbon_stock, "mean", na.rm = TRUE)[1,1], 1),
      round(global(carbon_stock, "median", na.rm = TRUE)[1,1], 1),
      round(global(carbon_stock, "sd", na.rm = TRUE)[1,1], 1),
      round(global(carbon_stock, "min", na.rm = TRUE)[1,1], 1),
      round(global(carbon_stock, "max", na.rm = TRUE)[1,1], 1),
      round(ncell(carbon_stock[!is.na(carbon_stock)]) * prod(res(carbon_stock)) / 10000, 1),
      round(global(carbon_stock, "sum", na.rm = TRUE)[1,1] * prod(res(carbon_stock)) / 10000, 0),
      if (!is.null(canopy_height)) round(global(canopy_height, "mean", na.rm = TRUE)[1,1], 1) else NA
    )
  )

  print(carbon_stats)

  write.csv(
    carbon_stats,
    file.path(OUTPUT_DIR, "carbon_stock_statistics.csv"),
    row.names = FALSE
  )
}

# ==============================================================================
# STEP 4: CREATE 2D MAPS
# ==============================================================================

cat("\n=== STEP 4: Creating 2D Maps ===\n")

# Map 1: Carbon Stock
if (!is.null(carbon_stock)) {

  carbon_df <- as.data.frame(carbon_stock, xy = TRUE, na.rm = TRUE)
  names(carbon_df)[3] <- "carbon"

  map_carbon <- ggplot(carbon_df, aes(x = x, y = y, fill = carbon)) +
    geom_raster() +
    scale_fill_gradientn(
      colors = VIS_3D$carbon_palette,
      name = "Carbon Stock\n(Mg C/ha)",
      na.value = "transparent"
    ) +
    coord_equal() +
    labs(
      title = "Forest Carbon Stock Map",
      subtitle = paste("Mean:", round(mean(carbon_df$carbon, na.rm = TRUE), 1), "Mg C/ha"),
      x = "Easting (m)",
      y = "Northing (m)"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(face = "bold", size = 14)
    )

  ggsave(
    file.path(OUTPUT_DIR, "carbon_stock_map_2d.png"),
    map_carbon,
    width = 12,
    height = 10,
    dpi = 300
  )

  cat("2D carbon map saved\n")
}

# Map 2: Canopy Height
if (!is.null(canopy_height)) {

  height_df <- as.data.frame(canopy_height, xy = TRUE, na.rm = TRUE)
  names(height_df)[3] <- "height"

  map_height <- ggplot(height_df, aes(x = x, y = y, fill = height)) +
    geom_raster() +
    scale_fill_gradientn(
      colors = VIS_3D$height_palette,
      name = "Canopy Height\n(m)",
      na.value = "transparent"
    ) +
    coord_equal() +
    labs(
      title = "Canopy Height Map (GEDI RH98)",
      subtitle = paste("Mean:", round(mean(height_df$height, na.rm = TRUE), 1), "m"),
      x = "Easting (m)",
      y = "Northing (m)"
    ) +
    theme_minimal() +
    theme(
      legend.position = "right",
      plot.title = element_text(face = "bold", size = 14)
    )

  ggsave(
    file.path(OUTPUT_DIR, "canopy_height_map_2d.png"),
    map_height,
    width = 12,
    height = 10,
    dpi = 300
  )

  cat("2D height map saved\n")
}

# ==============================================================================
# STEP 5: CREATE 3D VISUALIZATIONS (RAYSHADER)
# ==============================================================================

cat("\n=== STEP 5: Creating 3D Visualizations ===\n")

if (!is.null(canopy_height) && !is.null(carbon_stock)) {

  cat("Preparing data for 3D rendering...\n")

  # Downsample for rendering speed
  if (VIS_3D$render_resolution > res(carbon_stock)[1]) {
    carbon_3d <- aggregate(carbon_stock, fact = VIS_3D$render_resolution / res(carbon_stock)[1], fun = mean)
    height_3d <- aggregate(canopy_height, fact = VIS_3D$render_resolution / res(canopy_height)[1], fun = mean)

    if (!is.null(elevation)) {
      elev_3d <- aggregate(elevation, fact = VIS_3D$render_resolution / res(elevation)[1], fun = mean)
    }
  } else {
    carbon_3d <- carbon_stock
    height_3d <- canopy_height
    elev_3d <- elevation
  }

  # Convert to matrix (required by rayshader)
  carbon_matrix <- as.matrix(carbon_3d, wide = TRUE)
  height_matrix <- as.matrix(height_3d, wide = TRUE)

  # Replace NAs with 0 for visualization
  carbon_matrix[is.na(carbon_matrix)] <- 0
  height_matrix[is.na(height_matrix)] <- 0

  cat("Creating 3D carbon visualization...\n")

  # Create 3D visualization - Carbon draped over topography
  tryCatch({

    # Generate texture from carbon values
    carbon_colors <- height_shade(
      carbon_matrix,
      texture = grDevices::colorRampPalette(VIS_3D$carbon_palette)(256)
    )

    # 3D Plot 1: Carbon stock as texture, height as elevation
    carbon_colors %>%
      plot_3d(
        height_matrix,
        zscale = VIS_3D$z_scale,
        theta = VIS_3D$camera_theta,
        phi = VIS_3D$camera_phi,
        zoom = VIS_3D$camera_zoom,
        windowsize = c(1200, 1000)
      )

    # Add title
    render_label(
      height_matrix,
      x = nrow(height_matrix) / 2,
      y = ncol(height_matrix) / 2,
      z = max(height_matrix, na.rm = TRUE) * VIS_3D$z_scale * 1.2,
      text = "3D Forest Carbon Stock",
      textsize = 2,
      linewidth = 3
    )

    # Save snapshot
    render_snapshot(
      filename = file.path(OUTPUT_DIR, "carbon_3d_view1.png"),
      clear = FALSE
    )

    cat("3D view 1 saved\n")

    # Rotate camera for different view
    render_camera(theta = 135, phi = 25, zoom = 0.6)

    render_snapshot(
      filename = file.path(OUTPUT_DIR, "carbon_3d_view2.png"),
      clear = FALSE
    )

    cat("3D view 2 saved\n")

    # High quality render (optional - takes longer)
    if (VIS_3D$render_quality == "high") {
      cat("Creating high-quality render (this may take a few minutes)...\n")

      render_highquality(
        filename = file.path(OUTPUT_DIR, "carbon_3d_high_quality.png"),
        samples = 200,
        width = 2400,
        height = 2000,
        lightdirection = c(315, 310, 280, 330),
        lightintensity = c(600, 400, 500, 300),
        lightaltitude = c(45, 60, 30, 50)
      )

      cat("High-quality render saved\n")
    }

    # Close 3D window
    rgl::rgl.close()

  }, error = function(e) {
    cat("WARNING: 3D rendering failed. Error:", e$message, "\n")
    cat("Skipping 3D visualizations. Try installing XQuartz (Mac) or X11 (Linux).\n")
  })

} else {
  cat("Skipping 3D visualization - missing required layers\n")
}

# ==============================================================================
# STEP 6: INTERACTIVE WEB MAP (PLOTLY)
# ==============================================================================

cat("\n=== STEP 6: Creating Interactive Map ===\n")

if (!is.null(carbon_stock)) {

  # Sample data for interactive plot (full resolution too slow)
  carbon_sampled <- aggregate(carbon_stock, fact = 5, fun = mean)
  carbon_df_interactive <- as.data.frame(carbon_sampled, xy = TRUE, na.rm = TRUE)
  names(carbon_df_interactive)[3] <- "carbon"

  if (!is.null(canopy_height)) {
    height_sampled <- aggregate(canopy_height, fact = 5, fun = mean)
    height_values <- as.data.frame(height_sampled, xy = TRUE, na.rm = TRUE)[, 3]
    carbon_df_interactive$height <- height_values
  }

  # Create plotly surface plot
  tryCatch({

    # Reshape to matrix
    x_unique <- sort(unique(carbon_df_interactive$x))
    y_unique <- sort(unique(carbon_df_interactive$y))

    carbon_matrix_plotly <- matrix(
      NA,
      nrow = length(x_unique),
      ncol = length(y_unique)
    )

    for (i in 1:nrow(carbon_df_interactive)) {
      x_idx <- which(x_unique == carbon_df_interactive$x[i])
      y_idx <- which(y_unique == carbon_df_interactive$y[i])
      carbon_matrix_plotly[x_idx, y_idx] <- carbon_df_interactive$carbon[i]
    }

    # Create 3D surface
    interactive_plot <- plot_ly(
      x = x_unique,
      y = y_unique,
      z = t(carbon_matrix_plotly),
      type = "surface",
      colorscale = list(
        c(0, VIS_3D$carbon_palette[1]),
        c(0.25, VIS_3D$carbon_palette[2]),
        c(0.5, VIS_3D$carbon_palette[3]),
        c(0.75, VIS_3D$carbon_palette[4]),
        c(1, VIS_3D$carbon_palette[5])
      ),
      colorbar = list(title = "Carbon<br>(Mg C/ha)")
    ) %>%
      layout(
        title = "Interactive 3D Forest Carbon Map",
        scene = list(
          xaxis = list(title = "Easting (m)"),
          yaxis = list(title = "Northing (m)"),
          zaxis = list(title = "Carbon Stock (Mg C/ha)")
        )
      )

    # Save as HTML
    htmlwidgets::saveWidget(
      interactive_plot,
      file.path(OUTPUT_DIR, "carbon_3d_interactive.html"),
      selfcontained = TRUE
    )

    cat("Interactive 3D map saved (open in web browser)\n")

  }, error = function(e) {
    cat("WARNING: Interactive plot creation failed:", e$message, "\n")
  })
}

# ==============================================================================
# STEP 7: CARBON STOCK CLASSIFICATION
# ==============================================================================

cat("\n=== STEP 7: Carbon Stock Classification ===\n")

if (!is.null(carbon_stock)) {

  # Classify into categories
  carbon_classes <- classify(
    carbon_stock,
    rcl = matrix(
      c(
        0, 50, 1,      # Very Low
        50, 100, 2,    # Low
        100, 150, 3,   # Medium
        150, 200, 4,   # High
        200, 500, 5    # Very High
      ),
      ncol = 3,
      byrow = TRUE
    )
  )

  names(carbon_classes) <- "carbon_class"

  # Calculate area per class
  class_areas <- freq(carbon_classes)
  class_areas$area_ha <- class_areas$count * prod(res(carbon_stock)) / 10000
  class_areas$class_name <- c("Very Low (<50)", "Low (50-100)",
                              "Medium (100-150)", "High (150-200)",
                              "Very High (>200)")[class_areas$value]

  print(class_areas[, c("class_name", "area_ha")])

  write.csv(
    class_areas,
    file.path(OUTPUT_DIR, "carbon_classification_areas.csv"),
    row.names = FALSE
  )

  # Plot classification
  class_df <- as.data.frame(carbon_classes, xy = TRUE, na.rm = TRUE)
  names(class_df)[3] <- "class"

  map_classes <- ggplot(class_df, aes(x = x, y = y, fill = factor(class))) +
    geom_raster() +
    scale_fill_manual(
      values = VIS_3D$carbon_palette,
      labels = c("Very Low\n(<50)", "Low\n(50-100)", "Medium\n(100-150)",
                "High\n(150-200)", "Very High\n(>200)"),
      name = "Carbon Stock\n(Mg C/ha)"
    ) +
    coord_equal() +
    labs(
      title = "Carbon Stock Classification",
      x = "Easting (m)",
      y = "Northing (m)"
    ) +
    theme_minimal()

  ggsave(
    file.path(OUTPUT_DIR, "carbon_classification_map.png"),
    map_classes,
    width = 12,
    height = 10,
    dpi = 300
  )

  cat("Carbon classification saved\n")
}

# ==============================================================================
# STEP 8: MANAGEMENT RECOMMENDATIONS
# ==============================================================================

cat("\n=== STEP 8: Generating Management Recommendations ===\n")

if (!is.null(carbon_stock)) {

  # Identify high-carbon areas for protection
  high_carbon_threshold <- quantile(values(carbon_stock), 0.75, na.rm = TRUE)

  high_carbon_areas <- carbon_stock >= high_carbon_threshold
  names(high_carbon_areas) <- "priority_conservation"

  # Calculate priority conservation area
  priority_area_ha <- sum(values(high_carbon_areas), na.rm = TRUE) * prod(res(carbon_stock)) / 10000
  priority_carbon_Mg <- sum(values(carbon_stock * high_carbon_areas), na.rm = TRUE) * prod(res(carbon_stock)) / 10000

  management_summary <- data.frame(
    recommendation = c(
      "Total Study Area (ha)",
      "High Carbon Areas (top 25%)",
      "Priority Conservation Area (ha)",
      "Carbon in Priority Areas (Mg C)",
      "% of Total Carbon in Priority Areas"
    ),
    value = c(
      round(ncell(carbon_stock[!is.na(carbon_stock)]) * prod(res(carbon_stock)) / 10000, 1),
      paste(">", round(high_carbon_threshold, 0), "Mg C/ha"),
      round(priority_area_ha, 1),
      round(priority_carbon_Mg, 0),
      round(100 * priority_carbon_Mg / sum(values(carbon_stock), na.rm = TRUE), 1)
    )
  )

  print(management_summary)

  write.csv(
    management_summary,
    file.path(OUTPUT_DIR, "management_recommendations.csv"),
    row.names = FALSE
  )

  # Export priority conservation areas as shapefile
  priority_polygons <- as.polygons(high_carbon_areas)
  priority_polygons <- st_as_sf(priority_polygons)
  priority_polygons <- priority_polygons %>% filter(priority_conservation == 1)

  if (nrow(priority_polygons) > 0) {
    st_write(
      priority_polygons,
      file.path(OUTPUT_DIR, "priority_conservation_areas.shp"),
      delete_dsn = TRUE,
      quiet = TRUE
    )

    cat("Priority conservation areas exported\n")
  }
}

# ==============================================================================
# COMPLETION
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("3D CARBON MAPPING COMPLETE!\n")
cat(strrep("=", 80) %+% "\n\n")

if (exists("carbon_stats")) {
  cat("Carbon Stock Summary:\n")
  cat("  Mean:", carbon_stats$value[1], "Mg C/ha\n")
  cat("  Total:", carbon_stats$value[7], "Mg C\n")
  cat("  Area:", carbon_stats$value[6], "ha\n\n")
}

cat("Outputs:\n")
cat("  - 2D maps:", file.path(OUTPUT_DIR, "*_2d.png"), "\n")
cat("  - 3D visualizations:", file.path(OUTPUT_DIR, "carbon_3d_*.png"), "\n")
cat("  - Interactive map:", file.path(OUTPUT_DIR, "carbon_3d_interactive.html"), "\n")
cat("  - Statistics:", file.path(OUTPUT_DIR, "carbon_stock_statistics.csv"), "\n")
cat("  - Management recommendations:", file.path(OUTPUT_DIR, "management_recommendations.csv"), "\n\n")

cat("FOREST CARBON REMOTE SENSING WORKFLOW COMPLETE!\n")
cat("All three workflows (Drone, Sampling, Remote Sensing) are now ready to use.\n\n")
