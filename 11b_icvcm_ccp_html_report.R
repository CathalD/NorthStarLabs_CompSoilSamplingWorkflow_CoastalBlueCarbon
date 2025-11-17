# ============================================================================
# ICVCM CCP HTML REPORT GENERATOR
# ============================================================================
# PURPOSE: Generate professional HTML report for ICVCM CCP compliance
#
# This script creates a comprehensive, visually appealing HTML report
# summarizing ICVCM Core Carbon Principles compliance assessment
#
# INPUTS:
#   - outputs/reports/icvcm_ccp_scorecard.csv
#   - outputs/reports/icvcm_gap_analysis.csv
#   - outputs/reports/icvcm_action_plan.csv
#
# OUTPUTS:
#   - outputs/reports/icvcm_ccp_assessment_report.html
# ============================================================================

# Required packages
if (!requireNamespace("knitr", quietly = TRUE)) {
  install.packages("knitr")
}
if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  install.packages("rmarkdown")
}

library(knitr)
library(rmarkdown)
library(dplyr)
library(readr)

# ============================================================================
# LOAD ICVCM ASSESSMENT RESULTS
# ============================================================================

# Check if assessment has been run
scorecard_file <- "outputs/reports/icvcm_ccp_scorecard.csv"
if (!file.exists(scorecard_file)) {
  stop("ICVCM CCP assessment has not been run yet. Please run 11_icvcm_ccp_assessment.R first.")
}

# Load results
scorecard <- read_csv(scorecard_file, show_col_types = FALSE)
gap_analysis <- read_csv("outputs/reports/icvcm_gap_analysis.csv", show_col_types = FALSE)
action_plan <- read_csv("outputs/reports/icvcm_action_plan.csv", show_col_types = FALSE)

# Calculate summary statistics
overall_score <- mean(scorecard$score[!is.na(scorecard$score)]) * 100
passed <- sum(scorecard$status == "PASS", na.rm = TRUE)
partial <- sum(scorecard$status == "PARTIAL", na.rm = TRUE)
review <- sum(scorecard$status == "REVIEW", na.rm = TRUE)
manual <- sum(scorecard$status == "MANUAL REVIEW", na.rm = TRUE)
failed <- sum(scorecard$status == "FAIL", na.rm = TRUE)

# Determine overall rating
overall_rating <- if (overall_score >= 80) {
  "EXCELLENT"
} else if (overall_score >= 60) {
  "GOOD"
} else if (overall_score >= 40) {
  "NEEDS IMPROVEMENT"
} else {
  "SIGNIFICANT WORK REQUIRED"
}

# ============================================================================
# CREATE HTML REPORT
# ============================================================================

# Create R Markdown content
rmd_content <- sprintf('
---
title: "ICVCM Core Carbon Principles Compliance Assessment"
subtitle: "Project: %s"
date: "%s"
output:
  html_document:
    toc: true
    toc_float: true
    toc_depth: 3
    theme: flatly
    highlight: tango
    css: styles.css
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)
library(dplyr)
library(knitr)
library(readr)

# Load data
scorecard <- read_csv("outputs/reports/icvcm_ccp_scorecard.csv", show_col_types = FALSE)
gap_analysis <- read_csv("outputs/reports/icvcm_gap_analysis.csv", show_col_types = FALSE)
action_plan <- read_csv("outputs/reports/icvcm_action_plan.csv", show_col_types = FALSE)
```

<style>
.excellent { background-color: #d4edda; border-left: 5px solid #28a745; padding: 15px; margin: 10px 0; }
.good { background-color: #d1ecf1; border-left: 5px solid #17a2b8; padding: 15px; margin: 10px 0; }
.needs-improvement { background-color: #fff3cd; border-left: 5px solid #ffc107; padding: 15px; margin: 10px 0; }
.significant-work { background-color: #f8d7da; border-left: 5px solid #dc3545; padding: 15px; margin: 10px 0; }
.status-pass { color: #28a745; font-weight: bold; }
.status-partial { color: #17a2b8; font-weight: bold; }
.status-review { color: #ffc107; font-weight: bold; }
.status-manual { color: #6c757d; font-weight: bold; }
.status-fail { color: #dc3545; font-weight: bold; }
.principle-card { border: 1px solid #dee2e6; border-radius: 5px; padding: 15px; margin: 10px 0; }
.high-priority { background-color: #f8d7da; border-left: 4px solid #dc3545; }
.medium-priority { background-color: #fff3cd; border-left: 4px solid #ffc107; }
.low-priority { background-color: #d1ecf1; border-left: 4px solid #17a2b8; }
</style>

# Executive Summary

<div class="%s">

## Overall Assessment: %s

**Overall Compliance Score: %.1f%%**

- ✓ **PASS:** %d / 10 principles
- ◐ **PARTIAL:** %d / 10 principles
- ⚠ **REVIEW:** %d / 10 principles
- 📋 **MANUAL REVIEW:** %d / 10 principles
- ✗ **FAIL:** %d / 10 principles

</div>

---

# What are the ICVCM Core Carbon Principles?

The **Integrity Council for the Voluntary Carbon Market (ICVCM)** established the **Core Carbon Principles (CCPs)** as the global benchmark for high-integrity carbon credits. CCP-labeled credits represent:

- **Environmental Integrity** - Real, measurable, permanent emission reductions/removals
- **Sustainable Development** - Positive impacts on communities and ecosystems
- **Transparency** - Full disclosure of project information
- **Robust Governance** - Independent verification and tracking

Projects meeting all 10 CCPs can receive the **CCP label**, recognized globally as high-quality carbon credits eligible for premium pricing in voluntary carbon markets.

---

# Assessment Results by Principle

## Program-Level Principles

These principles are assessed at the carbon crediting program level (e.g., Verra, Gold Standard).

```{r program-principles, results="asis"}
program_principles <- scorecard %>%%
  filter(level == "Program-level")

for (i in 1:nrow(program_principles)) {
  principle <- program_principles[i,]

  # Determine status class
  status_class <- tolower(gsub(" ", "-", gsub("MANUAL REVIEW", "manual", principle$status)))

  # Create card
  cat(sprintf("
### %s: %s

<div class=\\"principle-card\\">

**Status:** <span class=\\"status-%s\\">%s</span>",
    principle$principle,
    principle$name,
    status_class,
    principle$status))

  if (!is.na(principle$score)) {
    cat(sprintf(" **(Score: %.0f%%)**", principle$score * 100))
  }

  cat(sprintf("

**Evidence:**
%s

**Recommendation:**
%s

</div>
", principle$evidence, principle$recommendation))
}
```

## Carbon-Credit Integrity Principles

These principles ensure the carbon credits represent real, additional, permanent emission reductions/removals.

```{r integrity-principles, results="asis"}
integrity_principles <- scorecard %>%%
  filter(level == "Project-level" & principle %%in%% c("CCP5", "CCP6", "CCP7"))

for (i in 1:nrow(integrity_principles)) {
  principle <- integrity_principles[i,]

  status_class <- tolower(gsub(" ", "-", gsub("MANUAL REVIEW", "manual", principle$status)))

  cat(sprintf("
### %s: %s

<div class=\\"principle-card\\">

**Status:** <span class=\\"status-%s\\">%s</span>",
    principle$principle,
    principle$name,
    status_class,
    principle$status))

  if (!is.na(principle$score)) {
    cat(sprintf(" **(Score: %.0f%%)**", principle$score * 100))
  }

  cat(sprintf("

**Evidence:**
%s

**Recommendation:**
%s

</div>
", principle$evidence, principle$recommendation))
}
```

## Sustainable Development Principles

These principles ensure the project contributes positively to local communities and the environment.

```{r sd-principles, results="asis"}
sd_principles <- scorecard %>%%
  filter(principle %%in%% c("CCP8", "CCP9"))

for (i in 1:nrow(sd_principles)) {
  principle <- sd_principles[i,]

  status_class <- tolower(gsub(" ", "-", gsub("MANUAL REVIEW", "manual", principle$status)))

  cat(sprintf("
### %s: %s

<div class=\\"principle-card\\">

**Status:** <span class=\\"status-%s\\">%s</span>",
    principle$principle,
    principle$name,
    status_class,
    principle$status))

  if (!is.na(principle$score)) {
    cat(sprintf(" **(Score: %.0f%%)**", principle$score * 100))
  }

  cat(sprintf("

**Evidence:**
%s

**Recommendation:**
%s

</div>
", principle$evidence, principle$recommendation))
}
```

## Net-Zero Alignment

This principle ensures the project contributes to long-term net-zero emissions pathways.

```{r netzero-principle, results="asis"}
netzero_principle <- scorecard %>%%
  filter(principle == "CCP10")

for (i in 1:nrow(netzero_principle)) {
  principle <- netzero_principle[i,]

  status_class <- tolower(gsub(" ", "-", gsub("MANUAL REVIEW", "manual", principle$status)))

  cat(sprintf("
### %s: %s

<div class=\\"principle-card\\">

**Status:** <span class=\\"status-%s\\">%s</span>",
    principle$principle,
    principle$name,
    status_class,
    principle$status))

  if (!is.na(principle$score)) {
    cat(sprintf(" **(Score: %.0f%%)**", principle$score * 100))
  }

  cat(sprintf("

**Evidence:**
%s

**Recommendation:**
%s

</div>
", principle$evidence, principle$recommendation))
}
```

---

# Gap Analysis

```{r gap-check, results="asis"}
if (nrow(gap_analysis) > 0) {
  cat("
The following principles require attention before achieving full CCP compliance:

")

  for (i in 1:nrow(gap_analysis)) {
    gap <- gap_analysis[i,]
    cat(sprintf("
### %s: %s

**Status:** %s

**Issue:**
%s

**Action Required:**
%s

---
", gap$principle, gap$name, gap$status, gap$evidence, gap$recommendation))
  }
} else {
  cat("
**✓ Congratulations!** Your project has achieved PASS status on all assessed principles.

Focus on completing documentation for manual review principles (CCP8, CCP9) to achieve full CCP compliance.
")
}
```

---

# Action Plan

This prioritized action plan identifies the steps needed to achieve CCP compliance.

## High Priority Actions

```{r high-priority, results="asis"}
high_priority <- action_plan %>%% filter(priority == "HIGH")

if (nrow(high_priority) > 0) {
  cat("
<div class=\\"high-priority\\" style=\\"padding: 15px; margin: 10px 0;\\">

**These actions must be completed before project validation.**

")

  for (i in 1:nrow(high_priority)) {
    action <- high_priority[i,]
    cat(sprintf("
**%d. %s (%s)**

- **Action:** %s
- **Timeline:** %s

", i, action$name, action$principle, action$recommendation, action$timeline))
  }

  cat("
</div>
")
} else {
  cat("✓ No high-priority actions required.

")
}
```

## Medium Priority Actions

```{r medium-priority, results="asis"}
medium_priority <- action_plan %>%% filter(priority == "MEDIUM")

if (nrow(medium_priority) > 0) {
  cat("
<div class=\\"medium-priority\\" style=\\"padding: 15px; margin: 10px 0;\\">

**These actions should be addressed before verification.**

")

  for (i in 1:nrow(medium_priority)) {
    action <- medium_priority[i,]
    cat(sprintf("
**%d. %s (%s)**

- **Action:** %s
- **Timeline:** %s

", i, action$name, action$principle, action$recommendation, action$timeline))
  }

  cat("
</div>
")
} else {
  cat("✓ No medium-priority actions required.

")
}
```

## Low Priority Actions

```{r low-priority, results="asis"}
low_priority <- action_plan %>%% filter(priority == "LOW")

if (nrow(low_priority) > 0) {
  cat("
<div class=\\"low-priority\\" style=\\"padding: 15px; margin: 10px 0;\\">

**These actions are recommended for ongoing improvement.**

")

  for (i in 1:nrow(low_priority)) {
    action <- low_priority[i,]
    cat(sprintf("
**%d. %s (%s)**

- **Action:** %s
- **Timeline:** %s

", i, action$name, action$principle, action$recommendation, action$timeline))
  }

  cat("
</div>
")
} else {
  cat("✓ No low-priority actions required.

")
}
```

---

# Pathway to CCP-Labeled Credits

## Phase 1: Technical Compliance (Current)

- [x] Run MMRV workflow with required modules enabled
- [x] Complete ICVCM CCP assessment
- [ ] Address all technical gaps identified in action plan

## Phase 2: Safeguards Documentation

- [ ] Conduct Environmental Impact Assessment (EIA)
- [ ] Obtain Free, Prior, and Informed Consent (FPIC) from affected communities
- [ ] Document compliance with local/national laws
- [ ] Map project activities to UN Sustainable Development Goals (SDGs)
- [ ] Develop co-benefits monitoring plan

## Phase 3: Program Registration

- [ ] Select CCP-approved carbon program (Verra, Gold Standard, CAR, ACR)
- [ ] Prepare Project Design Document (PDD)
- [ ] Submit for validation
- [ ] Receive validation statement

## Phase 4: Monitoring & Verification

- [ ] Implement MMRV plan according to methodology
- [ ] Collect monitoring data at required intervals
- [ ] Engage accredited Validation/Verification Body (VVB)
- [ ] Submit monitoring reports
- [ ] Receive verification statement

## Phase 5: Credit Issuance

- [ ] Credits issued by carbon program
- [ ] CCP label applied (if all principles met)
- [ ] Credits listed on registry
- [ ] Market carbon credits to buyers

---

# Next Steps

```{r next-steps, results="asis"}
if (overall_score >= 80) {
  cat("
**Your project is well-positioned for CCP compliance!**

Immediate actions:
1. Complete high-priority items in action plan
2. Prepare documentation for manual review principles (CCP8, CCP9)
3. Engage with CCP-approved carbon program
4. Begin validation preparation

")
} else if (overall_score >= 60) {
  cat("
**Your project shows good progress toward CCP compliance.**

Immediate actions:
1. Review gap analysis and prioritize improvements
2. Address all high and medium priority items
3. Strengthen technical documentation
4. Prepare safeguards documentation

")
} else {
  cat("
**Significant work is needed to achieve CCP compliance.**

Immediate actions:
1. Systematically address each principle in gap analysis
2. Enable all recommended workflow features (temporal analysis, uncertainty analysis)
3. Strengthen project documentation
4. Consider engaging CCP compliance consultant

")
}
```

---

# Resources

## ICVCM Resources

- **ICVCM Website:** [https://icvcm.org](https://icvcm.org)
- **Core Carbon Principles:** [https://icvcm.org/the-core-carbon-principles/](https://icvcm.org/the-core-carbon-principles/)
- **Assessment Framework:** [https://icvcm.org/assessment-framework/](https://icvcm.org/assessment-framework/)
- **CCP-Approved Programs:** [https://icvcm.org/ccp-approved-programs/](https://icvcm.org/ccp-approved-programs/)

## CCP-Approved Carbon Programs

- **Verra (VCS):** [https://verra.org](https://verra.org)
- **Gold Standard:** [https://www.goldstandard.org](https://www.goldstandard.org)
- **Climate Action Reserve:** [https://www.climateactionreserve.org](https://www.climateactionreserve.org)
- **American Carbon Registry:** [https://americancarbonregistry.org](https://americancarbonregistry.org)

## Supporting Tools

- **SD VISta (SDG Impact Tool):** [https://sdvista.verra.org](https://sdvista.verra.org)
- **Climate Warehouse (Credit Tracking):** [https://www.theclimatewarehouse.org](https://www.theclimatewarehouse.org)

## Methodology Resources

- **VM0033 (Blue Carbon):** [https://verra.org/methodologies/vm0033/](https://verra.org/methodologies/vm0033/)
- **VM0012 (Forests - IFM):** [https://verra.org/methodologies/vm0012/](https://verra.org/methodologies/vm0012/)
- **VM0026 (Grasslands):** [https://verra.org/methodologies/vm0026/](https://verra.org/methodologies/vm0026/)
- **VM0036 (Wetlands):** [https://verra.org/methodologies/vm0036/](https://verra.org/methodologies/vm0036/)

---

# Appendix: Full Assessment Scorecard

```{r full-scorecard}
scorecard %>%%
  select(principle, name, level, status, score, evidence, recommendation) %>%%
  kable(
    caption = "Complete ICVCM CCP Assessment Results",
    col.names = c("Principle", "Name", "Level", "Status", "Score", "Evidence", "Recommendation")
  )
```

---

<div style="background-color: #f8f9fa; padding: 20px; margin-top: 30px; border-top: 3px solid #007bff;">

**Report Generated:** %s

**Workflow Version:** 2.1 (with ICVCM CCP Assessment)

**Assessment Module:** 11_icvcm_ccp_assessment.R

For questions or support, see [ICVCM_CCP_COMPLIANCE_GUIDE.md](ICVCM_CCP_COMPLIANCE_GUIDE.md)

</div>
',
  get("PROJECT_NAME", envir = .GlobalEnv),
  format(Sys.time(), "%%Y-%%m-%%d %%H:%%M:%%S"),
  tolower(gsub(" ", "-", overall_rating)),
  overall_rating,
  overall_score,
  passed, partial, review, manual, failed,
  format(Sys.time(), "%%Y-%%m-%%d %%H:%%M:%%S")
)

# Write R Markdown file
rmd_file <- "outputs/reports/icvcm_ccp_assessment_report.Rmd"
writeLines(rmd_content, rmd_file)

# Render to HTML
cat("Generating ICVCM CCP HTML report...\n")
output_file <- rmarkdown::render(
  rmd_file,
  output_file = "icvcm_ccp_assessment_report.html",
  output_dir = "outputs/reports",
  quiet = TRUE
)

cat(sprintf("\n✓ ICVCM CCP HTML report generated: %s\n", output_file))
cat("\nOpen in browser to view:\n")
cat(sprintf("  browseURL(\"%s\")\n\n", output_file))

# Clean up Rmd file
file.remove(rmd_file)

# ============================================================================
# END OF REPORT GENERATOR
# ============================================================================
