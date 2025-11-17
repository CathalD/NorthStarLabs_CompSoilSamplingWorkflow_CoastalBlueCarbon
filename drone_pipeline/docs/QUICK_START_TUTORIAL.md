# Quick Start Tutorial: Berry Harvesting Area Survey

This tutorial walks through a complete drone survey analysis for a traditional berry harvesting area.

## Scenario

A First Nation wants to assess vegetation conditions in a 15-hectare traditional berry harvesting area. They need to:
1. Map current vegetation types
2. Count and measure shrubs and trees
3. Identify areas where conifers are suppressing berry-producing shrubs
4. Generate a report for their Natural Resources Committee

## Prerequisites

- Drone survey completed (150 geotagged images)
- R and required packages installed
- Docker with OpenDroneMap ready

## Step-by-Step Workflow

### Step 1: Organize Your Data (5 minutes)

```bash
# Create project folder
cd drone_pipeline

# Copy your drone images
cp /path/to/drone/photos/*.JPG data_input/images/

# Verify images are present
ls data_input/images/
# Should see: DJI_0001.JPG, DJI_0002.JPG, etc.
```

### Step 2: Configure Project (10 minutes)

Edit `config/drone_config.R`:

```r
# Project Information
PROJECT_NAME <- "Berry_Harvesting_Area_2024"
SURVEY_DATE <- "2024-06-20"
LOCATION_NAME <- "Traditional Berry Grounds - South Plot"
SURVEY_PURPOSE <- "Baseline vegetation mapping for restoration planning"
COMMUNITY_NAME <- "Example First Nation"
SURVEYOR_NAME <- "Jane Smith"

# Coordinate System (choose appropriate for your region)
# British Columbia: EPSG:3005 (BC Albers)
# Alberta: EPSG:3400 (Alberta 10-TM Forest)
# Ontario: EPSG:2958 (NAD83(CSRS) / UTM zone 17N)
OUTPUT_CRS <- "EPSG:3005"

# Classification Settings
CLASSIFICATION_METHOD <- "unsupervised"  # No training data needed
N_CLASSES_UNSUPERVISED <- 5  # Will identify 5 vegetation types

# Tree/Shrub Detection
MIN_TREE_HEIGHT <- 1.5  # meters (includes tall shrubs)
MAX_TREE_HEIGHT <- 30.0  # meters
TREE_DETECTION_METHOD <- "watershed"

# Reports
REPORT_FORMAT <- c("PDF", "HTML")
INCLUDE_INTERACTIVE_MAP <- TRUE
```

Save and close the file.

### Step 3: Run Pipeline (2-4 hours)

```r
# Open R or RStudio
# Navigate to pipeline directory
setwd("/path/to/drone_pipeline")

# Run complete pipeline
source("drone_pipeline_main.R")

# You will see:
# ✓ Configuration loaded
# ✓ Validation passed
# Continue? (y/n): y

# Pipeline will now run all modules automatically
# Progress messages will keep you informed
```

**What's happening:**
- **Module 01** (1-2 hours): ODM generates orthomosaic and DSM
- **Module 02** (10 min): Classifies vegetation into 5 types
- **Module 03** (10 min): Detects individual trees and shrubs
- **Module 04** (skipped): No previous survey for comparison
- **Module 05** (2 min): Calculates summary statistics
- **Module 06** (5 min): Generates reports

### Step 4: Review Results (15 minutes)

**A. Open PDF Report**

```bash
# PDF report location
open outputs/reports/Berry_Harvesting_Area_2024_Report_2024-06-20.pdf
```

Key findings you'll see:
- **Survey area**: 14.8 hectares
- **Trees/shrubs detected**: 3,245 individuals
- **Stem density**: 219 per hectare
- **Vegetation types**: 5 classes mapped with areas
- **Height distribution**: Mean 3.2m, range 1.5-18.5m

**B. Explore Interactive Map**

```bash
# Open in web browser
open outputs/maps/interactive_tree_map.html
```

- Pan and zoom around your survey area
- Click on any red dot to see tree details (height, coordinates)
- Use this to navigate to specific locations in the field

**C. Review GIS Data**

If you use GIS software (QGIS, ArcGIS):

```bash
# Load these files:
outputs/geotiff/vegetation_classification.tif  # Vegetation map
outputs/shapefiles/tree_locations.shp          # GPS points of each tree
outputs/shapefiles/tree_crowns.shp             # Crown polygons
outputs/geotiff/chm.tif                        # Height map
```

### Step 5: Interpret Results (20 minutes)

**Understanding the Vegetation Classification:**

The unsupervised classification identified 5 classes. Interpret them by:

1. Looking at the map and comparing to your field knowledge
2. Checking spectral index values for each class (in CSV outputs)
3. Typical patterns:
   - **Class 1** (high NDVI, low height): Herbaceous meadow
   - **Class 2** (medium NDVI, medium height): Shrubland (your berry habitat!)
   - **Class 3** (medium NDVI, tall height): Young conifer forest
   - **Class 4** (low NDVI): Bare ground, rock outcrops
   - **Class 5** (very low NDVI): If present, likely water or shadows

**Identifying Restoration Priorities:**

From the CSV file `outputs/csv/classification_area_statistics.csv`:

```csv
value,count,area_m2,area_ha,percent_of_total
1,125000,31250,3.13,21.1
2,95000,23750,2.38,16.0
3,180000,45000,4.50,30.4
4,55000,13750,1.38,9.3
5,45000,11250,1.13,7.6
```

Analysis:
- **30% is conifer-dominated** (Class 3) - potential for selective thinning
- **16% is shrubland** (Class 2) - maintain and expand this habitat
- **21% is meadow** (Class 1) - monitor for berry seedling establishment

**Tree Detection for Thinning:**

Load `outputs/shapefiles/tree_locations.shp` in GPS unit or mapping app:
- Filter for trees >4m height (likely conifers suppressing shrubs)
- Export GPS waypoints for field crews
- Provides ~1,200 coordinates for selective removal

### Step 6: Share Results (10 minutes)

**For Community Council Meeting:**

1. **Print PDF report** - professional, peer-reviewed methods
2. **Show interactive map** - projected on screen, zoom to areas of interest
3. **Key takeaways slide**:
   - 15 hectares surveyed
   - 3,245 trees/shrubs counted
   - 30% area needs thinning to restore berry habitat
   - GPS coordinates provided for restoration work

**For Field Crews:**

1. **Export tree locations** to GPS unit:
   ```r
   # In R:
   library(sf)
   trees <- st_read("outputs/shapefiles/tree_locations.shp")

   # Filter tall trees (likely conifers to thin)
   conifers <- trees[trees$height > 4, ]

   # Export as GPX for GPS unit
   st_write(conifers, "outputs/trees_to_thin.gpx", driver = "GPX")
   ```

2. **Print map** from `outputs/reports/*.pdf` - mark up in field

### Step 7: Plan Follow-up Survey (Planning)

**For monitoring restoration success:**

1. **One year post-thinning**: Repeat survey
2. **Set up change detection**:
   ```r
   # In config file for Year 2 survey:
   PREVIOUS_ORTHOMOSAIC <- "../Berry_Area_2024/outputs/geotiff/orthomosaic.tif"
   ENABLE_CHANGE_DETECTION <- TRUE
   ```

3. **Metrics to track**:
   - Shrubland area increase (Class 2)
   - Reduction in conifer dominance (Class 3)
   - New shrub recruitment (tree detection <2m height)
   - NDVI increase (vegetation vigor)

## Troubleshooting

**Problem**: ODM fails with "Insufficient image overlap"

**Solution**:
- Check image timestamps - if gaps >30 seconds, may have missed coverage
- Reflown survey with slower speed or lower altitude
- Can try reducing `min_num_features` to 5000 in ODM_PARAMS

---

**Problem**: Classification shows only 2-3 classes instead of 5

**Solution**:
- Vegetation may be more homogeneous than expected
- Try `N_CLASSES_UNSUPERVISED <- 3` for simpler classification
- Or use supervised classification with field training samples

---

**Problem**: Tree detection misses many shrubs

**Solution**:
- Lower `MIN_TREE_HEIGHT` to 1.0m
- Check CHM - on sloped terrain, may need DTM
- Shrubs with flat crowns are harder to detect than trees

## Next Steps

**Expand Analysis:**
- Add multispectral sensor for better vegetation discrimination
- Collect field training samples for supervised classification
- Measure berry productivity in mapped shrubland areas

**Long-term Monitoring:**
- Annual surveys to track restoration trajectory
- Build time series of vegetation cover
- Correlate with berry harvest yields

**Other Applications:**
- Wildlife habitat mapping (berry shrubs = bear habitat)
- Traditional plant inventory (medicinal species locations)
- Carbon stock estimation (add allometric equations)

## Additional Resources

- **OpenDroneMap Docs**: https://docs.opendronemap.org/
- **ForestTools Tutorial**: https://github.com/andrew-plowright/ForestTools
- **Mission Planning**: DJI GS Pro, Pix4D Capture apps
- **GIS Software**: QGIS (free) - https://qgis.org/

---

**Congratulations!** You've completed a professional drone survey analysis. Your results are scientifically defensible, reproducible, and ready to support community decision-making.

**Questions?** See `README_DRONE_PIPELINE.md` for full documentation.
