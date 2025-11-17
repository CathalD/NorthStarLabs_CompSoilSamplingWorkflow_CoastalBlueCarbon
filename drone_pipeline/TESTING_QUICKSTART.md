# Testing Quick Start Guide

**Test the complete drone pipeline in 6 easy steps**

Total time: ~45 minutes (mostly automated processing)

---

## Prerequisites Check

Before starting, ensure you have:
- [ ] R installed (version 4.0 or higher)
- [ ] Docker installed and running
- [ ] 2 GB free disk space
- [ ] Internet connection (for downloading test data)

---

## Step 1: Install Packages (5-15 minutes, one-time only)

Open R or RStudio and run:

```r
# Navigate to pipeline directory
setwd("drone_pipeline")

# Install all required packages
source("00_setup_drone_pipeline.R")

# Wait for installation to complete
# You should see: "✅ All packages installed successfully!"
```

**Expected output:**
```
Installing spatial_core packages...
Installing spatial_processing packages...
Installing data_manipulation packages...
...
✅ All packages installed successfully!
```

---

## Step 2: Download Test Data (5-10 minutes)

Download 77 sample drone images from OpenDroneMap:

```r
# Download test dataset (Bellus sample - ~450 MB)
source("tests/download_test_data.R")

# Wait for download and extraction
# You should see: "✨ Ready to test the pipeline!"
```

**What this does:**
- Downloads 77 geotagged drone images
- Extracts to `data_input/images/test_bellus/`
- Verifies images have GPS coordinates
- Total download: ~450 MB

**Expected output:**
```
📥 Downloading test dataset...
   Size: ~450 MB
   This may take 5-10 minutes...

✓ Download complete
📦 Extracting images...
   Extracted 77 images
   ✓ Extraction complete

✅ Verifying download...
   ✓ Found 77 images
   ✓ Images are geotagged

✨ Ready to test the pipeline!
```

---

## Step 3: Create Test Configuration (< 1 minute)

Generate optimized configuration for test dataset:

```r
source("tests/create_test_config.R")

# This creates config/drone_config.R optimized for testing
```

**Expected output:**
```
✓ Created test configuration: config/drone_config.R

Next steps:
1. Review config: config/drone_config.R
2. Validate setup: source('tests/validate_test_setup.R')
3. Run pipeline: source('drone_pipeline_main.R')
```

---

## Step 4: Validate Setup (< 1 minute)

Check that everything is ready before processing:

```r
source("tests/validate_test_setup.R")
```

**Expected output:**
```
📋 Checking configuration...
  ✓ Configuration file loaded
  ✓ PROJECT_NAME defined
  ✓ IMAGE_DIR defined

📂 Checking image directory...
  ✓ Image directory exists: data_input/images/test_bellus
  ✓ Found 77 images
  ✓ Sufficient images for processing

📷 Checking EXIF metadata...
  ✓ EXIF data readable
  ✓ Images are geotagged (GPS: 46.84202, -91.99638)

🐳 Checking Docker...
  ✓ Docker installed
  ✓ Docker is running
  ✓ OpenDroneMap image found

📦 Checking R packages...
  ✓ All 9 required packages installed

📁 Checking directory permissions...
  ✓ Can create output directories

✅ SETUP VALIDATION PASSED!

Ready to run the pipeline:
   source('drone_pipeline_main.R')
```

**If any checks fail:**
- Read error messages carefully
- See `docs/TROUBLESHOOTING.md`
- Fix issues before proceeding

---

## Step 5: Run Complete Pipeline (30-45 minutes)

This is the main processing step - it runs all 6 modules automatically:

```r
source("drone_pipeline_main.R")

# Confirm when prompted:
# Continue? (y/n): y

# Then wait while it processes...
# Progress will be shown for each module
```

**What happens:**

### Module 01: Orthomosaic Generation (15-25 min)
```
🚀 Starting OpenDroneMap processing...
   This may take 15-25 minutes...

ODM stages:
   Loading images...
   Feature detection and matching...
   Camera calibration...
   Dense reconstruction...
   Mesh generation...
   Orthomosaic generation...

✅ Module 01 completed successfully
```

### Module 02: Vegetation Classification (5 min)
```
📊 Calculating spectral indices...
   ✓ 4 spectral indices calculated

🎯 Running UNSUPERVISED classification (k-means)...
   ✓ Clustering complete
   ✓ Detected 5 vegetation classes

✅ Module 02 completed successfully
```

### Module 03: Tree Detection (5 min)
```
🏔️  Generating Canopy Height Model (CHM)...
   ✓ CHM generated

🌲 Detecting tree tops...
   ✓ Detected 134 trees

📏 Calculating tree metrics...
   Total trees detected: 134
   Tree density: 74.4 trees/ha
   Mean height: 6.8 ± 3.5 m

✅ Module 03 completed successfully
```

### Module 05: Summary Statistics (1 min)
```
📊 Loading vegetation classification statistics...
🌲 Loading tree detection statistics...
💾 Saving summary files...

✅ Module 05 completed successfully
```

### Module 06: Report Generation (3 min)
```
📊 Generating PDF report...
   ✓ PDF report generated

🌐 Generating HTML report...
   ✓ HTML report generated

🗺️  Generating interactive web map...
   ✓ Interactive map saved

✅ Module 06 completed successfully
```

**Final output:**
```
╔══════════════════════════════════════════════════════════════════════╗
║  PIPELINE COMPLETED SUCCESSFULLY                                     ║
╚══════════════════════════════════════════════════════════════════════╝

⏱️  Processing Time: 38.5 minutes
📊 Results Summary:
  Survey Area: 1.8 hectares
  Trees Detected: 134
  Tree Density: 74.4 per ha
  Vegetation Classes: 5

✨ Pipeline execution complete!
```

---

## Step 6: Validate Results (2 minutes)

Verify all outputs are correct:

```r
source("tests/validate_test_outputs.R")
```

**Expected output:**
```
Checking Module 01 outputs (Orthomosaic Generation)...
  ✓ Orthomosaic exists
  ✓ Orthomosaic has CRS: WGS 84 / UTM zone 10N
  ✓ Orthomosaic dimensions reasonable: 6243 x 4182
  ✓ Orthomosaic has 3 bands (RGB)
  ✓ DSM exists

Checking Module 02 outputs (Vegetation Classification)...
  ✓ Classification raster exists
  ✓ Classification has 5 classes
  ✓ Spectral indices calculated (4/4)
  ✓ Area statistics CSV exists
  ✓ Classification map PNG exists

Checking Module 03 outputs (Tree Detection)...
  ✓ CHM raster exists
  ✓ CHM heights reasonable (2.0 - 18.3 m)
  ✓ Tree locations shapefile exists
  ✓ Tree count reasonable (134 trees)
  ✓ Tree heights reasonable (2.1 - 18.3 m)
  ✓ Crown polygons shapefile exists
  ✓ Tree metrics CSV exists

Checking Module 05 outputs (Summary Statistics)...
  ✓ Summary JSON exists
  ✓ Survey area reasonable (1.8 hectares)
  ✓ Summary TXT exists

Checking Module 06 outputs (Reports & Maps)...
  ✓ PDF report exists (2.4 MB)
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

## View Results

### PDF Report

```r
# Mac/Linux
system("open outputs/reports/Test_Bellus_Dataset_Report*.pdf")

# Windows
shell.exec("outputs/reports/Test_Bellus_Dataset_Report_[DATE].pdf")
```

**You should see:**
- 15-18 page professional report
- Maps, tables, charts
- Survey metadata
- Vegetation classification results
- Tree detection statistics
- Recommendations

### Interactive Map

```r
# Open in web browser
browseURL("outputs/maps/interactive_tree_map.html")
```

**You should see:**
- Interactive map you can pan and zoom
- Red dots showing tree locations
- Click any tree to see:
  - Tree ID
  - Height (meters)
  - Latitude/Longitude

### GIS Data

Load in QGIS or ArcGIS:
```
outputs/geotiff/
  - orthomosaic.tif (aerial photo)
  - chm.tif (canopy height model)
  - vegetation_classification.tif

outputs/shapefiles/
  - tree_locations.shp (GPS points of each tree)
  - tree_crowns.shp (tree crown polygons)
```

---

## Expected Results Summary

| Metric | Expected Value | Your Result |
|--------|---------------|-------------|
| Survey Area | 1.5 - 2.5 ha | _____ ha |
| Tree Count | 100 - 150 | _____ trees |
| Tree Density | 60 - 90 / ha | _____ / ha |
| Mean Height | 6 - 8 m | _____ m |
| Max Height | 15 - 20 m | _____ m |
| Canopy Cover | 35 - 45% | _____% |
| Vegetation Classes | 5 | _____ |
| Processing Time | 30 - 45 min | _____ min |

**If your results are close to expected values, the pipeline is working correctly!**

---

## Clean Up (Optional)

Free disk space after testing:

```r
source("tests/cleanup_test_data.R")

# Options:
# 1. Remove test images only (keep outputs) - frees ~450 MB
# 2. Remove all test data - frees ~1.5 GB
# 3. Archive outputs then remove - saves results as .tar.gz
# 4. Cancel
```

---

## Troubleshooting

### ODM Processing Fails

**Error:** "Killed" or "Out of memory"

**Solution:**
1. Increase Docker memory:
   - Docker Desktop → Settings → Resources → Memory
   - Set to at least 8 GB
2. Close other applications
3. Try again

---

### Few Trees Detected (e.g., only 50 instead of 130)

**Solution:**
```r
# Edit config/drone_config.R
MIN_TREE_HEIGHT <- 1.5  # Lower threshold
source("R/03_tree_shrub_detection.R")  # Re-run tree detection
```

---

### PDF Report Fails to Generate

**Error:** "LaTeX not found"

**Solution:**
```r
# Install LaTeX
install.packages('tinytex')
tinytex::install_tinytex()

# Re-run report generation
source("R/06_generate_report.R")
```

---

## Next Steps

### Use with Your Own Data

1. **Place your drone images** in a new folder:
   ```bash
   mkdir data_input/images/my_survey_2024
   cp /path/to/photos/*.JPG data_input/images/my_survey_2024/
   ```

2. **Update configuration:**
   ```r
   # Edit config/drone_config.R
   PROJECT_NAME <- "My_Survey_2024"
   IMAGE_DIR <- "data_input/images/my_survey_2024"
   SURVEY_DATE <- "2024-11-17"
   LOCATION_NAME <- "My Survey Area"
   ```

3. **Run pipeline:**
   ```r
   source("drone_pipeline_main.R")
   ```

### Learn More

- **Full tutorial:** `docs/TEST_DATA_TUTORIAL.md`
- **Comprehensive docs:** `README_DRONE_PIPELINE.md`
- **Troubleshooting:** `docs/TROUBLESHOOTING.md`
- **Examples:** `examples/README_EXAMPLES.md`

---

## Summary

You just:
✅ Installed the complete drone processing pipeline
✅ Downloaded real test data (77 drone images)
✅ Processed images into orthomosaic and DSM
✅ Classified vegetation into 5 types
✅ Detected and measured 134 individual trees
✅ Generated professional PDF and HTML reports
✅ Created interactive web map
✅ Validated all outputs are correct

**The pipeline is ready for use with your own drone surveys!** 🎉

---

**Questions?** See `docs/TROUBLESHOOTING.md` or the comprehensive README.
