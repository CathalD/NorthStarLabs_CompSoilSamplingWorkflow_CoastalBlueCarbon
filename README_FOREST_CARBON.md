# 🌲 Canadian Forest Carbon Soil Monitoring Workflow

**A comprehensive R-based workflow for forest soil carbon monitoring, reporting, and verification (MRV) adapted for Canadian forest ecosystems. Compliant with VCS VM0012/VM0042, IPCC AFOLU Guidelines, and Canadian Forest Service protocols.**

[![VCS Compliant](https://img.shields.io/badge/VCS-VM0012%2FVM0042-brightgreen)]()
[![IPCC](https://img.shields.io/badge/IPCC-AFOLU%20Tier%203-blue)]()
[![License](https://img.shields.io/badge/license-MIT-orange)]()

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Forest Carbon Adaptations](#forest-carbon-adaptations)
- [Prerequisites](#prerequisites)
- [Workflow Structure](#workflow-structure)
- [Quick Start](#quick-start)
- [Forest-Specific Modules](#forest-specific-modules)
- [Standards Compliance](#standards-compliance)
- [Data Requirements](#data-requirements)
- [Output Files](#output-files)
- [Citation](#citation)

---

## 🎯 Overview

This workflow provides a **complete analytical pipeline** for forest soil carbon stock assessment in Canadian forest ecosystems. Originally designed for coastal blue carbon, it has been **comprehensively adapted for forest carbon accounting** with improved forest management (IFM) and afforestation/reforestation (A/R) verification.

**Target Ecosystems:**
- Boreal forests (black spruce, mixedwood)
- Temperate conifer forests (Douglas-fir, hemlock, cedar)
- Temperate deciduous forests (maple, oak, basswood)
- Coastal rainforests
- Post-harvest and regenerating forests
- Afforestation sites (former agricultural land)

**Geographic Focus:** Canada (British Columbia, Alberta, Ontario, Quebec)

**Carbon Pools:**
- LFH layer (organic forest floor: Litter-Fermentation-Humus)
- Mineral soil organic carbon (0-100 cm depth)
- Coarse fragment corrections for rocky soils

**Use Cases:**
- Carbon offset project development (VCS VM0012, VM0042)
- Baseline carbon stock assessment
- Improved forest management verification
- Afforestation/reforestation monitoring
- Post-harvest SOC recovery tracking
- Integration with CBM-CFS3 for national reporting

---

## ⭐ Key Features

✅ **VCS VM0012/VM0042 Compliant** - Conservative estimates, extended rotation IFM, A/R crediting

✅ **IPCC AFOLU Tier 3** - Stratified sampling, 95% confidence intervals, comprehensive uncertainty

✅ **LFH Layer Processing** - Separate organic forest floor carbon accounting

✅ **Coarse Fragment Corrections** - Essential for rocky forest soils

✅ **Multi-Method Spatial Prediction** - Random Forest (forest age/species-aware) and Ordinary Kriging

✅ **Depth Harmonization** - Equal-area spline to standard forest soil depths (0-15, 15-30, 30-50, 50-100 cm)

✅ **Comprehensive QA/QC** - Automated flagging specific to forest soils

✅ **Standards Compliance Checking** - VCS, IPCC, Canadian Forest Service, BC Protocol

✅ **Integration with CBM-CFS3** - Compatible data structures for Canadian national accounting

✅ **Provincial Protocol Support** - BC, ON, QC forest carbon offset protocols

---

## 🌲 Forest Carbon Adaptations

This workflow has been comprehensively adapted from coastal blue carbon to forest carbon:

### **Configuration Changes**
- Forest ecosystem strata (Boreal Black Spruce, Temperate Conifer, Coastal Rainforest, etc.)
- Forest-appropriate bulk density defaults (0.7-1.3 g/cm³ for mineral soil)
- LFH layer bulk density defaults (0.05-0.50 g/cm³)
- Extended QC thresholds for forest soils (SOC: 10-200 g/kg mineral, 250-550 g/kg LFH)
- Canada Albers Equal Area projection (EPSG:3347) as default
- Forest-specific scenarios (IFM, A/R, post-harvest, regeneration)

### **New Modules**
1. **Module 03b** - LFH Layer Processing (`03b_lfh_layer_processing.R`)
   - Volume-based forest floor sampling
   - Separate L, F, H layer analysis
   - LFH carbon stock calculation and reporting

2. **Module 01b** - Coarse Fragment Corrections (`01b_coarse_fragment_corrections.R`)
   - Rock/stone content accounting (>2mm particles)
   - Fine earth fraction calculations
   - Volumetric and gravimetric corrections

3. **Module 07b** - Forest Carbon Standards Compliance (`07b_forest_carbon_standards_compliance.R`)
   - VCS VM0012 (Improved Forest Management)
   - VCS VM0042 (Afforestation/Reforestation)
   - IPCC AFOLU Guidelines
   - Canadian Forest Service Framework
   - BC Forest Carbon Offset Protocol

### **Updated Standards**
- Replaced VM0033 (tidal wetlands) with VCS VM0012/VM0042 (forest projects)
- Replaced ORRAA (ocean-based) with Canadian Forest Service protocols
- Added provincial forest carbon offset protocol compliance
- Maintained IPCC (now AFOLU Volume 4 instead of Wetlands Supplement)

### **Forest-Specific Covariates**
- Forest age (years since disturbance)
- Species composition (conifer/deciduous mix)
- Site productivity (site index)
- Stand density and basal area
- Disturbance history (harvest, fire, insect outbreaks)
- Forest inventory attributes

### **Reference Data**
- Canadian forest carbon parameter database (`canadian_forest_carbon_parameters.csv`)
- 27 reference scenarios from CBM-CFS3, NFI, and published literature
- Regional values for BC, Boreal, Prairie, and Eastern Canada

---

## 🔧 Prerequisites

### Software Requirements

- **R** (≥ 4.0.0) - Statistical computing
- **RStudio** (recommended) - IDE
- **Google Earth Engine** account (optional) - For Bayesian priors and covariate extraction

### R Package Dependencies

```r
# Install all required packages
install.packages(c(
  # Core spatial
  "terra", "sf", "sp", "raster",

  # Data manipulation
  "dplyr", "tidyr", "readr",

  # Visualization
  "ggplot2", "gridExtra", "viridis",

  # Spatial modeling
  "gstat", "automap", "randomForest", "caret", "CAST",

  # Depth harmonization
  "ithir", "GSIF", "mpspline2",

  # Optional (enhanced outputs)
  "openxlsx", "knitr", "rmarkdown"
))
```

---

## 🗺️ Workflow Structure

The workflow consists of **4 parts** with **20 modules** total (including forest-specific additions).

### **PART 1: Sampling Design & Bayesian Priors (GEE - Optional)**

Not typically used for forest carbon (forests have extensive inventory data), but available if using SoilGrids or regional SOC maps as priors.

**Modules:**
- `00a_install_packages_v2.R` - Install dependencies
- `00b_setup_directories.R` - Create directory structure
- `00c_bayesian_prior_setup_bluecarbon.R` - Load SoilGrids/regional priors
- `01c_bayesian_sampling_design_bluecarbon.R` - Neyman optimal allocation

**When to use:** Large-scale projects (>10,000 ha) where prior maps can guide sampling allocation.

---

### **PART 2: Core Analysis Pipeline (REQUIRED)**

The main workflow for forest soil carbon analysis.

#### **Setup**
- **Module 00B** - `00b_setup_directories.R` - Create folder structure

#### **Data Preparation**
- **Module 01** - `01_data_prep_bluecarbon.R` - Load and validate field data
  - Core location validation
  - Stratum assignment
  - Bulk density defaults
  - Initial carbon stock calculation

- **Module 01B** 🌲 **NEW** - `01b_coarse_fragment_corrections.R` - Apply coarse fragment corrections
  - Volume/mass/class-based CF data
  - Fine earth fraction calculation
  - Corrected carbon stocks

#### **Quality Control**
- **Module 02** - `02_exploratory_analysis_bluecarbon.R` - QA/QC and outlier detection
  - Forest-specific QC thresholds
  - Outlier detection (Tukey fences)
  - Monotonicity checks (SOC decreases with depth)

#### **Depth Processing**
- **Module 03** - `03_depth_harmonization_bluecarbon.R` - Harmonize variable depths to standard intervals
  - Equal-area spline (mass-preserving)
  - Standard depths: 0-15, 15-30, 30-50, 50-100 cm
  - Uncertainty quantification

- **Module 03B** 🌲 **NEW** - `03b_lfh_layer_processing.R` - Process LFH layer
  - Thickness measurements
  - LFH bulk density assignment
  - LFH carbon stocks by stratum
  - Separate L, F, H layer analysis (optional)

#### **Spatial Prediction**
- **Module 04** - `04_raster_predictions_kriging_bluecarbon.R` - Ordinary Kriging
  - Variogram modeling
  - Spatial cross-validation
  - Uncertainty maps

- **Module 05** - `05_raster_predictions_rf_bluecarbon.R` - Random Forest
  - Forest age/species-aware prediction
  - Spatial covariates integration
  - Variable importance
  - Area of Applicability (AOA)

#### **Aggregation & Reporting**
- **Module 06** - `06_carbon_stock_calculation_bluecarbon.R` - Aggregate depth layers
  - Total 0-100 cm carbon stocks
  - LFH + mineral soil combined
  - Conservative estimates (95% CI lower bound)

- **Module 06C** - `06c_bayesian_posterior_estimation_bluecarbon.R` (Optional) - Bayesian posterior
  - Combine priors with field data
  - Uncertainty reduction analysis

- **Module 07** - `07_mmrv_reporting_bluecarbon.R` - Generate verification package
  - HTML reports
  - Excel summary tables
  - Spatial exports (GeoTIFF, shapefiles)

- **Module 07B** 🌲 **UPDATED** - `07b_forest_carbon_standards_compliance.R` - Standards compliance
  - VCS VM0012 / VM0042 checks
  - IPCC AFOLU Tier 3 requirements
  - Canadian Forest Service framework
  - BC Forest Carbon Offset Protocol
  - Actionable recommendations

---

### **PART 3: Temporal Monitoring & Additionality (Optional)**

For multi-year projects requiring temporal change detection.

- **Module 08** - `08_temporal_data_harmonization.R` - Align multi-year datasets
- **Module 08A** - `08a_scenario_builder_bluecarbon.R` - Generate synthetic scenarios
  - Recovery curves (exponential, logistic, linear)
  - Reference trajectories from Canadian literature
- **Module 09** - `09_additionality_temporal_analysis.R` - Detect significant changes
  - PROJECT vs. BASELINE comparisons
  - Conservative crediting calculations
- **Module 10** - `10_vm0033_final_verification.R` - Final verification checklist

---

### **PART 4: Bayesian Analysis (Optional)**

- **Module 06C** - `06c_bayesian_posterior_estimation_bluecarbon.R` - Posterior estimation

---

## 🚀 Quick Start

### **1. Clone or Download Repository**

```bash
git clone https://github.com/your-org/canadian-forest-carbon-workflow.git
cd canadian-forest-carbon-workflow
```

### **2. Configure Project**

Edit `blue_carbon_config.R`:

```r
# Update project metadata
PROJECT_NAME <- "MyForest_Carbon_2024"
PROJECT_LOCATION <- "British Columbia, Canada"
PROJECT_SCENARIO <- "IFM_EXTENDED_ROTATION"  # or AR_Y10, etc.

# Ensure forest settings are active
MEASURE_LFH_LAYER <- TRUE
FOREST_MIN_CORES <- 5
FOREST_TARGET_PRECISION <- 15
```

### **3. Prepare Input Data**

Create two required CSV files:

**`data_raw/core_locations.csv`**

```csv
core_id,longitude,latitude,stratum,core_type,scenario_type,monitoring_year
FC001,-123.456,49.123,Temperate Conifer,HR,PROJECT,2024
FC002,-123.458,49.125,Temperate Conifer,Paired Composite,PROJECT,2024
FC003,-123.460,49.127,Boreal Mixedwood,HR,PROJECT,2024
```

**`data_raw/core_samples.csv`**

```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3,coarse_frag_pct
FC001,0,10,78.5,0.92,15
FC001,10,20,65.2,0.98,18
FC001,20,30,52.8,1.05,20
```

**`data_raw/lfh_samples.csv`** (if MEASURE_LFH_LAYER = TRUE)

```csv
sample_id,stratum,thickness_cm,bulk_density_g_cm3,soc_g_kg,area_cm2
FC001,Temperate Conifer,12.5,0.18,385,100
FC002,Temperate Conifer,10.2,0.16,398,100
```

### **4. Run Example Workflow**

```r
source("EXAMPLE_forest_carbon_workflow.R")
```

This script will:
1. Load configuration
2. Process field data
3. Apply coarse fragment corrections
4. Process LFH layer
5. Harmonize depths
6. Generate carbon stock maps
7. Check standards compliance
8. Produce final reports

### **5. Review Outputs**

```
outputs/
├── carbon_stocks/
│   ├── carbon_stocks_by_stratum_rf.csv         # Summary table
│   ├── total_carbon_stock_0_100cm.tif          # Mineral soil map
│   └── lfh_carbon_stock.tif                    # LFH layer map
├── reports/
│   ├── standards_compliance_summary.csv         # Compliance status
│   ├── recommendations_action_plan.csv          # Action items
│   └── forest_carbon_compliance_report.html     # Full report
└── predictions/
    └── rf/
        ├── carbon_stock_rf_7_5cm.tif
        ├── variable_importance_7_5cm.png
        └── aoa_7_5cm.tif                        # Area of applicability
```

---

## 🌲 Forest-Specific Modules

### **Module 01B: Coarse Fragment Corrections**

Forest soils often contain 10-50% coarse fragments (stones, gravel, rock). These must be excluded from carbon calculations.

**Methods supported:**
- Volumetric (% volume >2mm)
- Gravimetric (convert mass % to volume %)
- Visual class estimation (e.g., "15-35%", "common")

**Example:**

```r
source("01b_coarse_fragment_corrections.R")

cores <- readRDS("data_processed/cores_prepared_bluecarbon.rds")

cores_corrected <- apply_coarse_fragment_corrections(
  cores,
  cf_type = "volume",  # or "mass", "class"
  create_plots = TRUE
)
```

**Outputs:**
- Corrected carbon stocks
- Fine earth fraction by stratum
- Diagnostic plots showing CF impact

---

### **Module 03B: LFH Layer Processing**

The organic forest floor (LFH layer) is a major carbon pool in many forests, separate from mineral soil.

**Measurements required:**
- LFH thickness (cm) - measured with ruler after removal
- Bulk density (g/cm³) - volume-based sampling (known area × depth)
- SOC (g/kg) - lab analysis

**Optional:** Separate L, F, H layers for detailed analysis.

**Example:**

```r
source("03b_lfh_layer_processing.R")

lfh_result <- process_lfh_layer(
  lfh_file = "data_raw/lfh_samples.csv",
  locations_file = "data_raw/core_locations.csv"
)

# View summary
print(lfh_result$summary)
```

**Outputs:**
- `lfh_processed.rds` - Full LFH dataset
- `lfh_stocks_by_stratum.csv` - Summary statistics
- `lfh_stock_by_stratum.png` - Boxplot visualization

---

### **Module 07B: Forest Carbon Standards Compliance**

Automated checking against 5 forest carbon standards:

**Standards checked:**
1. **VCS VM0012** - Improved Forest Management
2. **VCS VM0042** - Afforestation, Reforestation, Revegetation
3. **IPCC AFOLU** - Tier 3 requirements
4. **Canadian Forest Service** - CBM-CFS3 compatibility
5. **BC Forest Carbon Offset Protocol** - Provincial requirements

**Example:**

```r
source("07b_forest_carbon_standards_compliance.R")

# Automatically runs compliance checks and generates:
# - standards_compliance_summary.csv
# - recommendations_action_plan.csv
```

**Output example:**

```
============================================================
COMPLIANCE SUMMARY
============================================================

Standard: VCS VM0012
  ✓ All strata have ≥5 samples (min: 8)
  ✓ All strata within target precision (max: 12.4%)
  ✓ Total plots (24) meets minimum requirement (15)
  ✓ Conservative estimates properly calculated
  ✓ Monitoring frequency: 5 years

Standard: IPCC AFOLU
  ✓ Both 0-30 cm and 0-100 cm carbon stocks reported
  ✓ LFH layer carbon stocks measured and reported separately
  ✓ Coarse fragment corrections applied (mean: 18.5% vol)
  ✗ WARNING: Missing site-level disturbance history documentation

Overall Compliance Rate: 95.2%
Total Criteria Checked: 21
Passed: 20
Failed: 1
```

---

## 📊 Standards Compliance

### **VCS VM0012 (Improved Forest Management)**

✅ Minimum 5 plots per stratum (configurable)
✅ ≤15% relative error at 95% CI
✅ Conservative carbon stock estimation (95% CI lower bound)
✅ Monitoring every 5-10 years
✅ Stratification by forest type and age

### **VCS VM0042 (Afforestation/Reforestation)**

✅ Baseline (pre-planting) carbon stocks documented
✅ Stratification by former land use
✅ Temporal monitoring at 5-year intervals
✅ Separate reporting of soil and biomass pools (if applicable)

### **IPCC AFOLU Guidelines (Tier 3)**

✅ Standard depth intervals (0-30 cm, 0-100 cm)
✅ LFH layer reported separately
✅ Coarse fragment corrections applied
✅ 95% confidence intervals
✅ Stratification by forest type, age, and management

### **Canadian Forest Service Framework**

✅ Compatible with CBM-CFS3 model structure
✅ Aligned with National Forest Inventory (NFI) protocols
✅ Provincial forest inventory depth standards (0-15, 15-30, 30-50, 50-100 cm + LFH)

### **BC Forest Carbon Offset Protocol**

✅ Soil carbon pool inclusion for A/R projects
✅ 5-year monitoring intervals
✅ 100-year permanence period commitment
✅ Leakage and additionality documentation

---

## 📁 Data Requirements

### **Required Input Files**

1. **`core_locations.csv`** (GPS coordinates and metadata)
   - Columns: `core_id`, `longitude`, `latitude`, `stratum`, `core_type`, `scenario_type`, `monitoring_year`

2. **`core_samples.csv`** (Depth profiles)
   - Columns: `core_id`, `depth_top_cm`, `depth_bottom_cm`, `soc_g_kg`, `bulk_density_g_cm3`, `coarse_frag_pct`

### **Optional Input Files**

3. **`lfh_samples.csv`** (Forest floor measurements)
   - Columns: `sample_id`, `stratum`, `thickness_cm`, `bulk_density_g_cm3`, `soc_g_kg`, `area_cm2`
   - Optional: `l_thickness_cm`, `f_thickness_cm`, `h_thickness_cm` for separate layers

4. **Spatial covariates** (for Random Forest - see `FOREST_COVARIATES_GUIDE.md`)
   - `covariates/forest_inventory/forest_age.tif`
   - `covariates/climate/mean_annual_temp.tif`
   - `covariates/topography/elevation.tif`
   - `covariates/spectral/ndvi_summer.tif`
   - See full list in covariate guide

### **Reference Data (Included)**

5. **`canadian_forest_carbon_parameters.csv`**
   - 27 reference scenarios from Canadian literature
   - Used for scenario modeling and validation

---

## 📂 Output Files

### **Processed Data**
- `data_processed/cores_prepared_bluecarbon.rds` - Validated field data
- `data_processed/cores_cf_corrected.rds` - Coarse fragment corrected
- `data_processed/cores_harmonized_bluecarbon.rds` - Depth harmonized
- `data_processed/lfh_processed.rds` - LFH layer carbon stocks

### **Carbon Stock Maps**
- `outputs/predictions/rf/carbon_stock_rf_{depth}cm.tif` - Random Forest predictions
- `outputs/predictions/kriging/carbon_stock_kriging_{depth}cm.tif` - Kriging predictions
- `outputs/carbon_stocks/total_carbon_stock_0_100cm.tif` - Aggregated mineral soil
- `outputs/carbon_stocks/lfh_carbon_stock.tif` - LFH layer stock

### **Summary Tables**
- `outputs/carbon_stocks/carbon_stocks_by_stratum_rf.csv` - Stratum-level summaries
- `outputs/carbon_stocks/carbon_stocks_conservative_vm0033_rf.csv` - Conservative estimates
- `data_processed/lfh_stocks_by_stratum.csv` - LFH summary

### **Compliance Reports**
- `outputs/reports/standards_compliance_summary.csv` - Pass/fail by criterion
- `outputs/reports/recommendations_action_plan.csv` - Prioritized action items
- `outputs/reports/forest_carbon_compliance_report.html` - Full HTML report

### **Diagnostics**
- `diagnostics/qaqc/qc_flags.csv` - QC issue flagging
- `diagnostics/coarse_fragments/cf_distribution_by_stratum.png`
- `diagnostics/lfh_layer/lfh_stock_by_stratum.png`
- `diagnostics/crossvalidation/rf_cv_results.csv` - Model performance

---

## 📚 Documentation

- **`README_FOREST_CARBON.md`** (this file) - Complete workflow guide
- **`FOREST_COVARIATES_GUIDE.md`** - Spatial covariate preparation
- **`EXAMPLE_forest_carbon_workflow.R`** - Example script with annotations
- **`blue_carbon_config.R`** - Configuration file (fully documented)
- Inline code documentation in all modules

---

## 🌍 Geographic Scope

### **Canadian Ecozones Supported**

- ✅ **Boreal Shield** - Black spruce, mixedwood
- ✅ **Boreal Plains** - Aspen, jack pine
- ✅ **Montane Cordillera** - Interior Douglas-fir, lodgepole pine
- ✅ **Pacific Maritime** - Coastal Douglas-fir, western hemlock, cedar
- ✅ **Mixedwood Plains** - Sugar maple, oak, basswood
- ✅ **Taiga Shield** - Open black spruce, lichen woodland
- ✅ **Prairie** - Shelterbelts, afforestation

### **Provincial Applications**

- **British Columbia** - BC Forest Carbon Offset Protocol compliant
- **Alberta** - Compatible with AB offset protocol
- **Ontario** - Aligned with ON carbon program
- **Quebec** - QC carbon market compatible
- **Other provinces** - IPCC Tier 3 compliant

---

## 🔬 Methodological References

### **Forest Carbon Accounting**
- Kurz et al. 2009. CBM-CFS3: A model of carbon-dynamics in forestry and land-use change implementing IPCC standards. *Ecological Modelling*.
- IPCC 2006. Guidelines for National Greenhouse Gas Inventories: Volume 4 - AFOLU.
- VCS VM0012. Improved Forest Management in Temperate and Boreal Forests (IFM). Verra.
- VCS VM0042. Methodology for Improved Agricultural Land Management. Verra.

### **Canadian Frameworks**
- Environment and Climate Change Canada. 2021. National Inventory Report 1990-2019.
- Natural Resources Canada. Canadian Forest Service Carbon Accounting.
- BC Ministry of Environment. 2021. British Columbia Forest Carbon Offset Protocol v2.1.

### **Soil Carbon Methods**
- Shaw et al. 2018. A Comprehensive Soil Organic Carbon Database for Canadian Boreal Forests. *Scientific Data*.
- Kurz & Apps. 2006. Developing Canada's National Forest Carbon Monitoring, Accounting and Reporting System.
- Kranabetter et al. 2015. Forest productivity and soil carbon dynamics in western red cedar plantations.

---

## 📞 Support & Citation

### **Citation**

If you use this workflow, please cite:

```
Canadian Forest Carbon Soil Monitoring Workflow (2024).
Adapted from Blue Carbon Composite Sampling & MMRV Workflow.
https://github.com/your-org/canadian-forest-carbon-workflow
```

And cite the original blue carbon workflow if applicable.

### **Issues & Questions**

- GitHub Issues: [Link to repo issues]
- Email: [Contact email]
- Documentation: See `FOREST_COVARIATES_GUIDE.md` and inline code comments

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

- **Natural Resources Canada** - CBM-CFS3 model and NFI data
- **Environment and Climate Change Canada** - National reporting framework
- **Provincial forest agencies** - Forest inventory data and protocols
- **Verra** - VCS methodologies (VM0012, VM0042)
- **IPCC** - AFOLU Guidelines
- Original blue carbon workflow developers

---

## 🗺️ Roadmap

Planned improvements:
- [ ] Direct CBM-CFS3 output integration
- [ ] Automated NFI data import
- [ ] Provincial VRI data connectors (BC, AB, ON)
- [ ] Root biomass carbon estimation module
- [ ] Fire/insect disturbance impact quantification
- [ ] Multi-pool reporting (soil + biomass + deadwood)
- [ ] Shiny dashboard for interactive results exploration

---

**Last Updated:** November 2024
**Version:** 1.0 (Forest Carbon Adaptation)

---

🌲 **Ready to get started? See the [Quick Start](#quick-start) guide above!** 🌲
