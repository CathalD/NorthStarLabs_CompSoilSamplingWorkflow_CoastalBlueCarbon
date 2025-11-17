# Module 11: 3D Ecosystem & Hydrological Modeling

**Complete guide for 3D visualization and hydrological analysis for coastal blue carbon restoration planning**

---

## 📋 Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Module 11: Core Analysis](#module-11-core-analysis)
- [Module 11b: Scenario Builder](#module-11b-scenario-builder)
- [Capabilities](#capabilities)
- [Outputs](#outputs)
- [Integration with Other Software](#integration-with-other-software)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

Module 11 extends the Blue Carbon workflow with powerful 3D visualization and hydrological modeling capabilities, **all within R**. This enables:

- ✅ **3D terrain visualization** with carbon stock overlays
- ✅ **Hydrological modeling** (flow, wetness, runoff, sediment)
- ✅ **Tidal flooding scenarios** under sea level rise
- ✅ **Riparian buffer analysis** for sediment/nutrient filtering
- ✅ **Restoration scenario planning** with before/after comparisons
- ✅ **Integration with VM0033 reporting** (Module 07)

**Key Advantage**: No need for external GIS software for basic-to-intermediate analyses!

---

## 🔧 Installation

### Step 1: Install Required Packages

```r
# Run the installation script
source("00a_install_packages_3d_hydro.R")
```

This installs:
- **3D Visualization**: `rayshader`, `rgl`, `plotly`, `rayrender`
- **Hydrology**: `whitebox`, `EcoHydRology`, `topmodel`
- **Coastal**: `TideHarmonics`, `oce`, `rtide`
- **Terrain**: `elevatr`, `terrainr`, `lakemorpho`

**Installation time**: 5-10 minutes

### Step 2: Install WhiteboxTools

WhiteboxTools is automatically installed by the `whitebox` R package:

```r
library(whitebox)
install_whitebox()  # Downloads WhiteboxTools executable
wbt_version()       # Verify installation
```

### Step 3: Verify Installation

```r
# Test 3D rendering
library(rayshader)
volcano %>%
  sphere_shade(texture = "desert") %>%
  plot_map()
```

If you see a colored elevation map of the volcano dataset, you're ready!

---

## 🚀 Quick Start

### Minimum Workflow

```r
# 1. Run core blue carbon workflow first (Modules 01-06)
source("01_data_prep_bluecarbon.R")
# ... through Module 06

# 2. Run 3D ecosystem modeling
source("11_3d_ecosystem_modeling.R")

# 3. Build restoration scenarios
source("11b_restoration_scenario_builder.R")
```

### What You Need

**Minimum inputs**:
- DEM (elevation raster) - `data_raw/gee_covariates/elevation.tif`
- Field data (for carbon stocks) - from Modules 01-06

**Optional inputs** (enhance analysis):
- Carbon stock predictions - from Module 05/06
- Ecosystem strata map - from Module 01
- Slope, NDVI, NDWI - from GEE covariate extraction

---

## 📊 Module 11: Core Analysis

### What It Does

Module 11 provides **baseline hydrological and ecosystem analysis**:

1. **Hydrological Modeling**
   - Flow accumulation
   - Topographic Wetness Index (TWI)
   - Stream network extraction
   - Watershed delineation

2. **Sediment Transport**
   - RUSLE soil loss estimation
   - Sediment deposition mapping
   - Erosion hotspots

3. **Tidal Flooding**
   - Current tidal scenarios (MHW, MHHW, storm surge)
   - Sea level rise projections (0.5m, 1.0m, 1.5m, 2.0m)
   - Carbon at risk assessment

4. **Riparian Buffer Analysis**
   - Test multiple buffer widths (10m, 20m, 30m, 50m, 100m)
   - Sediment trapping efficiency
   - Carbon sequestration potential

5. **3D Visualization**
   - Interactive 3D terrain models
   - Carbon stock overlays
   - Multiple viewing angles
   - High-resolution exports

### Configuration

Edit parameters at the top of `11_3d_ecosystem_modeling.R`:

```r
# 3D Visualization
CONFIG_3D <- list(
  render_3d = TRUE,              # Set FALSE if no display available
  z_scale = 5,                   # Vertical exaggeration (1-20)
  save_snapshots = TRUE,
  create_animations = FALSE      # Slow - enable for presentations
)

# Hydrological Modeling
CONFIG_HYDRO <- list(
  flow_accumulation = TRUE,
  wetness_index = TRUE,
  stream_network = TRUE,
  stream_threshold = 1000        # Cells for stream definition
)

# Tidal/Sea Level Rise
CONFIG_TIDAL <- list(
  enable = TRUE,
  mhw_elevation = 2.5,           # Adjust for your site
  slr_scenarios = c(0, 0.5, 1.0, 1.5, 2.0)  # Meters
)

# Riparian Buffers
CONFIG_BUFFER <- list(
  enable = TRUE,
  buffer_widths = c(10, 20, 30, 50, 100),  # Meters
  sediment_trap_efficiency = 0.70           # 70% per 10m
)
```

### Outputs

```
outputs/
├── 3d_models/
│   ├── renders/
│   │   ├── terrain_2d.png
│   │   ├── carbon_stocks_2d.png
│   │   ├── terrain_3d_view1.png
│   │   └── terrain_3d_view2.png
│   ├── animations/              # If enabled
│   └── module11_summary.json    # Summary statistics
├── hydrology/
│   ├── flow_accumulation.tif
│   ├── topographic_wetness_index.tif
│   ├── stream_network.tif
│   └── high_wetness_areas.tif
├── sediment/
│   ├── soil_loss_rusle.tif
│   └── deposition_potential.tif
├── tidal/
│   ├── inundation_MHW.tif
│   ├── inundation_MHHW.tif
│   ├── inundation_Storm.tif
│   ├── inundation_SLR_0p5m.tif
│   ├── inundation_SLR_1p0m.tif
│   └── inundation_summary.csv
└── riparian_buffers/
    ├── sediment_trapped_10m.tif
    ├── sediment_trapped_30m.tif
    ├── buffer_effectiveness_summary.csv
    └── buffer_effectiveness_curve.png
```

### Example Output Interpretation

**Hydrological Metrics**:
```
Stream length: 2.3 km
Mean slope: 8.5%
High wetness area: 12.5 ha (priority restoration sites)
```

**Sediment Transport**:
```
Mean soil loss: 3.2 tons/ha/year
Total soil loss: 485 tons/year
Sediment delivery to wetlands: ~340 tons/year
```

**Sea Level Rise**:
```
Current MHW inundation: 15.2 ha
+0.5m SLR: 18.7 ha (+23%)
+1.0m SLR: 24.3 ha (+60%)
+1.5m SLR: 31.8 ha (+109%)
Carbon at risk (+1m SLR): 1,250 Mg C
```

**Riparian Buffers**:
```
30m buffer:
  - Sediment trapped: 85 tons/year (24% reduction)
  - Buffer area: 4.2 ha
  - Carbon sequestration: 6.3 Mg C/year
```

---

## 🏗️ Module 11b: Scenario Builder

### What It Does

Module 11b enables **custom restoration scenario planning**:

- Modify DEMs (grading, excavation)
- Add vegetation/riparian buffers
- Create tidal channels
- Compare ecosystem service outcomes (carbon, hydrology, flood risk)

### Pre-Defined Scenarios

Six scenarios are included by default:

#### 1. **Baseline** (Current Conditions)
- No modifications
- Reference for comparisons

#### 2. **Tidal Restoration**
- Remove dike/levee
- Lower elevation to restore tidal connection (-1.5m)
- Convert to tidal marsh vegetation
- **Carbon benefit**: +2.5 Mg C/ha/year

#### 3. **Riparian Buffer Restoration**
- Plant 30m vegetated buffers along streams
- Dense native vegetation
- **Sediment reduction**: 70% trap efficiency
- **Carbon benefit**: +1.5 Mg C/ha/year

#### 4. **Tidal Channel Creation**
- Excavate dendritic channel network
- 1m deep × 5m wide channels
- Improve sediment delivery and drainage
- **Hydrology improvement**: Enhanced tidal exchange

#### 5. **Full Restoration** (Combined)
- Tidal restoration + buffers + channels
- **Maximum carbon benefit**: ~4.0 Mg C/ha/year
- **Flood mitigation**: Enhanced

#### 6. **Climate Adaptation**
- Elevate refuge zones for SLR resilience
- Enhance sediment supply (thin-layer placement)
- **Future-proofs** restoration investments

### Customizing Scenarios

Edit `SCENARIO_DEFINITIONS` in `11b_restoration_scenario_builder.R`:

```r
SCENARIO_DEFINITIONS <- list(
  my_custom_scenario = list(
    name = "My Custom Scenario",
    description = "Description here",
    modifications = list(
      list(
        type = "remove_dike",
        elevation_adjust = -1.2,  # Lower by 1.2m
        description = "Partial dike breach"
      ),
      list(
        type = "create_buffer",
        target = "streams",
        buffer_width = 25,  # 25m buffer
        carbon_sequestration_rate = 1.8  # Mg C/ha/year
      )
    )
  )
)
```

### Modification Types

| Type | Parameters | Effect |
|------|-----------|--------|
| `remove_dike` | `elevation_adjust` | Lowers elevation in target area |
| `create_buffer` | `buffer_width`, `target` | Adds vegetated buffer zones |
| `excavate_channels` | `channel_depth`, `channel_width` | Creates tidal channels |
| `vegetation_change` | `new_stratum`, `c_factor` | Changes vegetation type |
| `elevate_zones` | `target_elevation` | Raises elevation for SLR adaptation |
| `enhance_sediment_supply` | `sediment_addition_rate` | Models sediment addition |

### Scenario Outputs

```
outputs/restoration_scenarios/
├── dems/
│   ├── baseline_dem.tif
│   ├── tidal_restoration_dem.tif
│   ├── riparian_buffer_dem.tif
│   └── full_restoration_dem.tif
├── [scenario_name]/
│   ├── flow_accumulation.tif
│   ├── twi.tif
│   └── carbon_stocks_projected.tif
├── comparisons/
│   ├── tidal_restoration_carbon_change.tif
│   ├── carbon_comparison.png
│   └── multimetric_comparison.png
└── scenario_comparison_summary.csv
```

### Example Comparison Output

```
Scenario Comparison Summary:
─────────────────────────────────────────────────────
Scenario                    | ΔCarbon  | ΔWetness | ΔFlood Area
                            | (Mg/ha)  | (TWI)    | (ha)
─────────────────────────────────────────────────────
Tidal Restoration           | +25.0    | +0.82    | +8.5
Riparian Buffer             | +15.0    | +0.15    | -1.2
Channel Creation            | +8.5     | +0.45    | -2.1
Full Restoration            | +40.0    | +1.05    | +5.8
Climate Adaptation          | +12.0    | -0.08    | -4.2
─────────────────────────────────────────────────────
```

**Interpretation**:
- **Tidal Restoration**: Highest carbon gain, but increases flood area (by design)
- **Riparian Buffer**: Moderate carbon, reduces flooding
- **Full Restoration**: Maximum combined benefits
- **Climate Adaptation**: Reduces flood risk for future SLR

---

## 🌊 Capabilities

### 1. Hydrological Modeling

#### Flow Accumulation
- **What**: Number of upstream cells draining to each location
- **Uses**: Stream network extraction, watershed delineation
- **Algorithm**: D8 flow direction (WhiteboxTools)

```r
# Flow accumulation threshold for streams
# Higher = only major channels
# Lower = includes minor tributaries
CONFIG_HYDRO$stream_threshold <- 1000  # cells
```

#### Topographic Wetness Index (TWI)
- **What**: `ln(α / tan(β))` where α = drainage area, β = slope
- **Uses**: Identify wet areas, restoration site selection
- **Values**: Higher TWI = wetter conditions

**Typical ranges**:
- TWI < 5: Dry uplands
- TWI 5-10: Moderate wetness
- TWI > 10: Saturated areas (ideal for wetland restoration)

#### Stream Network Extraction
- **Method**: Flow accumulation threshold
- **Output**: Binary stream network raster
- **Applications**: Riparian buffer design, channel restoration planning

### 2. Sediment Transport Modeling

#### RUSLE (Revised Universal Soil Loss Equation)
**Formula**: `A = R × K × LS × C × P`

Where:
- **A** = Soil loss (tons/ha/year)
- **R** = Rainfall erosivity (MJ·mm/ha·h·year)
  - BC Coast typical: 150-250
  - Interior BC: 50-100
- **K** = Soil erodibility (0-1)
  - Sandy soils: 0.05-0.15
  - Loamy soils: 0.25-0.40
  - Clay soils: 0.15-0.25
- **LS** = Slope length and steepness factor (calculated from DEM)
- **C** = Cover management factor (0-1)
  - Dense vegetation: 0.001-0.01
  - Bare soil: 1.0
- **P** = Support practice factor (typically 1.0 for natural areas)

**Sediment Deposition**:
- Wetlands trap sediment proportional to TWI
- High TWI = high deposition potential
- Critical for blue carbon accretion!

### 3. Tidal Flooding & Sea Level Rise

#### Inundation Modeling
- **Method**: Simple bathtub model (DEM < water level)
- **Scenarios**:
  - **MHW** (Mean High Water): Regular tidal flooding
  - **MHHW** (Mean Higher High Water): Spring tide flooding
  - **Storm**: MHHW + storm surge
  - **SLR**: MHHW + sea level rise increments

**Limitations**:
- Does not account for wave action
- Does not model dynamic flow
- Best for screening-level analysis

**For detailed hydraulic modeling**, export DEMs to:
- HEC-RAS 2D (free, USACE)
- MIKE 21 (commercial, DHI)
- Delft3D (free, Deltares)

#### Carbon at Risk
- Intersects inundation maps with carbon stock rasters
- Calculates total carbon in vulnerable areas
- **Important**: Some inundation may be beneficial (tidal restoration)!

### 4. Riparian Buffer Analysis

#### Sediment Trapping
**Model**: Exponential decay with distance

```r
Trap efficiency = 0.70 per 10m buffer
Total trapping = 1 - (1 - 0.70)^(width/10)

Examples:
  10m buffer: 70% sediment removed
  20m buffer: 91% sediment removed
  30m buffer: 97% sediment removed
```

#### Carbon Sequestration
**Rates** (Mg C/ha/year):
- Young restoration (0-5 years): 0.5-1.0
- Established restoration (5-15 years): 1.5-2.5
- Mature (15+ years): 0.5-1.5 (asymptotic)

**Default**: 1.5 Mg C/ha/year (conservative mid-range)

#### Nutrient Removal
- Nitrogen: 40-80% removal in vegetated buffers
- Phosphorus: 50-90% removal (sorption + uptake)
- **Note**: Currently not quantified in Module 11 but can be added

### 5. 3D Visualization

#### Rayshader Rendering
**Key parameters**:

```r
z_scale = 5        # Vertical exaggeration
                   # 1 = true scale (flat for low-relief sites)
                   # 5-10 = typical for visualization
                   # 20+ = extreme exaggeration

theta = 45         # Viewing azimuth (degrees)
phi = 45           # Viewing elevation (degrees)
zoom = 0.75        # Camera zoom (0.5-1.5)
fov = 0            # Field of view (0 = orthographic)
```

**Rendering quality**:
- `windowsize = c(800, 600)` - Fast preview
- `windowsize = c(1600, 1200)` - Standard
- `windowsize = c(3200, 2400)` - High-res publication

#### Overlays
- **Carbon stocks**: Blue (low) → Green (high)
- **Sediment**: Yellow (low) → Red (high)
- **Inundation**: Blue transparency overlay
- **Vegetation**: Color by ecosystem type

---

## 📁 Outputs

### Raster Outputs (GeoTIFF)

All outputs are saved as GeoTIFFs and can be opened in:
- **R**: `terra::rast("file.tif")`
- **QGIS**: Drag and drop into QGIS
- **ArcGIS Pro**: Add data
- **Python**: `rasterio.open("file.tif")`

### Key Raster Layers

| Layer | Units | Description |
|-------|-------|-------------|
| `flow_accumulation.tif` | cells | Upstream drainage area |
| `topographic_wetness_index.tif` | - | Wetness potential (higher = wetter) |
| `stream_network.tif` | binary | 1 = stream, 0 = no stream |
| `soil_loss_rusle.tif` | tons/ha/year | Erosion rate |
| `deposition_potential.tif` | tons/ha/year | Sediment deposition |
| `inundation_*.tif` | binary | 1 = flooded, 0 = dry |
| `sediment_trapped_*.tif` | tons/ha/year | Sediment trapped by buffer |
| `carbon_stocks_projected.tif` | Mg C/ha | Carbon after restoration |

### Summary Tables (CSV)

- `inundation_summary.csv` - Inundation area by scenario
- `buffer_effectiveness_summary.csv` - Buffer performance metrics
- `scenario_comparison_summary.csv` - Multi-metric scenario comparison

### 3D Visualizations (PNG)

- `terrain_2d.png` - 2D hillshade map
- `carbon_stocks_2d.png` - 2D carbon overlay
- `terrain_3d_view*.png` - 3D perspective views
- `buffer_effectiveness_curve.png` - Buffer performance plots
- `carbon_comparison.png` - Scenario carbon comparison
- `multimetric_comparison.png` - 4-panel comparison

---

## 🔗 Integration with Other Software

### QGIS Workflow

1. **Load outputs**:
   ```
   Layers → Add Raster Layer → Navigate to outputs/
   ```

2. **Visualize**:
   - Use "Singleband pseudocolor" for continuous rasters
   - Use "Paletted/Unique values" for discrete rasters (streams, inundation)

3. **3D View**:
   - View → 3D Map Views → New 3D Map View
   - Configure → Terrain → Elevation: `elevation.tif`
   - Add carbon/sediment as texture overlay

4. **Export**:
   - Project → Import/Export → Export Map to PDF

### ArcGIS Pro Workflow

1. **Load DEMs**:
   - Add Data → outputs/restoration_scenarios/dems/

2. **Surface Analysis**:
   - Spatial Analyst Tools → Surface → Viewshed/Profile
   - Compare baseline vs. restoration DEMs

3. **3D Visualization**:
   - Insert → New Map → New Local Scene
   - Elevation Source → `*_dem.tif`
   - Symbology → Carbon stocks as draped texture

4. **Animation**:
   - View → Animation → Create flythrough

### AutoCAD Civil 3D Workflow

1. **Import DEM**:
   - Insert → Import → DEM
   - Select `*_dem.tif`
   - Creates TIN surface

2. **Design Restoration**:
   - Grading Tools → Create Grading
   - Design tidal channels, buffers, excavation

3. **Calculate Volumes**:
   - Surfaces → Volume Dashboard
   - Cut/fill volumes for earthwork estimates

4. **Export**:
   - Export → DEM → Restored surface as GeoTIFF
   - Re-import to R for updated modeling!

### Python Integration

```python
import rasterio
import numpy as np
import matplotlib.pyplot as plt

# Read DEM
with rasterio.open('outputs/restoration_scenarios/dems/baseline_dem.tif') as src:
    dem = src.read(1)
    meta = src.meta

# Read carbon stocks
with rasterio.open('outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif') as src:
    carbon = src.read(1)

# Calculate carbon change
carbon_proj = carbon + 25  # Add 25 Mg C/ha from restoration

# Save
with rasterio.open('carbon_projected_python.tif', 'w', **meta) as dst:
    dst.write(carbon_proj, 1)

# Visualize
plt.imshow(carbon_proj, cmap='Greens')
plt.colorbar(label='Carbon (Mg C/ha)')
plt.title('Projected Carbon Stocks')
plt.show()
```

### Google Earth Engine (Advanced)

Export Module 11 outputs to Earth Engine Assets:

```javascript
// Upload outputs as assets, then combine with satellite imagery

var carbonStocks = ee.Image('users/yourname/carbon_stocks_projected');
var dem = ee.Image('users/yourname/baseline_dem');
var sentinel = ee.ImageCollection('COPERNICUS/S2_SR')
  .filterBounds(roi)
  .filterDate('2024-01-01', '2024-12-31')
  .median();

// Overlay
var viz = sentinel.visualize({bands: ['B4', 'B3', 'B2'], min: 0, max: 3000});
var carbonViz = carbonStocks.visualize({palette: ['blue', 'green', 'yellow'], min: 50, max: 200});

Map.addLayer(viz);
Map.addLayer(carbonViz, {}, 'Carbon Stocks', 0.6);
```

---

## 🎓 Advanced Usage

### Custom RUSLE Parameters

#### Site-Specific R-Factor (Rainfall Erosivity)

Calculate from rainfall data:

```r
# Load annual rainfall (mm)
rainfall_mm <- 1200  # Example: Vancouver area

# Simplified R-factor estimation for BC
# From Pacific Climate Impacts Consortium data
R_factor <- 0.15 * rainfall_mm + 50

# Typical BC ranges:
# Coast: 150-250 (high rainfall)
# Interior: 50-100 (low rainfall)
# Mountains: 100-150 (moderate)

CONFIG_SEDIMENT$R_factor <- R_factor
```

#### Soil-Specific K-Factor

Load from soil map:

```r
# Example: Load soil texture map from GEE or provincial soils data
soil_texture <- rast("data_raw/soil_texture_map.tif")

# Define K-factors by texture class
# 1 = Sand, 2 = Loam, 3 = Clay
K_lookup <- c(0.10, 0.30, 0.20)

K_raster <- app(soil_texture, function(x) K_lookup[x])
writeRaster(K_raster, "data_processed/K_factor_map.tif")

# Then modify Module 11 to read K_raster instead of using default
```

### Custom Tidal Datums

If you have local tide gauge data:

```r
# Example: Adjust tidal datums for your site
# Data from tides.gc.ca (Canadian Hydrographic Service)

CONFIG_TIDAL$mhw_elevation <- 2.35   # Site-specific MHW (m)
CONFIG_TIDAL$mhhw_elevation <- 2.85  # Site-specific MHHW (m)
CONFIG_TIDAL$tidal_range <- 3.45     # Mean range (m)

# If DEM is in different datum, convert:
# Example: DEM in CGVD2013, tides in Chart Datum
CONFIG_TIDAL$datum_offset <- -1.20  # Offset to convert (m)
```

### Tide Prediction Integration

Use `TideHarmonics` or `rtide` for dynamic tidal modeling:

```r
library(rtide)

# Predict tides for your location
station <- "Point Atkinson"  # BC coast example
start_date <- as.Date("2024-01-01")
end_date <- as.Date("2024-12-31")

tides <- tide_height(station, from = start_date, to = end_date)

# Extract statistics
mhw <- quantile(tides$tide_height, 0.75)
mhhw <- quantile(tides$tide_height, 0.95)

cat(sprintf("Site: %s\n", station))
cat(sprintf("MHW: %.2f m\n", mhw))
cat(sprintf("MHHW: %.2f m\n", mhhw))

# Use these in CONFIG_TIDAL
```

### Animations and Flythroughs

Create 3D animations (requires `av` package):

```r
library(rayshader)
library(av)

# Load terrain
elev_matrix <- raster_to_matrix(dem)
base_map <- elev_matrix %>%
  sphere_shade(texture = "desert") %>%
  add_shadow(ray_shade(elev_matrix, zscale = 5))

# Render 3D
plot_3d(base_map, elev_matrix, zscale = 5)

# Create circular flythrough
angles <- seq(0, 360, by = 2)

for (i in seq_along(angles)) {
  render_camera(theta = angles[i], phi = 45, zoom = 0.7)
  render_snapshot(filename = sprintf("frames/frame_%04d.png", i))
}

# Combine into video
av::av_encode_video(
  list.files("frames", "frame_.*\\.png", full.names = TRUE),
  output = "outputs/3d_models/animations/flythrough.mp4",
  framerate = 30
)

rgl::rgl.close()
```

### Multi-Scenario Carbon Trajectories

Model carbon accumulation over time:

```r
# Define trajectory model
carbon_trajectory <- function(baseline_carbon, accretion_rate, years, model = "exponential") {

  if (model == "exponential") {
    # Fast initial accumulation, slowing over time
    k <- 0.1  # Rate constant
    carbon <- baseline_carbon + accretion_rate * (1 - exp(-k * years)) / k

  } else if (model == "linear") {
    # Constant accumulation
    carbon <- baseline_carbon + accretion_rate * years

  } else if (model == "logistic") {
    # S-shaped curve with asymptote
    K <- baseline_carbon + 100  # Carrying capacity
    r <- 0.2  # Growth rate
    carbon <- K / (1 + ((K - baseline_carbon) / baseline_carbon) * exp(-r * years))
  }

  return(carbon)
}

# Apply to scenarios
years_sequence <- 0:50  # 50-year projection
scenarios_names <- c("Baseline", "Tidal Restoration", "Full Restoration")
accretion_rates <- c(0, 2.5, 4.0)  # Mg C/ha/year

trajectory_df <- data.frame()

for (i in seq_along(scenarios_names)) {
  for (year in years_sequence) {
    carbon <- carbon_trajectory(
      baseline_carbon = 80,  # Mg C/ha
      accretion_rate = accretion_rates[i],
      years = year,
      model = "exponential"
    )

    trajectory_df <- rbind(trajectory_df, data.frame(
      scenario = scenarios_names[i],
      year = year,
      carbon_mg_ha = carbon
    ))
  }
}

# Plot trajectories
library(ggplot2)

ggplot(trajectory_df, aes(x = year, y = carbon_mg_ha, color = scenario)) +
  geom_line(size = 1.5) +
  labs(
    title = "Carbon Accumulation Trajectories",
    x = "Years Since Restoration",
    y = "Carbon Stock (Mg C/ha)",
    color = "Scenario"
  ) +
  theme_minimal() +
  scale_color_manual(values = c("gray", "darkgreen", "blue"))

ggsave("outputs/restoration_scenarios/carbon_trajectories.png",
       width = 10, height = 6, dpi = 300)
```

---

## 🐛 Troubleshooting

### Issue: "WhiteboxTools not found"

**Solution**:
```r
library(whitebox)
install_whitebox()
wbt_version()  # Should show version number
```

If still fails, manually download from: https://www.whiteboxgeo.com/download-whiteboxtools/

### Issue: "3D rendering window doesn't open"

**Cause**: No display available (common on remote servers)

**Solution 1** - Disable 3D rendering:
```r
CONFIG_3D$render_3d <- FALSE
CONFIG_3D$save_snapshots <- FALSE
```

**Solution 2** - Use offscreen rendering:
```r
library(rgl)
options(rgl.useNULL = TRUE)  # Render without opening window
```

### Issue: "DEM not found"

**Solution**: Provide DEM or download automatically:
```r
library(elevatr)
library(sf)

# Define study area (example coordinates)
bbox <- st_bbox(c(xmin = -123.5, ymin = 48.5, xmax = -123.3, ymax = 48.7), crs = 4326)
bbox_sf <- st_as_sfc(bbox)

# Fetch DEM
dem <- get_elev_raster(bbox_sf, z = 13, src = "aws")

# Save
writeRaster(rast(dem), "data_raw/gee_covariates/elevation.tif", overwrite = TRUE)
```

### Issue: "Memory error with large rasters"

**Solution**: Reduce resolution or process in tiles:
```r
# Resample to lower resolution
dem_coarse <- aggregate(dem, fact = 2, fun = "mean")

# Or set max memory
terra::terraOptions(memfrac = 0.8)  # Use 80% of available RAM
```

### Issue: "Inundation maps look unrealistic"

**Cause**: DEM not in correct tidal datum

**Solution**: Check and correct datum:
```r
# Check DEM elevation range
print(global(dem, "range", na.rm = TRUE))

# If elevations seem too high/low, adjust:
CONFIG_TIDAL$datum_offset <- -2.0  # Example: lower by 2m

# Or directly adjust DEM:
dem_corrected <- dem - 2.0
writeRaster(dem_corrected, "data_raw/gee_covariates/elevation_corrected.tif")
```

### Issue: "Scenario builder produces NaN values"

**Cause**: Division by zero or missing data

**Solution**: Check inputs:
```r
# Check for NA values
print(global(dem, "isNA"))

# Fill NA values
dem_filled <- ifel(is.na(dem), mean(dem, na.rm = TRUE), dem)

# Check for zeros in denominator (e.g., slope)
slope_safe <- ifel(slope == 0, 0.001, slope)
```

---

## 📚 References & Resources

### Documentation
- **WhiteboxTools**: https://www.whiteboxgeo.com/manual/wbt_book/
- **rayshader**: https://www.rayshader.com/
- **terra**: https://rspatial.org/terra/

### Hydrological Modeling
- **RUSLE**: Renard et al. (1997). USDA Agriculture Handbook 703
- **TWI**: Beven & Kirkby (1979). *Hydrological Sciences Bulletin* 24:43-69

### Blue Carbon & Coastal Processes
- **Sediment Accretion**: Ouyang & Lee (2014). *Ecological Engineering* 70:45-56
- **Tidal Marsh Restoration**: Burden et al. (2019). *PLOS ONE* 14:e0221090
- **Sea Level Rise**: Schuerch et al. (2018). *Nature* 561:231-234

### Software
- **QGIS**: https://qgis.org/
- **HEC-RAS**: https://www.hec.usace.army.mil/software/hec-ras/
- **Delft3D**: https://oss.deltares.nl/web/delft3d

### Canadian Resources
- **Tides**: https://tides.gc.ca/
- **BC Soils**: https://catalogue.data.gov.bc.ca/dataset/soil-survey-spatial-data
- **Pacific Climate**: https://pacificclimate.org/

---

## 📞 Support

**Questions or issues?**
1. Check troubleshooting section above
2. Review examples in script comments
3. Open an issue on GitHub
4. Email: [your-email@domain.com]

---

**Last Updated**: 2024-11-17
**Module Version**: 1.0
**Compatible with**: Blue Carbon Workflow v1.0

---

🌊 **Happy modeling!** 🗻🌱
