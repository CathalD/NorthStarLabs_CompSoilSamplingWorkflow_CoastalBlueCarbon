# ============================================================================
# ADVANCED TRANSFER LEARNING TECHNIQUES - MODULAR FUNCTIONS
# ============================================================================
# Additional methods you can plug into the main transfer learning script
# ============================================================================

library(tidyverse)
library(ranger)
library(sf)

# ============================================================================
# 1. SPATIAL CROSS-VALIDATION
# ============================================================================

#' Spatial block cross-validation for blue carbon data
#' 
#' @param data Data frame with lat/lon and response variable
#' @param predictors Character vector of predictor names
#' @param response Character name of response variable
#' @param n_folds Number of spatial folds (default 5)
#' @param block_size Size of spatial blocks in km (default 50)
#' @return List with CV results and fold assignments
spatial_cv_block <- function(data, predictors, response, n_folds = 5, block_size = 50) {
  
  require(sf)
  
  # Convert to spatial object
  data_sf <- st_as_sf(data, coords = c("longitude", "latitude"), crs = 4326)
  
  # Project to equal-area (Mollweide for global data)
  data_sf <- st_transform(data_sf, crs = "+proj=moll +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m")
  
  # Create spatial grid
  bbox <- st_bbox(data_sf)
  grid <- st_make_grid(data_sf, 
                       cellsize = block_size * 1000,  # Convert km to m
                       what = "polygons")
  
  # Assign each point to a grid cell
  grid_ids <- st_intersects(data_sf, grid)
  data$grid_id <- sapply(grid_ids, function(x) ifelse(length(x) > 0, x[1], NA))
  
  # Randomly assign grid cells to folds
  unique_grids <- unique(data$grid_id[!is.na(data$grid_id)])
  fold_assignments <- sample(rep(1:n_folds, length.out = length(unique_grids)))
  names(fold_assignments) <- unique_grids
  
  data$fold <- fold_assignments[as.character(data$grid_id)]
  
  # Run cross-validation
  cv_results <- vector("list", n_folds)
  
  for (fold in 1:n_folds) {
    
    train_data <- data %>% filter(fold != !!fold)
    test_data <- data %>% filter(fold == !!fold)
    
    # Build formula
    formula_rf <- as.formula(paste(response, "~", paste(predictors, collapse = " + ")))
    
    # Train model
    model <- ranger(
      formula_rf,
      data = train_data,
      num.trees = 500,
      importance = "permutation",
      seed = 42
    )
    
    # Predict
    predictions <- predict(model, test_data)$predictions
    
    # Calculate metrics
    cv_results[[fold]] <- tibble(
      fold = fold,
      n_train = nrow(train_data),
      n_test = nrow(test_data),
      rmse = sqrt(mean((test_data[[response]] - predictions)^2)),
      mae = mean(abs(test_data[[response]] - predictions)),
      r2 = 1 - sum((test_data[[response]] - predictions)^2) / 
               sum((test_data[[response]] - mean(train_data[[response]]))^2),
      predictions = list(predictions),
      actual = list(test_data[[response]])
    )
  }
  
  cv_summary <- bind_rows(cv_results)
  
  cat("\n=== Spatial Cross-Validation Results ===\n")
  cat(sprintf("Mean RMSE: %.2f ± %.2f\n", mean(cv_summary$rmse), sd(cv_summary$rmse)))
  cat(sprintf("Mean R²: %.3f ± %.3f\n", mean(cv_summary$r2), sd(cv_summary$r2)))
  
  return(list(
    results = cv_summary,
    fold_assignments = data %>% select(any_of(c("core_id", "fold", "grid_id")))
  ))
}

# ============================================================================
# 2. QUANTILE REGRESSION FORESTS (for uncertainty)
# ============================================================================

#' Train QRF model for prediction intervals
#' 
#' @param data Training data
#' @param predictors Predictor names
#' @param response Response variable name
#' @param quantiles Quantiles to predict (default c(0.025, 0.5, 0.975) for 95% CI)
#' @return Model object with predict method
train_qrf_model <- function(data, predictors, response, 
                            quantiles = c(0.025, 0.5, 0.975)) {
  
  require(quantregForest)
  
  # Prepare data
  X <- as.matrix(data[, predictors])
  y <- data[[response]]
  
  # Train QRF
  cat("Training Quantile Regression Forest...\n")
  qrf_model <- quantregForest(
    x = X,
    y = y,
    ntree = 500,
    nodesize = 5
  )
  
  # Return model with metadata
  structure(
    list(
      model = qrf_model,
      predictors = predictors,
      response = response,
      quantiles = quantiles,
      training_n = length(y)
    ),
    class = "qrf_blue_carbon"
  )
}

#' Predict with uncertainty intervals
predict.qrf_blue_carbon <- function(object, newdata, quantiles = NULL) {
  
  if (is.null(quantiles)) quantiles <- object$quantiles
  
  X_new <- as.matrix(newdata[, object$predictors])
  
  predictions <- predict(object$model, X_new, what = quantiles)
  
  # Create output dataframe
  result <- as.data.frame(predictions)
  names(result) <- paste0("q", quantiles * 100)
  
  # Add point prediction (median) and prediction interval width
  result$prediction <- result[[paste0("q", 50)]]
  if ("q2.5" %in% names(result) && "q97.5" %in% names(result)) {
    result$pi_width <- result$q97.5 - result$q2.5
  }
  
  return(result)
}

# ============================================================================
# 3. MULTI-TASK LEARNING (predict multiple depths simultaneously)
# ============================================================================

#' Train multi-task model for all depths
#' 
#' @param data Long-format data with depth_cm and carbon_stock columns
#' @param predictors Predictor names
#' @param depths Target depths to model
#' @return List of linked models
train_multitask_model <- function(data, predictors, depths = c(7.5, 22.5, 40, 75)) {
  
  # Reshape to wide format (one row per core, columns for each depth)
  data_wide <- data %>%
    filter(depth_cm_midpoint %in% depths) %>%
    select(core_id, depth_cm_midpoint, carbon_stock_kg_m2, all_of(predictors)) %>%
    pivot_wider(
      names_from = depth_cm_midpoint,
      values_from = carbon_stock_kg_m2,
      names_prefix = "carbon_"
    )
  
  # Get predictor values (should be same for all depths from same core)
  predictor_data <- data_wide %>%
    group_by(core_id) %>%
    summarise(across(all_of(predictors), ~first(na.omit(.))), .groups = 'drop')
  
  # Merge back
  data_wide <- data_wide %>%
    select(core_id, starts_with("carbon_")) %>%
    distinct() %>%
    left_join(predictor_data, by = "core_id")
  
  # Train separate models but with shared feature importance
  models <- list()
  shared_importance <- NULL
  
  for (depth in depths) {
    
    carbon_col <- paste0("carbon_", depth)
    
    if (!carbon_col %in% names(data_wide)) next
    
    # Filter complete cases
    model_data <- data_wide %>%
      select(all_of(c(carbon_col, predictors))) %>%
      drop_na()
    
    if (nrow(model_data) < 20) next
    
    # Train model
    formula_rf <- as.formula(paste(carbon_col, "~", paste(predictors, collapse = " + ")))
    
    model <- ranger(
      formula_rf,
      data = model_data,
      num.trees = 500,
      importance = "permutation",
      seed = 42
    )
    
    models[[as.character(depth)]] <- model
    
    # Accumulate importance across depths
    if (is.null(shared_importance)) {
      shared_importance <- model$variable.importance
    } else {
      shared_importance <- shared_importance + model$variable.importance
    }
  }
  
  # Average importance
  shared_importance <- shared_importance / length(models)
  
  # Re-rank predictors by shared importance
  predictor_ranks <- sort(shared_importance, decreasing = TRUE)
  
  cat("\n=== Multi-Task Model Summary ===\n")
  cat(sprintf("Trained models for %d depths\n", length(models)))
  cat("\nTop 10 predictors across all depths:\n")
  print(head(predictor_ranks, 10))
  
  return(list(
    models = models,
    shared_importance = shared_importance,
    predictor_ranks = predictor_ranks
  ))
}

# ============================================================================
# 4. COVARIATE SHIFT DETECTION
# ============================================================================

#' Detect and quantify covariate shift between domains
#' 
#' @param source_data Data from source domain (global)
#' @param target_data Data from target domain (local)
#' @param predictors Predictor names to compare
#' @return List with shift metrics and visualization
detect_covariate_shift <- function(source_data, target_data, predictors) {
  
  # Calculate summary statistics for each predictor
  shift_metrics <- map_df(predictors, function(pred) {
    
    source_vals <- source_data[[pred]][!is.na(source_data[[pred]])]
    target_vals <- target_data[[pred]][!is.na(target_data[[pred]])]
    
    if (length(source_vals) < 10 || length(target_vals) < 10) {
      return(NULL)
    }
    
    # Kolmogorov-Smirnov test
    ks_test <- ks.test(source_vals, target_vals)
    
    # Effect size (standardized mean difference)
    cohens_d <- (mean(target_vals) - mean(source_vals)) / 
                sqrt((sd(source_vals)^2 + sd(target_vals)^2) / 2)
    
    tibble(
      predictor = pred,
      source_mean = mean(source_vals),
      target_mean = mean(target_vals),
      source_sd = sd(source_vals),
      target_sd = sd(target_vals),
      mean_diff = mean(target_vals) - mean(source_vals),
      cohens_d = cohens_d,
      ks_statistic = ks_test$statistic,
      ks_pvalue = ks_test$p.value,
      shift_magnitude = abs(cohens_d)
    )
  })
  
  # Sort by shift magnitude
  shift_metrics <- shift_metrics %>%
    arrange(desc(shift_magnitude))
  
  # Classify shift severity
  shift_metrics <- shift_metrics %>%
    mutate(
      shift_severity = case_when(
        shift_magnitude < 0.2 ~ "Negligible",
        shift_magnitude < 0.5 ~ "Small",
        shift_magnitude < 0.8 ~ "Medium",
        TRUE ~ "Large"
      )
    )
  
  # Create visualization
  p <- ggplot(shift_metrics, aes(x = reorder(predictor, shift_magnitude), 
                                  y = shift_magnitude, 
                                  fill = shift_severity)) +
    geom_col() +
    coord_flip() +
    theme_minimal() +
    labs(
      title = "Covariate Shift Analysis",
      subtitle = "Difference between source (global) and target (local) domains",
      x = "Predictor",
      y = "Cohen's d (effect size)",
      fill = "Shift Severity"
    ) +
    scale_fill_manual(values = c(
      "Negligible" = "lightgreen",
      "Small" = "yellow",
      "Medium" = "orange",
      "Large" = "red"
    ))
  
  cat("\n=== Covariate Shift Summary ===\n")
  cat(sprintf("Predictors with large shift (|d| > 0.8): %d\n",
              sum(shift_metrics$shift_severity == "Large")))
  cat(sprintf("Predictors with medium shift (0.5 < |d| < 0.8): %d\n",
              sum(shift_metrics$shift_severity == "Medium")))
  cat("\nTop 5 shifted predictors:\n")
  print(shift_metrics %>% select(predictor, cohens_d, shift_severity) %>% head(5))
  
  return(list(
    metrics = shift_metrics,
    plot = p,
    summary = list(
      n_large_shift = sum(shift_metrics$shift_severity == "Large"),
      n_medium_shift = sum(shift_metrics$shift_severity == "Medium"),
      mean_shift = mean(shift_metrics$shift_magnitude)
    )
  ))
}

# ============================================================================
# 5. ADAPTIVE FEATURE SELECTION
# ============================================================================

#' Select features that transfer well across domains
#' 
#' @param source_data Source domain data
#' @param target_data Target domain data  
#' @param predictors Candidate predictors
#' @param response Response variable name
#' @param top_n Number of features to select
#' @return Selected feature names
adaptive_feature_selection <- function(source_data, target_data, predictors, 
                                      response, top_n = 20) {
  
  # Train models on source domain
  source_importance <- map_df(1:10, function(i) {
    
    # Bootstrap sample
    sample_idx <- sample(1:nrow(source_data), replace = TRUE)
    sample_data <- source_data[sample_idx, ]
    
    formula_rf <- as.formula(paste(response, "~", paste(predictors, collapse = " + ")))
    
    model <- ranger(
      formula_rf,
      data = sample_data,
      num.trees = 100,
      importance = "permutation",
      seed = i
    )
    
    tibble(
      predictor = names(model$variable.importance),
      importance = model$variable.importance,
      iteration = i
    )
  })
  
  # Average importance
  source_avg <- source_importance %>%
    group_by(predictor) %>%
    summarise(
      source_importance = mean(importance),
      source_sd = sd(importance),
      .groups = 'drop'
    )
  
  # Train on target domain (if enough data)
  if (nrow(target_data) >= 30) {
    
    target_importance <- map_df(1:10, function(i) {
      
      sample_idx <- sample(1:nrow(target_data), replace = TRUE)
      sample_data <- target_data[sample_idx, ]
      
      formula_rf <- as.formula(paste(response, "~", paste(predictors, collapse = " + ")))
      
      model <- ranger(
        formula_rf,
        data = sample_data,
        num.trees = 100,
        importance = "permutation",
        seed = i
      )
      
      tibble(
        predictor = names(model$variable.importance),
        importance = model$variable.importance,
        iteration = i
      )
    })
    
    target_avg <- target_importance %>%
      group_by(predictor) %>%
      summarise(
        target_importance = mean(importance),
        target_sd = sd(importance),
        .groups = 'drop'
      )
    
    # Combine and calculate transferability score
    feature_scores <- source_avg %>%
      left_join(target_avg, by = "predictor") %>%
      mutate(
        # High score if important in both domains
        transfer_score = sqrt(source_importance * target_importance),
        # Penalize if very different importance between domains
        consistency = 1 - abs(source_importance - target_importance) / 
                          (source_importance + target_importance + 1e-6)
      ) %>%
      mutate(
        final_score = transfer_score * consistency
      ) %>%
      arrange(desc(final_score))
    
  } else {
    # Not enough target data, just use source importance
    feature_scores <- source_avg %>%
      mutate(final_score = source_importance) %>%
      arrange(desc(final_score))
  }
  
  # Select top features
  selected_features <- feature_scores$predictor[1:min(top_n, nrow(feature_scores))]
  
  cat("\n=== Adaptive Feature Selection ===\n")
  cat(sprintf("Selected %d features that transfer well\n", length(selected_features)))
  cat("\nTop 10 features:\n")
  print(head(feature_scores, 10))
  
  return(list(
    selected_features = selected_features,
    feature_scores = feature_scores
  ))
}

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

# # Assuming you have loaded your data:
# 
# # 1. Spatial CV
# cv_results <- spatial_cv_block(
#   data = combined_data,
#   predictors = good_predictors,
#   response = "carbon_stock_kg_m2",
#   n_folds = 5,
#   block_size = 50
# )
# 
# # 2. Quantile RF for uncertainty
# qrf_model <- train_qrf_model(
#   data = training_data,
#   predictors = good_predictors,
#   response = "carbon_stock_kg_m2"
# )
# 
# # Predict with 95% prediction intervals
# predictions <- predict(qrf_model, newdata = test_data)
# 
# # 3. Multi-task learning
# mtl_models <- train_multitask_model(
#   data = combined_data,
#   predictors = good_predictors,
#   depths = c(7.5, 22.5, 40, 75)
# )
# 
# # 4. Detect covariate shift
# shift_analysis <- detect_covariate_shift(
#   source_data = global_data,
#   target_data = local_data,
#   predictors = good_predictors
# )
# 
# # View shift plot
# print(shift_analysis$plot)
# 
# # 5. Adaptive feature selection
# best_features <- adaptive_feature_selection(
#   source_data = global_data,
#   target_data = local_data,
#   predictors = all_predictors,
#   response = "carbon_stock_kg_m2",
#   top_n = 20
# )
