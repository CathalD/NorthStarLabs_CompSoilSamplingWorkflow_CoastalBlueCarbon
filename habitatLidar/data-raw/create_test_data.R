#' Generate Synthetic Lidar Test Data
#'
#' Creates realistic synthetic lidar point cloud for testing and tutorials
#'
#' This script generates a simulated lidar dataset that mimics real airborne
#' lidar data with ground points, vegetation at multiple heights, and realistic
#' forest structure suitable for habitat analysis.

library(lidR)
library(sf)

# Set seed for reproducibility
set.seed(42)

# Create output directory
if (!dir.exists("inst/extdata")) {
  dir.create("inst/extdata", recursive = TRUE)
}

#' Generate synthetic lidar point cloud
#'
#' Creates a 200m x 200m tile with realistic forest structure
#'
#' @param area_size Size of area in meters (default 200)
#' @param point_density Target point density (pts/m², default 4)
#' @param n_trees Number of trees to simulate (default 80)
#' @return LAS object
generate_test_lidar <- function(area_size = 200, point_density = 4, n_trees = 80) {

  message("Generating synthetic lidar data...")

  # Calculate total points
  area_m2 <- area_size^2
  n_points <- round(area_m2 * point_density)

  # Generate random XY coordinates
  x <- runif(n_points, 0, area_size)
  y <- runif(n_points, 0, area_size)

  # Initialize Z values (will be populated)
  z <- numeric(n_points)
  classification <- rep(1L, n_points)  # Default: unclassified
  return_number <- rep(1L, n_points)
  number_of_returns <- rep(1L, n_points)
  intensity <- runif(n_points, 50, 255)

  # 1. Generate terrain (DTM) with some topography
  message("  - Creating terrain...")
  # Gentle slope and some undulation
  dtm <- 100 + 0.1 * x + 0.05 * y +
         3 * sin(x / 20) * cos(y / 20) +
         rnorm(n_points, 0, 0.3)  # Small noise

  # 2. Classify ground points (20% of points)
  message("  - Classifying ground points...")
  n_ground <- round(n_points * 0.20)
  ground_idx <- sample(1:n_points, n_ground)
  z[ground_idx] <- dtm[ground_idx] + rnorm(n_ground, 0, 0.1)
  classification[ground_idx] <- 2L  # Ground

  # 3. Generate trees with realistic structure
  message("  - Generating tree crowns...")

  # Tree parameters
  tree_x <- runif(n_trees, 10, area_size - 10)
  tree_y <- runif(n_trees, 10, area_size - 10)
  tree_height <- rgamma(n_trees, shape = 4, scale = 5) + 8  # 8-40m typical
  tree_crown_radius <- 0.3 * tree_height + rnorm(n_trees, 0, 0.5)
  tree_crown_radius[tree_crown_radius < 1] <- 1

  # For each point, determine if it's in a tree crown
  veg_idx <- setdiff(1:n_points, ground_idx)

  for (i in veg_idx) {
    # Distance to each tree
    dist_to_trees <- sqrt((x[i] - tree_x)^2 + (y[i] - tree_y)^2)

    # Find nearest tree
    nearest_tree <- which.min(dist_to_trees)
    dist <- dist_to_trees[nearest_tree]

    # If within crown radius
    if (dist < tree_crown_radius[nearest_tree]) {
      # Height within crown (conical shape)
      crown_fraction <- 1 - (dist / tree_crown_radius[nearest_tree])
      crown_base <- tree_height[nearest_tree] * 0.3  # Crown starts at 30% of height
      point_height <- crown_base + (tree_height[nearest_tree] - crown_base) * crown_fraction *
                      runif(1, 0.7, 1.0)  # Some variation

      z[i] <- dtm[i] + point_height
      classification[i] <- ifelse(point_height > 2, 5L, 3L)  # High veg or med veg

      # Multiple returns for vegetation
      if (runif(1) > 0.3) {
        return_number[i] <- sample(1:3, 1, prob = c(0.6, 0.3, 0.1))
        number_of_returns[i] <- sample(return_number[i]:3, 1)
      }

    } else {
      # Understory vegetation (shrubs, regeneration)
      if (runif(1) < 0.6) {  # 60% has understory
        understory_height <- rexp(1, rate = 1) + 0.5  # 0.5-5m typical
        if (understory_height > 5) understory_height <- 5

        z[i] <- dtm[i] + understory_height
        classification[i] <- 3L  # Medium vegetation

        if (runif(1) > 0.5) {
          return_number[i] <- sample(1:2, 1, prob = c(0.7, 0.3))
          number_of_returns[i] <- sample(return_number[i]:2, 1)
        }
      } else {
        # Low vegetation or ground
        z[i] <- dtm[i] + runif(1, 0, 0.5)
        classification[i] <- 2L
      }
    }
  }

  # 4. Add some noise points (very high or very low - to be filtered)
  message("  - Adding noise points...")
  n_noise <- round(n_points * 0.01)
  noise_idx <- sample(veg_idx, n_noise)
  z[noise_idx] <- dtm[noise_idx] + runif(n_noise, 50, 100)  # Unrealistic heights
  classification[noise_idx] <- 7L  # Low point (noise)

  # 5. Create LAS object
  message("  - Creating LAS object...")

  # Create data frame
  data <- data.frame(
    X = x,
    Y = y,
    Z = z,
    Intensity = as.integer(intensity),
    ReturnNumber = as.integer(return_number),
    NumberOfReturns = as.integer(number_of_returns),
    Classification = as.integer(classification),
    ScanAngle = rnorm(n_points, 0, 10),
    UserData = 0L,
    PointSourceID = 1L
  )

  # Create LAS header
  header <- lidR::LASheader(data)
  header@PHB[["X scale factor"]] <- 0.001
  header@PHB[["Y scale factor"]] <- 0.001
  header@PHB[["Z scale factor"]] <- 0.001
  header@PHB[["X offset"]] <- 0
  header@PHB[["Y offset"]] <- 0
  header@PHB[["Z offset"]] <- 0

  # Create LAS object
  las <- lidR::LAS(data, header, check = FALSE)

  # Set CRS (NAD83 UTM Zone 10N - common for BC/western Canada)
  sf::st_crs(las) <- 26910

  message(sprintf("  - Generated %s points over %s area",
                  format(n_points, big.mark = ","),
                  paste0(area_size, "m x ", area_size, "m")))
  message(sprintf("  - Ground points: %d (%.1f%%)", n_ground, n_ground/n_points*100))
  message(sprintf("  - Trees: %d", n_trees))

  return(las)
}

#' Generate multiple test tiles for batch processing tutorial
generate_test_catalog <- function(n_tiles = 4) {
  message("\nGenerating test catalog with ", n_tiles, " tiles...")

  catalog_dir <- "inst/extdata/catalog"
  if (!dir.exists(catalog_dir)) {
    dir.create(catalog_dir, recursive = TRUE)
  }

  for (i in 1:n_tiles) {
    message(sprintf("\nGenerating tile %d of %d...", i, n_tiles))

    # Vary the parameters slightly for each tile
    las <- generate_test_lidar(
      area_size = 200,
      point_density = runif(1, 3, 5),
      n_trees = round(runif(1, 60, 100))
    )

    # Offset coordinates for each tile
    offset_x <- ((i - 1) %% 2) * 200
    offset_y <- floor((i - 1) / 2) * 200

    las@data$X <- las@data$X + offset_x
    las@data$Y <- las@data$Y + offset_y

    # Update header
    las <- lidR::las_update(las)

    # Save
    filename <- file.path(catalog_dir, sprintf("tile_%d.las", i))
    lidR::writeLAS(las, filename)
    message(sprintf("  Saved: %s", filename))
  }

  message("\nCatalog generation complete!")
}

#' Create test area of interest polygon
generate_test_aoi <- function() {
  message("\nGenerating test area of interest polygon...")

  # Create a polygon representing a "traditional use area"
  # 50m x 50m area in the center of the test tile
  coords <- matrix(c(
    75, 75,
    125, 75,
    125, 125,
    75, 125,
    75, 75
  ), ncol = 2, byrow = TRUE)

  poly <- sf::st_polygon(list(coords))
  aoi <- sf::st_sf(
    id = 1,
    name = "Traditional Use Area",
    geometry = sf::st_sfc(poly, crs = 26910)
  )

  # Save
  sf::st_write(aoi, "inst/extdata/test_aoi.gpkg", delete_dsn = TRUE, quiet = TRUE)
  message("  Saved: inst/extdata/test_aoi.gpkg")

  return(aoi)
}

#' Create test species occurrence points
generate_test_occurrences <- function() {
  message("\nGenerating test species occurrence points...")

  # Simulate moose observations
  n_obs <- 15
  occurrences <- data.frame(
    species = "moose",
    lat = runif(n_obs, 75, 125),
    long = runif(n_obs, 75, 125),
    date = seq(as.Date("2023-01-01"), by = "week", length.out = n_obs),
    observer = "Field Survey"
  )

  # Save as CSV
  write.csv(occurrences, "inst/extdata/moose_occurrences.csv", row.names = FALSE)
  message("  Saved: inst/extdata/moose_occurrences.csv")

  # Also create as spatial points
  occ_sf <- sf::st_as_sf(
    occurrences,
    coords = c("long", "lat"),
    crs = 26910
  )

  sf::st_write(occ_sf, "inst/extdata/moose_occurrences.gpkg",
               delete_dsn = TRUE, quiet = TRUE)
  message("  Saved: inst/extdata/moose_occurrences.gpkg")

  return(occurrences)
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

message("========================================")
message("GENERATING TEST DATA FOR habitatLidar")
message("========================================\n")

# 1. Generate main test LAS file
message("Step 1: Main test LAS file")
message("---------------------------")
las_test <- generate_test_lidar(area_size = 200, point_density = 4, n_trees = 80)
lidR::writeLAS(las_test, "inst/extdata/test_tile.las")
message("✓ Saved: inst/extdata/test_tile.las\n")

# 2. Generate catalog for batch processing
message("\nStep 2: Test catalog (4 tiles)")
message("-------------------------------")
generate_test_catalog(n_tiles = 4)

# 3. Generate AOI polygon
message("\nStep 3: Area of Interest")
message("------------------------")
aoi <- generate_test_aoi()

# 4. Generate species occurrences
message("\nStep 4: Species Occurrences")
message("---------------------------")
occurrences <- generate_test_occurrences()

# 5. Create a README for the test data
message("\nStep 5: Documentation")
message("---------------------")

readme_content <- "# Test Data for habitatLidar Package

## Overview

This directory contains synthetic lidar data and associated files for testing
and tutorial purposes.

## Files

### Lidar Point Clouds

- **test_tile.las** (200m x 200m, ~160,000 points)
  - Main test dataset for tutorials
  - Point density: ~4 pts/m²
  - Contains ~80 trees with realistic structure
  - Includes ground, vegetation, and noise points
  - CRS: NAD83 UTM Zone 10N (EPSG:26910)

- **catalog/** (4 tiles, 400m x 400m total coverage)
  - For batch processing tutorials
  - Each tile: 200m x 200m
  - Varying point densities and tree counts

### Spatial Data

- **test_aoi.gpkg** - Test area of interest polygon (50m x 50m)
  - Represents a \"traditional use area\" for habitat assessment

- **moose_occurrences.gpkg/csv** - Simulated moose observation points
  - 15 observations with dates
  - For validating habitat model predictions

## Data Characteristics

### Forest Structure

The synthetic data mimics a mixed boreal/coastal forest:

- **Tree heights**: 8-40m (gamma distribution)
- **Crown structure**: Conical crowns with realistic crown:height ratios
- **Understory**: ~60% coverage, 0.5-5m height
- **Ground points**: ~20% of total
- **Old-growth indicators**: Several trees >30m

### Point Classifications

- **2**: Ground
- **3**: Medium vegetation (0.5-2m)
- **5**: High vegetation (>2m)
- **7**: Noise (to be filtered)

### Terrain

- Gentle slope with undulation
- Elevation range: ~100-110m
- Realistic for analysis without extreme topography

## Usage in Tutorials

See the package vignettes for step-by-step tutorials using this data:

```r
# Load test data
las <- lidR::readLAS(system.file(\"extdata/test_tile.las\", package = \"habitatLidar\"))

# Load AOI
aoi <- sf::st_read(system.file(\"extdata/test_aoi.gpkg\", package = \"habitatLidar\"))
```

## Regenerating Test Data

To regenerate this test data (e.g., with different parameters):

```r
source(\"data-raw/create_test_data.R\")
```

## Notes

- Data is synthetic and for demonstration only
- Does NOT represent any real location
- Designed to demonstrate package functionality and produce realistic outputs
- Point density and structure are typical of Canadian government lidar data
"

writeLines(readme_content, "inst/extdata/README.md")
message("✓ Saved: inst/extdata/README.md\n")

# Summary
message("\n========================================")
message("TEST DATA GENERATION COMPLETE!")
message("========================================\n")
message("Generated files:")
message("  - inst/extdata/test_tile.las (main test file)")
message("  - inst/extdata/catalog/ (4 tiles for batch processing)")
message("  - inst/extdata/test_aoi.gpkg (area of interest)")
message("  - inst/extdata/moose_occurrences.gpkg/csv")
message("  - inst/extdata/README.md (documentation)")
message("\nTotal size: ~", round(sum(file.size(list.files("inst/extdata",
                                                          full.names = TRUE,
                                                          recursive = TRUE))) / 1024 / 1024, 1), " MB")
message("\nReady for tutorials! See vignettes/complete_tutorial.Rmd\n")
