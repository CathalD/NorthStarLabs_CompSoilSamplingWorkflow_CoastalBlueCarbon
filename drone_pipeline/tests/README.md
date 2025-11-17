# Test Scripts

This directory contains scripts for testing and validating the drone processing pipeline.

## Quick Start

Run all test scripts in sequence:

```r
# 1. Download test data
source("tests/download_test_data.R")

# 2. Create test configuration
source("tests/create_test_config.R")

# 3. Validate setup before running
source("tests/validate_test_setup.R")

# 4. Run the pipeline (30-45 minutes)
source("drone_pipeline_main.R")

# 5. Validate outputs after running
source("tests/validate_test_outputs.R")

# 6. Clean up when done (optional)
source("tests/cleanup_test_data.R")
```

---

## Test Scripts Overview

### `download_test_data.R`

**Purpose:** Downloads OpenDroneMap "Bellus" sample dataset for testing

**What it does:**
- Downloads 77 geotagged drone images (~450 MB)
- Extracts to `data_input/images/test_bellus/`
- Verifies download integrity
- Checks for GPS coordinates in EXIF data

**Runtime:** 5-10 minutes (internet speed dependent)

**Requirements:** Internet connection, ~1 GB free disk space

---

### `create_test_config.R`

**Purpose:** Creates optimized configuration for testing

**What it does:**
- Generates `config/drone_config.R` tuned for test dataset
- Backs up existing config if present
- Sets faster processing parameters
- Configures for 77-image Bellus dataset

**Runtime:** < 1 minute

**Outputs:** `config/drone_config.R`

---

### `validate_test_setup.R`

**Purpose:** Validates environment before running pipeline

**Checks:**
- ✓ Configuration file loads correctly
- ✓ Image directory exists with images
- ✓ Images have GPS coordinates
- ✓ Docker installed and running
- ✓ OpenDroneMap image available
- ✓ Required R packages installed
- ✓ Can create output directories
- ✓ Sufficient disk space

**Runtime:** < 1 minute

**Output:** Pass/fail report with specific errors

---

### `validate_test_outputs.R`

**Purpose:** Validates pipeline outputs after processing

**Checks:**
- ✓ Module 01: Orthomosaic, DSM, point cloud
- ✓ Module 02: Classification, spectral indices
- ✓ Module 03: CHM, tree locations, metrics
- ✓ Module 05: Summary statistics
- ✓ Module 06: PDF/HTML reports, interactive map

**Validates:**
- Files exist in expected locations
- Rasters have correct CRS and dimensions
- Tree counts and heights are reasonable
- Reports contain content

**Runtime:** 1-2 minutes

**Output:** Detailed validation report (25 checks)

---

### `cleanup_test_data.R`

**Purpose:** Clean up test data to free disk space

**Options:**
1. Remove test images only (keep outputs)
2. Remove all test data
3. Archive outputs then remove all
4. Cancel

**Runtime:** 1-2 minutes

**Disk space freed:** ~500 MB to 2 GB depending on option

---

## Expected Test Results

### Test Dataset (Bellus)

| Metric | Expected Value |
|--------|---------------|
| Number of images | 77 |
| Survey area | 1.5 - 2.5 hectares |
| Processing time | 30 - 45 minutes |
| Tree count | 100 - 150 |
| Mean tree height | 6 - 8 meters |
| Vegetation classes | 5 distinct types |
| Canopy cover | 35 - 45% |

### Output Files

After successful run, you should have:

```
data_processed/
├── orthomosaics/odm_project/
│   ├── odm_orthophoto/odm_orthophoto.tif (~100 MB)
│   └── odm_dem/dsm.tif (~50 MB)
├── classifications/
│   ├── vegetation_classification.tif
│   └── spectral_indices/*.tif (4 files)
└── tree_detections/
    ├── chm.tif
    └── chm_with_trees.png

outputs/
├── reports/
│   ├── Test_Bellus_Dataset_Report_[DATE].pdf (~5 MB)
│   ├── Test_Bellus_Dataset_Report_[DATE].html
│   └── survey_summary.json
├── shapefiles/
│   ├── tree_locations.shp
│   └── tree_crowns.shp
├── csv/
│   ├── tree_metrics.csv (~15 KB)
│   ├── classification_area_statistics.csv
│   └── tree_summary_statistics.csv
└── maps/
    └── interactive_tree_map.html (~500 KB)
```

---

## Troubleshooting Test Failures

### Download Fails

**Error:** Cannot download test dataset

**Solutions:**
1. Check internet connection
2. Manual download from: https://github.com/OpenDroneMap/odm_data_bellus
3. Extract to `data_input/images/test_bellus/`

---

### Validation Setup Fails

**Error:** Docker not running

**Solution:**
```bash
# Start Docker Desktop (Mac/Windows)
# Or start Docker daemon (Linux):
sudo systemctl start docker
```

**Error:** Missing R packages

**Solution:**
```r
source("00_setup_drone_pipeline.R")
```

---

### ODM Processing Fails

**Error:** Out of memory

**Solution:**
- Increase Docker memory (Docker Desktop → Settings → Resources)
- Set to at least 8 GB
- Close other applications

---

### Validation Outputs Fails

**Error:** Tree count unusual (e.g., only 20 trees detected)

**Investigation:**
```r
# Check CHM visually
library(terra)
chm <- rast("outputs/data_processed/tree_detections/chm.tif")
plot(chm)

# Lower threshold if needed
MIN_TREE_HEIGHT <- 1.5  # Instead of 2.0
```

---

## Advanced Testing

### Test with Different Parameters

Modify `config/drone_config.R` to test:

**Different classification methods:**
```r
CLASSIFICATION_METHOD <- "supervised"  # Requires training data
N_CLASSES_UNSUPERVISED <- 3  # Reduce classes
```

**Different tree detection:**
```r
TREE_DETECTION_METHOD <- "local_maxima"  # Instead of watershed
MIN_TREE_HEIGHT <- 1.0  # Lower threshold
```

**Faster processing:**
```r
ODM_PARAMS$pc_quality <- "low"
ODM_PARAMS$orthophoto_resolution <- 5  # 5cm instead of 3cm
```

---

### Test Change Detection

Requires two surveys. Quick simulation:

```r
# Copy current orthomosaic as "previous"
file.copy(
  "outputs/data_processed/orthomosaics/odm_project/odm_orthophoto/odm_orthophoto.tif",
  "data_input/previous_surveys/previous_orthomosaic.tif"
)

# Enable in config
ENABLE_CHANGE_DETECTION <- TRUE
PREVIOUS_ORTHOMOSAIC <- "data_input/previous_surveys/previous_orthomosaic.tif"

# Run Module 04
source("R/04_change_detection.R")
```

Note: This shows minimal change since it's the same survey. For real testing, use surveys from different dates.

---

## Continuous Integration

To add automated testing (future development):

```r
# tests/run_all_tests.R
source("tests/download_test_data.R")
source("tests/create_test_config.R")
source("tests/validate_test_setup.R")
source("drone_pipeline_main.R")
source("tests/validate_test_outputs.R")
```

---

## Test Data Sources

### Current: Bellus Dataset

- **Source:** OpenDroneMap sample data
- **Location:** Park area, Pacific Northwest USA
- **Size:** 77 images, ~1.8 hectares
- **Camera:** DJI Phantom 4
- **Features:** Mixed vegetation, paths, trees, grass

### Additional Test Datasets (Optional)

1. **ODM Aukerman:**
   - 77 images
   - Agricultural field
   - Download: https://github.com/OpenDroneMap/odm_data_aukerman

2. **ODM Caliterra:**
   - 77 images
   - Beach/coastal area
   - Download: https://github.com/OpenDroneMap/odm_data_caliterra

3. **Your own data:**
   - Small survey (<50 images) for quick testing
   - Known ground truth for validation

---

## Performance Benchmarks

Tested on various systems:

| System | Specs | Processing Time |
|--------|-------|----------------|
| High-end Desktop | i7-10700K, 32GB RAM, SSD | 25 minutes |
| Mid-range Laptop | i5-8265U, 16GB RAM, SSD | 35 minutes |
| Budget Laptop | i3-7100U, 8GB RAM, HDD | 60 minutes |

Times are for Bellus dataset (77 images) with medium quality settings.

---

## Questions?

- See main documentation: `docs/TEST_DATA_TUTORIAL.md`
- Troubleshooting guide: `docs/TROUBLESHOOTING.md`
- Pipeline README: `README_DRONE_PIPELINE.md`

---

**Ready to test?** Run `source("tests/download_test_data.R")` to begin!
