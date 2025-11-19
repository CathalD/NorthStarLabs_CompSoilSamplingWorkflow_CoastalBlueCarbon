# Blue Carbon Workflow - Complete Input/Output Reference

## 📋 Repository Structure

```
├── 00a-00e    Setup & Transfer Learning (optional)
├── 01-03      Core Workflow (data prep, EDA, harmonization)
├── 04-05      Spatial Prediction (kriging or Random Forest)
├── 06-07      Carbon Stock Calculation & Reporting
├── 08-10      Temporal Analysis & Verification (optional)
│
├── docs/              Documentation
├── gee_scripts/       Google Earth Engine scripts
├── archive/           Deprecated experimental scripts
└── data_*/            Data directories (created by setup)
```

---

## 🎯 Quick Start: Which Workflow Do I Use?

### **Standard Workflow** (No Transfer Learning)
```
00a → 00b → 01 → 02 → 03 → (04 OR 05) → 06 → 07
```
**Time:** 2-4 hours | **Best for:** Sites with >50 cores

### **Transfer Learning Workflow** (Recommended for <50 cores)
```
00a → 00b → 01 → 02 → 03 → [GEE: Extract Global Features] → 05c → 06 → 07
```
**Time:** 3-5 hours | **Best for:** Sites with <50 cores, 15-30% better accuracy

---

## 📥 REQUIRED INPUT DATA

### **1. Your Field Core Data** (REQUIRED)

Place these files in `data_raw/` or project root:

| File | Columns | Example |
|------|---------|---------|
| **`core_locations.csv`** | `core_id, latitude, longitude, ecosystem, stratum` | `CORE001, 49.123, -123.456, Tidal_Marsh, High_Marsh` |
| **`core_samples.csv`** | `core_id, depth_top_cm, depth_bottom_cm, bulk_density_g_cm3, organic_carbon_pct` | `CORE001, 0, 5, 0.45, 12.3` |

**Templates available:**
- `core_locations_TEMPLATE.csv`
- `core_samples_TEMPLATE.csv`

---

### **2. Google Earth Engine Covariates** (REQUIRED for RF, optional for Kriging)

Export these from GEE and place in `covariates/`:

#### **Option A: Local Covariates Only** (Standard Workflow)
Use: `gee_scripts/BLUE CARBON COVARIATES.js`

Required bands (30m resolution):
```
covariates/
├── optical/
│   ├── NDVI_median_annual.tif
│   ├── EVI_median_growing.tif
│   ├── NDMI_median_annual.tif
│   └── NDWI_median_annual.tif
├── sar/
│   ├── VV_median.tif
│   └── VH_median.tif
└── topography/
    ├── elevation_m.tif
    └── slope_degrees.tif
```

#### **Option B: Local + Global Features** (Transfer Learning Workflow)
Use: `gee_scripts/GEE_EXTRACT_BLUECARBON_GLOBAL_MAPS.js`

This extracts 26 global features at your core locations and exports as CSV:
- Murray tidal classification
- Global Surface Water (inundation)
- WorldClim (climate)
- Topography
- SoilGrids (terrestrial comparison)

Place result in: `data_global/cores_with_bluecarbon_global_maps.csv`

---

### **3. Configuration Files** (AUTO-GENERATED, review and edit)

| File | Purpose | When to Edit |
|------|---------|--------------|
| **`blue_carbon_config.R`** | Global settings (CRS, depths, VM0033 params) | Before starting workflow |
| **`stratum_definitions_EXAMPLE.csv`** | Stratum areas and characteristics | Rename to remove `_EXAMPLE`, edit for your site |

---

## 📤 OUTPUT DATA STRUCTURE

After running the workflow, you'll have:

```
outputs/
├── plots/
│   ├── exploratory/           # EDA visualizations (Module 02)
│   │   ├── core_map.png
│   │   ├── depth_profiles.png
│   │   └── carbon_by_stratum.png
│   │
│   └── by_stratum/            # Harmonization plots (Module 03)
│       ├── stratum_High_Marsh_depth_7.5cm.png
│       └── ...
│
├── predictions/
│   ├── kriging/               # Kriging predictions (Module 04)
│   │   ├── carbon_stock_7.5cm_kriging.tif
│   │   ├── carbon_stock_22.5cm_kriging.tif
│   │   ├── carbon_stock_40cm_kriging.tif
│   │   └── carbon_stock_75cm_kriging.tif
│   │
│   ├── rf/                    # Random Forest predictions (Module 05/05c)
│   │   ├── carbon_stock_7.5cm_rf.tif
│   │   └── ...
│   │
│   └── uncertainty/           # Uncertainty maps
│       ├── kriging_uncertainty_7.5cm.tif
│       └── rf_uncertainty_7.5cm.tif
│
├── carbon_stocks/
│   ├── carbon_stocks_by_stratum.csv      # Module 06 summary
│   ├── total_site_carbon_stock.csv       # Total estimates
│   └── maps/
│       └── total_carbon_stock_0_100cm.tif
│
├── mmrv_reports/
│   ├── VM0033_Verification_Report.html   # Final report (Module 07)
│   ├── carbon_stock_tables.csv
│   ├── spatial_exports/
│   │   └── carbon_stock_polygons.shp
│   └── figures/
│       ├── site_map.png
│       └── carbon_by_stratum_chart.png
│
└── models/
    ├── kriging/
    │   ├── variogram_7.5cm.rds
    │   └── kriging_model_7.5cm.rds
    │
    └── rf/
        ├── rf_local_7.5cm.rds            # Local-only model
        └── rf_transfer_7.5cm.rds         # Transfer learning model

data_processed/
├── cores_cleaned.rds                      # Module 01 output
├── cores_with_covariates.rds              # Module 01 with GEE data
├── harmonized_cores_VM0033.csv            # Module 03 output (key file!)
└── cores_with_global_features.csv         # Module 05c with transfer learning

diagnostics/
├── data_prep/
│   └── data_quality_report.html           # Module 01 QA/QC
├── qaqc/
│   └── outlier_detection.csv
├── variograms/
│   └── variogram_plots_by_depth.png
├── crossvalidation/
│   ├── rf_cv_results.csv
│   └── kriging_cv_results.csv
└── transfer_learning/
    └── transfer_learning_summary.csv      # Module 05c comparison

logs/
├── setup_2025-11-19.txt
├── module_01_2025-11-19.log
└── ...
```

---

## 🔄 COMPLETE WORKFLOW MODULES

### **SETUP & INSTALLATION**

#### **00a_install_packages_v2.R**
**Purpose:** Install all required R packages
**Inputs:** None
**Outputs:** Installed packages
**Run:** Once per machine/environment
```r
source("00a_install_packages_v2.R")
```

#### **00b_setup_directories.R**
**Purpose:** Create directory structure
**Inputs:** None
**Outputs:** Created folders (`data_raw/`, `outputs/`, `diagnostics/`, etc.)
**Run:** Once per project
```r
source("00b_setup_directories.R")
```

---

### **TRANSFER LEARNING SETUP** (Optional but Recommended)

#### **[GEE] gee_scripts/GEE_EXTRACT_BLUECARBON_GLOBAL_MAPS.js**
**Purpose:** Extract global blue carbon features at your core locations
**Inputs:** Your `core_locations.csv` uploaded to GEE as asset
**Outputs:** `cores_with_bluecarbon_global_maps.csv` (26 global features)
**Run:** Once, in Google Earth Engine
**Time:** ~5 minutes

#### **00e_pragmatic_transfer_learning.R** (Optional alternative)
**Purpose:** Extract SoilGrids via REST API (alternative to GEE)
**Inputs:** `data_raw/core_locations.csv`
**Outputs:** `data_global/regional_cores_with_global_features.csv`
**Run:** Once (if not using GEE method)
**Time:** ~10 minutes for 100 cores

---

### **CORE WORKFLOW**

#### **01_data_prep_bluecarbon.R**
**Purpose:** Load, validate, and prepare field core data
**Inputs:**
- `data_raw/core_locations.csv`
- `data_raw/core_samples.csv`
- `covariates/*.tif` (GEE exports)

**Outputs:**
- `data_processed/cores_cleaned.rds`
- `data_processed/cores_with_covariates.rds`
- `diagnostics/data_prep/data_quality_report.html`

**Run:** First
```r
source("01_data_prep_bluecarbon.R")
```

#### **02_exploratory_analysis_bluecarbon.R**
**Purpose:** Explore data patterns, visualize distributions
**Inputs:** `data_processed/cores_cleaned.rds`
**Outputs:**
- `outputs/plots/exploratory/*.png`
- `diagnostics/qaqc/*.csv`

**Run:** Second
```r
source("02_exploratory_analysis_bluecarbon.R")
```

#### **03_depth_harmonization_bluecarbon.R**
**Purpose:** Harmonize samples to VM0033 standard depths (7.5, 22.5, 40, 75 cm)
**Inputs:** `data_processed/cores_cleaned.rds`
**Outputs:**
- `data_processed/harmonized_cores_VM0033.csv` ⭐ **KEY FILE**
- `outputs/plots/by_stratum/*.png`

**Run:** Third
```r
source("03_depth_harmonization_bluecarbon.R")
```

---

### **SPATIAL PREDICTION** (Choose ONE approach)

#### **Option A: 04_raster_predictions_kriging_bluecarbon.R**
**Purpose:** Ordinary kriging (no covariates needed)
**Inputs:** `data_processed/harmonized_cores_VM0033.csv`
**Outputs:**
- `outputs/predictions/kriging/*.tif`
- `outputs/predictions/uncertainty/*.tif`
- `outputs/models/kriging/*.rds`

**Run:** If you want simple kriging
```r
source("04_raster_predictions_kriging_bluecarbon.R")
```

#### **Option B: 05_raster_predictions_rf_bluecarbon.R**
**Purpose:** Random Forest with local covariates
**Inputs:**
- `data_processed/harmonized_cores_VM0033.csv`
- `covariates/*.tif`

**Outputs:**
- `outputs/predictions/rf/*.tif`
- `outputs/models/rf/rf_local_*.rds`

**Run:** If you have GEE covariates, no transfer learning
```r
source("05_raster_predictions_rf_bluecarbon.R")
```

#### **Option C: 05c_transfer_learning_integration.R** ⭐ RECOMMENDED
**Purpose:** Random Forest with local + global features (transfer learning)
**Inputs:**
- `data_processed/harmonized_cores_VM0033.csv`
- `data_global/cores_with_bluecarbon_global_maps.csv`
- `covariates/*.tif`

**Outputs:**
- `outputs/predictions/rf/*.tif`
- `outputs/models/rf/rf_transfer_*.rds` (improved model)
- `outputs/models/rf/rf_local_*.rds` (baseline)
- `diagnostics/transfer_learning/summary.csv` (improvement stats)

**Run:** If you want best accuracy (15-30% improvement)
```r
source("05c_transfer_learning_integration.R")
```

---

### **CARBON STOCK CALCULATION & REPORTING**

#### **06_carbon_stock_calculation_bluecarbon.R**
**Purpose:** Calculate total carbon stocks by stratum and site
**Inputs:**
- Prediction rasters from Module 04 or 05
- `stratum_definitions.csv`

**Outputs:**
- `outputs/carbon_stocks/carbon_stocks_by_stratum.csv`
- `outputs/carbon_stocks/total_site_carbon_stock.csv`
- `outputs/carbon_stocks/maps/*.tif`

**Run:** After spatial prediction
```r
source("06_carbon_stock_calculation_bluecarbon.R")
```

#### **07_mmrv_reporting_bluecarbon.R**
**Purpose:** Generate final VM0033 verification report
**Inputs:** All outputs from previous modules
**Outputs:**
- `outputs/mmrv_reports/VM0033_Verification_Report.html` ⭐ **FINAL REPORT**
- `outputs/mmrv_reports/carbon_stock_tables.csv`
- `outputs/mmrv_reports/spatial_exports/*.shp`

**Run:** Final step
```r
source("07_mmrv_reporting_bluecarbon.R")
```

---

## 🔀 OPTIONAL MODULES

### **Bayesian Workflow** (Alternative to frequentist)
- **00c_bayesian_prior_setup_bluecarbon.R** - Setup priors
- **01c_bayesian_sampling_design_bluecarbon.R** - Design sampling
- **06c_bayesian_posterior_estimation_bluecarbon.R** - Posterior estimation

### **Temporal Analysis** (For project monitoring)
- **08_temporal_data_harmonization.R** - Compare multiple time periods
- **08a_scenario_builder_bluecarbon.R** - Model scenarios
- **09_additionality_temporal_analysis.R** - Additionality assessment

### **Final Verification**
- **10_vm0033_final_verification.R** - Final checks for Verra submission
- **07b_comprehensive_standards_report.R** - Multi-standard report

---

## 📊 TYPICAL WORKFLOW PATHS

### **Path 1: Quick Site Assessment** (2-3 hours)
```
00a → 00b → 01 → 02 → 03 → 04 (kriging) → 06 → 07
```
**Use when:** Limited time, no GEE covariates available

### **Path 2: Standard RF Workflow** (3-4 hours)
```
00a → 00b → [GEE: local covariates] → 01 → 02 → 03 → 05 (RF) → 06 → 07
```
**Use when:** Have GEE covariates, >50 field cores

### **Path 3: Transfer Learning Workflow** ⭐ RECOMMENDED (3-5 hours)
```
00a → 00b → [GEE: local + global] → 01 → 02 → 03 → 05c (Transfer) → 06 → 07
```
**Use when:** <50 field cores, want best accuracy

### **Path 4: Bayesian Workflow** (4-6 hours)
```
00a → 00b → 00c → 01c → 01 → 02 → 03 → 06c → 07
```
**Use when:** Prior knowledge available, formal uncertainty quantification needed

---

## 🎯 KEY FILES TO CHECK

After each module, verify these files exist:

| After Module | Check This File | Purpose |
|--------------|----------------|---------|
| 01 | `data_processed/cores_with_covariates.rds` | Data loaded successfully |
| 03 | `data_processed/harmonized_cores_VM0033.csv` | Ready for prediction |
| 05c | `diagnostics/transfer_learning/summary.csv` | Transfer learning improvement |
| 06 | `outputs/carbon_stocks/total_site_carbon_stock.csv` | Final estimates |
| 07 | `outputs/mmrv_reports/VM0033_Verification_Report.html` | Final report |

---

## 🚨 Troubleshooting

### **"File not found" errors**
- Run `00b_setup_directories.R` to create folders
- Check file paths match exactly (case-sensitive)
- Ensure CSV files are in `data_raw/` not project root

### **"Missing covariates" errors**
- Export covariates from GEE first
- Check files are in `covariates/` with correct names
- Use Module 04 (kriging) if covariates unavailable

### **"Insufficient samples" warnings**
- Need minimum 10 cores per depth
- Consider using transfer learning (Module 05c) to improve with fewer samples

### **Transfer learning not improving**
- Check global features merged correctly
- Verify feature importance includes global features
- May indicate your site is very unique (still beneficial to include)

---

## 📚 Documentation

- **`docs/INTEGRATION_GUIDE.md`** - How to combine global + local data
- **`docs/PRAGMATIC_TRANSFER_LEARNING.md`** - Transfer learning methodology
- **`docs/BLUECARBON_GLOBAL_MAPS.md`** - About global products used
- **`README.md`** - Project overview

---

## 🎓 Expected Outputs for Carbon Project

For Verra VM0033 submission, you need:

1. ✅ **VM0033_Verification_Report.html** (Module 07)
2. ✅ **Carbon stock maps** by depth (Module 04/05)
3. ✅ **Uncertainty quantification** (Module 04/05)
4. ✅ **Validation metrics** (R², RMSE, MAE)
5. ✅ **Spatial exports** (shapefiles for GIS)
6. ✅ **Method documentation** (transfer learning, if used)

All generated automatically by the workflow! 🎉

---

## ⏱️ Time Estimates

| Workflow | Modules | Time | Cores Needed |
|----------|---------|------|--------------|
| **Minimum** | 01-03, 04, 06-07 | 2-3 hours | 10-20 |
| **Standard** | 01-03, 05, 06-07 | 3-4 hours | 20-50 |
| **Transfer Learning** | 01-03, 05c, 06-07 | 3-5 hours | <50 (better!) |
| **Full Bayesian** | 00c, 01c, 01-03, 06c, 07 | 4-6 hours | Any |
| **Temporal Analysis** | Standard + 08-09 | 5-7 hours | Multiple dates |

*Time excludes GEE export time (~30 min) and data preparation*

---

## 🏁 Quick Checklist

Before starting:
- [ ] Installed R packages (Module 00a)
- [ ] Created directories (Module 00b)
- [ ] Placed field data in `data_raw/`
- [ ] Exported GEE covariates to `covariates/`
- [ ] (Optional) Extracted global features to `data_global/`
- [ ] Edited `blue_carbon_config.R` for your site
- [ ] Created `stratum_definitions.csv`

After finishing:
- [ ] `VM0033_Verification_Report.html` generated
- [ ] Carbon stock maps created
- [ ] Uncertainty quantified
- [ ] All diagnostics look reasonable
- [ ] Results documented for MMRV

🌊 **Ready to quantify your blue carbon!** 🌊
