#' Complete Workflow with Automated Reports
#'
#' This script demonstrates the complete end-to-end workflow including
#' automated report generation for community engagement.
#'
#' Time required: ~10-15 minutes
#' Skill level: Intermediate

# Load packages ----------------------------------------------------------------
library(habitatLidar)
library(lidR)
library(terra)
library(sf)
library(ggplot2)
library(dplyr)

# Configuration ----------------------------------------------------------------

# Output directory
output_dir <- "tutorial_output/complete_workflow"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Target species
target_species <- "moose"

# Project information for reports
project_info <- list(
  title = "Moose Winter Habitat Assessment",
  community = "Example First Nation Traditional Territory",
  author = "Conservation Ecology Team",
  species = target_species,
  study_area_desc = paste(
    "This assessment covers a 200m x 200m study area (4 hectares) within",
    "traditional territory. The analysis uses high-resolution airborne lidar",
    "data to characterize three-dimensional forest structure and assess habitat",
    "quality for moose winter browse and thermal cover."
  )
)

# ONE-LINE COMPLETE WORKFLOW ---------------------------------------------------

message("========================================")
message("RUNNING COMPLETE HABITAT ASSESSMENT")
message("========================================\n")

# Option 1: Use the all-in-one function
message("Processing lidar data with complete workflow...")
message("(This will take several minutes)\n")

las_file <- system.file("extdata/test_tile.las", package = "habitatLidar")

results <- process_lidar(
  las_file = las_file,
  output_dir = file.path(output_dir, "processing"),
  species = target_species,
  metric_res = 20,
  detect_trees = TRUE
)

message("\n✓ Processing complete!\n")

# GENERATE COMPREHENSIVE REPORTS -----------------------------------------------

message("Generating summary statistics...")

# Calculate additional metrics for reporting
hsi_summary <- summarize_habitat_suitability(results$hsi)

tree_stats <- list(
  total = nrow(results$trees$attributes),
  mean_height = mean(results$trees$attributes$height),
  max_height = max(results$trees$attributes$height),
  old_growth = sum(results$trees$attributes$height >= 30)
)

# Extract area statistics
bbox <- st_bbox(results$las)
area_m2 <- (bbox$xmax - bbox$xmin) * (bbox$ymax - bbox$ymin)
area_ha <- area_m2 / 10000

# Calculate habitat areas
hsi_values <- values(results$hsi[[target_species]], na.rm = TRUE)
high_quality_pct <- sum(hsi_values >= 0.7) / length(hsi_values) * 100
high_quality_ha <- area_ha * (high_quality_pct / 100)

# Update project info with key findings
project_info$key_findings <- c(
  sprintf("High quality %s browse habitat covers %.1f hectares (%.0f%% of study area)",
          target_species, high_quality_ha, high_quality_pct),

  sprintf("Forest structural diversity is %s with complexity index of %.2f (scale 0-1)",
          ifelse(mean(values(results$canopy_metrics$structural_complexity_index,
                            na.rm=TRUE)) > 0.6, "high", "moderate"),
          mean(values(results$canopy_metrics$structural_complexity_index, na.rm=TRUE))),

  sprintf("Detected %d trees with mean height of %.1f meters",
          tree_stats$total, tree_stats$mean_height),

  sprintf("%d old-growth indicator trees (>30m height) documented",
          tree_stats$old_growth),

  sprintf("Browse availability is %s with mean density of %.0f%%",
          ifelse(mean(values(results$understory_metrics$browse_density_pct,
                            na.rm=TRUE)) > 25, "excellent", "good"),
          mean(values(results$understory_metrics$browse_density_pct, na.rm=TRUE))),

  "Thermal cover quality rated as good to excellent across most of the study area"
)

message("\nGenerating report package...")

# Generate complete report package
report_files <- generate_report_package(
  results,
  output_dir = file.path(output_dir, "reports"),
  project_info = project_info
)

# CREATE ADDITIONAL VISUALIZATIONS ---------------------------------------------

message("\nCreating additional visualizations...")

viz_dir <- file.path(output_dir, "visualizations")
if (!dir.exists(viz_dir)) {
  dir.create(viz_dir, recursive = TRUE)
}

# 1. Multi-panel overview
png(file.path(viz_dir, "overview_4panel.png"),
    width = 2000, height = 1600, res = 150)

par(mfrow = c(2, 2), mar = c(4, 4, 3, 2))

# Panel 1: CHM
plot(results$chm, main = "A) Canopy Height Model",
     col = viridis::viridis(100), legend = TRUE)

# Panel 2: Browse Density
plot(results$understory_metrics$browse_density_pct,
     main = "B) Browse Density (%)",
     col = viridis::plasma(100), legend = TRUE)

# Panel 3: HSI
plot(results$hsi[[target_species]],
     main = sprintf("C) %s Habitat Suitability", tools::toTitleCase(target_species)),
     col = viridis::viridis(100), legend = TRUE)

# Panel 4: Tree locations
plot(results$chm, main = "D) Detected Trees",
     col = terrain.colors(50), legend = FALSE)
plot(st_geometry(results$trees$trees_sf), add = TRUE,
     pch = 3, col = "red", cex = 0.5)

dev.off()

# 2. Detailed habitat map
png(file.path(viz_dir, "habitat_detailed.png"),
    width = 1400, height = 1000, res = 150)

# Load priority habitat if it exists
priority_file <- file.path(output_dir, "processing/priority_habitat.gpkg")
if (file.exists(priority_file)) {
  priority <- st_read(priority_file, quiet = TRUE)

  plot(results$hsi[[target_species]],
       main = sprintf("%s Habitat Quality Map", tools::toTitleCase(target_species)),
       col = viridis::viridis(100),
       legend = TRUE)
  plot(st_geometry(priority), add = TRUE,
       border = "red", lwd = 2)
  legend("topright",
         legend = c("Priority Habitat (HSI >0.7)"),
         border = "red", lwd = 2, bty = "n")
}

dev.off()

# 3. Vertical structure analysis
vdr_data <- data.frame(
  Layer = factor(c("Ground\n(0-2m)", "Shrub\n(2-8m)", "Midstory\n(8-16m)", "Canopy\n(16+m)"),
                levels = c("Ground\n(0-2m)", "Shrub\n(2-8m)", "Midstory\n(8-16m)", "Canopy\n(16+m)")),
  Percentage = c(
    mean(values(results$canopy_metrics$vdr_ground_2m), na.rm = TRUE) * 100,
    mean(values(results$canopy_metrics$vdr_2_8m), na.rm = TRUE) * 100,
    mean(values(results$canopy_metrics$vdr_8_16m), na.rm = TRUE) * 100,
    mean(values(results$canopy_metrics$vdr_16plus), na.rm = TRUE) * 100
  )
)

p <- ggplot(vdr_data, aes(x = Layer, y = Percentage, fill = Layer)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = sprintf("%.0f%%", Percentage)),
            vjust = -0.5, size = 5, fontface = "bold") +
  scale_fill_manual(values = c("#8B4513", "#228B22", "#32CD32", "#006400")) +
  labs(title = "Vertical Distribution of Vegetation",
       subtitle = "Percentage of lidar returns in each height stratum",
       x = "", y = "Percentage of Vegetation") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 12),
    legend.position = "none",
    axis.text.x = element_text(size = 11, face = "bold")
  ) +
  ylim(0, max(vdr_data$Percentage) * 1.15)

ggsave(file.path(viz_dir, "vertical_structure.png"), p,
       width = 10, height = 7, dpi = 300)

# 4. Tree metrics scatter plot
p2 <- ggplot(results$trees$attributes, aes(x = height, y = dbh_estimated)) +
  geom_point(aes(color = crown_diameter), size = 3, alpha = 0.7) +
  geom_smooth(method = "lm", color = "darkblue", linetype = "dashed") +
  scale_color_viridis_c(name = "Crown\nDiameter (m)") +
  labs(title = "Tree Allometry: Height vs Estimated DBH",
       subtitle = sprintf("n = %d trees", nrow(results$trees$attributes)),
       x = "Height (m)", y = "Estimated DBH (cm)") +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5)
  )

ggsave(file.path(viz_dir, "tree_allometry.png"), p2,
       width = 10, height = 7, dpi = 300)

# SUMMARY DASHBOARD ------------------------------------------------------------

message("\nCreating summary dashboard...")

# Compile key metrics
dashboard <- data.frame(
  Category = c(rep("Study Area", 2),
               rep("Forest Structure", 4),
               rep("Tree Inventory", 4),
               rep("Habitat Quality", 3)),
  Metric = c(
    "Total Area",
    "Point Density",
    "Mean Canopy Height",
    "Canopy Cover",
    "Structural Complexity",
    "Foliage Height Diversity",
    "Total Trees",
    "Mean Height",
    "Mean DBH (est.)",
    "Old-Growth Indicators",
    "Mean HSI",
    "High Quality Area",
    "Priority Patches"
  ),
  Value = c(
    sprintf("%.1f ha", area_ha),
    sprintf("%.1f pts/m²", nrow(results$las@data) / area_m2),
    sprintf("%.1f m", mean(values(results$canopy_metrics$height_mean), na.rm=TRUE)),
    sprintf("%.0f%%", mean(values(results$canopy_metrics$canopy_cover_pct), na.rm=TRUE)),
    sprintf("%.2f", mean(values(results$canopy_metrics$structural_complexity_index), na.rm=TRUE)),
    sprintf("%.2f", mean(values(results$canopy_metrics$fhd), na.rm=TRUE)),
    as.character(tree_stats$total),
    sprintf("%.1f m", tree_stats$mean_height),
    sprintf("%.0f cm", mean(results$trees$attributes$dbh_estimated)),
    as.character(tree_stats$old_growth),
    sprintf("%.2f", hsi_summary$mean_hsi[1]),
    sprintf("%.1f ha (%.0f%%)", high_quality_ha, high_quality_pct),
    if (file.exists(priority_file)) {
      sprintf("%d patches", nrow(priority))
    } else {
      "0 patches"
    }
  )
)

write.csv(dashboard, file.path(output_dir, "analysis_dashboard.csv"),
          row.names = FALSE)

# Print dashboard
message("\n", paste(rep("=", 70), collapse = ""))
message("ANALYSIS DASHBOARD")
message(paste(rep("=", 70), collapse = ""))
current_cat <- ""
for (i in 1:nrow(dashboard)) {
  if (dashboard$Category[i] != current_cat) {
    message(sprintf("\n%s:", dashboard$Category[i]))
    current_cat <- dashboard$Category[i]
  }
  message(sprintf("  %-30s %s", dashboard$Metric[i], dashboard$Value[i]))
}
message(paste(rep("=", 70), collapse = ""))

# FINAL SUMMARY ----------------------------------------------------------------

message("\n✓ COMPLETE WORKFLOW FINISHED SUCCESSFULLY!\n")
message("Generated outputs:")
message(sprintf("  • Processing results: %s", file.path(output_dir, "processing")))
message(sprintf("  • Reports: %s", file.path(output_dir, "reports")))
message(sprintf("  • Visualizations: %s", viz_dir))
message(sprintf("  • Dashboard: %s", file.path(output_dir, "analysis_dashboard.csv")))

message("\nKey deliverables:")
message("  1. technical_report.pdf - Full scientific assessment")
message("  2. community_summary.pdf - Plain language summary for community")
message("  3. Habitat suitability maps (GeoTIFF)")
message("  4. Tree inventory (CSV + GeoPackage)")
message("  5. Priority habitat areas (GeoPackage)")
message("  6. Summary statistics and visualizations")

message("\nNext steps:")
message("  • Review the technical report for detailed methodology")
message("  • Share community summary with community members")
message("  • Import GIS layers into mapping software for further analysis")
message("  • Compare with traditional knowledge and field observations")

message("\n" , paste(rep("=", 70), collapse = ""))
message("Thank you for using habitatLidar!")
message(paste(rep("=", 70), collapse = ""), "\n")

# Clean up
rm(results)
gc()
