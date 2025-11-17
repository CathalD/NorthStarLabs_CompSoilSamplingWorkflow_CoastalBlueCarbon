# Forest Carbon Measurement, Monitoring & Reporting (MMRV) Workflows

## Overview

This repository now includes **three integrated workflows** for comprehensive forest carbon assessment in Canadian forests, bogs, and fens, specifically designed for resource-constrained forest managers.

**Target Ecosystems:**
- Boreal and temperate forests
- Peatlands (bogs, fens, treed peatlands)
- Mixed forest-wetland landscapes

**Technology Integration:**
- ✈️ Drone-based tree-level mapping
- 🛰️ Satellite remote sensing (GEDI LiDAR + Sentinel-2)
- 📊 Strategic field sampling design
- 🗺️ 3D carbon visualization

---

## Workflow 1: Drone-Based Forest Carbon Assessment

### Purpose
Process drone imagery/LiDAR to map individual trees and calculate carbon stocks at high resolution (sub-hectare scale).

### Files
1. **`DRONE_01_preprocessing_pointcloud.R`** - Process drone point clouds (LiDAR or photogrammetry)
2. **`DRONE_02_tree_segmentation.R`** - Detect individual trees and delineate crowns
3. **`DRONE_03_biomass_calculation.R`** - Calculate biomass and carbon stocks

### Workflow

```
Raw Drone Data → Point Cloud/Orthomosaic → Tree Segmentation →
Individual Tree Attributes → Biomass Calculation → Carbon Stock Maps
```

### Key Capabilities
- **Individual tree detection** using watershed segmentation or Dalponte 2016 algorithm
- **Canopy height models (CHM)** at 0.5m resolution
- **Automated tree measurements:** height, crown diameter, estimated DBH
- **Allometric biomass equations** for Canadian tree species:
  - White Spruce (*Picea glauca*)
  - Black Spruce (*Picea mariana*)
  - Lodgepole Pine (*Pinus contorta*)
  - Douglas Fir (*Pseudotsuga menziesii*)
  - Trembling Aspen (*Populus tremuloides*)
  - 10+ more species
- **Carbon stock calculation** including aboveground + belowground (roots)
- **Uncertainty quantification** (±15-25% typical)

### Input Requirements
| Data Type | Source | Resolution | Format |
|-----------|--------|------------|--------|
| Point cloud | Drone LiDAR | 50-200 pts/m² | LAS/LAZ |
| OR Imagery | Drone RGB | 3-5 cm GSD | JPEG/TIFF |
| DEM (optional) | Processed or external | 1-10 m | GeoTIFF |

### Outputs
- Individual tree locations and attributes (CSV, shapefile)
- Tree crown polygons (shapefile)
- Canopy height model (GeoTIFF)
- Carbon stock maps (GeoTIFF)
- Stand-level carbon summary

### Recommended Drone Setup

| Budget Level | Equipment | Carbon Accuracy |
|--------------|-----------|-----------------|
| **Entry** ($5k-10k) | DJI Mavic 3 Multispectral + Pix4D | ±25-30% |
| **Medium** ($15k-30k) | Matrice 300 + Zenmuse P1 + MicaSense RedEdge | ±20-25% |
| **Advanced** ($60k+) | Above + YellowScan LiDAR | ±15-20% |

### Example Usage

```r
# 1. Preprocess point cloud
source("DRONE_01_preprocessing_pointcloud.R")
# → Creates canopy height model (CHM)

# 2. Segment trees
source("DRONE_02_tree_segmentation.R")
# → Detects 500-2000 trees per hectare

# 3. Calculate carbon
source("DRONE_03_biomass_calculation.R")
# → Outputs: "Carbon Stock: 125.3 Mg C/ha ± 18.2 Mg C/ha"
```

---

## Workflow 2: Strategic Sampling Design for Forests

### Purpose
Optimize field plot placement to achieve target precision with minimum sampling effort.

### Files
1. **`SAMPLING_01_forest_stratification.R`** - Stratify forest into homogeneous units
2. **`SAMPLING_02_plot_design_optimization.R`** - Generate optimized plot locations

### Workflow

```
Study Area + Environmental Layers → K-means Clustering → Stratification Map →
Neyman Allocation → Optimized Plot Locations → Field Data Sheets + GPS Files
```

### Key Capabilities
- **K-means clustering** on environmental variables (GEDI height, NDVI, terrain)
- **Neyman optimal allocation** - more plots in high-variability strata
- **Sample size calculation** for target precision (±10% default)
- **Multiple export formats:**
  - Shapefile (GIS)
  - CSV (data)
  - GPX (handheld GPS)
  - KML (Google Earth)
  - Excel field data sheets
- **Minimum distance enforcement** (avoids clustered plots)
- **Oversample generation** (backup plots if primary inaccessible)

### Input Requirements
| Layer | Source | Purpose |
|-------|--------|---------|
| Canopy height | GEDI (GEE script) or drone | Forest structure |
| NDVI | Sentinel-2 (GEE) | Vegetation vigor |
| Slope/TWI | SRTM DEM (GEE) | Topographic variation |
| Study boundary | Shapefile or drawn | Sampling extent |

### Outputs
- Stratification map (raster + shapefile)
- Plot locations with GPS coordinates
- Field data sheets (Excel with instructions)
- Field maps per stratum (PNG for crews)
- Sample allocation summary

### Typical Sample Size

| Forest Area | Target Precision | Recommended Plots | Field Effort |
|-------------|------------------|-------------------|--------------|
| 1,000 ha | ±10% | 30-50 plots | 5-8 days |
| 5,000 ha | ±10% | 50-80 plots | 10-15 days |
| 10,000 ha | ±15% | 60-100 plots | 12-20 days |

### Example Usage

```r
# 1. Stratify forest
source("SAMPLING_01_forest_stratification.R")
# → Creates 5 strata based on height/NDVI

# 2. Generate plot locations
source("SAMPLING_02_plot_design_optimization.R")
# → Outputs: 45 primary + 9 oversample plots
# → Load plot_locations.gpx to GPS device
```

---

## Workflow 3: Remote Sensing - GEDI + Sentinel-2 Integration

### Purpose
Wall-to-wall carbon stock mapping using satellite LiDAR (GEDI) and optical imagery (Sentinel-2).

### Files
1. **`GEE_FOREST_GEDI_SENTINEL2.js`** - Google Earth Engine script (run in browser)
2. **`REMOTE_01_gedi_processing.R`** - Process GEDI data and calibrate models
3. **`REMOTE_02_3d_carbon_mapping.R`** - Create 3D visualizations and maps

### Workflow

```
Google Earth Engine (JavaScript) → Export Layers →
R Processing → Biomass Model → 3D Carbon Maps
```

### Part A: Google Earth Engine (Web-Based)

**Run in:** https://code.earthengine.google.com/

**What it does:**
1. Extracts GEDI LiDAR footprints (25m diameter, forest heights)
2. Creates Sentinel-2 composite (cloud-free, summer)
3. Calculates vegetation indices (NDVI, EVI, NDMI)
4. Generates terrain derivatives (slope, TWI)
5. Applies GEDI-based biomass model
6. Exports all layers to Google Drive

**Layers Exported:**
- GEDI composite (canopy heights, cover)
- Sentinel-2 summer composite
- Terrain derivatives
- Initial biomass/carbon estimates
- Full feature stack (for modeling)

### Part B: R Processing (Desktop)

**`REMOTE_01_gedi_processing.R`**
- Loads GEE exports
- Quality filters GEDI data
- Calibrates biomass models (Random Forest or linear regression)
- Cross-validation (70/30 split)
- Outputs model performance metrics

**`REMOTE_02_3d_carbon_mapping.R`**
- Creates 2D carbon stock maps
- Generates 3D visualizations (rayshader)
- Interactive web maps (plotly)
- Classifies carbon stocks (Very Low → Very High)
- Identifies priority conservation areas

### Key Capabilities
- **GEDI LiDAR integration** - forest heights from space (2019-present)
- **Multi-sensor fusion** - combines LiDAR + optical + terrain
- **Machine learning** - Random Forest for biomass prediction
- **3D visualization** - flythrough-style carbon maps
- **Scalability** - works on 1 ha to 1 million ha
- **Free data** - all inputs are open-access

### GEDI Data Characteristics

| Metric | Value |
|--------|-------|
| Footprint diameter | 25 m |
| Footprint spacing | ~60-600 m (orbit-dependent) |
| Coverage period | April 2019 - present |
| Canopy height accuracy | ±3-5 m RMSE |
| Best for | Forests >5 m height |

### Typical Accuracy (Boreal/Temperate Forests)

| Method | Biomass R² | Carbon RMSE |
|--------|-----------|-------------|
| GEDI + Sentinel-2 (RF model) | 0.70-0.85 | ±30-45 Mg C/ha |
| GEDI alone | 0.55-0.70 | ±40-60 Mg C/ha |
| With field calibration | 0.80-0.90 | ±20-35 Mg C/ha |

### Example Usage

```javascript
// 1. Google Earth Engine (browser)
// Open GEE_FOREST_GEDI_SENTINEL2.js
// Update study area coordinates
// Click "Run" → exports appear in Tasks tab
// Export to Google Drive
```

```r
# 2. Download exports to data/gee_exports/

# 3. Process GEDI data
source("REMOTE_01_gedi_processing.R")
# → Model R² = 0.78, RMSE = 32.4 Mg C/ha

# 4. Create 3D maps
source("REMOTE_02_3d_carbon_mapping.R")
# → Generates interactive carbon map (open in browser)
```

---

## Configuration File

**`forest_carbon_config.R`** - Central configuration for all workflows

### What's Included
- **Forest ecosystem definitions** (7 types)
- **Allometric equations** (12 Canadian species)
- **Drone parameters** (flight settings, sensors)
- **Sampling design** (plot types, sample size formulas)
- **Remote sensing** (GEDI, Sentinel-2 settings)
- **GEDI biomass models** (boreal, temperate coefficients)
- **QA/QC thresholds**
- **Color schemes** for maps

### Example Customization

```r
# Modify for your region
PROJECT$coordinate_system <- "EPSG:32610"  # UTM Zone 10N

# Change default species
SPECIES_ASSIGNMENT$default_species <- "Pinus_contorta"  # Lodgepole pine

# Adjust plot size
PLOT_DESIGN$plot_radius_m <- 17.84  # 1000 m² plots

# Set target precision
SAMPLING_DESIGN$target_precision <- 0.15  # ±15%
```

---

## Integration Strategy: Combining All Three Workflows

### Scenario: Managing 50,000 ha of boreal forest

**Phase 1: Desktop Planning (Week 1)**
1. Run GEE script → get wall-to-wall GEDI/Sentinel-2 layers
2. Run SAMPLING_01 → stratify into 5-7 forest types
3. Run SAMPLING_02 → generate 60-80 optimized plot locations

**Phase 2: Field Sampling (Weeks 2-4)**
4. Visit plots with GPS + field data sheets
5. Measure trees (DBH, species) per sampling protocols
6. Collect peat cores in wetland strata (0-300 cm)

**Phase 3: Drone Surveys (Weeks 3-5)**
7. Fly drone over 5-10 representative plots per stratum (50-100 ha total)
8. Run DRONE_01 → DRONE_03 for each site
9. Validate tree counts/heights against field data

**Phase 4: Analysis (Week 6)**
10. Run REMOTE_01 with field data → calibrate GEDI biomass model
11. Run REMOTE_02 → create final wall-to-wall carbon map
12. Compare drone (high detail) vs. satellite (broad coverage) results

**Phase 5: Reporting (Week 7)**
13. Generate management recommendations:
    - Identify top 25% carbon density areas → protect
    - Identify low carbon areas → potential harvest
    - Map peatland areas → avoid disturbance
14. Create 3D visualizations for stakeholders
15. Calculate carbon stock by ownership/management zone

### Technology Allocation

| Technology | Coverage | Cost per ha | Best Use |
|------------|----------|-------------|----------|
| **Satellite** (GEDI + S2) | 100% | $0-0.01 | Landscape-scale mapping, stratification |
| **Drone** | 0.1-1% | $5-20 | High-priority areas, validation, detailed assessment |
| **Field plots** | 0.01-0.1% | $50-200 | Calibration, validation, species ID |

---

## Data Requirements Summary

### For Drone Workflow
```
data/
├── drone/
│   └── raw/
│       ├── pointcloud.laz           # Drone LiDAR
│       └── dem.tif                  # Ground elevation (optional)
```

### For Sampling Workflow
```
data/
├── environmental_layers/            # From GEE exports
│   ├── canopy_height_gedi.tif
│   ├── ndvi_summer_median.tif
│   ├── elevation.tif
│   ├── slope.tif
│   └── topographic_wetness_index.tif
└── study_area/
    └── boundary.shp                 # Study area polygon
```

### For Remote Sensing Workflow
```
data/
└── gee_exports/                     # Downloaded from Google Drive
    ├── GEDI_Composite.tif
    ├── Sentinel2_Summer_Composite.tif
    ├── Terrain_Derivatives.tif
    ├── Biomass_Carbon_Stock.tif
    ├── Forest_Carbon_Feature_Stack.tif
    └── GEDI_Footprints_with_Sentinel2.csv
```

---

## Software Requirements

### R Packages (will auto-install if missing)
```r
# Drone workflow
lidR, ForestTools, terra, sf, raster

# Sampling workflow
BalancedSampling, spsample, openxlsx

# Remote sensing
randomForest, gstat, rayshader, plotly, rasterVis

# Common
dplyr, ggplot2, viridis, caret
```

### External Software
- **Google Earth Engine** (free account) - https://earthengine.google.com/
- **Drone processing** (choose one):
  - Agisoft Metashape (commercial, $179-3500)
  - Pix4Dmapper (commercial, $350/month)
  - OpenDroneMap (free, open-source)
- **Optional:**
  - QGIS (free GIS software) - for viewing outputs
  - RStudio (recommended R interface)

---

## Expected Outputs & Deliverables

### Management Reports
1. **Stratification Report**
   - Forest type classification map
   - Area by stratum
   - Recommended sample allocation

2. **Field Sampling Report**
   - Plot locations (GPS-ready)
   - Field data sheets
   - Maps for field crews

3. **Carbon Stock Assessment**
   - Wall-to-wall carbon map (GeoTIFF)
   - Stand-level summaries (CSV)
   - Uncertainty estimates
   - 3D visualizations (PNG, HTML)

4. **Management Recommendations**
   - Priority conservation areas (top 25% carbon)
   - Harvest planning zones
   - Peatland protection zones
   - Carbon stock by management unit

### File Formats
| Output | Format | Use |
|--------|--------|-----|
| Maps | GeoTIFF | GIS analysis |
| Plot data | CSV, Shapefile | Field work, analysis |
| GPS waypoints | GPX, KML | Navigation |
| Field sheets | Excel | Data collection |
| Visualizations | PNG, HTML | Reporting |
| 3D models | PNG, RGL | Stakeholder engagement |

---

## Use Cases

### Use Case 1: Carbon Credit Project Development
**Goal:** Quantify carbon stocks for baseline assessment

**Workflow:**
1. Remote sensing → identify project area boundaries
2. Sampling design → stratified inventory
3. Drone → detailed assessment of representative areas
4. **Result:** Baseline carbon stock ± uncertainty for VCS/Gold Standard

### Use Case 2: Harvest Planning with Carbon Constraints
**Goal:** Identify harvest areas while protecting high-carbon stands

**Workflow:**
1. Remote sensing → wall-to-wall carbon map
2. Classify into 5 carbon classes
3. Protect top 25% (high carbon density)
4. Harvest middle 50% (sustainable)
5. **Result:** Harvest plan that maintains 70% of landscape carbon

### Use Case 3: Peatland Conservation Prioritization
**Goal:** Map peatland carbon to guide protection efforts

**Workflow:**
1. Remote sensing → identify wetlands (TWI, NDVI)
2. Sampling design → peatland-specific plots (soil cores)
3. Lab analysis → peat depth, bulk density, carbon content
4. Spatial interpolation → peatland carbon map
5. **Result:** Priority peatland conservation zones (>500 Mg C/ha)

---

## Accuracy & Uncertainty

### Sources of Uncertainty

| Source | Magnitude | How to Reduce |
|--------|-----------|---------------|
| Allometric equations | ±15-30% | Use local equations, increase field sampling |
| GEDI height measurement | ±3-5 m | Filter by quality flag, multi-year composite |
| Drone tree detection | ±5-15% | High overlap, LiDAR > photogrammetry |
| Sampling error | ±10-20% | Stratified design, increase sample size |
| Species misclassification | ±10-25% | Multispectral imagery, field validation |

### Combined Uncertainty (95% CI)

| Method | Carbon Stock Uncertainty |
|--------|--------------------------|
| Satellite only | ±35-50% |
| Satellite + Field plots | ±20-35% |
| Drone (validated) | ±15-25% |
| Integrated (all three) | ±15-20% |

---

## Troubleshooting

### Common Issues

**1. GEE script fails with "Out of memory"**
- Reduce study area size
- Increase EXPORT_SCALE from 30m to 50m or 100m
- Filter GEDI by date range (e.g., last 2 years only)

**2. Drone segmentation detects too few/many trees**
- Adjust `variable_window` parameters in DRONE_02
- Check CHM smoothing in DRONE_01
- Verify minimum height threshold

**3. GEDI data is sparse in my area**
- GEDI has orbital gaps - check coverage at https://gedi.earthdata.nasa.gov/
- Use multi-year composite (2019-2023)
- Consider Sentinel-1 radar as supplement

**4. Field plots are inaccessible (steep/wet terrain)**
- Use oversample plots
- Adjust `edge_buffer_m` and `min_distance_m`
- Consider drone-only assessment for inaccessible areas

**5. 3D visualization crashes**
- Reduce `render_resolution` (increase to 100m or 200m)
- Use `render_quality = "low"`
- Install XQuartz (Mac) or X11 libraries (Linux)

---

## References & Further Reading

### Allometric Equations
- Lambert et al. (2005). Canadian national tree aboveground biomass equations. *Canadian Journal of Forest Research*, 35(8), 1996-2018.
- Ung et al. (2008). Canadian national biomass equations: new parameter estimates. *Canadian Journal of Forest Research*, 38(10), 2535-2551.

### GEDI Forest Structure
- Duncanson et al. (2022). Aboveground biomass density models for NASA's Global Ecosystem Dynamics Investigation (GEDI) lidar mission. *Remote Sensing of Environment*, 270, 112845.
- Potapov et al. (2021). Mapping global forest canopy height through integration of GEDI and Landsat data. *Remote Sensing of Environment*, 253, 112165.

### Peatland Carbon
- Vitt et al. (2000). Spatial and temporal trends in carbon storage of peatlands of continental western Canada through the Holocene. *Canadian Journal of Earth Sciences*, 37(5), 683-693.

### Sampling Design
- Grafström & Schelin (2014). How to select representative samples. *Scandinavian Journal of Statistics*, 41(2), 277-290.

---

## Support & Citation

**Developed by:** NorthStar Labs

**License:** Open source (specify license)

**Citation:**
```
NorthStar Labs (2025). Forest Carbon MMRV Workflows for Canadian Forests.
GitHub: [repository URL]
```

**Issues & Questions:**
- Open an issue on GitHub
- Email: [your contact]

---

## Changelog

### Version 1.0 (2025-11-17)
- Initial release
- Three integrated workflows (Drone, Sampling, Remote Sensing)
- Canadian forest focus (boreal, temperate, peatlands)
- GEDI + Sentinel-2 integration
- 12 tree species allometric equations
- 3D visualization capabilities

---

## Next Steps for Users

### Getting Started (First-Time Users)

**Step 1:** Install R and required packages
```r
source("forest_carbon_config.R")  # Auto-installs packages
```

**Step 2:** Set up Google Earth Engine
1. Create free account at https://earthengine.google.com/
2. Open code editor at https://code.earthengine.google.com/
3. Copy-paste `GEE_FOREST_GEDI_SENTINEL2.js`

**Step 3:** Define your study area
- Draw polygon in GEE
- OR upload shapefile to GEE Assets
- Update script with study area

**Step 4:** Run GEE script
- Click "Run"
- Go to Tasks tab → Run all exports
- Wait 10-60 minutes for exports to complete
- Download from Google Drive to `data/gee_exports/`

**Step 5:** Run R workflows
```r
# Sampling design
source("SAMPLING_01_forest_stratification.R")
source("SAMPLING_02_plot_design_optimization.R")

# Remote sensing
source("REMOTE_01_gedi_processing.R")
source("REMOTE_02_3d_carbon_mapping.R")

# Drone (if you have drone data)
source("DRONE_01_preprocessing_pointcloud.R")
source("DRONE_02_tree_segmentation.R")
source("DRONE_03_biomass_calculation.R")
```

**Step 6:** Review outputs
- Check `outputs/forest_carbon/` for all results
- Open interactive 3D map in web browser
- Load shapefiles in QGIS for review

---

**Ready to start measuring forest carbon? 🌲📊🛰️**
