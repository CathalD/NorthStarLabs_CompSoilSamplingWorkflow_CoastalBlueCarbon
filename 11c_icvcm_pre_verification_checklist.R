# ============================================================================
# ICVCM CCP PRE-VERIFICATION CHECKLIST
# ============================================================================
# PURPOSE: Interactive checklist for CCP compliance documentation
#
# This script helps project developers systematically prepare for
# third-party verification by checking all required documentation
# and evidence for ICVCM Core Carbon Principles compliance.
#
# OUTPUTS:
#   - outputs/reports/icvcm_pre_verification_checklist.csv
#   - outputs/reports/icvcm_pre_verification_summary.txt
#   - Console-based interactive checklist
# ============================================================================

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# Load configuration
if (file.exists("config.R")) {
  source("config.R")
}

# Create output directory
if (!dir.exists("outputs/reports")) {
  dir.create("outputs/reports", recursive = TRUE)
}

# ============================================================================
# DEFINE CHECKLIST ITEMS
# ============================================================================

# Create comprehensive checklist
checklist <- data.frame(
  category = c(
    # CCP1: Effective Governance
    "CCP1", "CCP1", "CCP1",

    # CCP2: Tracking
    "CCP2", "CCP2", "CCP2",

    # CCP3: Transparency
    "CCP3", "CCP3", "CCP3", "CCP3", "CCP3",

    # CCP4: Validation/Verification
    "CCP4", "CCP4", "CCP4",

    # CCP5: Additionality
    "CCP5", "CCP5", "CCP5", "CCP5", "CCP5",

    # CCP6: Permanence
    "CCP6", "CCP6", "CCP6", "CCP6", "CCP6",

    # CCP7: Robust Quantification
    "CCP7", "CCP7", "CCP7", "CCP7", "CCP7",

    # CCP8: No Net Harm
    "CCP8", "CCP8", "CCP8", "CCP8", "CCP8", "CCP8",

    # CCP9: Sustainable Development
    "CCP9", "CCP9", "CCP9", "CCP9", "CCP9",

    # CCP10: Net-Zero Contribution
    "CCP10", "CCP10", "CCP10"
  ),

  principle_name = c(
    # CCP1
    "Effective Governance", "Effective Governance", "Effective Governance",

    # CCP2
    "Tracking", "Tracking", "Tracking",

    # CCP3
    "Transparency", "Transparency", "Transparency", "Transparency", "Transparency",

    # CCP4
    "Robust Validation/Verification", "Robust Validation/Verification", "Robust Validation/Verification",

    # CCP5
    "Additionality", "Additionality", "Additionality", "Additionality", "Additionality",

    # CCP6
    "Permanence", "Permanence", "Permanence", "Permanence", "Permanence",

    # CCP7
    "Robust Quantification", "Robust Quantification", "Robust Quantification", "Robust Quantification", "Robust Quantification",

    # CCP8
    "No Net Harm", "No Net Harm", "No Net Harm", "No Net Harm", "No Net Harm", "No Net Harm",

    # CCP9
    "Sustainable Development", "Sustainable Development", "Sustainable Development", "Sustainable Development", "Sustainable Development",

    # CCP10
    "Net-Zero Contribution", "Net-Zero Contribution", "Net-Zero Contribution"
  ),

  item = c(
    # CCP1
    "Project registered with CCP-approved program (Verra, Gold Standard, CAR, ACR)",
    "Program methodology document obtained and reviewed",
    "Understanding of program governance and grievance procedures",

    # CCP2
    "Project registered on program registry with unique project ID",
    "Serialization system in place for carbon credits",
    "Registry account created for credit issuance and tracking",

    # CCP3
    "Project Design Document (PDD) prepared",
    "Monitoring plan documented and approved",
    "All geospatial data (shapefiles, rasters) prepared for disclosure",
    "QA/QC reports and diagnostics compiled",
    "Carbon stock calculation spreadsheets/reports ready for review",

    # CCP4
    "Accredited Validation/Verification Body (VVB) selected",
    "VVB contract signed and validation scheduled",
    "All technical documentation prepared for VVB review",

    # CCP5
    "Baseline scenario documented (business-as-usual without project)",
    "Project scenario documented (with project intervention)",
    "Additionality assessment completed (barrier analysis, common practice)",
    "Temporal analysis results showing project vs. baseline",
    "Conservative baseline assumptions documented",

    # CCP6
    "Permanence risk assessment completed for ecosystem type",
    "Reversal risk mitigation plan documented",
    "Buffer pool allocation calculated (if required by program)",
    "Long-term project commitment documented (legal agreements, easements)",
    "Monitoring plan for detecting reversals established",

    # CCP7
    "Conservative quantification approach documented (95% CI lower bound)",
    "Uncertainty analysis completed and reported",
    "Cross-validation results documented (R², RMSE, MAE)",
    "Leakage assessment completed (if applicable)",
    "All calculation methods peer-reviewed or following approved methodology",

    # CCP8
    "Environmental Impact Assessment (EIA) completed",
    "Free, Prior, and Informed Consent (FPIC) obtained from indigenous peoples/local communities",
    "Documentation of compliance with local and national laws",
    "Biodiversity impact assessment completed",
    "Stakeholder consultation records maintained",
    "Evidence of no human rights violations",

    # CCP9
    "UN Sustainable Development Goals (SDGs) mapping completed",
    "Co-benefits documented (biodiversity, livelihoods, water quality, etc.)",
    "Community engagement plan and records",
    "Gender equality considerations documented",
    "Co-benefits monitoring plan established",

    # CCP10
    "Activity type clearly labeled (carbon removal vs. reduction)",
    "Alignment with Paris Agreement Article 6 documented",
    "Contribution to net-zero transition pathways explained"
  ),

  priority = c(
    # CCP1
    "HIGH", "HIGH", "MEDIUM",

    # CCP2
    "HIGH", "MEDIUM", "MEDIUM",

    # CCP3
    "HIGH", "HIGH", "HIGH", "HIGH", "HIGH",

    # CCP4
    "HIGH", "HIGH", "HIGH",

    # CCP5
    "HIGH", "HIGH", "HIGH", "MEDIUM", "MEDIUM",

    # CCP6
    "HIGH", "HIGH", "MEDIUM", "MEDIUM", "MEDIUM",

    # CCP7
    "HIGH", "HIGH", "MEDIUM", "MEDIUM", "MEDIUM",

    # CCP8
    "CRITICAL", "CRITICAL", "CRITICAL", "HIGH", "HIGH", "HIGH",

    # CCP9
    "HIGH", "HIGH", "MEDIUM", "MEDIUM", "MEDIUM",

    # CCP10
    "MEDIUM", "MEDIUM", "MEDIUM"
  ),

  document_type = c(
    # CCP1
    "Registration", "Methodology", "Procedures",

    # CCP2
    "Registration", "Registry", "Registry",

    # CCP3
    "PDD", "Monitoring Plan", "Spatial Data", "QA/QC", "Reports",

    # CCP4
    "Contract", "Contract", "Documentation Package",

    # CCP5
    "PDD Section", "PDD Section", "Additionality Assessment", "Technical Report", "PDD Section",

    # CCP6
    "Risk Assessment", "Mitigation Plan", "Buffer Calculation", "Legal Documents", "Monitoring Plan",

    # CCP7
    "Methodology Section", "Uncertainty Report", "Cross-Validation Report", "Leakage Assessment", "Methodology",

    # CCP8
    "EIA Report", "FPIC Documentation", "Legal Compliance", "Biodiversity Assessment", "Consultation Records", "Safeguards Report",

    # CCP9
    "SDG Assessment", "Co-Benefits Report", "Community Engagement", "Gender Assessment", "Monitoring Plan",

    # CCP10
    "Credit Labeling", "Paris Alignment", "Net-Zero Contribution"
  ),

  stringsAsFactors = FALSE
)

# Add status column (to be filled)
checklist$status <- "NOT STARTED"
checklist$evidence_location <- ""
checklist$notes <- ""

# ============================================================================
# AUTO-CHECK WORKFLOW OUTPUTS
# ============================================================================

cat("\n")
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║       ICVCM CCP PRE-VERIFICATION CHECKLIST                    ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n")
cat("\n")

cat("Checking workflow outputs for automatic verification...\n\n")

# Check CCP3 items based on workflow outputs
if (file.exists("outputs/mmrv_reports/vm0033_verification_package.html")) {
  checklist$status[checklist$item == "Project Design Document (PDD) prepared"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "Project Design Document (PDD) prepared"] <- "outputs/mmrv_reports/vm0033_verification_package.html"
}

if (file.exists("outputs/mmrv_reports/vm0033_verification_package.html")) {
  checklist$status[checklist$item == "Monitoring plan documented and approved"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "Monitoring plan documented and approved"] <- "outputs/mmrv_reports/"
}

if (dir.exists("outputs/predictions") && length(list.files("outputs/predictions", pattern = ".tif$", recursive = TRUE)) > 0) {
  checklist$status[checklist$item == "All geospatial data (shapefiles, rasters) prepared for disclosure"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "All geospatial data (shapefiles, rasters) prepared for disclosure"] <- "outputs/predictions/"
}

if (dir.exists("diagnostics") && length(list.files("diagnostics", recursive = TRUE)) > 0) {
  checklist$status[checklist$item == "QA/QC reports and diagnostics compiled"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "QA/QC reports and diagnostics compiled"] <- "diagnostics/"
}

if (dir.exists("outputs/carbon_stocks") && length(list.files("outputs/carbon_stocks", pattern = ".csv$")) > 0) {
  checklist$status[checklist$item == "Carbon stock calculation spreadsheets/reports ready for review"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "Carbon stock calculation spreadsheets/reports ready for review"] <- "outputs/carbon_stocks/"
}

# Check CCP5 items
if (file.exists("outputs/additionality") || any(grepl("additionality", list.files("outputs", recursive = TRUE)))) {
  checklist$status[checklist$item == "Temporal analysis results showing project vs. baseline"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "Temporal analysis results showing project vs. baseline"] <- "outputs/"
}

# Check CCP7 items
if (file.exists("diagnostics/crossvalidation")) {
  checklist$status[checklist$item == "Cross-validation results documented (R², RMSE, MAE)"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "Cross-validation results documented (R², RMSE, MAE)"] <- "diagnostics/crossvalidation/"
}

if (file.exists("outputs/carbon_stocks") && any(grepl("conservative", list.files("outputs/carbon_stocks")))) {
  checklist$status[checklist$item == "Conservative quantification approach documented (95% CI lower bound)"] <- "COMPLETE"
  checklist$evidence_location[checklist$item == "Conservative quantification approach documented (95% CI lower bound)"] <- "outputs/carbon_stocks/"
}

# Calculate completion statistics
total_items <- nrow(checklist)
completed <- sum(checklist$status == "COMPLETE")
not_started <- sum(checklist$status == "NOT STARTED")
in_progress <- sum(checklist$status == "IN PROGRESS")

completion_pct <- round(completed / total_items * 100, 1)

# ============================================================================
# DISPLAY RESULTS
# ============================================================================

cat("\n")
cat("════════════════════════════════════════════════════════════════\n")
cat("VERIFICATION READINESS SUMMARY\n")
cat("════════════════════════════════════════════════════════════════\n")
cat(sprintf("\nOverall Completion: %.1f%% (%d / %d items)\n", completion_pct, completed, total_items))
cat(sprintf("\n  ✓ Completed:    %d\n", completed))
cat(sprintf("  ◐ In Progress:  %d\n", in_progress))
cat(sprintf("  ○ Not Started:  %d\n", not_started))
cat("\n")

# Completion by principle
cat("Completion by Core Carbon Principle:\n")
cat("────────────────────────────────────────────────────────────────\n")

for (ccp in paste0("CCP", 1:10)) {
  ccp_items <- checklist %>% filter(category == ccp)
  ccp_complete <- sum(ccp_items$status == "COMPLETE")
  ccp_total <- nrow(ccp_items)
  ccp_pct <- round(ccp_complete / ccp_total * 100, 0)

  principle_name <- unique(ccp_items$principle_name)

  status_symbol <- if (ccp_pct == 100) "✓" else if (ccp_pct >= 50) "◐" else "○"

  cat(sprintf("%s %s - %s: %d%% (%d/%d)\n",
              status_symbol, ccp, principle_name, ccp_pct, ccp_complete, ccp_total))
}
cat("\n")

# Critical items
cat("════════════════════════════════════════════════════════════════\n")
cat("CRITICAL ITEMS REQUIRING IMMEDIATE ATTENTION\n")
cat("════════════════════════════════════════════════════════════════\n\n")

critical_items <- checklist %>%
  filter(priority == "CRITICAL" & status != "COMPLETE")

if (nrow(critical_items) > 0) {
  for (i in 1:nrow(critical_items)) {
    item <- critical_items[i,]
    cat(sprintf("%d. [%s] %s\n", i, item$category, item$item))
    cat(sprintf("   Type: %s\n", item$document_type))
    cat(sprintf("   Status: %s\n\n", item$status))
  }
} else {
  cat("✓ All critical items completed!\n\n")
}

# High priority items
cat("════════════════════════════════════════════════════════════════\n")
cat("HIGH PRIORITY ITEMS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

high_priority <- checklist %>%
  filter(priority == "HIGH" & status != "COMPLETE")

if (nrow(high_priority) > 0) {
  for (i in 1:nrow(high_priority)) {
    item <- high_priority[i,]
    cat(sprintf("%d. [%s] %s\n", i, item$category, item$item))
    cat(sprintf("   Type: %s\n", item$document_type))
    cat(sprintf("   Status: %s\n\n", item$status))
  }
} else {
  cat("✓ All high priority items completed!\n\n")
}

# ============================================================================
# SAVE CHECKLIST
# ============================================================================

# Save to CSV
checklist_file <- "outputs/reports/icvcm_pre_verification_checklist.csv"
write_csv(checklist, checklist_file)
cat(sprintf("✓ Checklist saved to: %s\n", checklist_file))

# Create summary report
summary_file <- "outputs/reports/icvcm_pre_verification_summary.txt"

sink(summary_file)
cat("ICVCM CCP PRE-VERIFICATION CHECKLIST SUMMARY\n")
cat("============================================\n\n")
cat(sprintf("Generated: %s\n", Sys.time()))
cat(sprintf("Project: %s\n\n", get("PROJECT_NAME", envir = .GlobalEnv)))

cat(sprintf("Overall Completion: %.1f%% (%d / %d items)\n\n", completion_pct, completed, total_items))

cat("Completion by Principle:\n")
for (ccp in paste0("CCP", 1:10)) {
  ccp_items <- checklist %>% filter(category == ccp)
  ccp_complete <- sum(ccp_items$status == "COMPLETE")
  ccp_total <- nrow(ccp_items)
  ccp_pct <- round(ccp_complete / ccp_total * 100, 0)
  principle_name <- unique(ccp_items$principle_name)
  cat(sprintf("  %s: %d%% (%d/%d) - %s\n", ccp, ccp_pct, ccp_complete, ccp_total, principle_name))
}

cat("\n\nREADINESS ASSESSMENT:\n")
if (completion_pct >= 90) {
  cat("READY FOR VERIFICATION - Your project has completed most documentation requirements.\n")
} else if (completion_pct >= 70) {
  cat("GOOD PROGRESS - Address remaining high-priority items before scheduling verification.\n")
} else if (completion_pct >= 50) {
  cat("NEEDS WORK - Significant documentation gaps remain. Focus on critical and high-priority items.\n")
} else {
  cat("NOT READY - Substantial preparation needed before verification. Systematically work through checklist.\n")
}

cat("\n\nNEXT STEPS:\n")
cat("1. Review checklist CSV for detailed item-by-item status\n")
cat("2. Address all CRITICAL priority items immediately\n")
cat("3. Complete HIGH priority items before contacting VVB\n")
cat("4. Prepare MEDIUM priority items for comprehensive documentation\n")
cat("5. Schedule validation once completion reaches >90%\n")

sink()

cat(sprintf("✓ Summary saved to: %s\n\n", summary_file))

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

cat("════════════════════════════════════════════════════════════════\n")
cat("RECOMMENDATIONS\n")
cat("════════════════════════════════════════════════════════════════\n\n")

if (completion_pct < 90) {
  cat("To increase verification readiness:\n\n")

  if (nrow(critical_items) > 0) {
    cat("1. CRITICAL: Complete all critical items (CCP8 safeguards)\n")
    cat("   - Engage environmental consultant for EIA\n")
    cat("   - Conduct FPIC process with local/indigenous communities\n")
    cat("   - Document all legal compliance\n\n")
  }

  if (nrow(high_priority) > 0) {
    cat("2. HIGH PRIORITY: Address high-priority documentation gaps\n")
    cat("   - Ensure PDD is complete and reviewed\n")
    cat("   - Select and engage VVB for validation\n")
    cat("   - Complete additionality and permanence assessments\n\n")
  }

  cat("3. Enable missing workflow modules:\n")
  if (!get("ENABLE_TEMPORAL_ANALYSIS", envir = .GlobalEnv)) {
    cat("   - Set ENABLE_TEMPORAL_ANALYSIS = TRUE for additionality (CCP5)\n")
  }
  if (!get("ENABLE_UNCERTAINTY_ANALYSIS", envir = .GlobalEnv)) {
    cat("   - Set ENABLE_UNCERTAINTY_ANALYSIS = TRUE for robust quantification (CCP7)\n")
  }
  cat("\n")

  cat("4. Prepare sustainable development documentation:\n")
  cat("   - Use SD VISta tool for SDG mapping\n")
  cat("   - Document all co-benefits systematically\n")
  cat("   - Develop community engagement plan\n\n")
}

cat("For detailed guidance, see:\n")
cat("  - ICVCM_CCP_COMPLIANCE_GUIDE.md\n")
cat("  - outputs/reports/icvcm_ccp_assessment_report.html\n")
cat("  - https://icvcm.org/the-core-carbon-principles/\n\n")

# ============================================================================
# END OF CHECKLIST
# ============================================================================
