# ============================================================================
# MODULE 00e: PRAGMATIC TRANSFER LEARNING FOR BLUE CARBON
# ============================================================================
# PURPOSE: Extract existing global soil carbon maps as features for regional modeling
# APPROACH: Instead of training a global model, leverage existing products
# RATIONALE: Computationally efficient, uses peer-reviewed global datasets
# ============================================================================
#
# TRANSFER LEARNING STRATEGY:
# ---------------------------
# Traditional approach (computationally expensive):
#   1. Train global model on 100k+ samples
#   2. Fine-tune on regional data
#   3. Combine predictions
#
# PRAGMATIC approach (this module):
#   1. Extract SoilGrids predictions at your locations (global baseline)
#   2. Use these as features in regional Random Forest
#   3. The model learns how to adjust global predictions for blue carbon
#
# MATHEMATICAL FRAMEWORK:
#   Regional_SOC = f(Local_Covariates, SoilGrids_SOC, Climate, Topography)
#
# This IS transfer learning because:
#   - SoilGrids embeds global soil-environment relationships
#   - Your regional model learns the "delta" from global baseline
#   - Equivalent to: Regional = Global + Local_Adjustment
#
# ADVANTAGES:
#   ✓ No massive compute needed
#   ✓ Uses peer-reviewed global products
#   ✓ Fast (minutes instead of hours/days)
#   ✓ Reproducible
#   ✓ Operationally practical for carbon projects
#
# ============================================================================

# Load required packages
suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(terra)
  library(httr)
  library(jsonlite)
})

# ============================================================================
# CONFIGURATION
# ============================================================================

cat("\n========================================\n")
cat("PRAGMATIC TRANSFER LEARNING\n")
cat("========================================\n\n")

CONFIG <- list(
  # Input files
  regional_cores = "data_raw/core_locations.csv",  # Your field cores

  # Output files
  output_dir = "data_global",
  output_file = "regional_cores_with_global_features.csv",

  # Global products to extract
  extract_soilgrids = TRUE,      # SoilGrids 250m (ISRIC)
  extract_worldclim = TRUE,      # WorldClim 2.1 (climate)
  extract_elevation = TRUE,      # SRTM elevation
  extract_gsw = TRUE,            # Global Surface Water (coastal)

  # API settings (for REST-based extraction)
  max_retries = 3,
  sleep_between = 1,             # seconds between API calls

  # Cache settings
  cache_dir = "data_global/cache",
  use_cache = TRUE
)

# Create directories
dir.create(CONFIG$output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(CONFIG$cache_dir, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Log message with timestamp
log_message <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  cat(sprintf("%s %s: %s\n", timestamp, level, msg))
}

#' Extract SoilGrids at point locations using REST API
#'
#' SoilGrids is a global soil database at 250m resolution
#' Trained on 240,000+ soil profiles worldwide
#' This provides the "global model" baseline
#'
#' @param lat Latitude
#' @param lon Longitude
#' @param depth Depth in cm (0-5, 5-15, 15-30, 30-60, 60-100, 100-200)
#' @return Data frame with soil properties
extract_soilgrids_point <- function(lat, lon, depths = c("0-5cm", "5-15cm")) {

  # SoilGrids REST API endpoint
  base_url <- "https://rest.isric.org/soilgrids/v2.0/properties/query"

  # Properties to extract
  properties <- c("soc", "bdod", "clay", "sand", "silt", "phh2o")

  # Build query
  query_url <- paste0(
    base_url,
    "?lon=", lon,
    "&lat=", lat,
    "&property=", paste(properties, collapse = ","),
    "&depth=", paste(depths, collapse = ","),
    "&value=mean"
  )

  # Try to fetch
  for (attempt in 1:CONFIG$max_retries) {
    tryCatch({
      response <- GET(query_url)

      if (status_code(response) == 200) {
        data <- content(response, "parsed")

        # Parse response
        result <- data.frame(
          latitude = lat,
          longitude = lon
        )

        # Extract each property
        for (prop in properties) {
          prop_data <- data$properties$layers[[prop]]
          if (!is.null(prop_data)) {
            for (depth_data in prop_data$depths) {
              depth_label <- depth_data$label
              value <- depth_data$values$mean

              # Convert units
              if (prop == "soc") {
                value <- value / 10  # dg/kg to g/kg
              } else if (prop == "bdod") {
                value <- value / 100  # cg/cm3 to g/cm3
              } else if (prop %in% c("clay", "sand", "silt")) {
                value <- value / 10  # g/kg to %
              } else if (prop == "phh2o") {
                value <- value / 10  # pH * 10 to pH
              }

              col_name <- paste0("sg_", prop, "_", gsub("-", "_", depth_label))
              result[[col_name]] <- value
            }
          }
        }

        Sys.sleep(CONFIG$sleep_between)
        return(result)
      }

    }, error = function(e) {
      log_message(paste("Attempt", attempt, "failed:", e$message), "WARNING")
      Sys.sleep(attempt * 2)  # Exponential backoff
    })
  }

  log_message(paste("Failed to extract SoilGrids for", lat, lon), "ERROR")
  return(NULL)
}

#' Extract WorldClim climate data
#'
#' WorldClim provides global climate data at 1km resolution
#' 19 bioclimatic variables derived from temperature and precipitation
#'
#' Note: For production use, download WorldClim tiles and extract locally
#'       This is faster than API calls for many points
extract_worldclim_batch <- function(cores_sf) {

  log_message("WorldClim extraction requires raster download")
  log_message("For now, using placeholder values")
  log_message("TODO: Download WorldClim tiles and extract locally")

  # Placeholder - in production, download WorldClim and extract
  cores_sf %>%
    mutate(
      wc_MAT_C = NA_real_,           # Mean annual temperature
      wc_MAP_mm = NA_real_,          # Mean annual precipitation
      wc_temp_seasonality = NA_real_,
      wc_precip_seasonality = NA_real_
    )
}

#' Extract SRTM elevation (placeholder)
extract_elevation_batch <- function(cores_sf) {
  log_message("Elevation extraction requires DEM raster")
  log_message("Use GEE script or download SRTM tiles")

  cores_sf %>%
    mutate(
      elevation_m = NA_real_,
      slope_deg = NA_real_
    )
}

#' Extract Global Surface Water (placeholder)
extract_gsw_batch <- function(cores_sf) {
  log_message("GSW extraction requires raster download")
  log_message("Use GEE script for coastal features")

  cores_sf %>%
    mutate(
      water_occurrence_pct = NA_real_,
      distance_to_water_m = NA_real_
    )
}

# ============================================================================
# MAIN EXTRACTION WORKFLOW
# ============================================================================

log_message("Starting pragmatic transfer learning extraction...")

# Load regional core locations
log_message(paste("Loading regional cores from:", CONFIG$regional_cores))

if (!file.exists(CONFIG$regional_cores)) {
  log_message("Regional cores file not found!", "ERROR")
  log_message("Please run Module 01 first to prepare core locations", "ERROR")
  quit(save = "no", status = 1)
}

cores <- read_csv(CONFIG$regional_cores, show_col_types = FALSE)

log_message(sprintf("Loaded %d core locations", nrow(cores)))

# Check required columns
required_cols <- c("core_id", "latitude", "longitude")
missing_cols <- setdiff(required_cols, names(cores))

if (length(missing_cols) > 0) {
  log_message(paste("Missing columns:", paste(missing_cols, collapse = ", ")), "ERROR")
  quit(save = "no", status = 1)
}

# ============================================================================
# EXTRACT SOILGRIDS (GLOBAL SOIL BASELINE)
# ============================================================================

if (CONFIG$extract_soilgrids) {
  log_message("\n=== Extracting SoilGrids (Global Baseline) ===")

  cache_file <- file.path(CONFIG$cache_dir, "soilgrids_extraction.rds")

  if (CONFIG$use_cache && file.exists(cache_file)) {
    log_message("Loading SoilGrids from cache...")
    soilgrids_data <- readRDS(cache_file)

  } else {
    log_message(sprintf("Extracting SoilGrids for %d locations...", nrow(cores)))
    log_message("This may take 5-10 minutes (API rate limits)")
    log_message("Progress will be saved to cache")

    # Extract for each core
    soilgrids_list <- list()

    for (i in 1:nrow(cores)) {
      if (i %% 10 == 0) {
        log_message(sprintf("Progress: %d/%d (%.1f%%)", i, nrow(cores), 100*i/nrow(cores)))
      }

      result <- extract_soilgrids_point(
        lat = cores$latitude[i],
        lon = cores$longitude[i],
        depths = c("0-5cm", "5-15cm", "15-30cm")
      )

      if (!is.null(result)) {
        result$core_id <- cores$core_id[i]
        soilgrids_list[[i]] <- result
      }
    }

    soilgrids_data <- bind_rows(soilgrids_list)

    # Cache results
    saveRDS(soilgrids_data, cache_file)
    log_message("SoilGrids data cached")
  }

  # Join with cores
  cores <- cores %>%
    left_join(soilgrids_data, by = c("core_id", "latitude", "longitude"))

  log_message(sprintf("✓ SoilGrids extracted: %d columns added",
                     sum(grepl("^sg_", names(cores)))))
}

# ============================================================================
# EXTRACT WORLDCLIM (CLIMATE)
# ============================================================================

if (CONFIG$extract_worldclim) {
  log_message("\n=== Extracting WorldClim (Climate) ===")
  log_message("Note: Using GEE script for full climate extraction")
  log_message("See: GEE_EXTRACT_GLOBAL_FEATURES.js")

  # Placeholder - recommend using GEE for batch extraction
}

# ============================================================================
# EXTRACT OTHER FEATURES
# ============================================================================

if (CONFIG$extract_elevation) {
  log_message("\n=== Elevation (Use GEE) ===")
  log_message("Recommend extracting via GEE script")
}

if (CONFIG$extract_gsw) {
  log_message("\n=== Global Surface Water (Use GEE) ===")
  log_message("Recommend extracting via GEE script")
}

# ============================================================================
# SAVE RESULTS
# ============================================================================

output_path <- file.path(CONFIG$output_dir, CONFIG$output_file)

write_csv(cores, output_path)

log_message(sprintf("\n✓ Results saved to: %s", output_path))
log_message(sprintf("  Total cores: %d", nrow(cores)))
log_message(sprintf("  Total columns: %d", ncol(cores)))

# ============================================================================
# SUMMARY & NEXT STEPS
# ============================================================================

cat("\n========================================\n")
cat("EXTRACTION COMPLETE\n")
cat("========================================\n\n")

cat("EXTRACTED FEATURES:\n")
cat(sprintf("  • SoilGrids: %d features\n", sum(grepl("^sg_", names(cores)))))
cat(sprintf("  • Total: %d columns\n", ncol(cores)))

cat("\n📋 NEXT STEPS:\n")
cat("1. Run GEE script to extract climate/elevation/coastal features:\n")
cat("   → GEE_EXTRACT_GLOBAL_FEATURES.js\n\n")

cat("2. Merge GEE results with SoilGrids data:\n")
cat("   → cores_with_gee <- read_csv('gee_features.csv')\n")
cat("   → cores_final <- left_join(cores, cores_with_gee, by='core_id')\n\n")

cat("3. Use in Module 05c for regional modeling:\n")
cat("   → The regional RF will learn to adjust global predictions\n")
cat("   → Transfer learning happens automatically!\n\n")

cat("💡 TRANSFER LEARNING EXPLANATION:\n")
cat("• SoilGrids SOC = Global baseline (trained on 240k+ profiles)\n")
cat("• Your regional model learns: Regional_SOC = f(SoilGrids_SOC + Local_Covariates)\n")
cat("• The model discovers how blue carbon differs from global patterns\n")
cat("• This is equivalent to: Regional = Global + Blue_Carbon_Delta\n\n")

cat("✅ ADVANTAGES OF THIS APPROACH:\n")
cat("• No massive model training needed\n")
cat("• Uses peer-reviewed global products\n")
cat("• Computationally efficient (minutes not days)\n")
cat("• Operationally practical for carbon projects\n")
cat("• Still achieves transfer learning benefits\n\n")

cat("🚀 Ready for regional modeling!\n\n")

log_message("Module 00e complete")
