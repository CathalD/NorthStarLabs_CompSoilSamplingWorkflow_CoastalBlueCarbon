# ============================================================================
# ICVCM CORE CARBON PRINCIPLES (CCP) COMPLIANCE MODULE
# ============================================================================
# PURPOSE: Assess carbon project compliance with ICVCM Core Carbon Principles
#
# CONTEXT:
# The Integrity Council for the Voluntary Carbon Market (ICVCM) established
# the Core Carbon Principles (CCPs) as a global quality benchmark for carbon
# credits in the voluntary carbon market. CCP-approved credits represent
# high-integrity carbon reduction/removal projects.
#
# INPUTS:
#   - Project documentation
#   - MMRV outputs from workflow
#   - Standards compliance reports
#
# OUTPUTS:
#   - outputs/reports/icvcm_ccp_assessment.html
#   - outputs/reports/icvcm_ccp_scorecard.csv
#   - outputs/reports/icvcm_gap_analysis.csv
#   - outputs/reports/icvcm_action_plan.csv
#
# REFERENCE: https://icvcm.org/the-core-carbon-principles/
# ============================================================================

# ============================================================================
# SETUP
# ============================================================================

# Load configuration
if (file.exists("config.R")) {
  source("config.R")
} else {
  stop("Configuration file not found.")
}

# Load utilities
if (file.exists("utils/mmrv_utils.R")) {
  source("utils/mmrv_utils.R")
}

# Create logger
log_message <- create_logger(file.path(DIR_LOGS, paste0("icvcm_ccp_", Sys.Date(), ".log")))
log_message("=== ICVCM CORE CARBON PRINCIPLES ASSESSMENT ===")

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(knitr)
})

# Create output directory
ensure_dir(DIR_OUTPUT_REPORTS)

# ============================================================================
# ICVCM CORE CARBON PRINCIPLES DEFINITIONS
# ============================================================================

# The 10 Core Carbon Principles
CCP_PRINCIPLES <- list(
  CCP1 = list(
    number = 1,
    name = "Effective Governance",
    description = "The Carbon-Crediting Program has effective program governance",
    category = "Program-level",
    assessment_level = "program",
    criteria = c(
      "Clear governance structure and decision-making processes",
      "Conflict of interest policies",
      "Stakeholder consultation mechanisms",
      "Grievance and dispute resolution procedures",
      "Transparency in governance"
    )
  ),

  CCP2 = list(
    number = 2,
    name = "Tracking",
    description = "Emission reductions and removals are tracked toward mitigation goals",
    category = "Program-level",
    assessment_level = "program",
    criteria = c(
      "Unique serial numbers for all carbon credits",
      "Registry system prevents double counting",
      "Credits tracked from issuance to retirement",
      "Integration with national/international tracking systems",
      "Transparent cancellation and retirement records"
    )
  ),

  CCP3 = list(
    number = 3,
    name = "Transparency",
    description = "All relevant information is disclosed to allow scrutiny of mitigation activities",
    category = "Program-level",
    assessment_level = "program",
    criteria = c(
      "Publicly available project documentation",
      "Methodology documents accessible",
      "Verification reports published",
      "Monitoring data disclosed",
      "Clear credit issuance records"
    )
  ),

  CCP4 = list(
    number = 4,
    name = "Robust Third-Party Validation and Verification",
    description = "Independent third-party validation and verification",
    category = "Program-level",
    assessment_level = "program",
    criteria = c(
      "Accredited validation/verification bodies (VVBs)",
      "Independence requirements for VVBs",
      "Competency requirements for auditors",
      "Quality assurance processes",
      "Regular re-verification requirements"
    )
  ),

  CCP5 = list(
    number = 5,
    name = "Additionality",
    description = "The mitigation activity goes beyond business-as-usual",
    category = "Carbon-credit integrity",
    assessment_level = "project",
    criteria = c(
      "Project activity would not occur without carbon finance",
      "Documented baseline scenario",
      "Barrier analysis (financial, technological, institutional)",
      "Common practice analysis",
      "Conservative baseline assumptions"
    )
  ),

  CCP6 = list(
    number = 6,
    name = "Permanence",
    description = "Permanent emission reductions or removals",
    category = "Carbon-credit integrity",
    assessment_level = "project",
    criteria = c(
      "Risk assessment for reversal (e.g., fire, disease, land-use change)",
      "Monitoring for reversals",
      "Buffer pool or insurance mechanism",
      "Long-term commitment to project (crediting period)",
      "Legal agreements ensure permanence"
    )
  ),

  CCP7 = list(
    number = 7,
    name = "Robust Quantification",
    description = "Robust quantification of emission reductions and removals",
    category = "Carbon-credit integrity",
    assessment_level = "project",
    criteria = c(
      "Conservative assumptions and approaches",
      "Uncertainty quantification and accounting",
      "Scientifically robust methodologies",
      "Appropriate baseline and project scenarios",
      "Leakage assessment and deductions"
    )
  ),

  CCP8 = list(
    number = 8,
    name = "No Net Harm",
    description = "The mitigation activity does not violate local and national laws",
    category = "Sustainable development",
    assessment_level = "project",
    criteria = c(
      "Environmental impact assessment conducted",
      "No negative impacts on biodiversity",
      "Free, prior, and informed consent (FPIC) obtained",
      "No human rights violations",
      "Compliance with local/national laws"
    )
  ),

  CCP9 = list(
    number = 9,
    name = "Sustainable Development Benefits",
    description = "The mitigation activity delivers net positive impacts",
    category = "Sustainable development",
    assessment_level = "project",
    criteria = c(
      "Positive contributions to UN SDGs",
      "Co-benefits for local communities",
      "Biodiversity conservation",
      "Gender equality considerations",
      "Monitoring and reporting of SD benefits"
    )
  ),

  CCP10 = list(
    number = 10,
    name = "Contribution Toward Net-Zero",
    description = "The nature of the mitigation activity is consistent with net-zero pathways",
    category = "Net-zero alignment",
    assessment_level = "project",
    criteria = c(
      "Activity type consistent with long-term net-zero goals",
      "Avoids lock-in of high-carbon systems",
      "Supports transition to low-carbon economy",
      "Aligned with Paris Agreement goals",
      "Clear labeling of removal vs. reduction credits"
    )
  )
)

# ============================================================================
# ASSESSMENT FUNCTIONS
# ============================================================================

#' Assess CCP1: Effective Governance
#'
#' @return Assessment result data frame
assess_ccp1_governance <- function() {
  log_message("Assessing CCP1: Effective Governance")

  # This is program-level - typically assessed at registry/methodology level
  # For project-level: Check if using CCP-approved program

  # Check if methodology is from approved program
  approved_programs <- c("Verra", "Gold Standard", "CAR", "ACR")

  # Get methodology from config
  methodology_used <- get_param("ECOSYSTEM_STANDARDS", default = c())

  uses_approved_program <- any(sapply(approved_programs, function(prog) {
    any(grepl(prog, methodology_used, ignore.case = TRUE))
  }))

  assessment <- data.frame(
    principle = "CCP1",
    name = "Effective Governance",
    level = "Program-level",
    status = ifelse(uses_approved_program, "PASS", "REVIEW"),
    score = ifelse(uses_approved_program, 1.0, 0.5),
    evidence = ifelse(uses_approved_program,
                     paste("Using approved program:", paste(methodology_used, collapse = ", ")),
                     "Methodology program not identified as CCP-approved"),
    recommendation = ifelse(uses_approved_program,
                           "Continue using CCP-approved program",
                           "Consider using CCP-approved carbon program (Verra, Gold Standard, etc.)")
  )

  return(assessment)
}

#' Assess CCP2: Tracking
assess_ccp2_tracking <- function() {
  log_message("Assessing CCP2: Tracking")

  # Program-level assessment
  # For project: Check if outputs include tracking-ready data

  # Check if project has unique identifiers
  has_project_id <- !is.null(get_param("PROJECT_NAME"))
  has_session_tracking <- !is.null(get_param("SESSION_ID"))

  # Check if outputs structured for registry upload
  carbon_stock_files <- list.files(DIR_OUTPUT_CARBON_STOCKS, pattern = "*.csv", full.names = TRUE)
  has_carbon_outputs <- length(carbon_stock_files) > 0

  score <- sum(c(has_project_id, has_session_tracking, has_carbon_outputs)) / 3

  assessment <- data.frame(
    principle = "CCP2",
    name = "Tracking",
    level = "Program-level",
    status = ifelse(score >= 0.8, "PASS", "REVIEW"),
    score = score,
    evidence = sprintf("Project ID: %s, Session tracking: %s, Carbon outputs: %s",
                      has_project_id, has_session_tracking, has_carbon_outputs),
    recommendation = "Ensure project registered with CCP-approved registry for credit tracking"
  )

  return(assessment)
}

#' Assess CCP3: Transparency
assess_ccp3_transparency <- function() {
  log_message("Assessing CCP3: Transparency")

  # Check if workflow outputs include transparency documentation

  # Check for key documentation outputs
  has_mmrv_report <- file.exists(file.path(DIR_OUTPUT_MMRV, "vm0033_verification_package.html"))
  has_standards_report <- file.exists(file.path(DIR_OUTPUT_REPORTS, "comprehensive_standards_report.html"))
  has_diagnostics <- dir.exists(DIR_DIAGNOSTICS) && length(list.files(DIR_DIAGNOSTICS, recursive = TRUE)) > 0
  has_logs <- dir.exists(DIR_LOGS) && length(list.files(DIR_LOGS)) > 0

  # Check for spatial data exports
  has_spatial_outputs <- dir.exists(file.path(DIR_OUTPUT_PREDICTIONS))

  transparency_checks <- c(
    "MMRV verification package" = has_mmrv_report,
    "Standards compliance report" = has_standards_report,
    "QA/QC diagnostics" = has_diagnostics,
    "Workflow logs" = has_logs,
    "Spatial data outputs" = has_spatial_outputs
  )

  score <- sum(transparency_checks) / length(transparency_checks)

  passed <- names(transparency_checks)[transparency_checks]
  missing <- names(transparency_checks)[!transparency_checks]

  assessment <- data.frame(
    principle = "CCP3",
    name = "Transparency",
    level = "Program-level",
    status = ifelse(score >= 0.8, "PASS", ifelse(score >= 0.6, "PARTIAL", "FAIL")),
    score = score,
    evidence = sprintf("Available: %s. Missing: %s",
                      paste(passed, collapse = ", "),
                      ifelse(length(missing) > 0, paste(missing, collapse = ", "), "None")),
    recommendation = ifelse(length(missing) > 0,
                           paste("Generate missing documentation:", paste(missing, collapse = ", ")),
                           "Maintain comprehensive documentation for public disclosure")
  )

  return(assessment)
}

#' Assess CCP4: Robust Validation and Verification
assess_ccp4_validation <- function() {
  log_message("Assessing CCP4: Robust Validation and Verification")

  # Check if methodology includes validation/verification requirements

  # Check for cross-validation results
  cv_files <- list.files(file.path(DIR_DIAGNOSTICS, "crossvalidation"),
                        pattern = "*.csv", full.names = TRUE)
  has_cross_validation <- length(cv_files) > 0

  # Check for QA/QC procedures
  qaqc_files <- list.files(file.path(DIR_DIAGNOSTICS, "qaqc"),
                          pattern = "*.csv", full.names = TRUE)
  has_qaqc <- length(qaqc_files) > 0

  # Check for uncertainty quantification
  has_uncertainty <- ENABLE_UNCERTAINTY_ANALYSIS

  # Check for verification package
  has_verification_pkg <- file.exists(file.path(DIR_OUTPUT_MMRV, "vm0033_verification_package.html"))

  checks <- c(has_cross_validation, has_qaqc, has_uncertainty, has_verification_pkg)
  score <- sum(checks) / length(checks)

  assessment <- data.frame(
    principle = "CCP4",
    name = "Robust Validation and Verification",
    level = "Program-level",
    status = ifelse(score >= 0.75, "PASS", "PARTIAL"),
    score = score,
    evidence = sprintf("Cross-validation: %s, QA/QC: %s, Uncertainty analysis: %s, Verification package: %s",
                      has_cross_validation, has_qaqc, has_uncertainty, has_verification_pkg),
    recommendation = "Engage accredited third-party VVB for independent verification"
  )

  return(assessment)
}

#' Assess CCP5: Additionality
assess_ccp5_additionality <- function() {
  log_message("Assessing CCP5: Additionality")

  # Check if temporal analysis demonstrates additionality
  has_temporal <- ENABLE_TEMPORAL_ANALYSIS

  # Check if baseline scenario documented
  has_baseline <- PROJECT_SCENARIO %in% c("PROJECT", "BASELINE") ||
                  file.exists(file.path(DIR_PROCESSED, "temporal_harmonized.rds"))

  # Check for additionality documentation
  has_additionality_output <- file.exists(file.path(DIR_OUTPUT, "additionality")) ||
                              any(grepl("additionality", list.files(DIR_OUTPUT, recursive = TRUE)))

  checks <- c(has_temporal, has_baseline, has_additionality_output)
  score <- sum(checks) / length(checks)

  assessment <- data.frame(
    principle = "CCP5",
    name = "Additionality",
    level = "Project-level",
    status = ifelse(score >= 0.67, "PASS", ifelse(score >= 0.33, "PARTIAL", "FAIL")),
    score = score,
    evidence = sprintf("Temporal analysis: %s, Baseline documented: %s, Additionality outputs: %s",
                      has_temporal, has_baseline, has_additionality_output),
    recommendation = ifelse(score < 0.67,
                           "Enable temporal analysis and document baseline vs. project scenarios",
                           "Document barrier analysis and common practice assessment for additionality")
  )

  return(assessment)
}

#' Assess CCP6: Permanence
assess_ccp6_permanence <- function() {
  log_message("Assessing CCP6: Permanence")

  # Ecosystem-specific permanence risks
  ecosystem <- get_param("ECOSYSTEM_TYPE", default = "unknown")

  permanence_risks <- list(
    coastal_blue_carbon = list(
      risk_level = "MEDIUM",
      risks = c("Sea level rise", "Erosion", "Storm damage", "Land use change"),
      monitoring_frequency = 5
    ),
    forests = list(
      risk_level = "MEDIUM-HIGH",
      risks = c("Fire", "Disease", "Insects", "Illegal logging", "Climate change"),
      monitoring_frequency = 5
    ),
    grasslands = list(
      risk_level = "LOW-MEDIUM",
      risks = c("Conversion to cropland", "Overgrazing", "Fire"),
      monitoring_frequency = 5
    ),
    wetlands_peatlands = list(
      risk_level = "HIGH",
      risks = c("Drainage", "Peat extraction", "Fire", "Climate change impacts"),
      monitoring_frequency = 3
    ),
    arctic_subarctic = list(
      risk_level = "VERY HIGH",
      risks = c("Permafrost thaw", "Thermokarst", "Rapid climate change", "Infrastructure development"),
      monitoring_frequency = 3
    )
  )

  ecosystem_risk <- permanence_risks[[ecosystem]]
  if (is.null(ecosystem_risk)) {
    ecosystem_risk <- list(risk_level = "UNKNOWN", risks = c("Not assessed"), monitoring_frequency = 5)
  }

  # Check for monitoring plan
  has_monitoring_plan <- !is.null(get_param("VM0033_MONITORING_FREQUENCY"))
  monitoring_freq <- get_param("VM0033_MONITORING_FREQUENCY", default = 5)

  # Score based on risk level and monitoring
  risk_scores <- c("LOW" = 1.0, "LOW-MEDIUM" = 0.85, "MEDIUM" = 0.75,
                   "MEDIUM-HIGH" = 0.65, "HIGH" = 0.55, "VERY HIGH" = 0.45, "UNKNOWN" = 0.5)

  base_score <- risk_scores[ecosystem_risk$risk_level]
  if (is.na(base_score)) base_score <- 0.5

  # Bonus for frequent monitoring
  monitoring_bonus <- ifelse(monitoring_freq <= 3, 0.1, ifelse(monitoring_freq <= 5, 0.05, 0))
  score <- min(base_score + monitoring_bonus, 1.0)

  assessment <- data.frame(
    principle = "CCP6",
    name = "Permanence",
    level = "Project-level",
    status = ifelse(score >= 0.7, "PASS", "REVIEW"),
    score = score,
    evidence = sprintf("%s ecosystem - Risk level: %s. Risks: %s. Monitoring frequency: %d years",
                      ecosystem, ecosystem_risk$risk_level,
                      paste(ecosystem_risk$risks, collapse = ", "),
                      monitoring_freq),
    recommendation = "Implement buffer pool mechanism and long-term monitoring for reversal risks"
  )

  return(assessment)
}

#' Assess CCP7: Robust Quantification
assess_ccp7_quantification <- function() {
  log_message("Assessing CCP7: Robust Quantification")

  # Check for conservative approach
  uses_conservative <- get_param("ADDITIONALITY_METHOD", default = "mean") == "lower_bound"

  # Check for uncertainty quantification
  has_uncertainty <- ENABLE_UNCERTAINTY_ANALYSIS

  # Check for cross-validation
  cv_results_exist <- file.exists(file.path(DIR_DIAGNOSTICS, "crossvalidation"))

  # Check for standards compliance
  standards_report_exists <- file.exists(file.path(DIR_OUTPUT_REPORTS, "comprehensive_standards_report.html"))

  # Check if carbon stocks calculated
  carbon_stocks_exist <- file.exists(DIR_OUTPUT_CARBON_STOCKS) &&
                         length(list.files(DIR_OUTPUT_CARBON_STOCKS, pattern = "*.csv")) > 0

  checks <- c(uses_conservative, has_uncertainty, cv_results_exist,
              standards_report_exists, carbon_stocks_exist)
  score <- sum(checks) / length(checks)

  assessment <- data.frame(
    principle = "CCP7",
    name = "Robust Quantification",
    level = "Project-level",
    status = ifelse(score >= 0.8, "PASS", "PARTIAL"),
    score = score,
    evidence = sprintf("Conservative approach: %s, Uncertainty analysis: %s, Cross-validation: %s, Standards compliance: %s, Carbon stocks calculated: %s",
                      uses_conservative, has_uncertainty, cv_results_exist, standards_report_exists, carbon_stocks_exist),
    recommendation = ifelse(score < 0.8,
                           "Enable conservative quantification and uncertainty analysis",
                           "Continue using scientifically robust methods with uncertainty quantification")
  )

  return(assessment)
}

#' Assess CCP8: No Net Harm
assess_ccp8_no_harm <- function() {
  log_message("Assessing CCP8: No Net Harm")

  # This requires external documentation - workflow cannot fully assess
  # Check if project metadata mentions safeguards

  project_desc <- get_param("PROJECT_DESCRIPTION", default = "")

  # Placeholder assessment - requires manual documentation
  assessment <- data.frame(
    principle = "CCP8",
    name = "No Net Harm",
    level = "Project-level",
    status = "MANUAL REVIEW",
    score = NA,
    evidence = "Requires external documentation: Environmental Impact Assessment, FPIC, legal compliance",
    recommendation = paste(
      "1. Conduct Environmental Impact Assessment (EIA)",
      "2. Obtain Free, Prior, and Informed Consent (FPIC) from indigenous peoples/local communities",
      "3. Document compliance with local/national laws",
      "4. Assess biodiversity impacts",
      "5. Ensure no human rights violations",
      sep = "; "
    )
  )

  return(assessment)
}

#' Assess CCP9: Sustainable Development Benefits
assess_ccp9_sd_benefits <- function() {
  log_message("Assessing CCP9: Sustainable Development Benefits")

  # Check ecosystem type for inherent co-benefits
  ecosystem <- get_param("ECOSYSTEM_TYPE", default = "unknown")

  sd_benefits <- list(
    coastal_blue_carbon = c("Coastal protection", "Fisheries habitat", "Water quality", "Biodiversity"),
    forests = c("Biodiversity", "Watershed protection", "Local livelihoods", "Climate regulation"),
    grasslands = c("Soil health", "Biodiversity", "Food security", "Cultural values"),
    wetlands_peatlands = c("Water regulation", "Biodiversity", "Flood control", "Water quality"),
    arctic_subarctic = c("Indigenous livelihoods", "Wildlife habitat", "Cultural preservation", "Climate regulation")
  )

  ecosystem_benefits <- sd_benefits[[ecosystem]]
  if (is.null(ecosystem_benefits)) {
    ecosystem_benefits <- c("To be determined")
  }

  # Placeholder - requires SDG mapping
  assessment <- data.frame(
    principle = "CCP9",
    name = "Sustainable Development Benefits",
    level = "Project-level",
    status = "MANUAL REVIEW",
    score = NA,
    evidence = sprintf("%s ecosystem provides co-benefits: %s",
                      ecosystem, paste(ecosystem_benefits, collapse = ", ")),
    recommendation = paste(
      "1. Map project activities to UN SDGs",
      "2. Engage with local communities on co-benefits",
      "3. Monitor and report co-benefits (biodiversity, livelihoods, gender)",
      "4. Use SD VISta or similar tool for SDG assessment",
      sep = "; "
    )
  )

  return(assessment)
}

#' Assess CCP10: Net-Zero Contribution
assess_ccp10_net_zero <- function() {
  log_message("Assessing CCP10: Net-Zero Contribution")

  # Classify activity type
  ecosystem <- get_param("ECOSYSTEM_TYPE", default = "unknown")
  scenario <- get_param("PROJECT_SCENARIO", default = "PROJECT")

  # Determine if removal or reduction
  activity_type <- ifelse(scenario == "BASELINE", "Unknown",
                         ifelse(grepl("restoration|PROJECT", scenario, ignore.case = TRUE),
                               "Carbon removal", "Unknown"))

  # Check alignment with Paris Agreement
  paris_aligned <- TRUE  # Most nature-based solutions are aligned

  # Check for clear labeling
  outputs_labeled <- file.exists(DIR_OUTPUT_CARBON_STOCKS)

  score <- ifelse(activity_type == "Carbon removal" && paris_aligned && outputs_labeled, 0.9, 0.6)

  assessment <- data.frame(
    principle = "CCP10",
    name = "Net-Zero Contribution",
    level = "Project-level",
    status = ifelse(score >= 0.8, "PASS", "REVIEW"),
    score = score,
    evidence = sprintf("Activity type: %s (%s ecosystem), Paris-aligned: %s, Outputs labeled: %s",
                      activity_type, ecosystem, paris_aligned, outputs_labeled),
    recommendation = paste(
      "1. Clearly label credits as 'Removal' or 'Reduction'",
      "2. Document alignment with Paris Agreement Article 6",
      "3. Ensure activity supports long-term net-zero transition",
      "4. Consider corresponding adjustments if selling internationally",
      sep = "; "
    )
  )

  return(assessment)
}

# ============================================================================
# MASTER ASSESSMENT FUNCTION
# ============================================================================

#' Run complete ICVCM CCP assessment
#'
#' @return Data frame with all CCP assessments
run_icvcm_assessment <- function() {
  cat("\n")
  cat("╔════════════════════════════════════════════════════════════════╗\n")
  cat("║       ICVCM CORE CARBON PRINCIPLES (CCP) ASSESSMENT           ║\n")
  cat("╚════════════════════════════════════════════════════════════════╝\n")
  cat("\n")

  log_message("Starting ICVCM CCP assessment")

  # Run all assessments
  assessments <- bind_rows(
    assess_ccp1_governance(),
    assess_ccp2_tracking(),
    assess_ccp3_transparency(),
    assess_ccp4_validation(),
    assess_ccp5_additionality(),
    assess_ccp6_permanence(),
    assess_ccp7_quantification(),
    assess_ccp8_no_harm(),
    assess_ccp9_sd_benefits(),
    assess_ccp10_net_zero()
  )

  return(assessments)
}

# ============================================================================
# EXECUTE ASSESSMENT
# ============================================================================

# Run assessment
icvcm_results <- run_icvcm_assessment()

# Calculate overall score
overall_score <- mean(icvcm_results$score[!is.na(icvcm_results$score)])
passed <- sum(icvcm_results$status == "PASS", na.rm = TRUE)
partial <- sum(icvcm_results$status == "PARTIAL", na.rm = TRUE)
review <- sum(icvcm_results$status == "REVIEW", na.rm = TRUE)
manual <- sum(icvcm_results$status == "MANUAL REVIEW", na.rm = TRUE)
failed <- sum(icvcm_results$status == "FAIL", na.rm = TRUE)

# Print summary
cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("ICVCM CCP ASSESSMENT SUMMARY\n")
cat("════════════════════════════════════════════════════════════════\n")
cat(sprintf("\nOverall Score: %.1f%%\n", overall_score * 100))
cat(sprintf("\nResults:\n"))
cat(sprintf("  ✓ PASS:          %d / 10\n", passed))
cat(sprintf("  ◐ PARTIAL:       %d / 10\n", partial))
cat(sprintf("  ⚠ REVIEW:        %d / 10\n", review))
cat(sprintf("  📋 MANUAL REVIEW: %d / 10\n", manual))
cat(sprintf("  ✗ FAIL:          %d / 10\n", failed))
cat("\n")

# Print individual results
cat("Individual Principle Assessment:\n")
cat("────────────────────────────────────────────────────────────────\n")
for (i in 1:nrow(icvcm_results)) {
  status_symbol <- switch(icvcm_results$status[i],
                         "PASS" = "✓",
                         "PARTIAL" = "◐",
                         "REVIEW" = "⚠",
                         "MANUAL REVIEW" = "📋",
                         "FAIL" = "✗",
                         "?")

  cat(sprintf("%s CCP%d - %s: %s",
              status_symbol,
              i,
              icvcm_results$name[i],
              icvcm_results$status[i]))

  if (!is.na(icvcm_results$score[i])) {
    cat(sprintf(" (%.0f%%)", icvcm_results$score[i] * 100))
  }
  cat("\n")
}
cat("\n")

# ============================================================================
# SAVE OUTPUTS
# ============================================================================

# Save scorecard
scorecard_file <- file.path(DIR_OUTPUT_REPORTS, "icvcm_ccp_scorecard.csv")
write_csv(icvcm_results, scorecard_file)
log_message(sprintf("Scorecard saved: %s", scorecard_file))

# Create gap analysis
gap_analysis <- icvcm_results %>%
  filter(status %in% c("PARTIAL", "REVIEW", "FAIL", "MANUAL REVIEW")) %>%
  select(principle, name, status, evidence, recommendation)

gap_file <- file.path(DIR_OUTPUT_REPORTS, "icvcm_gap_analysis.csv")
write_csv(gap_analysis, gap_file)
log_message(sprintf("Gap analysis saved: %s", gap_file))

# Create action plan
action_plan <- gap_analysis %>%
  mutate(
    priority = case_when(
      status == "FAIL" ~ "HIGH",
      status == "MANUAL REVIEW" ~ "HIGH",
      status == "REVIEW" ~ "MEDIUM",
      status == "PARTIAL" ~ "MEDIUM",
      TRUE ~ "LOW"
    ),
    timeline = case_when(
      priority == "HIGH" ~ "Before project validation",
      priority == "MEDIUM" ~ "Before verification",
      TRUE ~ "Ongoing"
    )
  ) %>%
  select(priority, principle, name, recommendation, timeline) %>%
  arrange(desc(priority == "HIGH"), desc(priority == "MEDIUM"))

action_file <- file.path(DIR_OUTPUT_REPORTS, "icvcm_action_plan.csv")
write_csv(action_plan, action_file)
log_message(sprintf("Action plan saved: %s", action_file))

# Print action plan
if (nrow(action_plan) > 0) {
  cat("════════════════════════════════════════════════════════════════\n")
  cat("PRIORITY ACTIONS REQUIRED\n")
  cat("════════════════════════════════════════════════════════════════\n")
  cat("\n")

  for (priority in c("HIGH", "MEDIUM", "LOW")) {
    priority_actions <- action_plan %>% filter(priority == !!priority)

    if (nrow(priority_actions) > 0) {
      cat(sprintf("%s PRIORITY (%d actions):\n", priority, nrow(priority_actions)))
      cat("────────────────────────────────────────────────────────────────\n")

      for (j in 1:nrow(priority_actions)) {
        cat(sprintf("%d. %s (%s)\n", j, priority_actions$name[j], priority_actions$principle[j]))
        cat(sprintf("   %s\n", priority_actions$recommendation[j]))
        cat(sprintf("   Timeline: %s\n\n", priority_actions$timeline[j]))
      }
    }
  }
}

# ============================================================================
# FINAL RECOMMENDATIONS
# ============================================================================

cat("════════════════════════════════════════════════════════════════\n")
cat("ICVCM CCP COMPLIANCE PATHWAY\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("\n")

if (overall_score >= 0.8) {
  cat("✓ PROJECT IS WELL-POSITIONED FOR CCP COMPLIANCE\n\n")
  cat("Your project demonstrates strong alignment with ICVCM Core Carbon\n")
  cat("Principles. Focus on completing manual review items and documenting\n")
  cat("all required safeguards.\n\n")
} else if (overall_score >= 0.6) {
  cat("⚠ PROJECT SHOWS PARTIAL CCP ALIGNMENT\n\n")
  cat("Your project has good foundation but requires additional work to\n")
  cat("achieve full CCP compliance. Prioritize high-priority actions and\n")
  cat("strengthen documentation.\n\n")
} else {
  cat("⚠ SIGNIFICANT WORK NEEDED FOR CCP COMPLIANCE\n\n")
  cat("Your project needs substantial improvements to meet CCP standards.\n")
  cat("Review gap analysis and systematically address each principle.\n\n")
}

cat("Next Steps:\n")
cat("1. Review gap analysis and action plan (outputs/reports/)\n")
cat("2. Complete manual review items (CCP8, CCP9)\n")
cat("3. Address high-priority gaps before validation\n")
cat("4. Engage with CCP-approved carbon program (Verra, Gold Standard, etc.)\n")
cat("5. Prepare for third-party verification\n")
cat("\n")

cat("Resources:\n")
cat("• ICVCM Website: https://icvcm.org\n")
cat("• CCP Assessment Framework: https://icvcm.org/assessment-framework/\n")
cat("• Approved Programs: https://icvcm.org/the-core-carbon-principles/\n")
cat("\n")

log_message("ICVCM CCP assessment completed")
log_message(sprintf("Overall score: %.1f%%", overall_score * 100))

cat(sprintf("\n✓ Assessment complete. Outputs saved to: %s\n\n", DIR_OUTPUT_REPORTS))

# ============================================================================
# END OF ASSESSMENT
# ============================================================================
