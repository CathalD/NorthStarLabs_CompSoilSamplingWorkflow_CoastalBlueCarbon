# 🌍 Generalized Multi-Ecosystem MMRV Workflow

**A flexible R-based framework for carbon monitoring, reporting, and verification (MMRV) across multiple ecosystem types**

[![Multi-Ecosystem](https://img.shields.io/badge/Ecosystems-5%20Types-brightgreen)]()
[![Standards Compliant](https://img.shields.io/badge/Standards-VM0033%20%7C%20IPCC%20%7C%20ORRAA%20%7C%20ICVCM%20CCP-blue)]()
[![Version](https://img.shields.io/badge/version-2.1-orange)]()
[![ICVCM](https://img.shields.io/badge/ICVCM-CCP%20Ready-success)]()

---

## 📋 Table of Contents

- [Overview](#overview)
- [Supported Ecosystems](#supported-ecosystems)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Ecosystem Selection](#ecosystem-selection)
  - [Composite Sampling Toggle](#composite-sampling-toggle)
  - [Optional Modules](#optional-modules)
- [Workflow Structure](#workflow-structure)
- [How to Run](#how-to-run)
- [Adding New Ecosystems](#adding-new-ecosystems)
- [Output Structure](#output-structure)
- [Troubleshooting](#troubleshooting)
- [Citation](#citation)

---

## 🎯 Overview

This workflow provides a **unified analytical framework** for soil carbon stock assessment and MMRV across multiple ecosystem types. Originally designed for coastal blue carbon, it has been generalized to support:

- **5 ecosystem types** (easily extensible)
- **Composite sampling** (optional - can be toggled on/off)
- **Modular design** with optional components
- **Standards-compliant** outputs for carbon credit development

**Version 2.0** represents a major generalization effort to create a single codebase that can handle diverse ecosystem types with ecosystem-specific parameters loaded dynamically.

---

## 🌲🌾🌊 Supported Ecosystems

### 1. **Coastal Blue Carbon** 🌊
- **Ecosystems:** Salt marshes, tidal wetlands, seagrass beds, mangroves
- **Standards:** VM0033, ORRAA, IPCC Wetlands Supplement
- **Depth:** 0-100 cm
- **Key Feature:** High carbon stocks, tidal influence

### 2. **Forests** 🌲
- **Ecosystems:** Boreal, temperate, coastal rainforests
- **Standards:** VM0012, VM0042, IPCC AFOLU
- **Depth:** LFH layer + 0-30 cm mineral soil
- **Key Feature:** Separate organic and mineral horizons

### 3. **Grasslands** 🌾
- **Ecosystems:** Native prairies, rangelands, improved pastures
- **Standards:** VM0026, VM0032, Alberta TIER
- **Depth:** 0-50 cm
- **Key Feature:** Grazing management effects

### 4. **Wetlands / Peatlands** 🏞️
- **Ecosystems:** Bogs, fens, swamps, freshwater marshes
- **Standards:** VM0036, IPCC Wetlands
- **Depth:** 0-300 cm (very deep)
- **Key Feature:** Very low bulk density, high carbon stocks

### 5. **Arctic / Subarctic** ❄️
- **Ecosystems:** Tundra, permafrost wetlands, polygonal terrain
- **Standards:** VM0036 adapted, Permafrost Carbon Network
- **Depth:** Active layer (0-50 cm) + permafrost transition
- **Key Feature:** Permafrost, active layer dynamics

---

## ⭐ Key Features

### Multi-Ecosystem Support
✅ **Ecosystem-specific parameters** - Bulk density, SOC ranges, depth intervals, strata definitions
✅ **Dynamic loading** - Select ecosystem type in config, parameters load automatically
✅ **Easy extensibility** - Add new ecosystems by creating parameter files

### Composite Sampling Toggle
✅ **Enable/disable** - `COMPOSITE_SAMPLING = TRUE/FALSE`
✅ **Flexible methods** - Paired, unpaired, or mixed composite sampling
✅ **Seamless integration** - Same output structure regardless of mode

### Modular Design
✅ **Optional components** - Enable/disable flux calculations, mapping, Bayesian analysis
✅ **Conditional execution** - Workflow adapts based on configuration
✅ **Independent modules** - Run individual scripts or entire workflow

### Standards Compliance
✅ **VM0033, VM0012, VM0026, VM0036** - Methodology-specific calculations
✅ **IPCC guidelines** - Tier 3 approach with site-specific data
✅ **ICVCM Core Carbon Principles** - Automated CCP compliance assessment
✅ **ORRAA High Quality Blue Carbon** - Best practice standards
✅ **Automated checks** - Compliance validation and recommendations

### Comprehensive Reporting
✅ **HTML verification packages** - Submit-ready documentation
✅ **Standards compliance reports** - Automated assessment against 4+ standards
✅ **Excel exports** - Formatted tables for stakeholders
✅ **GIS-ready outputs** - Shapefiles and rasters

---

## 🚀 Quick Start

### Prerequisites

1. **R** (≥ 4.0.0)
2. **Required packages:** Install via `00a_install_packages_v2.R`
3. **Input data:** Core locations and sample data (see templates)

### Basic Usage (5 Steps)

```r
# 1. Configure your project
# Edit config.R:
ECOSYSTEM_TYPE <- "coastal_blue_carbon"  # or "forests", "grasslands", etc.
COMPOSITE_SAMPLING <- TRUE               # or FALSE for individual samples
PROJECT_NAME <- "My_Carbon_Project_2025"

# 2. Run the workflow
source("run_workflow.R")

# 3. Review outputs
browseURL("outputs/reports/comprehensive_standards_report.html")

# 4. Check MMRV package
browseURL("outputs/mmrv_reports/vm0033_verification_package.html")

# 5. Examine carbon stocks
read.csv("outputs/carbon_stocks/carbon_stocks_by_stratum_*.csv")
```

---

## ⚙️ Configuration

### Main Configuration File: `config.R`

#### Ecosystem Selection

```r
# Select your ecosystem type
ECOSYSTEM_TYPE <- "coastal_blue_carbon"

# Options:
#   "coastal_blue_carbon"
#   "forests"
#   "grasslands"
#   "wetlands_peatlands"
#   "arctic_subarctic"
```

When you set `ECOSYSTEM_TYPE`, the workflow automatically loads ecosystem-specific parameters from:
```
ecosystems/coastal_blue_carbon_params.R
ecosystems/forests_params.R
ecosystems/grasslands_params.R
ecosystems/wetlands_peatlands_params.R
ecosystems/arctic_subarctic_params.R
```

#### Composite Sampling Toggle

```r
# Enable/disable composite sampling
COMPOSITE_SAMPLING <- TRUE  # or FALSE

# When TRUE:
#   - Subsamples are combined into composite samples
#   - Uses existing composite sampling pipeline
#   - Choose method: "paired", "unpaired", "mixed"

# When FALSE:
#   - Each sample processed individually
#   - Same output structure maintained
#   - Useful for high-resolution spatial analysis
```

**Effect on workflow:**
- **Data preparation:** Aggregates or keeps samples separate
- **Depth harmonization:** Applied to composites or individuals
- **Spatial predictions:** Same methods, different input resolution
- **Outputs:** Labeled with `_composite` or `_individual` suffix

#### Optional Modules

```r
# Enable/disable optional components
ENABLE_FLUX_CALCULATIONS <- TRUE      # GHG flux calculations
ENABLE_MAPPING <- TRUE                # Spatial kriging and RF predictions
ENABLE_INVENTORY <- TRUE              # Detailed inventory outputs
ENABLE_REMOTE_SENSING <- FALSE        # Requires GEE covariates
ENABLE_BAYESIAN <- FALSE              # Requires prior maps
ENABLE_TEMPORAL_ANALYSIS <- FALSE     # Multi-year comparisons
ENABLE_UNCERTAINTY_ANALYSIS <- TRUE   # Bootstrap and CV
```

### Ecosystem-Specific Parameters

Each ecosystem has its own parameter file in `ecosystems/` directory:

**Example: `ecosystems/grasslands_params.R`**

```r
# Stratification
VALID_STRATA <- c(
  "Native Prairie",
  "Improved Pasture",
  "Degraded Grassland"
)

# Depth configuration
DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 15, 30),
  depth_bottom = c(15, 30, 50),
  depth_midpoint = c(7.5, 22.5, 40),
  thickness_cm = c(15, 15, 20)
)

# Bulk density defaults (g/cm³)
BD_DEFAULTS <- list(
  "Native Prairie" = 1.1,
  "Improved Pasture" = 1.2,
  "Degraded Grassland" = 1.3
)

# SOC ranges (g/kg)
SOC_MIN <- 0
SOC_MAX <- 200

# Standards compliance
VM0026_MIN_PLOTS <- 4
VM0026_TARGET_PRECISION <- 20  # percent
```

---

## 🗺️ Workflow Structure

### Overview

The workflow consists of **7 parts** with **17+ modules**:

```
PART 0: Setup
├── 00a: Install packages
├── 00b: Setup directories
└── 00c: Bayesian priors (optional)

PART 1: Data Ingestion
├── 01: Data preparation
└── 02: Exploratory analysis (optional)

PART 2: Depth Harmonization
└── 03: Equal-area spline harmonization

PART 3: Spatial Predictions
├── 04: Kriging predictions (optional)
└── 05: Random Forest predictions (optional)

PART 4: Bayesian Analysis (optional)
└── 06c: Bayesian posterior estimation

PART 5: Carbon Stock Calculation
└── 06: Aggregate stocks by stratum

PART 6: Reporting
├── 07: MMRV verification package
└── 07b: Comprehensive standards report

PART 7: Temporal Analysis (optional)
├── 08: Temporal harmonization
├── 09: Temporal change detection
└── 10: Final verification
```

### Module Execution Logic

The master script (`run_workflow.R`) determines which modules to run based on:

1. **Configuration settings** (`ENABLE_*` flags)
2. **Ecosystem type** (some modules ecosystem-specific)
3. **Data availability** (skips if inputs missing)
4. **Error handling** (continues on non-critical failures)

---

## ▶️ How to Run

### Option 1: Master Workflow (Recommended)

Run the entire workflow end-to-end:

```r
source("run_workflow.R")
```

The master script will:
- ✅ Load configuration
- ✅ Validate ecosystem parameters
- ✅ Create output directories
- ✅ Execute modules in order
- ✅ Handle errors gracefully
- ✅ Generate comprehensive logs
- ✅ Create summary report

### Option 2: Individual Modules

Run specific modules manually:

```r
# Load configuration first
source("config.R")

# Run individual modules
source("01_data_prep_bluecarbon.R")
source("03_depth_harmonization_bluecarbon.R")
source("06_carbon_stock_calculation_bluecarbon.R")
```

### Option 3: Command Line

```bash
Rscript run_workflow.R
```

---

## ➕ Adding New Ecosystems

You can easily add support for new ecosystem types:

### Step 1: Create Parameter File

Create a new file in `ecosystems/` directory:

```r
# ecosystems/my_new_ecosystem_params.R

ECOSYSTEM_NAME <- "My New Ecosystem"
ECOSYSTEM_DESCRIPTION <- "Description of the ecosystem"

# Required parameters
VALID_STRATA <- c("Stratum1", "Stratum2", "Stratum3")

DEPTH_INTERVALS <- data.frame(
  depth_top = c(0, 20),
  depth_bottom = c(20, 40),
  depth_midpoint = c(10, 30),
  thickness_cm = c(20, 20)
)

STANDARD_DEPTHS <- c(10, 30)
MAX_CORE_DEPTH <- 40

BD_DEFAULTS <- list(
  "Stratum1" = 1.0,
  "Stratum2" = 1.1,
  "Stratum3" = 1.2
)

SOC_MIN <- 0
SOC_MAX <- 300

# Standards compliance
VM0033_MIN_CORES <- 3
VM0033_TARGET_PRECISION <- 20
VM0033_CV_THRESHOLD <- 30

# Emission factors (optional)
CH4_EMISSION_FACTORS <- list(...)
N2O_EMISSION_FACTORS <- list(...)
```

### Step 2: Update Configuration

In `config.R`, set:

```r
ECOSYSTEM_TYPE <- "my_new_ecosystem"
```

### Step 3: Run Workflow

```r
source("run_workflow.R")
```

The workflow will automatically:
- Load your custom parameters
- Validate the configuration
- Adapt calculations to your ecosystem
- Generate ecosystem-specific outputs

### Required Parameters

At minimum, define:
- `ECOSYSTEM_NAME` - Display name
- `VALID_STRATA` - Valid stratum names
- `DEPTH_INTERVALS` - Depth layer specifications
- `STANDARD_DEPTHS` - Depth midpoints for harmonization
- `BD_DEFAULTS` - Default bulk densities by stratum
- `SOC_MIN` / `SOC_MAX` - SOC valid ranges
- Standards compliance thresholds

---

## 📁 Output Structure

```
project_root/
├── config.R                          # Main configuration
├── run_workflow.R                    # Master script
├── ecosystems/                       # Ecosystem parameters
│   ├── coastal_blue_carbon_params.R
│   ├── forests_params.R
│   ├── grasslands_params.R
│   ├── wetlands_peatlands_params.R
│   └── arctic_subarctic_params.R
├── utils/
│   └── mmrv_utils.R                  # Utility functions
├── data_raw/                         # Input data
│   ├── core_samples.csv
│   └── core_locations.csv
├── data_processed/                   # Intermediate data
│   ├── cores_clean_*.rds
│   └── cores_harmonized_*.rds
├── outputs/
│   ├── carbon_stocks/                # **Main results**
│   │   ├── carbon_stocks_by_stratum_*.csv
│   │   └── carbon_stocks_conservative_*.csv
│   ├── predictions/                  # Spatial predictions
│   │   ├── rf/
│   │   ├── kriging/
│   │   └── posterior/
│   ├── reports/                      # **Standards reports**
│   │   ├── comprehensive_standards_report.html
│   │   └── standards_compliance_summary.csv
│   ├── mmrv_reports/                 # **Verification packages**
│   │   ├── vm0033_verification_package.html
│   │   └── vm0033_summary_tables.xlsx
│   └── maps/                         # Spatial outputs
├── diagnostics/                      # QA/QC and diagnostics
│   ├── data_prep/
│   ├── qaqc/
│   ├── harmonization/
│   └── crossvalidation/
└── logs/                             # Execution logs
    └── workflow_*.log
```

### Key Outputs

| File | Description |
|------|-------------|
| `carbon_stocks_by_stratum_*.csv` | Mean carbon stocks by stratum (Mg C/ha) |
| `carbon_stocks_conservative_*.csv` | Conservative estimates (95% CI lower bound) |
| `comprehensive_standards_report.html` | Standards compliance assessment |
| `vm0033_verification_package.html` | MMRV verification documentation |
| `workflow_summary_*.txt` | Execution summary |

---

## 🏆 ICVCM Core Carbon Principles (CCP) Compliance

**NEW in Version 2.1:** Automated assessment against the **ICVCM Core Carbon Principles**, the global quality benchmark for high-integrity carbon credits.

### What is ICVCM CCP?

The **Integrity Council for the Voluntary Carbon Market (ICVCM)** established the **Core Carbon Principles (CCPs)** as a global quality standard. CCP-labeled carbon credits are recognized worldwide as meeting rigorous standards for:

- **Environmental integrity** - Real, measurable, permanent emission reductions/removals
- **Sustainable development** - Positive impacts on communities and ecosystems
- **Transparency** - Full disclosure of project information
- **Robust governance** - Independent verification and tracking

### The 10 Core Carbon Principles

1. **CCP1: Effective Governance** - Program has effective governance structure
2. **CCP2: Tracking** - Emission reductions tracked toward mitigation goals
3. **CCP3: Transparency** - All relevant information disclosed
4. **CCP4: Robust Validation/Verification** - Independent third-party assessment
5. **CCP5: Additionality** - Activity goes beyond business-as-usual
6. **CCP6: Permanence** - Permanent emission reductions or removals
7. **CCP7: Robust Quantification** - Conservative, scientifically robust methods
8. **CCP8: No Net Harm** - No violation of laws or negative impacts
9. **CCP9: Sustainable Development Benefits** - Net positive impacts on SDGs
10. **CCP10: Net-Zero Contribution** - Consistent with net-zero pathways

### How the Workflow Assesses CCP Compliance

The workflow provides **automated assessment** for technical principles:

✅ **CCP1-CCP4** (Program-level) - Checks if using CCP-approved programs (Verra, Gold Standard, etc.)
✅ **CCP5** (Additionality) - Verifies temporal analysis and baseline documentation
✅ **CCP6** (Permanence) - Assesses ecosystem-specific reversal risks and monitoring
✅ **CCP7** (Quantification) - Confirms conservative approach, uncertainty analysis, cross-validation
📋 **CCP8** (No Harm) - Manual review required (EIA, FPIC, legal compliance)
📋 **CCP9** (SD Benefits) - Manual review required (SDG mapping, co-benefits)
✅ **CCP10** (Net-Zero) - Classifies activity type and Paris Agreement alignment

### Enable ICVCM Assessment

In `config.R`:

```r
ENABLE_ICVCM_CCP_ASSESSMENT <- TRUE
```

Run workflow:
```r
source("run_workflow.R")
```

### Outputs

Assessment generates three key reports in `outputs/reports/`:

1. **icvcm_ccp_scorecard.csv** - Complete assessment of all 10 principles
2. **icvcm_gap_analysis.csv** - Identifies principles requiring attention
3. **icvcm_action_plan.csv** - Prioritized actions with timelines

### Interpreting Results

| Status | Meaning |
|--------|---------|
| ✓ PASS | Principle met or strong alignment |
| ◐ PARTIAL | Partially compliant, improvements needed |
| ⚠ REVIEW | Requires attention or additional work |
| 📋 MANUAL REVIEW | Requires external documentation |
| ✗ FAIL | Not compliant - critical action needed |

**Overall Score:**
- **≥80%** - Well-positioned for CCP compliance
- **60-79%** - Partial alignment, address gaps
- **<60%** - Significant work needed

### Detailed Guide

For complete documentation, see [ICVCM_CCP_COMPLIANCE_GUIDE.md](ICVCM_CCP_COMPLIANCE_GUIDE.md)

---

## 🔧 Troubleshooting

### Common Issues

#### 1. "Ecosystem configuration file not found"

**Solution:** Check that `ECOSYSTEM_TYPE` matches a parameter file in `ecosystems/`:

```r
# config.R
ECOSYSTEM_TYPE <- "coastal_blue_carbon"  # Must match filename

# Requires:
# ecosystems/coastal_blue_carbon_params.R
```

#### 2. "Missing required parameter"

**Solution:** Ensure your ecosystem parameter file defines all required parameters:

```r
# Required in all ecosystem param files:
VALID_STRATA
DEPTH_INTERVALS
STANDARD_DEPTHS
BD_DEFAULTS
SOC_MIN
SOC_MAX
VM0033_MIN_CORES
VM0033_TARGET_PRECISION
```

#### 3. Composite sampling not working

**Solution:** Check data structure:

```r
# For composite sampling, data needs:
# - Multiple subsamples per core_id and depth
# - core_type column (optional)

# If COMPOSITE_SAMPLING = FALSE, each row is treated independently
```

#### 4. Module fails but workflow continues

This is intentional! Non-critical modules (e.g., mapping, Bayesian) will skip on error.

**Check logs:**
```r
# logs/workflow_*.log
# Look for WARNING or ERROR entries
```

---

## 🔮 Future Enhancements

Planned features for future versions:

- [ ] **Bidirectional GIS integration** - Direct read/write from GIS databases
- [ ] **Real-time monitoring dashboards** - Shiny app for live data
- [ ] **Carbon registry integration** - Direct upload to Verra, Gold Standard
- [ ] **Machine learning enhancements** - Deep learning for spatial predictions
- [ ] **Multi-core parallel processing** - Faster execution for large datasets
- [ ] **Cloud deployment** - AWS/Azure compatibility
- [ ] **Additional ecosystems** - Croplands, agroforestry, urban soils

---

## 📚 Citation

If you use this workflow, please cite:

```bibtex
@software{generalized_mmrv_2025,
  title = {Generalized Multi-Ecosystem MMRV Workflow},
  author = {North Star Labs},
  year = {2025},
  version = {2.0},
  url = {https://github.com/NorthStarLabs/CompSoilSamplingWorkflow},
  note = {Multi-ecosystem carbon monitoring framework supporting VM0033, VM0012, VM0026, VM0036}
}
```

**Standards:**
- Verra VM0033 (Blue Carbon), VM0012 (Forests), VM0026 (Grasslands), VM0036 (Wetlands)
- IPCC 2013 Wetlands Supplement, 2019 Refinement
- ORRAA High Quality Blue Carbon Principles

---

## 📧 Support

**Issues:** Report bugs via GitHub Issues
**Documentation:** See individual script headers for module-specific docs
**Contact:** For collaboration or custom development

---

## 🙏 Acknowledgments

- **Verra** - VM0033, VM0012, VM0026, VM0036 methodologies
- **ISRIC** - SoilGrids global soil data
- **IPCC** - Emission factor databases and guidelines
- **R Community** - terra, sf, CAST, ithir packages
- **Canadian Blue Carbon Network** - Regional guidance

---

**Last Updated:** January 2025
**Workflow Version:** 2.0 (Generalized Multi-Ecosystem)
**License:** MIT (or specify your license)

---

*For original blue carbon-specific documentation, see `README.md`*
