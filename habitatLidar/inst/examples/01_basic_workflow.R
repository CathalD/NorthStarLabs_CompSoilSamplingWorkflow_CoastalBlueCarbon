#' Basic Habitat Assessment Workflow
#'
#' This script demonstrates the basic workflow for analyzing a single lidar tile
#' and generating a habitat assessment for moose.
#'
#' Time required: ~5-10 minutes
#' Skill level: Beginner

# Load packages ----------------------------------------------------------------
library(habitatLidar)
library(lidR)
library(terra)
library(sf)
library(ggplot2)

# Setup ------------------------------------------------------------------------

# Define paths
output_dir <- "tutorial_output/basic_workflow"

# Create output directory
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Set target species
target_species <- "moose"

# Step 1: Load Data ------------------------------------------------------------

message("Step 1: Loading test data...")

# Load test lidar tile
las_file <- system.file("extdata/test_tile.las", package = "habitatLidar")

if (!file.exists(las_file)) {
  stop("Test data not found. Please run: source('data-raw/create_test_data.R')")
}

las <- readLAS(las_file)

message(sprintf("  ✓ Loaded %s points", format(nrow(las@data), big.mark = ",")))

# Step 2: Quality Control ------------------------------------------------------

message("\nStep 2: Quality control assessment...")

qc_report <- quality_control_report(las, return_report = FALSE)

# Step 3: Preprocess -----------------------------------------------------------

message("\nStep 3: Preprocessing (ground classification & normalization)...")

preprocessed <- preprocess_lidar(
  las,
  ground_method = "csf",
  noise_method = "sor",
  output_dir = file.path(output_dir, "preprocessed")
)

las_clean <- preprocessed$las
chm <- preprocessed$chm
dtm <- preprocessed$dtm

message("  ✓ Preprocessing complete")

# Save CHM visualization
png(file.path(output_dir, "01_canopy_height_model.png"),
    width = 1200, height = 800, res = 150)
plot(chm, main = "Canopy Height Model (CHM)", col = viridis::viridis(100))
dev.off()

# Step 4: Calculate Metrics ----------------------------------------------------

message("\nStep 4: Calculating vegetation metrics...")

# Canopy metrics (20m resolution)
canopy_metrics <- generate_canopy_metrics_grid(las_clean, res = 20)
message("  ✓ Canopy metrics calculated")

# Understory metrics (10m resolution)
understory_metrics <- generate_understory_metrics_grid(
  las_clean,
  res = 10,
  species = target_species
)
message("  ✓ Understory metrics calculated")

# Save metrics
writeRaster(canopy_metrics,
            file.path(output_dir, "canopy_metrics.tif"),
            overwrite = TRUE)
writeRaster(understory_metrics,
            file.path(output_dir, "understory_metrics.tif"),
            overwrite = TRUE)

# Visualize key metrics
png(file.path(output_dir, "02_browse_density.png"),
    width = 1200, height = 800, res = 150)
plot(understory_metrics$browse_density_pct,
     main = "Moose Browse Density (%)",
     col = viridis::viridis(100))
dev.off()

# Step 5: Tree Detection -------------------------------------------------------

message("\nStep 5: Detecting individual trees...")

# Variable window for tree detection
ws_func <- function(x) { 0.05 * x + 1.0 }

tree_results <- detect_segment_trees(
  las_clean,
  chm = chm,
  method = "watershed",
  ws = ws_func,
  hmin = 5,
  region = "boreal"
)

message(sprintf("  ✓ Detected %d trees", nrow(tree_results$attributes)))

# Save tree data
st_write(tree_results$trees_sf,
         file.path(output_dir, "trees.gpkg"),
         delete_dsn = TRUE,
         quiet = TRUE)

write.csv(tree_results$attributes,
          file.path(output_dir, "tree_inventory.csv"),
          row.names = FALSE)

# Visualize trees
png(file.path(output_dir, "03_detected_trees.png"),
    width = 1200, height = 800, res = 150)
plot(chm, main = "Detected Trees", col = terrain.colors(50))
plot(st_geometry(tree_results$trees_sf), add = TRUE, pch = 3, col = "red", cex = 0.5)
dev.off()

# Tree size distribution
png(file.path(output_dir, "04_tree_distribution.png"),
    width = 1000, height = 600, res = 150)
hist(tree_results$attributes$height,
     breaks = 20,
     main = "Tree Height Distribution",
     xlab = "Height (m)",
     ylab = "Number of Trees",
     col = "#2E7D32",
     border = "white")
abline(v = 30, col = "red", lwd = 2, lty = 2)
text(32, par("usr")[4] * 0.9, "Old-growth\nthreshold", col = "red", adj = 0)
dev.off()

# Step 6: Habitat Suitability --------------------------------------------------

message("\nStep 6: Calculating habitat suitability...")

hsi_results <- calculate_multispecies_hsi(
  las_clean,
  res = 30,
  species_list = c(target_species),
  output_dir = file.path(output_dir, "hsi")
)

hsi <- hsi_results[[target_species]]

# Summary statistics
hsi_values <- values(hsi, na.rm = TRUE)
cat(sprintf("\n  Habitat Suitability Summary for %s:\n", target_species))
cat(sprintf("    Mean HSI: %.2f\n", mean(hsi_values)))
cat(sprintf("    High quality (>0.7): %.1f%%\n",
            sum(hsi_values >= 0.7) / length(hsi_values) * 100))
cat(sprintf("    Moderate (0.5-0.7): %.1f%%\n",
            sum(hsi_values >= 0.5 & hsi_values < 0.7) / length(hsi_values) * 100))

# Visualize HSI
png(file.path(output_dir, "05_habitat_suitability.png"),
    width = 1200, height = 800, res = 150)
plot(hsi,
     main = sprintf("%s Habitat Suitability Index", tools::toTitleCase(target_species)),
     col = viridis::viridis(100),
     legend = TRUE)
dev.off()

# Identify priority habitat
priority <- identify_priority_habitat(hsi, threshold = 0.7, min_patch_size = 0.5)

if (!is.null(priority) && nrow(priority) > 0) {
  st_write(priority,
           file.path(output_dir, "priority_habitat.gpkg"),
           delete_dsn = TRUE,
           quiet = TRUE)

  message(sprintf("  ✓ Identified %d priority habitat patches (%.1f ha total)",
                  nrow(priority), sum(priority$area_ha)))
}

# Step 7: Summary Report -------------------------------------------------------

message("\nStep 7: Generating summary report...")

# Create summary statistics
summary_stats <- data.frame(
  Metric = c(
    "Study Area",
    "Point Density",
    "Trees Detected",
    "Mean Tree Height",
    "Trees >30m",
    "Mean Canopy Cover",
    "Mean Browse Density",
    "Mean HSI",
    "High Quality Habitat"
  ),
  Value = c(
    format_area(st_bbox(las)$xmax - st_bbox(las)$xmin *
                st_bbox(las)$ymax - st_bbox(las)$ymin),
    sprintf("%.1f pts/m²", nrow(las@data) / ((st_bbox(las)$xmax - st_bbox(las)$xmin) *
                                              (st_bbox(las)$ymax - st_bbox(las)$ymin))),
    as.character(nrow(tree_results$attributes)),
    sprintf("%.1f m", mean(tree_results$attributes$height)),
    as.character(sum(tree_results$attributes$height >= 30)),
    sprintf("%.1f%%", mean(values(canopy_metrics$canopy_cover_pct), na.rm = TRUE)),
    sprintf("%.1f%%", mean(values(understory_metrics$browse_density_pct), na.rm = TRUE)),
    sprintf("%.2f", mean(hsi_values)),
    sprintf("%.1f%%", sum(hsi_values >= 0.7) / length(hsi_values) * 100)
  )
)

write.csv(summary_stats,
          file.path(output_dir, "summary_statistics.csv"),
          row.names = FALSE)

# Print summary
message("\n" , paste(rep("=", 60), collapse = ""))
message("ANALYSIS COMPLETE - SUMMARY")
message(paste(rep("=", 60), collapse = ""))
for (i in 1:nrow(summary_stats)) {
  message(sprintf("%-25s %s", summary_stats$Metric[i], summary_stats$Value[i]))
}
message(paste(rep("=", 60), collapse = ""))

# List output files
message("\nOutput files saved to:", output_dir)
message("  - 01_canopy_height_model.png")
message("  - 02_browse_density.png")
message("  - 03_detected_trees.png")
message("  - 04_tree_distribution.png")
message("  - 05_habitat_suitability.png")
message("  - canopy_metrics.tif")
message("  - understory_metrics.tif")
message("  - trees.gpkg")
message("  - tree_inventory.csv")
message("  - hsi/hsi_moose.tif")
message("  - priority_habitat.gpkg")
message("  - summary_statistics.csv")

message("\n✓ Workflow complete! Open", output_dir, "to view results.\n")

# Cleanup
rm(las, las_clean, chm, dtm, canopy_metrics, understory_metrics,
   tree_results, hsi_results, hsi)
gc()
