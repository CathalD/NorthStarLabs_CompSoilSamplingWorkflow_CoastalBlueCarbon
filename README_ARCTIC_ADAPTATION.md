# 🧊 Arctic Permafrost Wetland Carbon Monitoring Workflow

**Adaptation of the Blue Carbon MMRV Workflow for Canadian Arctic and Subarctic Permafrost Ecosystems**

[![Permafrost](https://img.shields.io/badge/Ecosystem-Arctic%20Permafrost-blue)]()
[![VM0036 Adapted](https://img.shields.io/badge/VM0036-Adapted-brightgreen)]()
[![Canada](https://img.shields.io/badge/Region-Canadian%20Arctic-red)]()

---

## 📋 Table of Contents

- [Overview](#overview)
- [Arctic-Specific Adaptations](#arctic-specific-adaptations)
- [Target Ecosystems](#target-ecosystems)
- [Critical Permafrost Variables](#critical-permafrost-variables)
- [Modified Workflow](#modified-workflow)
- [Data Sources](#data-sources)
- [Field Protocols](#field-protocols)
- [Quick Start Guide](#quick-start-guide)
- [Key Differences from Coastal Workflow](#key-differences-from-coastal-workflow)
- [Verification Standards](#verification-standards)
- [Example Use Cases](#example-use-cases)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## 🎯 Overview

This workflow adapts the coastal blue carbon monitoring system for **Canadian Arctic and Subarctic permafrost wetlands**, enabling:

- **Permafrost carbon stock quantification** (active layer and permafrost zones)
- **Climate vulnerability assessment** (thaw trajectory modeling)
- **Temporal monitoring** (active layer deepening, thermokarst expansion)
- **MMRV-ready reporting** (adapted from VM0036 peatlands methodology)

### Target Region

**Canadian Arctic and Subarctic:**
- **Territories:** Northwest Territories, Nunavut, Yukon
- **Latitude Range:** 60°N to 83°N
- **Permafrost Zones:** Continuous, discontinuous, and sporadic permafrost
- **Climate:** Mean annual temperature <0°C

### Primary Use Cases

1. **Baseline carbon assessment** for intact permafrost peatlands
2. **Degradation monitoring** in thermokarst-affected areas
3. **Climate vulnerability quantification** (vulnerable carbon pools)
4. **Research support** for permafrost carbon science
5. **Policy/decision support** for Arctic land management

---

## ⚡ Arctic-Specific Adaptations

### Key Modifications from Coastal Workflow

| Aspect | Coastal Blue Carbon | Arctic Permafrost |
|--------|---------------------|-------------------|
| **Ecosystem Types** | Salt marshes, seagrass | Polygonal tundra, palsas, fens, thermokarst |
| **Max Core Depth** | 100 cm | 300 cm (permafrost zones) |
| **Depth Intervals** | Fixed VM0033 (0-15, 15-30, 30-50, 50-100 cm) | Variable by active layer depth (30-150 cm) |
| **Bulk Density Range** | 0.6-1.2 g/cm³ | 0.05-1.2 g/cm³ (very low for peat) |
| **SOC Range** | 0-500 g/kg | 0-800 g/kg (ancient permafrost carbon) |
| **Critical Variables** | Tidal inundation, salinity | Active layer depth, ground ice, permafrost table |
| **Temporal Focus** | Restoration trajectory | Permafrost thaw trajectory |
| **Scenarios** | Baseline vs. Project | Intact vs. Degrading vs. Thermokarst |
| **Climate Data** | Sea level, tides | Ground temperature, thaw degree days, snow |
| **Remote Sensing** | Water occurrence, NDVI | Active layer thickness, permafrost extent, snow duration |
| **Verification Standard** | VM0033 (coastal) | VM0036 adapted (peatlands) |
| **Sampling Season** | Year-round possible | July-August only (maximum thaw window) |

---

## 🌍 Target Ecosystems

### Stratum Definitions (Arctic)

The workflow recognizes **10 permafrost wetland strata** defined in `stratum_definitions_ARCTIC.csv`:

#### 1. **Polygonal Tundra - Wet Center**
- **Description:** Ice-wedge polygon centers with high water table
- **Carbon Stocks:** High (organic accumulation)
- **Bulk Density:** 0.15 g/cm³
- **Active Layer:** ~60 cm
- **Permafrost:** Intact
- **Key Features:** Sedge/moss vegetation, water-saturated

#### 2. **Polygonal Tundra - Dry Rim**
- **Description:** Elevated polygon rims with better drainage
- **Carbon Stocks:** Moderate
- **Bulk Density:** 0.20 g/cm³
- **Active Layer:** ~70 cm
- **Permafrost:** Intact
- **Key Features:** Mineral influence, better aeration

#### 3. **Palsa Peatland**
- **Description:** Permafrost peat mounds (elevated)
- **Carbon Stocks:** Very High (fibric peat)
- **Bulk Density:** 0.10 g/cm³
- **Active Layer:** ~40 cm (shallow due to elevation)
- **Permafrost:** Intact
- **Key Features:** Dry surface, low productivity

#### 4. **Thermokarst Fen**
- **Description:** Collapsed permafrost with wet, decomposed peat
- **Carbon Stocks:** High but vulnerable
- **Bulk Density:** 0.20 g/cm³
- **Active Layer:** ~100 cm (deep due to subsidence)
- **Permafrost:** Degrading
- **Key Features:** Waterlogged, rapid decomposition

#### 5. **Subarctic Fen**
- **Description:** Permafrost-free minerotrophic wetland
- **Carbon Stocks:** Moderate
- **Bulk Density:** 0.12 g/cm³
- **Active Layer:** ~150 cm (no permafrost)
- **Permafrost:** Absent
- **Key Features:** Groundwater influence, moderate pH

#### 6. **Tundra Pond Margin**
- **Description:** Emergent vegetation around thermokarst ponds
- **Carbon Stocks:** Variable
- **Bulk Density:** 0.18 g/cm³
- **Active Layer:** ~80 cm
- **Permafrost:** Degrading
- **Key Features:** Aquatic-terrestrial transition

#### 7. **Intact Permafrost Peatland**
- **Description:** Reference condition with stable permafrost
- **Carbon Stocks:** Very High
- **Bulk Density:** 0.12 g/cm³
- **Active Layer:** ~50 cm
- **Permafrost:** Intact
- **Key Features:** Undisturbed, deep organic layer

#### 8. **Degrading Permafrost Peatland**
- **Description:** Active permafrost thaw with subsidence
- **Carbon Stocks:** High but rapidly changing
- **Bulk Density:** 0.16 g/cm³ (compaction from thaw)
- **Active Layer:** ~120 cm (deepening)
- **Permafrost:** Degrading
- **Key Features:** Visible subsidence, altered hydrology

#### 9. **Polygon Center - Vegetated**
- **Description:** Low-center polygons with sedge/moss dominance
- **Carbon Stocks:** High
- **Bulk Density:** 0.14 g/cm³
- **Active Layer:** ~65 cm
- **Permafrost:** Intact
- **Key Features:** High primary productivity

#### 10. **Bare Mineral Tundra**
- **Description:** Exposed mineral soil with minimal organics
- **Carbon Stocks:** Very Low
- **Bulk Density:** 1.20 g/cm³
- **Active Layer:** ~90 cm
- **Permafrost:** Variable
- **Key Features:** Erosion, cryoturbation

---

## 🔬 Critical Permafrost Variables

### Required Field Measurements

All sampling sites must record these variables (defined in `blue_carbon_config.R`):

#### Permafrost-Specific:
1. **active_layer_depth_cm** - Measured thaw depth (frost probe) at end of season
2. **permafrost_table_depth_cm** - Depth to frozen layer
3. **ground_ice_content_pct** - Ground ice volume % (gravimetric method)
4. **thaw_settlement_cm** - Subsidence from ice melt

#### Soil Temperature:
5. **soil_temp_surface_C** - Surface soil temperature
6. **soil_temp_10cm_C** - 10 cm depth temperature
7. **soil_temp_50cm_C** - 50 cm depth temperature (if active layer allows)

#### Site Characterization:
8. **vegetation_type** - Sedge/moss/shrub dominance (%)
9. **microtopography_type** - Polygon/palsa/fen classification
10. **thermokarst_feature** - Type of thermokarst (pond/trough/slump/etc.)
11. **water_track_proximity_m** - Distance to nearest water track

#### Climate (if instrumented):
12. **mean_annual_temp_C** - Mean annual air temperature
13. **mean_annual_ground_temp_C** - Mean annual ground temperature (MAGT)
14. **thaw_degree_days** - Cumulative positive degree days
15. **freeze_degree_days** - Cumulative negative degree days
16. **snow_depth_cm** - Snow depth (affects ground insulation)
17. **snow_duration_days** - Days with snow cover

### Standard Core Variables

In addition to permafrost-specific variables, collect standard soil core data:

- **core_id** - Unique identifier
- **latitude, longitude** - WGS84 coordinates
- **stratum** - Ecosystem type (from 10 Arctic strata)
- **depth_top_cm, depth_bottom_cm** - Sample depth intervals
- **bulk_density_g_cm3** - Measured bulk density (thawed samples)
- **organic_carbon_pct** - Soil organic carbon %
- **scenario** - INTACT, BASELINE, DEGRADING, THERMOKARST, etc.

---

## 🔄 Modified Workflow

### Part 1: Sampling Design & Spatial Covariates (GEE)

**Script:** `ARCTIC_PERMAFROST_COVARIATES.js`

**Covariates Extracted:**
- **Climate:** Mean annual temperature, thaw degree days, freeze degree days
- **Permafrost:** Permafrost probability, active layer thickness (modeled)
- **Terrain:** Elevation, slope, aspect, TPI, TRI (for polygon/palsa detection)
- **Snow:** Snow occurrence %, snow duration (days)
- **Vegetation:** NDVI, EVI, NDWI, NDMI (summer only)
- **SAR:** VV, VH, moisture proxies (all-season)
- **Water:** Water occurrence, distance to water (thermokarst ponds)
- **Thermokarst:** Combined indicator (roughness + ice + water)
- **Microtopography:** Classification (0=center, 1=rim, 2=elevated)

**DEM Source:** ArcticDEM (2m resolution mosaic, resampled to 30m)

**Processing CRS:** EPSG:3573 (WGS 84 / North Pole LAEA Canada)

**Export:**
1. Full covariate stack (multi-band GeoTIFF)
2. Active layer thickness map
3. Permafrost probability map
4. Mean annual temperature map

Place in: `data_raw/gee_covariates/`

---

### Part 2: Core Analysis Workflow (R)

**Configuration:** `blue_carbon_config.R` (Arctic-adapted)

#### Module 01: Data Preparation

**Script:** `01_data_prep_bluecarbon.R`

**Modifications:**
- Load permafrost-specific variables
- Apply Arctic QC thresholds:
  - SOC: 0-800 g/kg (higher for permafrost)
  - Bulk density: 0.05-2.0 g/cm³ (lower for peat)
  - Active layer depth: 20-200 cm
  - Ground ice: 0-90% volume
- Apply ground ice correction to bulk density (if frozen samples)
- Flag samples by layer (active vs. permafrost)

**Ground Ice Correction:**
```r
# If BD measured on frozen samples
BD_thawed = (BD_frozen × (1 - ground_ice_fraction)) + (BD_ice × ground_ice_fraction)
# Where BD_ice = 0.92 g/cm³
```

**Output:** `data_processed/cores_clean_arctic.rds`

---

#### Module 02: Exploratory Analysis

**Script:** `02_exploratory_analysis_bluecarbon.R`

**Arctic-Specific Plots:**
- Active layer depth distribution by stratum
- Ground ice content by stratum
- SOC vs. active layer depth
- Permafrost vs. active layer carbon comparison

---

#### Module 03: Depth Harmonization

**Script:** `03_depth_harmonization_bluecarbon.R`

**CRITICAL Arctic Adaptations:**

1. **Variable Active Layer Depth:**
   - Harmonization depths adapt to site-specific active layer
   - If ALT < 70 cm: Use shallow depths (7.5, 15, 30 cm)
   - If ALT 70-100 cm: Use standard depths (7.5, 22.5, 40, 75 cm)
   - If ALT > 100 cm: Use extended depths (7.5, 22.5, 40, 75, 125 cm)

2. **No Interpolation Through Frozen Layer:**
   - Equal-area spline only applied within active layer
   - Permafrost samples (below active layer) reported separately
   - No interpolation across permafrost table boundary

3. **Temporal Variability:**
   - Active layer depth recorded for each sampling year
   - Depths harmonized relative to annual active layer
   - Inter-annual variability tracked

**Output:**
- `data_processed/cores_harmonized_arctic_active_layer.rds`
- `data_processed/cores_harmonized_arctic_permafrost.rds` (if sampled)

---

#### Module 05: Random Forest Spatial Prediction

**Script:** `05_raster_predictions_rf_bluecarbon.R`

**Arctic Covariate Importance (Expected):**
1. Active layer thickness (modeled) - **PRIMARY**
2. Mean annual temperature
3. Thaw degree days
4. Permafrost probability
5. Microtopography (TPI)
6. Water occurrence (thermokarst)
7. NDVI (vegetation biomass)
8. Snow duration
9. Elevation
10. Aspect (affects thaw rate)

**Separate Models:**
- Model 1: Active layer carbon stocks
- Model 2: Permafrost carbon stocks (if sampled)

**Area of Applicability (AOA):**
- Critical for Arctic due to extreme environmental gradients
- Only predict where covariates are within training range

---

#### Module 06: Carbon Stock Calculation

**Script:** `06_carbon_stock_calculation_bluecarbon.R`

**Arctic-Specific Calculations:**

**Active Layer Carbon Stock:**
```r
# Sum harmonized depths within active layer
C_active_layer = Σ(C_depth_i × thickness_i)
# Where depths are 0-15, 15-30, 30-50, 50-ALT cm
```

**Permafrost Carbon Stock (if sampled):**
```r
# Separately sum permafrost zone (below active layer)
C_permafrost = Σ(C_depth_i × thickness_i)
# Where depths are ALT-100, 100-150, 150-200, 200-300 cm
```

**Vulnerable Carbon Pool:**
```r
# Top 1m of permafrost (IPCC definition)
C_vulnerable = C_depth(ALT to ALT+100cm)
```

**Total Ecosystem Carbon:**
```r
C_total = C_active_layer + C_permafrost
# Reported separately in MMRV reports
```

---

#### Module 07: MMRV Reporting

**Script:** `07_mmrv_reporting_bluecarbon.R`

**Arctic-Specific Report Sections:**

1. **Carbon Pool Breakdown:**
   - Active layer carbon (0-ALT cm)
   - Transition zone carbon (ALT to ALT+50 cm)
   - Upper permafrost carbon (ALT+50 to ALT+150 cm)
   - Deep permafrost carbon (>ALT+150 cm, if sampled)

2. **Climate Vulnerability Metrics:**
   - Vulnerable carbon pool (top 1m of permafrost)
   - Active layer deepening rate (cm/year)
   - Permafrost thaw trajectory (projected)
   - Thermokarst expansion rate (%)
   - Comparison to CMIP6 projections

3. **Temporal Trends:**
   - Inter-annual active layer variability
   - Carbon loss trajectory (degrading sites)
   - Subsidence rates (thermokarst)

4. **Verification Standards Compliance:**
   - VM0036 (adapted) - Peatlands methodology
   - IPCC Wetlands Supplement
   - CALM protocols (active layer)
   - CCIN standards (Canadian cryosphere)
   - Arctic Council guidelines

**Output:** `outputs/mmrv_reports/arctic_permafrost_verification_package.html`

---

#### Module 07b: Standards Compliance

**Script:** `07b_comprehensive_standards_report.R`

**Arctic-Specific Checks:**

**VM0036 Adapted (Peatlands):**
- ✓ Minimum 3 cores per stratum
- ✓ Active layer depth measured at all sites
- ✓ Ground ice content recorded
- ✓ Separate active layer and permafrost pools
- ✓ Conservative 95% CI estimates
- ✓ Temporal monitoring (annual recommended for permafrost)

**CALM Protocols:**
- ✓ Frost probe methodology
- ✓ Late summer sampling (maximum thaw)
- ✓ Spatial variability assessment

**IPCC Tier 3:**
- ✓ Site-specific measurements
- ✓ Stratification by ecosystem type
- ✓ Uncertainty quantification
- ✓ Conservative approach for GHG accounting

---

### Part 3: Temporal Monitoring (Annual Recommended)

**Arctic Permafrost Requires More Frequent Monitoring:**

- **Annual monitoring** recommended (vs. 5-year for coastal)
- Tracks:
  - Active layer depth inter-annual variability
  - Permafrost thaw progression
  - Thermokarst expansion
  - Carbon pool changes

**Modules:**
- **08:** Temporal data harmonization
- **09:** Thaw trajectory analysis (replaces "additionality")
- **10:** Climate vulnerability verification

---

## 📊 Data Sources

### Canadian Government & Networks

**See:** `CANADIAN_ARCTIC_PERMAFROST_DATA_SOURCES.md` for comprehensive list

**Essential:**
1. **Natural Resources Canada (NRCan):** Permafrost maps, ground temperature
2. **PermafrostNet:** Canadian research network, monitoring sites
3. **CALM Network:** Active layer thickness data
4. **GTN-P:** Global permafrost temperature database
5. **CanSIS:** Northern soil profiles
6. **GSC:** Geological Survey of Canada permafrost distribution

**International:**
7. **Permafrost Pathways (Woodwell):** Flux towers, MRV framework
8. **NASA CMS:** Remote sensing tools (SMAP, MODIS, Landsat)
9. **ESA Permafrost_CCI:** Active layer thickness, ground temperature
10. **IIASA:** Permafrost carbon models, CMIP6 projections

**Literature Databases:**
11. **NTED:** Northern Terrestrial Ecosystem Database (ORNL)
12. **IPA:** International Permafrost Association maps
13. **AMAP:** Arctic Monitoring and Assessment Programme

---

## 🔬 Field Protocols

### Timing

**CRITICAL:** Sampling MUST occur during **maximum thaw depth** (late summer)

**Recommended Window:**
- **Late July to Mid-August** (varies by latitude/region)
- Coordinate with local CALM network for optimal timing
- Active layer depth measured same day as coring

---

### Active Layer Measurement

**Method:** CALM Frost Probe Protocol

**Equipment:**
- Graduated frost probe (steel rod, 1.5-2m length)
- Marker/flag for probe location
- GPS for coordinates

**Procedure:**
1. Insert probe vertically until resistance (frozen layer)
2. Record depth to nearest cm
3. Repeat at multiple points (121-point CALM grid if spatial variability assessment)
4. Average for site-level active layer depth

**QC:**
- Avoid recent disturbance (footprints, vehicle tracks)
- Avoid organic mat "bounce" (firm pressure)
- Record any anomalies (ice lenses, stones)

---

### Soil Coring

**Target Depths (adapt to active layer):**

**Scenario A: Shallow Active Layer (30-70 cm)**
- 0-15 cm (surface organic)
- 15-30 cm (mid active layer)
- 30-ALT cm (near permafrost table)

**Scenario B: Moderate Active Layer (70-100 cm)**
- 0-15 cm
- 15-30 cm
- 30-50 cm
- 50-100 cm (standard VM0033)

**Scenario C: Deep Active Layer or Permafrost Sampling (>100 cm)**
- 0-15 cm
- 15-30 cm
- 30-50 cm
- 50-100 cm
- 100-150 cm (transition zone)
- 150-200 cm (permafrost, if equipment allows)
- 200-300 cm (deep permafrost, research only)

**Equipment:**
- Permafrost corer (diamond-bit or SIPRE auger)
- Coolers with ice packs (for frozen sample transport)
- Sample bags (Whirl-Pak or similar)
- Depth markers

---

### Ground Ice Content Measurement

**Method:** Gravimetric (thaw and weigh)

**Procedure:**
1. Weigh frozen sample (W_frozen)
2. Thaw sample completely (room temperature, sealed to prevent evaporation)
3. Weigh thawed sample (W_thawed)
4. Calculate: `Ground_Ice_% = (W_frozen - W_thawed) / W_frozen × 100`

**QC:**
- Use sealed containers (minimize evaporation)
- Record initial sample volume (for bulk density correction)
- Separate organic and mineral fractions if possible

---

### Frozen Sample Handling

**CRITICAL Protocols:**

1. **Keep frozen during transport:**
   - Use coolers with dry ice or gel packs
   - Minimize thaw cycles (degrades sample structure)

2. **Bulk density measurement:**
   - Option A: Measure on frozen sample, then apply ground ice correction
   - Option B: Thaw, remove ice water, measure dry bulk density (more accurate but loses structure)

3. **Lab analysis:**
   - Dry at 60°C (prevent combustion of organics)
   - Grind frozen samples (easier than thawed peat)
   - Analyze for SOC% (dry combustion or loss-on-ignition)

---

### Site Documentation

**Photos (minimum):**
- Landscape view (4 cardinal directions)
- Microtopography close-up (polygon pattern, palsa, etc.)
- Vegetation cover (quadrat or close-up)
- Soil core profile (with depth scale)
- Any thermokarst features (ponds, troughs, subsidence)

**Metadata:**
- GPS coordinates (WGS84, decimal degrees, ±3m accuracy)
- Date and time
- Weather conditions (temperature, recent precipitation)
- Observer name
- Equipment used

---

## 🚀 Quick Start Guide

### Step 1: Configure for Arctic

**Edit:** `blue_carbon_config.R`

Already configured with Arctic defaults:
```r
PROJECT_NAME <- "Arctic_Permafrost_Wetlands_2024"
ECOSYSTEM_TYPE <- "ARCTIC_PERMAFROST_WETLANDS"
PROCESSING_CRS <- 3573  # Arctic-optimized projection
MAX_CORE_DEPTH <- 300   # Extended for permafrost
```

**Review and adjust:**
- Active layer depth ranges (`ACTIVE_LAYER_DEPTH_MIN/MAX`)
- Bulk density defaults by stratum (`BD_DEFAULTS`)
- QC thresholds (`QC_SOC_MAX`, `QC_BD_MIN`)
- Monitoring scenarios (`VALID_SCENARIOS`)

---

### Step 2: Prepare Field Data

**Required CSV files:**

**File 1:** `core_locations.csv`
```csv
core_id,latitude,longitude,stratum,scenario,active_layer_depth_cm,permafrost_table_depth_cm,ground_ice_content_pct,sampling_date
POLY001,68.5234,-133.4521,Polygonal Tundra - Wet Center,INTACT,62,62,45,2024-08-05
PALS002,68.5298,-133.4312,Palsa Peatland,BASELINE,38,38,35,2024-08-05
THER003,68.5156,-133.4789,Thermokarst Fen,DEGRADING,98,98,55,2024-08-06
```

**File 2:** `core_samples.csv`
```csv
core_id,depth_top_cm,depth_bottom_cm,bulk_density_g_cm3,organic_carbon_pct,notes
POLY001,0,15,0.14,42.5,Fibric moss peat
POLY001,15,30,0.16,38.2,Sedge peat
POLY001,30,62,0.18,35.8,Near permafrost table
PALS002,0,15,0.09,51.3,Very fibric peat (palsa top)
PALS002,15,38,0.11,48.7,Fibric peat to permafrost
```

Place in: `data_raw/`

---

### Step 3: Extract Spatial Covariates (GEE)

**Open:** `ARCTIC_PERMAFROST_COVARIATES.js` in Google Earth Engine Code Editor

**Steps:**
1. Draw your AOI polygon on map (or load from asset)
2. Adjust config:
   ```javascript
   yearStart: 2022,
   yearEnd: 2024,
   exportScale: 30,  // 30m for Arctic
   processingCRS: 'EPSG:3573'
   ```
3. Run script (green "Run" button)
4. Go to Tasks tab
5. Run export tasks (4 GeoTIFF files)
6. Download from Google Drive
7. Place in: `data_raw/gee_covariates/`

**Expected outputs:**
- `ArcticPermafrost_CovariateStack_Arctic.tif` (multi-band)
- `ArcticPermafrost_ActiveLayerThickness.tif`
- `ArcticPermafrost_PermafrostProbability.tif`
- `ArcticPermafrost_MeanAnnualTemp.tif`

---

### Step 4: Run R Workflow

**In RStudio:**

```r
# Install packages (first time only)
source("00a_install_packages_v2.R")

# Set up directory structure
source("00b_setup_directories.R")

# Core workflow
source("blue_carbon_config.R")  # Load Arctic config
source("01_data_prep_bluecarbon.R")  # Data prep + QC
source("02_exploratory_analysis_bluecarbon.R")  # EDA
source("03_depth_harmonization_bluecarbon.R")  # Depth harmonization
source("05_raster_predictions_rf_bluecarbon.R")  # Spatial prediction
source("06_carbon_stock_calculation_bluecarbon.R")  # Carbon stocks
source("07_mmrv_reporting_bluecarbon.R")  # MMRV report
source("07b_comprehensive_standards_report.R")  # Standards compliance
```

**Output location:** `outputs/mmrv_reports/`

---

### Step 5: Review Outputs

**Key Files:**

1. **`arctic_permafrost_verification_package.html`**
   - Main MMRV report
   - Active layer vs. permafrost carbon breakdown
   - Climate vulnerability metrics
   - Temporal trends

2. **`comprehensive_standards_report.html`**
   - VM0036 compliance check
   - CALM protocol compliance
   - Recommendations for additional sampling

3. **`carbon_stocks_conservative_arctic.csv`**
   - Conservative carbon stock estimates (Mg C/ha)
   - Separate active layer and permafrost pools
   - 95% CI bounds

4. **`outputs/predictions/rf/carbon_stock_rf_[depth].tif`**
   - Spatial carbon stock maps
   - For each harmonized depth
   - CRS: EPSG:3573 (Arctic projection)

---

## 🔍 Key Differences from Coastal Workflow

### 1. Depth Handling

**Coastal:**
- Fixed depths (0-15, 15-30, 30-50, 50-100 cm)
- Equal-area spline interpolates entire profile
- 100 cm maximum

**Arctic:**
- Variable depths (adapt to active layer)
- Spline only within active layer
- Permafrost reported separately
- 300 cm possible (research coring)

---

### 2. Bulk Density

**Coastal:**
- Range: 0.6-1.2 g/cm³
- Mostly mineral-influenced
- Direct measurement

**Arctic:**
- Range: 0.05-1.2 g/cm³
- Very low for fibric peat
- Ground ice correction required
- Frozen vs. thawed density distinction

---

### 3. Carbon Pools

**Coastal:**
- Single pool (0-100 cm soil)
- Reported as total stock

**Arctic:**
- **Active layer carbon** (0-ALT cm) - seasonally dynamic
- **Transition zone carbon** (ALT to ALT+50 cm) - vulnerable
- **Permafrost carbon** (>ALT+50 cm) - ancient, frozen
- **Vulnerable carbon pool** (top 1m of permafrost) - IPCC definition

---

### 4. Temporal Monitoring

**Coastal:**
- 5-year verification cycle (VM0033)
- Restoration trajectory focus
- Scenarios: BASELINE → PROJECT

**Arctic:**
- Annual monitoring recommended
- Permafrost thaw trajectory focus
- Scenarios: INTACT → DEGRADING → THERMOKARST

---

### 5. Climate Vulnerability

**Coastal:**
- Sea level rise
- Storm surge
- Salinity changes

**Arctic:**
- Permafrost thaw
- Active layer deepening
- Thermokarst expansion
- CMIP6 climate projections

---

## ✅ Verification Standards

### Primary: VM0036 Adapted (Verra Peatlands)

**Adaptations for Permafrost:**
- Replace "water table depth" with "active layer depth"
- Add ground ice content requirement
- Separate active layer and permafrost carbon pools
- Extend monitoring to annual frequency (vs. 5-year)
- Add permafrost-specific strata (polygon, palsa, thermokarst)

**Core Requirements (Maintained):**
- Minimum 3 cores per stratum
- Stratification by ecosystem type and condition
- Conservative 95% CI estimates
- Comprehensive QA/QC
- Spatial prediction with uncertainty
- Cross-validation required

---

### Secondary Standards

**IPCC Wetlands Supplement (2013):**
- Tier 3 approach (site-specific data)
- Peatlands chapter (Chapter 3)
- Conservative uncertainty treatment
- Separate carbon pools (active vs. permafrost)

**CALM Protocols:**
- Frost probe methodology
- Late summer sampling (maximum thaw)
- Spatial variability assessment (121-point grid)
- Multi-year monitoring

**Arctic Council Guidelines:**
- Pan-Arctic monitoring consistency
- Indigenous knowledge integration (recommended)
- Climate scenario reporting
- Policy-relevant metrics

**CCIN Standards (Canadian):**
- Metadata standards (ISO 19115)
- Interoperability with GTN-P
- Data quality control
- National data archiving (Polar Data Catalogue)

---

## 📖 Example Use Cases

### Use Case 1: Baseline Carbon Assessment (Intact Permafrost)

**Objective:** Quantify carbon stocks in intact polygonal tundra for climate vulnerability assessment.

**Strata:**
- Polygonal Tundra - Wet Center
- Polygonal Tundra - Dry Rim
- Intact Permafrost Peatland

**Sampling:**
- 5 cores per stratum (15 total)
- Depths: 0-15, 15-30, 30-50, 50-ALT cm
- Active layer measurement at all sites

**Expected Carbon Stocks:**
- Active layer (0-70 cm): 150-250 Mg C/ha
- Upper permafrost (70-170 cm): 200-400 Mg C/ha
- **Total:** 350-650 Mg C/ha

**Outputs:**
- Baseline carbon stock map
- Vulnerable carbon pool quantification
- Active layer depth distribution

---

### Use Case 2: Thermokarst Degradation Monitoring

**Objective:** Track carbon loss and emissions from expanding thermokarst features.

**Strata:**
- Thermokarst Fen (degraded)
- Tundra Pond Margin (edge)
- Intact Permafrost Peatland (reference)

**Temporal Design:**
- Baseline (Year 0): All strata
- Annual monitoring (Years 1-5): All strata
- Track:
  - Active layer deepening rate
  - Thermokarst expansion (%)
  - Carbon stock changes
  - Subsidence rates

**Expected Trends:**
- Active layer deepening: 1-3 cm/year (degrading sites)
- Carbon loss: 2-5 Mg C/ha/year (thermokarst)
- Pond expansion: 5-10% coverage increase per decade

**Outputs:**
- Temporal change maps
- Carbon loss trajectory
- Vulnerable carbon at risk
- CMIP6 scenario comparison

---

### Use Case 3: Research - Permafrost Carbon Depth Distribution

**Objective:** Characterize vertical distribution of carbon in permafrost zone.

**Sampling:**
- Deep permafrost coring (0-300 cm)
- Intact Permafrost Peatland stratum only
- 3 sites with deep cores

**Depths:**
- Active layer: 0-15, 15-30, 30-50 cm
- Transition: 50-100 cm
- Permafrost: 100-150, 150-200, 200-300 cm

**Expected Distribution:**
- Surface (0-30 cm): SOC 400-600 g/kg
- Active layer (30-70 cm): SOC 300-500 g/kg
- Permafrost (70-300 cm): SOC 200-400 g/kg (ancient carbon)

**Outputs:**
- Depth-carbon profiles
- Age-depth modeling (if radiocarbon available)
- Vulnerable carbon quantification

---

## 🛠️ Troubleshooting

### Issue 1: Active Layer Variability Too High

**Symptom:** CV >50% for active layer depth within stratum

**Causes:**
- Microtopography heterogeneity (polygons)
- Sampling across degradation gradient
- Measurement error (probe hitting ice lenses vs. permafrost)

**Solutions:**
1. **Increase sampling:** Add 2-3 cores per stratum
2. **Sub-stratify:** Separate polygon centers vs. rims
3. **CALM grid:** Implement 121-point grid for spatial characterization
4. **QC probe data:** Exclude anomalous measurements (ice lenses)

---

### Issue 2: Ground Ice Correction Uncertainty

**Symptom:** Bulk density ranges overlap unrealistically after correction

**Causes:**
- High ground ice content (>60%)
- Variable ice distribution within sample
- Measurement error in ice content

**Solutions:**
1. **Replicate measurements:** Measure ground ice on multiple subsamples
2. **Use literature values:** If direct measurement unavailable, use stratum-specific defaults from NTED or CanSIS
3. **Sensitivity analysis:** Report carbon stocks with/without ice correction
4. **Flag high uncertainty:** Document in QC report

---

### Issue 3: Depth Harmonization Fails (Frozen Layer)

**Symptom:** Error in equal-area spline - cannot interpolate through discontinuity

**Cause:** Attempting to spline through permafrost table (ice-bonded soil)

**Solutions:**
1. **Split at active layer:** Harmonize only within active layer (0-ALT cm)
2. **Report permafrost separately:** Do NOT interpolate below permafrost table
3. **Use config flag:** Set `PERMAFROST_DEPTH_HARMONIZATION_NOTES$no_spline_through_frozen = TRUE`

**Code example:**
```r
# In 03_depth_harmonization_bluecarbon.R
if (max(sample_depths) > active_layer_depth) {
  # Split into active and permafrost
  active_samples <- filter(depths <= active_layer_depth)
  permafrost_samples <- filter(depths > active_layer_depth)

  # Harmonize active layer only
  active_harmonized <- equal_area_spline(active_samples)

  # Report permafrost as measured (no interpolation)
  permafrost_harmonized <- permafrost_samples
}
```

---

### Issue 4: Covariate Extraction Fails (ArcticDEM)

**Symptom:** GEE script errors on DEM loading

**Causes:**
- ArcticDEM not available for AOI (incomplete coverage)
- Region outside ArcticDEM extent (some subarctic areas)

**Solutions:**
1. **Use CDEM:** Switch to Canadian Digital Elevation Model
   ```javascript
   demSource: 'CDEM'  // In CONFIG
   ```
2. **Use ASTER/SRTM:** Lower resolution but better coverage
3. **Contact ArcticDEM team:** Request priority processing for AOI

---

### Issue 5: Low Sample Size Per Stratum

**Symptom:** <3 cores per stratum (VM0036 minimum)

**Solutions:**
1. **Combine similar strata:**
   - Merge "Polygonal Tundra - Wet Center" + "Polygon Center - Vegetated"
   - Merge "Degrading Permafrost Peatland" + "Thermokarst Fen"
2. **Collect additional samples:** Field logistics permitting
3. **Use Bayesian priors:** Integrate NTED literature values (Part 4)
4. **Document limitation:** Acknowledge in standards compliance report

---

### Issue 6: Permafrost Carbon Not Sampled

**Symptom:** Cores only reach active layer depth (no permafrost samples)

**Cause:** Equipment limitations (hand augers cannot penetrate frozen ground)

**Acceptable Approaches:**
1. **Report active layer carbon only:**
   - Document in methods: "Permafrost zone not sampled due to equipment constraints"
   - Focus on active layer carbon stocks (still valuable for MMRV)

2. **Use literature estimates for permafrost:**
   - NTED database for regional permafrost carbon
   - GSC permafrost characterization
   - Sensitivity analysis: Report range based on literature

3. **Plan for deep coring:**
   - Future field season with permafrost corer (SIPRE, diamond-bit)
   - Helicopter access for heavy equipment
   - Collaboration with research teams (PermafrostNet)

**Still valid for:**
- Active layer carbon stocks
- Temporal monitoring (annual active layer changes)
- Climate vulnerability (vulnerable carbon = top 1m of permafrost can be estimated from literature)

---

## 📚 References

### Key Publications

**Permafrost Carbon Science:**
- Schuur, E.A.G., et al. (2015). Climate change and the permafrost carbon feedback. *Nature*, 520(7546), 171-179.
- Hugelius, G., et al. (2014). Estimated stocks of circumpolar permafrost carbon with quantified uncertainty ranges and identified data gaps. *Biogeosciences*, 11(23), 6573-6593.
- Treat, C.C., et al. (2024). Permafrost Carbon: Progress on Understanding Stocks and Dynamics. *AGU Advances*.

**Monitoring Protocols:**
- Brown, J., et al. (2000). Circumpolar Active Layer Monitoring (CALM) Program. *Polar Geography*, 24(3), 166-176.
- IPCC (2014). 2013 Supplement to the 2006 IPCC Guidelines for National Greenhouse Gas Inventories: Wetlands. IPCC, Switzerland.

**Canadian Context:**
- Smith, S.L., et al. (2022). Recent trends from Canadian permafrost thermal monitoring network sites. *Permafrost and Periglacial Processes*, 33(1), 57-71.

### Data Sources

**Comprehensive list:** See `CANADIAN_ARCTIC_PERMAFROST_DATA_SOURCES.md`

**Quick links:**
- **Permafrost Pathways:** https://www.woodwellclimate.org/project/permafrost-pathways/
- **PermafrostNet:** https://permafrostnet.ca/
- **NRCan Permafrost:** https://natural-resources.canada.ca/permafrost
- **GTN-P:** https://gtnp.arcticportal.org/
- **CALM Network:** https://www2.gwu.edu/~calm/
- **NASA CMS:** https://carbon.nasa.gov/

---

## 📝 Citation

If you use this workflow for research or carbon project development, please cite:

> NorthStar Labs. (2024). Arctic Permafrost Wetland Carbon Monitoring Workflow: Adaptation of Blue Carbon MMRV for Canadian Arctic and Subarctic Ecosystems. GitHub repository.

**Original coastal workflow:**
> NorthStar Labs. (2024). Blue Carbon Composite Sampling & MMRV Workflow. VM0033-compliant coastal carbon assessment. GitHub repository.

---

## 📧 Contact & Support

**Questions or issues?**
- **GitHub Issues:** [Report bugs or request features]
- **PermafrostNet:** https://permafrostnet.ca/contact/
- **Permafrost Pathways:** Contact via Woodwell Climate

**Collaboration opportunities:**
- Co-location with CALM/GTN-P sites
- Data sharing with Polar Data Catalogue
- Integration with Canadian monitoring networks

---

## 📄 License

MIT License - Free to use for research and carbon project development. Please cite appropriately.

---

**Last Updated:** 2024-11-17
**Version:** 1.0 (Arctic Adaptation)
**Maintained by:** NorthStar Labs
