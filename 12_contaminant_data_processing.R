# ============================================================================
# MODULE 12: CONTAMINANT DATA PROCESSING AND INTERPRETATION
# ============================================================================
# PURPOSE: Process laboratory contaminant results, compare to CCME standards,
#          and generate food safety assessments for Indigenous agriculture
#
# INPUTS:
#   - blue_carbon_config.R (configuration)
#   - data_raw/contaminant_lab_results.csv (laboratory data)
#   - ccme_soil_quality_guidelines.csv (CCME standards)
#   - diagnostics/contaminant_assessment/risk_assessment_summary.csv (Module 11)
#
# OUTPUTS:
#   Results Processing (data_processed/contaminant/):
#     - contaminant_results_clean.csv (cleaned lab data)
#     - ccme_comparison.csv (results vs. guidelines)
#     - exceedances_summary.csv (flagged contaminants)
#
#   Assessment Reports (outputs/reports/contaminant/):
#     - food_safety_assessment.html (plain-language report)
#     - food_safety_summary.csv (site-level pass/fail)
#     - crop_recommendations.csv (suitable crops by site)
#     - remediation_priorities.csv (action plan)
#
#   Maps (outputs/maps/contaminant_results/):
#     - contaminant_spatial_map.png (exceedances mapped)
#     - depth_profile_plots.png (contamination vs. depth)
#
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (file.exists("blue_carbon_config.R")) {
  source("blue_carbon_config.R")
} else {
  stop("Configuration file not found.")
}

# Create required output directories
required_dirs <- c(
  "logs",
  "data_processed/contaminant",
  "outputs/reports/contaminant",
  "outputs/maps/contaminant_results"
)

for (dir in required_dirs) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
}

# Initialize logging
log_file <- file.path("logs", paste0("contaminant_processing_", Sys.Date(), ".log"))

log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  log_entry <- sprintf("[%s] %s: %s", timestamp, level, msg)
  cat(log_entry, "\n")
  cat(log_entry, "\n", file = log_file, append = TRUE)
}

log_message("=== MODULE 12: CONTAMINANT DATA PROCESSING ===")

# Load packages
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(purrr)
  library(stringr)
})

log_message("Packages loaded successfully")

# ============================================================================
# LOAD REFERENCE DATA
# ============================================================================

log_message("Loading CCME standards...")
ccme_standards <- read_csv("ccme_soil_quality_guidelines.csv", show_col_types = FALSE)

log_message(sprintf("Loaded guidelines for %d contaminants", nrow(ccme_standards)))

# ============================================================================
# LOAD LAB RESULTS
# ============================================================================

log_message("Loading laboratory results...")

# Check if lab results exist
if (!file.exists("data_raw/contaminant_lab_results.csv")) {

  log_message("contaminant_lab_results.csv not found. Creating template...", "WARNING")

  # Create template
  template <- data.frame(
    sample_id = c("SITE_001_0-15cm", "SITE_001_15-30cm", "SITE_002_0-15cm"),
    site_id = c("SITE_001", "SITE_001", "SITE_002"),
    stratum = c("Upper Marsh", "Upper Marsh", "Mid Marsh"),
    depth_top_cm = c(0, 15, 0),
    depth_bottom_cm = c(15, 30, 15),
    contaminant = c("Arsenic", "Arsenic", "Arsenic"),
    concentration_mg_kg = c(8.5, 5.2, 3.1),
    units = c("mg/kg", "mg/kg", "mg/kg"),
    detection_limit_mg_kg = c(0.5, 0.5, 0.5),
    lab_qualifier = c("", "", ""),
    analysis_date = c("2024-11-01", "2024-11-01", "2024-11-01"),
    laboratory = c("ALS Environmental", "ALS Environmental", "ALS Environmental"),
    method = c("EPA 3050B + ICP-MS", "EPA 3050B + ICP-MS", "EPA 3050B + ICP-MS")
  )

  write_csv(template, "data_raw/contaminant_lab_results.csv")

  log_message("Template created at data_raw/contaminant_lab_results.csv")

  cat("\n")
  cat("======================================================================\n")
  cat("ACTION REQUIRED: Add laboratory results\n")
  cat("======================================================================\n")
  cat("\n")
  cat("A template has been created at data_raw/contaminant_lab_results.csv\n")
  cat("\n")
  cat("Please populate with actual laboratory data in this format:\n")
  cat("  - One row per contaminant per sample\n")
  cat("  - Use contaminant names matching CCME standards (see ccme_soil_quality_guidelines.csv)\n")
  cat("  - Include depth intervals matching carbon sampling\n")
  cat("  - Report detection limits and lab qualifiers\n")
  cat("\n")
  cat("Then re-run this script to process results.\n")
  cat("======================================================================\n")

  stop("Laboratory results required. Template created.")
}

# Load lab data
lab_results <- read_csv("data_raw/contaminant_lab_results.csv", show_col_types = FALSE)

log_message(sprintf("Loaded %d contaminant measurements from %d samples",
                    nrow(lab_results),
                    length(unique(lab_results$sample_id))))

# ============================================================================
# DATA VALIDATION AND QA/QC
# ============================================================================

log_message("Performing data validation...")

# Check for required columns
required_cols <- c("sample_id", "site_id", "contaminant", "concentration_mg_kg",
                   "depth_top_cm", "depth_bottom_cm")

missing_cols <- setdiff(required_cols, names(lab_results))

if (length(missing_cols) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")))
}

# Flag non-detects
lab_results <- lab_results %>%
  mutate(
    is_non_detect = grepl("<|ND|U", lab_qualifier, ignore.case = TRUE),
    concentration_clean = if_else(is_non_detect, detection_limit_mg_kg / 2, concentration_mg_kg),
    qc_flag = case_when(
      is.na(concentration_mg_kg) ~ "MISSING_VALUE",
      is_non_detect ~ "NON_DETECT",
      TRUE ~ "DETECTED"
    )
  )

# Count non-detects
non_detect_count <- sum(lab_results$is_non_detect, na.rm = TRUE)
log_message(sprintf("  Non-detects: %d of %d (%.1f%%)",
                    non_detect_count,
                    nrow(lab_results),
                    100 * non_detect_count / nrow(lab_results)))

# Save cleaned data
write_csv(lab_results, "data_processed/contaminant/contaminant_results_clean.csv")

# ============================================================================
# COMPARE TO CCME GUIDELINES
# ============================================================================

log_message("Comparing results to CCME Agricultural Guidelines...")

# Join with CCME standards
results_with_standards <- lab_results %>%
  left_join(
    ccme_standards %>% select(contaminant, ccme_agricultural_mg_kg,
                              ccme_residential_mg_kg, health_concern, uptake_category),
    by = "contaminant"
  ) %>%
  mutate(
    # Calculate exceedance ratios
    exceedance_ratio_ag = concentration_clean / ccme_agricultural_mg_kg,
    exceedance_ratio_res = concentration_clean / ccme_residential_mg_kg,

    # Flag exceedances
    exceeds_agricultural = concentration_clean > ccme_agricultural_mg_kg,
    exceeds_residential = concentration_clean > ccme_residential_mg_kg,

    # Exceedance severity
    exceedance_category = case_when(
      is.na(ccme_agricultural_mg_kg) ~ "NO_GUIDELINE",
      exceedance_ratio_ag > 2 ~ "MAJOR_EXCEEDANCE",
      exceedance_ratio_ag > 1 ~ "EXCEEDANCE",
      exceedance_ratio_ag > 0.5 ~ "APPROACHING",
      TRUE ~ "COMPLIANT"
    ),

    # Food safety flag
    food_safety_flag = case_when(
      exceedance_category == "MAJOR_EXCEEDANCE" ~ "UNSAFE",
      exceedance_category == "EXCEEDANCE" ~ "CAUTION",
      exceedance_category == "APPROACHING" ~ "MONITOR",
      exceedance_category == "COMPLIANT" ~ "SAFE",
      TRUE ~ "UNKNOWN"
    )
  )

# Count exceedances
exceedance_summary <- results_with_standards %>%
  group_by(exceedance_category) %>%
  summarise(
    n_measurements = n(),
    n_contaminants = n_distinct(contaminant),
    n_sites = n_distinct(site_id),
    .groups = "drop"
  )

log_message("Exceedance summary:")
for (i in 1:nrow(exceedance_summary)) {
  log_message(sprintf("  %s: %d measurements across %d sites",
                      exceedance_summary$exceedance_category[i],
                      exceedance_summary$n_measurements[i],
                      exceedance_summary$n_sites[i]))
}

# Save comparison
write_csv(results_with_standards, "data_processed/contaminant/ccme_comparison.csv")

# ============================================================================
# IDENTIFY EXCEEDANCES
# ============================================================================

log_message("Identifying priority exceedances...")

exceedances <- results_with_standards %>%
  filter(exceedance_category %in% c("EXCEEDANCE", "MAJOR_EXCEEDANCE")) %>%
  arrange(desc(exceedance_ratio_ag)) %>%
  select(sample_id, site_id, stratum, depth_top_cm, depth_bottom_cm,
         contaminant, concentration_clean, ccme_agricultural_mg_kg,
         exceedance_ratio_ag, exceedance_category, food_safety_flag,
         health_concern, uptake_category)

if (nrow(exceedances) > 0) {
  log_message(sprintf("ALERT: %d exceedances detected across %d sites",
                      nrow(exceedances),
                      length(unique(exceedances$site_id))),
              "WARNING")

  write_csv(exceedances, "data_processed/contaminant/exceedances_summary.csv")

} else {
  log_message("No CCME exceedances detected. All samples COMPLIANT.", "INFO")
}

# ============================================================================
# SITE-LEVEL FOOD SAFETY ASSESSMENT
# ============================================================================

log_message("Generating site-level food safety assessment...")

site_safety <- results_with_standards %>%
  group_by(site_id, stratum) %>%
  summarise(
    n_contaminants_tested = n_distinct(contaminant),
    n_exceedances = sum(exceeds_agricultural, na.rm = TRUE),
    n_major_exceedances = sum(exceedance_category == "MAJOR_EXCEEDANCE", na.rm = TRUE),
    max_exceedance_ratio = max(exceedance_ratio_ag, na.rm = TRUE),
    contaminants_exceeded = paste(unique(contaminant[exceeds_agricultural]), collapse = "; "),

    # Overall site safety rating
    site_safety_rating = case_when(
      n_major_exceedances > 0 ~ "UNSAFE",
      n_exceedances > 2 ~ "CAUTION",
      n_exceedances > 0 ~ "RESTRICTED",
      max_exceedance_ratio > 0.5 ~ "MONITOR",
      TRUE ~ "SAFE"
    ),

    # Food production recommendation
    food_production_recommendation = case_when(
      site_safety_rating == "UNSAFE" ~ "DO NOT PLANT FOOD CROPS - Remediation required",
      site_safety_rating == "CAUTION" ~ "Avoid high-uptake crops; use amended soil/raised beds",
      site_safety_rating == "RESTRICTED" ~ "Restrict to low-uptake crops; avoid leafy greens",
      site_safety_rating == "MONITOR" ~ "Proceed with caution; monitor crop uptake",
      TRUE ~ "Suitable for all crops"
    ),

    .groups = "drop"
  )

write_csv(site_safety, "outputs/reports/contaminant/food_safety_summary.csv")

log_message(sprintf("Site safety assessment complete for %d sites", nrow(site_safety)))

# ============================================================================
# CROP RECOMMENDATIONS BY SITE
# ============================================================================

log_message("Generating crop recommendations...")

# Crop uptake database (simplified)
crop_sensitivity <- data.frame(
  contaminant = c("Arsenic", "Cadmium", "Lead", "Mercury", "Copper", "Zinc"),
  high_uptake_crops = c(
    "Rice; Leafy greens (lettuce, spinach, chard)",
    "Leafy greens; Root vegetables (carrots, potatoes)",
    "Leafy greens; Root vegetables",
    "Leafy greens",
    "Leafy greens",
    "Leafy greens; Grains"
  ),
  low_uptake_crops = c(
    "Berries; Tree fruits; Grains",
    "Tree fruits; Berries; Grains",
    "Tree fruits; Berries (fruit flesh)",
    "Tree fruits; Grains",
    "Tree fruits; Berries",
    "Tree fruits"
  )
)

# Generate crop recommendations
crop_recommendations <- site_safety %>%
  left_join(
    results_with_standards %>%
      filter(exceeds_agricultural) %>%
      select(site_id, contaminant, uptake_category) %>%
      distinct(),
    by = "site_id",
    relationship = "many-to-many"
  ) %>%
  left_join(crop_sensitivity, by = "contaminant") %>%
  group_by(site_id, stratum, site_safety_rating) %>%
  summarise(
    avoid_crops = paste(unique(high_uptake_crops), collapse = " | "),
    suitable_crops = paste(unique(low_uptake_crops), collapse = " | "),
    .groups = "drop"
  )

write_csv(crop_recommendations, "outputs/reports/contaminant/crop_recommendations.csv")

# ============================================================================
# REMEDIATION PRIORITIES
# ============================================================================

log_message("Developing remediation priorities...")

remediation_plan <- exceedances %>%
  group_by(site_id, stratum) %>%
  summarise(
    n_exceedances = n(),
    contaminants = paste(unique(contaminant), collapse = "; "),
    max_depth_cm = max(depth_bottom_cm),
    max_exceedance_ratio = max(exceedance_ratio_ag),

    # Priority scoring
    priority_score = n_exceedances * max_exceedance_ratio,

    priority_level = case_when(
      priority_score > 10 ~ "URGENT",
      priority_score > 5 ~ "HIGH",
      priority_score > 2 ~ "MEDIUM",
      TRUE ~ "LOW"
    ),

    # Remediation strategy
    recommended_action = case_when(
      max_depth_cm <= 15 ~ "Remove surface soil (0-20 cm); Replace with clean topsoil",
      max_depth_cm <= 30 ~ "Consider raised beds (60+ cm) with clean soil",
      TRUE ~ "Consult environmental professional - Deep contamination"
    ),

    .groups = "drop"
  ) %>%
  arrange(desc(priority_score))

if (nrow(remediation_plan) > 0) {
  write_csv(remediation_plan, "outputs/reports/contaminant/remediation_priorities.csv")
  log_message(sprintf("Remediation priorities identified for %d sites", nrow(remediation_plan)))
}

# ============================================================================
# VISUALIZATIONS
# ============================================================================

log_message("Creating visualizations...")

# 1. Exceedance summary by contaminant
p_exceedances <- results_with_standards %>%
  filter(exceeds_agricultural) %>%
  ggplot(aes(x = reorder(contaminant, exceedance_ratio_ag), y = exceedance_ratio_ag, fill = exceedance_category)) +
  geom_col() +
  geom_hline(yintercept = 1, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 2, linetype = "dashed", color = "darkred") +
  scale_fill_manual(values = c("EXCEEDANCE" = "#f57c00", "MAJOR_EXCEEDANCE" = "#d32f2f")) +
  coord_flip() +
  labs(
    title = "Contaminant Exceedances of CCME Agricultural Guidelines",
    subtitle = "Ratio > 1.0 exceeds guideline; Ratio > 2.0 is major exceedance",
    x = "Contaminant",
    y = "Exceedance Ratio (Concentration / CCME Guideline)",
    fill = "Severity"
  ) +
  theme_minimal()

ggsave("outputs/maps/contaminant_results/exceedance_summary.png",
       p_exceedances, width = 10, height = 6, dpi = 300)

# 2. Depth profiles
if (nrow(exceedances) > 0) {
  p_depth <- results_with_standards %>%
    filter(site_id %in% unique(exceedances$site_id)) %>%
    mutate(depth_midpoint = (depth_top_cm + depth_bottom_cm) / 2) %>%
    ggplot(aes(x = concentration_clean, y = depth_midpoint, color = contaminant)) +
    geom_point(size = 3, alpha = 0.7) +
    geom_line(aes(group = contaminant), alpha = 0.5) +
    geom_vline(aes(xintercept = ccme_agricultural_mg_kg), linetype = "dashed", alpha = 0.5) +
    scale_y_reverse() +
    facet_wrap(~site_id) +
    labs(
      title = "Contaminant Depth Profiles - Sites with Exceedances",
      subtitle = "Dashed lines show CCME Agricultural Guidelines",
      x = "Concentration (mg/kg)",
      y = "Depth (cm)",
      color = "Contaminant"
    ) +
    theme_minimal()

  ggsave("outputs/maps/contaminant_results/depth_profiles_exceedances.png",
         p_depth, width = 12, height = 8, dpi = 300)
}

# 3. Site safety map
p_safety <- site_safety %>%
  ggplot(aes(x = stratum, y = n_contaminants_tested, fill = site_safety_rating)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c(
    "UNSAFE" = "#d32f2f",
    "CAUTION" = "#f57c00",
    "RESTRICTED" = "#fbc02d",
    "MONITOR" = "#aed581",
    "SAFE" = "#66bb6a"
  )) +
  labs(
    title = "Site Food Safety Assessment by Stratum",
    x = "Stratum",
    y = "Number of Contaminants Tested",
    fill = "Safety Rating"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("outputs/maps/contaminant_results/site_safety_summary.png",
       p_safety, width = 10, height = 6, dpi = 300)

log_message("Visualizations saved to outputs/maps/contaminant_results/")

# ============================================================================
# PLAIN-LANGUAGE SUMMARY REPORT
# ============================================================================

cat("\n")
cat("======================================================================\n")
cat("SOIL CONTAMINANT FOOD SAFETY ASSESSMENT\n")
cat("======================================================================\n")
cat("\n")
cat(sprintf("Project: %s\n", PROJECT_NAME))
cat(sprintf("Report Date: %s\n", Sys.Date()))
cat("\n")

cat("OVERALL SUMMARY:\n")
cat("----------------\n")
cat(sprintf("  Sites tested: %d\n", length(unique(lab_results$site_id))))
cat(sprintf("  Samples analyzed: %d\n", length(unique(lab_results$sample_id))))
cat(sprintf("  Contaminants analyzed: %d\n", length(unique(lab_results$contaminant))))
cat(sprintf("  CCME exceedances: %d\n", nrow(exceedances)))
cat("\n")

cat("SITE SAFETY RATINGS:\n")
cat("--------------------\n")
safety_counts <- site_safety %>%
  count(site_safety_rating) %>%
  arrange(desc(n))

for (i in 1:nrow(safety_counts)) {
  cat(sprintf("  %s: %d sites\n", safety_counts$site_safety_rating[i], safety_counts$n[i]))
}
cat("\n")

if (nrow(exceedances) > 0) {
  cat("CONTAMINANTS OF CONCERN:\n")
  cat("------------------------\n")

  contaminant_summary <- exceedances %>%
    group_by(contaminant) %>%
    summarise(
      n_sites = n_distinct(site_id),
      max_concentration = max(concentration_clean),
      max_ratio = max(exceedance_ratio_ag),
      .groups = "drop"
    ) %>%
    arrange(desc(max_ratio))

  for (i in 1:nrow(contaminant_summary)) {
    cat(sprintf("  • %s: Detected at %d sites (max %.1fx guideline)\n",
                contaminant_summary$contaminant[i],
                contaminant_summary$n_sites[i],
                contaminant_summary$max_ratio[i]))
  }
  cat("\n")

  cat("PRIORITY ACTIONS:\n")
  cat("-----------------\n")

  if (nrow(remediation_plan) > 0) {
    urgent <- remediation_plan %>% filter(priority_level == "URGENT")
    if (nrow(urgent) > 0) {
      cat(sprintf("  URGENT (%d sites):\n", nrow(urgent)))
      for (i in 1:min(3, nrow(urgent))) {
        cat(sprintf("    • %s (%s): %s\n",
                    urgent$site_id[i],
                    urgent$contaminants[i],
                    urgent$recommended_action[i]))
      }
    }

    high <- remediation_plan %>% filter(priority_level == "HIGH")
    if (nrow(high) > 0) {
      cat(sprintf("  HIGH PRIORITY (%d sites):\n", nrow(high)))
      cat("    • Restrict high-uptake crops\n")
      cat("    • Consider raised beds with clean soil\n")
    }
  }

} else {
  cat("GOOD NEWS:\n")
  cat("----------\n")
  cat("  ✓ No CCME exceedances detected\n")
  cat("  ✓ All tested sites are suitable for food production\n")
  cat("  ✓ Proceed with restoration as planned\n")
}

cat("\n")
cat("CULTURAL FOOD SAFETY CONSIDERATIONS:\n")
cat("------------------------------------\n")
cat("  • Share results with community in plain language\n")
cat("  • Engage Elders in decision-making about acceptable use\n")
cat("  • Prioritize culturally important species in clean areas\n")
cat("  • Consider traditional preparation methods that reduce exposure\n")
cat("\n")

cat("DETAILED REPORTS:\n")
cat("-----------------\n")
cat("  • CCME comparison: data_processed/contaminant/ccme_comparison.csv\n")
cat("  • Site safety summary: outputs/reports/contaminant/food_safety_summary.csv\n")
cat("  • Crop recommendations: outputs/reports/contaminant/crop_recommendations.csv\n")
if (nrow(exceedances) > 0) {
  cat("  • Remediation priorities: outputs/reports/contaminant/remediation_priorities.csv\n")
}
cat("  • Maps: outputs/maps/contaminant_results/\n")
cat("\n")

cat("For complete guidance, see: CONTAMINANT_TESTING_GUIDE.md\n")
cat("======================================================================\n")

log_message("=== MODULE 12 COMPLETE ===")
log_message(sprintf("Total runtime: %.1f seconds", as.numeric(Sys.time() - SESSION_START, units = "secs")))
