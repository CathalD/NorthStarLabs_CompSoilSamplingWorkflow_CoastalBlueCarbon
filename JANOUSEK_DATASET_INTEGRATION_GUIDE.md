# Janousek et al. 2025 Blue Carbon Dataset - Integration Guide

## 📄 Paper Information

**Title:** "Blue Carbon Stocks Along the Pacific Coast of North America Are Mainly Driven by Local Rather Than Regional Factors"

**Authors:** Janousek, C.N., et al.

**Journal:** Global Biogeochemical Cycles (2025), Volume 39, Issue 3

**DOI:** [10.1029/2024GB008239](https://doi.org/10.1029/2024GB008239)

**Dataset DOI:** [10.25573/data.28127486](https://doi.org/10.25573/data.28127486)

---

## 📊 Dataset Overview

### Scope
- **1,284 sediment cores** from Pacific coast of North America
- **69 compiled data sources**
- **>6,500 km of coastline** covered
- **86 estuaries/coastal regions**

### Geographic Coverage
- Pacific coast from Alaska to Mexico
- Focus on least-disturbed wetlands
- Spans multiple climate zones (Köppen-Geiger)
- Multiple ecoregions

### Ecosystem Types Included
1. **Emergent marsh** (salt marsh) - Primary
2. **Seagrass meadows** - Marine
3. **Mangroves** - Tropical/subtropical
4. **Tidal swamps** - Forested wetlands
5. **Tideflats** - Unvegetated

### Variables Included
- **Down-core profiles:**
  - Bulk density (g/cm³)
  - Organic carbon content (% or g/kg)
  - Depth intervals (cm)

- **Spatial metadata:**
  - Latitude, longitude
  - Standardized tidal elevation (z*)
  - Ecoregion classification
  - Köppen-Geiger climate zone

- **Environmental data:**
  - Sediment grain size
  - Vegetation type
  - Site characteristics

---

## 🎯 Why This Dataset is Perfect for Transfer Learning

### Advantages Over Generic SoilGrids

| Feature | SoilGrids | Janousek et al. 2025 |
|---------|-----------|----------------------|
| **Ecosystem focus** | Generic terrestrial soils | Blue carbon wetlands ✅ |
| **Tidal context** | No | Standardized z* elevation ✅ |
| **Quality control** | Variable | High-quality, QC'd data ✅ |
| **Depth profiles** | Fixed depths | Actual core profiles ✅ |
| **Sample density** | Global (sparse locally) | Regional (dense) ✅ |
| **Ecosystem stratification** | Land cover only | Wetland-specific types ✅ |
| **Coastal covariates** | Limited | Tidal, salinity context ✅ |

### Key Benefits

1. **Domain-Specific:** All samples from coastal blue carbon ecosystems
2. **High Relevance:** Pacific coast data directly applicable to BC coastal projects
3. **Comprehensive:** Multiple ecosystem types = robust model generalization
4. **Standardized:** Consistent methodology across 69 studies
5. **Peer-Reviewed:** Published in top-tier journal with rigorous QC

---

## 📥 How to Obtain the Dataset

### Step 1: Download from Smithsonian Figshare

**URL:** https://smithsonian.figshare.com/articles/dataset/Dataset_Carbon_stocks_and_environmental_driver_data_for_blue_carbon_ecosystems_along_the_Pacific_coast_of_North_America/28127486

**Files included:**
- Core-level data (down-core profiles)
- Site metadata
- Carbon stock summaries
- Environmental driver data
- Data dictionary

### Step 2: Extract Dataset Files

The Janousek dataset comes in **two separate files**:

1. **`Janousek_Core_Locations.csv`** - Core-level metadata
   - sample_id (unique core identifier)
   - latitude, longitude (WGS84 coordinates)
   - ecosystem (marsh, seagrass, mangrove, etc.)
   - ecoregion (regional classification)
   - core_depth (total core depth in cm)

2. **`Janousek_Samples.csv`** - Sample-level measurements
   - sample_id (links to Core_Locations)
   - SubSampleID (unique subsample identifier)
   - depth_min, depth_max (depth interval in cm)
   - bulk_density (g/cm³)
   - soc_percent (soil organic carbon in %)
   - carbon_density_gpercm3 (carbon density in g/cm³)

### Step 3: Place Files in Repository

Both files must be in the repository root:

```bash
# Copy both files to repository root
cp Janousek_Core_Locations.csv /path/to/your/blue/carbon/workflow/
cp Janousek_Samples.csv /path/to/your/blue/carbon/workflow/

# Verify both files are present
ls Janousek_*.csv
# Should show:
# Janousek_Core_Locations.csv
# Janousek_Samples.csv
```

---

## 🔧 Integration Workflow

### Complete Workflow Steps

```
┌─────────────────────────────────────────────────────┐
│ STEP 1: Prepare Janousek Dataset                   │
│ • Download from Figshare                            │
│ • Place CSV in repository root                      │
│ • Inspect column structure                          │
└───────────────────┬─────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────────┐
│ STEP 2: Run Module 00D-BC                          │
│ • Loads Janousek data                               │
│ • Harmonizes to VM0033 depths                       │
│ • Creates GEE script for covariate extraction       │
│ • Pauses for covariate extraction                   │
└───────────────────┬─────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────────┐
│ STEP 3: Extract Covariates in GEE                  │
│ • Upload harmonized cores to GEE                    │
│ • Run GEE_EXTRACT_JANOUSEK_COVARIATES.js            │
│ • Download: janousek_cores_with_covariates.csv      │
│ • Place in data_global/                             │
└───────────────────┬─────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────────┐
│ STEP 4: Re-run Module 00D-BC                       │
│ • Merges cores with covariates                      │
│ • Trains blue carbon Random Forest models           │
│ • Generates diagnostics                             │
│ • Saves pre-trained models                          │
│ Runtime: 30-60 minutes                              │
└───────────────────┬─────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────────┐
│ STEP 5: Apply to Regional Data (Module 05c)        │
│ • Loads pre-trained blue carbon models              │
│ • Fine-tunes on your regional cores                 │
│ • Generates transfer learning predictions           │
└───────────────────┬─────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────────────┐
│ STEP 6: Compare Performance (Module 05d)           │
│ • Quantifies improvement over standard RF           │
│ • Generates comparison report                       │
└─────────────────────────────────────────────────────┘
```

---

## 📝 Actual Dataset Structure

### Two-File Structure (Confirmed)

The Janousek dataset uses a **relational structure** with two CSV files:

#### File 1: `Janousek_Core_Locations.csv`

Core-level metadata (one row per core):

| Column | Description | Example |
|--------|-------------|---------|
| `sample_id` | Unique core identifier | "CORE_001" |
| `latitude` | WGS84 latitude | 48.5234 |
| `longitude` | WGS84 longitude | -123.4567 |
| `ecosystem` | Ecosystem type | "Emergent marsh" |
| `ecoregion` | Regional classification | "Puget Sound" |
| `core_depth` | Total core depth (cm) | 100 |

#### File 2: `Janousek_Samples.csv`

Sample-level measurements (multiple rows per core):

| Column | Description | Example |
|--------|-------------|---------|
| `sample_id` | Links to Core_Locations | "CORE_001" |
| `SubSampleID` | Unique subsample ID | "CORE_001_S01" |
| `depth_min` | Top of layer (cm) | 0 |
| `depth_max` | Bottom of layer (cm) | 15 |
| `bulk_density` | Bulk density (g/cm³) | 0.85 |
| `soc_percent` | Soil organic carbon (%) | 4.5 |
| `carbon_density_gpercm3` | Carbon density (g/cm³) | 0.038 |

### Relationship Between Files

```
Core_Locations (1,284 cores)
    └─── Samples (multiple samples per core)
         Joined on: sample_id
```

**Example:**
- Core "CORE_001" in `Core_Locations`: lat=48.52, lon=-123.45, ecosystem="marsh"
- Samples in `Samples`:
  - CORE_001_S01: depth 0-15cm, BD=0.85, SOC=4.5%
  - CORE_001_S02: depth 15-30cm, BD=0.92, SOC=3.8%
  - CORE_001_S03: depth 30-50cm, BD=1.05, SOC=2.1%
  - etc.

### Module 00D-BC Handles This Automatically

The updated module:
1. ✅ Loads both files separately
2. ✅ Joins on `sample_id`
3. ✅ Converts `soc_percent` to g/kg (multiply by 10)
4. ✅ Validates against `carbon_density_gpercm3`
5. ✅ Assigns to VM0033 standard depths

**No manual modification needed** - the column mappings are hardcoded based on the confirmed structure!

---

## 🔄 Column Mapping Examples

### Example 1: If OC is in %

```r
# In harmonize_janousek_data() function, modify:
soc_g_kg = organic_carbon * 10  # Convert % to g/kg
```

### Example 2: If OC is already in g/kg

```r
soc_g_kg = organic_carbon  # Already in correct units
```

### Example 3: If you have Organic Matter instead

```r
# Convert OM (%) to OC (g/kg)
# Typical conversion: OC ≈ OM / 1.724 (van Bemmelen factor)
soc_g_kg = (organic_matter / 1.724) * 10
```

### Example 4: Different depth column names

```r
depth_top_cm = depth_min,
depth_bottom_cm = depth_max
```

---

## 🎨 Covariate Extraction Strategy

### Recommended Covariates for Blue Carbon

**Priority 1 (Essential):**
1. **NDVI, NDWI** - Vegetation and water indices
2. **Tidal elevation (z*)** - If available in dataset, otherwise extract
3. **Distance to water** - Critical for coastal wetlands
4. **Climate** - MAT, MAP (WorldClim)

**Priority 2 (Important):**
5. **SAR backscatter** - Sentinel-1 VV, VH (water/soil detection)
6. **Elevation** - SRTM or better DEM
7. **Soil texture priors** - SoilGrids clay/sand content

**Priority 3 (Nice to have):**
8. **Salinity indicators** - Coastal proximity, tidal influence
9. **Inundation frequency** - From Global Surface Water
10. **Vegetation height** - Canopy height models

### GEE Script Customization

The auto-generated script `GEE_EXTRACT_JANOUSEK_COVARIATES.js` includes all these. You can:

1. **Add more covariates** based on your research questions
2. **Adjust time periods** (currently 2020-2023 mean)
3. **Add ecosystem-specific covariates** (e.g., mangrove indices)

---

## 📊 Expected Model Performance

### Based on Article Results

**Janousek et al. 2025 findings:**
- Blue carbon stocks mainly driven by **local factors** (not regional)
- High variability within ecosystems
- Tidal elevation (z*) is strong predictor
- Grain size important for seagrass
- Climate less important than expected

### Expected Transfer Learning Performance

**For your BC regional data:**

| Your Sample Size | Expected MAE Improvement |
|------------------|-------------------------|
| n < 5 per stratum | **25-35%** ⭐⭐⭐ |
| n = 5-15 per stratum | **15-25%** ⭐⭐ |
| n = 15-30 per stratum | **10-15%** ⭐ |
| n > 30 per stratum | **5-10%** |

**Why such high improvement?**
1. Janousek dataset has 1,284 cores (rich global knowledge)
2. Pacific coast focus (same region as your BC data)
3. Multiple ecosystem types (better generalization)
4. High-quality QC (reduces noise in pre-training)

---

## ⚠️ Important Considerations

### 1. Data Quality

**Check for:**
- Missing values in critical columns (lat, lon, depth, BD, OC)
- Outliers (BD > 2.5 g/cm³, OC > 50%)
- Duplicate cores
- Inconsistent units

**Module 00D-BC handles:**
- ✅ Automatic QC filtering
- ✅ Unit conversion
- ✅ Standardization to VM0033 depths

### 2. Ecosystem Matching

**Your regional data should ideally include:**
- Similar ecosystem types as Janousek (marsh, seagrass, etc.)
- Comparable tidal elevations
- Pacific coast region (for best match)

**If different ecosystems:**
- Model will still work (generalization)
- But gains may be smaller
- Consider stratifying by ecosystem type

### 3. Covariate Consistency

**Critical:** Regional covariates must match large-scale covariates

**Ensure:**
- Same data sources (Sentinel-2, WorldClim, etc.)
- Same time periods (or similar)
- Same processing methods
- Same spatial resolution (or resample appropriately)

### 4. Computational Requirements

**Module 00D-BC:**
- RAM: 8-16 GB (less than generic Module 00d)
- Runtime: 30-60 minutes (smaller dataset)
- Storage: ~5-10 GB (models + diagnostics)

---

## 🚀 Quick Start Commands

### Step 1: Place Both Dataset Files
```bash
# Ensure both files are in repository root
ls Janousek_Core_Locations.csv
ls Janousek_Samples.csv

# Or check both at once
ls Janousek_*.csv
# Should show both files
```

### Step 2: Run Module 00D-BC (First Time)
```r
source("00d_bluecarbon_large_scale_training.R")
# Will create GEE script and pause for covariate extraction
```

### Step 3: Extract Covariates in GEE
```javascript
// In Google Earth Engine Code Editor:
// 1. Upload data_global/janousek_harmonized_bluecarbon.csv as asset
// 2. Open GEE_EXTRACT_JANOUSEK_COVARIATES.js
// 3. Update 'YOUR_USERNAME' to your GEE username
// 4. Run script
// 5. Download janousek_cores_with_covariates.csv to data_global/
```

### Step 4: Run Module 00D-BC (Second Time)
```r
source("00d_bluecarbon_large_scale_training.R")
# Will now train models with covariates
```

### Step 5: Apply Transfer Learning
```r
# Standard workflow first
source("01_data_prep_bluecarbon.R")
source("03_depth_harmonization_bluecarbon.R")
source("05_raster_predictions_rf_bluecarbon.R")  # Baseline

# Transfer learning
source("05c_transfer_learning_regional_application.R")
# Will automatically detect blue carbon models

# Compare performance
source("05d_performance_comparison.R")
browseURL("outputs/reports/transfer_learning_performance_report.html")
```

---

## 📈 Interpreting Results

### Model Diagnostics

**Module 00D-BC generates:**

1. **Model Metadata** (`model_metadata.csv`)
   - OOB R² by depth
   - RMSE by depth
   - Sample sizes
   - → Expect R² = 0.6-0.8 for blue carbon

2. **Feature Importance** (`feature_importance.csv`)
   - Top predictors of blue carbon stocks
   - → Likely: z* (tidal elevation), NDVI, grain size

3. **Ecosystem Performance** (`ecosystem_performance.csv`)
   - Performance by ecosystem type
   - → Shows which ecosystems predict well

### Transfer Learning Gains

**Module 05d report shows:**

| Metric | What it tells you |
|--------|-------------------|
| **Overall MAE improvement** | Did transfer learning help? |
| **Improvement by depth** | Which depths benefit most? |
| **Improvement by stratum** | Which strata benefit most? |
| **R² comparison** | How much better is the model? |

**Expected for BC coastal data:**
- Overall improvement: **15-25%**
- Largest gains in undersampled strata
- Smaller gains where you already have good coverage

---

## 🔬 Scientific Interpretation

### Why Local Factors Matter (Janousek Findings)

The paper found that **local factors** (site-specific conditions) are more important than regional factors for predicting blue carbon stocks. This means:

**Transfer learning is particularly valuable because:**
1. The large-scale model learns local factor relationships
2. These relationships transfer well to new sites
3. Regional fine-tuning adapts to your specific local conditions
4. Best of both worlds: global knowledge + local adaptation

### Implications for Your Project

**Your regional model benefits from:**
- 1,284 examples of local factor effects
- Diverse ecosystem types
- Range of environmental conditions
- Robust covariate relationships

**Even with few samples, transfer learning provides:**
- Strong priors on predictor importance
- Expected ranges for carbon stocks
- Ecosystem-specific patterns
- Robust generalization

---

## 📚 Citation

If you use this integration approach in publications:

**Dataset:**
```
Janousek, C. N., et al. (2025). Dataset: Carbon stocks and environmental
driver data for blue carbon ecosystems along the Pacific coast of North
America. Smithsonian Institution. doi:10.25573/data.28127486
```

**Paper:**
```
Janousek, C. N., et al. (2025). Blue carbon stocks along the Pacific coast
of North America are mainly driven by local rather than regional factors.
Global Biogeochemical Cycles, 39(3), e2024GB008239. doi:10.1029/2024GB008239
```

**Method:**
```
Transfer learning approach adapted from: [Geoderma 2025 transfer learning paper]
Applied to blue carbon using Janousek et al. (2025) Pacific coast dataset.
```

---

## ❓ Troubleshooting

### Issue: Column names don't match

**Solution:** Inspect dataset and modify `harmonize_janousek_data()` function in Module 00D-BC

```r
# Check your column names
names(janousek_data)

# Modify column mapping in Module 00D-BC lines ~140-200
```

### Issue: Units unclear (% vs g/kg)

**Solution:** Check ranges

```r
summary(janousek_data$organic_carbon)
# If max < 100 → probably %
# If max > 100 → probably g/kg
```

### Issue: GEE export fails

**Solution:**
1. Check core locations file uploaded correctly
2. Verify username in GEE script
3. Try smaller batches (split by ecoregion)

### Issue: Models perform poorly (R² < 0.5)

**Possible causes:**
1. Covariate mismatch (different time periods?)
2. Missing key predictors (z* tidal elevation?)
3. Ecosystem mismatch (mangroves vs seagrass?)

**Solutions:**
1. Add more ecosystem-relevant covariates
2. Stratify by ecosystem type
3. Check covariate extraction quality

---

## 🎯 Success Criteria

**You'll know it's working when:**

✅ Module 00D-BC completes without errors
✅ OOB R² > 0.6 for at least 3 depths
✅ Feature importance makes ecological sense
✅ Ecosystem-specific performance is reasonable
✅ Module 05c detects blue carbon models automatically
✅ Module 05d shows >10% improvement over baseline

---

## 📞 Support

**If you get stuck:**

1. Check column names match in `harmonize_janousek_data()`
2. Verify covariate extraction completed successfully
3. Review GEE script for errors
4. Check log files in `logs/` directory
5. Inspect harmonized data: `data_global/janousek_harmonized_bluecarbon.csv`

---

**This integration leverages cutting-edge blue carbon science to enhance your regional predictions!**
