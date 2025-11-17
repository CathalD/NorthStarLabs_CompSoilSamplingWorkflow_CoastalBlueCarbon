# =============================================================================
# MODULE 02: VEGETATION CLASSIFICATION
# =============================================================================
#
# Purpose: Classify vegetation types from orthomosaic imagery using spectral
#          indices and machine learning (Random Forest or k-means clustering)
#
# Inputs:
#   - Orthomosaic (GeoTIFF) from Module 01
#   - Optional: Training samples (shapefile) for supervised classification
#
# Outputs:
#   - Classified raster with vegetation types
#   - Spectral index rasters (NDVI, ExG, VARI, GLI)
#   - Classification accuracy assessment (if training data provided)
#   - Variable importance plots
#
# Methods:
#   - Spectral indices: NDVI, ExG, VARI, GLI
#   - Supervised: Random Forest classification
#   - Unsupervised: k-means clustering
#
# Runtime: 5-30 minutes (depending on raster size and method)
#
# References:
#   - Tucker (1979). Red and photographic infrared linear combinations for
#     monitoring vegetation. Remote Sensing of Environment, 8(2), 127-150.
#   - Woebbecke et al. (1995). Color indices for weed identification under
#     various soil, residue, and lighting conditions. Transactions of the ASAE.
#   - Breiman (2001). Random forests. Machine Learning, 45(1), 5-32.
#
# =============================================================================

# Load required packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  terra,           # Raster processing
  sf,              # Vector data
  randomForest,    # Random forest classification
  caret,           # ML training framework
  dplyr,           # Data manipulation
  ggplot2,         # Visualization
  viridis,         # Color scales
  RColorBrewer,    # Color palettes
  progress         # Progress bars
)

# =============================================================================
# CONFIGURATION
# =============================================================================

# Source configuration file
if (!exists("PROJECT_NAME")) {
  if (file.exists("config/drone_config.R")) {
    source("config/drone_config.R")
  } else if (file.exists("../config/drone_config.R")) {
    source("../config/drone_config.R")
  } else {
    stop("Configuration file not found.")
  }
}

# =============================================================================
# SPECTRAL INDICES FUNCTIONS
# =============================================================================

#' Calculate NDVI (Normalized Difference Vegetation Index)
#'
#' NDVI = (NIR - Red) / (NIR + Red)
#' Note: For RGB-only imagery, we use a proxy with Green and Red bands
#'
#' @param red Red band raster
#' @param nir NIR band raster (or green for RGB-only)
#' @return NDVI raster
calculate_ndvi <- function(red, nir) {
  ndvi <- (nir - red) / (nir + red)
  return(ndvi)
}

#' Calculate ExG (Excess Green Index)
#'
#' ExG = 2 * Green - Red - Blue
#' Useful for identifying green vegetation
#'
#' @param red Red band raster
#' @param green Green band raster
#' @param blue Blue band raster
#' @return ExG raster
calculate_exg <- function(red, green, blue) {
  exg <- 2 * green - red - blue
  return(exg)
}

#' Calculate VARI (Visible Atmospherically Resistant Index)
#'
#' VARI = (Green - Red) / (Green + Red - Blue)
#'
#' @param red Red band raster
#' @param green Green band raster
#' @param blue Blue band raster
#' @return VARI raster
calculate_vari <- function(red, green, blue) {
  vari <- (green - red) / (green + red - blue + 0.00001)  # Add small value to avoid division by zero
  return(vari)
}

#' Calculate GLI (Green Leaf Index)
#'
#' GLI = (2 * Green - Red - Blue) / (2 * Green + Red + Blue)
#'
#' @param red Red band raster
#' @param green Green band raster
#' @param blue Blue band raster
#' @return GLI raster
calculate_gli <- function(red, green, blue) {
  gli <- (2 * green - red - blue) / (2 * green + red + blue + 0.00001)
  return(gli)
}

#' Calculate all spectral indices
#'
#' @param orthomosaic Path to orthomosaic or SpatRaster object
#' @param indices Vector of indices to calculate
#' @return SpatRaster stack with all indices
calculate_spectral_indices <- function(orthomosaic, indices = SPECTRAL_INDICES) {
  cat("📊 Calculating spectral indices...\n")

  # Load orthomosaic if path provided
  if (is.character(orthomosaic)) {
    ortho <- rast(orthomosaic)
  } else {
    ortho <- orthomosaic
  }

  # Check number of bands
  n_bands <- nlyr(ortho)
  cat("   Orthomosaic has", n_bands, "bands\n")

  # For RGB imagery, bands are typically: 1=Red, 2=Green, 3=Blue
  # Adjust indices if needed based on actual band order
  if (n_bands < 3) {
    stop("Orthomosaic must have at least 3 bands (RGB)")
  }

  # Extract bands (assuming RGB order)
  red <- ortho[[1]]
  green <- ortho[[2]]
  blue <- ortho[[3]]

  # For multispectral imagery with NIR
  if (n_bands >= 4) {
    nir <- ortho[[4]]
    has_nir <- TRUE
  } else {
    # Use green as proxy for NIR in RGB-only imagery
    nir <- green
    has_nir <- FALSE
    cat("   ⚠️  No NIR band detected. Using Green band as proxy for NDVI\n")
  }

  # Calculate requested indices
  index_list <- list()

  if ("NDVI" %in% indices) {
    cat("   Calculating NDVI...\n")
    index_list[["NDVI"]] <- calculate_ndvi(red, nir)
  }

  if ("ExG" %in% indices) {
    cat("   Calculating ExG...\n")
    index_list[["ExG"]] <- calculate_exg(red, green, blue)
  }

  if ("VARI" %in% indices) {
    cat("   Calculating VARI...\n")
    index_list[["VARI"]] <- calculate_vari(red, green, blue)
  }

  if ("GLI" %in% indices) {
    cat("   Calculating GLI...\n")
    index_list[["GLI"]] <- calculate_gli(red, green, blue)
  }

  # Stack all indices
  indices_stack <- rast(index_list)
  names(indices_stack) <- names(index_list)

  cat("   ✓", length(index_list), "spectral indices calculated\n")

  return(indices_stack)
}

# =============================================================================
# UNSUPERVISED CLASSIFICATION (K-MEANS)
# =============================================================================

#' Perform k-means clustering classification
#'
#' @param orthomosaic SpatRaster orthomosaic
#' @param indices_stack SpatRaster stack of spectral indices
#' @param n_classes Number of classes
#' @return List with classified raster and cluster statistics
classify_kmeans <- function(orthomosaic, indices_stack, n_classes = N_CLASSES_UNSUPERVISED) {
  cat("\n🎯 Performing k-means classification...\n")
  cat("   Number of classes:", n_classes, "\n")

  # Stack orthomosaic bands and indices
  all_bands <- c(orthomosaic, indices_stack)

  # Convert to matrix for k-means
  cat("   Preparing data...\n")
  values_matrix <- as.matrix(all_bands, wide = FALSE)

  # Remove NA values
  complete_cases <- complete.cases(values_matrix)
  values_clean <- values_matrix[complete_cases, ]

  cat("   Running k-means clustering...\n")
  set.seed(42)

  # Perform k-means
  kmeans_result <- kmeans(
    values_clean,
    centers = n_classes,
    iter.max = 100,
    nstart = 25
  )

  cat("   ✓ Clustering complete\n")

  # Create classification raster
  classification <- all_bands[[1]]
  classification[] <- NA
  classification[complete_cases] <- kmeans_result$cluster

  # Calculate cluster statistics
  cluster_stats <- data.frame(
    cluster = 1:n_classes,
    size = kmeans_result$size,
    percent = round(kmeans_result$size / sum(kmeans_result$size) * 100, 2)
  )

  # Add mean values for each band
  centers_df <- as.data.frame(kmeans_result$centers)
  cluster_stats <- cbind(cluster_stats, centers_df)

  cat("\n   Cluster statistics:\n")
  print(cluster_stats)

  return(list(
    classification = classification,
    clusters = kmeans_result,
    statistics = cluster_stats
  ))
}

# =============================================================================
# SUPERVISED CLASSIFICATION (RANDOM FOREST)
# =============================================================================

#' Extract training data from polygons
#'
#' @param orthomosaic SpatRaster orthomosaic
#' @param indices_stack SpatRaster stack of indices
#' @param training_polygons SF object with training polygons
#' @param class_column Name of column with class labels
#' @return Data frame with training data
extract_training_data <- function(orthomosaic, indices_stack, training_polygons, class_column = "class") {
  cat("📦 Extracting training data from polygons...\n")

  # Stack all bands
  all_bands <- c(orthomosaic, indices_stack)

  # Extract values
  training_values <- terra::extract(all_bands, vect(training_polygons), df = TRUE)

  # Add class labels
  # Match by polygon ID
  class_labels <- training_polygons[[class_column]][training_values$ID]
  training_data <- cbind(training_values[, -1], class = class_labels)

  # Remove NA values
  training_data <- na.omit(training_data)

  cat("   Extracted", nrow(training_data), "training pixels\n")
  cat("   Classes:", paste(unique(training_data$class), collapse = ", "), "\n")

  # Print class distribution
  class_counts <- table(training_data$class)
  print(class_counts)

  return(training_data)
}

#' Train Random Forest classifier
#'
#' @param training_data Data frame with training data
#' @param rf_params RF parameters from config
#' @return Trained Random Forest model
train_random_forest <- function(training_data, rf_params = RF_PARAMS) {
  cat("\n🌲 Training Random Forest classifier...\n")

  # Split into training and validation
  set.seed(42)
  train_idx <- createDataPartition(training_data$class, p = 1 - VALIDATION_SPLIT, list = FALSE)
  train_set <- training_data[train_idx, ]
  val_set <- training_data[-train_idx, ]

  cat("   Training samples:", nrow(train_set), "\n")
  cat("   Validation samples:", nrow(val_set), "\n")

  # Determine mtry if not specified
  if (is.null(rf_params$mtry)) {
    rf_params$mtry <- floor(sqrt(ncol(train_set) - 1))
  }

  # Train model
  cat("   Training model...\n")
  rf_model <- randomForest(
    class ~ .,
    data = train_set,
    ntree = rf_params$ntree,
    mtry = rf_params$mtry,
    importance = rf_params$importance,
    nodesize = rf_params$nodesize
  )

  cat("   ✓ Model trained\n")

  # Validate model
  cat("\n   Validating model...\n")
  val_pred <- predict(rf_model, val_set)
  conf_matrix <- confusionMatrix(val_pred, as.factor(val_set$class))

  cat("\n   Overall Accuracy:", round(conf_matrix$overall["Accuracy"], 3), "\n")
  cat("   Kappa:", round(conf_matrix$overall["Kappa"], 3), "\n\n")

  print(conf_matrix$table)

  # Variable importance
  if (rf_params$importance) {
    var_imp <- importance(rf_model)
    cat("\n   Top 5 important variables:\n")
    print(head(var_imp[order(var_imp[, "MeanDecreaseAccuracy"], decreasing = TRUE), ], 5))
  }

  return(list(
    model = rf_model,
    train_set = train_set,
    val_set = val_set,
    confusion_matrix = conf_matrix,
    variable_importance = if(rf_params$importance) var_imp else NULL
  ))
}

#' Apply Random Forest classification to raster
#'
#' @param rf_model Trained RF model
#' @param orthomosaic SpatRaster orthomosaic
#' @param indices_stack SpatRaster indices stack
#' @return Classified raster
apply_rf_classification <- function(rf_model, orthomosaic, indices_stack) {
  cat("\n🗺️  Applying classification to entire raster...\n")

  # Stack all bands
  all_bands <- c(orthomosaic, indices_stack)

  # Predict
  cat("   Predicting...\n")
  classification <- predict(all_bands, rf_model$model, na.rm = TRUE)

  cat("   ✓ Classification complete\n")

  return(classification)
}

# =============================================================================
# VISUALIZATION
# =============================================================================

#' Plot spectral indices
#'
#' @param indices_stack SpatRaster with spectral indices
#' @param output_path Path to save plot
plot_spectral_indices <- function(indices_stack, output_path = NULL) {
  cat("📊 Creating spectral indices visualization...\n")

  n_indices <- nlyr(indices_stack)

  if (!is.null(output_path)) {
    png(output_path, width = 12, height = 3 * ceiling(n_indices/2), units = "in", res = 300)
  }

  par(mfrow = c(ceiling(n_indices/2), 2))

  for (i in 1:n_indices) {
    index_name <- names(indices_stack)[i]
    plot(indices_stack[[i]],
         main = index_name,
         col = viridis(100),
         axes = FALSE)
  }

  if (!is.null(output_path)) {
    dev.off()
    cat("   ✓ Saved to:", output_path, "\n")
  }
}

#' Plot classification map
#'
#' @param classification Classified raster
#' @param class_names Vector of class names
#' @param output_path Path to save plot
plot_classification <- function(classification, class_names = NULL, output_path = NULL) {
  cat("🗺️  Creating classification map...\n")

  # Get unique classes
  unique_classes <- unique(values(classification, na.rm = TRUE))
  n_classes <- length(unique_classes)

  # Generate colors
  colors <- brewer.pal(min(n_classes, 9), "Set1")
  if (n_classes > 9) {
    colors <- rainbow(n_classes)
  }

  if (!is.null(output_path)) {
    png(output_path, width = 10, height = 8, units = "in", res = 300)
  }

  plot(classification,
       main = "Vegetation Classification",
       col = colors,
       axes = FALSE,
       legend = FALSE)

  # Add legend
  if (!is.null(class_names) && length(class_names) == n_classes) {
    legend("topright",
           legend = class_names,
           fill = colors,
           title = "Class",
           bg = "white")
  } else {
    legend("topright",
           legend = paste("Class", unique_classes),
           fill = colors,
           title = "Class",
           bg = "white")
  }

  if (!is.null(output_path)) {
    dev.off()
    cat("   ✓ Saved to:", output_path, "\n")
  }
}

# =============================================================================
# MAIN WORKFLOW
# =============================================================================

#' Run complete vegetation classification workflow
#'
#' @param orthomosaic_path Path to orthomosaic
#' @export
run_vegetation_classification <- function(orthomosaic_path = NULL) {
  cat("\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat(" MODULE 02: VEGETATION CLASSIFICATION\n")
  cat("═══════════════════════════════════════════════════════════════════════\n")
  cat("\n")

  # Find orthomosaic if not provided
  if (is.null(orthomosaic_path)) {
    ortho_files <- list.files(
      OUTPUT_DIRS$orthomosaics,
      pattern = "orthomosaic.*\\.tif$",
      full.names = TRUE,
      recursive = TRUE
    )

    if (length(ortho_files) == 0) {
      stop("No orthomosaic found. Please run Module 01 first.")
    }

    orthomosaic_path <- ortho_files[1]
  }

  cat("📂 Loading orthomosaic:", orthomosaic_path, "\n")
  orthomosaic <- rast(orthomosaic_path)

  # Calculate spectral indices
  indices_stack <- calculate_spectral_indices(orthomosaic, SPECTRAL_INDICES)

  # Save spectral indices
  indices_dir <- file.path(OUTPUT_DIRS$classifications, "spectral_indices")
  dir.create(indices_dir, recursive = TRUE, showWarnings = FALSE)

  for (i in 1:nlyr(indices_stack)) {
    index_name <- names(indices_stack)[i]
    output_path <- file.path(indices_dir, paste0(index_name, ".tif"))
    writeRaster(indices_stack[[i]], output_path, overwrite = TRUE)
    cat("   Saved:", output_path, "\n")
  }

  # Plot spectral indices
  plot_spectral_indices(
    indices_stack,
    file.path(OUTPUT_DIRS$classifications, "spectral_indices_plot.png")
  )

  # Classification
  if (CLASSIFICATION_METHOD == "supervised" && !is.null(TRAINING_SAMPLES)) {
    cat("\n🎯 Running SUPERVISED classification...\n")

    # Load training samples
    training_polygons <- st_read(TRAINING_SAMPLES, quiet = TRUE)

    # Extract training data
    training_data <- extract_training_data(orthomosaic, indices_stack, training_polygons)

    # Train Random Forest
    rf_results <- train_random_forest(training_data)

    # Apply classification
    classification <- apply_rf_classification(rf_results, orthomosaic, indices_stack)

    # Save variable importance plot
    if (!is.null(rf_results$variable_importance)) {
      png(file.path(OUTPUT_DIRS$classifications, "variable_importance.png"),
          width = 8, height = 6, units = "in", res = 300)
      varImpPlot(rf_results$model, main = "Variable Importance")
      dev.off()
    }

    class_names_used <- CLASS_NAMES

  } else {
    cat("\n🎯 Running UNSUPERVISED classification (k-means)...\n")

    # K-means classification
    kmeans_results <- classify_kmeans(orthomosaic, indices_stack, N_CLASSES_UNSUPERVISED)
    classification <- kmeans_results$classification

    # Save cluster statistics
    write.csv(
      kmeans_results$statistics,
      file.path(OUTPUT_DIRS$csv, "kmeans_cluster_statistics.csv"),
      row.names = FALSE
    )

    class_names_used <- paste("Cluster", 1:N_CLASSES_UNSUPERVISED)
  }

  # Save classification
  classification_path <- file.path(OUTPUT_DIRS$classifications, "vegetation_classification.tif")
  writeRaster(classification, classification_path, overwrite = TRUE)
  cat("\n💾 Saved classification:", classification_path, "\n")

  # Plot classification
  plot_classification(
    classification,
    class_names_used,
    file.path(OUTPUT_DIRS$classifications, "classification_map.png")
  )

  # Calculate area statistics
  class_areas <- freq(classification)
  pixel_area <- prod(res(classification))  # Area per pixel in map units^2
  class_areas$area_m2 <- class_areas$count * pixel_area
  class_areas$area_ha <- class_areas$area_m2 / 10000

  write.csv(
    class_areas,
    file.path(OUTPUT_DIRS$csv, "classification_area_statistics.csv"),
    row.names = FALSE
  )

  cat("\n📊 Classification area summary:\n")
  print(class_areas)

  cat("\n✅ Module 02 complete!\n")
  cat("\nNext step: Run Module 03 (Tree Detection)\n")
  cat("   source('R/03_tree_detection.R')\n\n")

  return(list(
    orthomosaic = orthomosaic,
    indices = indices_stack,
    classification = classification,
    area_stats = class_areas
  ))
}

# =============================================================================
# RUN MODULE (if sourced directly)
# =============================================================================

if (!interactive() || exists("RUN_MODULE_02")) {
  results <- run_vegetation_classification()
}
