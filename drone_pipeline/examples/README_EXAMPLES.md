# Example Files and Templates

This directory contains example files to help you get started with the drone pipeline.

## Ground Control Points (GCPs)

**File:** `gcp_template.csv`

Ground Control Points improve the absolute positional accuracy of your orthomosaic. They are optional but recommended for:
- Surveys requiring high positional accuracy (<5 cm)
- Multi-temporal surveys (ensures alignment between dates)
- Integration with existing GIS databases

**How to collect GCPs:**

1. **Equipment needed:**
   - Survey-grade GPS (RTK) or high-precision GNSS receiver
   - Visible ground targets (checkerboard panels, painted markers, or natural features)

2. **GCP placement:**
   - Minimum 5 GCPs for small areas (<10 ha)
   - 10-15 GCPs for larger areas (>20 ha)
   - Distribute around perimeter and center of survey area
   - Place at known elevations if possible (avoid slopes)

3. **Workflow:**
   - Mark GCP locations on ground before drone flight
   - Ensure markers visible in drone imagery
   - Survey GCP coordinates with RTK GPS
   - Record: gcp_id, latitude, longitude, elevation

4. **Formatting:**
   - Use WGS84 coordinate system (EPSG:4326)
   - Decimal degrees for lat/long
   - Elevation in meters above sea level

5. **Use in pipeline:**
   ```r
   # In config/drone_config.R:
   GCP_FILE <- "data_input/gcp/ground_control_points.csv"
   ODM_PARAMS$use_gcp <- TRUE
   ```

**Example GCP:**
```csv
gcp_id,latitude,longitude,elevation_m
GCP_001,49.2827,-123.1207,125.34
```

---

## Training Samples for Supervised Classification

To use supervised classification, you need to provide training polygons for each vegetation class.

**How to create training samples:**

### Method 1: Field Collection with GPS

1. **In the field:**
   - Walk to representative areas of each vegetation type
   - Record GPS coordinates or collect polygon boundaries
   - Take photos and notes

2. **Create shapefile:**
   ```r
   library(sf)

   # Example: Create training polygons
   forest_pts <- data.frame(
     lon = c(-123.120, -123.121, -123.121, -123.120),
     lat = c(49.282, 49.282, 49.283, 49.283),
     class = "Forest"
   )

   forest_poly <- st_as_sf(forest_pts, coords = c("lon", "lat"), crs = 4326) %>%
     st_combine() %>%
     st_cast("POLYGON")

   # Repeat for each class, then combine
   training <- st_sf(
     class = c("Forest", "Shrubland", "Herbaceous", "Bare", "Water"),
     geometry = st_sfc(forest_poly, shrub_poly, herb_poly, bare_poly, water_poly)
   )

   st_write(training, "data_input/training/training_polygons.shp")
   ```

### Method 2: Digitize from Orthomosaic in QGIS

1. **Load orthomosaic** in QGIS:
   - File → Add Raster Layer → Select your orthomosaic

2. **Create new shapefile:**
   - Layer → Create Layer → New Shapefile Layer
   - Geometry type: Polygon
   - Add field: "class" (Text)

3. **Digitize polygons:**
   - Toggle editing (pencil icon)
   - Add Polygon Feature (click to draw boundaries)
   - Enter class name (e.g., "Forest")
   - Draw 10-20 polygons per class
   - Aim for 50-100 pixels per polygon
   - Distribute across survey area

4. **Best practices:**
   - Avoid class boundaries (don't mix classes in one polygon)
   - Include spectral variability within each class
   - Sample both sunlit and shadowed examples
   - More samples = better accuracy (aim for 50+ per class)

5. **Save and use:**
   - Save shapefile to `data_input/training/training_polygons.shp`
   - Update config:
   ```r
   CLASSIFICATION_METHOD <- "supervised"
   TRAINING_SAMPLES <- "data_input/training/training_polygons.shp"
   CLASS_NAMES <- c("Forest", "Shrubland", "Herbaceous", "Bare", "Water")
   ```

---

## Example Project Configurations

### Berry Harvesting Area Survey

```r
PROJECT_NAME <- "Berry_Area_Baseline_2024"
SURVEY_DATE <- "2024-06-20"
LOCATION_NAME <- "Traditional Berry Grounds - South Block"
SURVEY_PURPOSE <- "Baseline vegetation assessment for restoration planning"

# Focus on detecting shrubs and small trees
MIN_TREE_HEIGHT <- 1.0  # Include tall shrubs
TREE_DETECTION_METHOD <- "watershed"

# Simple unsupervised classification
CLASSIFICATION_METHOD <- "unsupervised"
N_CLASSES_UNSUPERVISED <- 4
```

### Wildlife Habitat Assessment

```r
PROJECT_NAME <- "Grizzly_Habitat_Assessment_2024"
SURVEY_DATE <- "2024-07-15"
LOCATION_NAME <- "Bear Foraging Area - Valley Bottom"
SURVEY_PURPOSE <- "Berry shrub mapping for wildlife habitat modeling"

# Supervised classification with field-validated classes
CLASSIFICATION_METHOD <- "supervised"
TRAINING_SAMPLES <- "data_input/training/habitat_classes.shp"
CLASS_NAMES <- c("Berry_Shrubs", "Forest", "Meadow", "Bare_Ground")

# Detailed tree metrics for canopy structure
MIN_TREE_HEIGHT <- 2.0
TREE_DETECTION_METHOD <- "watershed"
```

### Post-Fire Recovery Monitoring

```r
PROJECT_NAME <- "Wildfire_Recovery_Year3"
SURVEY_DATE <- "2024-08-10"
LOCATION_NAME <- "2021 Fire Perimeter - Northern Section"
SURVEY_PURPOSE <- "Vegetation recovery monitoring - 3 years post-fire"

# Enable change detection
PREVIOUS_ORTHOMOSAIC <- "../Year2_2023/outputs/geotiff/orthomosaic.tif"
ENABLE_CHANGE_DETECTION <- TRUE

# Focus on seedling detection
MIN_TREE_HEIGHT <- 0.5  # Include small seedlings
TREE_DETECTION_METHOD <- "local_maxima"
```

### Forest Inventory

```r
PROJECT_NAME <- "Forest_Inventory_Plot42_2024"
SURVEY_DATE <- "2024-09-05"
LOCATION_NAME <- "Timber Plot 42"
SURVEY_PURPOSE <- "Individual tree inventory for carbon stock estimation"

# Mature forest parameters
MIN_TREE_HEIGHT <- 5.0  # Focus on commercial trees
MAX_TREE_HEIGHT <- 40.0
TREE_DETECTION_METHOD <- "watershed"

# High resolution for accurate stem counts
ODM_PARAMS$orthophoto_resolution <- 1.5  # 1.5 cm GSD
```

---

## Test Dataset

For testing the pipeline, use a small sample dataset:

1. **Download sample images:**
   - 20-30 drone images
   - Known location with vegetation
   - Good overlap (>70%)

2. **Quick test run:**
   ```r
   # Use default config
   # Place images in data_input/images/
   source("drone_pipeline_main.R")
   ```

3. **Expected outputs:**
   - Processing time: ~15 minutes (with Docker ODM)
   - Orthomosaic: 2-5 hectares
   - Tree detection: 50-500 individuals
   - Report: 10-15 pages

---

## Recommended Reading

**Mission Planning:**
- DJI GS Pro User Manual
- Pix4D Capture Guide
- ODM Best Practices: https://docs.opendronemap.org/flying/

**Classification:**
- Campbell & Wynne (2011). Introduction to Remote Sensing. Chapter on image classification.
- Supervised vs. Unsupervised guide: https://gisgeography.com/supervised-unsupervised-classification/

**Tree Detection:**
- ForestTools Tutorial: https://github.com/andrew-plowright/ForestTools
- Li et al. (2012). A review of remote sensing methods for forest tree structure extraction.

---

## Community Resources

Share your configurations and results with others:

- Example surveys from Canadian contexts
- Lessons learned and tips
- Adaptations for specific ecosystems (boreal, coastal, prairie)
- Integration with traditional ecological knowledge

**Contact:** [Your community network or email]

---

**Need Help?**

See `docs/TROUBLESHOOTING.md` for common issues and solutions.
