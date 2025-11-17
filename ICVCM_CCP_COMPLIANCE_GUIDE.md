# ICVCM Core Carbon Principles (CCP) Compliance Guide

## Overview

The **Integrity Council for the Voluntary Carbon Market (ICVCM)** has established the **Core Carbon Principles (CCPs)** as the global quality benchmark for high-integrity carbon credits in the voluntary carbon market.

This workflow now includes **automated assessment** of your carbon project against all 10 Core Carbon Principles, providing:
- ✅ Automated compliance scoring for technical principles
- 📋 Structured checklist for manual review principles
- 📊 Gap analysis identifying areas for improvement
- 📝 Action plan with prioritized recommendations
- 🎯 Pathway to CCP-approved carbon credits

---

## What are the Core Carbon Principles?

The ICVCM Core Carbon Principles define **high-integrity carbon credits**. CCP-labeled credits are recognized globally as meeting rigorous standards for:

- **Environmental integrity** - Real, measurable, permanent emission reductions/removals
- **Sustainable development** - Positive impacts on communities and ecosystems
- **Transparency** - Full disclosure of project information
- **Robust governance** - Independent verification and tracking

---

## The 10 Core Carbon Principles

### **Program-Level Principles** (Assessed at carbon program level)

#### CCP1: Effective Governance
The Carbon-Crediting Program has effective program governance.

**Criteria:**
- Clear governance structure and decision-making processes
- Conflict of interest policies
- Stakeholder consultation mechanisms
- Grievance and dispute resolution procedures
- Transparency in governance

**Workflow Assessment:**
- ✅ Checks if using CCP-approved program (Verra, Gold Standard, CAR, ACR)
- ✅ Verifies methodology standards alignment

---

#### CCP2: Tracking
Emission reductions and removals are tracked toward mitigation goals.

**Criteria:**
- Unique serial numbers for all carbon credits
- Registry system prevents double counting
- Credits tracked from issuance to retirement
- Integration with national/international tracking systems
- Transparent cancellation and retirement records

**Workflow Assessment:**
- ✅ Verifies project has unique identifiers
- ✅ Checks for session tracking and traceability
- ✅ Confirms carbon stock outputs structured for registry upload

---

#### CCP3: Transparency
All relevant information is disclosed to allow scrutiny of mitigation activities.

**Criteria:**
- Publicly available project documentation
- Methodology documents accessible
- Verification reports published
- Monitoring data disclosed
- Clear credit issuance records

**Workflow Assessment:**
- ✅ Checks for MMRV verification package
- ✅ Verifies standards compliance reports generated
- ✅ Confirms QA/QC diagnostics available
- ✅ Validates workflow logs and spatial data outputs

---

#### CCP4: Robust Third-Party Validation and Verification
Independent third-party validation and verification.

**Criteria:**
- Accredited validation/verification bodies (VVBs)
- Independence requirements for VVBs
- Competency requirements for auditors
- Quality assurance processes
- Regular re-verification requirements

**Workflow Assessment:**
- ✅ Checks for cross-validation results
- ✅ Verifies QA/QC procedures implemented
- ✅ Confirms uncertainty quantification enabled
- ✅ Validates verification package generated
- 📋 Recommends engaging accredited third-party VVB

---

### **Carbon-Credit Integrity Principles** (Assessed at project level)

#### CCP5: Additionality
The mitigation activity goes beyond business-as-usual.

**Criteria:**
- Project activity would not occur without carbon finance
- Documented baseline scenario
- Barrier analysis (financial, technological, institutional)
- Common practice analysis
- Conservative baseline assumptions

**Workflow Assessment:**
- ✅ Checks for temporal analysis (baseline vs. project comparison)
- ✅ Verifies baseline scenario documented
- ✅ Confirms additionality outputs generated
- 📋 Recommends documenting barrier analysis

---

#### CCP6: Permanence
Permanent emission reductions or removals.

**Criteria:**
- Risk assessment for reversal (e.g., fire, disease, land-use change)
- Monitoring for reversals
- Buffer pool or insurance mechanism
- Long-term commitment to project (crediting period)
- Legal agreements ensure permanence

**Workflow Assessment:**
- ✅ Ecosystem-specific risk assessment
- ✅ Evaluates monitoring frequency adequacy
- 📊 Risk levels by ecosystem:
  - **Coastal Blue Carbon:** MEDIUM (erosion, sea level rise, storms)
  - **Forests:** MEDIUM-HIGH (fire, disease, logging)
  - **Grasslands:** LOW-MEDIUM (conversion, overgrazing)
  - **Wetlands/Peatlands:** HIGH (drainage, fire, peat extraction)
  - **Arctic/Subarctic:** VERY HIGH (permafrost thaw, thermokarst)
- 📋 Recommends buffer pool and legal safeguards

---

#### CCP7: Robust Quantification
Robust quantification of emission reductions and removals.

**Criteria:**
- Conservative assumptions and approaches
- Uncertainty quantification and accounting
- Scientifically robust methodologies
- Appropriate baseline and project scenarios
- Leakage assessment and deductions

**Workflow Assessment:**
- ✅ Verifies conservative approach enabled (95% CI lower bound)
- ✅ Checks uncertainty analysis activated
- ✅ Confirms cross-validation performed
- ✅ Validates standards compliance documentation
- ✅ Confirms carbon stocks calculated using robust methods

---

### **Sustainable Development Principles** (Assessed at project level)

#### CCP8: No Net Harm
The mitigation activity does not violate local and national laws.

**Criteria:**
- Environmental impact assessment conducted
- No negative impacts on biodiversity
- Free, prior, and informed consent (FPIC) obtained
- No human rights violations
- Compliance with local/national laws

**Workflow Assessment:**
- 📋 MANUAL REVIEW REQUIRED
- 📋 Requires external documentation:
  - Environmental Impact Assessment (EIA)
  - Free, Prior, and Informed Consent (FPIC) from indigenous peoples/local communities
  - Legal compliance documentation
  - Biodiversity impact assessment
  - Human rights safeguards

---

#### CCP9: Sustainable Development Benefits and Safeguards
The mitigation activity delivers net positive impacts.

**Criteria:**
- Positive contributions to UN Sustainable Development Goals (SDGs)
- Co-benefits for local communities
- Biodiversity conservation
- Gender equality considerations
- Monitoring and reporting of sustainable development benefits

**Workflow Assessment:**
- 📋 MANUAL REVIEW REQUIRED
- ✅ Identifies ecosystem-specific co-benefits:
  - **Coastal Blue Carbon:** Coastal protection, fisheries, water quality, biodiversity
  - **Forests:** Biodiversity, watershed protection, livelihoods, climate regulation
  - **Grasslands:** Soil health, biodiversity, food security, cultural values
  - **Wetlands/Peatlands:** Water regulation, flood control, biodiversity
  - **Arctic/Subarctic:** Indigenous livelihoods, wildlife habitat, cultural preservation
- 📋 Recommends SDG mapping and community engagement

---

### **Net-Zero Alignment Principle**

#### CCP10: Contribution Toward Net-Zero Emissions
The nature of the mitigation activity is consistent with net-zero pathways.

**Criteria:**
- Activity type consistent with long-term net-zero goals
- Avoids lock-in of high-carbon systems
- Supports transition to low-carbon economy
- Aligned with Paris Agreement goals
- Clear labeling of removal vs. reduction credits

**Workflow Assessment:**
- ✅ Classifies activity type (removal vs. reduction)
- ✅ Verifies Paris Agreement alignment
- ✅ Checks for clear output labeling
- 📋 Recommends explicit removal/reduction labeling for credits

---

## How to Run ICVCM CCP Assessment

### Step 1: Enable in Configuration

In `config.R`:

```r
# Enable ICVCM Core Carbon Principles assessment
ENABLE_ICVCM_CCP_ASSESSMENT <- TRUE
```

### Step 2: Run Complete Workflow

```r
source("run_workflow.R")
```

The ICVCM CCP assessment runs automatically after Module 07b (Standards Compliance Report).

### Step 3: Run Assessment Standalone

To run only the ICVCM assessment:

```r
source("config.R")
source("11_icvcm_ccp_assessment.R")
```

---

## Output Files

The ICVCM CCP assessment generates four key outputs in `outputs/reports/`:

### 1. **icvcm_ccp_scorecard.csv**
Complete assessment of all 10 principles with:
- Principle number and name
- Assessment level (program or project)
- Status (PASS / PARTIAL / REVIEW / MANUAL REVIEW / FAIL)
- Numerical score (0-1, where applicable)
- Evidence supporting the assessment
- Specific recommendations

### 2. **icvcm_gap_analysis.csv**
Identifies principles requiring attention:
- Lists all principles not achieving "PASS" status
- Provides detailed evidence and recommendations
- Helps prioritize improvement efforts

### 3. **icvcm_action_plan.csv**
Prioritized action plan with:
- **Priority levels:** HIGH, MEDIUM, LOW
- **Actions required** for each principle
- **Timeline recommendations:**
  - HIGH priority → Before project validation
  - MEDIUM priority → Before verification
  - LOW priority → Ongoing improvement

### 4. **Console Summary**
Real-time assessment summary showing:
- Overall compliance score (%)
- Breakdown by status (PASS, PARTIAL, REVIEW, etc.)
- Individual principle results
- Priority actions
- Next steps and resources

---

## Interpreting Results

### Status Levels

| Status | Meaning | Action Required |
|--------|---------|-----------------|
| **✓ PASS** | Principle met or strong alignment | Maintain documentation |
| **◐ PARTIAL** | Partially compliant, improvements needed | Address gaps before verification |
| **⚠ REVIEW** | Requires attention or additional work | Prioritize improvements |
| **📋 MANUAL REVIEW** | Requires external documentation | Prepare required documents |
| **✗ FAIL** | Not compliant | Critical - address before validation |

### Overall Score Interpretation

| Score | Assessment | Pathway |
|-------|------------|---------|
| **≥80%** | Well-positioned for CCP compliance | Focus on manual review items |
| **60-79%** | Partial alignment | Address gaps systematically |
| **<60%** | Significant work needed | Review all principles, prioritize critical gaps |

---

## CCP-Approved Carbon Programs

To achieve CCP-labeled credits, your project must use a **CCP-approved carbon program**. As of 2025, the following programs are approved or under assessment:

### ✅ CCP-Approved Programs:
- **Verra (VCS)** - Includes VM0033, VM0012, VM0026, VM0036
- **Gold Standard**
- **Climate Action Reserve (CAR)**
- **American Carbon Registry (ACR)**

### 🔄 Programs Under Assessment:
- Check ICVCM website for latest approved programs

**Recommendation:** This workflow is designed for Verra methodologies (VM0033, VM0012, VM0026, VM0036), which are CCP-approved.

---

## Roadmap to CCP Compliance

### Phase 1: Technical Compliance (Automated by Workflow)
- ✅ **CCP1-CCP4:** Use CCP-approved program and methodology
- ✅ **CCP5:** Enable temporal analysis, document additionality
- ✅ **CCP6:** Implement monitoring plan, assess permanence risks
- ✅ **CCP7:** Use conservative quantification, enable uncertainty analysis

**Timeline:** During project design and MMRV implementation

### Phase 2: Safeguards Documentation (Manual)
- 📋 **CCP8:** Conduct Environmental Impact Assessment
- 📋 **CCP8:** Obtain Free, Prior, and Informed Consent (FPIC)
- 📋 **CCP8:** Document legal compliance
- 📋 **CCP9:** Map activities to UN SDGs
- 📋 **CCP9:** Engage communities on co-benefits

**Timeline:** Before project validation

### Phase 3: Third-Party Verification
- 🔍 Engage accredited Validation/Verification Body (VVB)
- 🔍 Submit documentation for independent review
- 🔍 Address VVB findings and recommendations

**Timeline:** Before credit issuance

### Phase 4: CCP Labeling
- 🏆 Carbon program applies CCP label to approved methodology
- 🏆 Project receives CCP-labeled credits upon verification
- 🏆 Credits recognized globally as high-integrity

**Timeline:** After successful verification

---

## Action Checklist for CCP Compliance

Use this checklist to systematically achieve CCP compliance:

### Technical Assessment (Workflow-Generated)
- [ ] Run ICVCM CCP assessment module
- [ ] Review scorecard and gap analysis
- [ ] Enable all recommended workflow features:
  - [ ] Temporal analysis (CCP5)
  - [ ] Uncertainty analysis (CCP7)
  - [ ] Conservative quantification (CCP7)
  - [ ] Comprehensive reporting (CCP3)
- [ ] Achieve ≥80% automated assessment score

### Documentation Preparation
- [ ] Environmental Impact Assessment (EIA) completed
- [ ] Free, Prior, and Informed Consent (FPIC) obtained
- [ ] Legal compliance documented
- [ ] Biodiversity impacts assessed
- [ ] Human rights safeguards in place
- [ ] UN SDG mapping completed
- [ ] Co-benefits documented and monitored
- [ ] Gender equality considerations addressed

### Project Registration
- [ ] Register with CCP-approved program (Verra, Gold Standard, etc.)
- [ ] Select CCP-approved methodology
- [ ] Submit Project Design Document (PDD)
- [ ] Obtain project validation

### Monitoring and Verification
- [ ] Implement monitoring plan per methodology
- [ ] Run MMRV workflow at required intervals
- [ ] Engage accredited VVB for verification
- [ ] Submit monitoring reports
- [ ] Address VVB findings

### Credit Issuance
- [ ] Receive verification statement
- [ ] Credits issued with CCP label
- [ ] Credits listed on registry
- [ ] Maintain transparency (public documentation)

---

## Frequently Asked Questions

### Q: Is CCP compliance mandatory?

**A:** CCP compliance is not legally mandatory, but it's becoming the **de facto quality standard** for voluntary carbon markets. Many buyers now require or prefer CCP-labeled credits.

### Q: Can existing projects achieve CCP compliance?

**A:** Yes! Existing projects on CCP-approved methodologies can be assessed and labeled as CCP-compliant if they meet all principles. This workflow helps identify and address any gaps.

### Q: How long does CCP assessment take?

**A:**
- **Automated workflow assessment:** 5-10 minutes
- **Manual documentation preparation:** Weeks to months (depends on project complexity)
- **Third-party verification:** 3-6 months

### Q: What if my project doesn't achieve 100% on all principles?

**A:** The gap analysis and action plan identify specific improvements needed. Many principles require external documentation (EIA, FPIC, etc.) that you prepare separately. The workflow assesses technical compliance.

### Q: Does CCP compliance guarantee credit sales?

**A:** CCP compliance significantly enhances credit marketability and can command premium prices, but does not guarantee sales. Market demand depends on credit type, price, co-benefits, and buyer preferences.

### Q: How often do I need to reassess CCP compliance?

**A:** Reassess at each verification period (typically every 5 years for most methodologies). Use this workflow at each monitoring cycle to maintain compliance.

---

## Resources

### Official ICVCM Resources
- **ICVCM Website:** https://icvcm.org
- **Core Carbon Principles:** https://icvcm.org/the-core-carbon-principles/
- **Assessment Framework:** https://icvcm.org/assessment-framework/
- **CCP-Approved Programs:** https://icvcm.org/ccp-approved-programs/

### Carbon Program Resources
- **Verra VCS:** https://verra.org/programs/verified-carbon-standard/
- **Gold Standard:** https://www.goldstandard.org/
- **Climate Action Reserve:** https://www.climateactionreserve.org/
- **American Carbon Registry:** https://americancarbonregistry.org/

### Methodology-Specific Guidance
- **VM0033 (Blue Carbon):** https://verra.org/methodologies/vm0033/
- **VM0012 (Forests - IFM):** https://verra.org/methodologies/vm0012/
- **VM0026 (Grasslands):** https://verra.org/methodologies/vm0026/
- **VM0036 (Wetlands):** https://verra.org/methodologies/vm0036/

### Supporting Tools
- **SD VISta (SDG Assessment):** https://sdvista.verra.org/
- **Climate Warehouse (Tracking):** https://www.theclimatewarehouse.org/

---

## Integration with Workflow

The ICVCM CCP assessment is **fully integrated** with the generalized MMRV workflow:

### Data Sources
The assessment uses outputs from:
- Module 01: Data preparation (project metadata)
- Module 03: Depth harmonization (uncertainty analysis)
- Module 06: Carbon stock calculation (conservative quantification)
- Module 07: MMRV reporting (verification package)
- Module 07b: Standards compliance (methodology alignment)
- Module 08-10: Temporal analysis (additionality)

### Complementary Standards
The workflow assesses compliance with multiple standards:
- **VM0033, VM0012, VM0026, VM0036** (Verra methodologies)
- **IPCC Guidelines** (Tier 3 approach)
- **ORRAA High Quality Blue Carbon**
- **ICVCM Core Carbon Principles** ← NEW

Together, these provide comprehensive quality assurance for carbon projects.

---

## Conclusion

The ICVCM Core Carbon Principles represent the **global quality standard for carbon markets**. This workflow provides:

1. **Automated technical assessment** of 7 principles
2. **Structured guidance** for 3 manual review principles
3. **Gap analysis** identifying improvements needed
4. **Action plan** with clear priorities and timelines
5. **Integration** with existing MMRV standards

By systematically addressing each principle, your project can achieve **high-integrity, CCP-labeled carbon credits** recognized globally in voluntary carbon markets.

**Start your CCP compliance journey today:**
```r
ENABLE_ICVCM_CCP_ASSESSMENT <- TRUE
source("run_workflow.R")
```

---

*Last Updated: January 2025*
*Workflow Version: 2.1 (with ICVCM CCP Assessment)*
*ICVCM CCP Version: 1.0 (March 2023)*
