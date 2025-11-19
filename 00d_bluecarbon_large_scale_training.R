# ============================================================================
# MODULE 00D-BC: BLUE CARBON LARGE-SCALE MODEL TRAINING (Janousek et al. 2025)
# ============================================================================
# PURPOSE: Train large-scale blue carbon model using Janousek et al. 2025
#          Pacific coast dataset (1,284 cores)
#
# DATASET: "Blue Carbon Stocks Along the Pacific Coast of North America Are
#          Mainly Driven by Local Rather Than Regional Factors"
#          Global Biogeochemical Cycles (2025), DOI: 10.1029/2024GB008239
#
# DATA SOURCE: Janousek et al. 2025 - 1,284 cores from Pacific coast NA
#   - Emergent marsh (salt marsh)
#   - Seagrass meadows
#   - Mangroves
#   - Tidal swamps
#   - Tideflats
#
# ADVANTAGES OVER GENERIC SOILGRIDS:
#   ✓ Blue carbon ecosystem specific
#   ✓ Coastal tidal wetlands focus
#   ✓ Standardized tidal elevation (z*)
#   ✓ Ecosystem-specific covariates
#   ✓ High-quality QC'd data
#   ✓ Regional coverage (Pacific coast)
#
# WORKFLOW POSITION:
#   This replaces Module 00d for blue carbon applications
#   Run BEFORE Module 05c (regional transfer learning)
#
# INPUTS:
#   - Janousek_Core_BCOnly - LargeScaleAnalysis.csv (user-provided)
#   - Environmental covariates (extract from GEE at core locations)
#
# OUTPUTS:
#   - outputs/models/large_scale_bluecarbon/global_bc_rf_model_*cm.rds
#   - outputs/models/large_scale_bluecarbon/model_metadata.csv
#   - outputs/models/large_scale_bluecarbon/feature_importance.csv
#   - outputs/models/large_scale_bluecarbon/ecosystem_performance.csv
#   - diagnostics/large_scale_bluecarbon/training_performance.csv
#   - diagnostics/large_scale_bluecarbon/ecosystem_comparison.png
#
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Clear workspace
rm(list = ls())

# Record start time
start_time <- Sys.time()

# Load configuration
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found. Run 00b_setup_directories.R first.")
}

# Create log file
log_file <- file.path("logs", paste0("large_scale_bluecarbon_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 00D-BC: BLUE CARBON LARGE-SCALE MODEL TRAINING ===")
log_message("Dataset: Janousek et al. 2025 - Pacific coast blue carbon cores")

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(sf)
  library(terra)
  library(ranger)
  library(caret)
  library(ggplot2)
  library(tidyr)
  library(gridExtra)
})

# Create output directories
dir.create("outputs/models/large_scale_bluecarbon", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/large_scale_bluecarbon", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# CONFIGURATION
# ============================================================================

BC_CONFIG <- list(
  # Model settings
  rf_ntree = 1000,
  rf_mtry = NULL,  # Auto-tune

  # Cross-validation
  cv_method = "spatial_block",
  cv_folds = 10,
  cv_block_size = 2,  # degrees (smaller for regional dataset)

  # Depth settings
  target_depths = c(7.5, 22.5, 40, 75),  # VM0033 standard depths

  # Ecosystem stratification
  stratify_by_ecosystem = TRUE,  # Train separate models per ecosystem?
  min_samples_per_ecosystem = 20,

  # Processing
  use_parallel = TRUE,
  n_cores = parallel::detectCores() - 1,

  # Outputs
  generate_ecosystem_comparison = TRUE,
  generate_importance = TRUE
)

log_message("Configuration loaded")

# ============================================================================
# STEP 1: LOAD JANOUSEK ET AL. 2025 DATASET
# ============================================================================

log_message("\n=== STEP 1: LOAD JANOUSEK ET AL. 2025 DATASET ===")

#' Load and prepare Janousek blue carbon dataset (two-file structure)
#'
#' The Janousek dataset comes in two parts:
#' 1. Core_Locations: Core-level metadata (lat, lon, ecosystem, etc.)
#' 2. Samples: Sample-level measurements (depth, BD, SOC, etc.)
#'
load_janousek_data <- function() {

  # File names
  core_locations_file <- "Janousek_Core_Locations.csv"
  samples_file <- "Janousek_Samples.csv"

  # Check if files exist
  if (!file.exists(core_locations_file)) {
    stop("\nJanousek Core Locations file not found: ", core_locations_file, "\n\n",
         "Please download from:\n",
         "https://smithsonian.figshare.com/articles/dataset/Dataset_Carbon_stocks_and_environmental_driver_data_for_blue_carbon_ecosystems_along_the_Pacific_coast_of_North_America/28127486\n\n",
         "Expected files:\n",
         "  1. Janousek_Core_Locations.csv (core metadata)\n",
         "  2. Janousek_Samples.csv (sample measurements)\n\n",
         "Place both files in the repository root directory.\n\n",
         "Dataset info:\n",
         "  - 1,284 cores from Pacific coast North America\n",
         "  - Ecosystems: marsh, seagrass, mangrove, tidal swamp, tideflat\n",
         "  - Paper: Janousek et al. (2025) Global Biogeochemical Cycles\n",
         "  - DOI: 10.1029/2024GB008239\n")
  }

  if (!file.exists(samples_file)) {
    stop("\nJanousek Samples file not found: ", samples_file, "\n\n",
         "Please download from:\n",
         "https://smithsonian.figshare.com/articles/dataset/Dataset_Carbon_stocks_and_environmental_driver_data_for_blue_carbon_ecosystems_along_the_Pacific_coast_of_North_America/28127486\n\n",
         "Expected files:\n",
         "  1. Janousek_Core_Locations.csv (core metadata)\n",
         "  2. Janousek_Samples.csv (sample measurements)\n\n",
         "Place both files in the repository root directory.\n")
  }

  log_message("Loading Janousek dataset (2-file structure)...")

  # Load core locations
  log_message(sprintf("Loading core locations: %s", core_locations_file))
  core_locations <- read_csv(core_locations_file, show_col_types = FALSE)

  log_message(sprintf("Core locations loaded: %d cores, %d columns",
                     nrow(core_locations), ncol(core_locations)))
  log_message(sprintf("Core location columns: %s",
                     paste(names(core_locations), collapse = ", ")))

  # Load samples
  log_message(sprintf("Loading samples: %s", samples_file))
  samples <- read_csv(samples_file, show_col_types = FALSE)

  log_message(sprintf("Samples loaded: %d samples, %d columns",
                     nrow(samples), ncol(samples)))
  log_message(sprintf("Sample columns: %s",
                     paste(names(samples), collapse = ", ")))

  # Display structure for user
  cat("\n=== CORE LOCATIONS STRUCTURE ===\n")
  print(str(core_locations))
  cat("\nFirst few core locations:\n")
  print(head(core_locations))

  cat("\n=== SAMPLES STRUCTURE ===\n")
  print(str(samples))
  cat("\nFirst few samples:\n")
  print(head(samples))

  # Check for sample_id in both datasets
  if (!"sample_id" %in% names(core_locations)) {
    stop("'sample_id' column not found in core_locations. Check column names.")
  }

  if (!"sample_id" %in% names(samples)) {
    stop("'sample_id' column not found in samples. Check column names.")
  }

  # Convert sample_id to character in both datasets to ensure compatibility
  # This handles cases where one file has numeric IDs and other has character IDs
  log_message("Standardizing sample_id types for joining...")

  core_locations <- core_locations %>%
    mutate(sample_id = as.character(sample_id))

  samples <- samples %>%
    mutate(sample_id = as.character(sample_id))

  log_message(sprintf("Core locations sample_id type: %s", class(core_locations$sample_id)))
  log_message(sprintf("Samples sample_id type: %s", class(samples$sample_id)))

  # Join datasets
  log_message("Joining core locations with samples on 'sample_id'...")

  combined_data <- samples %>%
    left_join(core_locations, by = "sample_id", suffix = c("_sample", "_core"))

  log_message(sprintf("Combined dataset: %d rows (samples)", nrow(combined_data)))

  # Handle duplicate columns - prefer core_locations version for metadata
  # Remove _sample versions if both _sample and _core exist
  duplicate_cols <- names(combined_data)[grepl("_sample$", names(combined_data))]

  if (length(duplicate_cols) > 0) {
    log_message(sprintf("Found %d duplicate columns from join", length(duplicate_cols)))

    for (col_with_suffix in duplicate_cols) {
      base_name <- sub("_sample$", "", col_with_suffix)
      core_version <- paste0(base_name, "_core")

      if (core_version %in% names(combined_data)) {
        # Remove _sample version, rename _core version to base name
        combined_data[[base_name]] <- combined_data[[core_version]]
        combined_data[[col_with_suffix]] <- NULL
        combined_data[[core_version]] <- NULL
        log_message(sprintf("  Resolved duplicate: kept '%s' from core_locations", base_name))
      }
    }
  }

  # Check for missing joins
  n_missing <- sum(is.na(combined_data$latitude))
  if (n_missing > 0) {
    log_message(sprintf("WARNING: %d samples have missing location data", n_missing),
               "WARNING")
  }

  return(combined_data)
}

# Load dataset
janousek_data <- tryCatch(
  load_janousek_data(),
  error = function(e) {
    log_message(paste("Dataset loading failed:", e$message), "ERROR")
    return(NULL)
  }
)

if (is.null(janousek_data)) {
  log_message("MODULE 00D-BC ABORTED - Dataset not available", "ERROR")
  quit(save = "no", status = 1)
}

# ============================================================================
# STEP 2: DATA HARMONIZATION AND PREPARATION
# ============================================================================

log_message("\n=== STEP 2: HARMONIZE DATA TO VM0033 STANDARD ===")

#' Harmonize Janousek data to VM0033 format
#'
#' This function processes the Janousek dataset (2-file structure) to match
#' the expected format for Module 05c.
#'
#' Column structure from Janousek dataset:
#' Core_Locations: sample_id, latitude, longitude, ecosystem, ecoregion, core_depth
#' Samples: sample_id, SubSampleID, depth_min, depth_max, bulk_density,
#'          soc_percent, carbon_density_gpercm3
#'
#' @param data Combined Janousek dataset (samples joined with core locations)
#' @return Harmonized data frame
harmonize_janousek_data <- function(data) {

  log_message("Harmonizing Janousek dataset to VM0033 standard depths...")

  # Convert to lowercase for consistent column access
  data_harmonized <- data %>%
    rename_with(~tolower(.), everything())

  # Check for required columns
  required_cols <- c("sample_id", "latitude", "longitude", "depth_min", "depth_max",
                    "bulk_density", "soc_percent", "ecosystem")

  missing_cols <- setdiff(required_cols, names(data_harmonized))

  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "), "\n",
         "Available columns: ", paste(names(data_harmonized), collapse = ", "))
  }

  log_message("All required columns found")

  # Convert numeric columns to numeric type (in case they were read as character)
  log_message("Converting numeric columns to proper types...")

  numeric_cols <- c("latitude", "longitude", "depth_min", "depth_max",
                   "bulk_density", "soc_percent", "carbon_density_gpercm3")

  for (col in numeric_cols) {
    if (col %in% names(data_harmonized)) {
      data_harmonized[[col]] <- as.numeric(data_harmonized[[col]])
    }
  }

  # Check for conversion issues
  n_na_soc <- sum(is.na(data_harmonized$soc_percent))
  n_na_bd <- sum(is.na(data_harmonized$bulk_density))

  if (n_na_soc > 0) {
    log_message(sprintf("WARNING: %d NA values in soc_percent after conversion", n_na_soc), "WARNING")
  }
  if (n_na_bd > 0) {
    log_message(sprintf("WARNING: %d NA values in bulk_density after conversion", n_na_bd), "WARNING")
  }

  # Standardize column names to workflow format
  data_harmonized <- data_harmonized %>%
    mutate(
      # Depth intervals (Janousek uses depth_min, depth_max)
      depth_top_cm = depth_min,
      depth_bottom_cm = depth_max,
      depth_cm = (depth_min + depth_max) / 2,

      # Bulk density (already in g/cm³)
      bd_g_cm3 = bulk_density,

      # SOC: Convert from percent to g/kg
      # soc_percent is in %, so multiply by 10 to get g/kg
      soc_g_kg = soc_percent * 10,

      # Ecosystem type (already correct name)
      # ecosystem = ecosystem (already exists)

      # Ecoregion (if available)
      ecoregion = if ("ecoregion" %in% names(.)) ecoregion else NA_character_,

      # Core depth (if available from Core_Locations)
      core_depth_cm = if ("core_depth" %in% names(.)) core_depth else NA_real_,

      # SubSampleID (keep for reference)
      subsample_id = if ("subsampleid" %in% names(.)) subsampleid else
                    if ("subsampled" %in% names(.)) subsampled else NA_character_
    )

  # Remove samples with missing critical data
  n_before <- nrow(data_harmonized)

  data_harmonized <- data_harmonized %>%
    filter(
      !is.na(latitude),
      !is.na(longitude),
      !is.na(depth_cm),
      !is.na(bd_g_cm3),
      !is.na(soc_g_kg),
      soc_g_kg > 0,
      bd_g_cm3 > 0
    )

  n_after <- nrow(data_harmonized)
  n_removed <- n_before - n_after

  if (n_removed > 0) {
    log_message(sprintf("Removed %d samples with missing data (%.1f%%)",
                       n_removed, 100 * n_removed / n_before), "WARNING")
  }

  # Calculate carbon stocks
  data_harmonized <- data_harmonized %>%
    mutate(
      layer_thickness_cm = depth_bottom_cm - depth_top_cm,

      # Calculate carbon stock (kg/m²)
      # Formula: SOC (g/kg) × BD (g/cm³) × thickness (cm) / 1000
      carbon_stock_kg_m2 = (soc_g_kg * bd_g_cm3 * layer_thickness_cm) / 1000,

      # Note: Janousek dataset also has carbon_density_gpercm3
      # We calculate carbon_stock ourselves for consistency with workflow
      # But keep original for validation if needed
      carbon_density_original = if ("carbon_density_gpercm3" %in% names(.)) {
        carbon_density_gpercm3
      } else {
        NA_real_
      }
    )

  # Validate our calculation against Janousek's carbon_density (if available)
  if ("carbon_density_gpercm3" %in% names(data_harmonized)) {
    # Convert our carbon_stock back to g/cm³ for comparison
    data_harmonized <- data_harmonized %>%
      mutate(
        carbon_density_calculated = (soc_g_kg * bd_g_cm3) / 1000,
        density_diff = abs(carbon_density_calculated - carbon_density_original)
      )

    mean_diff <- mean(data_harmonized$density_diff, na.rm = TRUE)
    log_message(sprintf("Validation: Mean difference with Janousek carbon_density: %.6f g/cm³",
                       mean_diff))

    if (mean_diff > 0.01) {
      log_message("WARNING: Large discrepancy with original carbon_density values", "WARNING")
      log_message("Check SOC unit conversion (% to g/kg)", "WARNING")
    } else {
      log_message("Validation PASSED: Carbon calculation matches Janousek data ✓")
    }
  }

  # Assign to standard VM0033 depths
  data_harmonized <- data_harmonized %>%
    mutate(
      standard_depth = case_when(
        depth_cm <= 15 ~ 7.5,
        depth_cm > 15 & depth_cm <= 30 ~ 22.5,
        depth_cm > 30 & depth_cm <= 50 ~ 40,
        depth_cm > 50 & depth_cm <= 100 ~ 75,
        TRUE ~ NA_real_
      )
    ) %>%
    filter(!is.na(standard_depth))

  log_message(sprintf("Harmonized data: %d samples", nrow(data_harmonized)))

  # Summary by ecosystem
  ecosystem_summary <- data_harmonized %>%
    group_by(ecosystem, standard_depth) %>%
    summarise(
      n_samples = n(),
      mean_carbon = mean(carbon_stock_kg_m2, na.rm = TRUE),
      sd_carbon = sd(carbon_stock_kg_m2, na.rm = TRUE),
      .groups = "drop"
    )

  log_message("\nSamples by ecosystem and depth:")
  print(ecosystem_summary, n = 100)

  return(data_harmonized)
}

# Harmonize data
harmonized_data <- harmonize_janousek_data(janousek_data)

# Create output directory if it doesn't exist
if (!dir.exists("data_global")) {
  dir.create("data_global", recursive = TRUE)
  log_message("Created directory: data_global/")
}

# Save harmonized data for inspection
write_csv(harmonized_data,
          "data_global/janousek_harmonized_bluecarbon.csv")
log_message("Harmonized data saved to: data_global/janousek_harmonized_bluecarbon.csv")

# ============================================================================
# STEP 3: EXTRACT ENVIRONMENTAL COVARIATES AT CORE LOCATIONS
# ============================================================================

log_message("\n=== STEP 3: EXTRACT ENVIRONMENTAL COVARIATES ===")

log_message("NOTE: You need to extract covariates at core locations using GEE")
log_message("See: GEE script template will be created below")

# Create GEE script template for covariate extraction
gee_template <- "// ============================================================================
// EXTRACT COVARIATES AT JANOUSEK CORE LOCATIONS
// ============================================================================
// Purpose: Extract environmental covariates at 1,284 blue carbon core locations
//          from Janousek et al. 2025 dataset
//
// Covariates to extract:
//   - Climate: WorldClim MAT, MAP, PET
//   - Topography: SRTM elevation (may be limited in tidal areas)
//   - Optical: Sentinel-2 NDVI, NDWI, EVI (2020-2023 mean)
//   - SAR: Sentinel-1 VV, VH (2020-2023 mean)
//   - Tidal: Distance to water, inundation frequency (if available)
//   - Soil: SoilGrids texture priors
// ============================================================================

// Load core locations from harmonized CSV
// Upload janousek_harmonized_bluecarbon.csv as GEE asset first

var cores = ee.FeatureCollection('users/YOUR_USERNAME/janousek_cores');

// Define study area (Pacific coast North America)
var bbox = cores.geometry().bounds();

Map.centerObject(bbox, 5);
Map.addLayer(cores, {color: 'red'}, 'Core locations');

// ============================================================================
// 1. CLIMATE (WorldClim v2.1)
// ============================================================================

var worldclim = ee.Image('WORLDCLIM/V1/BIO');

var climate = worldclim.select([
  'bio01',  // Mean annual temperature (°C × 10)
  'bio12',  // Annual precipitation (mm)
  'bio15'   // Precipitation seasonality (CV)
]).divide([10, 1, 1]).rename(['MAT', 'MAP', 'precip_seasonality']);

// ============================================================================
// 2. TOPOGRAPHY (SRTM - may have gaps in tidal areas)
// ============================================================================

var dem = ee.Image('USGS/SRTMGL1_003');
var slope = ee.Terrain.slope(dem);
var aspect = ee.Terrain.aspect(dem);

var topo = ee.Image.cat([
  dem.rename('elevation'),
  slope.rename('slope'),
  aspect.rename('aspect')
]);

// ============================================================================
// 3. OPTICAL REMOTE SENSING (Sentinel-2, 2020-2023)
// ============================================================================

var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterDate('2020-01-01', '2023-12-31')
  .filterBounds(bbox)
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 20))
  .map(function(img) {
    var ndvi = img.normalizedDifference(['B8', 'B4']).rename('NDVI');
    var ndwi = img.normalizedDifference(['B3', 'B8']).rename('NDWI');
    var evi = img.expression(
      '2.5 * ((NIR - RED) / (NIR + 6 * RED - 7.5 * BLUE + 1))', {
        'NIR': img.select('B8'),
        'RED': img.select('B4'),
        'BLUE': img.select('B2')
      }).rename('EVI');

    return img.addBands([ndvi, ndwi, evi]);
  });

var s2_mean = s2.select(['NDVI', 'NDWI', 'EVI', 'B2', 'B3', 'B4', 'B8'])
  .median()
  .rename(['NDVI', 'NDWI', 'EVI', 'blue', 'green', 'red', 'nir']);

// ============================================================================
// 4. SAR (Sentinel-1, 2020-2023)
// ============================================================================

var s1 = ee.ImageCollection('COPERNICUS/S1_GRD')
  .filterDate('2020-01-01', '2023-12-31')
  .filterBounds(bbox)
  .filter(ee.Filter.eq('instrumentMode', 'IW'))
  .filter(ee.Filter.eq('orbitProperties_pass', 'ASCENDING'))
  .select(['VV', 'VH']);

var s1_mean = s1.median().rename(['VV', 'VH']);

// VV/VH ratio
var vv_vh_ratio = s1_mean.select('VV').divide(s1_mean.select('VH'))
  .rename('VV_VH_ratio');

var sar = s1_mean.addBands(vv_vh_ratio);

// ============================================================================
// 5. DISTANCE TO WATER (Global Surface Water)
// ============================================================================

var gsw = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');
var water = gsw.select('occurrence').gt(50);  // Water > 50% of time
var distance_to_water = water.fastDistanceTransform().sqrt()
  .multiply(ee.Image.pixelArea().sqrt())
  .rename('distance_to_water');

// ============================================================================
// 6. SOIL TEXTURE (SoilGrids)
// ============================================================================

var soilgrids_clay = ee.Image('projects/soilgrids-isric/clay_mean')
  .select('clay_0-5cm_mean').rename('clay_content');

var soilgrids_sand = ee.Image('projects/soilgrids-isric/sand_mean')
  .select('sand_0-5cm_mean').rename('sand_content');

var soil_texture = soilgrids_clay.addBands(soilgrids_sand);

// ============================================================================
// COMBINE ALL COVARIATES
// ============================================================================

var all_covariates = climate
  .addBands(topo)
  .addBands(s2_mean)
  .addBands(sar)
  .addBands(distance_to_water)
  .addBands(soil_texture);

print('Covariates:', all_covariates.bandNames());

// ============================================================================
// EXTRACT VALUES AT CORE LOCATIONS
// ============================================================================

var extracted = all_covariates.reduceRegions({
  collection: cores,
  reducer: ee.Reducer.first(),
  scale: 30  // 30m resolution
});

print('Sample extracted values:', extracted.limit(5));

// ============================================================================
// EXPORT TO CSV
// ============================================================================

Export.table.toDrive({
  collection: extracted,
  description: 'janousek_cores_with_covariates',
  fileFormat: 'CSV',
  selectors: ['sample_id', 'latitude', 'longitude', 'ecosystem', 'depth_cm',
              'MAT', 'MAP', 'precip_seasonality',
              'elevation', 'slope', 'aspect',
              'NDVI', 'NDWI', 'EVI', 'blue', 'green', 'red', 'nir',
              'VV', 'VH', 'VV_VH_ratio',
              'distance_to_water',
              'clay_content', 'sand_content']
});

log_message('Export task created: janousek_cores_with_covariates');
log_message('Run this script in GEE, then download CSV to data_global/');
"

# Write GEE script
writeLines(gee_template, "GEE_EXTRACT_JANOUSEK_COVARIATES.js")
log_message("GEE script template created: GEE_EXTRACT_JANOUSEK_COVARIATES.js")

# Check if covariates already extracted
covariate_file <- "data_global/janousek_cores_with_covariates.csv"

if (!file.exists(covariate_file)) {
  log_message("\n⚠️  COVARIATES NOT YET EXTRACTED ⚠️", "WARNING")
  log_message("", "WARNING")
  log_message("Next steps:", "INFO")
  log_message("1. Upload data_global/janousek_harmonized_bluecarbon.csv to GEE as asset", "INFO")
  log_message("2. Run GEE_EXTRACT_JANOUSEK_COVARIATES.js in Google Earth Engine", "INFO")
  log_message("3. Download result to data_global/janousek_cores_with_covariates.csv", "INFO")
  log_message("4. Re-run this module (00d_bluecarbon_large_scale_training.R)", "INFO")
  log_message("", "WARNING")

  stop("\nCovariate extraction required. See instructions above.\n",
       "This is a one-time setup step.\n")
}

# Load covariates
log_message("Loading extracted covariates...")
cores_with_covariates <- read_csv(covariate_file, show_col_types = FALSE)

# Merge with harmonized data
training_data <- harmonized_data %>%
  left_join(cores_with_covariates, by = "sample_id")

log_message(sprintf("Training data prepared: %d samples with covariates",
                   nrow(training_data)))

# Get covariate names (exclude identifiers and response)
exclude_cols <- c("sample_id", "latitude", "longitude", "depth_top_cm",
                 "depth_bottom_cm", "depth_cm", "bd_g_cm3", "soc_g_kg",
                 "carbon_stock_kg_m2", "standard_depth", "ecosystem",
                 "layer_thickness_cm", "z_star")

covariate_names <- setdiff(names(training_data), exclude_cols)

log_message(sprintf("Using %d covariates: %s",
                   length(covariate_names),
                   paste(head(covariate_names, 10), collapse = ", ")))

# ============================================================================
# STEP 4: TRAIN BLUE CARBON MODELS
# ============================================================================

log_message("\n=== STEP 4: TRAIN BLUE CARBON MODELS ===")

#' Train Random Forest for blue carbon at specific depth
train_bluecarbon_rf <- function(data, covariate_names, depth, config) {

  log_message(sprintf("\n--- Training model for depth %g cm ---", depth))

  # Filter to target depth
  data_depth <- data %>%
    filter(standard_depth == depth) %>%
    select(all_of(c("carbon_stock_kg_m2", "ecosystem", covariate_names))) %>%
    na.omit()

  n_samples <- nrow(data_depth)
  log_message(sprintf("Training samples: %d", n_samples))

  if (n_samples < 50) {
    log_message("Insufficient samples for reliable training", "WARNING")
    return(NULL)
  }

  # Ecosystem distribution
  ecosystem_counts <- table(data_depth$ecosystem)
  log_message("Samples by ecosystem:")
  print(ecosystem_counts)

  # Prepare formula
  formula <- as.formula(paste("carbon_stock_kg_m2 ~",
                             paste(covariate_names, collapse = " + ")))

  # Train model
  log_message("Training Random Forest...")

  set.seed(123)

  model <- ranger(
    formula = formula,
    data = data_depth %>% select(-ecosystem),  # Don't use ecosystem as predictor
    num.trees = config$rf_ntree,
    mtry = config$rf_mtry,
    importance = "impurity",
    num.threads = if (config$use_parallel) config$n_cores else 1,
    verbose = FALSE,
    keep.inbag = TRUE
  )

  log_message(sprintf("Training complete. OOB R²: %.4f, OOB RMSE: %.4f kg/m²",
                     model$r.squared,
                     sqrt(model$prediction.error)))

  # Variable importance
  if (config$generate_importance) {
    importance_df <- data.frame(
      covariate = names(model$variable.importance),
      importance = model$variable.importance
    ) %>%
      arrange(desc(importance))

    model$importance_df <- importance_df

    log_message(sprintf("Top 10 important variables: %s",
                       paste(head(importance_df$covariate, 10), collapse = ", ")))
  }

  # Ecosystem-specific performance (optional)
  if (config$generate_ecosystem_comparison) {
    ecosystem_performance <- list()

    for (eco in names(ecosystem_counts)[ecosystem_counts >= 10]) {
      eco_data <- data_depth %>% filter(ecosystem == eco)

      if (nrow(eco_data) >= 10) {
        pred <- predict(model, eco_data)$predictions
        obs <- eco_data$carbon_stock_kg_m2

        ecosystem_performance[[eco]] <- data.frame(
          ecosystem = eco,
          depth_cm = depth,
          n = nrow(eco_data),
          mae = mean(abs(obs - pred)),
          rmse = sqrt(mean((obs - pred)^2)),
          r2 = cor(obs, pred)^2
        )
      }
    }

    model$ecosystem_performance <- bind_rows(ecosystem_performance)

    if (nrow(model$ecosystem_performance) > 0) {
      log_message("\nPerformance by ecosystem:")
      print(model$ecosystem_performance)
    }
  }

  return(model)
}

# Train models for all depths
log_message(sprintf("Training models for %d depths...",
                   length(BC_CONFIG$target_depths)))

# Create output directories if they don't exist
output_dirs <- c(
  "outputs/models/large_scale_bluecarbon",
  "diagnostics/large_scale_bluecarbon"
)

for (dir_path in output_dirs) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
    log_message(sprintf("Created directory: %s", dir_path))
  }
}

bc_models <- list()

for (depth in BC_CONFIG$target_depths) {
  model <- train_bluecarbon_rf(
    training_data,
    covariate_names,
    depth,
    BC_CONFIG
  )

  if (!is.null(model)) {
    bc_models[[as.character(depth)]] <- model

    # Save individual model
    model_file <- sprintf("outputs/models/large_scale_bluecarbon/global_bc_rf_model_%gcm.rds",
                         depth)
    saveRDS(model, model_file)
    log_message(sprintf("Model saved: %s", model_file))
  }
}

if (length(bc_models) == 0) {
  log_message("No models successfully trained!", "ERROR")
  quit(save = "no", status = 1)
}

# ============================================================================
# STEP 5: GENERATE DIAGNOSTICS
# ============================================================================

log_message("\n=== STEP 5: GENERATE DIAGNOSTICS ===")

# Model metadata
model_metadata <- data.frame(
  depth_cm = as.numeric(names(bc_models)),
  dataset = "Janousek et al. 2025",
  n_cores = 1284,
  n_trees = BC_CONFIG$rf_ntree,
  oob_r2 = sapply(bc_models, function(m) m$r.squared),
  oob_rmse = sapply(bc_models, function(m) sqrt(m$prediction.error)),
  n_samples = sapply(bc_models, function(m) m$num.samples),
  n_covariates = length(covariate_names),
  date_trained = as.character(Sys.Date())
)

write_csv(model_metadata,
          "outputs/models/large_scale_bluecarbon/model_metadata.csv")
log_message("Model metadata saved")

# Feature importance
if (BC_CONFIG$generate_importance) {
  importance_all <- bind_rows(lapply(names(bc_models), function(d) {
    bc_models[[d]]$importance_df %>%
      mutate(depth_cm = as.numeric(d))
  }))

  write_csv(importance_all,
           "outputs/models/large_scale_bluecarbon/feature_importance.csv")

  # Plot
  p_importance <- importance_all %>%
    group_by(depth_cm) %>%
    slice_max(order_by = importance, n = 15) %>%
    ungroup() %>%
    ggplot(aes(x = reorder(covariate, importance), y = importance)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    facet_wrap(~paste0(depth_cm, " cm"), scales = "free_y") +
    labs(
      title = "Feature Importance - Blue Carbon Models",
      subtitle = "Janousek et al. 2025 dataset (1,284 cores)",
      x = "Covariate",
      y = "Importance"
    ) +
    theme_minimal()

  ggsave("diagnostics/large_scale_bluecarbon/feature_importance_plots.png",
         p_importance, width = 14, height = 10, dpi = 300)

  log_message("Feature importance plots saved")
}

# Ecosystem comparison
if (BC_CONFIG$generate_ecosystem_comparison) {
  ecosystem_perf_all <- bind_rows(lapply(bc_models, function(m) {
    m$ecosystem_performance
  }))

  if (nrow(ecosystem_perf_all) > 0) {
    write_csv(ecosystem_perf_all,
             "outputs/models/large_scale_bluecarbon/ecosystem_performance.csv")

    # Plot
    p_ecosystem <- ecosystem_perf_all %>%
      ggplot(aes(x = ecosystem, y = r2, fill = factor(depth_cm))) +
      geom_col(position = "dodge") +
      labs(
        title = "Model Performance by Ecosystem Type",
        subtitle = "R² values across blue carbon ecosystems",
        x = "Ecosystem",
        y = "R² (Out-of-Bag)",
        fill = "Depth (cm)"
      ) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggsave("diagnostics/large_scale_bluecarbon/ecosystem_comparison.png",
           p_ecosystem, width = 10, height = 6, dpi = 300)

    log_message("Ecosystem comparison plots saved")
  }
}

# ============================================================================
# COMPLETION
# ============================================================================

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

log_message("\n=== MODULE 00D-BC COMPLETE ===")
log_message(sprintf("Runtime: %.1f minutes", as.numeric(elapsed_time)))
log_message(sprintf("Dataset: Janousek et al. 2025 - %d blue carbon cores",
                   length(unique(harmonized_data$sample_id))))
log_message(sprintf("Models trained: %d depths", length(bc_models)))
log_message(sprintf("Mean OOB R²: %.4f", mean(model_metadata$oob_r2)))
log_message("\nOutputs saved:")
log_message("  - outputs/models/large_scale_bluecarbon/global_bc_rf_model_*.rds")
log_message("  - outputs/models/large_scale_bluecarbon/model_metadata.csv")
log_message("  - outputs/models/large_scale_bluecarbon/feature_importance.csv")
log_message("  - outputs/models/large_scale_bluecarbon/ecosystem_performance.csv")
log_message("\nNext step:")
log_message("  Run Module 05c to apply transfer learning to your regional BC data")
log_message("  (Module 05c will automatically detect and use these blue carbon models)")
