# =============================================================================
# DRONE ORTHOMOSAIC TO ECOLOGICAL METRICS PIPELINE
# Setup Script - Install Required Packages
# =============================================================================
#
# This script installs all R packages required for the drone processing pipeline
#
# Runtime: 5-15 minutes (first time only)
#
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  DRONE PIPELINE - PACKAGE INSTALLATION                              ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# =============================================================================
# REQUIRED PACKAGES
# =============================================================================

required_packages <- list(

  # Core spatial data handling
  spatial_core = c(
    "terra",        # Modern raster data handling (replacement for raster)
    "sf",           # Simple features for vector data
    "sp",           # Legacy spatial package (still needed by some packages)
    "stars",        # Spatiotemporal arrays for raster/vector data cubes
    "rgdal",        # GDAL bindings (may be deprecated, but still useful)
    "raster"        # Legacy raster package (for compatibility)
  ),

  # Geospatial processing
  spatial_processing = c(
    "lidR",         # LiDAR processing (for point clouds and CHM)
    "ForestTools",  # Tree detection and crown delineation
    "itcSegment",   # Individual tree crown segmentation
    "TreeLS"        # Tree-level metrics from point clouds
  ),

  # Data manipulation
  data_manipulation = c(
    "dplyr",        # Data frame manipulation
    "tidyr",        # Data tidying
    "readr",        # Fast CSV reading
    "data.table",   # High-performance data manipulation
    "purrr",        # Functional programming tools
    "stringr"       # String manipulation
  ),

  # Visualization
  visualization = c(
    "ggplot2",      # Grammar of graphics plotting
    "gridExtra",    # Arrange multiple plots
    "RColorBrewer", # Color palettes
    "viridis",      # Perceptually uniform color maps
    "scales",       # Scale functions for visualization
    "ggthemes",     # Additional themes for ggplot2
    "patchwork"     # Combine separate ggplots
  ),

  # Machine learning and classification
  machine_learning = c(
    "randomForest", # Random forest classification/regression
    "caret",        # Classification and regression training
    "e1071",        # SVM and other ML algorithms
    "class",        # K-nearest neighbors
    "cluster"       # Clustering algorithms (k-means, etc.)
  ),

  # Image processing
  image_processing = c(
    "imager",       # Image processing
    "OpenImageR",   # Additional image operations
    "jpeg",         # Read JPEG images
    "png"           # Read PNG images
  ),

  # Spatial statistics
  spatial_statistics = c(
    "spatstat",     # Spatial point pattern analysis
    "spdep",        # Spatial dependence
    "gstat"         # Geostatistics
  ),

  # Interactive mapping
  interactive_maps = c(
    "leaflet",      # Interactive web maps
    "mapview",      # Quick interactive viewing
    "leaflet.extras", # Additional leaflet plugins
    "htmlwidgets"   # HTML widgets framework
  ),

  # Report generation
  reporting = c(
    "rmarkdown",    # R Markdown documents
    "knitr",        # Dynamic report generation
    "kableExtra",   # Enhanced tables
    "flextable",    # Flexible table formatting
    "officer",      # Manipulate MS Office documents
    "pagedown"      # Paginated HTML documents
  ),

  # File I/O
  file_io = c(
    "openxlsx",     # Read/write Excel files
    "writexl",      # Lightweight Excel writer
    "yaml",         # YAML file parsing
    "jsonlite",     # JSON handling
    "xml2"          # XML parsing
  ),

  # Metadata and EXIF
  metadata = c(
    "exifr",        # Extract EXIF data from images
    "exiftoolr"     # Interface to ExifTool
  ),

  # Progress tracking
  progress = c(
    "progress",     # Progress bars
    "progressr"     # Unified progress updates
  ),

  # Parallel processing
  parallel = c(
    "parallel",     # Base R parallel (built-in)
    "foreach",      # Foreach loops
    "doParallel",   # Parallel backend for foreach
    "future",       # Unified parallel processing
    "future.apply"  # Apply functions in parallel
  ),

  # Utility packages
  utilities = c(
    "here",         # Project-relative paths
    "fs",           # Cross-platform file system operations
    "glue",         # String interpolation
    "assertthat",   # Pre- and post-condition checks
    "logger"        # Logging framework
  )
)

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

# Function to check if package is installed
is_installed <- function(pkg) {
  return(pkg %in% rownames(installed.packages()))
}

# Function to install single package with error handling
install_package <- function(pkg) {
  if (!is_installed(pkg)) {
    cat("   Installing:", pkg, "...\n")
    tryCatch({
      install.packages(pkg, dependencies = TRUE, quiet = TRUE)
      cat("   ✓", pkg, "installed successfully\n")
      return(TRUE)
    }, error = function(e) {
      cat("   ✗", pkg, "installation failed:", conditionMessage(e), "\n")
      return(FALSE)
    })
  } else {
    cat("   ✓", pkg, "already installed\n")
    return(TRUE)
  }
}

# Function to install packages from GitHub (if needed)
install_github_package <- function(repo) {
  pkg_name <- basename(repo)
  if (!is_installed(pkg_name)) {
    cat("   Installing from GitHub:", repo, "...\n")
    if (!is_installed("remotes")) {
      install.packages("remotes")
    }
    tryCatch({
      remotes::install_github(repo, quiet = TRUE)
      cat("   ✓", pkg_name, "installed successfully from GitHub\n")
      return(TRUE)
    }, error = function(e) {
      cat("   ✗", pkg_name, "installation from GitHub failed:", conditionMessage(e), "\n")
      return(FALSE)
    })
  } else {
    cat("   ✓", pkg_name, "already installed\n")
    return(TRUE)
  }
}

# =============================================================================
# INSTALLATION PROCESS
# =============================================================================

cat("Starting package installation...\n\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Track installation results
installation_results <- list()

# Install packages by category
for (category in names(required_packages)) {
  cat("\n═══════════════════════════════════════════════════════════════════════\n")
  cat("Installing", category, "packages\n")
  cat("═══════════════════════════════════════════════════════════════════════\n\n")

  pkgs <- required_packages[[category]]
  results <- sapply(pkgs, install_package)
  installation_results[[category]] <- results
}

# =============================================================================
# SPECIAL INSTALLATIONS
# =============================================================================

cat("\n═══════════════════════════════════════════════════════════════════════\n")
cat("Installing special packages\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

# Install ForestTools from GitHub if CRAN version outdated
# Uncomment if needed:
# install_github_package("andrew-plowright/ForestTools")

# =============================================================================
# SYSTEM DEPENDENCIES CHECK
# =============================================================================

cat("\n═══════════════════════════════════════════════════════════════════════\n")
cat("Checking system dependencies\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

# Check for GDAL
tryCatch({
  sf::sf_extSoftVersion()
  cat("✓ GDAL found:\n")
  print(sf::sf_extSoftVersion())
}, error = function(e) {
  cat("⚠️  GDAL check failed. You may need to install GDAL system libraries.\n")
  cat("   Ubuntu/Debian: sudo apt-get install libgdal-dev\n")
  cat("   MacOS: brew install gdal\n")
  cat("   Windows: Install OSGeo4W\n")
})

# Check for ExifTool (required for EXIF extraction)
exiftool_installed <- system2("which", "exiftool", stdout = FALSE, stderr = FALSE) == 0 ||
                      system2("where", "exiftool", stdout = FALSE, stderr = FALSE) == 0

if (exiftool_installed) {
  cat("✓ ExifTool found\n")
} else {
  cat("⚠️  ExifTool not found. Install from https://exiftool.org/\n")
  cat("   This is required for extracting GPS data from drone images.\n")
  cat("   Ubuntu/Debian: sudo apt-get install libimage-exiftool-perl\n")
  cat("   MacOS: brew install exiftool\n")
  cat("   Windows: Download from https://exiftool.org/\n")
}

# Check for OpenDroneMap (Docker or native)
docker_installed <- system2("which", "docker", stdout = FALSE, stderr = FALSE) == 0 ||
                    system2("where", "docker", stdout = FALSE, stderr = FALSE) == 0

if (docker_installed) {
  cat("✓ Docker found (required for OpenDroneMap)\n")
} else {
  cat("⚠️  Docker not found. Required for OpenDroneMap integration.\n")
  cat("   Install from: https://docs.docker.com/get-docker/\n")
}

# =============================================================================
# INSTALLATION SUMMARY
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  INSTALLATION SUMMARY                                                ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

total_packages <- 0
installed_packages <- 0
failed_packages <- c()

for (category in names(installation_results)) {
  results <- installation_results[[category]]
  n_total <- length(results)
  n_installed <- sum(results)
  n_failed <- n_total - n_installed

  total_packages <- total_packages + n_total
  installed_packages <- installed_packages + n_installed

  cat(sprintf("%-30s: %2d/%2d installed", category, n_installed, n_total))
  if (n_failed > 0) {
    cat(" ⚠️\n")
    failed_names <- names(results)[!results]
    failed_packages <- c(failed_packages, failed_names)
  } else {
    cat(" ✓\n")
  }
}

cat("\n")
cat(sprintf("TOTAL: %d/%d packages installed\n", installed_packages, total_packages))

if (length(failed_packages) > 0) {
  cat("\n⚠️  Failed packages:\n")
  for (pkg in failed_packages) {
    cat("   •", pkg, "\n")
  }
  cat("\nYou may need to install these manually or check system dependencies.\n")
} else {
  cat("\n✅ All packages installed successfully!\n")
}

# =============================================================================
# CREATE DIRECTORIES
# =============================================================================

cat("\n═══════════════════════════════════════════════════════════════════════\n")
cat("Creating directory structure\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

# Define directories
dirs <- c(
  "data_input/images",
  "data_input/gcp",
  "data_input/metadata",
  "data_input/training",
  "data_input/previous_surveys",
  "data_processed/orthomosaics",
  "data_processed/dsm",
  "data_processed/point_clouds",
  "data_processed/classifications",
  "data_processed/tree_detections",
  "data_processed/change_detection",
  "outputs/geotiff",
  "outputs/shapefiles",
  "outputs/csv",
  "outputs/reports",
  "outputs/maps",
  "outputs/logs"
)

# Create directories (from drone_pipeline/ folder)
if (basename(getwd()) == "drone_pipeline" ||
    grepl("drone_pipeline$", getwd())) {
  base_path <- "."
} else {
  base_path <- "drone_pipeline"
}

for (dir in dirs) {
  full_path <- file.path(base_path, dir)
  if (!dir.exists(full_path)) {
    dir.create(full_path, recursive = TRUE)
    cat("   Created:", dir, "\n")
  } else {
    cat("   Exists:", dir, "\n")
  }
}

cat("\n✅ Directory structure created\n")

# =============================================================================
# VALIDATION
# =============================================================================

cat("\n═══════════════════════════════════════════════════════════════════════\n")
cat("Validating installation\n")
cat("═══════════════════════════════════════════════════════════════════════\n\n")

# Test key packages
critical_packages <- c("terra", "sf", "lidR", "ForestTools", "randomForest",
                       "rmarkdown", "leaflet", "ggplot2")

all_critical_installed <- TRUE
for (pkg in critical_packages) {
  if (is_installed(pkg)) {
    cat("   ✓", pkg, "\n")
  } else {
    cat("   ✗", pkg, "MISSING (CRITICAL)\n")
    all_critical_installed <- FALSE
  }
}

# =============================================================================
# FINAL MESSAGE
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
if (all_critical_installed && length(failed_packages) == 0) {
  cat("║  ✅ SETUP COMPLETE - READY TO PROCESS DRONE IMAGERY                  ║\n")
} else if (all_critical_installed) {
  cat("║  ⚠️  SETUP COMPLETE WITH WARNINGS                                    ║\n")
} else {
  cat("║  ❌ SETUP INCOMPLETE - CRITICAL PACKAGES MISSING                     ║\n")
}
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

if (all_critical_installed) {
  cat("Next steps:\n")
  cat("1. Edit config/drone_config.R with your project settings\n")
  cat("2. Place drone images in data_input/images/\n")
  cat("3. Run pipeline: source('drone_pipeline_main.R')\n")
  cat("\n")
  cat("For help: See docs/README_DRONE_PIPELINE.md\n")
} else {
  cat("Please install missing critical packages before proceeding.\n")
}

cat("\n")

# Save installation log
log_file <- file.path(base_path, "outputs/logs/installation_log.txt")
sink(log_file)
cat("Drone Pipeline Installation Log\n")
cat("Date:", as.character(Sys.time()), "\n")
cat("R Version:", R.version.string, "\n\n")
cat("Installed packages:", installed_packages, "/", total_packages, "\n")
if (length(failed_packages) > 0) {
  cat("\nFailed packages:\n")
  cat(paste("  -", failed_packages, collapse = "\n"), "\n")
}
sink()

cat("Installation log saved to:", log_file, "\n")
