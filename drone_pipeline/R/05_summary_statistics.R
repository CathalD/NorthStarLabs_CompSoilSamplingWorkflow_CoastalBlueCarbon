# =============================================================================
# MODULE 05: SUMMARY STATISTICS & REPORTING TABLES
# =============================================================================
#
# Purpose: Aggregate all results and generate comprehensive summary statistics
#
# Inputs:
#   - Classification results from Module 02
#   - Tree detection results from Module 03
#   - Change detection results from Module 04 (if available)
#
# Outputs:
#   - Comprehensive summary statistics CSV
#   - Survey metadata JSON
#   - Ready-to-use tables for report generation
#
# Runtime: < 5 minutes
#
# =============================================================================

if (!require("pacman")) install.packages("pacman")
pacman::p_load(terra, sf, dplyr, jsonlite, knitr, kableExtra)

# Source configuration
if (!exists("PROJECT_NAME")) {
  if (file.exists("config/drone_config.R")) {
    source("config/drone_config.R")
  } else if (file.exists("../config/drone_config.R")) {
    source("../config/drone_config.R")
  }
}

#' Generate comprehensive summary statistics
run_summary_statistics <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(" MODULE 05: SUMMARY STATISTICS\n")
  cat("═══════════════════════════════════════════════════════════════════════\n\n")

  summary_data <- list()

  # -------------------------------------------------------------------------
  # Survey metadata
  # -------------------------------------------------------------------------
  cat("📋 Compiling survey metadata...\n")

  summary_data$metadata <- list(
    project_name = PROJECT_NAME,
    survey_date = SURVEY_DATE,
    location = LOCATION_NAME,
    purpose = SURVEY_PURPOSE,
    community = COMMUNITY_NAME,
    surveyor = SURVEYOR_NAME,
    processing_date = as.character(Sys.Date()),
    crs = OUTPUT_CRS
  )

  # -------------------------------------------------------------------------
  # Survey area
  # -------------------------------------------------------------------------
  cat("📏 Calculating survey area...\n")

  # Load classification to get extent
  if (file.exists(file.path(OUTPUT_DIRS$classifications, "vegetation_classification.tif"))) {
    classification <- rast(file.path(OUTPUT_DIRS$classifications, "vegetation_classification.tif"))
    survey_area_m2 <- prod(dim(classification)[1:2]) * prod(res(classification))
    survey_area_ha <- survey_area_m2 / 10000

    summary_data$survey_area <- list(
      area_m2 = survey_area_m2,
      area_ha = survey_area_ha,
      area_acres = survey_area_ha * 2.47105
    )

    cat("   Survey area:", round(survey_area_ha, 2), "hectares\n")
  }

  # -------------------------------------------------------------------------
  # Vegetation classification statistics
  # -------------------------------------------------------------------------
  cat("\n📊 Loading vegetation classification statistics...\n")

  class_stats_file <- file.path(OUTPUT_DIRS$csv, "classification_area_statistics.csv")
  if (file.exists(class_stats_file)) {
    class_stats <- read.csv(class_stats_file)
    class_stats$percent_of_total <- (class_stats$area_ha / survey_area_ha) * 100

    summary_data$vegetation_classes <- class_stats

    cat("   Vegetation cover by class:\n")
    print(class_stats[, c("value", "area_ha", "percent_of_total")])
  }

  # -------------------------------------------------------------------------
  # Tree detection statistics
  # -------------------------------------------------------------------------
  cat("\n🌲 Loading tree detection statistics...\n")

  tree_stats_file <- file.path(OUTPUT_DIRS$csv, "tree_summary_statistics.csv")
  if (file.exists(tree_stats_file)) {
    tree_stats <- read.csv(tree_stats_file)
    summary_data$tree_statistics <- tree_stats

    cat("   Total trees:", tree_stats$total_trees, "\n")
    cat("   Tree density:", round(tree_stats$tree_density_per_ha, 1), "trees/ha\n")
    cat("   Mean height:", round(tree_stats$mean_height_m, 1), "m\n")

    if ("canopy_cover_percent" %in% names(tree_stats)) {
      cat("   Canopy cover:", round(tree_stats$canopy_cover_percent, 1), "%\n")
    }
  }

  # -------------------------------------------------------------------------
  # Change detection statistics (if available)
  # -------------------------------------------------------------------------
  if (ENABLE_CHANGE_DETECTION) {
    cat("\n🔄 Loading change detection statistics...\n")

    change_stats_file <- file.path(OUTPUT_DIRS$csv, "change_statistics.csv")
    if (file.exists(change_stats_file)) {
      change_stats <- read.csv(change_stats_file)
      summary_data$change_statistics <- change_stats

      cat("   Change detection results loaded\n")
    }
  }

  # -------------------------------------------------------------------------
  # Save comprehensive summary
  # -------------------------------------------------------------------------
  cat("\n💾 Saving summary files...\n")

  # Save as JSON
  summary_json <- file.path(OUTPUT_DIRS$reports, "survey_summary.json")
  dir.create(dirname(summary_json), recursive = TRUE, showWarnings = FALSE)
  write_json(summary_data, summary_json, pretty = TRUE, auto_unbox = TRUE)
  cat("   Saved JSON:", summary_json, "\n")

  # Save as formatted text report
  summary_txt <- file.path(OUTPUT_DIRS$reports, "survey_summary.txt")
  sink(summary_txt)
  cat("╔══════════════════════════════════════════════════════════════════════╗\n")
  cat("║  DRONE SURVEY SUMMARY REPORT                                         ║\n")
  cat("╚══════════════════════════════════════════════════════════════════════╝\n\n")
  cat("PROJECT:", PROJECT_NAME, "\n")
  cat("LOCATION:", LOCATION_NAME, "\n")
  cat("DATE:", SURVEY_DATE, "\n")
  cat("COMMUNITY:", COMMUNITY_NAME, "\n")
  cat("PROCESSED:", as.character(Sys.Date()), "\n\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("SURVEY AREA\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("  Total area:", round(survey_area_ha, 2), "hectares (", round(survey_area_ha * 2.47105, 2), "acres)\n\n")

  if (!is.null(summary_data$vegetation_classes)) {
    cat("═══════════════════════════════════════════════════════════════════════\n")
    cat("VEGETATION CLASSIFICATION\n")
    cat("═══════════════════════════════════════════════════════════════════════\n")
    for (i in 1:nrow(class_stats)) {
      cat(sprintf("  Class %d: %.2f ha (%.1f%%)\n",
                  class_stats$value[i],
                  class_stats$area_ha[i],
                  class_stats$percent_of_total[i]))
    }
    cat("\n")
  }

  if (!is.null(summary_data$tree_statistics)) {
    cat("═══════════════════════════════════════════════════════════════════════\n")
    cat("TREE/SHRUB DETECTION\n")
    cat("═══════════════════════════════════════════════════════════════════════\n")
    cat("  Total individuals:", tree_stats$total_trees, "\n")
    cat("  Density:", round(tree_stats$tree_density_per_ha, 1), "stems/hectare\n")
    cat("  Height range:", round(tree_stats$min_height_m, 1), "-", round(tree_stats$max_height_m, 1), "m\n")
    cat("  Mean height:", round(tree_stats$mean_height_m, 1), "±", round(tree_stats$sd_height_m, 1), "m\n")
    if ("canopy_cover_percent" %in% names(tree_stats)) {
      cat("  Canopy cover:", round(tree_stats$canopy_cover_percent, 1), "%\n")
    }
    cat("\n")
  }

  if (ENABLE_CHANGE_DETECTION && !is.null(summary_data$change_statistics)) {
    cat("═══════════════════════════════════════════════════════════════════════\n")
    cat("CHANGE DETECTION\n")
    cat("═══════════════════════════════════════════════════════════════════════\n")
    for (i in 1:nrow(change_stats)) {
      cat(sprintf("  Change type %d: %.2f ha\n", change_stats$value[i], change_stats$area_ha[i]))
    }
    cat("\n")
  }

  sink()
  cat("   Saved text report:", summary_txt, "\n")

  cat("\n✅ Module 05 complete!\n")
  cat("\nNext step: Generate final report\n")
  cat("   source('R/06_generate_report.R')\n\n")

  return(summary_data)
}

if (!interactive() || exists("RUN_MODULE_05")) {
  results <- run_summary_statistics()
}
