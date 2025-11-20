# Transfer Learning Workflow for Blue Carbon Analysis

## Overview

This workflow implements **advanced transfer learning** to leverage the Janousek et al. 2025 global blue carbon dataset for improving local predictions. The workflow harmonizes global and local data to VM0033 standard depths, preserves environmental covariates, and compares 5 different transfer learning approaches.

## Required Data Files

Place these files in `data_global/`:

1. **cores_with_bluecarbon_global_maps.csv** (9.1 MB)
   - Janousek global dataset with depth profiles AND GEE covariates
   - Contains: depth_top_cm, depth_bottom_cm, soc_g_kg, bd_g_cm3
   - Contains: topo_*, wc_*, gsw_*, sg_* covariates
   - Contains: sample_id, latitude, longitude

## Workflow Steps

### Step 1: Harmonize Global Dataset to VM0033 Depths

```bash
Rscript 03_depth_harmonization_bluecarbon.R
```

**What this does:**
- Loads `cores_with_bluecarbon_global_maps.csv`
- Extracts core metadata including ALL 14+ covariates
- Uses `sample_id` as `core_id`
- Harmonizes depth profiles to VM0033 depths (7.5, 22.5, 40, 75 cm) using equal-area splines
- Joins harmonized depths with covariates
- Saves `data_processed/global_cores_harmonized_VM0033.csv`

**Expected output:**
```
✓ Loaded XX rows from global dataset
✓ Harmonized XX global cores to VM0033 depths
✓ Retained XX columns (including covariates)
✓ Covariates: 14 columns preserved
  File: data_processed/global_cores_harmonized_VM0033.csv
```

**Verify covariates were preserved:**
```bash
head -n 1 data_processed/global_cores_harmonized_VM0033.csv | tr ',' '\n' | grep -E "^(topo_|wc_)"
```

You should see all 14 covariates:
- `topo_aspect_deg`, `topo_eastness`, `topo_elevation_m`, `topo_northness`
- `topo_slope_deg`, `topo_tidal_elevation_flag`
- `wc_MAP_mm`, `wc_MAT_C`, `wc_max_temp_warmest_C`, `wc_min_temp_coldest_C`
- `wc_precip_driest_month_mm`, `wc_precip_seasonality`
- `wc_precip_wettest_month_mm`, `wc_temp_seasonality`

### Step 2: Run Advanced Transfer Learning

```bash
Rscript 05c_transfer_learning_integration_IMPROVED.R
```

**What this does:**

1. **Loads Data**
   - Local harmonized cores
   - Global harmonized cores (with covariates)
   - Checks if covariates are present, merges if needed

2. **Prepares Predictors**
   - Identifies all covariate types (water, soil, topography, climate)
   - Filters predictors by data coverage (>50% non-NA)
   - Adds depth_cm_midpoint as key predictor

3. **Domain Analysis**
   - Calculates domain statistics (local vs global)
   - Quantifies covariate shift between domains

4. **Instance Weighting**
   - Computes Mahalanobis distance-based weights
   - Weights global samples by similarity to local domain

5. **Trains 5 Transfer Learning Approaches** (per depth):
   - **Local-only**: Baseline using only local data
   - **Global (naive)**: Train on global, test on local (no adaptation)
   - **Weighted Transfer**: Weight global samples by similarity
   - **Fine-tuned**: Pre-train on global, fine-tune on local
   - **Ensemble**: Combined model with domain indicator

6. **Model Comparison**
   - Compares all approaches by R² and RMSE
   - Selects best approach per depth
   - Saves best model

7. **Creates Visualizations**
   - Approach comparison plots
   - Feature importance by depth
   - Performance summaries

**Expected output:**
```
========== DEPTH: 7.5 cm ==========
Samples: XXX total (Local: 23, Global: XXX)

--- Approach 1: Local-Only Baseline ---
Local-only: R² = X.XX, RMSE = X.XX kg/m²

--- Approach 2: Global Model (Naive Transfer) ---
Global model on local test: R² = X.XX, RMSE = X.XX kg/m²

--- Approach 3: Instance-Weighted Transfer ---
Weighted transfer: R² = X.XX, RMSE = X.XX kg/m²

--- Approach 4: Two-Stage Fine-Tuning ---
Fine-tuned model: R² = X.XX, RMSE = X.XX kg/m²

--- Approach 5: Combined Ensemble ---
Ensemble model on local test: R² = X.XX, RMSE = X.XX kg/m²

--- COMPARISON ---
Best approach: Ensemble (R² = X.XX, RMSE = X.XX)
```

## Outputs

After running the workflow, you'll find:

### Models
`outputs/models/transfer_learning_v2/`
- `rf_depth_7.5_cm_best.rds`
- `rf_depth_22.5_cm_best.rds`
- `rf_depth_40_cm_best.rds`
- `rf_depth_75_cm_best.rds`

### Diagnostics
`diagnostics/transfer_learning_v2/`
- `final_summary.csv` - Overall performance summary
- `all_results.rds` - Complete results object
- `comparison_depth_*.csv` - Approach comparisons per depth
- `importance_depth_*.csv` - Feature importance per depth

### Plots
`diagnostics/transfer_learning_v2/plots/`
- `approach_comparison_r2.png` - R² comparison across depths
- `approach_comparison_rmse.png` - RMSE comparison across depths
- `importance_depth_*.png` - Feature importance plots per depth

## Transfer Learning Approaches Explained

### 1. Local-Only Baseline
- **Pros**: No domain shift, uses only local data
- **Cons**: Limited sample size (n=23 local cores)
- **When it's best**: When local domain is very different from global

### 2. Global Model (Naive Transfer)
- **Pros**: Large sample size (hundreds of global cores)
- **Cons**: May not generalize to local conditions
- **When it's best**: When local/global domains are similar

### 3. Instance-Weighted Transfer
- **Pros**: Adapts to local domain by weighting similar samples
- **Cons**: Requires sufficient local data to define target distribution
- **When it's best**: When there's moderate covariate shift

### 4. Two-Stage Fine-Tuning
- **Pros**: Pre-trains general patterns, fine-tunes to local specifics
- **Cons**: Requires enough local data for fine-tuning (n≥10)
- **When it's best**: When global and local share some patterns but differ in details

### 5. Combined Ensemble
- **Pros**: Leverages all data, learns domain-specific patterns
- **Cons**: May overfit if domains are very different
- **When it's best**: Often the most robust overall approach

## Troubleshooting

### Issue: "Global harmonized data missing covariates"

**Cause**: Module 03 didn't preserve covariates

**Solution**:
1. Check that `cores_with_bluecarbon_global_maps.csv` has covariate columns
2. Re-run Module 03
3. Verify output has covariates: `head -n 1 data_processed/global_cores_harmonized_VM0033.csv | tr ',' '\n' | grep topo_`

### Issue: "Global: 0" samples in output

**Cause**: Covariates not matching properly or filtering too strict

**Solution**:
1. Check that global harmonized data has covariates
2. Lower the coverage threshold in line 186: change `na_pct < 0.5` to `na_pct < 0.8`
3. Check that depth_cm_midpoint values match between local and global

### Issue: Poor transfer learning performance

**Possible causes**:
- Large covariate shift between domains
- Missing important covariates
- Different ecosystems (local mangrove vs global salt marsh)

**Solutions**:
1. Review covariate shift analysis in diagnostics
2. Use adaptive feature selection (in `advanced_transfer_learning_functions.R`)
3. Consider local-only or weighted transfer instead of naive transfer

## Advanced Techniques

The `advanced_transfer_learning_functions.R` file contains additional methods:

### Spatial Cross-Validation
```r
source("advanced_transfer_learning_functions.R")
cv_results <- spatial_cv_block(
  data = combined_data,
  predictors = good_predictors,
  response = "carbon_stock_kg_m2",
  n_folds = 5,
  block_size = 50  # km
)
```

### Quantile Regression Forests (Uncertainty)
```r
qrf_model <- train_qrf_model(
  data = training_data,
  predictors = good_predictors,
  response = "carbon_stock_kg_m2"
)
predictions_with_ci <- predict(qrf_model, newdata = test_data)
```

### Covariate Shift Analysis
```r
shift_analysis <- detect_covariate_shift(
  source_data = global_data,
  target_data = local_data,
  predictors = good_predictors
)
print(shift_analysis$plot)
```

### Adaptive Feature Selection
```r
best_features <- adaptive_feature_selection(
  source_data = global_data,
  target_data = local_data,
  predictors = all_predictors,
  response = "carbon_stock_kg_m2",
  top_n = 20
)
```

## Next Steps

1. **Review Results**: Examine the comparison plots and performance metrics
2. **Feature Importance**: Check which environmental variables are most important at each depth
3. **Spatial Predictions**: Use best models to make spatial predictions across your study area
4. **Uncertainty Quantification**: Apply QRF models for prediction intervals
5. **Validation**: Test predictions against independent validation cores if available

## References

- Janousek et al. 2025. Global blue carbon dataset (hypothetical reference)
- VM0033 Methodology for Tidal Wetland and Seagrass Restoration
- Bishop, C. M. (2006). Pattern Recognition and Machine Learning. Springer.
- Pan, S. J., & Yang, Q. (2010). A survey on transfer learning. IEEE TKDE, 22(10), 1345-1359.
