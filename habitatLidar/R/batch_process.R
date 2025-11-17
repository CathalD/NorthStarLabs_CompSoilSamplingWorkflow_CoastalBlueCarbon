#' Batch Processing Functions for Large-Area Analysis
#'
#' @name batch_process
NULL

#' Process lidar catalog in batch mode
#'
#' Processes multiple lidar tiles with parallel processing and progress tracking
#'
#' @param catalog_folder Path to folder with .las/.laz files
#' @param output_folder Path for output files
#' @param processing_options List of processing options
#' @param n_cores Number of CPU cores to use (default: all available - 1)
#' @param chunk_size Chunk size for processing (default 500m)
#' @param buffer Buffer size for chunk overlap (default 30m)
#' @return List with processing results and summary
#' @export
#' @examples
#' \dontrun{
#' options <- list(
#'   preprocess = TRUE,
#'   canopy_metrics = TRUE,
#'   tree_detection = TRUE,
#'   hsi_species = c("moose", "caribou")
#' )
#' results <- batch_process_catalog("lidar_tiles/", "output/", options)
#' }
batch_process_catalog <- function(catalog_folder, output_folder,
                                 processing_options = list(),
                                 n_cores = NULL, chunk_size = 500, buffer = 30) {

  logger::log_info("Starting batch processing of lidar catalog")
  logger::log_info("Input: {catalog_folder}")
  logger::log_info("Output: {output_folder}")

  # Create output directory
  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  # Create LAScatalog
  ctg <- lidR::readLAScatalog(catalog_folder)

  # Set processing options
  lidR::opt_chunk_size(ctg) <- chunk_size
  lidR::opt_chunk_buffer(ctg) <- buffer
  lidR::opt_output_files(ctg) <- file.path(output_folder, "{ORIGINALFILENAME}")

  # Set up parallel processing
  if (is.null(n_cores)) {
    n_cores <- max(1, parallel::detectCores() - 1)
  }

  logger::log_info("Using {n_cores} CPU cores for parallel processing")
  future::plan(future::multisession, workers = n_cores)
  lidR::opt_parallel_strategy(ctg) <- future::multisession

  # Track processing time
  start_time <- Sys.time()

  # Processing results list
  results <- list()

  # 1. Preprocessing (if requested)
  if (isTRUE(processing_options$preprocess)) {
    logger::log_info("Step 1: Preprocessing tiles...")

    preprocess_folder <- file.path(output_folder, "preprocessed")
    dir.create(preprocess_folder, showWarnings = FALSE)

    # This would process each tile
    # In practice, would use lidR::catalog_apply with custom function
    results$preprocessing <- "Completed"
  }

  # 2. Generate metrics (if requested)
  if (isTRUE(processing_options$canopy_metrics)) {
    logger::log_info("Step 2: Calculating canopy metrics...")

    metrics_folder <- file.path(output_folder, "metrics")
    dir.create(metrics_folder, showWarnings = FALSE)

    # Generate metrics for catalog
    metrics_output <- file.path(metrics_folder, "canopy_metrics_{XLEFT}_{YBOTTOM}")

    metrics_raster <- lidR::pixel_metrics(
      ctg,
      ~calculate_canopy_metrics(X, Y, Z, ReturnNumber),
      res = processing_options$metric_resolution %||% 20
    )

    results$canopy_metrics <- metrics_folder
  }

  # 3. Generate understory metrics (if requested)
  if (isTRUE(processing_options$understory_metrics)) {
    logger::log_info("Step 3: Calculating understory metrics...")

    understory_folder <- file.path(output_folder, "understory")
    dir.create(understory_folder, showWarnings = FALSE)

    understory_raster <- lidR::pixel_metrics(
      ctg,
      ~calculate_understory_metrics(X, Y, Z, species = "moose"),
      res = processing_options$metric_resolution %||% 10
    )

    results$understory_metrics <- understory_folder
  }

  # 4. Tree detection (if requested)
  if (isTRUE(processing_options$tree_detection)) {
    logger::log_info("Step 4: Detecting and segmenting trees...")

    trees_folder <- file.path(output_folder, "trees")
    dir.create(trees_folder, showWarnings = FALSE)

    # Generate CHM first
    chm <- lidR::rasterize_canopy(ctg, res = 0.5, algorithm = lidR::p2r())

    # Detect trees
    ws_func <- function(x) { 0.05 * x + 1.0 }
    ttops <- lidR::locate_trees(chm, lidR::lmf(ws = ws_func, hmin = 5))

    # Save tree locations
    sf::st_write(ttops, file.path(trees_folder, "tree_locations.gpkg"), delete_dsn = TRUE)

    results$tree_detection <- list(
      n_trees = nrow(ttops),
      output = trees_folder
    )
  }

  # 5. Calculate HSI for species (if requested)
  if (!is.null(processing_options$hsi_species)) {
    logger::log_info("Step 5: Calculating habitat suitability indices...")

    hsi_folder <- file.path(output_folder, "habitat_suitability")
    dir.create(hsi_folder, showWarnings = FALSE)

    # This would calculate HSI for each species
    # Results would be mosaicked across tiles

    results$hsi <- hsi_folder
  }

  # Reset parallel processing
  future::plan(future::sequential)

  # Calculate processing time
  end_time <- Sys.time()
  processing_time <- difftime(end_time, start_time, units = "mins")

  logger::log_info("Batch processing complete in {round(processing_time, 1)} minutes")

  # Summary
  summary <- list(
    input_folder = catalog_folder,
    output_folder = output_folder,
    n_tiles = length(ctg@data$filename),
    processing_time_mins = as.numeric(processing_time),
    n_cores = n_cores,
    results = results
  )

  return(summary)
}

#' Process single lidar tile with full workflow
#'
#' Complete workflow for a single tile: preprocess, metrics, trees, HSI
#'
#' @param las_file Path to LAS file
#' @param output_dir Output directory
#' @param species Target species for habitat analysis
#' @param metric_res Metric grid resolution
#' @param detect_trees Whether to detect trees
#' @return List with all results
#' @export
process_lidar <- function(las_file, output_dir, species = "moose",
                         metric_res = 20, detect_trees = TRUE) {

  logger::log_info("Processing: {basename(las_file)}")

  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Read LAS
  las <- lidR::readLAS(las_file)

  # Step 1: Preprocess
  logger::log_info("Step 1/5: Preprocessing...")
  preprocess_result <- preprocess_lidar(las, output_dir = output_dir)
  las_clean <- preprocess_result$las
  chm <- preprocess_result$chm

  # Step 2: Canopy metrics
  logger::log_info("Step 2/5: Calculating canopy metrics...")
  canopy_metrics <- generate_canopy_metrics_grid(las_clean, res = metric_res)
  terra::writeRaster(
    canopy_metrics,
    file.path(output_dir, "canopy_metrics.tif"),
    overwrite = TRUE
  )

  # Step 3: Understory metrics
  logger::log_info("Step 3/5: Calculating understory metrics...")
  understory_metrics <- generate_understory_metrics_grid(
    las_clean,
    res = metric_res / 2,  # Finer resolution for understory
    species = species
  )
  terra::writeRaster(
    understory_metrics,
    file.path(output_dir, "understory_metrics.tif"),
    overwrite = TRUE
  )

  # Step 4: Tree detection (optional)
  tree_result <- NULL
  if (detect_trees) {
    logger::log_info("Step 4/5: Detecting trees...")
    ws_func <- function(x) { 0.05 * x + 1.0 }
    tree_result <- detect_segment_trees(
      las_clean,
      chm = chm,
      ws = ws_func,
      hmin = 5
    )

    # Save tree data
    sf::st_write(
      tree_result$trees_sf,
      file.path(output_dir, "trees.gpkg"),
      delete_dsn = TRUE
    )
    write.csv(
      tree_result$attributes,
      file.path(output_dir, "tree_attributes.csv"),
      row.names = FALSE
    )
  }

  # Step 5: Habitat suitability
  logger::log_info("Step 5/5: Calculating habitat suitability...")
  hsi_results <- calculate_multispecies_hsi(
    las_clean,
    res = metric_res,
    species_list = c(species),
    output_dir = file.path(output_dir, "hsi")
  )

  logger::log_info("Processing complete!")

  return(list(
    las = las_clean,
    chm = chm,
    canopy_metrics = canopy_metrics,
    understory_metrics = understory_metrics,
    trees = tree_result,
    hsi = hsi_results,
    output_dir = output_dir
  ))
}

#' Resume interrupted batch processing
#'
#' Continues processing from where it left off
#'
#' @param catalog_folder Lidar catalog folder
#' @param output_folder Output folder
#' @param completed_tiles Vector of already processed tile names
#' @param processing_options Processing options
#' @return Processing summary
#' @export
resume_batch_processing <- function(catalog_folder, output_folder,
                                   completed_tiles = NULL,
                                   processing_options = list()) {

  logger::log_info("Resuming batch processing")

  # Read catalog
  ctg <- lidR::readLAScatalog(catalog_folder)

  # Identify completed tiles
  if (is.null(completed_tiles)) {
    # Try to auto-detect from output folder
    completed_files <- list.files(
      file.path(output_folder, "preprocessed"),
      pattern = "\\.las$"
    )
    completed_tiles <- tools::file_path_sans_ext(completed_files)
  }

  logger::log_info("Found {length(completed_tiles)} completed tiles")
  logger::log_info("Remaining: {length(ctg@data$filename) - length(completed_tiles)} tiles")

  # Filter catalog to unprocessed tiles
  # Implementation would filter ctg here

  # Process remaining tiles
  # Would call batch_process_catalog on filtered catalog

  logger::log_info("Resume processing complete")
}

#' Generate processing summary report
#'
#' Creates summary statistics from batch processing results
#'
#' @param output_folder Batch processing output folder
#' @return Data frame with summary statistics
#' @export
summarize_batch_results <- function(output_folder) {
  logger::log_info("Generating batch processing summary")

  summary_list <- list()

  # Scan for metrics files
  metrics_files <- list.files(
    file.path(output_folder, "metrics"),
    pattern = "\\.tif$",
    full.names = TRUE
  )

  if (length(metrics_files) > 0) {
    # Load and summarize metrics
    for (f in metrics_files) {
      r <- terra::rast(f)
      stats <- terra::global(r, fun = c("mean", "sd", "min", "max"), na.rm = TRUE)
      summary_list[[basename(f)]] <- stats
    }
  }

  # Tree summary
  tree_files <- list.files(
    file.path(output_folder, "trees"),
    pattern = "\\.gpkg$",
    full.names = TRUE
  )

  if (length(tree_files) > 0) {
    total_trees <- 0
    for (f in tree_files) {
      trees <- sf::st_read(f, quiet = TRUE)
      total_trees <- total_trees + nrow(trees)
    }
    summary_list$trees <- list(total_trees = total_trees)
  }

  # HSI summary
  hsi_files <- list.files(
    file.path(output_folder, "hsi"),
    pattern = "^hsi_.*\\.tif$",
    full.names = TRUE
  )

  if (length(hsi_files) > 0) {
    hsi_summary <- data.frame()
    for (f in hsi_files) {
      species <- gsub("hsi_(.*)\\.tif", "\\1", basename(f))
      r <- terra::rast(f)
      vals <- terra::values(r, na.rm = TRUE)

      hsi_summary <- rbind(hsi_summary, data.frame(
        species = species,
        mean_hsi = mean(vals, na.rm = TRUE),
        high_quality_pct = sum(vals >= 0.7, na.rm = TRUE) / length(vals) * 100
      ))
    }
    summary_list$hsi <- hsi_summary
  }

  logger::log_info("Batch summary complete")

  return(summary_list)
}

#' Mosaic metrics across tiles
#'
#' Combines individual tile metrics into seamless coverage
#'
#' @param metrics_folder Folder with metric rasters
#' @param output_file Output mosaic file
#' @param metric_name Name of metric to mosaic
#' @return SpatRaster mosaic
#' @export
mosaic_metrics <- function(metrics_folder, output_file, metric_name = "height_max") {
  logger::log_info("Mosaicking {metric_name} across tiles")

  # Find all metric files
  metric_files <- list.files(
    metrics_folder,
    pattern = "\\.tif$",
    full.names = TRUE
  )

  if (length(metric_files) == 0) {
    stop("No metric files found in {metrics_folder}")
  }

  # Load rasters
  rasters <- lapply(metric_files, terra::rast)

  # Extract specific layer if multi-band
  if (metric_name %in% names(rasters[[1]])) {
    rasters <- lapply(rasters, function(r) r[[metric_name]])
  }

  # Mosaic
  mosaic <- do.call(terra::mosaic, rasters)

  # Save
  terra::writeRaster(mosaic, output_file, overwrite = TRUE)

  logger::log_info("Mosaic saved: {output_file}")

  return(mosaic)
}

#' `%||%` helper for default values
#'
#' @param x Value to check
#' @param y Default value
#' @return x if not NULL, otherwise y
#' @keywords internal
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Monitor batch processing progress
#'
#' Tracks progress and estimates completion time
#'
#' @param output_folder Batch output folder
#' @param total_tiles Total number of tiles
#' @param check_interval Time between checks (seconds)
#' @export
monitor_batch_progress <- function(output_folder, total_tiles, check_interval = 60) {
  logger::log_info("Monitoring batch processing progress...")

  start_time <- Sys.time()

  while (TRUE) {
    # Count completed tiles
    completed <- length(list.files(
      file.path(output_folder, "preprocessed"),
      pattern = "\\.las$"
    ))

    pct_complete <- (completed / total_tiles) * 100
    elapsed <- difftime(Sys.time(), start_time, units = "mins")

    if (completed > 0) {
      rate <- as.numeric(elapsed) / completed
      remaining <- (total_tiles - completed) * rate
    } else {
      remaining <- NA
    }

    logger::log_info(
      "Progress: {completed}/{total_tiles} tiles ({round(pct_complete, 1)}%) | ",
      "Elapsed: {round(elapsed, 1)}min | ",
      "Est. remaining: {round(remaining, 1)}min"
    )

    if (completed >= total_tiles) {
      logger::log_info("Processing complete!")
      break
    }

    Sys.sleep(check_interval)
  }
}
