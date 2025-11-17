# Complete Test Data Tutorial

**Test the drone pipeline with real data - step-by-step walkthrough**

This tutorial uses a small public dataset to test all pipeline modules. Expected runtime: 30-45 minutes.

---

## 🎯 Objectives

By the end of this tutorial, you will have:
- ✅ Downloaded and set up test drone images
- ✅ Run the complete pipeline
- ✅ Generated an orthomosaic, classification map, and tree detection
- ✅ Created a professional PDF report
- ✅ Validated all outputs are correct

---

## 📋 Prerequisites

Before starting, ensure you have:
- [ ] R (≥ 4.0) installed
- [ ] RStudio (recommended but optional)
- [ ] Docker installed and running
- [ ] Pipeline packages installed (`source("00_setup_drone_pipeline.R")`)
- [ ] Internet connection (for downloading test data)
- [ ] ~2 GB free disk space

---

## Step 1: Download Test Dataset (5 minutes)

We'll use the OpenDroneMap "Bellus" sample dataset - a small area with 77 images.

### Option A: Automated Download (Recommended)

```r
# Run the test data download script
setwd("drone_pipeline")
source("tests/download_test_data.R")

# This will:
# - Download 77 sample drone images (~450 MB)
# - Place them in data_input/images/test_bellus/
# - Verify download integrity
# - Create test configuration
```

### Option B: Manual Download

If the automated script fails:

1. **Download images:**
   ```bash
   cd drone_pipeline/data_input/images
   mkdir test_bellus
   cd test_bellus

   # Download from ODM sample data
   wget https://github.com/OpenDroneMap/ODM/releases/download/v2.0.0/Bellus.zip
   unzip Bellus.zip
   mv Bellus/* .
   rm -rf Bellus Bellus.zip
   ```

2. **Verify download:**
   ```bash
   ls -1 | wc -l
   # Should show 77 (or 76-78, depending on extraction)
   ```

---

## Step 2: Configure for Test Dataset (3 minutes)

Create a test-specific configuration:

```r
# Open R or RStudio
setwd("drone_pipeline")

# Load the test configuration template
source("tests/create_test_config.R")

# This creates: config/drone_config_TEST.R
```

**Or manually edit** `config/drone_config.R`:

```r
# PROJECT METADATA
PROJECT_NAME <- "Test_Bellus_Dataset"
SURVEY_DATE <- "2023-08-15"
LOCATION_NAME <- "Bellus Park - Test Area"
SURVEY_PURPOSE <- "Pipeline testing and validation"
COMMUNITY_NAME <- "Test User"
SURVEYOR_NAME <- "Your Name"

# INPUT PATHS
IMAGE_DIR <- "data_input/images/test_bellus"
GCP_FILE <- NULL  # No GCPs for test dataset
TRAINING_SAMPLES <- NULL

# OUTPUT CRS
OUTPUT_CRS <- "EPSG:32610"  # UTM Zone 10N (appropriate for this dataset)

# CLASSIFICATION
CLASSIFICATION_METHOD <- "unsupervised"
N_CLASSES_UNSUPERVISED <- 5

# TREE DETECTION
MIN_TREE_HEIGHT <- 2.0  # meters
MAX_TREE_HEIGHT <- 30.0
TREE_DETECTION_METHOD <- "watershed"

# ODM SETTINGS (optimized for test dataset)
ODM_PARAMS <- list(
  feature_quality = "medium",  # Faster processing
  min_num_features = 8000,
  pc_quality = "medium",
  mesh_octree_depth = 10,     # Slightly lower for speed
  orthophoto_resolution = 3,   # 3 cm GSD
  dsm = TRUE,
  dtm = FALSE,
  use_gcp = FALSE,
  auto_boundary = TRUE,
  crop = 2
)

# REPORTS
REPORT_FORMAT <- c("PDF", "HTML")
INCLUDE_INTERACTIVE_MAP <- TRUE

# CHANGE DETECTION (disabled for initial test)
ENABLE_CHANGE_DETECTION <- FALSE
PREVIOUS_ORTHOMOSAIC <- NULL

# PERFORMANCE (adjust based on your system)
MAX_CORES <- NULL  # Use all available
MEMORY_SETTINGS$max_ram_gb <- 8
```

Save the configuration file.

---

## Step 3: Validate Setup (2 minutes)

Before running the pipeline, validate everything is configured correctly:

```r
# Load configuration
source("config/drone_config.R")

# Run validation
source("tests/validate_test_setup.R")

# Expected output:
# ✓ Configuration loaded
# ✓ Image directory exists: data_input/images/test_bellus
# ✓ Found 77 images
# ✓ Sample image has EXIF data
# ✓ Sample image is geotagged (GPS coordinates found)
# ✓ Docker is running
# ✓ All required R packages installed
# ✓ Output directories created
#
# ✅ Setup validation passed! Ready to run pipeline.
```

If any checks fail, see the **Troubleshooting** section at the end.

---

## Step 4: Run Module 01 - Orthomosaic Generation (15-25 minutes)

This is the longest step - ODM will process 77 images into an orthomosaic.

```r
# Set working directory
setwd("drone_pipeline")

# Run Module 01
source("R/01_odm_orthomosaic_generation.R")
```

**What you'll see:**

```
═══════════════════════════════════════════════════════════════════════
 MODULE 01: OPENDRONEMAP ORTHOMOSAIC GENERATION
═══════════════════════════════════════════════════════════════════════

📷 Extracting EXIF metadata from images...
   Found 77 images
   77 / 77 images have GPS coordinates

📊 Calculating image overlap and coverage...
   Estimated overlap: 72.3%
   Estimated coverage: 1.8 hectares

🔍 Performing quality checks...
   ✅ All critical checks passed

📁 Copying images to ODM project directory...
   Copied 77 images

⚙️  Generating OpenDroneMap command...
   ODM command generated

🚀 Starting OpenDroneMap processing...
   This may take 15-25 minutes...
```

**ODM processing stages you'll see:**
1. Loading images (1 min)
2. Feature detection and matching (3-5 min)
3. Camera calibration (2-3 min)
4. Georeferencing (1-2 min)
5. Dense reconstruction (5-10 min)
6. Mesh generation (2-3 min)
7. Orthomosaic generation (1-2 min)

**Expected outputs:**
```
data_processed/orthomosaics/odm_project/
├── odm_orthophoto/
│   └── odm_orthophoto.tif          ← Main orthomosaic
├── odm_dem/
│   └── dsm.tif                     ← Digital Surface Model
└── odm_georeferencing/
    └── odm_georeferenced_model.laz ← Point cloud
```

**Validation:**

```r
# Check orthomosaic was created
library(terra)
ortho <- rast("data_processed/orthomosaics/odm_project/odm_orthophoto/odm_orthophoto.tif")

# Should see:
print(ortho)
# class       : SpatRaster
# dimensions  : ~6000, ~4000, 3  (nrow, ncol, nlyr)
# resolution  : 0.03, 0.03  (x, y)
# extent      : [coordinates]
# coord. ref. : WGS 84 / UTM zone 10N (EPSG:32610)
# source      : odm_orthophoto.tif
# names       : odm_orthophoto_1, odm_orthophoto_2, odm_orthophoto_3

# Quick visual check
plot(ortho)
```

**Expected result:** You should see an aerial image of a park-like area with trees, grass, and paths.

---

## Step 5: Run Module 02 - Vegetation Classification (5 minutes)

Classify vegetation into distinct types using spectral analysis.

```r
source("R/02_vegetation_classification.R")
```

**What you'll see:**

```
═══════════════════════════════════════════════════════════════════════
 MODULE 02: VEGETATION CLASSIFICATION
═══════════════════════════════════════════════════════════════════════

📂 Loading orthomosaic: [path]

📊 Calculating spectral indices...
   Orthomosaic has 3 bands
   ⚠️  No NIR band detected. Using Green band as proxy for NDVI
   Calculating NDVI...
   Calculating ExG...
   Calculating VARI...
   Calculating GLI...
   ✓ 4 spectral indices calculated

🎯 Running UNSUPERVISED classification (k-means)...
   Number of classes: 5
   Preparing data...
   Running k-means clustering...
   ✓ Clustering complete

   Cluster statistics:
     cluster  size percent
   1       1  45230   22.5
   2       2  38950   19.4
   3       3  52100   25.9
   4       4  31200   15.5
   5       5  33420   16.6
```

**Expected outputs:**
```
outputs/data_processed/classifications/
├── spectral_indices/
│   ├── NDVI.tif
│   ├── ExG.tif
│   ├── VARI.tif
│   └── GLI.tif
├── vegetation_classification.tif
├── spectral_indices_plot.png
└── classification_map.png

outputs/csv/
├── classification_area_statistics.csv
└── kmeans_cluster_statistics.csv
```

**Validation:**

```r
# Load classification
class_raster <- rast("outputs/data_processed/classifications/vegetation_classification.tif")
plot(class_raster, main = "Vegetation Classification")

# Check area statistics
class_stats <- read.csv("outputs/csv/classification_area_statistics.csv")
print(class_stats)

# Expected: 5 classes with areas ranging from 0.2-0.5 hectares
```

**Interpretation:**
- Class 1: Likely bare ground/paths (low NDVI)
- Class 2: Herbaceous vegetation (medium NDVI, low texture)
- Class 3: Shrubland (medium-high NDVI)
- Class 4: Tree canopy (high NDVI, high texture)
- Class 5: Shadows/water (very low NDVI)

---

## Step 6: Run Module 03 - Tree Detection (5 minutes)

Detect individual trees and measure their characteristics.

```r
source("R/03_tree_shrub_detection.R")
```

**What you'll see:**

```
═══════════════════════════════════════════════════════════════════════
 MODULE 03: TREE/SHRUB DETECTION
═══════════════════════════════════════════════════════════════════════

🏔️  Generating Canopy Height Model (CHM)...
   Loaded DSM: [path]
   ⚠️  No DTM provided. Using DSM as CHM proxy.
   Applying height filters...
     Min height: 2.0 m
     Max height: 30.0 m
   Smoothing CHM (focal filter)...
   ✓ CHM generated

   CHM Statistics:
     Min height: 2.01 m
     Max height: 18.34 m
     Mean height: 6.82 m
     SD: 3.45 m

🌲 Detecting tree tops using local maxima method...
   Searching for local maxima...
   ✓ Detected 134 trees

🌲 Performing watershed segmentation...
   Running marker-controlled watershed...
   ✓ Delineated 134 crowns

📏 Calculating tree metrics...
   Calculating crown metrics...
   ✓ Calculated metrics for 134 trees

📊 Calculating summary statistics...

   Tree Detection Summary:
   ═══════════════════════════════════════════
   Total trees detected: 134
   Height range: 2.1 - 18.3 m
   Mean height: 6.8 ± 3.5 m
   Tree density: 74.4 trees/ha
   Canopy cover: 38.2%

   Height distribution:
   <2m    2-5m  5-10m  10-15m  15-20m  >20m
     0     42     58      28       6     0
```

**Expected outputs:**
```
outputs/data_processed/tree_detections/
├── chm.tif
├── chm_with_trees.png
└── tree_height_distribution.png

outputs/shapefiles/
├── tree_locations.shp (and .dbf, .shx, .prj)
└── tree_crowns.shp

outputs/csv/
├── tree_metrics.csv
└── tree_summary_statistics.csv
```

**Validation:**

```r
# Load tree locations
library(sf)
trees <- st_read("outputs/shapefiles/tree_locations.shp")

# Check tree count
nrow(trees)
# Expected: 130-140 trees

# View tree metrics
head(trees)
# Should show: tree_id, height, crown_area_m2, crown_diameter_m, latitude, longitude

# Summary statistics
summary(trees$height)
# Expected range: 2-18 meters, mean ~6-7 meters

# Plot CHM with tree locations
chm <- rast("outputs/data_processed/tree_detections/chm.tif")
plot(chm, main = "CHM with Tree Locations")
points(vect(trees), col = "red", pch = 20, cex = 0.5)
```

**Expected result:** You should see trees concentrated in forested areas, with heights ranging from small shrubs (2m) to tall trees (18m).

---

## Step 7: Run Module 05 - Summary Statistics (1 minute)

Aggregate all results into summary tables.

```r
source("R/05_summary_statistics.R")
```

**What you'll see:**

```
═══════════════════════════════════════════════════════════════════════
 MODULE 05: SUMMARY STATISTICS
═══════════════════════════════════════════════════════════════════════

📋 Compiling survey metadata...
📏 Calculating survey area...
   Survey area: 1.8 hectares

📊 Loading vegetation classification statistics...
   Vegetation cover by class:
     value  area_ha  percent_of_total
   1     1     0.41              22.5
   2     2     0.35              19.4
   3     3     0.47              25.9
   4     4     0.28              15.5
   5     5     0.30              16.6

🌲 Loading tree detection statistics...
   Total trees: 134
   Tree density: 74.4 trees/ha
   Mean height: 6.8 m
   Canopy cover: 38.2%
```

**Expected outputs:**
```
outputs/reports/
├── survey_summary.json
└── survey_summary.txt
```

**Validation:**

```r
# View text summary
cat(readLines("outputs/reports/survey_summary.txt"), sep = "\n")

# Or load JSON
library(jsonlite)
summary_data <- fromJSON("outputs/reports/survey_summary.json")
str(summary_data)
```

---

## Step 8: Run Module 06 - Report Generation (3 minutes)

Generate professional PDF and HTML reports.

```r
# First, ensure LaTeX is installed for PDF generation
# If not already installed:
# install.packages('tinytex')
# tinytex::install_tinytex()

# Generate reports
source("R/06_generate_report.R")
```

**What you'll see:**

```
═══════════════════════════════════════════════════════════════════════
 MODULE 06: AUTOMATED REPORT GENERATION
═══════════════════════════════════════════════════════════════════════

📄 Using template: templates/drone_survey_report.Rmd

📊 Generating PDF report...
   ✓ PDF report generated: outputs/reports/Test_Bellus_Dataset_Report_2024-XX-XX.pdf

🌐 Generating HTML report...
   ✓ HTML report generated: outputs/reports/Test_Bellus_Dataset_Report_2024-XX-XX.html

🗺️  Generating interactive web map...
   ✓ Interactive map saved: outputs/maps/interactive_tree_map.html
```

**Expected outputs:**
```
outputs/reports/
├── Test_Bellus_Dataset_Report_[DATE].pdf
├── Test_Bellus_Dataset_Report_[DATE].html
└── survey_summary.json

outputs/maps/
└── interactive_tree_map.html
```

**Validation:**

Open the reports:

```r
# Open PDF (Mac/Linux)
system("open outputs/reports/Test_Bellus_Dataset_Report*.pdf")

# Open HTML
browseURL("outputs/reports/Test_Bellus_Dataset_Report_[DATE].html")

# Open interactive map
browseURL("outputs/maps/interactive_tree_map.html")
```

**Expected PDF report contents:**
- Title page
- Executive Summary (1 page)
- Survey Information (1 page)
- Methods (2-3 pages)
- Results (5-6 pages):
  - Vegetation classification table and map
  - Tree detection statistics and plots
  - Height distribution histogram
  - CHM map with tree locations
- Discussion (1-2 pages)
- Recommendations (1 page)
- Appendices (2 pages)

**Total: ~15-18 pages**

---

## Step 9: Test Interactive Features (5 minutes)

### Interactive Web Map

1. **Open** `outputs/maps/interactive_tree_map.html` in web browser
2. **Pan and zoom** around the map
3. **Click on red dots** (trees) to see pop-up with:
   - Tree ID
   - Height (meters)
   - Latitude/Longitude
4. **Zoom in** to individual tree crowns
5. **Switch base layers** (if multiple available)

**Expected:** Should see 134 clickable tree points on an interactive map.

### HTML Report

1. **Open** HTML report in web browser
2. **Test table of contents** - clicking should jump to sections
3. **Hover over plots** - should show interactive tooltips (if plotly enabled)
4. **Verify all images load** - maps, charts, photos

---

## Step 10: Validate All Outputs (5 minutes)

Run the comprehensive validation script:

```r
source("tests/validate_test_outputs.R")
```

**Expected output:**

```
╔══════════════════════════════════════════════════════════════════════╗
║  PIPELINE OUTPUT VALIDATION                                          ║
╚══════════════════════════════════════════════════════════════════════╝

Checking Module 01 outputs...
  ✓ Orthomosaic exists
  ✓ Orthomosaic has correct CRS (EPSG:32610)
  ✓ Orthomosaic dimensions reasonable (4000-8000 pixels)
  ✓ DSM exists
  ✓ Point cloud exists (optional)

Checking Module 02 outputs...
  ✓ Classification raster exists
  ✓ Classification has 5 classes
  ✓ Spectral indices calculated (4 files)
  ✓ Area statistics CSV exists
  ✓ Classification map PNG exists

Checking Module 03 outputs...
  ✓ CHM raster exists
  ✓ Tree locations shapefile exists
  ✓ Tree count reasonable (100-150 trees)
  ✓ Tree heights within expected range (2-20m)
  ✓ Crown polygons shapefile exists
  ✓ Tree metrics CSV exists

Checking Module 05 outputs...
  ✓ Summary JSON exists
  ✓ Summary TXT exists
  ✓ Survey area reasonable (1.5-2.5 ha)

Checking Module 06 outputs...
  ✓ PDF report exists
  ✓ HTML report exists
  ✓ Interactive map exists

═══════════════════════════════════════════════════════════════════════
VALIDATION SUMMARY
═══════════════════════════════════════════════════════════════════════
  Total checks: 25
  Passed: 25
  Failed: 0
  Warnings: 0

✅ ALL VALIDATIONS PASSED!

Your pipeline is working correctly. You can now use it with your own data.
```

---

## 🎉 Success! What You Accomplished

You have successfully:
- ✅ Processed 77 drone images into a georeferenced orthomosaic
- ✅ Generated a Digital Surface Model and Canopy Height Model
- ✅ Classified vegetation into 5 types covering 1.8 hectares
- ✅ Detected and measured 134 individual trees
- ✅ Calculated comprehensive summary statistics
- ✅ Generated a professional 15+ page PDF report
- ✅ Created an interactive web map
- ✅ Validated all outputs are correct

**Processing Time Breakdown:**
- Module 01 (ODM): 15-25 minutes
- Module 02 (Classification): 5 minutes
- Module 03 (Tree Detection): 5 minutes
- Module 05 (Statistics): 1 minute
- Module 06 (Reports): 3 minutes
- **Total: ~30-40 minutes**

---

## 🔄 Next Steps: Test Advanced Features

### Test Change Detection (Module 04)

To test change detection, you need two surveys. Options:

1. **Simulate change** by modifying the current orthomosaic
2. **Download another ODM sample** dataset and use as "previous survey"

Quick simulation test:

```r
# Copy current orthomosaic as "previous"
file.copy(
  "outputs/data_processed/orthomosaics/odm_project/odm_orthophoto/odm_orthophoto.tif",
  "data_input/previous_surveys/previous_orthomosaic.tif"
)

# Enable change detection in config
ENABLE_CHANGE_DETECTION <- TRUE
PREVIOUS_ORTHOMOSAIC <- "data_input/previous_surveys/previous_orthomosaic.tif"

# Run change detection
source("R/04_change_detection.R")

# NOTE: This will show minimal change since it's the same survey
# For a real test, use a different time period
```

### Test Supervised Classification

Create simple training samples:

```r
library(sf)
library(terra)

# Load classification to identify coordinates
ortho <- rast("data_processed/orthomosaics/odm_project/odm_orthophoto/odm_orthophoto.tif")
plot(ortho)

# Click on map to get coordinates for different vegetation types
# Then create training polygons (example coordinates - adjust based on your map):

training_data <- data.frame(
  class = c("Tree_Canopy", "Grass", "Bare_Ground", "Tree_Canopy", "Grass"),
  xmin = c(557100, 557200, 557300, 557150, 557250),
  xmax = c(557120, 557220, 557320, 557170, 557270),
  ymin = c(5160100, 5160200, 5160300, 5160150, 5160250),
  ymax = c(5160120, 5160220, 5160320, 5160170, 5160270)
)

# Create polygons (simplified example - in practice, digitize in QGIS)
# ... save as shapefile

# Then run supervised classification
CLASSIFICATION_METHOD <- "supervised"
TRAINING_SAMPLES <- "data_input/training/training_polygons.shp"
source("R/02_vegetation_classification.R")
```

---

## 🧪 Test with Your Own Data

Now that you've validated the pipeline works, try with your own drone survey:

1. **Collect drone images:**
   - Ensure GPS is enabled
   - 70%+ front overlap, 60%+ side overlap
   - Consistent altitude
   - Good lighting conditions

2. **Place in new folder:**
   ```bash
   mkdir data_input/images/my_survey_2024
   cp /path/to/your/photos/*.JPG data_input/images/my_survey_2024/
   ```

3. **Update configuration:**
   ```r
   # Edit config/drone_config.R
   PROJECT_NAME <- "My_Survey_2024"
   IMAGE_DIR <- "data_input/images/my_survey_2024"
   # ... update other settings
   ```

4. **Run pipeline:**
   ```r
   source("drone_pipeline_main.R")
   ```

---

## 🐛 Troubleshooting

### ODM Processing Fails

**Error:** "Killed" or "Out of memory"

**Solution:**
```r
# Reduce processing demands
ODM_PARAMS$pc_quality <- "low"
ODM_PARAMS$orthophoto_resolution <- 5
ODM_PARAMS$mesh_octree_depth <- 9

# Increase Docker memory (Docker Desktop → Settings → Resources)
```

### Few Trees Detected

**Issue:** Expected more trees but only got 50

**Solution:**
```r
# Lower height threshold
MIN_TREE_HEIGHT <- 1.5  # instead of 2.0

# Try different detection method
TREE_DETECTION_METHOD <- "local_maxima"  # instead of "watershed"

# Check CHM visually
chm <- rast("outputs/data_processed/tree_detections/chm.tif")
plot(chm)
# Should show clear height variation where trees are
```

### Classification Seems Wrong

**Issue:** All pixels classified as one or two classes

**Solution:**
```r
# Reduce number of classes
N_CLASSES_UNSUPERVISED <- 3

# Check spectral indices
ndvi <- rast("outputs/data_processed/classifications/spectral_indices/NDVI.tif")
plot(ndvi)
summary(values(ndvi))
# Should show range of values (e.g., -0.2 to 0.8)
```

### PDF Report Fails to Generate

**Error:** "LaTeX not found"

**Solution:**
```r
install.packages('tinytex')
tinytex::install_tinytex()

# Or generate HTML only
REPORT_FORMAT <- "HTML"
```

---

## 📊 Expected Results Summary

| Metric | Expected Value | What It Means |
|--------|---------------|---------------|
| **Survey Area** | 1.5 - 2.5 ha | Small park/greenspace |
| **Tree Count** | 100 - 150 | Scattered trees, not dense forest |
| **Tree Density** | 60 - 90 trees/ha | Park-like spacing |
| **Mean Tree Height** | 6 - 8 m | Mix of young and mature trees |
| **Max Tree Height** | 15 - 20 m | Some tall mature specimens |
| **Canopy Cover** | 35 - 45% | Moderate tree cover |
| **Vegetation Classes** | 5 distinct | Trees, shrubs, grass, bare, shadow |
| **Processing Time** | 30 - 45 min | Depends on computer speed |

---

## 💾 Cleaning Up After Testing

When you're done testing and want to clean up:

```bash
# Remove test data (keep pipeline code)
cd drone_pipeline

# Remove test images
rm -rf data_input/images/test_bellus

# Remove processed outputs
rm -rf data_processed/
rm -rf outputs/

# Or use the cleanup script
source("tests/cleanup_test_data.R")
```

To keep test results for reference:
```bash
# Archive test outputs
tar -czf test_results_$(date +%Y%m%d).tar.gz outputs/ data_processed/
```

---

## 📚 Additional Resources

**OpenDroneMap Documentation:**
- https://docs.opendronemap.org/
- Sample datasets: https://github.com/OpenDroneMap/ODM#sample-datasets

**ForestTools Examples:**
- https://github.com/andrew-plowright/ForestTools

**Mission Planning:**
- DJI GS Pro (iOS): For planning drone flights with proper overlap
- Pix4D Capture (iOS/Android): Alternative mission planner

**GIS Software for Viewing Outputs:**
- QGIS (free): https://qgis.org/
- Load GeoTIFFs and shapefiles for detailed analysis

---

## ✅ Checklist: Tutorial Complete

- [ ] Test data downloaded (77 images)
- [ ] Configuration updated for test dataset
- [ ] Module 01 completed - Orthomosaic generated
- [ ] Module 02 completed - Vegetation classified
- [ ] Module 03 completed - Trees detected
- [ ] Module 05 completed - Statistics calculated
- [ ] Module 06 completed - Reports generated
- [ ] PDF report opens and looks professional
- [ ] HTML report displays correctly
- [ ] Interactive map shows clickable tree points
- [ ] All validation checks passed
- [ ] Ready to use pipeline with own data

---

**Congratulations!** 🎉

You've successfully run the complete drone processing pipeline and validated all outputs. The pipeline is now ready for use with your own surveys.

**Questions?** See `docs/TROUBLESHOOTING.md` or open an issue on GitHub.
