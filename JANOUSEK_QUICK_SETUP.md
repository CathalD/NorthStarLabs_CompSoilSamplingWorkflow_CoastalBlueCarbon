# Janousek Dataset - Quick Setup Guide

## ✅ Updated for Two-File Structure

Module 00D-BC now correctly handles the Janousek dataset's two-file structure.

---

## 📁 Dataset Files Required

You need **TWO files** from the Janousek dataset:

### 1. `Janousek_Core_Locations.csv`
**Contains:** Core-level metadata (1,284 cores)

| Column | Description |
|--------|-------------|
| sample_id | Unique core ID |
| latitude | WGS84 latitude |
| longitude | WGS84 longitude |
| ecosystem | Marsh, seagrass, mangrove, etc. |
| ecoregion | Regional classification |
| core_depth | Total core depth (cm) |

### 2. `Janousek_Samples.csv`
**Contains:** Sample-level measurements (multiple per core)

| Column | Description |
|--------|-------------|
| sample_id | Links to Core_Locations |
| SubSampleID | Unique subsample ID |
| depth_min | Top of layer (cm) |
| depth_max | Bottom of layer (cm) |
| bulk_density | g/cm³ |
| soc_percent | SOC in % |
| carbon_density_gpercm3 | Carbon density g/cm³ |

---

## 🚀 Setup Steps

### Step 1: Place Both Files in Repository Root

```bash
# Both files must be in the same directory as README.md
cp Janousek_Core_Locations.csv /path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon/
cp Janousek_Samples.csv /path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon/

# Verify both files present
cd /path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon/
ls Janousek_*.csv

# Should show:
# Janousek_Core_Locations.csv
# Janousek_Samples.csv
```

### Step 2: Run Module 00D-BC (First Time)

```r
# Open R in repository directory
setwd("/path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon/")

# Run module
source("00d_bluecarbon_large_scale_training.R")
```

**What happens:**
1. ✅ Loads both CSV files
2. ✅ Joins them on `sample_id`
3. ✅ Shows you the structure of both files
4. ✅ Converts `soc_percent` (%) to g/kg
5. ✅ Validates against `carbon_density_gpercm3`
6. ✅ Creates harmonized dataset
7. ✅ Generates GEE covariate extraction script
8. ⏸️ Pauses - asks you to extract covariates in GEE

**Expected output:**
```
=== MODULE 00D-BC: BLUE CARBON LARGE-SCALE MODEL TRAINING ===
Dataset: Janousek et al. 2025 - Pacific coast blue carbon cores

=== STEP 1: LOAD JANOUSEK ET AL. 2025 DATASET ===
Loading Janousek dataset (2-file structure)...
Loading core locations: Janousek_Core_Locations.csv
Core locations loaded: 1284 cores, 6 columns
Core location columns: sample_id, latitude, longitude, ecosystem, ecoregion, core_depth

Loading samples: Janousek_Samples.csv
Samples loaded: XXXX samples, 7 columns
Sample columns: sample_id, SubSampleID, depth_min, depth_max, bulk_density, soc_percent, carbon_density_gpercm3

=== CORE LOCATIONS STRUCTURE ===
[Shows first few cores]

=== SAMPLES STRUCTURE ===
[Shows first few samples]

Joining core locations with samples on 'sample_id'...
Combined dataset: XXXX rows (samples)

=== STEP 2: HARMONIZE DATA TO VM0033 STANDARD ===
Harmonizing Janousek dataset to VM0033 standard depths...
All required columns found
Validation: Mean difference with Janousek carbon_density: 0.000XXX g/cm³
Validation PASSED: Carbon calculation matches Janousek data ✓
Harmonized data: XXXX samples

Samples by ecosystem and depth:
[Shows distribution]

Harmonized data saved to: data_global/janousek_harmonized_bluecarbon.csv

=== STEP 3: EXTRACT ENVIRONMENTAL COVARIATES ===
GEE script template created: GEE_EXTRACT_JANOUSEK_COVARIATES.js

⚠️  COVARIATES NOT YET EXTRACTED ⚠️

Next steps:
1. Upload data_global/janousek_harmonized_bluecarbon.csv to GEE as asset
2. Run GEE_EXTRACT_JANOUSEK_COVARIATES.js in Google Earth Engine
3. Download result to data_global/janousek_cores_with_covariates.csv
4. Re-run this module (00d_bluecarbon_large_scale_training.R)
```

### Step 3: Extract Covariates in GEE

```javascript
// In Google Earth Engine Code Editor:

// 1. Upload data_global/janousek_harmonized_bluecarbon.csv as asset
//    Assets → NEW → CSV file → Upload

// 2. Open GEE_EXTRACT_JANOUSEK_COVARIATES.js (auto-generated)

// 3. Update line 8 with your username:
var cores = ee.FeatureCollection('users/YOUR_USERNAME/janousek_cores');
//                                      ^^^^^^^^^^^^^ CHANGE THIS

// 4. Run script (click Run button)

// 5. Tasks tab → Export: janousek_cores_with_covariates
//    → RUN → Export to Drive

// 6. Wait for export to complete (5-15 minutes)

// 7. Download from Google Drive to:
//    data_global/janousek_cores_with_covariates.csv
```

### Step 4: Run Module 00D-BC (Second Time)

```r
# After covariates extracted
source("00d_bluecarbon_large_scale_training.R")
```

**What happens:**
1. ✅ Loads cores + covariates
2. ✅ Trains Random Forest models (all depths)
3. ✅ Generates feature importance
4. ✅ Creates ecosystem-specific performance
5. ✅ Saves pre-trained models

**Runtime:** 30-60 minutes

**Expected output:**
```
=== STEP 4: TRAIN BLUE CARBON MODELS ===

--- Training model for depth 7.5 cm ---
Training samples: XXXX
Samples by ecosystem:
  Emergent marsh: XXX
  Seagrass: XXX
  Mangrove: XXX
  ...
Training Random Forest...
Training complete. OOB R²: 0.XXXX, OOB RMSE: X.XXXX kg/m²
Top 10 important variables: NDVI, z_star, MAT, NDWI, ...
Model saved: outputs/models/large_scale_bluecarbon/global_bc_rf_model_7.5cm.rds

[Repeats for depths 22.5, 40, 75 cm]

=== STEP 5: GENERATE DIAGNOSTICS ===
Model metadata saved
Feature importance plots saved
Ecosystem comparison plots saved

=== MODULE 00D-BC COMPLETE ===
Runtime: XX.X minutes
Dataset: Janousek et al. 2025 - 1284 blue carbon cores
Models trained: 4 depths
Mean OOB R²: 0.XXX

Outputs saved:
  - outputs/models/large_scale_bluecarbon/global_bc_rf_model_*.rds
  - outputs/models/large_scale_bluecarbon/model_metadata.csv
  - outputs/models/large_scale_bluecarbon/feature_importance.csv
  - outputs/models/large_scale_bluecarbon/ecosystem_performance.csv

Next step:
  Run Module 05c to apply transfer learning to your regional BC data
  (Module 05c will automatically detect and use these blue carbon models)
```

---

## ✨ What's Automatic

The module now **automatically handles**:

1. ✅ **Loading both files** - No manual merging needed
2. ✅ **Joining on sample_id** - Relational database join
3. ✅ **Unit conversion** - soc_percent (%) → g/kg
4. ✅ **Validation** - Checks against carbon_density_gpercm3
5. ✅ **VM0033 depths** - Assigns to standard depths
6. ✅ **Carbon stock calculation** - Uses correct formula
7. ✅ **Error checking** - Clear messages if problems

**You don't need to modify any code!**

---

## 🔍 Validation

The module validates your data:

```r
# Converts soc_percent to g/kg
soc_g_kg = soc_percent * 10

# Calculates carbon stock
carbon_stock_kg_m2 = (soc_g_kg × bd_g_cm3 × thickness_cm) / 1000

# Validates against Janousek's carbon_density
carbon_density_calculated = (soc_g_kg × bd_g_cm3) / 1000
difference = |carbon_density_calculated - carbon_density_gpercm3|

# Reports results
if mean(difference) < 0.01:
    "Validation PASSED ✓"
else:
    "WARNING: Large discrepancy"
```

---

## 📊 After Training

Once models trained, use with your regional data:

```r
# Standard workflow
source("01_data_prep_bluecarbon.R")
source("03_depth_harmonization_bluecarbon.R")
source("05_raster_predictions_rf_bluecarbon.R")  # Baseline

# Transfer learning (auto-detects blue carbon models)
source("05c_transfer_learning_regional_application.R")

# Compare performance
source("05d_performance_comparison.R")
browseURL("outputs/reports/transfer_learning_performance_report.html")
```

**Module 05c automatically:**
- Looks for `outputs/models/large_scale_bluecarbon/` first
- Uses blue carbon models if found
- Falls back to generic models if not found

---

## ❓ Troubleshooting

### Issue: "Core Locations file not found"

```bash
# Check file name exactly
ls -la Janousek_Core_Locations.csv

# Common issues:
# - Wrong directory (must be in repository root)
# - Typo in filename
# - File has spaces or special characters
```

### Issue: "Samples file not found"

```bash
# Check file name exactly
ls -la Janousek_Samples.csv

# Both files must be in same directory
```

### Issue: "sample_id column not found"

```r
# Check column names in your files
library(readr)
core_locs <- read_csv("Janousek_Core_Locations.csv")
names(core_locs)

samples <- read_csv("Janousek_Samples.csv")
names(samples)

# If column names different, let me know and I'll update the module
```

### Issue: "Validation WARNING: Large discrepancy"

**Possible causes:**
1. soc_percent units incorrect (maybe already g/kg, not %)
2. Bulk density units different
3. Data quality issues in original dataset

**Solution:**
```r
# Check soc_percent range
summary(samples$soc_percent)

# If max < 100 → probably %
# If max > 100 → probably already g/kg (don't multiply by 10)
```

Let me know the summary output and I'll adjust the conversion.

---

## 📞 Questions?

If you encounter any issues:

1. Check both files are present: `ls Janousek_*.csv`
2. Check column names match expected structure
3. Review log file: `logs/large_scale_bluecarbon_YYYY-MM-DD.log`
4. Check harmonized output: `data_global/janousek_harmonized_bluecarbon.csv`

---

**Module is now ready for the two-file Janousek dataset structure!**
