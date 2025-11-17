# ============================================================================
# MODULE 00a: 3D ECOSYSTEM & HYDROLOGICAL MODELING - PACKAGE INSTALLATION
# ============================================================================
# PURPOSE: Install packages for 3D visualization and hydrological modeling
# USAGE: Run this after 00a_install_packages_v2.R
# ============================================================================

cat("\n========================================\n")
cat("3D ECOSYSTEM & HYDRO - PACKAGE INSTALLATION\n")
cat("========================================\n\n")

# ============================================================================
# SET OPTIONS
# ============================================================================

options(
  repos = c(CRAN = "https://cloud.r-project.org/"),
  timeout = 300,
  install.packages.compile.from.source = "never"
)

# ============================================================================
# DEFINE 3D & HYDROLOGY PACKAGES
# ============================================================================

# 3D Visualization packages
viz_3d_packages <- c(
  "rayshader",      # 3D terrain rendering (CORE)
  "rgl",            # Interactive 3D graphics
  "plotly",         # Interactive 3D plots
  "rayrender",      # Photorealistic 3D rendering (optional)
  "av"              # Video rendering for animations
)

# Hydrological modeling packages
hydro_packages <- c(
  "whitebox",       # WhiteboxTools R interface (CORE - terrain analysis)
  "EcoHydRology",   # Ecohydrological modeling
  "hydroGOF",       # Hydrological model evaluation
  "topmodel",       # Topography-based hydrological model
  "reservoir",      # Wetland/reservoir water balance
  "soilwater",      # Soil water retention curves
  "Evapotranspiration"  # ET calculation methods
)

# Coastal/Tidal specific packages
coastal_packages <- c(
  "TideHarmonics",  # Tidal prediction
  "oce",            # Oceanographic analysis
  "rtide"           # Tide height calculations
)

# Spatial hydrology & terrain analysis (extended)
terrain_packages <- c(
  "elevatr",        # Fetch elevation data
  "terrainr",       # Terrain data retrieval
  "lakemorpho",     # Lake/wetland morphometry
  "riverdist"       # River network distance calculations
)

# Combine all packages
all_3d_hydro_packages <- c(
  viz_3d_packages,
  hydro_packages,
  coastal_packages,
  terrain_packages
)

cat(sprintf("3D Visualization packages: %d\n", length(viz_3d_packages)))
cat(sprintf("Hydrological modeling packages: %d\n", length(hydro_packages)))
cat(sprintf("Coastal/tidal packages: %d\n", length(coastal_packages)))
cat(sprintf("Terrain analysis packages: %d\n", length(terrain_packages)))
cat(sprintf("Total new packages: %d\n\n", length(all_3d_hydro_packages)))

# ============================================================================
# INSTALLATION FUNCTION
# ============================================================================

install_pkg <- function(pkg, verbose = TRUE) {

  # Check if already installed
  if (requireNamespace(pkg, quietly = TRUE)) {
    if (verbose) cat(sprintf("  ✓ %s (already installed)\n", pkg))
    return(TRUE)
  }

  # Try to install
  if (verbose) cat(sprintf("  Installing %s... ", pkg))

  success <- tryCatch({
    suppressWarnings(
      suppressMessages(
        install.packages(pkg,
                        dependencies = TRUE,
                        quiet = TRUE,
                        type = "binary",
                        repos = "https://cloud.r-project.org/")
      )
    )

    # Verify installation
    if (requireNamespace(pkg, quietly = TRUE)) {
      if (verbose) cat("✓\n")
      TRUE
    } else {
      if (verbose) cat("✗ (verification failed)\n")
      FALSE
    }

  }, error = function(e) {
    if (verbose) cat(sprintf("✗ (error: %s)\n", e$message))
    FALSE
  })

  return(success)
}

# ============================================================================
# INSTALL 3D VISUALIZATION PACKAGES
# ============================================================================

cat("\n========================================\n")
cat("INSTALLING 3D VISUALIZATION PACKAGES\n")
cat("========================================\n\n")

viz_results <- logical(length(viz_3d_packages))
names(viz_results) <- viz_3d_packages

for (i in seq_along(viz_3d_packages)) {
  pkg <- viz_3d_packages[i]
  cat(sprintf("[%d/%d] ", i, length(viz_3d_packages)))
  viz_results[pkg] <- install_pkg(pkg, verbose = TRUE)
  Sys.sleep(0.1)
}

cat(sprintf("\n3D Visualization: %d/%d installed\n",
            sum(viz_results), length(viz_3d_packages)))

# ============================================================================
# INSTALL HYDROLOGICAL PACKAGES
# ============================================================================

cat("\n========================================\n")
cat("INSTALLING HYDROLOGICAL PACKAGES\n")
cat("========================================\n\n")

hydro_results <- logical(length(hydro_packages))
names(hydro_results) <- hydro_packages

for (i in seq_along(hydro_packages)) {
  pkg <- hydro_packages[i]
  cat(sprintf("[%d/%d] ", i, length(hydro_packages)))
  hydro_results[pkg] <- install_pkg(pkg, verbose = TRUE)
  Sys.sleep(0.1)
}

cat(sprintf("\nHydrological: %d/%d installed\n",
            sum(hydro_results), length(hydro_packages)))

# ============================================================================
# INSTALL COASTAL/TIDAL PACKAGES
# ============================================================================

cat("\n========================================\n")
cat("INSTALLING COASTAL/TIDAL PACKAGES\n")
cat("========================================\n\n")

coastal_results <- logical(length(coastal_packages))
names(coastal_results) <- coastal_packages

for (i in seq_along(coastal_packages)) {
  pkg <- coastal_packages[i]
  cat(sprintf("[%d/%d] ", i, length(coastal_packages)))
  coastal_results[pkg] <- install_pkg(pkg, verbose = TRUE)
  Sys.sleep(0.1)
}

cat(sprintf("\nCoastal/Tidal: %d/%d installed\n",
            sum(coastal_results), length(coastal_packages)))

# ============================================================================
# INSTALL TERRAIN ANALYSIS PACKAGES
# ============================================================================

cat("\n========================================\n")
cat("INSTALLING TERRAIN ANALYSIS PACKAGES\n")
cat("========================================\n\n")

terrain_results <- logical(length(terrain_packages))
names(terrain_results) <- terrain_packages

for (i in seq_along(terrain_packages)) {
  pkg <- terrain_packages[i]
  cat(sprintf("[%d/%d] ", i, length(terrain_packages)))
  terrain_results[pkg] <- install_pkg(pkg, verbose = TRUE)
  Sys.sleep(0.1)
}

cat(sprintf("\nTerrain: %d/%d installed\n",
            sum(terrain_results), length(terrain_packages)))

# ============================================================================
# WHITEBOX TOOLS SETUP (CRITICAL FOR HYDROLOGY)
# ============================================================================

cat("\n========================================\n")
cat("WHITEBOX TOOLS SETUP\n")
cat("========================================\n\n")

if (requireNamespace("whitebox", quietly = TRUE)) {
  cat("Installing WhiteboxTools executable...\n")

  tryCatch({
    library(whitebox)

    # Install WhiteboxTools binary
    whitebox::install_whitebox()

    # Check installation
    wbt_version <- whitebox::wbt_version()
    cat(sprintf("✓ WhiteboxTools installed: %s\n", wbt_version))

    # Set verbose mode off (reduces console spam)
    whitebox::wbt_verbose(FALSE)

  }, error = function(e) {
    cat(sprintf("✗ WhiteboxTools setup failed: %s\n", e$message))
    cat("  Try manually: library(whitebox); install_whitebox()\n")
  })

} else {
  cat("✗ whitebox package not available\n")
  cat("  WhiteboxTools is required for hydrological modeling\n")
}

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("INSTALLATION SUMMARY\n")
cat("========================================\n\n")

all_results <- c(viz_results, hydro_results, coastal_results, terrain_results)
total_success <- sum(all_results)
total_attempted <- length(all_results)

cat(sprintf("Total: %d/%d installed (%.1f%%)\n\n",
            total_success, total_attempted,
            100 * total_success / total_attempted))

# Critical packages for Module 11
critical_3d <- c("rayshader", "whitebox", "rgl", "plotly")
critical_status <- sapply(critical_3d, function(p) requireNamespace(p, quietly = TRUE))

cat("Critical packages for Module 11:\n")
for (i in seq_along(critical_3d)) {
  pkg <- critical_3d[i]
  status <- if (critical_status[i]) "✓" else "✗"
  cat(sprintf("  %s %s\n", status, pkg))
}
cat("\n")

# ============================================================================
# TEST 3D RENDERING (OPTIONAL)
# ============================================================================

cat("========================================\n")
cat("OPTIONAL: Test 3D rendering?\n")
cat("========================================\n\n")

cat("To test your 3D setup, run:\n")
cat("  library(rayshader)\n")
cat("  volcano %>% sphere_shade() %>% plot_map()\n\n")

# ============================================================================
# NEXT STEPS
# ============================================================================

cat("========================================\n")
cat("NEXT STEPS\n")
cat("========================================\n\n")

if (sum(critical_status) == length(critical_3d)) {
  cat("✓✓✓ SUCCESS! All critical packages installed.\n\n")
  cat("You can now run:\n")
  cat("  source('11_3d_ecosystem_modeling.R')\n\n")
} else {
  cat("⚠️  Some critical packages missing.\n\n")
  missing <- critical_3d[!critical_status]
  cat("Try installing manually:\n")
  for (pkg in missing) {
    cat(sprintf("  install.packages('%s')\n", pkg))
  }
  cat("\n")
}

# Special note for rayshader
if (!requireNamespace("rayshader", quietly = TRUE)) {
  cat("Note: rayshader requires:\n")
  cat("  - R >= 4.0\n")
  cat("  - Rtools (Windows) or Xcode (Mac)\n")
  cat("  See: https://github.com/tylermorganwall/rayshader\n\n")
}

cat("Done! 🌊🗻\n\n")

# ============================================================================
# SAVE INSTALLATION RECORD
# ============================================================================

if (!dir.exists("logs")) {
  dir.create("logs", recursive = TRUE, showWarnings = FALSE)
}

install_record <- data.frame(
  package = names(all_results),
  category = c(
    rep("3d_viz", length(viz_results)),
    rep("hydrology", length(hydro_results)),
    rep("coastal", length(coastal_results)),
    rep("terrain", length(terrain_results))
  ),
  installed = all_results,
  date = Sys.Date(),
  stringsAsFactors = FALSE
)

write.csv(install_record,
          file.path("logs", paste0("3d_hydro_install_", Sys.Date(), ".csv")),
          row.names = FALSE)

cat("Installation record saved to: logs/3d_hydro_install_", Sys.Date(), ".csv\n\n", sep = "")
