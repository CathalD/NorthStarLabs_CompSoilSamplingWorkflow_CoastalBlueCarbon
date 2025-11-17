# Forest Carbon Spatial Covariates Guide

This guide describes the spatial covariates (environmental predictors) needed for Random Forest-based carbon stock mapping in Canadian forest ecosystems.

## Overview

Spatial prediction of forest soil carbon requires covariates that capture the environmental controls on carbon accumulation and decomposition. These include forest stand characteristics, climate, topography, and soil properties.

## Required Directory Structure

```
covariates/
├── forest_inventory/
│   ├── forest_age.tif              # Years since last disturbance
│   ├── species_composition.tif     # Dominant species code
│   ├── pct_conifer.tif            # % coniferous vs deciduous
│   ├── stand_density.tif          # Trees per hectare
│   ├── basal_area.tif             # m²/ha
│   ├── site_index.tif             # Site productivity (m at 50 years)
│   └── disturbance_type.tif       # Last disturbance (fire/harvest/insect)
│
├── climate/
│   ├── mean_annual_temp.tif       # Mean annual temperature (°C)
│   ├── mean_annual_precip.tif     # Mean annual precipitation (mm)
│   ├── growing_degree_days.tif    # GDD above 5°C
│   ├── frost_free_days.tif        # Days per year
│   ├── climate_moisture_index.tif # CMI (precipitation - evapotranspiration)
│   └── continentality.tif         # Temperature range (°C)
│
├── topography/
│   ├── elevation.tif              # Elevation (m)
│   ├── slope.tif                  # Slope (degrees)
│   ├── aspect.tif                 # Aspect (degrees, 0-360)
│   ├── twi.tif                    # Topographic Wetness Index
│   ├── solar_radiation.tif        # Annual solar radiation (MJ/m²/yr)
│   └── tpi.tif                    # Topographic Position Index
│
├── soil/
│   ├── soil_order.tif             # Canadian System soil order
│   ├── drainage_class.tif         # Soil drainage (1-6 scale)
│   ├── texture_class.tif          # USDA texture class
│   ├── parent_material.tif        # Glacial till, fluvial, etc.
│   ├── depth_to_bedrock.tif       # cm
│   └── soil_ph.tif                # pH (if available)
│
└── spectral/
    ├── ndvi_summer.tif            # Normalized Difference Vegetation Index
    ├── evi_summer.tif             # Enhanced Vegetation Index
    ├── nbr.tif                    # Normalized Burn Ratio
    ├── tcap_brightness.tif        # Tasseled Cap Brightness
    ├── tcap_greenness.tif         # Tasseled Cap Greenness
    └── tcap_wetness.tif           # Tasseled Cap Wetness
```

## Priority Covariates (Minimum Requirements)

For basic Random Forest modeling, these covariates are most important:

### **Essential** (Required for reasonable predictions)

1. **Forest Age** (`forest_age.tif`)
   - Years since last major disturbance
   - **Single strongest predictor of forest soil carbon**
   - Source: Provincial forest inventory, Landsat disturbance history

2. **Elevation** (`elevation.tif`)
   - Controls temperature, moisture, decomposition rates
   - Source: Canadian Digital Elevation Model (CDEM), SRTM

3. **Climate Variables**
   - `mean_annual_temp.tif` - Governs decomposition rates
   - `mean_annual_precip.tif` - Controls productivity and moisture
   - Source: ClimateNA, WorldClim, BioSIM

4. **Species Composition** (`species_composition.tif` or `pct_conifer.tif`)
   - Conifer vs deciduous strongly affects litter quality and SOC
   - Source: Provincial vegetation resource inventory (VRI), Landsat

### **Highly Recommended** (Improves accuracy significantly)

5. **Site Productivity** (`site_index.tif`)
   - Height at reference age (50 years) - proxy for C input rates
   - Source: Forest inventory growth and yield models

6. **Topographic Wetness Index** (`twi.tif`)
   - Controls soil moisture and decomposition
   - Calculate from DEM using SAGA GIS or WhiteboxTools

7. **Soil Drainage Class** (`drainage_class.tif`)
   - Critical for boreal forests (wet = high SOC, dry = low SOC)
   - Source: Soil Landscapes of Canada (SLC), provincial soil surveys

8. **NDVI** (`ndvi_summer.tif`)
   - Proxy for vegetation productivity and biomass
   - Source: Landsat, Sentinel-2

### **Optional** (Additional refinement)

9. Slope, aspect, parent material, disturbance type, spectral indices

---

## Data Sources for Canadian Forests

### **Forest Inventory Data**

| Variable | Source | Resolution | URL |
|----------|--------|------------|-----|
| Forest Age | Provincial VRI | 25-30m | BC: https://www.for.gov.bc.ca/hts/vri/ |
| Species | National Forest Inventory | 250m | https://nfi.nfis.org/ |
| Site Index | Growth & Yield models | 25-30m | Provincial forest agencies |
| Disturbance History | Canadian Disturbance Database | 30m | https://opendata.nfis.org/ |

### **Climate Data**

| Variable | Source | Resolution | URL |
|----------|--------|------------|-----|
| Temperature, Precipitation | ClimateNA | 1km | https://climatena.ca/ |
| WorldClim 2.1 | WorldClim | 1km | https://www.worldclim.org/ |
| Canadian Climate Normals | Environment Canada | Station-based | https://climate.weather.gc.ca/ |

### **Topography**

| Variable | Source | Resolution | URL |
|----------|--------|------------|-----|
| Elevation | CDEM | 20m | https://open.canada.ca/data/en/dataset/7f245e4d-76c2-4caa-951a-45d1d2051333 |
| SRTM | NASA | 30m | https://earthexplorer.usgs.gov/ |
| Derivatives (slope, TWI) | Calculate from DEM | Same as DEM | Use SAGA GIS, WhiteboxTools, or GRASS |

### **Soil Data**

| Variable | Source | Resolution | URL |
|----------|--------|------------|-----|
| Soil Order, Texture | Soil Landscapes of Canada (SLC) | 1:1M polygons | https://sis.agr.gc.ca/cansis/ |
| Drainage Class | Provincial soil surveys | Variable | Provincial agriculture/forestry agencies |
| SoilGrids (global) | ISRIC | 250m | https://soilgrids.org/ |

### **Spectral/Remote Sensing**

| Variable | Source | Resolution | URL |
|----------|--------|------------|-----|
| NDVI, EVI, NBR | Landsat 8/9 | 30m | https://earthengine.google.com/ |
| NDVI, EVI | Sentinel-2 | 10-20m | https://earthengine.google.com/ |
| Tasseled Cap | Landsat composites | 30m | GEE: `ee.Image.fromAsset()` |

---

## Processing Spatial Covariates

### **1. Coordinate Reference System**

All covariates **must be in the same CRS** as defined in `blue_carbon_config.R`:

```r
PROCESSING_CRS <- 3347  # Canada Albers Equal Area
```

**Reprojection example (using GDAL):**

```bash
gdalwarp -t_srs EPSG:3347 -tr 30 30 -r bilinear \
  input_covariate.tif output_covariate_albers.tif
```

**In R:**

```r
library(terra)

# Reproject raster
cov <- rast("input_covariate.tif")
cov_proj <- project(cov, "EPSG:3347", method = "bilinear")
writeRaster(cov_proj, "output_covariate_albers.tif")
```

### **2. Spatial Resolution**

Match the resolution defined in `blue_carbon_config.R`:

```r
RF_CELL_SIZE <- 30  # meters (Landsat-based forest inventory)
```

**Resampling example:**

```bash
gdalwarp -tr 30 30 -r bilinear input.tif output_30m.tif
```

### **3. Extent Alignment**

All covariates must cover the same geographic extent (or larger than your study area).

**Crop to study area:**

```r
library(terra)

# Load study area boundary
study_area <- vect("data_raw/study_area_boundary.shp")
study_area <- project(study_area, "EPSG:3347")

# Crop and mask covariate
cov <- rast("covariate.tif")
cov_crop <- crop(cov, study_area)
cov_mask <- mask(cov_crop, study_area)

writeRaster(cov_mask, "covariate_study_area.tif")
```

### **4. Missing Data Handling**

- Fill small gaps using focal statistics: `focal(cov, w=3, fun="mean", na.rm=TRUE)`
- For large gaps: Omit covariate or use auxiliary data

---

## Google Earth Engine Code for Covariate Extraction

### **Climate Variables (WorldClim)**

```javascript
// Load WorldClim 2.1 bioclimatic variables
var worldclim = ee.Image("WORLDCLIM/V1/BIO");

// Extract mean annual temperature (BIO1) and precipitation (BIO12)
var mat = worldclim.select('bio01').divide(10); // Convert to °C
var map = worldclim.select('bio12'); // mm/year

// Export
Export.image.toDrive({
  image: mat,
  description: 'mean_annual_temp',
  scale: 1000,
  region: studyArea,
  crs: 'EPSG:3347'
});

Export.image.toDrive({
  image: map,
  description: 'mean_annual_precip',
  scale: 1000,
  region: studyArea,
  crs: 'EPSG:3347'
});
```

### **Forest Age (from Landsat Disturbance)**

```javascript
// Load Canadian forest disturbance dataset (if available)
// Or use LandTrendr for disturbance detection
var disturbance = ee.Image("users/your_asset/canadian_forest_disturbance");

// Calculate years since disturbance
var currentYear = 2024;
var disturbanceYear = disturbance.select('year_of_disturbance');
var forestAge = ee.Image(currentYear).subtract(disturbanceYear);

// Export
Export.image.toDrive({
  image: forestAge,
  description: 'forest_age',
  scale: 30,
  region: studyArea,
  crs: 'EPSG:3347'
});
```

### **NDVI (Sentinel-2 Summer Composite)**

```javascript
// Load Sentinel-2 SR
var s2 = ee.ImageCollection('COPERNICUS/S2_SR')
  .filterBounds(studyArea)
  .filterDate('2023-06-01', '2023-08-31')
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 20));

// Calculate NDVI
var addNDVI = function(image) {
  var ndvi = image.normalizedDifference(['B8', 'B4']).rename('NDVI');
  return image.addBands(ndvi);
};

var s2NDVI = s2.map(addNDVI);

// Median composite
var ndviMedian = s2NDVI.select('NDVI').median();

// Export
Export.image.toDrive({
  image: ndviMedian,
  description: 'ndvi_summer_2023',
  scale: 10,
  region: studyArea,
  crs: 'EPSG:3347',
  maxPixels: 1e13
});
```

### **Topographic Wetness Index (from SRTM)**

```javascript
// Load SRTM elevation
var srtm = ee.Image("USGS/SRTMGL1_003");

// Calculate slope (degrees)
var slope = ee.Terrain.slope(srtm);

// Calculate flow accumulation (requires careful setup)
// Using simplified approach with local contributing area

// TWI = ln(a / tan(slope))
// where a = specific catchment area (m²/m)

// For basic implementation:
var slopeRadians = slope.multiply(Math.PI).divide(180);
var tanSlope = slopeRadians.tan();

// Accumulate flow (simplified - use proper hydrology algorithm for production)
var flowAccum = srtm.focalMean(500, 'circle', 'meters'); // Placeholder

// Calculate TWI
var twi = flowAccum.divide(tanSlope.add(0.001)).log();

// Export
Export.image.toDrive({
  image: twi,
  description: 'twi',
  scale: 30,
  region: studyArea,
  crs: 'EPSG:3347'
});
```

---

## Covariate Selection Tips

### **Avoid Multicollinearity**

Many forest covariates are correlated (e.g., elevation and temperature). Use Variable Importance from Random Forest to identify redundant predictors.

**In R (after running Module 05):**

```r
# Check variable importance
var_imp <- readRDS("outputs/models/rf/variable_importance_7_5cm.rds")
print(var_imp)

# Remove covariates with importance < 5%
```

### **Temporal Consistency**

Ensure covariates represent the same time period as your field sampling:
- NDVI: Use imagery from same year as field work
- Forest age: Calculate from most recent disturbance layer
- Climate: Use 30-year normals (1991-2020)

### **Scale Appropriateness**

Match covariate resolution to your sampling intensity:
- Dense sampling (>30 plots): 10-30m resolution
- Sparse sampling (<20 plots): 100-250m resolution may be sufficient

---

## Quality Control Checklist

Before running Module 05 (Random Forest), verify:

- [ ] All covariates in same CRS (`EPSG:3347` or as defined in config)
- [ ] All covariates have same pixel size (`30m` or as defined in config)
- [ ] All covariates cover study area extent (or larger)
- [ ] No systematic missing data (small gaps ok, will be interpolated)
- [ ] File names match expected pattern (lowercase, underscores, `.tif` extension)
- [ ] Categorical covariates (species, soil order) are coded as integers
- [ ] Continuous covariates have realistic value ranges (check with `terra::minmax()`)

---

## Example Workflow

```r
library(terra)

# 1. Define study area
study_area <- vect("data_raw/study_area_boundary.shp")
study_area <- project(study_area, "EPSG:3347")

# 2. Create template raster
template <- rast(study_area, res = 30)

# 3. Process each covariate
cov_files <- list.files("covariates_raw", pattern = "\\.tif$", full.names = TRUE)

for (file in cov_files) {
  # Read
  cov <- rast(file)

  # Reproject
  cov_proj <- project(cov, template, method = "bilinear")

  # Crop
  cov_crop <- crop(cov_proj, study_area)

  # Save
  outname <- file.path("covariates", basename(file))
  writeRaster(cov_crop, outname, overwrite = TRUE)

  cat(sprintf("Processed: %s\n", basename(file)))
}
```

---

## Further Resources

- **Canadian Forest Service Publications**: https://cfs.nrcan.gc.ca/publications
- **Google Earth Engine Guides**: https://developers.google.com/earth-engine/
- **SAGA GIS Terrain Analysis**: http://www.saga-gis.org/
- **WhiteboxTools**: https://www.whiteboxgeo.com/
- **ClimateNA**: https://climatena.ca/
- **CBM-CFS3 User Guide**: https://www.nrcan.gc.ca/climate-change/impacts-adaptations/climate-change-impacts-forests/carbon-accounting/carbon-budget-model/13107

---

**Questions? Issues?**

Check the main `README.md` for troubleshooting tips or open an issue on GitHub.
