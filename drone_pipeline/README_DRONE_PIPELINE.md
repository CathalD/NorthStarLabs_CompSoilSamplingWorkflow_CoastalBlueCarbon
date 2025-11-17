# 🚁 Drone Orthomosaic to Ecological Metrics Pipeline

**A production-ready R pipeline for processing drone imagery into actionable ecological metrics**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)]()
[![R Version](https://img.shields.io/badge/R-%E2%89%A5%204.0-brightgreen)]()
[![Status](https://img.shields.io/badge/status-production--ready-success)]()

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Installation](#installation)
  - [System Requirements](#system-requirements)
  - [R Packages](#r-packages)
  - [OpenDroneMap Setup](#opendronemap-setup)
- [Usage](#usage)
  - [Basic Workflow](#basic-workflow)
  - [Configuration](#configuration)
  - [Running the Pipeline](#running-the-pipeline)
  - [Module-by-Module Execution](#module-by-module-execution)
- [Pipeline Modules](#pipeline-modules)
- [Outputs](#outputs)
- [Example Use Cases](#example-use-cases)
- [Troubleshooting](#troubleshooting)
- [Scientific Methods](#scientific-methods)
- [Acknowledgments](#acknowledgments)

---

## 🎯 Overview

This pipeline transforms raw geotagged drone images into comprehensive ecological metrics and professional reports. Designed specifically for **Indigenous communities and conservation practitioners in Canada**, it provides scientifically defensible results without requiring expensive proprietary software.

**Target Users:**
- Indigenous communities conducting land monitoring
- Conservation ecologists
- Restoration practitioners
- Environmental consultants
- Academic researchers

**Input:** Raw geotagged drone images (JPG with EXIF GPS data)

**Output:** Orthomosaics, vegetation maps, tree inventories, change detection, professional PDF/HTML reports

---

## ⭐ Key Features

✅ **Complete Pipeline** - From raw images to publication-ready reports
✅ **No Proprietary Software** - Uses open-source tools (OpenDroneMap, R)
✅ **Scientific Rigor** - Peer-reviewed methods with uncertainty quantification
✅ **Professional Reports** - Auto-generated PDF and HTML reports
✅ **User-Friendly** - Comprehensive documentation and plain language explanations
✅ **Vegetation Classification** - ML-based mapping of vegetation types
✅ **Individual Tree Detection** - Automated tree/shrub counting and metrics
✅ **Change Detection** - Multi-temporal monitoring capabilities
✅ **Interactive Maps** - Web-based visualizations with Leaflet
✅ **Production-Ready** - Handles surveys up to 500 images (~50 hectares)

---

## 🚀 Quick Start

### Prerequisites
- R (≥ 4.0)
- Docker (for OpenDroneMap)
- ExifTool (for GPS extraction)

### Installation (5-15 minutes)

```r
# 1. Clone or download this repository
cd /path/to/NorthStarLabs_CompSoilSamplingWorkflow_CoastalBlueCarbon
cd drone_pipeline

# 2. Install R packages
source("00_setup_drone_pipeline.R")
```

### Run Pipeline (10 minutes to several hours)

```r
# 1. Edit configuration
# Open config/drone_config.R and set your project parameters

# 2. Add your drone images
# Place geotagged JPG images in: data_input/images/

# 3. Run complete pipeline
source("drone_pipeline_main.R")

# 4. View results
# PDF report: outputs/reports/
# Interactive map: outputs/maps/interactive_tree_map.html
```

---

## 📦 Installation

### System Requirements

**Minimum:**
- OS: Ubuntu 20.04+, macOS 12+, or Windows 10+
- RAM: 8 GB
- Storage: 20 GB free space
- Processor: Quad-core CPU

**Recommended:**
- RAM: 16 GB
- Storage: 50 GB SSD
- Processor: 8-core CPU
- GPU: Not required but helpful for ODM

### R Packages

The setup script installs all required packages automatically:

```r
source("00_setup_drone_pipeline.R")
```

**Core packages:**
- **Spatial:** `terra`, `sf`, `stars`, `lidR`, `ForestTools`
- **Machine Learning:** `randomForest`, `caret`, `e1071`
- **Visualization:** `ggplot2`, `leaflet`, `viridis`
- **Reporting:** `rmarkdown`, `knitr`, `kableExtra`

### OpenDroneMap Setup

**Option 1: Docker (Recommended)**

```bash
# Install Docker
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install docker.io

# MacOS:
brew install docker

# Windows: Download from https://docs.docker.com/docker-for-windows/install/

# Pull ODM image
docker pull opendronemap/odm
```

**Option 2: Native Installation**

Follow instructions at: https://docs.opendronemap.org/installation/

**Option 3: WebODM (Cloud-based)**

Use WebODM for processing large datasets: https://www.opendronemap.org/webodm/

### ExifTool Installation

**Ubuntu/Debian:**
```bash
sudo apt-get install libimage-exiftool-perl
```

**MacOS:**
```bash
brew install exiftool
```

**Windows:**
Download from: https://exiftool.org/

---

## 💻 Usage

### Basic Workflow

1. **Configure** - Edit `config/drone_config.R`
2. **Add Images** - Place drone photos in `data_input/images/`
3. **Run** - Execute `source("drone_pipeline_main.R")`
4. **Review** - Open PDF report and interactive map

### Configuration

Edit `config/drone_config.R` to set project parameters:

```r
# Project metadata
PROJECT_NAME <- "Berry_Area_2024"
SURVEY_DATE <- "2024-06-15"
LOCATION_NAME <- "Traditional Harvesting Area"
COMMUNITY_NAME <- "Example First Nation"

# Input paths
IMAGE_DIR <- "data_input/images"
GCP_FILE <- NULL  # Optional: path to ground control points

# Classification method
CLASSIFICATION_METHOD <- "unsupervised"  # or "supervised"
N_CLASSES_UNSUPERVISED <- 5

# Tree detection
MIN_TREE_HEIGHT <- 2.0  # meters
TREE_DETECTION_METHOD <- "watershed"  # or "local_maxima"

# Report format
REPORT_FORMAT <- c("PDF", "HTML")
INCLUDE_INTERACTIVE_MAP <- TRUE

# Change detection (multi-temporal)
PREVIOUS_ORTHOMOSAIC <- NULL  # Path to previous survey for change detection
ENABLE_CHANGE_DETECTION <- !is.null(PREVIOUS_ORTHOMOSAIC)
```

### Running the Pipeline

**Full Pipeline (One Command):**

```r
source("drone_pipeline_main.R")
```

This executes all 6 modules in sequence:
1. Orthomosaic generation (ODM)
2. Vegetation classification
3. Tree/shrub detection
4. Change detection (if enabled)
5. Summary statistics
6. Report generation

**Estimated Runtime:**
- Small survey (<100 images, <10 ha): 30-60 minutes
- Medium survey (100-300 images, 10-30 ha): 1-3 hours
- Large survey (300-500 images, 30-50 ha): 3-8 hours

### Module-by-Module Execution

For fine-grained control, run modules individually:

```r
# Module 01: Orthomosaic Generation
source("R/01_odm_orthomosaic_generation.R")

# Module 02: Vegetation Classification
source("R/02_vegetation_classification.R")

# Module 03: Tree Detection
source("R/03_tree_shrub_detection.R")

# Module 04: Change Detection (optional)
source("R/04_change_detection.R")

# Module 05: Summary Statistics
source("R/05_summary_statistics.R")

# Module 06: Report Generation
source("R/06_generate_report.R")
```

---

## 🔧 Pipeline Modules

### Module 01: Orthomosaic Generation

**Purpose:** Generate georeferenced orthomosaic and DSM from raw drone images

**Method:** Structure-from-Motion (SfM) photogrammetry via OpenDroneMap

**Inputs:**
- Geotagged drone images (JPG with EXIF GPS)
- Optional: Ground Control Points (GCP) CSV

**Outputs:**
- Orthomosaic (GeoTIFF)
- Digital Surface Model - DSM (GeoTIFF)
- Point cloud (LAZ)
- Quality assessment report

**Runtime:** 10 minutes to several hours

**Key Parameters:**
- `feature_quality`: Feature detection quality (high, medium, low)
- `orthophoto_resolution`: Ground sampling distance (cm/pixel)
- `use_gcp`: Use ground control points for accuracy

---

### Module 02: Vegetation Classification

**Purpose:** Classify vegetation types using spectral analysis and machine learning

**Methods:**
- **Spectral Indices:** NDVI, ExG, VARI, GLI
- **Classification:** Random Forest (supervised) or k-means (unsupervised)

**Inputs:**
- Orthomosaic from Module 01
- Optional: Training samples shapefile

**Outputs:**
- Classified raster (GeoTIFF)
- Spectral index rasters (NDVI, ExG, VARI, GLI)
- Classification accuracy assessment
- Area statistics by class

**Runtime:** 5-20 minutes

**Classes (default unsupervised):**
1. Forest/Woodland
2. Shrubland
3. Herbaceous Vegetation
4. Bare Ground/Rock
5. Water

**For supervised classification:**
- Provide training polygons shapefile
- Set `CLASSIFICATION_METHOD <- "supervised"`
- Set `TRAINING_SAMPLES <- "path/to/training.shp"`

---

### Module 03: Tree/Shrub Detection

**Purpose:** Detect individual trees/shrubs and extract metrics

**Methods:**
- CHM generation from DSM
- Watershed segmentation or local maxima detection
- Crown delineation

**Inputs:**
- DSM from Module 01
- Optional: DTM for accurate CHM

**Outputs:**
- Canopy Height Model - CHM (GeoTIFF)
- Tree locations (shapefile + CSV with lat/long)
- Tree metrics: height, crown area, coordinates
- Crown delineation polygons (shapefile)
- Summary statistics (density, height distribution)

**Runtime:** 5-20 minutes

**Key Parameters:**
- `MIN_TREE_HEIGHT`: Minimum height threshold (default: 2m)
- `MAX_TREE_HEIGHT`: Maximum height filter (default: 50m)
- `TREE_DETECTION_METHOD`: "watershed" or "local_maxima"

**Output Metrics:**
- Tree ID
- Height (m)
- Crown area (m²)
- Crown diameter (m)
- Latitude/Longitude (WGS84)
- X/Y coordinates (project CRS)

---

### Module 04: Change Detection

**Purpose:** Detect vegetation changes between survey periods

**Methods:**
- Image co-registration
- NDVI differencing
- Height change analysis
- Classification change matrix

**Inputs:**
- Current survey orthomosaic and CHM
- Previous survey orthomosaic and CHM

**Outputs:**
- NDVI change map (GeoTIFF)
- Height change map (GeoTIFF)
- Change classification raster
- Change statistics (area by change type)

**Runtime:** 10-30 minutes

**Enable by setting:**
```r
PREVIOUS_ORTHOMOSAIC <- "path/to/previous_orthomosaic.tif"
ENABLE_CHANGE_DETECTION <- TRUE
```

**Change Classes:**
1. Stable (no significant change)
2. Vegetation Gain (increase in NDVI and height)
3. Vegetation Loss (decrease in NDVI and height)
4. Height Increase Only
5. Height Decrease Only

---

### Module 05: Summary Statistics

**Purpose:** Aggregate results and generate summary tables

**Inputs:**
- Results from all previous modules

**Outputs:**
- Comprehensive summary CSV
- Survey metadata JSON
- Formatted text report

**Runtime:** <5 minutes

**Statistics Calculated:**
- Total survey area (hectares, acres)
- Vegetation cover by class (area, percent)
- Tree density (stems/ha)
- Mean/max/min vegetation height
- Canopy cover percentage
- Change statistics (if applicable)

---

### Module 06: Report Generation

**Purpose:** Generate professional PDF and HTML reports

**Method:** R Markdown templating

**Inputs:**
- Summary data from Module 05
- All processed outputs

**Outputs:**
- PDF report (print-ready)
- HTML report (interactive)
- Interactive Leaflet map

**Runtime:** 5-10 minutes

**Report Sections:**
- Executive Summary
- Survey Information
- Methods (plain language + technical)
- Results (maps, tables, charts)
- Discussion & Interpretation
- Recommendations
- Appendices (technical details, references)

**Requirements for PDF:**
- LaTeX installation (use TinyTeX)
  ```r
  install.packages('tinytex')
  tinytex::install_tinytex()
  ```

---

## 📁 Outputs

All outputs are saved in the `outputs/` directory:

```
drone_pipeline/
├── outputs/
│   ├── geotiff/
│   │   ├── orthomosaic.tif
│   │   ├── dsm.tif
│   │   ├── chm.tif
│   │   └── vegetation_classification.tif
│   ├── shapefiles/
│   │   ├── tree_locations.shp
│   │   ├── tree_crowns.shp
│   │   └── survey_boundary.shp
│   ├── csv/
│   │   ├── tree_metrics.csv
│   │   ├── classification_area_statistics.csv
│   │   ├── tree_summary_statistics.csv
│   │   └── change_statistics.csv
│   ├── reports/
│   │   ├── [ProjectName]_Report_[Date].pdf
│   │   ├── [ProjectName]_Report_[Date].html
│   │   └── survey_summary.json
│   └── maps/
│       └── interactive_tree_map.html
```

### Key Output Files

**For GIS Analysis:**
- `geotiff/`: All raster outputs (orthomosaic, DSM, CHM, classification)
- `shapefiles/`: Vector data (tree locations, crowns, boundaries)

**For Reporting:**
- `reports/*.pdf`: Professional PDF report
- `reports/*.html`: Interactive HTML report
- `maps/interactive_tree_map.html`: Web map with tree locations

**For Data Analysis:**
- `csv/tree_metrics.csv`: Individual tree measurements
- `csv/*_statistics.csv`: Summary statistics tables

---

## 📊 Example Use Cases

### Use Case 1: Berry Harvesting Area Restoration

**Scenario:** A First Nation wants to restore traditional berry harvesting areas by selectively thinning conifers that suppress shrub growth.

**Workflow:**
1. Fly drone survey of 20 hectare area
2. Run pipeline with default settings
3. Classify vegetation to identify shrubland vs. conifer areas
4. Detect individual conifers (height, location)
5. Generate map showing where thinning is needed

**Outputs Used:**
- Classification map → identifies where shrubs are suppressed
- Tree detection shapefile → provides GPS coordinates for thinning crews
- Report → presents results to community council

**Monitoring:**
- Repeat survey 1-2 years post-thinning
- Use change detection module to quantify shrub recovery

---

### Use Case 2: Wildfire Recovery Monitoring

**Scenario:** Track vegetation regeneration after wildfire.

**Workflow:**
1. Baseline survey immediately post-fire
2. Follow-up surveys at 1, 3, and 5 years
3. Use change detection to quantify:
   - Vegetation cover increase (NDVI)
   - Tree recruitment (new stems detected)
   - Height growth of regenerating trees

**Outputs Used:**
- Multi-temporal NDVI maps
- Tree density trends over time
- Height distribution changes

---

### Use Case 3: Invasive Species Mapping

**Scenario:** Map extent of invasive shrub species.

**Workflow:**
1. Collect field training samples (GPS points of invasive vs. native)
2. Export as shapefile with class labels
3. Set `CLASSIFICATION_METHOD <- "supervised"`
4. Run pipeline with training data
5. Map shows spatial extent of invasion

**Outputs Used:**
- Supervised classification map
- Area statistics (hectares invaded)
- Accuracy assessment (how reliable is the map)

---

## 🔧 Troubleshooting

### Common Issues

**Problem:** "No images found in directory"

**Solution:**
- Ensure images are in `data_input/images/`
- Check file extensions (must be .jpg or .jpeg)
- Verify IMAGE_DIR path in config

---

**Problem:** "GPS coordinates not found in EXIF data"

**Solution:**
- Ensure images are geotagged (check with ExifTool)
- DJI drones: Ensure GPS was locked during flight
- If images not geotagged, ODM can still process but won't georeference

---

**Problem:** "ODM Docker command fails"

**Solution:**
- Verify Docker is installed and running
- Check Docker has sufficient resources allocated
- Try running Docker command manually to see detailed errors
- For large datasets, increase Docker memory limit

---

**Problem:** "Insufficient image overlap"

**Solution:**
- Recommended: 70-80% front overlap, 60-70% side overlap
- Refly survey with slower speed or lower altitude
- Use mission planning app (Pix4D Capture, DJI GS Pro) to ensure proper overlap

---

**Problem:** "Tree detection misses many trees"

**Solution:**
- Adjust `MIN_TREE_HEIGHT` threshold
- Try different `TREE_DETECTION_METHOD` (watershed vs. local_maxima)
- Check CHM quality - may need DTM for sloped terrain
- Some tree species with irregular crowns are harder to detect

---

**Problem:** "Classification accuracy is low"

**Solution:**
- For supervised: Collect more diverse training samples
- For unsupervised: Adjust `N_CLASSES_UNSUPERVISED`
- Consider timing: survey during peak growing season for best spectral separation
- RGB limitations: Multispectral sensor would improve results

---

**Problem:** "PDF report generation fails"

**Solution:**
- Install LaTeX: `tinytex::install_tinytex()`
- Or generate HTML only: `REPORT_FORMAT <- "HTML"`
- Check R Markdown template exists in `templates/`

---

**Problem:** "Out of memory errors"

**Solution:**
- Reduce `orthophoto_resolution` (larger value = lower resolution)
- Set `downsample_large_rasters = TRUE` in config
- Process in chunks (split survey area)
- Upgrade RAM or use cloud processing (WebODM)

---

### System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install libgdal-dev libgeos-dev libproj-dev libudunits2-dev
sudo apt-get install libimage-exiftool-perl
sudo apt-get install docker.io
```

**MacOS:**
```bash
brew install gdal geos proj
brew install exiftool
brew install docker
```

---

## 🔬 Scientific Methods

### Photogrammetry

**Structure-from-Motion (SfM):**
- Westoby et al. (2012). *Geomorphology*, 179, 300-314
- Reconstructs 3D geometry from overlapping 2D images
- Identifies matching features across images
- Estimates camera positions and 3D point locations

**Multi-View Stereo (MVS):**
- Generates dense point cloud from sparse SfM output
- Produces high-resolution DSM

### Vegetation Indices

**NDVI** (Normalized Difference Vegetation Index):
- Tucker (1979). *Remote Sensing of Environment*, 8(2), 127-150
- Formula: (NIR - Red) / (NIR + Red)
- Proxy for photosynthetic activity and biomass

**ExG** (Excess Green):
- Woebbecke et al. (1995). *Transactions of the ASAE*
- Formula: 2 * Green - Red - Blue
- Discriminates green vegetation from soil

### Tree Detection

**Watershed Segmentation:**
- Dalponte & Coomes (2016). *Methods in Ecology and Evolution*, 7(10), 1236-1245
- Treats CHM as inverted watershed
- Water flows from tree tops to crown edges
- Delineates individual crowns

**Local Maxima:**
- Popescu & Wynne (2004). *Photogrammetric Engineering & Remote Sensing*, 70(5)
- Identifies local height peaks as tree tops
- Variable window size accounts for different tree sizes

### Machine Learning

**Random Forest Classification:**
- Breiman (2001). *Machine Learning*, 45(1), 5-32
- Ensemble of decision trees
- Non-parametric, handles complex relationships
- Provides variable importance metrics

---

## 📚 References

### Key Publications

1. **Photogrammetry:**
   - Westoby, M.J., et al. (2012). 'Structure-from-Motion' photogrammetry: A low-cost, effective tool for geoscience applications. *Geomorphology*, 179, 300-314.

2. **Remote Sensing:**
   - Tucker, C.J. (1979). Red and photographic infrared linear combinations for monitoring vegetation. *Remote Sensing of Environment*, 8(2), 127-150.

3. **Tree Detection:**
   - Dalponte, M., & Coomes, D.A. (2016). Tree-centric mapping of forest carbon density from airborne laser scanning and hyperspectral data. *Methods in Ecology and Evolution*, 7(10), 1236-1245.

4. **Machine Learning:**
   - Breiman, L. (2001). Random forests. *Machine Learning*, 45(1), 5-32.

### Software Citations

- **OpenDroneMap:** https://www.opendronemap.org/
- **R:** R Core Team (2024). R: A language and environment for statistical computing. https://www.R-project.org/
- **terra:** Hijmans, R.J. (2023). terra: Spatial Data Analysis. R package.
- **sf:** Pebesma, E. (2018). Simple Features for R: Standardized Support for Spatial Vector Data. *The R Journal*, 10(1), 439-446.
- **ForestTools:** Plowright, A. (2023). ForestTools: Tools for Analyzing Remote Sensing Forest Data. R package.

---

## 🙏 Acknowledgments

This pipeline was developed to support Indigenous-led conservation and monitoring in Canada. Special thanks to:

- **Indigenous communities** who guided development and testing
- **OpenDroneMap community** for open-source photogrammetry tools
- **R spatial community** for comprehensive geospatial packages
- **Canadian conservation practitioners** who provided feedback

---

## 📧 Contact & Support

**Documentation:** See `docs/` folder for additional guides

**Issues:** For bugs or feature requests, open an issue on GitHub

**Community Support:** Join OpenDroneMap community forum for ODM-specific questions

---

## 📝 License

[Specify license - e.g., MIT, GPL-3]

---

**Version:** 1.0.0
**Last Updated:** November 2024
**Tested Platforms:** Ubuntu 20.04+, macOS 12+, Windows 10+
**R Version:** ≥ 4.0

---

*Developed for conservation ecologists working with Indigenous communities in Canada. Adaptable globally for drone-based vegetation monitoring.*
