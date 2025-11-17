# ICVCM CCP Quick Reference Guide

## One-Page Summary for Project Developers

### What is ICVCM CCP?

The **Integrity Council for the Voluntary Carbon Market (ICVCM)** created the **Core Carbon Principles (CCPs)** as the global quality standard for carbon credits. CCP-labeled credits are:

- ✅ Recognized globally as high-integrity
- ✅ Eligible for premium pricing
- ✅ Preferred by many corporate buyers
- ✅ Required for high-quality carbon portfolios

### The 10 Core Carbon Principles (30-Second Summary)

| # | Principle | What It Means | Workflow Support |
|---|-----------|---------------|------------------|
| **1** | Effective Governance | Use CCP-approved program (Verra, Gold Standard, etc.) | ✅ Auto-check |
| **2** | Tracking | Credits tracked from issuance to retirement | ✅ Auto-check |
| **3** | Transparency | All project info publicly available | ✅ Auto-check |
| **4** | Robust Verification | Independent third-party validation | ✅ Auto-check |
| **5** | Additionality | Wouldn't happen without carbon finance | ✅ Auto-check |
| **6** | Permanence | Carbon stays stored long-term | ✅ Auto-check |
| **7** | Robust Quantification | Conservative, scientifically sound methods | ✅ Auto-check |
| **8** | No Net Harm | No environmental or social harm | 📋 Manual docs |
| **9** | Sustainable Development | Net positive community/biodiversity impacts | 📋 Manual docs |
| **10** | Net-Zero Contribution | Supports long-term climate goals | ✅ Auto-check |

### How to Use the Workflow for CCP Compliance

#### Step 1: Enable Assessment (2 minutes)

```r
# In config.R
ENABLE_ICVCM_CCP_ASSESSMENT <- TRUE
ENABLE_TEMPORAL_ANALYSIS <- TRUE  # For additionality (CCP5)
ENABLE_UNCERTAINTY_ANALYSIS <- TRUE  # For robust quantification (CCP7)
```

#### Step 2: Run Workflow (1-4 hours depending on data size)

```r
source("run_workflow.R")
```

The workflow automatically runs:
- **Module 11:** CCP assessment (automated scoring)
- **Module 11b:** HTML report generation
- **Module 11c:** Pre-verification checklist

#### Step 3: Review Results (15 minutes)

```r
# Open HTML report
browseURL("outputs/reports/icvcm_ccp_assessment_report.html")

# Check verification readiness
source("11c_icvcm_pre_verification_checklist.R")
```

### Typical Results Timeline

| Your Score | Status | Action Required | Timeline to Compliance |
|------------|--------|-----------------|------------------------|
| **≥80%** | Ready for compliance | Complete manual review items | 2-6 months |
| **60-79%** | Good progress | Address gaps systematically | 4-12 months |
| **<60%** | Needs significant work | Strengthen all areas | 6-18 months |

### Manual Documentation Checklist (CCP8 & CCP9)

These items require external documentation:

#### CCP8: No Net Harm (CRITICAL)
- [ ] Environmental Impact Assessment (EIA)
- [ ] Free, Prior, Informed Consent (FPIC) from local/indigenous communities
- [ ] Legal compliance documentation
- [ ] Biodiversity assessment
- [ ] Human rights safeguards

**Timeline:** Must complete BEFORE validation

#### CCP9: Sustainable Development Benefits (HIGH PRIORITY)
- [ ] UN SDG mapping (use SD VISta tool)
- [ ] Co-benefits documentation
- [ ] Community engagement plan
- [ ] Gender equality considerations

**Timeline:** Complete BEFORE verification

### Quick Action Plan by Score

#### If Score ≥80%: "Ready for Compliance"

1. ✅ Complete manual review items (CCP8, CCP9)
2. 📞 Contact CCP-approved program (Verra, Gold Standard)
3. 📋 Prepare Project Design Document (PDD)
4. 🔍 Engage Validation/Verification Body (VVB)

**Estimated time to CCP labeling:** 3-6 months

#### If Score 60-79%: "Good Progress"

1. 📊 Review gap analysis carefully
2. ⚠️ Address all HIGH priority items first
3. 📄 Strengthen technical documentation
4. 📋 Begin manual documentation (CCP8, CCP9)

**Estimated time to CCP labeling:** 6-12 months

#### If Score <60%: "Needs Work"

1. 🔧 Enable missing workflow features
2. 📊 Run temporal analysis for additionality
3. 📈 Improve data quality and sampling
4. 📚 Study CCP requirements in detail

**Estimated time to CCP labeling:** 12-18 months

### Ecosystem-Specific Permanence Risks (CCP6)

| Ecosystem | Risk Level | Key Threats | Mitigation |
|-----------|------------|-------------|------------|
| **Coastal Blue Carbon** | MEDIUM | Sea level rise, erosion, storms | Buffer pool, monitoring, legal protection |
| **Forests** | MEDIUM-HIGH | Fire, disease, logging, climate change | Fire management, pest control, easements |
| **Grasslands** | LOW-MEDIUM | Conversion, overgrazing | Land use agreements, monitoring |
| **Wetlands/Peatlands** | HIGH | Drainage, fire, peat extraction | Water management, fire prevention |
| **Arctic/Subarctic** | VERY HIGH | Permafrost thaw, climate change | Active layer monitoring, risk insurance |

### CCP-Approved Carbon Programs

Your project must use one of these programs to receive CCP label:

| Program | Methodologies Available | Best For |
|---------|------------------------|----------|
| **Verra (VCS)** | VM0033, VM0012, VM0026, VM0036 | All ecosystem types - most comprehensive |
| **Gold Standard** | Multiple | Projects with strong SD benefits |
| **Climate Action Reserve (CAR)** | Forest protocols | US-based forest projects |
| **American Carbon Registry (ACR)** | Various | North American projects |

**Recommendation:** This workflow is optimized for **Verra methodologies**.

### Cost Estimates for CCP Compliance

| Item | Cost Range (USD) | When |
|------|------------------|------|
| Environmental Impact Assessment | $5,000 - $50,000 | Before validation |
| FPIC Process | $2,000 - $20,000 | Before validation |
| Validation (VVB fees) | $15,000 - $100,000+ | Validation phase |
| Verification (VVB fees) | $10,000 - $50,000+ | Every 5 years |
| Program registration | $500 - $5,000 | Initial |
| Annual program fees | $500 - $5,000/year | Ongoing |
| **Total first-year cost** | **$33,000 - $225,000+** | Variable by project size |

**Note:** Costs vary significantly based on project size, complexity, and location.

### Premium Value of CCP-Labeled Credits

CCP-labeled credits typically command **10-30% premium** over non-labeled credits:

| Credit Type | Typical Price Range (2024) |
|-------------|---------------------------|
| Standard VCM credit | $5 - $15 per tCO2e |
| CCP-labeled credit | $8 - $25 per tCO2e |
| Premium | +$3 - $10 per tCO2e |

**ROI:** For a 100,000 tCO2e project, CCP labeling could add $300,000 - $1,000,000 in value.

### Timeline from Start to CCP-Labeled Credits

```
Month 0-3:   Project design, baseline assessment, MMRV setup
Month 3-6:   Run workflow, CCP assessment, identify gaps
Month 6-12:  Complete manual documentation (EIA, FPIC, SDGs)
Month 12-15: Prepare PDD, engage VVB, validation
Month 15-18: First monitoring period
Month 18-21: Verification, credit issuance
Month 21+:   CCP-labeled credits issued and marketed

TOTAL: 18-24 months typical timeline
```

### Resources (Bookmark These!)

#### Official ICVCM
- **Main site:** https://icvcm.org
- **CCPs explained:** https://icvcm.org/the-core-carbon-principles/
- **Assessment framework:** https://icvcm.org/assessment-framework/

#### Tools
- **SD VISta (SDG mapping):** https://sdvista.verra.org
- **Verra registry:** https://registry.verra.org

#### This Workflow
- **Full guide:** `ICVCM_CCP_COMPLIANCE_GUIDE.md`
- **HTML report:** `outputs/reports/icvcm_ccp_assessment_report.html`
- **Checklist:** `outputs/reports/icvcm_pre_verification_checklist.csv`

### FAQs (Top 5)

**Q: Is CCP compliance mandatory?**
A: No, but it's becoming the de facto standard. Many buyers require or strongly prefer CCP-labeled credits.

**Q: Can I get CCP label for existing projects?**
A: Yes! Existing projects on CCP-approved methodologies can be assessed and labeled if they meet all principles.

**Q: How long does the assessment take?**
A: Automated workflow assessment: 5-10 minutes. Manual documentation: weeks to months. Full compliance: 6-18 months.

**Q: What if I don't pass all principles?**
A: The gap analysis shows exactly what to improve. Most projects pass technical principles but need work on safeguards (CCP8-9).

**Q: Does CCP replace VM0033/other methodology compliance?**
A: No - CCP is complementary. You still need methodology compliance PLUS CCP principles for the label.

### One-Line Summary

> **ICVCM CCP = Global quality stamp for carbon credits. This workflow automates 70% of the assessment. Complete the remaining 30% (safeguards docs) to achieve high-integrity, premium-priced carbon credits.**

---

**Need help?** See full documentation in `ICVCM_CCP_COMPLIANCE_GUIDE.md`

**Ready to start?** Run `source("run_workflow.R")` with `ENABLE_ICVCM_CCP_ASSESSMENT = TRUE`

---

*Last updated: January 2025 | Workflow v2.1 | ICVCM CCP v1.0*
