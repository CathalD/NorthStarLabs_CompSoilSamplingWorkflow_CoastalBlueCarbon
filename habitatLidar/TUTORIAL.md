# habitatLidar Tutorial: Getting Started

This tutorial will walk you through your first habitat assessment using the **habitatLidar** package, from installation through generating professional reports.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Generate Test Data](#generate-test-data)
4. [Run Your First Analysis](#run-your-first-analysis)
5. [Understanding the Results](#understanding-the-results)
6. [Next Steps](#next-steps)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **R** (≥ 4.0.0) - [Download here](https://www.r-project.org/)
- **RStudio** (recommended) - [Download here](https://posit.co/download/rstudio-desktop/)

### System Requirements

- **RAM**: Minimum 8GB, 16GB+ recommended for large datasets
- **Disk Space**: ~2GB for package and dependencies, plus storage for your data
- **CPU**: Multi-core processor recommended for batch processing

### R Knowledge

- Basic R programming (variables, functions, data frames)
- Familiarity with RStudio interface
- Understanding of file paths

**Estimated time for first tutorial**: 30-45 minutes

---

## Installation

### Step 1: Install System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install libgdal-dev libproj-dev libgeos-dev libudunits2-dev libglpk-dev
```

**macOS (using Homebrew):**
```bash
brew install gdal proj geos udunits glpk
```

**Windows:**
System dependencies are typically handled automatically. If you encounter issues, install [Rtools](https://cran.r-project.org/bin/windows/Rtools/).

### Step 2: Install R Package Dependencies

Open R or RStudio and run:

```r
# Install CRAN packages
install.packages(c(
  "lidR",        # Core lidar processing
  "terra",       # Raster operations
  "sf",          # Vector spatial data
  "rgl",         # 3D visualization
  "future",      # Parallel processing
  "ggplot2",     # Plotting
  "dplyr",       # Data manipulation
  "tidyr",       # Data tidying
  "viridis",     # Color palettes
  "rmarkdown",   # Report generation
  "knitr",       # Report rendering
  "progress",    # Progress bars
  "logger"       # Logging
))

# Install additional packages for advanced features
install.packages(c(
  "ForestTools",   # Tree detection
  "alphashape3d",  # 3D crown modeling
  "geometry",      # Geometric calculations
  "rayshader",     # 3D rendering
  "plotly",        # Interactive plots
  "leaflet",       # Web maps
  "htmlwidgets"    # HTML export
))
```

**Time estimate**: 10-20 minutes depending on connection speed

### Step 3: Install habitatLidar Package

```r
# Install from GitHub (when published)
# devtools::install_github("yourusername/habitatLidar")

# OR install from local source directory
devtools::install("path/to/habitatLidar")

# Load the package
library(habitatLidar)
```

### Step 4: Verify Installation

```r
# Check package version
packageVersion("habitatLidar")

# View package help
help(package = "habitatLidar")

# Test basic function
?preprocess_lidar
```

If everything loaded without errors, you're ready to proceed!

---

## Generate Test Data

Before analyzing real data, let's create synthetic test data to learn the workflow.

### Option 1: Automatic Generation

```r
# Navigate to package directory
pkg_dir <- system.file(package = "habitatLidar")

# Run test data generation script
source(file.path(pkg_dir, "../../data-raw/create_test_data.R"))
```

This creates:
- `inst/extdata/test_tile.las` - Main test lidar file (200m × 200m, ~160,000 points)
- `inst/extdata/catalog/` - Four tiles for batch processing
- `inst/extdata/test_aoi.gpkg` - Area of interest polygon
- `inst/extdata/moose_occurrences.csv` - Simulated moose observations

**Time estimate**: 2-3 minutes

### Option 2: Manual Data Download

If you have real lidar data:

```r
# Load your own LAS file
las <- lidR::readLAS("path/to/your/lidar.las")

# Check basic properties
print(las)
plot(las)
```

**Supported formats**: .las, .laz (LAS 1.2, 1.3, 1.4)

---

## Run Your First Analysis

We provide two example scripts with increasing complexity.

### Beginner: Basic Workflow (01_basic_workflow.R)

This script demonstrates core functionality:

```r
# Load the example script
example_file <- system.file("examples/01_basic_workflow.R",
                           package = "habitatLidar")

# View the script
file.edit(example_file)

# Run it!
source(example_file)
```

**What it does:**
1. ✓ Loads test lidar data
2. ✓ Performs quality control
3. ✓ Preprocesses (ground classification, normalization)
4. ✓ Calculates canopy and understory metrics
5. ✓ Detects individual trees
6. ✓ Calculates moose habitat suitability
7. ✓ Generates summary visualizations

**Time estimate**: 5-8 minutes

**Outputs** (saved to `tutorial_output/basic_workflow/`):
- CHM visualization
- Browse density map
- Tree detection map
- Tree size distribution
- Habitat suitability map
- Summary statistics CSV

### Intermediate: Complete Workflow with Reports (02_complete_workflow_with_reports.R)

This script adds automated report generation:

```r
# Load the example script
example_file <- system.file("examples/02_complete_workflow_with_reports.R",
                           package = "habitatLidar")

# Run it!
source(example_file)
```

**Additional features:**
- Automated PDF report generation (technical + community versions)
- Multi-panel visualizations
- Tree allometry analysis
- Vertical structure breakdown
- Analysis dashboard

**Time estimate**: 10-15 minutes

**Outputs** (saved to `tutorial_output/complete_workflow/`):
- **Processing/** - All geospatial outputs
- **Reports/** - Technical and community PDF reports
- **Visualizations/** - High-resolution figures
- **analysis_dashboard.csv** - Summary metrics

---

## Understanding the Results

### Key Output Files

#### 1. Geospatial Data (GIS)

| File | Format | Description |
|------|--------|-------------|
| `canopy_metrics.tif` | GeoTIFF | 20+ canopy structure metrics |
| `understory_metrics.tif` | GeoTIFF | Understory and browse metrics |
| `hsi/hsi_moose.tif` | GeoTIFF | Habitat suitability (0-1 scale) |
| `trees.gpkg` | GeoPackage | Tree locations (points) |
| `priority_habitat.gpkg` | GeoPackage | High-quality patches (polygons) |

**How to use:**
- Open in QGIS, ArcGIS, or other GIS software
- Overlay with traditional use areas, roads, etc.
- Create custom maps for planning

#### 2. Tabular Data (CSV)

| File | Description |
|------|-------------|
| `tree_inventory.csv` | Complete tree inventory with heights, DBH, crown dimensions |
| `summary_statistics.csv` | Key metrics summary table |
| `analysis_dashboard.csv` | Comprehensive metrics dashboard |

**How to use:**
- Open in Excel or R
- Calculate custom statistics
- Create charts and graphs

#### 3. Reports (PDF)

| File | Audience | Contents |
|------|----------|----------|
| `technical_report.pdf` | Scientists, managers | Full methodology, results, references |
| `community_summary.pdf` | Community members | Plain language, large maps, key findings |

#### 4. Visualizations (PNG)

All figures are publication-quality (300 DPI):
- Canopy height model
- Browse density
- Habitat suitability map
- Tree distribution
- Vertical structure
- Multi-panel overviews

### Interpreting Results

#### Habitat Suitability Index (HSI)

| HSI Value | Interpretation | Management |
|-----------|----------------|------------|
| 0.8 - 1.0 | Excellent habitat | Priority for protection |
| 0.6 - 0.8 | Good habitat | Suitable for conservation |
| 0.4 - 0.6 | Moderate habitat | Enhancement opportunities |
| 0.2 - 0.4 | Low habitat | Limited suitability |
| 0.0 - 0.2 | Poor habitat | Not suitable |

#### Structural Complexity Index

| Value | Interpretation |
|-------|----------------|
| > 0.7 | High diversity, multi-aged forest, excellent wildlife habitat |
| 0.5 - 0.7 | Moderate diversity, good structure |
| 0.3 - 0.5 | Low diversity, simple structure |
| < 0.3 | Very simple structure, plantation-like |

#### Tree Size Classes

| Height | Class | Significance |
|--------|-------|--------------|
| 30+ m | Old-growth indicators | High conservation value |
| 20-30 m | Mature forest | Good habitat structure |
| 10-20 m | Mid-aged forest | Developing habitat |
| 5-10 m | Young forest | Future habitat potential |

---

## Next Steps

### 1. Try Different Species

Modify the target species in the workflow:

```r
# Instead of moose, try:
target_species <- "caribou"  # Old-growth specialist
target_species <- "deer"     # Edge habitat
target_species <- "bear"     # Berry habitat
```

Each species has different habitat requirements and will produce different HSI maps.

### 2. Adjust Parameters

Experiment with different settings:

```r
# Metric resolution
canopy_metrics <- generate_canopy_metrics_grid(las, res = 10)  # Finer detail

# Tree detection sensitivity
ws_function <- function(x) { 0.03 * x + 0.5 }  # Smaller window = more trees

# HSI threshold
priority <- identify_priority_habitat(hsi, threshold = 0.8)  # Stricter
```

### 3. Process Your Own Data

```r
# Load your lidar data
my_las <- readLAS("path/to/my_data.las")

# Run the complete workflow
my_results <- process_lidar(
  my_las,
  output_dir = "my_analysis/",
  species = "moose",
  metric_res = 20,
  detect_trees = TRUE
)
```

### 4. Batch Processing

For large areas with multiple tiles:

```r
# Set up catalog
catalog_folder <- "path/to/lidar_tiles/"
output_folder <- "batch_results/"

# Process all tiles
batch_results <- batch_process_catalog(
  catalog_folder,
  output_folder,
  processing_options = list(
    preprocess = TRUE,
    canopy_metrics = TRUE,
    tree_detection = TRUE,
    hsi_species = c("moose", "caribou")
  ),
  n_cores = 4  # Use 4 CPU cores
)
```

### 5. Explore Vignettes

Detailed tutorials for specific topics:

```r
# View available vignettes
vignette(package = "habitatLidar")

# Open specific vignette
vignette("complete_tutorial", package = "habitatLidar")
vignette("habitat_assessment", package = "habitatLidar")
vignette("3d_visualization", package = "habitatLidar")
```

---

## Troubleshooting

### Common Issues

#### 1. Package Installation Fails

**Error**: `installation of package 'X' had non-zero exit status`

**Solution**:
```r
# Try installing dependencies individually
install.packages("lidR")
install.packages("terra")
# etc.

# Check for system dependencies
# On Ubuntu: sudo apt-get install libgdal-dev
```

#### 2. "Cannot allocate vector of size..."

**Error**: Memory error with large datasets

**Solution**:
```r
# Increase memory limit (Windows)
memory.limit(size = 16000)  # 16GB

# Process in smaller chunks
lidR::opt_chunk_size(catalog) <- 250  # Smaller chunks

# Use lower resolution
canopy_metrics <- generate_canopy_metrics_grid(las, res = 30)  # Instead of 20
```

#### 3. RGL 3D Visualization Not Working

**Error**: `rgl` fails to open window

**Solution**:
```r
# Try alternative 3D viewer
plot_3d_plotly(las, sample_pct = 10)  # Web-based alternative

# Or use 2D plots
plot(las, color = "Z")
```

#### 4. "Test data not found"

**Error**: Cannot find test LAS files

**Solution**:
```r
# Regenerate test data
pkg_dir <- system.file(package = "habitatLidar")
source(file.path(pkg_dir, "../../data-raw/create_test_data.R"))

# Or specify full path
las_file <- "/full/path/to/inst/extdata/test_tile.las"
```

#### 5. Reports Fail to Generate

**Error**: R Markdown errors

**Solution**:
```r
# Ensure packages installed
install.packages(c("rmarkdown", "knitr"))

# Check LaTeX (for PDF)
# Install TinyTeX
tinytex::install_tinytex()

# Generate HTML instead
rmarkdown::render("report.Rmd", output_format = "html_document")
```

### Getting Help

1. **Package Documentation**
   ```r
   ?function_name  # Function help
   help(package = "habitatLidar")  # Package overview
   ```

2. **Vignettes**
   ```r
   vignette("quickstart", package = "habitatLidar")
   ```

3. **GitHub Issues**
   - Report bugs: [github.com/yourusername/habitatLidar/issues](https://github.com/yourusername/habitatLidar/issues)
   - Search existing issues first

4. **Contact**
   - Email: [your contact]
   - Include: R version, error message, sessionInfo() output

---

## Performance Tips

### For Large Datasets

1. **Use Parallel Processing**
   ```r
   future::plan(future::multisession, workers = 8)  # 8 cores
   ```

2. **Process in Chunks**
   ```r
   lidR::opt_chunk_size(catalog) <- 500  # 500m chunks
   lidR::opt_chunk_buffer(catalog) <- 30  # 30m overlap
   ```

3. **Sample Points for Visualization**
   ```r
   plot_3d_point_cloud(las, sample_pct = 25)  # Show 25%
   ```

4. **Lower Resolution for Initial Exploration**
   ```r
   canopy_metrics <- generate_canopy_metrics_grid(las, res = 50)  # Fast
   # Then refine areas of interest at res = 20
   ```

### Expected Processing Times

| Dataset Size | Processing | Tree Detection | Complete Workflow |
|--------------|------------|----------------|-------------------|
| 1 km² (4 pts/m²) | 2-3 min | 2 min | 5-8 min |
| 10 km² (4 pts/m²) | 20-30 min | 15 min | 45-60 min |
| 100 km² (4 pts/m²) | 3-4 hours* | 2 hours* | 6-8 hours* |

*With 8-core parallel processing

---

## Quick Reference Card

### Essential Functions

| Task | Function |
|------|----------|
| Load lidar | `las <- lidR::readLAS("file.las")` |
| Quality check | `quality_control_report(las)` |
| Preprocess | `preprocess_lidar(las)` |
| Canopy metrics | `generate_canopy_metrics_grid(las, res=20)` |
| Understory metrics | `generate_understory_metrics_grid(las, res=10)` |
| Detect trees | `detect_segment_trees(las, ws=func, hmin=5)` |
| Habitat suitability | `calculate_multispecies_hsi(las, species=c("moose"))` |
| 3D visualization | `plot_3d_point_cloud(las)` |
| Generate reports | `generate_report_package(results, dir, info)` |
| Complete workflow | `process_lidar(file, dir, species, res)` |

### Common Workflows

**Quick Analysis**:
```r
results <- process_lidar("tile.las", "output/", species="moose")
```

**Custom Analysis**:
```r
las <- readLAS("tile.las")
preprocessed <- preprocess_lidar(las)
metrics <- generate_canopy_metrics_grid(preprocessed$las, res=20)
hsi <- calculate_multispecies_hsi(preprocessed$las, species=c("moose"))
```

**Batch Processing**:
```r
batch_process_catalog("tiles/", "output/", options, n_cores=8)
```

---

## Resources

### Learning Materials

- **Quick Start**: `vignette("quickstart")`
- **Complete Tutorial**: `vignette("complete_tutorial")`
- **Habitat Assessment**: `vignette("habitat_assessment")`
- **3D Visualization**: `vignette("3d_visualization")`

### Example Data

- Test data location: `system.file("extdata", package="habitatLidar")`
- Example scripts: `system.file("examples", package="habitatLidar")`

### External Resources

- **lidR package**: [r-lidar.github.io/lidRbook](https://r-lidar.github.io/lidRbook/)
- **Terra package**: [rspatial.org](https://rspatial.org/terra/)
- **sf package**: [r-spatial.github.io/sf](https://r-spatial.github.io/sf/)

---

## Feedback Welcome!

We're constantly improving **habitatLidar**. Your feedback helps!

- ⭐ Star the repository if you find it useful
- 🐛 Report bugs via GitHub Issues
- 💡 Suggest features or improvements
- 📖 Contribute documentation or examples
- 🤝 Share your success stories

---

**Ready to start?** Jump to [Generate Test Data](#generate-test-data) and run your first analysis!

For questions, contact: [your contact information]

*Happy analyzing! 🌲🦌📊*
