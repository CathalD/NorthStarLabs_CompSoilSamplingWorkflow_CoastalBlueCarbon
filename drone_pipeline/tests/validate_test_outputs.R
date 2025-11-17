# =============================================================================
# VALIDATE TEST OUTPUTS
# =============================================================================
#
# Validates that all pipeline modules produced expected outputs
#
# Checks:
#   - Module 01: Orthomosaic, DSM, point cloud
#   - Module 02: Classification raster, spectral indices, statistics
#   - Module 03: CHM, tree locations, tree metrics
#   - Module 05: Summary statistics
#   - Module 06: Reports and maps
#
# =============================================================================

cat("\n")
cat("╔══════════════════════════════════════════════════════════════════════╗\n")
cat("║  PIPELINE OUTPUT VALIDATION                                          ║\n")
cat("╚══════════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Load required packages
if (!require("terra", quietly = TRUE)) stop("terra package required")
if (!require("sf", quietly = TRUE)) stop("sf package required")

# Initialize results
validation <- list(
  total = 0,
  passed = 0,
  failed = 0,
  warnings = 0,
  errors = c()
)

# Helper function
check_output <- function(condition, pass_msg, fail_msg, is_warning = FALSE) {
  validation$total <<- validation$total + 1

  if (condition) {
    cat("  ✓", pass_msg, "\n")
    validation$passed <<- validation$passed + 1
    return(TRUE)
  } else {
    if (is_warning) {
      cat("  ⚠️ ", fail_msg, "\n")
      validation$warnings <<- validation$warnings + 1
    } else {
      cat("  ✗", fail_msg, "\n")
      validation$failed <<- validation$failed + 1
      validation$errors <<- c(validation$errors, fail_msg)
    }
    return(FALSE)
  }
}

# =============================================================================
# MODULE 01: ORTHOMOSAIC GENERATION
# =============================================================================

cat("Checking Module 01 outputs (Orthomosaic Generation)...\n")

# Orthomosaic
ortho_paths <- list.files(
  "data_processed/orthomosaics",
  pattern = "orthomosaic.*\\.tif$",
  full.names = TRUE,
  recursive = TRUE
)

ortho_exists <- length(ortho_paths) > 0

check_output(
  ortho_exists,
  "Orthomosaic exists",
  "Orthomosaic not found"
)

if (ortho_exists) {
  ortho <- rast(ortho_paths[1])

  # Check CRS
  has_crs <- !is.na(crs(ortho))
  check_output(
    has_crs,
    paste("Orthomosaic has CRS:", crs(ortho, describe = TRUE)$name),
    "Orthomosaic missing CRS"
  )

  # Check dimensions
  dims <- dim(ortho)
  reasonable_size <- dims[1] > 1000 && dims[1] < 20000 && dims[2] > 1000 && dims[2] < 20000

  check_output(
    reasonable_size,
    paste("Orthomosaic dimensions reasonable:", paste(dims[1:2], collapse = " x ")),
    paste("Orthomosaic dimensions unusual:", paste(dims[1:2], collapse = " x ")),
    is_warning = TRUE
  )

  # Check bands
  n_bands <- nlyr(ortho)
  check_output(
    n_bands >= 3,
    paste("Orthomosaic has", n_bands, "bands (RGB or more)"),
    paste("Orthomosaic has only", n_bands, "band(s)"),
    is_warning = n_bands < 3
  )
}

# DSM
dsm_paths <- list.files(
  "data_processed",
  pattern = "dsm.*\\.tif$",
  full.names = TRUE,
  recursive = TRUE
)

check_output(
  length(dsm_paths) > 0,
  "DSM exists",
  "DSM not found",
  is_warning = TRUE
)

# Point cloud (optional)
pc_paths <- list.files(
  "data_processed",
  pattern = "\\.(laz|las|ply)$",
  full.names = TRUE,
  recursive = TRUE
)

check_output(
  length(pc_paths) > 0,
  "Point cloud exists",
  "Point cloud not found (optional)",
  is_warning = TRUE
)

# =============================================================================
# MODULE 02: VEGETATION CLASSIFICATION
# =============================================================================

cat("\nChecking Module 02 outputs (Vegetation Classification)...\n")

# Classification raster
class_path <- "outputs/data_processed/classifications/vegetation_classification.tif"

class_exists <- file.exists(class_path)
check_output(
  class_exists,
  "Classification raster exists",
  "Classification raster not found"
)

if (class_exists) {
  class_raster <- rast(class_path)

  # Check number of classes
  class_values <- unique(values(class_raster, na.rm = TRUE))
  n_classes <- length(class_values)

  check_output(
    n_classes >= 3 && n_classes <= 10,
    paste("Classification has", n_classes, "classes"),
    paste("Unusual number of classes:", n_classes),
    is_warning = n_classes < 3 || n_classes > 10
  )

  # Check classes are consecutive integers starting from 1
  expected_classes <- 1:n_classes
  all_present <- all(expected_classes %in% class_values)

  check_output(
    all_present,
    "Class values are valid (1 to n)",
    "Class values have gaps or don't start at 1",
    is_warning = TRUE
  )
}

# Spectral indices
indices <- c("NDVI", "ExG", "VARI", "GLI")
indices_found <- 0

for (idx in indices) {
  idx_path <- file.path("outputs/data_processed/classifications/spectral_indices",
                        paste0(idx, ".tif"))
  if (file.exists(idx_path)) indices_found <- indices_found + 1
}

check_output(
  indices_found >= 3,
  paste("Spectral indices calculated (", indices_found, "/", length(indices), ")"),
  paste("Missing spectral indices (only", indices_found, "found)")
)

# Classification statistics
check_output(
  file.exists("outputs/csv/classification_area_statistics.csv"),
  "Area statistics CSV exists",
  "Area statistics CSV not found"
)

# Classification map
check_output(
  file.exists("outputs/data_processed/classifications/classification_map.png"),
  "Classification map PNG exists",
  "Classification map PNG not found",
  is_warning = TRUE
)

# =============================================================================
# MODULE 03: TREE DETECTION
# =============================================================================

cat("\nChecking Module 03 outputs (Tree Detection)...\n")

# CHM
chm_path <- "outputs/data_processed/tree_detections/chm.tif"

chm_exists <- file.exists(chm_path)
check_output(
  chm_exists,
  "CHM raster exists",
  "CHM raster not found"
)

if (chm_exists) {
  chm <- rast(chm_path)

  # Check CHM values are reasonable
  chm_stats <- global(chm, c("min", "max"), na.rm = TRUE)

  reasonable_heights <- chm_stats$min >= 0 && chm_stats$max < 50

  check_output(
    reasonable_heights,
    paste("CHM heights reasonable (", round(chm_stats$min, 1), "-",
          round(chm_stats$max, 1), "m)"),
    paste("CHM heights unusual (", round(chm_stats$min, 1), "-",
          round(chm_stats$max, 1), "m)"),
    is_warning = !reasonable_heights
  )
}

# Tree locations shapefile
tree_shp <- "outputs/shapefiles/tree_locations.shp"

trees_exist <- file.exists(tree_shp)
check_output(
  trees_exist,
  "Tree locations shapefile exists",
  "Tree locations shapefile not found"
)

if (trees_exist) {
  trees <- st_read(tree_shp, quiet = TRUE)

  # Check tree count
  n_trees <- nrow(trees)

  reasonable_count <- n_trees >= 10 && n_trees <= 1000

  check_output(
    reasonable_count,
    paste("Tree count reasonable (", n_trees, "trees)"),
    paste("Tree count unusual (", n_trees, "trees)"),
    is_warning = !reasonable_count
  )

  # Check required fields
  required_fields <- c("tree_id", "height", "latitude", "longitude")
  has_fields <- all(required_fields %in% names(trees))

  check_output(
    has_fields,
    "Tree metrics have required fields",
    paste("Missing fields:", paste(required_fields[!required_fields %in% names(trees)],
                                   collapse = ", "))
  )

  # Check height values
  if ("height" %in% names(trees)) {
    height_range <- range(trees$height, na.rm = TRUE)

    reasonable_heights <- height_range[1] >= 0.5 && height_range[2] <= 50

    check_output(
      reasonable_heights,
      paste("Tree heights reasonable (", round(height_range[1], 1), "-",
            round(height_range[2], 1), "m)"),
      paste("Tree heights unusual (", round(height_range[1], 1), "-",
            round(height_range[2], 1), "m)"),
      is_warning = !reasonable_heights
    )
  }
}

# Crown polygons (optional)
check_output(
  file.exists("outputs/shapefiles/tree_crowns.shp"),
  "Crown polygons shapefile exists",
  "Crown polygons not found (only generated with watershed method)",
  is_warning = TRUE
)

# Tree metrics CSV
check_output(
  file.exists("outputs/csv/tree_metrics.csv"),
  "Tree metrics CSV exists",
  "Tree metrics CSV not found"
)

# =============================================================================
# MODULE 05: SUMMARY STATISTICS
# =============================================================================

cat("\nChecking Module 05 outputs (Summary Statistics)...\n")

# Summary JSON
summary_json <- "outputs/reports/survey_summary.json"

json_exists <- file.exists(summary_json)
check_output(
  json_exists,
  "Summary JSON exists",
  "Summary JSON not found"
)

if (json_exists && requireNamespace("jsonlite", quietly = TRUE)) {
  summary_data <- jsonlite::fromJSON(summary_json)

  # Check survey area
  if (!is.null(summary_data$survey_area)) {
    area_ha <- summary_data$survey_area$area_ha

    reasonable_area <- area_ha > 0.1 && area_ha < 100

    check_output(
      reasonable_area,
      paste("Survey area reasonable (", round(area_ha, 2), "hectares)"),
      paste("Survey area unusual (", round(area_ha, 2), "hectares)"),
      is_warning = !reasonable_area
    )
  }
}

# Summary text
check_output(
  file.exists("outputs/reports/survey_summary.txt"),
  "Summary TXT exists",
  "Summary TXT not found"
)

# =============================================================================
# MODULE 06: REPORT GENERATION
# =============================================================================

cat("\nChecking Module 06 outputs (Reports & Maps)...\n")

# PDF report
pdf_reports <- list.files("outputs/reports", pattern = ".*\\.pdf$", full.names = TRUE)

check_output(
  length(pdf_reports) > 0,
  paste("PDF report exists:", basename(pdf_reports[1])),
  "PDF report not found (LaTeX may not be installed)",
  is_warning = TRUE
)

if (length(pdf_reports) > 0) {
  pdf_size <- file.size(pdf_reports[1])

  check_output(
    pdf_size > 10000,  # At least 10 KB
    paste("PDF report has content (", round(pdf_size / 1024), "KB)"),
    "PDF report is too small (may be corrupted)",
    is_warning = pdf_size < 10000
  )
}

# HTML report
html_reports <- list.files("outputs/reports", pattern = ".*\\.html$", full.names = TRUE)

check_output(
  length(html_reports) > 0,
  paste("HTML report exists:", basename(html_reports[1])),
  "HTML report not found"
)

# Interactive map
map_path <- "outputs/maps/interactive_tree_map.html"

check_output(
  file.exists(map_path),
  "Interactive map exists",
  "Interactive map not found",
  is_warning = TRUE
)

if (file.exists(map_path)) {
  map_size <- file.size(map_path)

  check_output(
    map_size > 1000,
    paste("Interactive map has content (", round(map_size / 1024), "KB)"),
    "Interactive map is too small (may not have loaded tree data)",
    is_warning = map_size < 1000
  )
}

# =============================================================================
# VALIDATION SUMMARY
# =============================================================================

cat("\n")
cat("═══════════════════════════════════════════════════════════════════════\n")
cat("VALIDATION SUMMARY\n")
cat("═══════════════════════════════════════════════════════════════════════\n")

cat("  Total checks:", validation$total, "\n")
cat("  Passed:      ", validation$passed, "\n")
cat("  Failed:      ", validation$failed, "\n")
cat("  Warnings:    ", validation$warnings, "\n")

if (validation$failed > 0) {
  cat("\n❌ VALIDATION FAILED\n\n")
  cat("Critical errors:\n")
  for (err in validation$errors) {
    cat("  •", err, "\n")
  }
  cat("\nSome pipeline modules did not produce expected outputs.\n")
  cat("Check error logs and see docs/TROUBLESHOOTING.md\n\n")

  return(invisible(FALSE))

} else if (validation$warnings > 0) {
  cat("\n✅ VALIDATION PASSED WITH WARNINGS\n\n")
  cat("All critical outputs are present, but some optional outputs are missing.\n")
  cat("This is usually okay, but review warnings above.\n\n")

  return(invisible(TRUE))

} else {
  cat("\n✅ ALL VALIDATIONS PASSED!\n\n")
  cat("Your pipeline is working correctly. You can now use it with your own data.\n\n")

  cat("Next steps:\n")
  cat("1. Review PDF report: outputs/reports/[ProjectName]_Report.pdf\n")
  cat("2. Explore interactive map: outputs/maps/interactive_tree_map.html\n")
  cat("3. Try with your own drone survey data\n\n")

  return(invisible(TRUE))
}
