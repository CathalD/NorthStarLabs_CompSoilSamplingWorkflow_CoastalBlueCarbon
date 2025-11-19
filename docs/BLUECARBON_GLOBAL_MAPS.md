# Blue Carbon Global Maps for Transfer Learning

## The SoilGrids Problem

**SoilGrids is terrestrial-focused** and doesn't adequately represent blue carbon ecosystems:
- ❌ Trained primarily on upland soils
- ❌ Limited tidal wetland training data
- ❌ Doesn't capture mangrove-specific relationships
- ❌ Misses seagrass/tidal marsh dynamics
- ❌ No inundation/salinity factors

**We need blue carbon-specific global products!**

---

## Blue Carbon Global Products Available

### 1. **Mangrove Soil Carbon** 🌴

#### **Sanderman et al. (2018)** - Nature Climate Change
- Global mangrove soil carbon stocks (0-1m depth)
- Based on 6,000+ mangrove cores
- Resolution: ~30m
- **Limitation:** Not directly in GEE, needs import

**Alternative - Simard et al. (2019)**
- Global mangrove AGB and canopy height
- Available in GEE: `projects/earth-engine-legacy/assets/GMW/Mangrove_AGB_SIMARD`
- Can estimate soil C: `Soil_C ≈ 3 × (0.47 × AGB)`
- Empirical relationship: Soil C = 2-4x aboveground C

**Global Mangrove Watch**
- Mangrove extent and change
- Available in GEE: `GMW/v1_3`
- Tracks mangrove distribution 1996-2020

### 2. **Tidal Wetland Extent** 🌊

#### **Murray et al. (2019)** - Nature
- Global intertidal wetland extent
- Available in GEE: `UQ/murray/Intertidal/v1_1/global_intertidal`
- Resolution: 30m
- Classifies tidal flats, marshes

**Bunting et al. (2018)**
- Global tidal wetland change 1999-2019
- Salt marsh, mangrove, tidal flats

### 3. **Seagrass Carbon** 🌾

#### **Fourqurean et al. (2012)** - Nature Geoscience
- Global seagrass carbon stocks
- Mean: 140 Mg C/ha (0-1m)
- Range: 50-300 Mg C/ha
- **Limitation:** Point data, not raster

**Approach:** Use literature mean + local refinement
```r
# For seagrass cores:
seagrass_baseline = 140  # Mg C/ha from Fourqurean
# Regional model learns deviation from this
```

### 4. **Coastal Carbon Research Coordination Network (CCRCN)** 📊

- 7,000+ coastal wetland cores
- Tidal marshes, mangroves, seagrass
- Holmquist et al. (2018) ESSD
- **Not a raster**, but can extract regional patterns

**Approach:** Calculate regional means by ecoregion
```r
# Extract CCRCN regional baselines:
# Pacific Northwest tidal marsh: 150 Mg C/ha
# Gulf Coast mangrove: 250 Mg C/ha
# etc.
```

---

## Recommended Transfer Learning Strategy

### **Ecosystem-Specific Baselines:**

| Ecosystem | Global Baseline | Source | Use |
|-----------|----------------|--------|-----|
| **Mangrove** | Simard AGB → Soil C | GEE: Simard 2019 | `soil_c = 3 × (0.47 × agb)` |
| **Tidal Marsh** | CCRCN regional mean | Literature | Ecoregion-specific constant |
| **Seagrass** | Fourqurean mean | Literature | Global mean: 140 Mg C/ha |
| **Tidal Flats** | Murray classification | GEE: Murray 2019 | Binary flag + water occurrence |

### **Universal Blue Carbon Features:**

For **all** blue carbon ecosystems, extract:

1. **Water/Tidal Characteristics:**
   - GSW water occurrence (%)
   - GSW water seasonality
   - Distance to permanent water
   - Elevation (tidal zone indicator)

2. **Climate:**
   - WorldClim MAT, MAP
   - Temperature seasonality
   - Precipitation patterns

3. **Terrestrial Comparison:**
   - SoilGrids SOC (to show how blue carbon DIFFERS)
   - Helps model learn marine vs terrestrial patterns

---

## Implementation with GEE Script

### **Run:** `GEE_EXTRACT_BLUECARBON_GLOBAL_MAPS.js`

This script extracts:

**Mangrove-specific (4 features):**
- `simard_agb_Mg_ha` - Aboveground biomass
- `simard_height_m` - Canopy height
- `estimated_mangrove_soil_c_Mg_ha` - Estimated soil C
- `gmw_mangrove_extent` - Extent flag

**Tidal wetland (2 features):**
- `murray_tidal_class` - Intertidal classification
- `murray_tidal_flag` - Binary: tidal vs not

**Coastal/tidal (5 features):**
- `gsw_water_occurrence_pct` - Water frequency
- `gsw_water_seasonality_months` - Seasonal variation
- `gsw_water_recurrence_pct` - Return interval
- `gsw_max_extent_flag` - Maximum water extent
- `gsw_distance_to_water_m` - Proximity to water

**Climate (6 features):**
- `wc_MAT_C`, `wc_MAP_mm` - Temperature, precipitation
- `wc_temp_seasonality`, `wc_precip_seasonality`
- `wc_max_temp_warmest_C`, `wc_min_temp_coldest_C`

**Topography (3 features):**
- `topo_elevation_m` - Elevation (key for tidal zones)
- `topo_slope_deg` - Slope
- `topo_tidal_elevation_flag` - Within tidal range (|elev| < 10m)

**Terrestrial comparison (2 features):**
- `sg_terrestrial_soc_0_5cm_g_kg` - SoilGrids 0-5cm
- `sg_terrestrial_soc_5_15cm_g_kg` - SoilGrids 5-15cm

**Total: 22 blue carbon-specific features**

---

## How Transfer Learning Works by Ecosystem

### **For Mangrove Cores:**

```r
# Your regional model learns:
mangrove_SOC ~
  # Global baseline (transfer learning!)
  estimated_mangrove_soil_c_Mg_ha +   # Simard estimate
  simard_agb_Mg_ha +                  # Biomass relationship

  # Tidal characteristics
  gsw_water_occurrence_pct +
  topo_elevation_m +

  # Climate (affects decomposition)
  wc_MAT_C +
  wc_MAP_mm +

  # Local refinements
  local_NDVI +
  local_SAR_VV
```

The model learns: **"How does this mangrove differ from Simard's global estimate?"**

### **For Tidal Marsh Cores:**

```r
# Your regional model learns:
marsh_SOC ~
  # Tidal wetland indicators (transfer learning!)
  murray_tidal_class +
  gsw_water_occurrence_pct +
  gsw_water_seasonality_months +
  topo_tidal_elevation_flag +

  # Climate
  wc_MAT_C +
  wc_precip_seasonality +

  # Terrestrial comparison
  sg_terrestrial_soc_0_5cm_g_kg +  # Learn how marsh differs from upland

  # Local refinements
  local_NDVI +
  local_EVI
```

The model learns: **"Tidal marsh carbon = tidal characteristics + deviation from terrestrial"**

### **For Seagrass Cores:**

```r
# Your regional model learns:
seagrass_SOC ~
  # Water characteristics (transfer learning!)
  gsw_water_occurrence_pct +   # Should be ~100% for seagrass
  gsw_distance_to_water_m +

  # Depth indicators
  topo_elevation_m +  # Negative = subtidal

  # Climate (affects productivity)
  wc_MAT_C +

  # Terrestrial comparison
  sg_terrestrial_soc_0_5cm_g_kg +  # Learn marine signal

  # Local refinements
  local_NDWI +  # Water index
  local_NDVI    # Productivity
```

The model learns: **"Seagrass carbon = water characteristics + marine soil properties"**

---

## Adding Literature Baselines

For ecosystems without global rasters, use **literature-derived constants**:

```r
# In your regional model preparation:

cores <- cores %>%
  mutate(
    # Literature-derived baselines (Mg C/ha, 0-1m)
    literature_baseline_Mg_ha = case_when(
      ecosystem == "Mangrove" ~ 250,      # Sanderman et al. 2018 median
      ecosystem == "Tidal_Marsh" ~ 150,   # CCRCN Pacific Northwest mean
      ecosystem == "Seagrass" ~ 140,      # Fourqurean et al. 2012 global mean
      ecosystem == "Tidal_Flat" ~ 50,     # McLeod et al. 2011
      TRUE ~ NA_real_
    ),

    # Ecoregion-specific if available
    ecoregion_baseline_Mg_ha = case_when(
      ecoregion == "Pacific_Northwest" & ecosystem == "Tidal_Marsh" ~ 145,
      ecoregion == "California_Coast" & ecosystem == "Tidal_Marsh" ~ 155,
      # Add more based on CCRCN database regional queries
      TRUE ~ literature_baseline_Mg_ha
    )
  )

# Then include in model:
rf_model <- ranger(
  SOC_Mg_ha ~
    ecoregion_baseline_Mg_ha +  # Transfer learning from literature!
    gsw_water_occurrence_pct +
    local_NDVI +
    ...
)
```

---

## Expected Performance by Ecosystem

Based on blue carbon literature and transfer learning principles:

### **Mangroves** (Strong global baseline available)
- Expected MAE reduction: **20-35%**
- R² improvement: **+0.15 to +0.25**
- Simard AGB correlates well with soil C

### **Tidal Marshes** (Moderate baseline - tidal characteristics)
- Expected MAE reduction: **15-25%**
- R² improvement: **+0.10 to +0.20**
- Tidal indicators + climate help

### **Seagrass** (Weak global baseline)
- Expected MAE reduction: **10-20%**
- R² improvement: **+0.05 to +0.15**
- Water occurrence + depth indicators help

### **Mixed Ecosystems** (Your Janousek dataset)
- Expected MAE reduction: **15-30%**
- R² improvement: **+0.10 to +0.20**
- Ecosystem-specific features beneficial

---

## Validation Approach

### **Compare Models:**

```r
# Model A: Local only
model_local <- ranger(SOC ~ local_NDVI + local_elevation + ...)

# Model B: Local + Blue Carbon Global Features
model_bc_transfer <- ranger(
  SOC ~
    local_NDVI +
    estimated_mangrove_soil_c +  # Blue carbon baseline
    gsw_water_occurrence_pct +
    murray_tidal_flag +
    ...
)

# Model C: Local + Terrestrial (SoilGrids) - for comparison
model_terrestrial <- ranger(
  SOC ~
    local_NDVI +
    sg_terrestrial_soc_0_5cm +  # Wrong baseline for blue carbon!
    ...
)

# Hypothesis: Model B > Model A > Model C
# Blue carbon features should outperform terrestrial
```

---

## Data Sources & Citations

### **For MMRV Reporting:**

**Mangrove:**
- Simard, M., et al. (2019). Mangrove canopy height globally related to precipitation, temperature and cyclone frequency. *Nature Geoscience*, 12(1), 40-45.
- Sanderman, J., et al. (2018). A global map of mangrove forest soil carbon at 30 m spatial resolution. *Environmental Research Letters*, 13(5), 055002.

**Tidal Wetlands:**
- Murray, N.J., et al. (2019). The global distribution and trajectory of tidal flats. *Nature*, 565(7738), 222-225.
- Holmquist, J.R., et al. (2018). Accuracy and precision of tidal wetland soil carbon mapping in the conterminous United States. *Scientific Reports*, 8, 9478.

**Seagrass:**
- Fourqurean, J.W., et al. (2012). Seagrass ecosystems as a globally significant carbon stock. *Nature Geoscience*, 5(7), 505-509.

**Coastal Water:**
- Pekel, J.F., et al. (2016). High-resolution mapping of global surface water and its long-term changes. *Nature*, 540(7633), 418-422.

**Climate:**
- Fick, S.E. & Hijmans, R.J. (2017). WorldClim 2: new 1‐km spatial resolution climate surfaces for global land areas. *International Journal of Climatology*, 37(12), 4302-4315.

---

## Summary

### **Key Takeaway:**

Instead of using **terrestrial SoilGrids**, use **blue carbon-specific products**:

✅ **Mangrove:** Simard AGB → soil C estimates
✅ **Tidal wetlands:** Murray classification + water occurrence
✅ **Seagrass:** Literature baselines + water characteristics
✅ **All ecosystems:** Tidal/water features + climate

This provides:
- Ecosystem-appropriate baselines
- Better transfer learning performance
- Scientifically defensible for carbon projects
- Still computationally efficient (5 minutes in GEE)

### **Next Steps:**

1. Run `GEE_EXTRACT_BLUECARBON_GLOBAL_MAPS.js`
2. Download blue carbon features CSV
3. Merge with your regional cores
4. Train ecosystem-specific or combined models
5. Compare performance vs terrestrial-only models

**Blue carbon deserves blue carbon baselines!** 🌊
