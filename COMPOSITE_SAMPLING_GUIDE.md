# Composite Sampling Guide

## Overview

The generalized MMRV workflow supports **toggling composite sampling on/off** while maintaining the same output structure. This allows you to:

1. **Use composite sampling** - Combine multiple subsamples into representative composite samples
2. **Process individual samples** - Analyze each sample separately for high-resolution spatial analysis
3. **Switch seamlessly** - Same workflow, same outputs, different sampling resolution

---

## Configuration

### Enable Composite Sampling

In `config.R`:

```r
COMPOSITE_SAMPLING <- TRUE
COMPOSITE_METHOD <- "paired"  # Options: "paired", "unpaired", "mixed"
```

### Disable Composite Sampling

```r
COMPOSITE_SAMPLING <- FALSE
# COMPOSITE_METHOD not used when FALSE
```

---

## How It Works

### When `COMPOSITE_SAMPLING = TRUE`

**What happens:**
1. Data preparation identifies subsamples belonging to same composite
2. Subsamples are aggregated by core_id and depth interval
3. Mean SOC and BD calculated for each composite
4. Standard errors propagated from subsamples
5. Depth harmonization applied to composite values
6. Spatial predictions use composite sample locations

**Input data structure:**

```csv
core_id,subsample_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bd_g_cm3,stratum,longitude,latitude
CORE01,A,0,15,45.2,1.1,Upper Marsh,-123.456,49.123
CORE01,B,0,15,48.1,1.0,Upper Marsh,-123.456,49.123
CORE01,C,0,15,46.5,1.05,Upper Marsh,-123.456,49.123
```

**Processing:**
- Subsamples A, B, C are averaged into one composite for CORE01 (0-15 cm)
- Mean SOC = (45.2 + 48.1 + 46.5) / 3 = 46.6 g/kg
- Mean BD = (1.1 + 1.0 + 1.05) / 3 = 1.05 g/cm³
- Standard errors calculated from subsample variation

### When `COMPOSITE_SAMPLING = FALSE`

**What happens:**
1. Each row in input data treated as independent sample
2. No aggregation performed
3. Each sample gets unique sample_id
4. All samples processed through workflow individually
5. Spatial predictions use all sample locations (higher density)

**Input data structure:**

```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bd_g_cm3,stratum,longitude,latitude
SITE01,0,15,45.2,1.1,Upper Marsh,-123.456,49.123
SITE02,0,15,52.3,1.0,Upper Marsh,-123.457,49.124
SITE03,0,15,38.9,1.15,Upper Marsh,-123.458,49.125
```

**Processing:**
- Each row is a separate sample
- No averaging
- Higher spatial resolution for mapping
- More data points for geostatistics

---

## Composite Sampling Methods

### Paired Composite

```r
COMPOSITE_METHOD <- "paired"
```

**Description:**
- Subsamples collected from same location
- Combined to reduce analytical costs
- Preserve spatial location accuracy

**Use when:**
- Multiple subsamples per core (e.g., A, B, C replicates)
- Reducing lab analysis costs
- Location precision more important than within-core variability

### Unpaired Composite

```r
COMPOSITE_METHOD <- "unpaired"
```

**Description:**
- Subsamples from nearby locations combined
- Representative of small area rather than point
- Spatial averaging

**Use when:**
- High spatial heterogeneity
- Budget constraints require fewer analyses
- Area-weighted estimates preferred

### Mixed Composite

```r
COMPOSITE_METHOD <- "mixed"
```

**Description:**
- Combination of paired and unpaired
- Some cores have replicates (paired), others don't
- Maximum flexibility

**Use when:**
- Mixed sampling design
- Different strata have different sampling intensities
- Transitioning between methods

---

## Data Requirements

### For Composite Sampling (TRUE)

**Required columns:**
- `core_id` - Unique identifier for composite group
- `subsample_id` (optional) - Identifier for subsamples
- `depth_top_cm` - Top of depth interval
- `depth_bottom_cm` - Bottom of depth interval
- `soc_g_kg` - Soil organic carbon
- `bd_g_cm3` - Bulk density
- `stratum` - Ecosystem stratum
- `longitude` - GPS longitude
- `latitude` - GPS latitude

**Example:**
```csv
core_id,subsample_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bd_g_cm3,stratum,longitude,latitude
C001,A,0,15,45.2,1.1,Mid Marsh,-123.4,49.1
C001,B,0,15,48.1,1.0,Mid Marsh,-123.4,49.1
C001,C,0,15,46.5,1.05,Mid Marsh,-123.4,49.1
C001,A,15,30,38.4,1.2,Mid Marsh,-123.4,49.1
C001,B,15,30,41.2,1.15,Mid Marsh,-123.4,49.1
C001,C,15,30,39.8,1.18,Mid Marsh,-123.4,49.1
```

### For Individual Sampling (FALSE)

**Required columns:**
- `core_id` - Unique sample identifier
- `depth_top_cm`
- `depth_bottom_cm`
- `soc_g_kg`
- `bd_g_cm3`
- `stratum`
- `longitude`
- `latitude`

**Example:**
```csv
core_id,depth_top_cm,depth_bottom_cm,soc_g_kg,bd_g_cm3,stratum,longitude,latitude
S001,0,15,45.2,1.1,Mid Marsh,-123.4,49.1
S002,0,15,52.3,1.0,Mid Marsh,-123.5,49.2
S003,0,15,38.9,1.15,Mid Marsh,-123.6,49.3
S001,15,30,38.4,1.2,Mid Marsh,-123.4,49.1
S002,15,30,44.1,1.05,Mid Marsh,-123.5,49.2
S003,15,30,35.6,1.22,Mid Marsh,-123.6,49.3
```

---

## Output Differences

### File Naming

**Composite mode:**
```
carbon_stocks_coastal_blue_carbon_composite.csv
cores_harmonized_coastal_blue_carbon_composite.rds
```

**Individual mode:**
```
carbon_stocks_coastal_blue_carbon_individual.csv
cores_harmonized_coastal_blue_carbon_individual.rds
```

### Output Structure

**Both modes produce:**
- Same column structure
- Same statistical summaries
- Same spatial predictions
- Same reports

**Differences:**
- Number of data points (fewer in composite mode)
- Spatial resolution (higher in individual mode)
- Uncertainty propagation (composite includes within-sample variation)

---

## Advantages and Disadvantages

### Composite Sampling (TRUE)

**Advantages:**
✅ Lower analytical costs (fewer lab analyses)
✅ Reduces random analytical error through averaging
✅ Standard practice in many protocols
✅ Easier field logistics (fewer samples to transport)

**Disadvantages:**
❌ Loss of fine-scale spatial information
❌ Cannot assess within-core variability
❌ Lower spatial resolution for mapping
❌ Potentially masks hotspots or anomalies

### Individual Sampling (FALSE)

**Advantages:**
✅ Maximum spatial resolution
✅ Preserves within-core variability
✅ Better for geostatistical analysis
✅ Can identify spatial patterns and hotspots
✅ More data points for model training

**Disadvantages:**
❌ Higher analytical costs
❌ More lab analyses required
❌ Potentially higher analytical error per sample
❌ More complex data management

---

## Recommendations

### Use Composite Sampling (TRUE) when:

1. **Budget constraints** - Limited funds for lab analyses
2. **Large-scale surveys** - Many locations to cover
3. **Homogeneous sites** - Low within-site variability
4. **Regulatory compliance** - Methodology requires composites
5. **Exploratory phase** - Screening large areas

### Use Individual Sampling (FALSE) when:

1. **High-resolution mapping** - Need detailed spatial patterns
2. **Heterogeneous sites** - High spatial variability
3. **Research objectives** - Investigating spatial processes
4. **Budget allows** - Can afford more analyses
5. **Model development** - Need more training data

### Consider Mixed Approach:

- Composite samples for most of site
- Individual samples in areas of interest
- Use `COMPOSITE_METHOD = "mixed"` and flag in data

---

## Example Workflows

### Example 1: Grassland Carbon Project (Composite)

```r
# config.R
ECOSYSTEM_TYPE <- "grasslands"
COMPOSITE_SAMPLING <- TRUE
COMPOSITE_METHOD <- "paired"

# Reasoning: Large prairie area, limited budget
# 3 subsamples per location combined to reduce costs
# 50 locations → 50 composite samples instead of 150 individual
```

### Example 2: Coastal Restoration Research (Individual)

```r
# config.R
ECOSYSTEM_TYPE <- "coastal_blue_carbon"
COMPOSITE_SAMPLING <- FALSE

# Reasoning: Studying spatial patterns of carbon accumulation
# Need high-resolution data for geostatistical modeling
# 100 individual samples for detailed kriging
```

### Example 3: Forest Inventory (Mixed)

```r
# config.R
ECOSYSTEM_TYPE <- "forests"
COMPOSITE_SAMPLING <- TRUE
COMPOSITE_METHOD <- "mixed"

# Reasoning: Most plots use paired composites
# Old growth stands sampled individually for detail
# Optimizes budget while preserving key information
```

---

## Troubleshooting

### Issue: Composite averaging not working

**Symptoms:** Each subsample appears as separate sample in output

**Solution:**
1. Check `COMPOSITE_SAMPLING = TRUE` in config.R
2. Verify `core_id` is identical for subsamples to be composited
3. Ensure `depth_top_cm` and `depth_bottom_cm` match exactly
4. Check for typos in core_id (e.g., "CORE01" vs "CORE_01")

### Issue: Too few samples after compositing

**Symptoms:** Very low sample size warnings

**Solution:**
1. Review input data - may have too much aggregation
2. Consider `COMPOSITE_SAMPLING = FALSE` for higher n
3. Collect more field samples
4. Use mixed method to balance cost and sample size

### Issue: Uncertainty too high

**Symptoms:** High CV, wide confidence intervals

**Possible causes:**
- High within-composite variability (check subsample SD)
- Too much spatial heterogeneity
- Small sample size

**Solutions:**
- Increase number of composites
- Refine stratification (more homogeneous strata)
- Check for outliers or data quality issues
- Consider individual sampling in high-variability areas

---

## References

- IPCC 2006 Guidelines - Chapter 3.3.1 (Sampling strategies)
- Verra VM0033 - Section 8.1.4 (Composite sampling)
- ORRAA Guidance - Sampling Design Principles

---

## Summary

The composite sampling toggle provides **flexibility without complexity**:

- **Same workflow** regardless of setting
- **Same output structure** for easy comparison
- **Easy to switch** between modes
- **Documented clearly** in output filenames

Choose the mode that best fits your:
- Project objectives
- Budget constraints
- Site characteristics
- Spatial resolution needs
- Methodology requirements

When in doubt, **start with composite sampling** (standard practice) and switch to individual if higher resolution is needed.
