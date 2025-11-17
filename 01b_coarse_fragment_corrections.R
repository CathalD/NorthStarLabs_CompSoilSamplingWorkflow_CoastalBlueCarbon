# ============================================================================
# MODULE 01B: COARSE FRAGMENT CORRECTIONS FOR FOREST SOILS
# ============================================================================
# Purpose: Apply coarse fragment corrections to forest soil carbon stocks
# Author: Adapted from blue carbon workflow for forest carbon accounting
# Last Updated: 2024
#
# DESCRIPTION:
# Forest soils often contain significant coarse fragments (>2mm diameter
# particles: gravel, stones, rocks). These must be excluded from soil carbon
# calculations as they do not contribute to carbon storage. This module
# provides functions to measure and correct for coarse fragment content.
#
# METHODS:
#   1. Volumetric method: % volume occupied by coarse fragments
#   2. Gravimetric method: Convert mass % to volume % using particle density
#   3. Visual estimation: Field-based classes (0-5%, 5-15%, 15-35%, etc.)
#
# CORRECTIONS APPLIED TO:
#   - Bulk density (fine earth <2mm only)
#   - Soil organic carbon stock calculations
#   - Depth-based carbon stock aggregations
#
# REQUIREMENTS:
#   - Configuration file (blue_carbon_config.R) must be loaded
#   - Coarse fragment data in core_samples.csv (column: coarse_frag_pct)
#
# USAGE:
#   source("blue_carbon_config.R")
#   source("01b_coarse_fragment_corrections.R")
#   cores_corrected <- apply_coarse_fragment_corrections(cores_data)
# ============================================================================

# Load required libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,    # Data manipulation
  ggplot2       # Plotting
)

cat("=======================================================\n")
cat("MODULE 01B: COARSE FRAGMENT CORRECTIONS\n")
cat("=======================================================\n\n")

# ============================================================================
# FUNCTION DEFINITIONS
# ============================================================================

#' Convert coarse fragment mass % to volume %
#'
#' @param mass_pct Coarse fragment content by mass (%)
#' @param particle_density Density of rock particles (g/cm³), default 2.65 for quartz
#' @param bulk_density Bulk density of fine earth (g/cm³)
#' @return Coarse fragment content by volume (%)
#' @references IPCC 2006 Guidelines, Volume 4, Chapter 2
mass_to_volume_cf <- function(mass_pct, particle_density = 2.65, bulk_density) {

  # Convert mass fraction to volume fraction
  # mass_frac = (vol_frac × particle_density) / [(vol_frac × particle_density) + ((1 - vol_frac) × bulk_density)]
  # Solving for vol_frac:

  mass_frac <- mass_pct / 100

  vol_frac <- (mass_frac * bulk_density) /
              ((mass_frac * bulk_density) + ((1 - mass_frac) * particle_density))

  vol_pct <- vol_frac * 100

  return(vol_pct)
}

#' Assign coarse fragment class midpoints for visual estimates
#'
#' @param cf_class Coarse fragment class (e.g., "0-5%", "5-15%", "15-35%")
#' @return Midpoint value for the class
#' @references Canadian System of Soil Classification (CSSC)
assign_cf_class_midpoint <- function(cf_class) {

  # Standard CSSC coarse fragment classes
  class_midpoints <- c(
    "0" = 0,
    "0-5%" = 2.5,
    "5-15%" = 10,
    "15-35%" = 25,
    "35-60%" = 47.5,
    "60-90%" = 75,
    ">90%" = 95,
    "trace" = 2.5,
    "few" = 10,
    "common" = 25,
    "many" = 47.5,
    "abundant" = 75,
    "dominant" = 95
  )

  # Match class to midpoint
  midpoint <- class_midpoints[tolower(cf_class)]

  # If no match, try to parse numeric range
  if (is.na(midpoint)) {
    # Try to extract numbers (e.g., "10-20" → 15)
    numbers <- as.numeric(str_extract_all(cf_class, "\\d+")[[1]])
    if (length(numbers) == 2) {
      midpoint <- mean(numbers)
    } else if (length(numbers) == 1) {
      midpoint <- numbers
    } else {
      midpoint <- NA
    }
  }

  return(as.numeric(midpoint))
}

#' Calculate fine earth fraction (soil <2mm)
#'
#' @param coarse_frag_vol_pct Coarse fragment content by volume (%)
#' @return Fine earth fraction (0-1)
calculate_fine_earth_fraction <- function(coarse_frag_vol_pct) {
  fine_earth_frac <- 1 - (coarse_frag_vol_pct / 100)
  return(fine_earth_frac)
}

#' Apply coarse fragment correction to soil carbon stock
#'
#' @param stock_uncorrected Uncorrected carbon stock (kg/m²)
#' @param coarse_frag_vol_pct Coarse fragment content by volume (%)
#' @return Corrected carbon stock (kg/m²)
#' @details
#' Correction formula:
#'   Corrected Stock = Uncorrected Stock × (1 - CF_vol%)
#' Where CF_vol% is the volumetric coarse fragment content
apply_cf_correction_to_stock <- function(stock_uncorrected, coarse_frag_vol_pct) {

  fine_earth_frac <- calculate_fine_earth_fraction(coarse_frag_vol_pct)
  stock_corrected <- stock_uncorrected * fine_earth_frac

  return(stock_corrected)
}

#' Estimate coarse fragment content from soil texture and parent material
#'
#' @param parent_material Parent material type
#' @param soil_texture Soil texture class
#' @return Estimated coarse fragment content (%)
#' @details Default estimates when field measurements unavailable
estimate_cf_from_parent_material <- function(parent_material, soil_texture = NULL) {

  # Default CF% by parent material (Canadian Forest Soils)
  cf_defaults <- c(
    "glacial_till" = 25,
    "colluvium" = 40,
    "moraine" = 35,
    "outwash" = 20,
    "lacustrine" = 5,
    "marine" = 5,
    "organic" = 0,
    "eolian" = 2,
    "fluvial" = 15,
    "bedrock" = 50,
    "residuum" = 30,
    "unknown" = 15
  )

  # Match parent material
  cf_est <- cf_defaults[tolower(parent_material)]

  # If unknown, use texture-based estimate
  if (is.na(cf_est) && !is.null(soil_texture)) {
    texture_cf <- c(
      "sand" = 10,
      "loamy_sand" = 12,
      "sandy_loam" = 15,
      "loam" = 15,
      "silt_loam" = 10,
      "silt" = 5,
      "clay_loam" = 20,
      "silty_clay_loam" = 15,
      "sandy_clay_loam" = 20,
      "clay" = 20,
      "silty_clay" = 15,
      "sandy_clay" = 20
    )
    cf_est <- texture_cf[tolower(soil_texture)]
  }

  # Default to 15% if still unknown
  if (is.na(cf_est)) cf_est <- 15

  return(as.numeric(cf_est))
}

#' Process coarse fragment data in core samples
#'
#' @param core_data Data frame with core sample data
#' @param cf_column Name of coarse fragment column (default: "coarse_frag_pct")
#' @param cf_type Type of CF data: "volume", "mass", or "class"
#' @param apply_correction Apply correction to carbon stocks (TRUE/FALSE)
#' @return Data frame with CF corrections applied
process_coarse_fragments <- function(core_data,
                                    cf_column = "coarse_frag_pct",
                                    cf_type = "volume",
                                    apply_correction = TRUE) {

  cat("\n--- Processing Coarse Fragment Data ---\n")

  # Check if CF column exists
  if (!cf_column %in% names(core_data)) {
    cat(sprintf("⚠ Column '%s' not found. Adding default CF estimates.\n", cf_column))

    # Add default estimates based on stratum
    core_data <- core_data %>%
      mutate(
        coarse_frag_vol_pct = case_when(
          grepl("Boreal", stratum) ~ 20,  # Glacial till dominant
          grepl("Harvested", stratum) ~ 15,  # Disturbance exposes stones
          grepl("Afforestation", stratum) ~ 5,  # Former agricultural (stones removed)
          grepl("Coastal", stratum) ~ 10,  # Marine/fluvial deposits
          TRUE ~ 15  # Default
        ),
        cf_source = "estimated_default"
      )

  } else {

    # Process CF data based on type
    if (cf_type == "volume") {
      # Already in volume %, just rename
      core_data <- core_data %>%
        mutate(
          coarse_frag_vol_pct = .data[[cf_column]],
          cf_source = "measured_volume"
        )

    } else if (cf_type == "mass") {
      # Convert mass % to volume %
      cat("  Converting mass % to volume %...\n")
      core_data <- core_data %>%
        mutate(
          coarse_frag_vol_pct = mass_to_volume_cf(
            mass_pct = .data[[cf_column]],
            bulk_density = bulk_density_g_cm3
          ),
          cf_source = "measured_mass_converted"
        )

    } else if (cf_type == "class") {
      # Convert class to midpoint
      cat("  Converting CF classes to midpoint values...\n")
      core_data <- core_data %>%
        mutate(
          coarse_frag_vol_pct = map_dbl(.data[[cf_column]], assign_cf_class_midpoint),
          cf_source = "class_midpoint"
        )
    }
  }

  # Fill missing values with estimates
  n_missing <- sum(is.na(core_data$coarse_frag_vol_pct))
  if (n_missing > 0) {
    cat(sprintf("  Filling %d missing CF values with stratum defaults\n", n_missing))

    core_data <- core_data %>%
      mutate(
        coarse_frag_vol_pct = ifelse(
          is.na(coarse_frag_vol_pct),
          case_when(
            grepl("Boreal", stratum) ~ 20,
            grepl("Harvested", stratum) ~ 15,
            grepl("Afforestation", stratum) ~ 5,
            grepl("Coastal", stratum) ~ 10,
            TRUE ~ 15
          ),
          coarse_frag_vol_pct
        ),
        cf_source = ifelse(is.na(cf_source), "estimated_default", cf_source)
      )
  }

  # Calculate fine earth fraction
  core_data <- core_data %>%
    mutate(
      fine_earth_fraction = calculate_fine_earth_fraction(coarse_frag_vol_pct)
    )

  # Apply correction to carbon stocks if requested
  if (apply_correction) {
    cat("  Applying CF corrections to carbon stocks...\n")

    # Check if carbon_stock column exists
    if ("carbon_stock_kg_m2" %in% names(core_data)) {
      core_data <- core_data %>%
        mutate(
          carbon_stock_uncorrected_kg_m2 = carbon_stock_kg_m2,
          carbon_stock_kg_m2 = apply_cf_correction_to_stock(
            carbon_stock_kg_m2,
            coarse_frag_vol_pct
          ),
          cf_correction_applied = TRUE
        )

      # Calculate total correction
      total_reduction <- sum(core_data$carbon_stock_uncorrected_kg_m2 -
                            core_data$carbon_stock_kg_m2, na.rm = TRUE)
      pct_reduction <- (total_reduction / sum(core_data$carbon_stock_uncorrected_kg_m2, na.rm = TRUE)) * 100

      cat(sprintf("  ✓ Total carbon stock reduction: %.2f%% due to CF correction\n", pct_reduction))
    }
  }

  # Summary statistics
  cf_summary <- core_data %>%
    group_by(stratum) %>%
    summarise(
      n = n(),
      mean_cf_pct = mean(coarse_frag_vol_pct, na.rm = TRUE),
      min_cf_pct = min(coarse_frag_vol_pct, na.rm = TRUE),
      max_cf_pct = max(coarse_frag_vol_pct, na.rm = TRUE),
      n_measured = sum(grepl("measured", cf_source)),
      n_estimated = sum(grepl("estimated", cf_source))
    )

  cat("\n  CF Summary by Stratum:\n")
  print(cf_summary, n = Inf)

  return(core_data)
}

#' Create diagnostic plots for coarse fragment data
#'
#' @param core_data Data frame with CF-corrected data
#' @param output_dir Output directory for plots
create_cf_diagnostic_plots <- function(core_data, output_dir = "diagnostics/coarse_fragments") {

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  # Plot 1: CF distribution by stratum
  p1 <- ggplot(core_data, aes(x = stratum, y = coarse_frag_vol_pct, fill = stratum)) +
    geom_boxplot(alpha = 0.7) +
    geom_jitter(width = 0.2, alpha = 0.4) +
    scale_fill_manual(values = STRATUM_COLORS) +
    labs(
      title = "Coarse Fragment Content by Forest Type",
      x = "Forest Stratum",
      y = "Coarse Fragment Content (% volume)"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none"
    )

  ggsave(
    file.path(output_dir, "cf_distribution_by_stratum.png"),
    p1,
    width = 10,
    height = 6,
    dpi = 300
  )

  # Plot 2: CF correction impact
  if ("carbon_stock_uncorrected_kg_m2" %in% names(core_data)) {
    p2 <- ggplot(core_data, aes(x = carbon_stock_uncorrected_kg_m2,
                                 y = carbon_stock_kg_m2,
                                 color = coarse_frag_vol_pct)) +
      geom_point(alpha = 0.6, size = 3) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red") +
      scale_color_viridis_c(option = "plasma") +
      labs(
        title = "Impact of Coarse Fragment Correction on Carbon Stocks",
        x = "Uncorrected Carbon Stock (kg/m²)",
        y = "Corrected Carbon Stock (kg/m²)",
        color = "CF Content (%)"
      ) +
      theme_minimal()

    ggsave(
      file.path(output_dir, "cf_correction_impact.png"),
      p2,
      width = 10,
      height = 6,
      dpi = 300
    )
  }

  cat(sprintf("✓ Diagnostic plots saved to: %s\n", output_dir))
}

# ============================================================================
# WRAPPER FUNCTION FOR WORKFLOW INTEGRATION
# ============================================================================

#' Apply coarse fragment corrections to core data
#'
#' @param cores Processed core data
#' @param cf_type Type of CF measurement ("volume", "mass", or "class")
#' @param create_plots Generate diagnostic plots (TRUE/FALSE)
#' @return CF-corrected core data
apply_coarse_fragment_corrections <- function(cores,
                                             cf_type = "volume",
                                             create_plots = TRUE) {

  cat("\n=======================================================\n")
  cat("APPLYING COARSE FRAGMENT CORRECTIONS\n")
  cat("=======================================================\n")

  # Process CF data
  cores_corrected <- process_coarse_fragments(
    cores,
    cf_type = cf_type,
    apply_correction = TRUE
  )

  # Create diagnostic plots
  if (create_plots) {
    create_cf_diagnostic_plots(cores_corrected)
  }

  cat("\n=======================================================\n")
  cat("COARSE FRAGMENT CORRECTIONS COMPLETE\n")
  cat("=======================================================\n\n")

  return(cores_corrected)
}

# ============================================================================
# END OF MODULE
# ============================================================================

cat("✓ Module 01B: Coarse Fragment Corrections loaded\n\n")
