#' Automated Report Generation Functions
#'
#' @name report_generate
NULL

#' Generate technical habitat assessment report
#'
#' Creates comprehensive PDF report with technical details
#'
#' @param results_list List with processing results (from process_lidar)
#' @param report_title Report title
#' @param author Author name
#' @param output_file Output PDF filename
#' @param study_area_description Description of study area
#' @return Path to generated report
#' @export
#' @examples
#' \dontrun{
#' results <- process_lidar("tile.las", "output/")
#' report <- generate_technical_report(
#'   results,
#'   report_title = "Moose Habitat Assessment - Traditional Territory",
#'   author = "Conservation Team",
#'   output_file = "technical_report.pdf"
#' )
#' }
generate_technical_report <- function(results_list, report_title,
                                     author = "habitatLidar Analysis",
                                     output_file = "technical_report.pdf",
                                     study_area_description = NULL) {

  logger::log_info("Generating technical report...")

  # Get template path
  template_path <- system.file(
    "rmarkdown/technical_report_template.Rmd",
    package = "habitatLidar"
  )

  if (!file.exists(template_path)) {
    logger::log_warn("Template not found, creating default report")
    template_path <- create_default_technical_template()
  }

  # Prepare data for report
  report_data <- list(
    title = report_title,
    author = author,
    date = format(Sys.Date(), "%B %d, %Y"),
    study_area = study_area_description,
    results = results_list
  )

  # Render report
  rmarkdown::render(
    input = template_path,
    output_file = output_file,
    params = report_data,
    envir = new.env()
  )

  logger::log_info("Technical report generated: {output_file}")

  return(output_file)
}

#' Generate community-friendly summary report
#'
#' Creates accessible PDF report with plain language and visual emphasis
#'
#' @param results_list List with processing results
#' @param report_title Report title
#' @param community_name Name of community/nation
#' @param output_file Output PDF filename
#' @param key_findings Vector of key findings to highlight
#' @return Path to generated report
#' @export
generate_community_report <- function(results_list, report_title,
                                     community_name = NULL,
                                     output_file = "community_summary.pdf",
                                     key_findings = NULL) {

  logger::log_info("Generating community-friendly report...")

  # Get template path
  template_path <- system.file(
    "rmarkdown/community_report_template.Rmd",
    package = "habitatLidar"
  )

  if (!file.exists(template_path)) {
    logger::log_warn("Template not found, creating default report")
    template_path <- create_default_community_template()
  }

  # Prepare data
  report_data <- list(
    title = report_title,
    community = community_name,
    date = format(Sys.Date(), "%B %d, %Y"),
    findings = key_findings,
    results = results_list
  )

  # Render report
  rmarkdown::render(
    input = template_path,
    output_file = output_file,
    params = report_data,
    envir = new.env()
  )

  logger::log_info("Community report generated: {output_file}")

  return(output_file)
}

#' Create default technical report template
#'
#' @return Path to template file
#' @keywords internal
create_default_technical_template <- function() {
  template_content <- '---
title: "`r params$title`"
author: "`r params$author`"
date: "`r params$date`"
output:
  pdf_document:
    toc: true
    toc_depth: 3
    number_sections: true
params:
  title: "Habitat Assessment Report"
  author: "Analysis Team"
  date: !r Sys.Date()
  study_area: NULL
  results: NULL
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)
library(ggplot2)
library(knitr)
library(terra)
```

# Executive Summary

This report presents the results of lidar-based habitat structure analysis
for the study area.

# Study Area

```{r}
if (!is.null(params$study_area)) {
  cat(params$study_area)
} else {
  cat("Study area description not provided.")
}
```

# Methods

## Data Acquisition

Airborne lidar point cloud data was processed using scientifically validated
methods implemented in the habitatLidar R package.

## Processing Workflow

1. Data preprocessing and quality control
2. Ground classification and height normalization
3. Canopy and understory metrics calculation
4. Individual tree detection and segmentation
5. Habitat suitability modeling

# Results

## Data Quality

```{r}
if (!is.null(params$results$las)) {
  qc <- quality_control_report(params$results$las, return_report = TRUE)

  cat(sprintf("- Study area: %s\\n", qc$extent$area_formatted))
  cat(sprintf("- Point density: %.2f pts/m²\\n", qc$points$point_density))
  cat(sprintf("- Total points: %s\\n", format(qc$points$total_points, big.mark = ",")))
}
```

## Canopy Structure

Summary statistics for canopy metrics...

## Habitat Suitability

Results of species-specific habitat modeling...

# Discussion

## Key Findings

## Management Recommendations

## Limitations and Uncertainties

# References

Relevant scientific literature cited in methods...

# Appendix

Additional technical details...
'

  temp_file <- tempfile(fileext = ".Rmd")
  writeLines(template_content, temp_file)
  return(temp_file)
}

#' Create default community report template
#'
#' @return Path to template file
#' @keywords internal
create_default_community_template <- function() {
  template_content <- '---
title: "`r params$title`"
subtitle: "Plain Language Summary"
date: "`r params$date`"
output:
  pdf_document:
    toc: false
params:
  title: "Habitat Assessment"
  community: NULL
  date: !r Sys.Date()
  findings: NULL
  results: NULL
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE, fig.height = 6)
library(ggplot2)
```

# What We Found

This report summarizes what we learned about wildlife habitat in your area
using advanced technology to map the forest structure.

## Key Findings

```{r}
if (!is.null(params$findings)) {
  for (i in seq_along(params$findings)) {
    cat(sprintf("%d. %s\\n\\n", i, params$findings[i]))
  }
}
```

## What This Means

The forest structure provides important habitat for wildlife...

## Maps and Visualizations

Large, clear maps showing habitat quality...

## Recommendations

Suggestions for conservation and management...
'

  temp_file <- tempfile(fileext = ".Rmd")
  writeLines(template_content, temp_file)
  return(temp_file)
}

#' Generate quick summary statistics table
#'
#' @param results_list Processing results
#' @return Data frame with summary stats
#' @export
generate_summary_table <- function(results_list) {
  summary_data <- data.frame(
    Metric = character(),
    Value = character(),
    stringsAsFactors = FALSE
  )

  # Add available metrics
  if (!is.null(results_list$canopy_metrics)) {
    metrics_summary <- terra::global(
      results_list$canopy_metrics,
      fun = "mean",
      na.rm = TRUE
    )

    for (i in 1:nrow(metrics_summary)) {
      summary_data <- rbind(summary_data, data.frame(
        Metric = rownames(metrics_summary)[i],
        Value = sprintf("%.2f", metrics_summary[i, 1])
      ))
    }
  }

  if (!is.null(results_list$trees)) {
    summary_data <- rbind(summary_data, data.frame(
      Metric = "Number of Trees Detected",
      Value = as.character(nrow(results_list$trees$attributes))
    ))

    summary_data <- rbind(summary_data, data.frame(
      Metric = "Mean Tree Height (m)",
      Value = sprintf("%.1f", mean(results_list$trees$attributes$height))
    ))
  }

  return(summary_data)
}

#' Create habitat suitability map for report
#'
#' @param hsi_raster HSI raster
#' @param species Species name
#' @param aoi Optional area of interest boundary
#' @return ggplot object
#' @export
create_hsi_map <- function(hsi_raster, species, aoi = NULL) {
  # Convert raster to data frame
  hsi_df <- as.data.frame(hsi_raster, xy = TRUE)
  names(hsi_df)[3] <- "hsi"

  # Create plot
  p <- ggplot2::ggplot() +
    ggplot2::geom_raster(
      data = hsi_df,
      ggplot2::aes(x = x, y = y, fill = hsi)
    ) +
    ggplot2::scale_fill_viridis_c(
      name = "Habitat\nSuitability",
      limits = c(0, 1),
      breaks = c(0, 0.3, 0.5, 0.7, 1.0),
      labels = c("Poor", "Low", "Moderate", "High", "Excellent")
    ) +
    ggplot2::labs(
      title = sprintf("%s Habitat Suitability", tools::toTitleCase(species)),
      x = "Easting (m)",
      y = "Northing (m)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, size = 16, face = "bold"),
      legend.position = "right"
    ) +
    ggplot2::coord_equal()

  # Add AOI boundary if provided
  if (!is.null(aoi)) {
    p <- p + ggplot2::geom_sf(
      data = aoi,
      fill = NA,
      color = "black",
      linewidth = 1
    )
  }

  return(p)
}

#' Create tree size distribution plot
#'
#' @param tree_attributes Tree attributes data frame
#' @return ggplot object
#' @export
create_tree_distribution_plot <- function(tree_attributes) {
  p <- ggplot2::ggplot(tree_attributes, ggplot2::aes(x = height)) +
    ggplot2::geom_histogram(
      bins = 30,
      fill = "#2E7D32",
      color = "white"
    ) +
    ggplot2::labs(
      title = "Tree Height Distribution",
      x = "Height (m)",
      y = "Number of Trees"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, size = 14, face = "bold")
    )

  return(p)
}

#' Create vertical structure profile plot
#'
#' @param metrics_df Metrics data frame with VDR components
#' @return ggplot object
#' @export
create_vertical_structure_plot <- function(metrics_df) {
  # Prepare data
  vdr_data <- data.frame(
    Layer = c("0-2m", "2-8m", "8-16m", "16+m"),
    Proportion = c(
      mean(metrics_df$vdr_ground_2m, na.rm = TRUE),
      mean(metrics_df$vdr_2_8m, na.rm = TRUE),
      mean(metrics_df$vdr_8_16m, na.rm = TRUE),
      mean(metrics_df$vdr_16plus, na.rm = TRUE)
    )
  )

  vdr_data$Layer <- factor(vdr_data$Layer, levels = vdr_data$Layer)

  p <- ggplot2::ggplot(vdr_data, ggplot2::aes(x = Layer, y = Proportion, fill = Layer)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_viridis_d() +
    ggplot2::labs(
      title = "Vertical Distribution of Vegetation",
      x = "Height Layer",
      y = "Proportion of Points"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, size = 14, face = "bold"),
      legend.position = "none"
    )

  return(p)
}

#' Generate complete habitat assessment report package
#'
#' Creates both technical and community reports plus supporting materials
#'
#' @param results Processing results
#' @param output_dir Output directory for report package
#' @param project_info List with project information
#' @return List of generated files
#' @export
#' @examples
#' \dontrun{
#' project_info <- list(
#'   title = "Traditional Territory Habitat Assessment",
#'   community = "First Nation Name",
#'   species = "moose",
#'   key_findings = c(
#'     "High quality moose browse habitat identified in northern area",
#'     "Old-growth forest structure present in protected zones"
#'   )
#' )
#' report_package <- generate_report_package(results, "reports/", project_info)
#' }
generate_report_package <- function(results, output_dir, project_info) {
  logger::log_info("Generating complete report package...")

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  generated_files <- list()

  # 1. Technical report
  tech_file <- file.path(output_dir, "technical_report.pdf")
  generate_technical_report(
    results,
    report_title = project_info$title,
    author = project_info$author %||% "Analysis Team",
    output_file = tech_file,
    study_area_description = project_info$study_area_desc
  )
  generated_files$technical <- tech_file

  # 2. Community report
  community_file <- file.path(output_dir, "community_summary.pdf")
  generate_community_report(
    results,
    report_title = project_info$title,
    community_name = project_info$community,
    output_file = community_file,
    key_findings = project_info$key_findings
  )
  generated_files$community <- community_file

  # 3. Summary statistics CSV
  summary_file <- file.path(output_dir, "summary_statistics.csv")
  summary_table <- generate_summary_table(results)
  write.csv(summary_table, summary_file, row.names = FALSE)
  generated_files$summary_csv <- summary_file

  # 4. Maps (PNG format for easy viewing)
  if (!is.null(results$hsi)) {
    maps_dir <- file.path(output_dir, "maps")
    dir.create(maps_dir, showWarnings = FALSE)

    for (species in names(results$hsi)) {
      map_file <- file.path(maps_dir, sprintf("%s_hsi_map.png", species))
      p <- create_hsi_map(results$hsi[[species]], species)
      ggplot2::ggsave(map_file, p, width = 10, height = 8, dpi = 300)
      generated_files[[sprintf("map_%s", species)]] <- map_file
    }
  }

  # 5. Tree data (if available)
  if (!is.null(results$trees)) {
    tree_file <- file.path(output_dir, "tree_inventory.csv")
    write.csv(results$trees$attributes, tree_file, row.names = FALSE)
    generated_files$tree_inventory <- tree_file

    # Tree distribution plot
    tree_plot_file <- file.path(output_dir, "tree_distribution.png")
    p <- create_tree_distribution_plot(results$trees$attributes)
    ggplot2::ggsave(tree_plot_file, p, width = 8, height = 6, dpi = 300)
    generated_files$tree_plot <- tree_plot_file
  }

  logger::log_info("Report package generated in: {output_dir}")
  logger::log_info("Generated {length(generated_files)} files")

  return(generated_files)
}
