# Blue Carbon MMRV Workflow - Data Structure Guide

## Overview

This directory (`data_raw/`) contains the **input data** required to run the Blue Carbon MMRV workflow. This guide explains the required data format and provides templates.

---

## Required Input Files

### 1. core_locations.csv

**Purpose:** GPS coordinates and metadata for each soil core sampling location

**Required Columns:**

| Column | Data Type | Description | Example | Required |
|--------|-----------|-------------|---------|----------|
| `core_id` | Character | Unique identifier for each core | `"CORE_001"` | ✅ Yes |
| `longitude` | Numeric | Longitude in decimal degrees (WGS84) | `-123.5234` | ✅ Yes |
| `latitude` | Numeric | Latitude in decimal degrees (WGS84) | `49.2145` | ✅ Yes |
| `stratum` | Character | Ecosystem stratum name | `"Mid Marsh"` | ✅ Yes |
| `core_type` | Character | Core collection method | `"HR"`, `"Paired Composite"` | ⚠️ Recommended |
| `scenario_type` | Character | Temporal scenario | `"PROJECT"`, `"BASELINE"` | ⚠️ Recommended |
| `monitoring_year` | Integer | Year of data collection | `2024` | ⚠️ Recommended |
| `collector` | Character | Name of field crew member | `"John Smith"` | ❌ Optional |
| `sampling_date` | Date | Date collected (YYYY-MM-DD) | `"2024-06-15"` | ❌ Optional |

**Valid Stratum Names** (customizable in `blue_carbon_config.R`):
- `"Upper Marsh"` - Infrequent flooding, salt-tolerant shrubs
- `"Mid Marsh"` - Regular inundation, mixed halophytes (highest C sequestration)
- `"Lower Marsh"` - Daily tides, dense Spartina (highest burial rates)
- `"Underwater Vegetation"` - Subtidal seagrass beds
- `"Open Water"` - Tidal channels, lagoons

**Valid Core Types:**
- `"HR"` - High-resolution (many depth increments, e.g., every 5 cm)
- `"Paired Composite"` - Composite cores paired with HR cores for validation
- `"Unpaired Composite"` - Composite cores without paired HR cores
- `"unknown"` - Core type not specified (default)

**Valid Scenario Types:**
- `"BASELINE"` - Pre-restoration or current degraded condition (t0)
- `"PROJECT"` - Post-restoration or project scenario
- `"CONTROL"` - No-intervention control site
- `"DEGRADED"` - Heavily degraded/lost ecosystem (lower bound)
- `"REFERENCE"` - Natural healthy ecosystem (upper bound target)
- Temporal: `"PROJECT_Y0"`, `"PROJECT_Y1"`, `"PROJECT_Y5"`, `"PROJECT_Y10"`, etc.

**Example:**
```csv
core_id,longitude,latitude,stratum,core_type,scenario_type,monitoring_year
CORE_001,-123.5234,49.2145,Mid Marsh,HR,PROJECT,2024
CORE_002,-123.5198,49.2167,Lower Marsh,Paired Composite,PROJECT,2024
CORE_003,-123.5301,49.2132,Upper Marsh,HR,PROJECT,2024
```

**QA/QC Checks:**
- ✅ Valid coordinate ranges: -180 to 180° (lon), -90 to 90° (lat)
- ✅ Duplicate location detection (< 1m apart flagged)
- ✅ Invalid stratum names flagged
- ✅ All cores must have unique `core_id`

---

### 2. core_samples.csv

**Purpose:** Soil organic carbon (SOC) and bulk density measurements for each depth increment

**Required Columns:**

| Column | Data Type | Description | Example | Required | Units |
|--------|-----------|-------------|---------|----------|-------|
| `core_id` | Character | Matches `core_id` in locations file | `"CORE_001"` | ✅ Yes | - |
| `depth_top_cm` | Numeric | Top of depth increment | `0`, `15`, `30` | ✅ Yes | cm |
| `depth_bottom_cm` | Numeric | Bottom of depth increment | `15`, `30`, `50` | ✅ Yes | cm |
| `soc_g_kg` | Numeric | Soil organic carbon content | `50.3` | ✅ Yes | g C / kg soil |
| `bulk_density_g_cm3` | Numeric | Bulk density | `1.2` | ⚠️ Recommended | g / cm³ |
| `sample_id` | Character | Unique sample identifier | `"CORE_001_S01"` | ❌ Optional | - |
| `lab_id` | Character | Laboratory analysis ID | `"LAB-2024-0123"` | ❌ Optional | - |
| `analytical_method` | Character | SOC measurement method | `"Loss on ignition"`, `"Dry combustion"` | ❌ Optional | - |

**Depth Increment Guidelines:**
- **High-Resolution Cores:** 5-10 cm increments preferred
- **Composite Cores:** VM0033 intervals (0-15, 15-30, 30-50, 50-100 cm) acceptable
- **Maximum depth:** 100 cm (VM0033 standard)
- **Minimum depth coverage:** Each core should sample from 0 cm to at least 50 cm

**Example:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3
CORE_001,0,15,80.5,0.85
CORE_001,15,30,65.2,1.02
CORE_001,30,50,45.8,1.18
CORE_001,50,100,32.4,1.30
CORE_002,0,15,72.3,0.91
CORE_002,15,30,58.7,1.08
CORE_002,30,50,40.2,1.22
CORE_002,50,100,28.9,1.35
```

**Data Quality Ranges (QA/QC):**
- ✅ **SOC:** 0-500 g/kg (typical range: 10-200 g/kg for coastal wetlands)
- ✅ **Bulk Density:** 0.1-3.0 g/cm³ (typical range: 0.5-1.5 g/cm³ for organic-rich soils)
- ✅ **Depths:** Must be sequential and non-overlapping per core
- ✅ **No gaps:** Depth coverage should be continuous (small gaps <5 cm acceptable)

**Missing Bulk Density Data:**
If `bulk_density_g_cm3` is missing (NA), the workflow will use **stratum-specific defaults** from `blue_carbon_config.R`:
- Upper Marsh: 0.8 g/cm³
- Mid Marsh: 1.0 g/cm³
- Lower Marsh: 1.2 g/cm³
- Underwater Vegetation: 0.6 g/cm³
- Open Water: 1.0 g/cm³

⚠️ **Important:** Measured bulk density is **strongly recommended** for VM0033 compliance. Using defaults increases uncertainty.

---

## Optional Input Files

### 3. GEE Covariates (from Google Earth Engine scripts)

**Location:** `data_raw/gee_covariates/`

**Files Generated by `BLUE CARBON COVARIATES.js`:**
- `sentinel2_ndvi.tif` - Normalized Difference Vegetation Index
- `sentinel2_ndwi.tif` - Normalized Difference Water Index
- `elevation.tif` - Digital Elevation Model
- `slope.tif` - Slope in degrees
- `twi.tif` - Topographic Wetness Index
- `distance_to_water.tif` - Distance to nearest water body

**Purpose:** Environmental covariates for Random Forest spatial predictions (Module 05)

**Resolution:** 10-30 meters (depending on source)

**Coordinate System:** Should match `PROCESSING_CRS` in config (e.g., EPSG:3005 for BC)

---

### 4. Bayesian Priors (from Google Earth Engine scripts)

**Location:** `data_prior/`

**Files Generated by `GEE_EXPORT_BAYESIAN_PRIORS.js`:**
- `carbon_stock_prior_mean_7_5cm.tif` - Prior mean carbon stock at 7.5 cm depth
- `carbon_stock_prior_se_7_5cm.tif` - Prior standard error at 7.5 cm depth
- `carbon_stock_prior_mean_22_5cm.tif` - Prior mean at 22.5 cm depth
- ... (8 files total for 4 VM0033 depths × 2 statistics)

**Data Source:** SoilGrids 250m (ISRIC) + optional regional data (Sothe et al. 2022)

**Units:** kg C / m²

**Purpose:** Bayesian posterior estimation (Module 06c, Part 4) to reduce uncertainty

**Required:** Only if `USE_BAYESIAN = TRUE` in `blue_carbon_config.R`

---

## Example Dataset

An **example dataset** is provided in `data_raw/EXAMPLE_DATASET/` for testing:
- 3 cores across 3 different strata
- VM0033-compliant depth intervals (0-15, 15-30, 30-50, 50-100 cm)
- Realistic SOC and bulk density values for BC coastal marshes

**To use the example dataset:**
```r
# Copy example files to main data_raw/ directory
file.copy("data_raw/EXAMPLE_DATASET/core_locations.csv", "data_raw/core_locations.csv")
file.copy("data_raw/EXAMPLE_DATASET/core_samples.csv", "data_raw/core_samples.csv")

# Run workflow
source("01_data_prep_bluecarbon.R")
```

---

## Data Preparation Workflow

### Step 1: Field Data Collection
1. Record GPS coordinates for each core location (WGS84, decimal degrees)
2. Assign each core to an ecosystem stratum (e.g., "Mid Marsh")
3. Collect soil cores to at least 100 cm depth (VM0033 requirement)
4. Subdivide cores into depth increments (VM0033: 0-15, 15-30, 30-50, 50-100 cm minimum)

### Step 2: Laboratory Analysis
1. Determine **bulk density** (g/cm³) for each depth increment (required for accuracy)
2. Measure **soil organic carbon** (SOC) concentration in g/kg:
   - Dry combustion (preferred, IPCC Tier 2/3)
   - Loss on ignition with Walkley-Black correction (acceptable)
   - Mid-IR spectroscopy with calibration (rapid, requires validation)

### Step 3: Data Entry
1. Create `core_locations.csv` using template
2. Create `core_samples.csv` using template
3. **QA/QC:** Check for typos, missing values, coordinate errors
4. **Validation:** Run `tests/test_workflow_validation.R` to check data structure

### Step 4: Run Workflow
```r
# 1. Install packages
source("00a_install_packages_v2.R")

# 2. Setup directories
source("00b_setup_directories.R")

# 3. Edit configuration
# Edit blue_carbon_config.R with your project details

# 4. Run data preparation
source("01_data_prep_bluecarbon.R")

# 5. Review diagnostics
# Check files in diagnostics/data_prep/ and diagnostics/qaqc/
```

---

## Troubleshooting

### Error: "Missing required columns"
**Solution:** Check CSV column names match exactly (case-sensitive):
```r
# Correct:
core_id, longitude, latitude, stratum

# Incorrect:
Core_ID, Longitude, Latitude, Stratum  # Wrong case
core_id, lon, lat, stratum  # Wrong names
```

### Error: "Invalid coordinates"
**Solution:**
- Longitude range: -180 to 180 (negative = West, positive = East)
- Latitude range: -90 to 90 (negative = South, positive = North)
- Use decimal degrees (not degrees-minutes-seconds)
- Example for BC coast: longitude ≈ -123.5, latitude ≈ 49.2

### Warning: "Invalid stratum names"
**Solution:** Check stratum names match `VALID_STRATA` in `blue_carbon_config.R`:
```r
# Edit config file to add your custom strata
VALID_STRATA <- c(
  "Your Custom Stratum 1",
  "Your Custom Stratum 2",
  ...
)
```

### Warning: "Bulk density missing - using defaults"
**Solution:** Measure bulk density in the lab for all samples. If unavailable:
1. Accept reduced accuracy and higher uncertainty
2. Update `BD_DEFAULTS` in config with site-specific literature values
3. Document in final report that defaults were used

### Error: "Cores have no location" or "Locations have no samples"
**Solution:** Ensure `core_id` values match **exactly** between:
- `core_locations.csv` (one row per core)
- `core_samples.csv` (multiple rows per core, one per depth increment)

---

## Data Format Checklist

Before running the workflow, verify:

- [ ] `core_locations.csv` exists in `data_raw/`
- [ ] `core_samples.csv` exists in `data_raw/`
- [ ] All required columns present (see tables above)
- [ ] `core_id` values match between location and samples files
- [ ] Coordinates are valid (WGS84 decimal degrees)
- [ ] Stratum names match `VALID_STRATA` in config
- [ ] SOC values in range 0-500 g/kg
- [ ] Bulk density values in range 0.1-3.0 g/cm³ (or NA)
- [ ] Depth increments are sequential and non-overlapping
- [ ] No duplicate `core_id` in locations file
- [ ] All cores sampled to at least 50 cm depth (100 cm preferred)

---

## Contact & Support

For data format questions:
1. Review this README
2. Check example dataset in `data_raw/EXAMPLE_DATASET/`
3. Run validation tests: `source("tests/test_workflow_validation.R")`
4. Review diagnostic outputs in `diagnostics/data_prep/`

For scientific methodology questions:
- Consult VM0033 methodology document (Verra 2020)
- Review workflow documentation in main README.md
- Check comprehensive review: `COMPREHENSIVE_MMRV_WORKFLOW_REVIEW.md`

---

**Last Updated:** 2025-11-17
**Version:** 1.0
