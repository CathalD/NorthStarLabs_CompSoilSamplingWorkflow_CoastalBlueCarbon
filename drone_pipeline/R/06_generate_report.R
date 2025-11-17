# =============================================================================
# MODULE 06: AUTOMATED REPORT GENERATION
# =============================================================================
#
# Purpose: Generate professional PDF and HTML reports from R Markdown template
#
# Inputs:
#   - Summary data from Module 05
#   - All processed outputs from previous modules
#   - R Markdown template
#
# Outputs:
#   - PDF report (professional, print-ready)
#   - HTML report (interactive, with web maps)
#
# Runtime: 5-10 minutes
#
# =============================================================================

if (!require("pacman")) install.packages("pacman")
pacman::p_load(rmarkdown, knitr, jsonlite, leaflet, here)

# Source configuration
if (!exists("PROJECT_NAME")) {
  if (file.exists("config/drone_config.R")) {
    source("config/drone_config.R")
  } else if (file.exists("../config/drone_config.R")) {
    source("../config/drone_config.R")
  }
}

#' Generate professional survey report
#'
#' @export
generate_drone_report <- function() {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(" MODULE 06: AUTOMATED REPORT GENERATION\n")
  cat("═══════════════════════════════════════════════════════════════════════\n\n")

  # Load summary data
  summary_json <- file.path(OUTPUT_DIRS$reports, "survey_summary.json")
  if (file.exists(summary_json)) {
    summary_data <- fromJSON(summary_json)
  } else {
    warning("Summary data not found. Run Module 05 first.")
    summary_data <- NULL
  }

  # Find R Markdown template
  template_path <- "templates/drone_survey_report.Rmd"
  if (!file.exists(template_path)) {
    template_path <- "../templates/drone_survey_report.Rmd"
  }

  if (!file.exists(template_path)) {
    stop("Report template not found: ", template_path)
  }

  cat("📄 Using template:", template_path, "\n")

  # Set up parameters for report
  report_params <- list(
    project_name = PROJECT_NAME,
    location_name = LOCATION_NAME,
    survey_date = SURVEY_DATE,
    community_name = COMMUNITY_NAME,
    survey_purpose = SURVEY_PURPOSE,
    surveyor_name = SURVEYOR_NAME,
    summary_data = summary_data,
    results_dir = "."
  )

  # Generate PDF report
  if ("PDF" %in% REPORT_FORMAT) {
    cat("\n📊 Generating PDF report...\n")

    pdf_output <- file.path(OUTPUT_DIRS$reports,
                           paste0(PROJECT_NAME, "_Report_", Sys.Date(), ".pdf"))

    tryCatch({
      rmarkdown::render(
        input = template_path,
        output_format = "pdf_document",
        output_file = basename(pdf_output),
        output_dir = dirname(pdf_output),
        params = report_params,
        quiet = TRUE
      )

      cat("   ✓ PDF report generated:", pdf_output, "\n")

    }, error = function(e) {
      warning("PDF generation failed: ", e$message)
      cat("   ⚠️  PDF generation requires LaTeX. Install TinyTeX:\n")
      cat("      install.packages('tinytex')\n")
      cat("      tinytex::install_tinytex()\n")
    })
  }

  # Generate HTML report
  if ("HTML" %in% REPORT_FORMAT) {
    cat("\n🌐 Generating HTML report...\n")

    html_output <- file.path(OUTPUT_DIRS$reports,
                            paste0(PROJECT_NAME, "_Report_", Sys.Date(), ".html"))

    tryCatch({
      rmarkdown::render(
        input = template_path,
        output_format = "html_document",
        output_file = basename(html_output),
        output_dir = dirname(html_output),
        params = report_params,
        quiet = TRUE
      )

      cat("   ✓ HTML report generated:", html_output, "\n")

    }, error = function(e) {
      warning("HTML generation failed: ", e$message)
    })
  }

  # Generate interactive map if requested
  if (INCLUDE_INTERACTIVE_MAP) {
    cat("\n🗺️  Generating interactive web map...\n")

    tree_points_file <- file.path(OUTPUT_DIRS$shapefiles, "tree_locations.shp")

    if (file.exists(tree_points_file)) {
      tree_points <- sf::st_read(tree_points_file, quiet = TRUE)

      # Transform to WGS84 for Leaflet
      tree_points_wgs84 <- sf::st_transform(tree_points, crs = 4326)

      # Create interactive map
      map <- leaflet(tree_points_wgs84) %>%
        addTiles() %>%
        addCircleMarkers(
          radius = 3,
          color = "red",
          fillOpacity = 0.5,
          popup = ~paste0(
            "<b>Tree ID:</b> ", tree_id, "<br>",
            "<b>Height:</b> ", round(height, 1), " m<br>",
            "<b>Lat:</b> ", round(latitude, 5), "<br>",
            "<b>Long:</b> ", round(longitude, 5)
          )
        ) %>%
        addScaleBar(position = "bottomleft")

      # Save map
      map_file <- file.path(OUTPUT_DIRS$maps, "interactive_tree_map.html")
      htmlwidgets::saveWidget(map, map_file, selfcontained = TRUE)

      cat("   ✓ Interactive map saved:", map_file, "\n")
    }
  }

  cat("\n✅ Module 06 complete!\n")
  cat("\n═══════════════════════════════════════════════════════════════════════\n")
  cat("   ALL PROCESSING COMPLETE\n")
  cat("═══════════════════════════════════════════════════════════════════════\n\n")

  cat("📂 Output files are located in:\n")
  cat("   ", OUTPUT_DIRS$reports, "\n")
  cat("   ", OUTPUT_DIRS$shapefiles, "\n")
  cat("   ", OUTPUT_DIRS$csv, "\n")
  cat("   ", OUTPUT_DIRS$geotiff, "\n")
  cat("   ", OUTPUT_DIRS$maps, "\n\n")

  cat("📧 Share the PDF report with community partners and stakeholders.\n")
  cat("🗺️  Open the HTML map in a web browser for interactive exploration.\n\n")
}

if (!interactive() || exists("RUN_MODULE_06")) {
  generate_drone_report()
}
