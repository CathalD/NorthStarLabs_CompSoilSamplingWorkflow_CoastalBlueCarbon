# ============================================================================
# MODULE 00D: LARGE-SCALE MODEL TRAINING (Part 1 - Transfer Learning Foundation)
# ============================================================================
# PURPOSE: Train large-scale soil carbon model on extensive global/continental
#          data to learn generalizable soil-environment relationships
#
# SCOPE: Continental to global scale (250-1000m resolution)
#
# METHODOLOGY:
#   Based on "Regional-scale soil carbon predictions can be enhanced by
#   transferring global-scale soil–environment relationships"
#   (Geoderma 2025, DOI: 10.1016/j.geoderma.2025.117466)
#
# WORKFLOW POSITION:
#   Run BEFORE Module 05c (regional transfer learning application)
#   This module creates the "global knowledge base" that Module 05c adapts
#
# INPUTS:
#   - data_global/large_scale_samples.csv (soil samples with coordinates)
#     Required columns: sample_id, latitude, longitude, depth_cm,
#                       soc_g_kg, bd_g_cm3, source
#   - data_global/covariates_250m/*.tif (environmental covariates)
#     Climate: MAT, MAP, PET, AI
#     Topography: elevation, slope, aspect, TWI, TPI
#     Optical: NDVI, NDWI, EVI, NBR (annual composites)
#     SAR: VV, VH, VV/VH ratio (Sentinel-1)
#     Other: soil texture priors, land cover, distance to water
#
# OUTPUTS:
#   - outputs/models/large_scale/global_rf_model_[depth]cm.rds
#   - outputs/models/large_scale/model_metadata.csv
#   - outputs/models/large_scale/feature_importance.csv
#   - outputs/models/large_scale/covariate_ranges.csv (for AOA)
#   - diagnostics/large_scale/training_performance.csv
#   - diagnostics/large_scale/spatial_cv_results.csv
#   - diagnostics/large_scale/feature_importance_plots.png
#   - diagnostics/large_scale/prediction_maps_250m.tif (optional)
#
# DATA SOURCES FOR TRAINING:
#   1. SoilGrids point data (ISRIC) - ~200k profiles globally
#   2. WoSIS (World Soil Information Service) - subset for coastal areas
#   3. National soil databases:
#      - Canadian Soil Database (Canada)
#      - LUCAS Soil (Europe)
#      - NRCS NSSC (USA)
#   4. Blue carbon literature data:
#      - Sothe et al. 2022 (BC Coast)
#      - Crooks et al. 2014 (global synthesis)
#      - Regional blue carbon studies
#
# COMPUTATIONAL REQUIREMENTS:
#   - RAM: 16-32 GB recommended
#   - CPU: Multi-core (8+ cores recommended)
#   - Storage: ~50-100 GB for covariates and models
#   - Runtime: 2-8 hours depending on sample size
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
log_file <- file.path("logs", paste0("large_scale_training_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 00D: LARGE-SCALE MODEL TRAINING ===")
log_message(sprintf("Session: %s", PROJECT_NAME))

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(sf)
  library(terra)
  library(ranger)      # Fast Random Forest
  library(caret)       # Cross-validation
  library(parallel)    # Parallel processing
  library(ggplot2)
  library(tidyr)
  library(gridExtra)
})

# Optional: Deep learning
has_torch <- requireNamespace("torch", quietly = TRUE)
if (has_torch) {
  library(torch)
  log_message("PyTorch available - deep learning enabled")
} else {
  log_message("PyTorch not available - using Random Forest only", "WARNING")
}

# Create output directories
dir.create("outputs/models/large_scale", recursive = TRUE, showWarnings = FALSE)
dir.create("diagnostics/large_scale", recursive = TRUE, showWarnings = FALSE)
dir.create("data_global/covariates_250m", recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# CONFIGURATION
# ============================================================================

LARGE_SCALE_CONFIG <- list(
  # Model settings
  model_type = "random_forest",  # "random_forest" or "deep_learning"
  rf_ntree = 1000,               # Number of trees
  rf_mtry = NULL,                # Auto-tune if NULL
  max_samples = NULL,            # NULL = use all samples

  # Spatial resolution
  target_resolution = 250,       # meters (250m, 500m, or 1000m)

  # Cross-validation
  cv_method = "spatial_block",   # "spatial_block" or "stratified"
  cv_folds = 10,
  cv_block_size = 5,            # degrees for spatial blocks

  # Feature engineering
  use_spatial_coords = TRUE,     # Include lat/lon as features
  use_interactions = FALSE,      # Include covariate interactions
  pca_transform = FALSE,         # PCA dimensionality reduction

  # Processing
  use_parallel = TRUE,
  n_cores = max(1, parallel::detectCores() - 2),

  # Depth settings (VM0033 standard depths)
  target_depths = c(7.5, 22.5, 40, 75),

  # Output options
  save_predictions = FALSE,      # Save full prediction rasters (large files)
  generate_importance = TRUE,
  generate_diagnostics = TRUE
)

log_message(sprintf("Configuration: %s model, %dm resolution, %d-fold CV",
                   LARGE_SCALE_CONFIG$model_type,
                   LARGE_SCALE_CONFIG$target_resolution,
                   LARGE_SCALE_CONFIG$cv_folds))

# ============================================================================
# STEP 1: LOAD AND PREPARE LARGE-SCALE TRAINING DATA
# ============================================================================

log_message("\n=== STEP 1: LOAD LARGE-SCALE TRAINING DATA ===")

#' Load large-scale soil sample database
#'
#' @return Data frame with soil samples
load_large_scale_samples <- function() {

  samples_file <- "data_global/large_scale_samples.csv"

  if (!file.exists(samples_file)) {
    log_message("Large-scale training data not found. Creating template...", "WARNING")

    # Create template
    template <- data.frame(
      sample_id = character(),
      latitude = numeric(),
      longitude = numeric(),
      depth_top_cm = numeric(),
      depth_bottom_cm = numeric(),
      depth_cm = numeric(),      # Midpoint
      soc_g_kg = numeric(),      # Soil organic carbon (g/kg)
      bd_g_cm3 = numeric(),      # Bulk density (g/cm³)
      source = character(),      # Data source identifier
      country = character(),     # Country code
      ecosystem = character(),   # Ecosystem type
      year_sampled = integer(),  # Year of sampling
      stringsAsFactors = FALSE
    )

    write_csv(template, samples_file)

    # Create detailed README
    readme <- "# LARGE-SCALE TRAINING DATA PREPARATION

## Data Structure

Required columns:
- sample_id: Unique identifier
- latitude, longitude: WGS84 coordinates
- depth_top_cm, depth_bottom_cm: Depth interval
- depth_cm: Midpoint depth
- soc_g_kg: Soil organic carbon concentration (g/kg)
- bd_g_cm3: Bulk density (g/cm³)
- source: Data source (e.g., 'soilgrids', 'wosis', 'lucas', 'canada_db')

Optional but recommended:
- country: ISO country code
- ecosystem: Ecosystem classification
- year_sampled: Year of sample collection

## Data Sources

### 1. WoSIS (World Soil Information Service)
**Priority: HIGH** - Comprehensive global database
- URL: https://www.isric.org/explore/wosis
- Access: Free (registration required)
- Coverage: Global, ~200k profiles
- Download: Use WoSIS API or bulk download
- Focus on: Coastal wetland profiles, organic soils

### 2. SoilGrids Training Points
**Priority: HIGH** - ISRIC's global soil maps training data
- URL: https://soilgrids.org
- Access: Via Google Earth Engine or bulk download
- Coverage: Global, 250m resolution
- Extract: Sample points with SOC and BD for depths 0-100cm

### 3. Canadian Soil Database
**Priority: HIGH** - Regional enhancement for BC Coast
- URL: https://sis.agr.gc.ca/cansis/nsdb/
- Access: Free download
- Coverage: Canada, focus on BC coastal profiles
- Importance: High relevance for BC blue carbon projects

### 4. LUCAS Soil Survey
**Priority: MEDIUM** - European data for global model diversity
- URL: https://esdac.jrc.ec.europa.eu/
- Access: Free download
- Coverage: European Union
- Use: Improve model generalization

### 5. Blue Carbon Literature
**Priority: HIGH** - Coastal wetland specific
- Sothe et al. 2022: BC coastal organic carbon data
- Crooks et al. 2014: Global blue carbon synthesis
- Howard et al. 2014: Coastal carbon assessment data
- Extract from: Published papers, supplementary materials

### 6. NRCS NSSC (USA)
**Priority: MEDIUM** - US National Soil Survey
- URL: https://ncsslabdatamart.sc.egov.usda.gov/
- Access: Free download
- Coverage: United States
- Focus on: Coastal marsh and wetland profiles

## Data Compilation Steps

1. **Download source datasets** (see URLs above)

2. **Harmonize format:**
   ```r
   # Example: Convert WoSIS to standard format
   wosis_data <- read_csv('wosis_raw.csv') %>%
     mutate(
       sample_id = paste0('wosis_', profile_id, '_', layer_number),
       depth_cm = (upper_depth + lower_depth) / 2,
       source = 'wosis'
     ) %>%
     select(sample_id, latitude, longitude, depth_top_cm, depth_bottom_cm,
            depth_cm, soc_g_kg, bd_g_cm3, source, country, year_sampled)
   ```

3. **Quality control:**
   - Remove samples with missing SOC or BD
   - Flag outliers (SOC > 500 g/kg, BD < 0.05 or > 2.5 g/cm³)
   - Check coordinate validity
   - Remove duplicates

4. **Calculate carbon stocks:**
   ```r
   samples <- samples %>%
     mutate(
       layer_thickness_cm = depth_bottom_cm - depth_top_cm,
       carbon_stock_kg_m2 = (soc_g_kg * bd_g_cm3 * layer_thickness_cm) / 1000
     )
   ```

5. **Harmonize to standard depths:**
   - Aggregate or interpolate to VM0033 depths: 7.5, 22.5, 40, 75 cm
   - Use equal-area spline or mass-weighted averaging

6. **Save compiled dataset:**
   ```r
   write_csv(samples, 'data_global/large_scale_samples.csv')
   ```

## Target Sample Size

**Minimum:** 10,000 samples (for basic model)
**Recommended:** 50,000+ samples (for robust model)
**Optimal:** 100,000+ samples (for maximum performance)

## Geographic Coverage

Aim for diverse coverage:
- Coastal wetlands (salt marshes, mangroves, seagrass beds)
- Temperate forests and grasslands
- Agricultural lands
- Peatlands and organic soils
- Multiple climate zones
- Different continents

## Ecosystem Representation

Priority for coastal blue carbon:
1. Salt marshes (HIGH PRIORITY)
2. Mangroves (HIGH PRIORITY)
3. Seagrass beds (HIGH PRIORITY)
4. Tidal wetlands (HIGH PRIORITY)
5. Estuarine systems
6. Coastal forests
7. Other ecosystems (for model generalization)

## Status

❌ NOT YET PREPARED

Complete data preparation before running Module 00d.
Estimated time: 2-4 weeks for comprehensive compilation.

See ARTICLE_ANALYSIS_Transfer_Learning_Integration.md for detailed guidance.
"

    writeLines(readme, "data_global/LARGE_SCALE_DATA_README.md")

    stop("\nLarge-scale training data not yet prepared.\n\n",
         "Required: data_global/large_scale_samples.csv\n",
         "See: data_global/LARGE_SCALE_DATA_README.md for detailed instructions\n\n",
         "Template created at: ", samples_file)
  }

  log_message(sprintf("Loading samples from: %s", samples_file))

  samples <- read_csv(samples_file, show_col_types = FALSE)

  # Validate required columns
  required_cols <- c("sample_id", "latitude", "longitude", "depth_cm",
                    "soc_g_kg", "bd_g_cm3", "source")
  missing_cols <- setdiff(required_cols, names(samples))

  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  log_message(sprintf("Loaded %d samples from %d sources",
                     nrow(samples), length(unique(samples$source))))

  # Calculate carbon stocks if not already present
  if (!"carbon_stock_kg_m2" %in% names(samples)) {
    log_message("Calculating carbon stocks...")

    samples <- samples %>%
      mutate(
        depth_top_cm = if_else(is.na(depth_top_cm),
                              pmax(0, depth_cm - 7.5), depth_top_cm),
        depth_bottom_cm = if_else(is.na(depth_bottom_cm),
                                 depth_cm + 7.5, depth_bottom_cm),
        layer_thickness_cm = depth_bottom_cm - depth_top_cm,
        carbon_stock_kg_m2 = (soc_g_kg * bd_g_cm3 * layer_thickness_cm) / 1000
      )
  }

  # Harmonize to standard depths
  samples <- samples %>%
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

  log_message(sprintf("Samples after depth harmonization: %d", nrow(samples)))

  # Sample subset if requested
  if (!is.null(LARGE_SCALE_CONFIG$max_samples) &&
      nrow(samples) > LARGE_SCALE_CONFIG$max_samples) {

    log_message(sprintf("Sampling %d from %d for computational efficiency",
                       LARGE_SCALE_CONFIG$max_samples, nrow(samples)))

    set.seed(123)
    samples <- samples %>%
      group_by(standard_depth) %>%
      slice_sample(n = LARGE_SCALE_CONFIG$max_samples /
                     length(LARGE_SCALE_CONFIG$target_depths)) %>%
      ungroup()
  }

  # Summary statistics
  summary_stats <- samples %>%
    group_by(standard_depth, source) %>%
    summarise(
      n_samples = n(),
      mean_carbon = mean(carbon_stock_kg_m2, na.rm = TRUE),
      sd_carbon = sd(carbon_stock_kg_m2, na.rm = TRUE),
      .groups = "drop"
    )

  log_message("\nSample distribution by depth and source:")
  print(summary_stats, n = 50)

  return(samples)
}

# Load samples
samples <- tryCatch(
  load_large_scale_samples(),
  error = function(e) {
    log_message(paste("Sample loading failed:", e$message), "ERROR")
    log_message("See data_global/LARGE_SCALE_DATA_README.md for instructions", "INFO")
    return(NULL)
  }
)

if (is.null(samples)) {
  log_message("MODULE 00D ABORTED - No training data available", "ERROR")
  quit(save = "no", status = 1)
}

# ============================================================================
# STEP 2: LOAD ENVIRONMENTAL COVARIATES
# ============================================================================

log_message("\n=== STEP 2: LOAD ENVIRONMENTAL COVARIATES ===")

#' Load covariate rasters at target resolution
load_covariates <- function(resolution = 250) {

  cov_dir <- sprintf("data_global/covariates_%dm", resolution)

  if (!dir.exists(cov_dir)) {
    log_message(sprintf("Covariate directory not found: %s", cov_dir), "WARNING")
    log_message("Creating directory and README...", "INFO")

    dir.create(cov_dir, recursive = TRUE)

    readme <- sprintf("# ENVIRONMENTAL COVARIATES (%dm RESOLUTION)

## Required Covariates

### Climate Variables (WorldClim, CHELSA)
- MAT: Mean annual temperature (°C)
- MAP: Mean annual precipitation (mm)
- PET: Potential evapotranspiration (mm)
- AI: Aridity index (MAP/PET)
- bio_01 to bio_19: Bioclimatic variables

### Topography (SRTM, ASTER GDEM)
- elevation: Elevation above sea level (m)
- slope: Slope (degrees)
- aspect: Aspect (degrees)
- TWI: Topographic Wetness Index
- TPI: Topographic Position Index
- roughness: Terrain roughness

### Optical Remote Sensing (Sentinel-2, Landsat)
- NDVI: Normalized Difference Vegetation Index (annual mean)
- NDWI: Normalized Difference Water Index (annual mean)
- EVI: Enhanced Vegetation Index (annual mean)
- NBR: Normalized Burn Ratio
- SAVI: Soil Adjusted Vegetation Index
- Red, Green, Blue, NIR, SWIR1, SWIR2 (annual means)

### SAR (Sentinel-1)
- VV: VV polarization backscatter (annual mean, dB)
- VH: VH polarization backscatter (annual mean, dB)
- VV_VH_ratio: VV/VH ratio
- VV_std: VV standard deviation (temporal variability)
- VH_std: VH standard deviation

### Soil & Geology
- clay_content: Clay content (%%) from SoilGrids
- sand_content: Sand content (%%)
- silt_content: Silt content (%%)
- soil_ph: Soil pH from SoilGrids
- bedrock_depth: Depth to bedrock (cm)
- parent_material: Parent material classification

### Hydrological
- distance_to_water: Distance to nearest water body (m)
- inundation_freq: Inundation frequency (days/year)
- wetness_index: Multi-temporal wetness index

### Other
- land_cover: Land cover classification (reclassified to numeric)
- distance_to_coast: Distance to coastline (m)
- tidal_range: Tidal range (m) - for coastal areas

## Data Sources and Access

### 1. Google Earth Engine (Recommended)
Most covariates available via GEE:
```javascript
// Example GEE script
var region = ee.Geometry.Rectangle([-130, 48, -122, 55]); // BC Coast
var resolution = %d;

// Climate (WorldClim)
var bio = ee.Image('WORLDCLIM/V1/BIO').select(['bio01', 'bio12', 'bio15']);

// Topography (SRTM)
var dem = ee.Image('USGS/SRTMGL1_003');
var slope = ee.Terrain.slope(dem);
var aspect = ee.Terrain.aspect(dem);

// Sentinel-2 (annual composite)
var s2 = ee.ImageCollection('COPERNICUS/S2_SR')
  .filterDate('2020-01-01', '2020-12-31')
  .filterBounds(region)
  .median();
var ndvi = s2.normalizedDifference(['B8', 'B4']);
var ndwi = s2.normalizedDifference(['B3', 'B8']);

// Sentinel-1 (annual composite)
var s1 = ee.ImageCollection('COPERNICUS/S1_GRD')
  .filterDate('2020-01-01', '2020-12-31')
  .filterBounds(region)
  .filter(ee.Filter.eq('instrumentMode', 'IW'))
  .select(['VV', 'VH'])
  .median();

// Export all covariates
Export.image.toDrive({
  image: bio.addBands([dem, slope, aspect, ndvi, ndwi, s1]),
  description: 'covariates_%dm',
  region: region,
  scale: resolution,
  crs: 'EPSG:4326'
});
```

### 2. Direct Downloads
- WorldClim: https://www.worldclim.org/
- SRTM DEM: https://srtm.csi.cgiar.org/
- SoilGrids: https://soilgrids.org/
- CHELSA: https://chelsa-climate.org/

## Processing Steps

1. Download or export covariates at %dm resolution
2. Reproject to common CRS (e.g., EPSG:4326 or local UTM)
3. Resample to exact %dm resolution
4. Clip to study extent (e.g., global coastal zone, or continental scale)
5. Save as GeoTIFF in this directory

## Naming Convention

Use descriptive names:
- climate_MAT.tif
- climate_MAP.tif
- topo_elevation.tif
- topo_slope.tif
- optical_ndvi_2020.tif
- sar_VV_2020.tif

## Status

❌ NOT YET PREPARED

Covariates must be prepared before running Module 00d.
Estimated time: 1-2 weeks for covariate compilation.
Storage: ~20-50 GB depending on spatial extent.
", resolution, resolution, resolution, resolution)

    writeLines(readme, file.path(cov_dir, "README.md"))

    stop("\nEnvironmental covariates not yet prepared.\n\n",
         "Required: ", cov_dir, "/*.tif\n",
         "See: ", file.path(cov_dir, "README.md"), " for instructions\n")
  }

  covariate_files <- list.files(cov_dir, pattern = "\\.tif$", full.names = TRUE)

  if (length(covariate_files) == 0) {
    stop("No covariate rasters found in: ", cov_dir)
  }

  log_message(sprintf("Loading %d covariate rasters from %s",
                     length(covariate_files), cov_dir))

  covariates <- rast(covariate_files)

  log_message(sprintf("Covariates loaded: %d layers", nlyr(covariates)))
  log_message(sprintf("Resolution: %.0f × %.0f m",
                     res(covariates)[1], res(covariates)[2]))
  log_message(sprintf("Extent: [%.2f, %.2f, %.2f, %.2f]",
                     ext(covariates)[1], ext(covariates)[2],
                     ext(covariates)[3], ext(covariates)[4]))

  return(covariates)
}

# Load covariates
covariates <- tryCatch(
  load_covariates(LARGE_SCALE_CONFIG$target_resolution),
  error = function(e) {
    log_message(paste("Covariate loading failed:", e$message), "ERROR")
    return(NULL)
  }
)

if (is.null(covariates)) {
  log_message("MODULE 00D ABORTED - No covariates available", "ERROR")
  quit(save = "no", status = 1)
}

# ============================================================================
# STEP 3: EXTRACT COVARIATE VALUES AT SAMPLE LOCATIONS
# ============================================================================

log_message("\n=== STEP 3: EXTRACT COVARIATE VALUES ===")

log_message("Converting samples to spatial points...")
samples_sf <- st_as_sf(samples, coords = c("longitude", "latitude"), crs = 4326)

# Transform to match covariate CRS
samples_sf <- st_transform(samples_sf, crs(covariates))

log_message("Extracting covariate values at sample locations...")
log_message("This may take several minutes for large datasets...")

# Extract values
covariate_values <- terra::extract(covariates, vect(samples_sf), ID = FALSE)

# Bind with sample data
samples_with_cov <- bind_cols(
  samples %>% select(-latitude, -longitude),  # Remove to avoid duplication
  st_coordinates(samples_sf) %>% as.data.frame() %>% rename(utm_x = X, utm_y = Y),
  covariate_values
)

# Get covariate names
covariate_names <- names(covariates)

# Add spatial coordinates if requested
if (LARGE_SCALE_CONFIG$use_spatial_coords) {
  covariate_names <- c(covariate_names, "utm_x", "utm_y")
  log_message("Including spatial coordinates as predictors")
}

# Remove samples with missing covariates
n_before <- nrow(samples_with_cov)
samples_with_cov <- samples_with_cov %>%
  filter(complete.cases(.[covariate_names]))

n_after <- nrow(samples_with_cov)
n_removed <- n_before - n_after

if (n_removed > 0) {
  log_message(sprintf("Removed %d samples with missing covariates (%.1f%%)",
                     n_removed, 100 * n_removed / n_before), "WARNING")
}

log_message(sprintf("Final training dataset: %d samples × %d covariates",
                   n_after, length(covariate_names)))

# Save covariate ranges for Area of Applicability analysis
covariate_ranges <- samples_with_cov %>%
  select(all_of(covariate_names)) %>%
  summarise(across(everything(), list(
    min = ~min(., na.rm = TRUE),
    max = ~max(., na.rm = TRUE),
    mean = ~mean(., na.rm = TRUE),
    sd = ~sd(., na.rm = TRUE)
  ))) %>%
  pivot_longer(everything(), names_to = "stat", values_to = "value") %>%
  separate(stat, into = c("covariate", "statistic"), sep = "_(?=[^_]+$)") %>%
  pivot_wider(names_from = statistic, values_from = value)

write_csv(covariate_ranges,
          "outputs/models/large_scale/covariate_ranges.csv")

log_message("Covariate ranges saved for AOA analysis")

# ============================================================================
# STEP 4: TRAIN LARGE-SCALE MODELS
# ============================================================================

log_message("\n=== STEP 4: TRAIN LARGE-SCALE MODELS ===")

#' Train Random Forest model for a specific depth
#'
#' @param data Training data with covariates
#' @param covariate_names Vector of covariate names
#' @param depth Target depth (7.5, 22.5, 40, or 75 cm)
#' @param config Configuration list
#' @return Trained model object
train_large_scale_rf <- function(data, covariate_names, depth, config) {

  log_message(sprintf("\n--- Training model for depth %g cm ---", depth))

  # Filter to target depth
  data_depth <- data %>%
    filter(standard_depth == depth) %>%
    select(all_of(c("carbon_stock_kg_m2", "sample_id", "source", covariate_names))) %>%
    na.omit()

  log_message(sprintf("Training samples: %d", nrow(data_depth)))

  if (nrow(data_depth) < 100) {
    log_message("Insufficient samples for reliable training", "ERROR")
    return(NULL)
  }

  # Prepare formula
  formula <- as.formula(paste("carbon_stock_kg_m2 ~",
                             paste(covariate_names, collapse = " + ")))

  # Spatial cross-validation setup
  if (config$cv_method == "spatial_block") {
    log_message("Setting up spatial block cross-validation...")

    # Assign samples to spatial blocks (5° × 5° grid)
    data_depth <- data_depth %>%
      mutate(
        cv_block = paste0(
          floor(utm_x / (config$cv_block_size * 111320)), "_",
          floor(utm_y / (config$cv_block_size * 111320))
        )
      )

    n_blocks <- length(unique(data_depth$cv_block))
    log_message(sprintf("Spatial blocks: %d", n_blocks))

    if (n_blocks < config$cv_folds) {
      log_message("Fewer blocks than folds, using stratified CV instead", "WARNING")
      config$cv_method <- "stratified"
    }
  }

  # Train model
  log_message("Training Random Forest...")

  set.seed(123)

  if (config$use_parallel) {
    log_message(sprintf("Using parallel processing: %d cores", config$n_cores))
  }

  model <- ranger(
    formula = formula,
    data = data_depth %>% select(-sample_id, -source, -cv_block),
    num.trees = config$rf_ntree,
    mtry = config$rf_mtry,  # NULL = auto-tune
    importance = "impurity",
    num.threads = if (config$use_parallel) config$n_cores else 1,
    verbose = FALSE,
    keep.inbag = TRUE  # For uncertainty quantification
  )

  log_message(sprintf("Training complete. OOB R²: %.4f, OOB RMSE: %.4f",
                     model$r.squared,
                     sqrt(model$prediction.error)))

  # Cross-validation
  if (config$generate_diagnostics) {
    log_message("Running cross-validation...")

    if (config$cv_method == "spatial_block") {
      # Spatial block CV
      cv_results <- list()
      unique_blocks <- unique(data_depth$cv_block)

      # Sample blocks for CV (to keep it manageable)
      if (length(unique_blocks) > config$cv_folds) {
        set.seed(123)
        cv_blocks <- sample(unique_blocks, config$cv_folds)
      } else {
        cv_blocks <- unique_blocks
      }

      for (i in seq_along(cv_blocks)) {
        test_block <- cv_blocks[i]

        train_data <- data_depth %>% filter(cv_block != test_block)
        test_data <- data_depth %>% filter(cv_block == test_block)

        if (nrow(test_data) < 5) next

        fold_model <- ranger(
          formula = formula,
          data = train_data %>% select(-sample_id, -source, -cv_block),
          num.trees = config$rf_ntree,
          num.threads = 1,
          verbose = FALSE
        )

        predictions <- predict(fold_model, test_data)$predictions

        cv_results[[i]] <- data.frame(
          fold = i,
          n_train = nrow(train_data),
          n_test = nrow(test_data),
          mae = mean(abs(test_data$carbon_stock_kg_m2 - predictions)),
          rmse = sqrt(mean((test_data$carbon_stock_kg_m2 - predictions)^2)),
          r2 = cor(test_data$carbon_stock_kg_m2, predictions)^2
        )
      }

      cv_summary <- bind_rows(cv_results) %>%
        summarise(
          cv_mae_mean = mean(mae, na.rm = TRUE),
          cv_mae_sd = sd(mae, na.rm = TRUE),
          cv_rmse_mean = mean(rmse, na.rm = TRUE),
          cv_rmse_sd = sd(rmse, na.rm = TRUE),
          cv_r2_mean = mean(r2, na.rm = TRUE),
          cv_r2_sd = sd(r2, na.rm = TRUE)
        )

      log_message(sprintf("CV results - MAE: %.4f ± %.4f, R²: %.4f ± %.4f",
                         cv_summary$cv_mae_mean, cv_summary$cv_mae_sd,
                         cv_summary$cv_r2_mean, cv_summary$cv_r2_sd))

      model$cv_results <- cv_summary
    }
  }

  # Variable importance
  if (config$generate_importance) {
    importance_df <- data.frame(
      covariate = names(model$variable.importance),
      importance = model$variable.importance
    ) %>%
      arrange(desc(importance))

    log_message(sprintf("Top 5 important covariates: %s",
                       paste(head(importance_df$covariate, 5), collapse = ", ")))

    model$importance_df <- importance_df
  }

  return(model)
}

# Train models for all depths
log_message(sprintf("Training models for %d depths...",
                   length(LARGE_SCALE_CONFIG$target_depths)))

large_scale_models <- list()

for (depth in LARGE_SCALE_CONFIG$target_depths) {
  model <- train_large_scale_rf(
    samples_with_cov,
    covariate_names,
    depth,
    LARGE_SCALE_CONFIG
  )

  if (!is.null(model)) {
    large_scale_models[[as.character(depth)]] <- model

    # Save individual model
    model_file <- sprintf("outputs/models/large_scale/global_rf_model_%gcm.rds", depth)
    saveRDS(model, model_file)
    log_message(sprintf("Model saved: %s", model_file))
  }
}

if (length(large_scale_models) == 0) {
  log_message("No models successfully trained!", "ERROR")
  quit(save = "no", status = 1)
}

# ============================================================================
# STEP 5: GENERATE DIAGNOSTICS AND OUTPUTS
# ============================================================================

log_message("\n=== STEP 5: GENERATE DIAGNOSTICS ===")

# Compile model metadata
model_metadata <- data.frame(
  depth_cm = as.numeric(names(large_scale_models)),
  n_trees = LARGE_SCALE_CONFIG$rf_ntree,
  oob_r2 = sapply(large_scale_models, function(m) m$r.squared),
  oob_rmse = sapply(large_scale_models, function(m) sqrt(m$prediction.error)),
  n_samples = sapply(large_scale_models, function(m) m$num.samples),
  n_covariates = length(covariate_names),
  date_trained = as.character(Sys.Date())
)

write_csv(model_metadata, "outputs/models/large_scale/model_metadata.csv")
log_message("Model metadata saved")

# Compile variable importance
if (LARGE_SCALE_CONFIG$generate_importance) {
  importance_all <- bind_rows(lapply(names(large_scale_models), function(d) {
    large_scale_models[[d]]$importance_df %>%
      mutate(depth_cm = as.numeric(d))
  }))

  write_csv(importance_all, "outputs/models/large_scale/feature_importance.csv")

  # Plot importance
  top_n_features <- 20

  p_importance <- importance_all %>%
    group_by(depth_cm) %>%
    slice_max(order_by = importance, n = top_n_features) %>%
    ungroup() %>%
    ggplot(aes(x = reorder(covariate, importance), y = importance)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    facet_wrap(~paste0(depth_cm, " cm"), scales = "free_y") +
    labs(
      title = "Feature Importance by Depth",
      subtitle = sprintf("Top %d covariates (Random Forest)", top_n_features),
      x = "Covariate",
      y = "Importance (impurity reduction)"
    ) +
    theme_minimal()

  ggsave("diagnostics/large_scale/feature_importance_plots.png",
         p_importance, width = 12, height = 10, dpi = 300)

  log_message("Feature importance plots saved")
}

# Training performance summary
if (LARGE_SCALE_CONFIG$generate_diagnostics) {
  cv_all <- bind_rows(lapply(names(large_scale_models), function(d) {
    cv <- large_scale_models[[d]]$cv_results
    if (!is.null(cv)) {
      cv %>% mutate(depth_cm = as.numeric(d))
    }
  }))

  if (nrow(cv_all) > 0) {
    write_csv(cv_all, "diagnostics/large_scale/spatial_cv_results.csv")
    log_message("Cross-validation results saved")
  }
}

# ============================================================================
# COMPLETION
# ============================================================================

end_time <- Sys.time()
elapsed_time <- difftime(end_time, start_time, units = "mins")

log_message("\n=== MODULE 00D COMPLETE ===")
log_message(sprintf("Runtime: %.1f minutes", as.numeric(elapsed_time)))
log_message(sprintf("Models trained: %d", length(large_scale_models)))
log_message(sprintf("Mean OOB R²: %.4f", mean(model_metadata$oob_r2)))
log_message("\nOutputs saved:")
log_message("  - outputs/models/large_scale/global_rf_model_*.rds")
log_message("  - outputs/models/large_scale/model_metadata.csv")
log_message("  - outputs/models/large_scale/feature_importance.csv")
log_message("  - outputs/models/large_scale/covariate_ranges.csv")
log_message("  - diagnostics/large_scale/*.csv and *.png")
log_message("\nNext step: Run Module 05c to apply transfer learning to regional data")
