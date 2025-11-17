# Implementation Guide for Conservation Practitioners
## Blue Carbon MMRV Workflow - From Field to Verification

**Target Audience:** Conservation practitioners, carbon project developers, restoration ecologists
**Prerequisite Knowledge:** Basic understanding of soil sampling and GIS
**Time Required:** 2-5 days for complete workflow execution (excluding field work)

---

## Quick Start Checklist

### Phase 1: Preparation (Before Field Work)
- [ ] Install R (version 4.0+) and RStudio
- [ ] Run `source("00a_install_packages_v2.R")` to install dependencies
- [ ] Run `source("00b_setup_directories.R")` to create folder structure
- [ ] Edit `blue_carbon_config.R` with your project details
- [ ] Plan sampling design: How many cores per stratum? (VM0033: minimum 3)
- [ ] Review `data_raw/README_DATA_STRUCTURE.md` for required data format

### Phase 2: Field Data Collection
- [ ] Collect soil cores (minimum 100 cm depth for VM0033)
- [ ] Record GPS coordinates (WGS84, decimal degrees)
- [ ] Photograph each core and sampling location
- [ ] Subdivide cores into depth increments (VM0033: 0-15, 15-30, 30-50, 50-100 cm)
- [ ] Label samples clearly (core_id + depth)

### Phase 3: Laboratory Analysis
- [ ] Measure bulk density for all depth increments (critical for accuracy!)
- [ ] Analyze soil organic carbon (SOC) concentration
- [ ] Record all measurements with unique sample IDs
- [ ] QA/QC: Re-run 10% of samples for validation

### Phase 4: Data Entry & Workflow Execution
- [ ] Create `core_locations.csv` from GPS data
- [ ] Create `core_samples.csv` from lab results
- [ ] Run validation tests: `source("tests/test_workflow_validation.R")`
- [ ] Execute workflow Modules 01-07 in sequence
- [ ] Review all diagnostic outputs and plots

### Phase 5: Verification Package Preparation
- [ ] Review `comprehensive_standards_report.html`
- [ ] Address HIGH priority recommendations
- [ ] Compile all outputs, maps, and QA/QC logs
- [ ] Submit to third-party verifier (if required for carbon credits)

---

## Detailed Implementation Steps

### Step 1: Software Installation (1-2 hours)

#### 1.1 Install R and RStudio

**Option A: Desktop Installation (Recommended for Beginners)**
1. Download R from: https://cloud.r-project.org/
2. Download RStudio from: https://posit.co/download/rstudio-desktop/
3. Install both programs (accept default settings)

**Option B: Use RStudio Cloud (No Installation Required)**
1. Sign up for free account: https://posit.cloud/
2. Upload workflow folder to your workspace
3. Run installation scripts in cloud environment

#### 1.2 Install R Packages

**Navigate to workflow directory in RStudio:**
```r
setwd("/path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon")

# Install all required packages (10-30 minutes)
source("00a_install_packages_v2.R")
```

**Expected Output:**
```
Required packages: 15/15 installed (100%)
Optional packages: 8/10 installed (80%)
✓✓✓ SUCCESS! All required packages installed.
```

**Troubleshooting:**
- If installation fails, check `logs/package_install_*.csv` for details
- For spatial packages (sf, terra), you may need system libraries:
  - **Mac:** `brew install gdal proj geos`
  - **Ubuntu/Debian:** `sudo apt-get install gdal-bin libgdal-dev libproj-dev`
  - **Windows:** Packages usually install without issues

#### 1.3 Setup Project Structure

```r
# Create all required directories
source("00b_setup_directories.R")
```

**Expected Output:**
```
Directory structure created:
✓ data_raw/
✓ data_processed/
✓ outputs/
✓ diagnostics/
✓ logs/
```

---

### Step 2: Project Configuration (30 minutes)

#### 2.1 Edit Configuration File

Open `blue_carbon_config.R` in RStudio and customize:

```r
# === PROJECT METADATA ===
PROJECT_NAME <- "YOUR_PROJECT_NAME_HERE"  # e.g., "Boundary Bay Restoration"
PROJECT_LOCATION <- "YOUR_LOCATION"  # e.g., "BC Coast, Canada"
PROJECT_SCENARIO <- "PROJECT"  # or "BASELINE", "CONTROL"
MONITORING_YEAR <- 2024  # Year of data collection

# === ECOSYSTEM STRATIFICATION ===
VALID_STRATA <- c(
  "Upper Marsh",
  "Mid Marsh",
  "Lower Marsh",
  "Underwater Vegetation",
  "Open Water"
)

# Update stratum names to match YOUR site:
# Example for a seagrass project:
VALID_STRATA <- c(
  "Dense Seagrass",
  "Patchy Seagrass",
  "Unvegetated Sediment"
)
```

#### 2.2 Set QA/QC Thresholds

**Adjust based on your ecosystem type:**

```r
# Default thresholds (suitable for temperate coastal marshes)
QC_SOC_MIN_G_KG <- 0
QC_SOC_MAX_G_KG <- 500

QC_BD_MIN_G_CM3 <- 0.1
QC_BD_MAX_G_CM3 <- 3.0

# For mangroves (typically higher SOC):
QC_SOC_MAX_G_KG <- 600

# For mineral-dominated systems (typically higher BD):
QC_BD_MAX_G_CM3 <- 2.0
```

#### 2.3 Set VM0033 Compliance Parameters

```r
# VM0033 Requirements (do not change unless using different standard)
VM0033_MIN_CORES <- 3  # Minimum cores per stratum
VM0033_TARGET_PRECISION <- 20  # Target 20% relative error at 95% CI
VM0033_CONFIDENCE_LEVEL <- 0.95  # 95% confidence interval
```

---

### Step 3: Field Sampling Design (Before Field Work)

#### 3.1 Determine Sample Size

**Use the built-in calculator:**

```r
source("blue_carbon_config.R")

# Calculate required sample size
z <- 1.96  # 95% CI
cv <- 30  # Assume 30% coefficient of variation (conservative)
target_precision <- 20  # 20% target (VM0033)

n_required <- ceiling((z * cv / target_precision)^2)
n_final <- max(n_required, 3)  # VM0033 minimum

cat(sprintf("Required sample size: %d cores per stratum\n", n_final))
# Expected output: ~9 cores per stratum for 30% CV
```

**Recommendations:**
- **Minimum:** 3 cores per stratum (VM0033 requirement)
- **Good:** 5-10 cores per stratum (typical projects)
- **Excellent:** 15+ cores per stratum (high-value carbon projects)

#### 3.2 Stratification Strategy

**Stratify by:**
1. **Vegetation type** (most important for blue carbon)
   - Saltmarsh species (Salicornia, Spartina, Distichlis, etc.)
   - Seagrass species (Zostera, Phyllospadix, Thalassia, etc.)
   - Mangrove species (Rhizophora, Avicennia, etc.)

2. **Tidal regime**
   - Upper marsh (infrequent flooding)
   - Mid marsh (regular inundation)
   - Lower marsh (daily tides)

3. **Restoration status** (for additionality projects)
   - Reference (natural, healthy)
   - Restored (project area)
   - Degraded (pre-restoration baseline)

**Example Stratification:**
```
Stratum 1: "Restored Upper Marsh" (5 cores)
Stratum 2: "Restored Mid Marsh" (10 cores - highest C stocks)
Stratum 3: "Restored Lower Marsh" (8 cores)
Stratum 4: "Degraded Control" (5 cores - for additionality)
```

#### 3.3 Spatial Sampling Design

**Option A: Stratified Random Sampling (Recommended)**
```r
# Use GEE script: BLUECARBONMANUALSTRATIFICATIONSAMPLINGTOOL.js
# 1. Upload stratum polygons to Google Earth Engine
# 2. Generate random points within each stratum
# 3. Export GPS coordinates for field navigation
```

**Option B: Systematic Grid**
```r
# Sample at regular intervals (e.g., every 50 m)
# Ensures spatial coverage but may miss rare habitats
```

**Option C: Targeted Sampling**
```r
# Expert-selected locations representing typical conditions
# Faster but potentially biased
```

---

### Step 4: Field Data Collection (Variable Duration)

#### 4.1 Equipment Needed

**Essential:**
- [ ] Soil corer (gouge auger, Russian peat corer, or vibracorer)
- [ ] GPS unit (±5 m accuracy minimum)
- [ ] Camera for photo documentation
- [ ] Core liners or sample bags
- [ ] Field notebook and waterproof pen
- [ ] Cooler with ice (for sample transport)

**Optional but Recommended:**
- [ ] Handheld pH meter
- [ ] Redox potential (Eh) probe
- [ ] Moisture meter
- [ ] Field scale for bulk density

#### 4.2 Core Collection Protocol

**For each sampling location:**

1. **Record GPS coordinates:**
   - Use WGS84 decimal degrees (not UTM or degrees-minutes-seconds)
   - Record at core location (not starting position)
   - Example: longitude = -123.5234, latitude = 49.2145

2. **Photograph site:**
   - Wide view showing vegetation
   - Close-up of surface (before coring)
   - Extracted core in sections

3. **Extract core:**
   - Insert corer to 100 cm depth minimum (VM0033 requirement)
   - Extract carefully to minimize compaction/expansion
   - Measure actual recovery depth (may differ from insertion depth)

4. **Subdivide core:**
   - **High-resolution option:** 5 cm increments (0-5, 5-10, 10-15, etc.)
   - **VM0033 minimum:** 0-15, 15-30, 30-50, 50-100 cm
   - Use clean tools between depths to avoid contamination

5. **Label samples:**
   - Format: `CORE_ID_DEPTH` (e.g., `CORE_001_0-15cm`)
   - Include on bag/container AND in field notes

6. **Record metadata:**
```
Core ID: CORE_001
Location: -123.5234, 49.2145
Stratum: Mid Marsh
Dominant vegetation: Salicornia pacifica
Tidal position: ~1.8 m above MLLW
Date: 2024-06-15
Collector: John Smith
Notes: Standing water present, typical density
```

#### 4.3 Bulk Density Sampling (CRITICAL)

**Why it matters:** Bulk density is required to convert SOC concentration to carbon stocks. Without it, accuracy drops significantly.

**Method 1: Known-volume core (Preferred)**
```
1. Use corer with known internal diameter (e.g., 5 cm)
2. Extract known length (e.g., 10 cm)
3. Calculate volume: V = π × r² × h
4. Weigh wet sample
5. Dry at 105°C for 24 hours
6. Weigh dry sample
7. Bulk density = dry mass (g) / volume (cm³)
```

**Method 2: Clod method**
```
1. Extract intact clod of soil
2. Measure volume by water displacement
3. Dry and weigh
4. BD = dry mass / volume
```

**Method 3: Use workflow defaults (Last Resort)**
```r
# If BD measurements are unavailable, workflow uses stratum defaults
# Example: Mid Marsh = 1.0 g/cm³
# WARNING: Increases uncertainty by ~15-30%
```

---

### Step 5: Laboratory Analysis (1-2 weeks)

#### 5.1 Sample Preparation

1. **Air dry** samples or dry at 60°C (do not exceed 105°C before SOC analysis)
2. **Homogenize:** Grind and sieve to <2 mm
3. **Subsample:** Take representative subsample for SOC analysis
4. **Remove roots:** Pick out live roots (>2 mm diameter)
5. **Document:** Photograph processed samples

#### 5.2 SOC Analysis Methods

**Method 1: Dry Combustion (Gold Standard)**
- Equipment: CHN elemental analyzer
- Precision: ±0.1% organic carbon
- Cost: $15-30 per sample
- **Best for:** VM0033 verification (IPCC Tier 2/3)

**Method 2: Loss on Ignition (LOI) with Walkley-Black Correction**
- Equipment: Muffle furnace
- Precision: ±0.5-1% organic carbon
- Cost: $5-10 per sample
- **Best for:** Budget-conscious projects, rapid screening
- **Note:** Requires site-specific calibration curve (LOI vs. dry combustion)

**Method 3: Mid-IR Spectroscopy (Rapid Method)**
- Equipment: FTIR or VisNIR spectrometer
- Precision: ±1-2% organic carbon (after calibration)
- Cost: $2-5 per sample (after instrument purchase)
- **Best for:** Large-scale projects (>500 samples)
- **Note:** Requires 50+ calibration samples analyzed by dry combustion

**Workflow accepts all methods** - document which method used in `core_samples.csv` column `analytical_method`

#### 5.3 Quality Control

**Duplicate Analysis:**
- Re-run 10% of samples randomly selected
- Calculate coefficient of variation (CV): CV = (SD / mean) × 100%
- Target: CV < 5% for SOC, CV < 10% for BD

**Reference Standards:**
- Run NIST or vendor standards every 20 samples
- Verify accuracy within ±5% of certified value

**Blank Samples:**
- Run 2-3 blanks per batch
- Verify contamination < detection limit

---

### Step 6: Data Entry & Validation (2-4 hours)

#### 6.1 Create core_locations.csv

**Use template:** `data_raw/core_locations_TEMPLATE.csv`

**Example:**
```csv
core_id,longitude,latitude,stratum,core_type,scenario_type,monitoring_year
SITE1_C01,-123.5234,49.2145,Mid Marsh,HR,PROJECT,2024
SITE1_C02,-123.5198,49.2167,Lower Marsh,Paired Composite,PROJECT,2024
SITE1_C03,-123.5301,49.2132,Upper Marsh,HR,PROJECT,2024
```

#### 6.2 Create core_samples.csv

**Use template:** `data_raw/core_samples_TEMPLATE.csv`

**Example:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bulk_density_g_cm3
SITE1_C01,0,15,85.3,0.82
SITE1_C01,15,30,68.2,1.05
SITE1_C01,30,50,48.7,1.21
SITE1_C01,50,100,34.2,1.33
SITE1_C02,0,15,78.1,0.89
...
```

#### 6.3 Validate Data Structure

```r
# Run comprehensive validation tests
source("tests/test_workflow_validation.R")

# Expected output:
# ✓ All tests passed (35/35)
# Workflow validation successful!
```

**If errors occur:**
- Review error messages in console
- Check column names (case-sensitive!)
- Verify core_id values match between files
- Check coordinate ranges (-180 to 180 lon, -90 to 90 lat)

---

### Step 7: Execute MMRV Workflow (2-6 hours)

#### 7.1 Module 01: Data Preparation & QA/QC

```r
source("01_data_prep_bluecarbon.R")
```

**What it does:**
- ✅ Validates coordinates and strata
- ✅ Calculates carbon stocks (kg/m²)
- ✅ Detects outliers (Tukey's fences)
- ✅ Flags duplicate locations
- ✅ Checks VM0033 compliance (sample size, precision)
- ✅ Generates QA/QC reports

**Review outputs:**
- `diagnostics/data_prep/core_summary_statistics.csv`
- `diagnostics/qaqc/data_quality_flags.csv`
- `diagnostics/data_prep/vm0033_compliance_report.csv`

**Action items:**
- If cores flagged as outliers, verify lab results
- If sample size insufficient, plan additional coring
- If precision >20%, increase sampling or accept higher uncertainty

**Expected Runtime:** 2-5 minutes

---

#### 7.2 Module 03: Depth Harmonization

```r
source("03_depth_harmonization_bluecarbon.R")
```

**What it does:**
- ✅ Harmonizes all cores to VM0033 standard depths (0-15, 15-30, 30-50, 50-100 cm)
- ✅ Uses equal-area spline (mass-preserving interpolation)
- ✅ Propagates uncertainty through harmonization
- ✅ Generates diagnostic plots for each stratum

**Review outputs:**
- `diagnostics/harmonization/harmonization_summary.csv`
- `diagnostics/harmonization/plots/` (depth profiles by stratum)
- `data_processed/cores_harmonized_bluecarbon.rds`

**Visual Check:**
- Open plots in `diagnostics/harmonization/plots/`
- Verify spline fits look reasonable (smooth, no artifacts)
- Check for any depth profiles with poor fits (reflagged in diagnostics)

**Expected Runtime:** 3-8 minutes

---

#### 7.3 Module 04 OR 05: Spatial Predictions

**Option A: Ordinary Kriging (Stratum-Specific)**
```r
source("04_kriging_predictions_bluecarbon.R")
```

**Use when:**
- You have 10+ cores per stratum
- Strata are large enough for variogram fitting
- You want conservative estimates

**Option B: Random Forest (Covariate-Driven)**
```r
source("05_rf_predictions_bluecarbon.R")
```

**Use when:**
- You have environmental covariates (from GEE)
- Cores are spatially clustered
- You want to incorporate vegetation indices, elevation, etc.

**Best Practice:** Run BOTH methods and compare (recommended for verification)

**What it does:**
- ✅ Fits spatial models to harmonized data
- ✅ Generates carbon stock prediction maps (GeoTIFF)
- ✅ Calculates uncertainty (standard error maps)
- ✅ Performs 3-fold cross-validation
- ✅ Flags areas of low reliability (Area of Applicability)

**Review outputs:**
- `outputs/predictions/kriging/` or `outputs/predictions/rf/`
- `diagnostics/crossvalidation/*_cv_results.csv`
- `diagnostics/spatial_cv_plots/`

**Visual Check:**
- Load prediction rasters in QGIS or ArcGIS
- Verify spatial patterns make ecological sense
- Check for artifacts or unrealistic values
- Review cross-validation R² (target: ≥0.5)

**Expected Runtime:** 15-45 minutes (depends on project size)

---

#### 7.4 Module 06: Carbon Stock Aggregation

```r
source("06_carbon_stock_calculation_bluecarbon.R")
```

**What it does:**
- ✅ Aggregates stocks across VM0033 depth intervals
- ✅ Calculates total 0-100 cm stocks
- ✅ Computes conservative estimates (lower 95% CI)
- ✅ Generates stratum-level statistics
- ✅ Compares kriging vs. RF methods (if both run)

**Review outputs:**
- `outputs/carbon_stocks/carbon_stocks_conservative_vm0033_*.csv`
- `outputs/carbon_stocks/carbon_stocks_by_stratum_*.csv`
- `outputs/carbon_stocks/carbon_stocks_method_comparison.csv`
- `outputs/carbon_stocks/maps/` (final stock maps)

**Key Metrics:**
```r
# Example output:
# Stratum: Mid Marsh
# Mean stock: 185.3 Mg C/ha
# Conservative stock: 152.7 Mg C/ha (VM0033 crediting basis)
# Total stock: 4,620 Mg C (across 25 hectares)
```

**Expected Runtime:** 2-5 minutes

---

#### 7.5 Module 07b: Comprehensive Standards Report

```r
source("07b_comprehensive_standards_report.R")
```

**What it does:**
- ✅ Automated compliance checking (VM0033, ORRAA, IPCC, Canadian standards)
- ✅ Generates actionable recommendations
- ✅ Creates HTML report with all figures
- ✅ Produces verification-ready CSV summaries

**Review outputs:**
- `outputs/reports/comprehensive_standards_report.html` ← **OPEN THIS IN WEB BROWSER**
- `outputs/reports/standards_compliance_summary.csv`
- `outputs/reports/recommendations_action_plan.csv`

**Action Items:**
- Review all **HIGH priority** recommendations
- Address failing compliance checks (if any)
- Document deviations from standards (if applicable)

**Expected Runtime:** 1-3 minutes

---

### Step 8: Verification Package Preparation (4-8 hours)

#### 8.1 Required Documents for VM0033 Verification

**Compile the following:**

1. **Comprehensive Standards Report**
   - `outputs/reports/comprehensive_standards_report.html`

2. **Carbon Stock Estimates**
   - `outputs/carbon_stocks/carbon_stocks_conservative_vm0033_*.csv`
   - Use **conservative** estimates for crediting

3. **QA/QC Documentation**
   - `diagnostics/qaqc/data_quality_flags.csv`
   - `diagnostics/qaqc/bd_transparency_report.csv`
   - `diagnostics/data_prep/vm0033_compliance_report.csv`

4. **Cross-Validation Results**
   - `diagnostics/crossvalidation/*_cv_results.csv`
   - Demonstrates model reliability

5. **Spatial Prediction Maps (GeoTIFF)**
   - `outputs/carbon_stocks/maps/carbon_stock_*_conservative.tif`
   - For third-party GIS verification

6. **Field & Lab Data**
   - `data_raw/core_locations.csv`
   - `data_raw/core_samples.csv`
   - Lab certificates (if available)
   - Field photos and notes

7. **Methodology Documentation**
   - `README.md` (workflow description)
   - `COMPREHENSIVE_MMRV_WORKFLOW_REVIEW.md` (scientific review)
   - `blue_carbon_config.R` (project configuration)

8. **Log Files**
   - `logs/*_*.log` (processing logs with timestamps)

#### 8.2 Verification Checklist

**Before submitting to verifier:**

- [ ] All HIGH priority recommendations addressed
- [ ] Cross-validation R² ≥ 0.5 (or documented why lower)
- [ ] Minimum 3 cores per stratum (VM0033)
- [ ] Bulk density measured (not defaults) for ≥80% of samples
- [ ] Conservative estimates used for crediting
- [ ] Spatial predictions validated in GIS
- [ ] No major QA/QC flags unresolved
- [ ] All data sources cited (SoilGrids, field data, literature)
- [ ] Methodology deviations documented (if any)

---

### Step 9: Temporal Monitoring (For Multi-Year Projects)

#### 9.1 Baseline vs. Project Scenario

**For additionality verification:**

```r
# Configure baseline scenario
MONITORING_YEAR <- 2020
PROJECT_SCENARIO <- "BASELINE"
source("01_data_prep_bluecarbon.R")
# ... run full workflow ...

# Configure project scenario (post-restoration)
MONITORING_YEAR <- 2024
PROJECT_SCENARIO <- "PROJECT"
source("01_data_prep_bluecarbon.R")
# ... run full workflow ...
```

#### 9.2 Change Detection (Module 09)

```r
source("09_additionality_temporal_analysis.R")

# Calculates:
# - Carbon stock change (PROJECT - BASELINE)
# - Emission reductions (Mg CO2e)
# - Statistical significance of change
```

#### 9.3 VM0033 Monitoring Frequency

**Requirement:** Verify carbon stocks every **5 years**

**Timeline Example:**
- **Year 0 (2024):** Baseline measurement (pre-restoration)
- **Year 1 (2025):** Project measurement (post-restoration)
- **Year 5 (2029):** 1st verification event
- **Year 10 (2034):** 2nd verification event
- **Year 15 (2039):** 3rd verification event

---

## Common Pitfalls & Solutions

### Pitfall 1: Insufficient Sample Size

**Problem:** Only 2 cores in one stratum (VM0033 requires 3)

**Solution:**
```r
# Workflow will flag this in Module 01 diagnostics
# Review: diagnostics/data_prep/vm0033_compliance_report.csv

# Action: Return to field and collect 1 additional core in that stratum
```

### Pitfall 2: Missing Bulk Density

**Problem:** Lab didn't measure BD for half the samples

**Solution:**
```r
# Workflow uses stratum defaults (but increases uncertainty)
# Better: Estimate BD from SOC using pedotransfer function

# Add to Module 01 (optional enhancement):
estimated_bd <- 1.0 / (1 + 0.6 * soc_percent)  # Adams (1973)
```

### Pitfall 3: Poor Cross-Validation Performance

**Problem:** Spatial predictions have R² < 0.3

**Diagnosis:**
```r
# Check: diagnostics/crossvalidation/*_cv_results.csv

# Common causes:
# 1. Insufficient cores (need 15+ for reliable kriging)
# 2. Cores all clustered (no spatial spread)
# 3. Missing environmental covariates (for RF)
# 4. High natural variability (wetlands are heterogeneous!)
```

**Solution:**
```r
# Option A: Collect more cores in poorly predicted areas
# Option B: Add GEE covariates (NDVI, TWI, elevation)
# Option C: Accept higher uncertainty (document in report)
# Option D: Use stratum means instead of spatial predictions
```

### Pitfall 4: Unrealistic SOC Values

**Problem:** One core has 800 g/kg SOC (likely data entry error)

**Solution:**
```r
# Workflow flags in QA/QC: diagnostics/qaqc/data_quality_flags.csv

# Check original lab report - common errors:
# - Typo: 80 g/kg entered as 800 g/kg
# - Units: Lab reported % organic matter (×10 higher than SOC)
# - Sample swap: High SOC sample mislabeled
```

---

## Frequently Asked Questions

### Q1: Can I use this workflow for seagrass meadows?

**A:** Yes! The workflow is designed for all blue carbon ecosystems:
- ✅ Saltmarshes
- ✅ Mangroves
- ✅ Seagrass meadows
- ✅ Tidal freshwater wetlands

**Customize:**
- Update `VALID_STRATA` with seagrass types (dense, patchy, unvegetated)
- Adjust `QC_SOC_MAX_G_KG` (seagrass typically lower than marshes: 20-80 g/kg)
- Use appropriate bulk density defaults: 0.4-1.0 g/cm³ for seagrass sediments

---

### Q2: How long does the full workflow take?

**A:** Total time depends on project size:

| Project Size | Modules 01-07 | Full Workflow + GEE |
|--------------|---------------|---------------------|
| Small (20 cores, 50 ha) | 30 minutes | 2-3 hours |
| Medium (50 cores, 500 ha) | 1 hour | 4-6 hours |
| Large (200 cores, 5000 ha) | 3-4 hours | 1-2 days |

**Does not include:**
- Field work (1-5 days)
- Lab analysis (1-2 weeks)
- Data entry (2-4 hours)

---

### Q3: Do I need Google Earth Engine?

**A:** Optional but recommended:

**Without GEE:**
- ✅ Kriging predictions work fine (Module 04)
- ✅ Basic VM0033 compliance met
- ❌ Cannot use Random Forest with covariates (Module 05)
- ❌ Cannot use Bayesian priors (Module 06c)

**With GEE:**
- ✅ Random Forest predictions (often more accurate)
- ✅ Bayesian uncertainty reduction
- ✅ Covariate-driven stratification

**Setup time:** 1-2 hours to learn GEE basics

---

### Q4: What if my cores don't reach 100 cm depth?

**A:** VM0033 requires 0-100 cm, but you have options:

**Option 1: Use available depth (document limitation)**
```r
# If all cores reach only 80 cm:
# - Report stocks for 0-80 cm
# - Document in verification report
# - May reduce creditable carbon (conservative)
```

**Option 2: Extrapolate to 100 cm (with caution)**
```r
# Workflow can extrapolate if cores reach ≥70 cm
# - Uses exponential decay model (common in wetlands)
# - Adds uncertainty flag
# - Requires justification in report
```

**Option 3: Return to field**
```r
# Recommended for high-value projects
# - Use longer corer or vibracoring equipment
# - Sample subset of locations to 100 cm
# - Use as reference for extrapolation
```

---

### Q5: Can I use this for mangroves?

**A:** Yes! Mangroves have some unique considerations:

**Adjust parameters:**
```r
# Mangrove-specific QC thresholds
QC_SOC_MAX_G_KG <- 600  # Mangroves can have very high SOC
QC_BD_MIN_G_CM3 <- 0.2  # Loose peat soils
QC_BD_MAX_G_CM3 <- 1.8  # Mineral-dominated sites

# Mangrove stratification examples:
VALID_STRATA <- c(
  "Landward Fringe (Avicennia)",
  "Mid Zone (Rhizophora)",
  "Seaward Fringe (Sonneratia)",
  "Cleared Mangrove (Degraded)"
)

# Depth intervals: VM0033 allows 0-100 cm OR site-specific
# Some mangroves have deep carbon (>1 m)
# Document if sampling beyond 100 cm
```

---

### Q6: How do I cite this workflow in publications?

**Suggested Citation:**
```
NorthStarLabs (2024). Blue Carbon Composite Sampling & MMRV Workflow
(Version 1.0). GitHub repository:
https://github.com/NorthStarLabs/CompSoilSamplingWorkflow_CoastalBlueCarbon

Methodology based on:
- VM0033 (Verra, 2020) for carbon crediting
- IPCC Wetlands Supplement (2013) for inventory methods
- ORRAA High Quality Blue Carbon Principles
```

**Key Methods to Cite:**
- Bishop et al. (1999) - Equal-area spline depth harmonization
- Meyer & Pebesma (2021) - Area of Applicability analysis
- Poggio et al. (2021) - SoilGrids 250m v2.0 (if used)

---

## Next Steps After Workflow Completion

### 1. Scientific Publication
- Draft manuscript using workflow outputs
- Include methods section (cite README.md)
- Submit to journals: *Estuaries and Coasts*, *Blue Carbon*, *Wetlands*

### 2. Carbon Credit Registration
- Submit verification package to Verra or Gold Standard
- Work with approved third-party verifier
- Await verification decision (6-12 months)

### 3. Adaptive Management
- Use carbon stock maps to prioritize restoration areas
- Monitor changes over time (Module 09)
- Adjust management based on observed carbon accumulation rates

### 4. Community Engagement
- Share results with stakeholders
- Create accessible summary reports
- Use maps for grant applications and education

---

## Support Resources

### Technical Support
- **Workflow Issues:** Review `logs/` directory and diagnostic outputs
- **R Errors:** Check `00a_install_packages_v2.R` installation log
- **GEE Errors:** Enable diagnostic mode in JavaScript scripts

### Scientific Support
- **VM0033 Methodology:** https://verra.org/methodologies/vm0033/
- **IPCC Wetlands Supplement:** https://www.ipcc-nggip.iges.or.jp/
- **ORRAA Blue Carbon:** https://www.oceanriskalliance.org/blue-carbon/

### Training & Workshops
- **Blue Carbon Initiative:** https://www.thebluecarboninitiative.org/
- **Coastal Carbon Network:** https://coastalcarbonnetwork.org/
- **Smithsonian MarineGEO:** https://marinegeo.github.io/seagrassdb/

---

## Change Log

**Version 1.0 (2025-11-17):**
- Initial implementation guide
- Covers workflow Modules 00-07
- Includes field sampling protocols
- VM0033-compliant procedures

**Planned Updates:**
- Video tutorials for each module
- Case studies from real projects
- Advanced spatial modeling techniques
- Integration with carbon registries

---

**Document Version:** 1.0
**Last Updated:** 2025-11-17
**Maintained By:** NorthStarLabs Blue Carbon Team
