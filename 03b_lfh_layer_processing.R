# ============================================================================
# MODULE 03B: LFH LAYER PROCESSING FOR FOREST CARBON
# ============================================================================
# Purpose: Process organic forest floor (LFH layer) measurements
# Author: Adapted from blue carbon workflow for forest carbon accounting
# Last Updated: 2024
#
# DESCRIPTION:
# This module processes LFH (Litter-Fermentation-Humus) layer data for
# Canadian forest carbon accounting. The LFH layer is the organic forest
# floor above mineral soil and must be measured and reported separately.
#
# INPUT:
#   - lfh_samples.csv: LFH thickness, bulk density, and carbon content
#   - core_locations.csv: Spatial information for LFH sampling points
#
# OUTPUT:
#   - lfh_processed.rds: Processed LFH carbon stocks by location
#   - lfh_stocks_by_stratum.csv: Summary statistics by forest type
#   - lfh_diagnostics.csv: QC flags and data quality metrics
#
# REQUIREMENTS:
#   - Configuration file (blue_carbon_config.R) must be loaded
#   - LFH layer sampling using volume-based methods (known area × depth)
#   - Separate L, F, H layers OR composite LFH measurement
#
# USAGE:
#   source("blue_carbon_config.R")
#   source("03b_lfh_layer_processing.R")
# ============================================================================

# Load required libraries
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse,    # Data manipulation
  sf,           # Spatial data handling
  ggplot2,      # Plotting
  viridis,      # Color palettes
  here          # File path management
)

# Source configuration
if (!exists("PROJECT_NAME")) {
  source(here("blue_carbon_config.R"))
}

cat("=======================================================\n")
cat("MODULE 03B: LFH LAYER PROCESSING\n")
cat("=======================================================\n\n")

# ============================================================================
# FUNCTION DEFINITIONS
# ============================================================================

#' Calculate LFH layer carbon stock
#'
#' @param thickness_cm LFH layer thickness (cm)
#' @param bulk_density_g_cm3 LFH bulk density (g/cm³)
#' @param soc_g_kg LFH soil organic carbon content (g/kg)
#' @param area_cm2 Sampling area (cm²) - default 100 cm² (10×10 cm frame)
#' @return Carbon stock in kg/m²
calculate_lfh_stock <- function(thickness_cm, bulk_density_g_cm3, soc_g_kg, area_cm2 = 100) {

  # Volume = area × thickness
  volume_cm3 <- area_cm2 * thickness_cm

  # Mass = volume × bulk density
  mass_g <- volume_cm3 * bulk_density_g_cm3

  # Organic carbon mass = mass × SOC fraction
  oc_mass_g <- mass_g * (soc_g_kg / 1000)

  # Convert to kg/m²
  # area_cm2 → m² conversion: divide by 10000
  stock_kg_m2 <- (oc_mass_g / 1000) / (area_cm2 / 10000)

  return(stock_kg_m2)
}

#' Calculate composite LFH stock from separate layers
#'
#' @param l_thickness_cm Litter layer thickness
#' @param f_thickness_cm Fermentation layer thickness
#' @param h_thickness_cm Humus layer thickness
#' @param l_bd L layer bulk density (default from config)
#' @param f_bd F layer bulk density (default from config)
#' @param h_bd H layer bulk density (default from config)
#' @param l_soc L layer SOC (g/kg)
#' @param f_soc F layer SOC (g/kg)
#' @param h_soc H layer SOC (g/kg)
#' @param area_cm2 Sampling area
#' @return List with total stock and layer-specific stocks
calculate_lfh_composite <- function(l_thickness_cm, f_thickness_cm, h_thickness_cm,
                                   l_bd = NULL, f_bd = NULL, h_bd = NULL,
                                   l_soc, f_soc, h_soc, area_cm2 = 100) {

  # Use defaults if not provided
  if (is.null(l_bd)) l_bd <- LFH_BD_DEFAULTS$L_layer
  if (is.null(f_bd)) f_bd <- LFH_BD_DEFAULTS$F_layer
  if (is.null(h_bd)) h_bd <- LFH_BD_DEFAULTS$H_layer

  # Calculate stock for each layer
  l_stock <- calculate_lfh_stock(l_thickness_cm, l_bd, l_soc, area_cm2)
  f_stock <- calculate_lfh_stock(f_thickness_cm, f_bd, f_soc, area_cm2)
  h_stock <- calculate_lfh_stock(h_thickness_cm, h_bd, h_soc, area_cm2)

  # Total stock
  total_stock <- l_stock + f_stock + h_stock

  # Total thickness
  total_thickness <- l_thickness_cm + f_thickness_cm + h_thickness_cm

  return(list(
    total_stock_kg_m2 = total_stock,
    l_stock_kg_m2 = l_stock,
    f_stock_kg_m2 = f_stock,
    h_stock_kg_m2 = h_stock,
    total_thickness_cm = total_thickness
  ))
}

#' Apply coarse fragment correction to LFH carbon stock
#'
#' @param stock_kg_m2 Uncorrected carbon stock
#' @param coarse_frag_pct Coarse fragment content (% by volume)
#' @return Corrected carbon stock in kg/m²
apply_coarse_fragment_correction_lfh <- function(stock_kg_m2, coarse_frag_pct) {
  # LFH layers typically have minimal coarse fragments, but correction may be needed
  # in recently disturbed or rocky sites
  correction_factor <- 1 - (coarse_frag_pct / 100)
  corrected_stock <- stock_kg_m2 * correction_factor
  return(corrected_stock)
}

#' QC check for LFH measurements
#'
#' @param lfh_data Data frame with LFH measurements
#' @return Data frame with QC flags
qc_lfh_measurements <- function(lfh_data) {

  lfh_data <- lfh_data %>%
    mutate(
      # Thickness QC
      flag_thickness_low = thickness_cm < QC_LFH_THICKNESS_MIN,
      flag_thickness_high = thickness_cm > QC_LFH_THICKNESS_MAX,

      # Bulk density QC
      flag_bd_low = bulk_density_g_cm3 < QC_LFH_BD_MIN,
      flag_bd_high = bulk_density_g_cm3 > QC_LFH_BD_MAX,

      # SOC QC
      flag_soc_low = soc_g_kg < QC_LFH_SOC_MIN,
      flag_soc_high = soc_g_kg > QC_LFH_SOC_MAX,

      # Calculate number of QC flags
      n_qc_flags = flag_thickness_low + flag_thickness_high +
                   flag_bd_low + flag_bd_high +
                   flag_soc_low + flag_soc_high,

      # Overall QC status
      qc_status = case_when(
        n_qc_flags == 0 ~ "PASS",
        n_qc_flags <= 2 ~ "WARNING",
        TRUE ~ "FAIL"
      )
    )

  return(lfh_data)
}

#' Assign LFH bulk density defaults by stratum
#'
#' @param lfh_data Data frame with LFH measurements
#' @param stratum_column Name of stratum column
#' @return Data frame with BD defaults filled
assign_lfh_bd_defaults <- function(lfh_data, stratum_column = "stratum") {

  lfh_data <- lfh_data %>%
    mutate(
      bd_source = ifelse(is.na(bulk_density_g_cm3), "default", "measured"),
      bulk_density_g_cm3 = ifelse(
        is.na(bulk_density_g_cm3),
        LFH_BD_BY_STRATUM[[.data[[stratum_column]]]],
        bulk_density_g_cm3
      )
    )

  return(lfh_data)
}

#' Calculate LFH summary statistics by stratum
#'
#' @param lfh_data Processed LFH data
#' @return Summary table
summarize_lfh_by_stratum <- function(lfh_data) {

  summary <- lfh_data %>%
    group_by(stratum) %>%
    summarise(
      n_samples = n(),

      # Thickness statistics
      mean_thickness_cm = mean(thickness_cm, na.rm = TRUE),
      sd_thickness_cm = sd(thickness_cm, na.rm = TRUE),
      se_thickness_cm = sd_thickness_cm / sqrt(n_samples),

      # Bulk density statistics
      mean_bd_g_cm3 = mean(bulk_density_g_cm3, na.rm = TRUE),
      sd_bd_g_cm3 = sd(bulk_density_g_cm3, na.rm = TRUE),

      # SOC statistics
      mean_soc_g_kg = mean(soc_g_kg, na.rm = TRUE),
      sd_soc_g_kg = sd(soc_g_kg, na.rm = TRUE),

      # Carbon stock statistics
      mean_stock_kg_m2 = mean(carbon_stock_kg_m2, na.rm = TRUE),
      sd_stock_kg_m2 = sd(carbon_stock_kg_m2, na.rm = TRUE),
      se_stock_kg_m2 = sd_stock_kg_m2 / sqrt(n_samples),
      cv_pct = (sd_stock_kg_m2 / mean_stock_kg_m2) * 100,

      # 95% Confidence interval
      ci95_lower = mean_stock_kg_m2 - qt(0.975, df = n_samples - 1) * se_stock_kg_m2,
      ci95_upper = mean_stock_kg_m2 + qt(0.975, df = n_samples - 1) * se_stock_kg_m2,

      # Conservative estimate (95% CI lower bound)
      conservative_stock_kg_m2 = ci95_lower,

      # Convert to Mg/ha
      mean_stock_Mg_ha = mean_stock_kg_m2 * 10,
      conservative_stock_Mg_ha = conservative_stock_kg_m2 * 10,

      # QC summary
      n_qc_pass = sum(qc_status == "PASS"),
      n_qc_warning = sum(qc_status == "WARNING"),
      n_qc_fail = sum(qc_status == "FAIL"),
      pct_bd_default = sum(bd_source == "default") / n_samples * 100
    ) %>%
    ungroup()

  return(summary)
}

# ============================================================================
# MAIN PROCESSING WORKFLOW
# ============================================================================

process_lfh_layer <- function(lfh_file = "data_raw/lfh_samples.csv",
                              locations_file = "data_raw/core_locations.csv",
                              output_dir = "data_processed",
                              diagnostics_dir = "diagnostics/lfh_layer") {

  cat("\n--- Loading LFH Layer Data ---\n")

  # Check if LFH measurement is enabled
  if (!MEASURE_LFH_LAYER) {
    cat("⚠ LFH layer measurement is DISABLED in configuration\n")
    cat("  Set MEASURE_LFH_LAYER <- TRUE in blue_carbon_config.R to enable\n")
    return(invisible(NULL))
  }

  # Create output directories
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(diagnostics_dir, showWarnings = FALSE, recursive = TRUE)

  # Load LFH samples
  if (!file.exists(lfh_file)) {
    cat("⚠ LFH samples file not found:", lfh_file, "\n")
    cat("  Please create lfh_samples.csv with columns:\n")
    cat("    - sample_id, stratum, thickness_cm, bulk_density_g_cm3, soc_g_kg\n")
    cat("    - Optional: coarse_frag_pct, l_thickness_cm, f_thickness_cm, h_thickness_cm\n")
    return(invisible(NULL))
  }

  lfh_raw <- read_csv(lfh_file, show_col_types = FALSE)
  cat(sprintf("  ✓ Loaded %d LFH samples\n", nrow(lfh_raw)))

  # Load location data
  locations <- read_csv(locations_file, show_col_types = FALSE)

  # Join with location data
  lfh_data <- lfh_raw %>%
    left_join(
      locations %>% select(sample_id = core_id, longitude, latitude, stratum),
      by = "sample_id"
    )

  cat("\n--- Assigning Bulk Density Defaults ---\n")

  # Count missing BD values
  n_missing_bd <- sum(is.na(lfh_data$bulk_density_g_cm3))
  cat(sprintf("  Missing bulk density values: %d (%.1f%%)\n",
              n_missing_bd, n_missing_bd / nrow(lfh_data) * 100))

  # Assign defaults
  lfh_data <- assign_lfh_bd_defaults(lfh_data)

  cat("\n--- Calculating LFH Carbon Stocks ---\n")

  # Calculate carbon stocks
  lfh_data <- lfh_data %>%
    mutate(
      # Calculate stock (default area = 100 cm² = 10×10 cm sampling frame)
      area_cm2 = ifelse(!is.na(area_cm2), area_cm2, 100),
      carbon_stock_kg_m2 = calculate_lfh_stock(
        thickness_cm,
        bulk_density_g_cm3,
        soc_g_kg,
        area_cm2
      ),

      # Apply coarse fragment correction if available
      carbon_stock_kg_m2 = ifelse(
        !is.na(coarse_frag_pct),
        apply_coarse_fragment_correction_lfh(carbon_stock_kg_m2, coarse_frag_pct),
        carbon_stock_kg_m2
      ),

      # Convert to Mg/ha
      carbon_stock_Mg_ha = carbon_stock_kg_m2 * 10
    )

  cat(sprintf("  ✓ Calculated carbon stocks for %d samples\n", nrow(lfh_data)))

  cat("\n--- Quality Control ---\n")

  # Run QC checks
  lfh_data <- qc_lfh_measurements(lfh_data)

  # QC summary
  qc_summary <- lfh_data %>%
    count(qc_status) %>%
    mutate(pct = n / sum(n) * 100)

  cat("  QC Status Summary:\n")
  for (i in 1:nrow(qc_summary)) {
    cat(sprintf("    %s: %d (%.1f%%)\n",
                qc_summary$qc_status[i],
                qc_summary$n[i],
                qc_summary$pct[i]))
  }

  cat("\n--- Summary Statistics by Stratum ---\n")

  # Calculate stratum summaries
  stratum_summary <- summarize_lfh_by_stratum(lfh_data)

  # Print summary table
  print(stratum_summary %>%
          select(stratum, n_samples, mean_thickness_cm,
                 mean_stock_Mg_ha, conservative_stock_Mg_ha, cv_pct) %>%
          mutate(across(where(is.numeric), ~round(.x, 2))))

  cat("\n--- Saving Outputs ---\n")

  # Save processed data
  saveRDS(lfh_data, file.path(output_dir, "lfh_processed.rds"))
  write_csv(lfh_data, file.path(output_dir, "lfh_processed.csv"))
  cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "lfh_processed.rds")))

  # Save summary statistics
  write_csv(stratum_summary, file.path(output_dir, "lfh_stocks_by_stratum.csv"))
  cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "lfh_stocks_by_stratum.csv")))

  # Save QC diagnostics
  qc_diagnostics <- lfh_data %>%
    filter(qc_status != "PASS") %>%
    select(sample_id, stratum, thickness_cm, bulk_density_g_cm3, soc_g_kg,
           starts_with("flag_"), qc_status, n_qc_flags)

  write_csv(qc_diagnostics, file.path(diagnostics_dir, "lfh_qc_flags.csv"))
  cat(sprintf("  ✓ Saved: %s\n", file.path(diagnostics_dir, "lfh_qc_flags.csv")))

  # Create visualization
  cat("\n--- Creating Visualizations ---\n")

  # LFH stock by stratum
  p1 <- ggplot(lfh_data, aes(x = stratum, y = carbon_stock_Mg_ha, fill = stratum)) +
    geom_boxplot(alpha = 0.7) +
    geom_jitter(width = 0.2, alpha = 0.5) +
    scale_fill_manual(values = STRATUM_COLORS) +
    labs(
      title = "LFH Layer Carbon Stock by Forest Type",
      x = "Forest Stratum",
      y = "Carbon Stock (Mg C/ha)"
    ) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none"
    )

  ggsave(
    file.path(diagnostics_dir, "lfh_stock_by_stratum.png"),
    p1,
    width = 10,
    height = 6,
    dpi = 300
  )

  # Thickness vs carbon stock
  p2 <- ggplot(lfh_data, aes(x = thickness_cm, y = carbon_stock_Mg_ha, color = stratum)) +
    geom_point(alpha = 0.6, size = 3) +
    geom_smooth(method = "lm", se = TRUE, alpha = 0.2) +
    scale_color_manual(values = STRATUM_COLORS) +
    labs(
      title = "LFH Thickness vs Carbon Stock",
      x = "LFH Thickness (cm)",
      y = "Carbon Stock (Mg C/ha)",
      color = "Forest Type"
    ) +
    theme_minimal()

  ggsave(
    file.path(diagnostics_dir, "lfh_thickness_vs_stock.png"),
    p2,
    width = 10,
    height = 6,
    dpi = 300
  )

  cat(sprintf("  ✓ Saved: %s\n", file.path(diagnostics_dir, "lfh_stock_by_stratum.png")))
  cat(sprintf("  ✓ Saved: %s\n", file.path(diagnostics_dir, "lfh_thickness_vs_stock.png")))

  cat("\n=======================================================\n")
  cat("MODULE 03B: LFH LAYER PROCESSING COMPLETE\n")
  cat("=======================================================\n\n")

  # Return summary for further use
  return(list(
    data = lfh_data,
    summary = stratum_summary,
    qc_diagnostics = qc_diagnostics
  ))
}

# ============================================================================
# EXECUTE IF RUN AS SCRIPT
# ============================================================================

if (!interactive()) {
  result <- process_lfh_layer()
}
