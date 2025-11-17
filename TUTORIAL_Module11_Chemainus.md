# Tutorial: 3D Ecosystem Modeling for Chemainus Estuary

**A complete hands-on guide for Module 11 using your Chemainus Estuary blue carbon project**

---

## 📍 Project Context

**Location**: Chemainus Estuary, British Columbia, Canada (49.69°N, 123.73°W)
**Ecosystem**: Coastal salt marsh and tidal wetlands
**Project Goal**: Assess blue carbon restoration potential and model restoration scenarios
**Tidal Range**: ~3.5 meters (meso-tidal)
**Elevation Range**: 0-15 meters CGVD2013

---

## 📋 Table of Contents

- [Part 1: Setup and Installation](#part-1-setup-and-installation)
- [Part 2: Baseline Analysis](#part-2-baseline-analysis)
- [Part 3: Hydrological Modeling](#part-3-hydrological-modeling)
- [Part 4: Tidal Flooding Scenarios](#part-4-tidal-flooding-scenarios)
- [Part 5: Restoration Scenarios](#part-5-restoration-scenarios)
- [Part 6: Interpreting Results](#part-6-interpreting-results)
- [Part 7: Integration with VM0033](#part-7-integration-with-vm0033)

---

## Part 1: Setup and Installation

### Step 1.1: Install Required Packages

**Time**: 5-10 minutes

```r
# Set working directory to your project folder
setwd("/path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon")

# Install 3D and hydrology packages
source("00a_install_packages_3d_hydro.R")
```

**Expected output**:
```
========================================
3D ECOSYSTEM & HYDRO - PACKAGE INSTALLATION
========================================

3D Visualization packages: 5
Hydrological modeling packages: 7
Coastal/tidal packages: 3
Terrain analysis packages: 4
Total new packages: 19

Installing 3D Visualization Packages:
  [1/5] ✓ rayshader (already installed)
  [2/5] Installing rgl... ✓
  [3/5] Installing plotly... ✓
  ...

✓✓✓ SUCCESS! All critical packages installed.
```

### Step 1.2: Verify WhiteboxTools Installation

```r
library(whitebox)

# Install WhiteboxTools executable
install_whitebox()

# Verify
wbt_version()
```

**Expected output**:
```
[1] "WhiteboxTools v2.3.0 by Dr. John B. Lindsay (c) 2017-2024"
```

### Step 1.3: Test 3D Rendering

```r
library(rayshader)

# Quick test with built-in volcano dataset
volcano %>%
  sphere_shade(texture = "desert") %>%
  plot_map()
```

**Expected**: A colored elevation map appears

✅ **If you see the volcano map, you're ready to proceed!**

---

## Part 2: Baseline Analysis

### Step 2.1: Check Required Data

Verify you have the required files from previous modules:

```r
# Check for required files
required_files <- c(
  "data_raw/gee_covariates/elevation.tif",
  "data_raw/gee_covariates/slope.tif",
  "data_raw/field_cores.csv",
  "outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif"
)

for (file in required_files) {
  exists <- file.exists(file)
  cat(sprintf("%s %s\n", ifelse(exists, "✓", "✗"), file))
}
```

**If elevation.tif is missing**, we can download it:

```r
library(elevatr)
library(sf)
library(terra)

# Chemainus Estuary bounding box
bbox <- st_bbox(c(
  xmin = -123.75,
  ymin = 49.67,
  xmax = -123.70,
  ymax = 49.71
), crs = 4326)

bbox_sf <- st_as_sfc(bbox)

# Download DEM (zoom 13 = ~30m resolution)
dem_download <- get_elev_raster(bbox_sf, z = 13, src = "aws")

# Convert to terra and save
dem <- rast(dem_download)
dir.create("data_raw/gee_covariates", recursive = TRUE, showWarnings = FALSE)
writeRaster(dem, "data_raw/gee_covariates/elevation.tif", overwrite = TRUE)

cat("✓ DEM downloaded for Chemainus Estuary\n")
```

### Step 2.2: Configure for Chemainus Estuary

**Create**: `config_chemainus_module11.R`

```r
# ============================================================================
# CHEMAINUS ESTUARY - MODULE 11 CONFIGURATION
# ============================================================================
# Site-specific parameters for 3D ecosystem modeling

# Tidal datums for Chemainus (from CHS Station 7907)
# Source: https://tides.gc.ca/en/stations/7907
CHEMAINUS_TIDAL <- list(
  enable = TRUE,

  # Tidal datums (meters CGVD2013)
  # Note: Approximate conversions from Chart Datum
  mhw_elevation = 2.35,      # Mean High Water
  mhhw_elevation = 2.85,     # Mean Higher High Water
  tidal_range = 3.45,        # Mean tidal range

  # Sea level rise scenarios (meters)
  # Based on BC Provincial SLR guidance (2020)
  slr_scenarios = c(
    0,      # Current (2024)
    0.28,   # 2050 - Low emissions (SSP1-2.6)
    0.46,   # 2050 - High emissions (SSP5-8.5)
    0.98,   # 2100 - Low emissions
    1.63    # 2100 - High emissions
  ),

  # Storm surge for design events
  storm_surge = 1.2,         # 1:100 year event (meters)

  # Datum conversion
  datum_offset = 0           # DEM already in CGVD2013
)

# Sediment transport parameters for Chemainus
CHEMAINUS_SEDIMENT <- list(
  enable = TRUE,
  method = "RUSLE",

  # Rainfall erosivity for East Vancouver Island
  # From Pacific Climate Impacts Consortium
  R_factor = 180,            # MJ·mm/ha·h·year (moderate rainfall)

  # Soil erodibility (sandy-loam coastal soils)
  K_factor_default = 0.28,

  # Cover management by ecosystem
  C_factor_by_stratum = list(
    "Upper Marsh" = 0.001,     # Dense Distichlis/Carex
    "Mid Marsh" = 0.002,       # Mixed halophytes
    "Lower Marsh" = 0.003,     # Spartina/Salicornia
    "Underwater Vegetation" = 0.0001,  # Zostera (seagrass)
    "Open Water" = 1.0         # Tidal channels
  ),

  P_factor = 1.0,              # No conservation practices
  deposition_model = TRUE
)

# Riparian buffer analysis
CHEMAINUS_BUFFER <- list(
  enable = TRUE,

  # Test widths (meters) - based on BC Riparian Areas Regulation
  buffer_widths = c(15, 30, 50),  # Provincial recommendations

  # Effectiveness (from BC coastal studies)
  sediment_trap_efficiency = 0.75,      # 75% per 10m
  nutrient_removal_rate = 0.60,         # 60% N/P removal

  # Carbon sequestration (Mg C/ha/year)
  # From Burden et al. 2019 (BC salt marsh restoration)
  carbon_sequestration_rate = 1.8
)

# Hydrological modeling
CHEMAINUS_HYDRO <- list(
  flow_accumulation = TRUE,
  wetness_index = TRUE,
  stream_network = TRUE,
  watershed_delineation = FALSE,

  # Stream threshold
  # Lower = more detailed network (use 500 for small estuaries)
  stream_threshold = 500,    # cells

  slope_percent = TRUE
)

# 3D Visualization
CHEMAINUS_3D <- list(
  render_3d = TRUE,
  render_resolution = 1200,
  z_scale = 8,               # Higher for flat coastal sites
  water_detect = TRUE,
  save_snapshots = TRUE,
  create_animations = FALSE  # Enable for presentations
)

cat("✓ Chemainus Estuary configuration loaded\n")
cat("  Tidal range: 3.45 m\n")
cat("  MHW elevation: 2.35 m CGVD2013\n")
cat("  R-factor: 180 (moderate rainfall erosivity)\n")
```

**Save this file** in your project root.

### Step 2.3: Quick Visual Check of Your Data

```r
library(terra)
library(sf)

# Load DEM
dem <- rast("data_raw/gee_covariates/elevation.tif")

# Plot
plot(dem, main = "Chemainus Estuary - Elevation (m)")

# Print statistics
cat("\nDEM Statistics:\n")
cat(sprintf("  Resolution: %.1f x %.1f meters\n", res(dem)[1], res(dem)[2]))
cat(sprintf("  Extent: %d x %d cells\n", ncol(dem), nrow(dem)))
cat(sprintf("  Elevation range: %.2f to %.2f m\n",
            global(dem, "min", na.rm = TRUE)[[1]],
            global(dem, "max", na.rm = TRUE)[[1]]))

# Load field cores (if available)
if (file.exists("data_raw/field_cores.csv")) {
  cores <- read.csv("data_raw/field_cores.csv")
  cores_sf <- st_as_sf(cores, coords = c("longitude", "latitude"), crs = 4326)
  cores_sf <- st_transform(cores_sf, crs(dem))

  # Add to plot
  plot(cores_sf, add = TRUE, pch = 19, col = "red", cex = 1.5)

  cat(sprintf("  Field cores: %d locations\n", nrow(cores)))
}

# Load carbon stocks (if available)
if (file.exists("outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif")) {
  carbon <- rast("outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif")

  plot(carbon, main = "Carbon Stocks (Mg C/ha)")

  cat(sprintf("  Mean carbon: %.1f Mg C/ha\n",
              global(carbon, "mean", na.rm = TRUE)[[1]]))
}
```

**Expected output**:
```
DEM Statistics:
  Resolution: 30.0 x 30.0 meters
  Extent: 185 x 148 cells
  Elevation range: 0.12 to 14.85 m
  Field cores: 24 locations
  Mean carbon: 82.3 Mg C/ha
```

---

## Part 3: Hydrological Modeling

### Step 3.1: Run Module 11 with Chemainus Configuration

```r
# Load project configuration
source("blue_carbon_config.R")

# Load Chemainus-specific configuration
source("config_chemainus_module11.R")

# Override default configs with Chemainus values
CONFIG_TIDAL <- CHEMAINUS_TIDAL
CONFIG_SEDIMENT <- CHEMAINUS_SEDIMENT
CONFIG_BUFFER <- CHEMAINUS_BUFFER
CONFIG_HYDRO <- CHEMAINUS_HYDRO
CONFIG_3D <- CHEMAINUS_3D

# Run Module 11
source("11_3d_ecosystem_modeling.R")
```

**Expected runtime**: 5-15 minutes depending on data size

### Step 3.2: Examine Hydrological Outputs

```r
library(terra)
library(ggplot2)

# Load outputs
flow_accum <- rast("outputs/hydrology/flow_accumulation.tif")
twi <- rast("outputs/hydrology/topographic_wetness_index.tif")
streams <- rast("outputs/hydrology/stream_network.tif")

# Visualize flow accumulation
plot(log10(flow_accum + 1),
     main = "Flow Accumulation (log scale)",
     col = hcl.colors(100, "Blues", rev = TRUE))

# Visualize TWI
plot(twi,
     main = "Topographic Wetness Index",
     col = hcl.colors(100, "Spectral", rev = FALSE))

# Overlay streams
plot(dem, main = "Stream Network on DEM")
plot(streams, add = TRUE, col = "blue", legend = FALSE)

# Statistics
cat("\nHydrological Metrics:\n")
cat(sprintf("  Stream cells: %d\n",
            global(streams, "sum", na.rm = TRUE)[[1]]))

stream_length_km <- global(streams, "sum", na.rm = TRUE)[[1]] * res(dem)[1] / 1000
cat(sprintf("  Stream length: %.2f km\n", stream_length_km))

cat(sprintf("  Mean TWI: %.2f\n",
            global(twi, "mean", na.rm = TRUE)[[1]]))

# Identify high wetness areas (TWI > 75th percentile)
twi_threshold <- global(twi, "quantile", probs = 0.75, na.rm = TRUE)[[1]]
wet_areas <- twi > twi_threshold
wet_area_ha <- global(wet_areas, "sum", na.rm = TRUE)[[1]] * res(dem)[1]^2 / 10000

cat(sprintf("  High wetness areas: %.1f ha (TWI > %.2f)\n",
            wet_area_ha, twi_threshold))
cat("  → Priority sites for wetland restoration\n")
```

**Example output**:
```
Hydrological Metrics:
  Stream cells: 342
  Stream length: 10.26 km
  Mean TWI: 6.84
  High wetness areas: 8.3 ha (TWI > 9.12)
  → Priority sites for wetland restoration
```

### Step 3.3: Interpret TWI for Restoration Planning

**TWI Zones for Chemainus**:

```r
# Create TWI classification
twi_class <- classify(twi,
  rcl = matrix(c(
    -Inf, 5, 1,    # Dry uplands
    5, 8, 2,       # Moderate wetness
    8, 11, 3,      # Wet areas
    11, Inf, 4     # Saturated zones
  ), ncol = 3, byrow = TRUE))

# Define zone names
twi_zones <- c("Dry Uplands", "Moderate", "Wet Areas", "Saturated")

# Calculate areas
twi_areas <- data.frame(
  zone = twi_zones,
  area_ha = numeric(4)
)

for (i in 1:4) {
  twi_areas$area_ha[i] <- global(twi_class == i, "sum", na.rm = TRUE)[[1]] *
                          res(dem)[1]^2 / 10000
}

print(twi_areas)

# Restoration suitability
cat("\nRestoration Suitability:\n")
cat("  Wet + Saturated zones:", sum(twi_areas$area_ha[3:4]), "ha\n")
cat("  → High potential for tidal wetland restoration\n")
```

**Example output**:
```
           zone area_ha
1  Dry Uplands    12.3
2     Moderate    25.8
3    Wet Areas    18.5
4    Saturated     6.2

Restoration Suitability:
  Wet + Saturated zones: 24.7 ha
  → High potential for tidal wetland restoration
```

---

## Part 4: Tidal Flooding Scenarios

### Step 4.1: Review Tidal Inundation Results

```r
# Load inundation maps
mhw <- rast("outputs/tidal/inundation_MHW.tif")
mhhw <- rast("outputs/tidal/inundation_MHHW.tif")
storm <- rast("outputs/tidal/inundation_Storm.tif")

# Load SLR scenarios
slr_0p46m <- rast("outputs/tidal/inundation_SLR_0p46m.tif")  # 2050 high
slr_1p63m <- rast("outputs/tidal/inundation_SLR_1p63m.tif")  # 2100 high

# Visualize current scenarios
par(mfrow = c(2, 2))

plot(dem, main = "Elevation", col = terrain.colors(100))
plot(mhw, main = "MHW Inundation", col = c("gray90", "lightblue"))
plot(mhhw, main = "MHHW Inundation", col = c("gray90", "blue"))
plot(storm, main = "Storm Surge", col = c("gray90", "darkblue"))
```

### Step 4.2: Calculate Inundation Statistics

```r
# Load summary table
inund_summary <- read.csv("outputs/tidal/inundation_summary.csv")

print(inund_summary)

# Calculate change from current
inund_summary$change_from_mhw_ha <- inund_summary$inundated_area_ha -
                                     inund_summary$inundated_area_ha[1]
inund_summary$change_pct <- (inund_summary$change_from_mhw_ha /
                             inund_summary$inundated_area_ha[1]) * 100

print(inund_summary[, c("scenario", "water_level_m", "inundated_area_ha", "change_pct")])
```

**Example output**:
```
      scenario water_level_m inundated_area_ha change_pct
1          MHW          2.35             18.42       0.00
2         MHHW          2.85             22.15      20.25
3        Storm          4.05             31.28      69.85
4  SLR_0p28m          3.13             24.73      34.26
5  SLR_0p46m          3.31             27.18      47.56
6  SLR_0p98m          3.83             35.62      93.43
7  SLR_1p63m          4.48             46.27     151.25
```

**Interpretation**:
- Current regular flooding (MHW): 18.4 ha
- By 2050 (high emissions, +0.46m): 27.2 ha (+47%)
- By 2100 (high emissions, +1.63m): 46.3 ha (+151%)
- **Action**: Design restoration to accommodate 2050 scenario

### Step 4.3: Carbon at Risk Assessment

```r
# Load carbon stocks
carbon <- rast("outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif")

# Resample carbon to match DEM resolution
carbon_resampled <- resample(carbon, dem, method = "bilinear")

# Calculate carbon at risk for each SLR scenario
carbon_risk <- data.frame(
  scenario = character(),
  carbon_at_risk_mg = numeric(),
  stringsAsFactors = FALSE
)

slr_scenarios <- c("MHW", "SLR_0p46m", "SLR_1p63m")

for (scenario in slr_scenarios) {
  inund <- rast(paste0("outputs/tidal/inundation_", scenario, ".tif"))

  # Mask carbon by inundation
  carbon_flooded <- mask(carbon_resampled, inund, maskvalues = 0)

  # Calculate total (Mg C)
  total_carbon <- global(carbon_flooded, "sum", na.rm = TRUE)[[1]] *
                  res(carbon_resampled)[1]^2 / 10000

  carbon_risk <- rbind(carbon_risk, data.frame(
    scenario = scenario,
    carbon_at_risk_mg = total_carbon
  ))
}

print(carbon_risk)

# Additional carbon exposed by SLR
carbon_risk$additional_mg <- carbon_risk$carbon_at_risk_mg - carbon_risk$carbon_at_risk_mg[1]

cat("\n┌─────────────────────────────────────────────┐\n")
cat("│ CARBON AT RISK - CHEMAINUS ESTUARY         │\n")
cat("├─────────────────────────────────────────────┤\n")
cat(sprintf("│ Current (MHW):        %8.0f Mg C        │\n", carbon_risk$carbon_at_risk_mg[1]))
cat(sprintf("│ 2050 (+0.46m SLR):    %8.0f Mg C (+%3.0f%%)│\n",
            carbon_risk$carbon_at_risk_mg[2],
            (carbon_risk$additional_mg[2] / carbon_risk$carbon_at_risk_mg[1]) * 100))
cat(sprintf("│ 2100 (+1.63m SLR):    %8.0f Mg C (+%3.0f%%)│\n",
            carbon_risk$additional_mg[3],
            (carbon_risk$additional_mg[3] / carbon_risk$carbon_at_risk_mg[1]) * 100))
cat("└─────────────────────────────────────────────┘\n")
cat("\n⚠️  Note: Coastal wetlands naturally accumulate sediment\n")
cat("   and accrete vertically to keep pace with SLR.\n")
cat("   This analysis shows potential vulnerability without\n")
cat("   accounting for accretion.\n")
```

---

## Part 5: Restoration Scenarios

### Step 5.1: Customize Scenarios for Chemainus

Edit `11b_restoration_scenario_builder.R` to add a Chemainus-specific scenario:

```r
# Add this to SCENARIO_DEFINITIONS in 11b_restoration_scenario_builder.R

  chemainus_dike_breach = list(
    name = "Chemainus Dike Breach Restoration",
    description = "Remove agricultural dike and restore tidal marsh",
    modifications = list(
      list(
        type = "remove_dike",
        elevation_adjust = -1.2,  # Lower by 1.2m to MHW level
        description = "Breach dike at 3 locations for tidal flow"
      ),
      list(
        type = "vegetation_change",
        new_stratum = "Lower Marsh",
        c_factor = 0.002,
        carbon_accretion_rate = 2.3  # From BC restoration studies
      ),
      list(
        type = "create_buffer",
        target = "streams",
        buffer_width = 30,
        vegetation_type = "Upper Marsh",
        carbon_sequestration_rate = 1.8
      )
    )
  )
```

### Step 5.2: Run Scenario Builder

```r
# Run the scenario builder
source("11b_restoration_scenario_builder.R")
```

**Expected runtime**: 10-20 minutes

### Step 5.3: Compare Scenario Outcomes

```r
# Load comparison summary
comparison <- read.csv("outputs/restoration_scenarios/scenario_comparison_summary.csv")

print(comparison)

# Create comparison plot
library(ggplot2)

# Carbon change plot
p1 <- ggplot(comparison, aes(x = reorder(scenario, carbon_change_mg_ha),
                              y = carbon_change_mg_ha)) +
  geom_col(aes(fill = carbon_change_mg_ha > 0)) +
  scale_fill_manual(values = c("red", "darkgreen"), guide = "none") +
  coord_flip() +
  labs(
    title = "Carbon Change by Restoration Scenario",
    subtitle = "Chemainus Estuary - 10 Year Projection",
    x = NULL,
    y = "Carbon Change (Mg C/ha)"
  ) +
  theme_minimal(base_size = 12)

print(p1)

ggsave("outputs/restoration_scenarios/chemainus_carbon_comparison.png",
       p1, width = 10, height = 6, dpi = 300)

# Multi-metric radar plot
library(fmsb)

# Normalize metrics to 0-100 scale
metrics_scaled <- comparison[, c("carbon_change_mg_ha", "wetness_change",
                                  "flood_area_change_ha")]
metrics_scaled <- apply(metrics_scaled, 2, function(x) {
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE)) * 100
})

# Add max/min rows for radar plot
metrics_radar <- rbind(
  rep(100, ncol(metrics_scaled)),  # Max
  rep(0, ncol(metrics_scaled)),    # Min
  metrics_scaled
)

# Plot
png("outputs/restoration_scenarios/chemainus_multimetric_radar.png",
    width = 2400, height = 2400, res = 300)

radarchart(
  metrics_radar,
  axistype = 1,
  pcol = rainbow(nrow(comparison)),
  plwd = 2,
  plty = 1,
  cglcol = "grey",
  cglty = 1,
  axislabcol = "grey",
  caxislabels = seq(0, 100, 25),
  title = "Multi-Metric Scenario Comparison"
)

legend("topright",
       legend = comparison$scenario,
       col = rainbow(nrow(comparison)),
       lty = 1,
       lwd = 2,
       cex = 0.8)

dev.off()
```

### Step 5.4: Select Optimal Scenario

```r
# Rank scenarios by total carbon benefit
comparison$rank_carbon <- rank(-comparison$total_carbon_mg, na.last = TRUE)

# Rank by wetness improvement (better hydrology)
comparison$rank_wetness <- rank(-comparison$wetness_change, na.last = TRUE)

# Overall rank (lower = better)
comparison$rank_overall <- comparison$rank_carbon + comparison$rank_wetness

comparison_ranked <- comparison[order(comparison$rank_overall), ]

cat("\n┌────────────────────────────────────────────────────┐\n")
cat("│ RECOMMENDED SCENARIO FOR CHEMAINUS ESTUARY         │\n")
cat("├────────────────────────────────────────────────────┤\n")
cat(sprintf("│ Scenario: %-40s │\n", comparison_ranked$scenario[1]))
cat("├────────────────────────────────────────────────────┤\n")
cat(sprintf("│ Carbon gain:        %8.1f Mg C/ha (10 yrs)    │\n",
            comparison_ranked$carbon_change_mg_ha[1]))
cat(sprintf("│ Total carbon:       %8.0f Mg C               │\n",
            comparison_ranked$total_carbon_mg[1]))
cat(sprintf("│ Wetness change:     %8.2f (TWI)              │\n",
            comparison_ranked$wetness_change[1]))
cat(sprintf("│ Flood storage:      %8.1f ha change          │\n",
            comparison_ranked$flood_area_change_ha[1]))
cat("└────────────────────────────────────────────────────┘\n")

# Calculate ecosystem service value (optional)
carbon_price <- 50  # $/tonne CO2e (example price)
co2_to_carbon <- 3.67  # 1 tonne C = 3.67 tonnes CO2

carbon_value <- comparison_ranked$total_carbon_mg[1] * co2_to_carbon * carbon_price

cat(sprintf("\nEstimated carbon credit value: $%.0f CAD (at $%d/tonne CO2e)\n",
            carbon_value, carbon_price))
cat("(10-year accumulation, not accounting for discounting)\n")
```

**Example output**:
```
┌────────────────────────────────────────────────────┐
│ RECOMMENDED SCENARIO FOR CHEMAINUS ESTUARY         │
├────────────────────────────────────────────────────┤
│ Scenario: Chemainus Dike Breach Restoration        │
├────────────────────────────────────────────────────┤
│ Carbon gain:           32.5 Mg C/ha (10 yrs)       │
│ Total carbon:          2845 Mg C                   │
│ Wetness change:         0.94 (TWI)                 │
│ Flood storage:          6.2 ha change              │
└────────────────────────────────────────────────────┘

Estimated carbon credit value: $521,548 CAD (at $50/tonne CO2e)
(10-year accumulation, not accounting for discounting)
```

---

## Part 6: Interpreting Results

### 6.1: Hydrological Interpretation

**Flow Accumulation** (`outputs/hydrology/flow_accumulation.tif`)

```r
# Interpret flow patterns
flow <- rast("outputs/hydrology/flow_accumulation.tif")

# Classify by drainage importance
flow_class <- classify(flow,
  rcl = matrix(c(
    0, 100, 1,       # Headwaters
    100, 500, 2,     # Tributaries
    500, 2000, 3,    # Minor channels
    2000, Inf, 4     # Major channels
  ), ncol = 3, byrow = TRUE))

# Calculate channel areas
channel_classes <- c("Headwaters", "Tributaries", "Minor Channels", "Major Channels")
for (i in 1:4) {
  area <- global(flow_class == i, "sum", na.rm = TRUE)[[1]] * res(flow)[1]^2 / 10000
  cat(sprintf("%s: %.2f ha\n", channel_classes[i], area))
}
```

**Implications for Restoration**:
- **Major channels** (>2000 cells): Primary sediment delivery pathways
- **High TWI + High flow accumulation**: Best sites for tidal channel restoration
- **Low flow areas with high TWI**: Suitable for marsh plain development

### 6.2: Sediment Budget

```r
# Calculate sediment budget
soil_loss <- rast("outputs/sediment/soil_loss_rusle.tif")
deposition <- rast("outputs/sediment/deposition_potential.tif")

# Erosion
total_erosion <- global(soil_loss, "sum", na.rm = TRUE)[[1]] *
                 res(soil_loss)[1]^2 / 10000

# Deposition in wetlands
total_deposition <- global(deposition, "sum", na.rm = TRUE)[[1]] *
                    res(deposition)[1]^2 / 10000

# Sediment delivery ratio
delivery_ratio <- total_deposition / total_erosion

cat("\n┌──────────────────────────────────────┐\n")
cat("│ SEDIMENT BUDGET - CHEMAINUS          │\n")
cat("├──────────────────────────────────────┤\n")
cat(sprintf("│ Erosion:      %8.1f t/year         │\n", total_erosion))
cat(sprintf("│ Deposition:   %8.1f t/year         │\n", total_deposition))
cat(sprintf("│ Delivery:     %7.1f%% to wetlands   │\n", delivery_ratio * 100))
cat("└──────────────────────────────────────┘\n")

# Carbon accumulation from sediment
# Typical BC salt marsh: 1-3% organic carbon in sediment
oc_percent <- 0.02  # 2% organic carbon
carbon_from_sediment <- total_deposition * oc_percent * 0.001  # tonnes to Mg

cat(sprintf("\nCarbon input from sediment: %.1f Mg C/year\n", carbon_from_sediment))
cat("(Supports ongoing blue carbon accumulation)\n")
```

### 6.3: Climate Adaptation Assessment

**Accretion Rate Needed to Keep Pace with SLR**:

```r
# Sea level rise rate for Chemainus
# From BC Provincial assessment (2020)
slr_rate_2050 <- 0.46 / 26  # meters per year (0.46m by 2050)
slr_rate_2100 <- 1.63 / 76  # meters per year (1.63m by 2100)

cat("\n┌────────────────────────────────────────────────┐\n")
cat("│ ACCRETION vs. SEA LEVEL RISE                   │\n")
cat("├────────────────────────────────────────────────┤\n")
cat(sprintf("│ SLR rate (2024-2050): %.1f mm/year             │\n", slr_rate_2050 * 1000))
cat(sprintf("│ SLR rate (2050-2100): %.1f mm/year             │\n", slr_rate_2100 * 1000))
cat("├────────────────────────────────────────────────┤\n")

# Typical BC marsh accretion rates
# From Thom et al. 2018 (Fraser River estuary)
accretion_low <- 3.5    # mm/year (degraded marsh)
accretion_high <- 8.2   # mm/year (healthy marsh)

cat(sprintf("│ Degraded marsh:       %.1f mm/year             │\n", accretion_low))
cat(sprintf("│ Healthy marsh:        %.1f mm/year             │\n", accretion_high))
cat("├────────────────────────────────────────────────┤\n")

# Can marshes keep pace?
if (accretion_high > slr_rate_2050 * 1000) {
  cat("│ ✓ Healthy marshes can keep pace to 2050       │\n")
} else {
  cat("│ ✗ Accretion insufficient - marshes will drown │\n")
}

if (accretion_high > slr_rate_2100 * 1000) {
  cat("│ ✓ Can keep pace to 2100                       │\n")
} else {
  cat("│ ⚠ Uncertain beyond 2050 - monitor needed      │\n")
}
cat("└────────────────────────────────────────────────┘\n")

cat("\nRecommendation: Restore sediment supply pathways\n")
cat("and maintain healthy vegetation to maximize accretion.\n")
```

---

## Part 7: Integration with VM0033

### 7.1: Export Results for VM0033 Reporting

```r
# Create VM0033-specific summary
vm0033_summary <- list(
  project_name = "Chemainus Estuary Blue Carbon Restoration",
  location = "49.69°N, 123.73°W",
  project_area_ha = global(!is.na(dem), "sum", na.rm = TRUE)[[1]] * res(dem)[1]^2 / 10000,

  baseline_carbon_mg_ha = global(carbon, "mean", na.rm = TRUE)[[1]],
  project_carbon_mg_ha = global(carbon, "mean", na.rm = TRUE)[[1]] +
                         comparison_ranked$carbon_change_mg_ha[1],

  carbon_gain_mg_ha_yr = comparison_ranked$carbon_change_mg_ha[1] / 10,

  crediting_period_years = 10,

  total_carbon_credits_mgCO2e = comparison_ranked$total_carbon_mg[1] * 3.67,

  co_benefits = list(
    flood_storage_ha = comparison_ranked$flood_area_change_ha[1],
    sediment_retention_t_yr = total_deposition,
    habitat_area_ha = wet_area_ha
  )
)

# Save as JSON for Module 07 integration
library(jsonlite)
write_json(vm0033_summary,
           "outputs/restoration_scenarios/vm0033_integration.json",
           pretty = TRUE, auto_unbox = TRUE)

cat("✓ VM0033 integration file created\n")
cat("  Location: outputs/restoration_scenarios/vm0033_integration.json\n\n")

# Print summary
cat("┌────────────────────────────────────────────────────────────┐\n")
cat("│ VM0033 SUMMARY - CHEMAINUS ESTUARY RESTORATION PROJECT    │\n")
cat("├────────────────────────────────────────────────────────────┤\n")
cat(sprintf("│ Project area:              %8.1f ha                      │\n",
            vm0033_summary$project_area_ha))
cat(sprintf("│ Baseline carbon:           %8.1f Mg C/ha                │\n",
            vm0033_summary$baseline_carbon_mg_ha))
cat(sprintf("│ Project carbon (Year 10):  %8.1f Mg C/ha                │\n",
            vm0033_summary$project_carbon_mg_ha))
cat(sprintf("│ Carbon gain rate:          %8.2f Mg C/ha/year           │\n",
            vm0033_summary$carbon_gain_mg_ha_yr))
cat("├────────────────────────────────────────────────────────────┤\n")
cat(sprintf("│ TOTAL CREDITS:             %8.0f Mg CO2e               │\n",
            vm0033_summary$total_carbon_credits_mgCO2e))
cat("├────────────────────────────────────────────────────────────┤\n")
cat("│ CO-BENEFITS:                                               │\n")
cat(sprintf("│   Flood storage:           %8.1f ha                      │\n",
            vm0033_summary$co_benefits$flood_storage_ha))
cat(sprintf("│   Sediment retention:      %8.0f t/year                 │\n",
            vm0033_summary$co_benefits$sediment_retention_t_yr))
cat(sprintf("│   Habitat creation:        %8.1f ha                      │\n",
            vm0033_summary$co_benefits$habitat_area_ha))
cat("└────────────────────────────────────────────────────────────┘\n")
```

### 7.2: Create Figures for VM0033 Verification Document

```r
# Create publication-quality figures
library(terra)
library(ggplot2)
library(patchwork)

# Load data
dem <- rast("data_raw/gee_covariates/elevation.tif")
carbon_baseline <- rast("outputs/predictions/rf/carbon_stock_rf_total_0_100cm.tif")
carbon_project <- rast("outputs/restoration_scenarios/chemainus_dike_breach/carbon_stocks_projected.tif")
inundation_slr <- rast("outputs/tidal/inundation_SLR_0p46m.tif")

# Figure 1: Study Area Overview
png("outputs/restoration_scenarios/vm0033_fig1_study_area.png",
    width = 3000, height = 2400, res = 300)

par(mfrow = c(1, 1), mar = c(4, 4, 3, 6))
plot(dem,
     main = "Chemainus Estuary Study Area",
     col = terrain.colors(100),
     xlab = "Easting (m)",
     ylab = "Northing (m)")

# Add field cores
if (exists("cores_sf")) {
  plot(st_geometry(cores_sf), add = TRUE, pch = 21, bg = "red", cex = 1.2)
}

dev.off()

# Figure 2: Carbon Stocks Before/After
png("outputs/restoration_scenarios/vm0033_fig2_carbon_comparison.png",
    width = 4000, height = 2000, res = 300)

par(mfrow = c(1, 2), mar = c(4, 4, 3, 6))

plot(carbon_baseline,
     main = "Baseline Carbon Stocks",
     col = hcl.colors(100, "Greens", rev = FALSE),
     xlab = "Easting (m)",
     ylab = "Northing (m)")

plot(carbon_project,
     main = "Projected Carbon Stocks (Year 10)",
     col = hcl.colors(100, "Greens", rev = FALSE),
     xlab = "Easting (m)",
     ylab = "Northing (m)")

dev.off()

# Figure 3: Carbon Change Map
carbon_change <- carbon_project - carbon_baseline

png("outputs/restoration_scenarios/vm0033_fig3_carbon_change.png",
    width = 3000, height = 2400, res = 300)

plot(carbon_change,
     main = "Carbon Stock Change (Baseline to Year 10)",
     col = hcl.colors(100, "RdYlGn", rev = FALSE),
     xlab = "Easting (m)",
     ylab = "Northing (m)")

dev.off()

# Figure 4: Climate Resilience (SLR)
png("outputs/restoration_scenarios/vm0033_fig4_slr_resilience.png",
    width = 3000, height = 2400, res = 300)

plot(dem,
     main = "Sea Level Rise Vulnerability (2050, +0.46m)",
     col = terrain.colors(100),
     xlab = "Easting (m)",
     ylab = "Northing (m)")

plot(inundation_slr,
     add = TRUE,
     col = c(NA, rgb(0, 0, 1, 0.5)),
     legend = FALSE)

legend("topright",
       legend = c("Dry land", "Inundated"),
       fill = c("gray", rgb(0, 0, 1, 0.5)),
       bg = "white")

dev.off()

cat("✓ VM0033 figures saved to outputs/restoration_scenarios/\n")
```

### 7.3: Create 3D Visualization for Stakeholders

```r
library(rayshader)

# Load terrain and carbon
elev_matrix <- raster_to_matrix(dem)
carbon_matrix <- raster_to_matrix(resample(carbon_project, dem))

# Normalize carbon for overlay
carbon_norm <- (carbon_matrix - min(carbon_matrix, na.rm = TRUE)) /
               (max(carbon_matrix, na.rm = TRUE) - min(carbon_matrix, na.rm = TRUE))

# Create color overlay (green gradient)
carbon_colors <- array(0, dim = c(nrow(carbon_norm), ncol(carbon_norm), 3))
carbon_colors[,,1] <- 0
carbon_colors[,,2] <- carbon_norm
carbon_colors[,,3] <- carbon_norm * 0.3

# Render base
base_map <- elev_matrix %>%
  sphere_shade(texture = "desert") %>%
  add_shadow(ray_shade(elev_matrix, zscale = 8), 0.5) %>%
  add_overlay(carbon_colors, alphalayer = 0.6)

# 3D render with labels
plot_3d(
  base_map,
  elev_matrix,
  zscale = 8,
  fov = 0,
  theta = 135,
  phi = 35,
  windowsize = c(1600, 1200),
  zoom = 0.7,
  water = TRUE,
  waterdepth = 2.35,  # MHW level
  wateralpha = 0.5,
  watercolor = "lightblue"
)

# Save snapshot
render_snapshot("outputs/restoration_scenarios/chemainus_3d_restoration.png")

# Rotate for different view
render_camera(theta = 45, phi = 40, zoom = 0.65)
render_snapshot("outputs/restoration_scenarios/chemainus_3d_restoration_view2.png")

rgl::rgl.close()

cat("✓ 3D visualizations saved\n")
```

---

## 🎓 Summary: What You've Accomplished

After completing this tutorial, you now have:

### **Hydrological Analysis**:
- ✅ Flow accumulation and drainage network
- ✅ Topographic Wetness Index (restoration site selection)
- ✅ Stream network (10+ km mapped)
- ✅ High wetness areas identified (~25 ha restoration potential)

### **Sediment Dynamics**:
- ✅ RUSLE soil loss estimates (~450 t/year)
- ✅ Sediment deposition mapping (supports carbon accretion)
- ✅ Riparian buffer effectiveness (75% sediment removal)

### **Climate Adaptation**:
- ✅ Current tidal inundation (MHW, MHHW, storm)
- ✅ Sea level rise scenarios (2050, 2100)
- ✅ Carbon at risk assessment (~1,800 Mg C vulnerable by 2100)
- ✅ Accretion rate evaluation (can marshes keep pace?)

### **Restoration Planning**:
- ✅ 6+ restoration scenarios modeled
- ✅ Carbon sequestration quantified (+32.5 Mg C/ha over 10 years)
- ✅ Optimal scenario identified (Dike Breach Restoration)
- ✅ Ecosystem service co-benefits quantified

### **VM0033 Integration**:
- ✅ Carbon credit potential: ~2,845 Mg CO2e over 10 years
- ✅ Publication-quality figures
- ✅ 3D stakeholder visualizations
- ✅ Verification-ready documentation

---

## 📚 Next Steps

### **For Project Development**:
1. **Field validation**: Verify DEM accuracy with RTK-GPS survey
2. **Sediment cores**: Measure actual accretion rates
3. **Stakeholder engagement**: Present 3D visualizations to community
4. **Engineering design**: Export DEMs to AutoCAD Civil 3D for detailed plans

### **For VM0033 Verification**:
1. **Integrate Module 11 outputs** into Module 07 verification package
2. **Update baseline monitoring** (Module 08/09) with restoration scenarios
3. **Conduct additionality analysis** (Module 10) using scenario comparisons
4. **Prepare verification docs** for third-party auditor

### **For Advanced Analysis**:
1. **Dynamic modeling**: Export to HEC-RAS for detailed hydraulic modeling
2. **Vegetation modeling**: Couple with SLAMM (Sea Level Affecting Marshes Model)
3. **Economic valuation**: Calculate ecosystem service values
4. **Long-term trajectories**: Model 50-100 year carbon accumulation

---

## 🐛 Troubleshooting

**Problem**: DEM elevations seem too high/low

```r
# Check if DEM is in correct datum
summary(values(dem))

# If needed, adjust to CGVD2013
dem_corrected <- dem - 3.5  # Example: subtract offset
writeRaster(dem_corrected, "data_raw/gee_covariates/elevation_corrected.tif")
```

**Problem**: WhiteboxTools fails

```r
# Reinstall
library(whitebox)
install_whitebox(force = TRUE)

# Check path
wbt_exe_path()
```

**Problem**: 3D rendering doesn't work on server

```r
# Disable 3D rendering
CONFIG_3D$render_3d <- FALSE
CONFIG_3D$save_snapshots <- FALSE

# You can still create all other outputs!
```

---

## 📧 Support

Questions about this tutorial?
Email: [your-email]
GitHub Issues: [repo-link]

---

**🌊 Congratulations! You've completed the Module 11 Tutorial for Chemainus Estuary! 🌱**

**Tutorial Version**: 1.0
**Last Updated**: 2024-11-17
**Estimated Time**: 2-4 hours for complete workflow
