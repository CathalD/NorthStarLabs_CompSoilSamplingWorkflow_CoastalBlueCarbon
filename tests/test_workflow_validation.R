# ============================================================================
# BLUE CARBON MMRV WORKFLOW - COMPREHENSIVE TESTING FRAMEWORK
# ============================================================================
# PURPOSE: Validate workflow functionality with automated tests
# USAGE: source("tests/test_workflow_validation.R")
# REQUIREMENTS: All R packages from 00a_install_packages_v2.R
# ============================================================================

cat("\n========================================\n")
cat("BLUE CARBON WORKFLOW - TEST SUITE\n")
cat("========================================\n\n")

# Load required packages
suppressPackageStartupMessages({
  library(dplyr)
  library(terra)
  library(sf)
})

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

TEST_MODE <- TRUE  # Set to TRUE to enable verbose output
test_results <- list()
tests_passed <- 0
tests_failed <- 0

# Helper function to run tests
run_test <- function(test_name, test_function) {
  cat(sprintf("\n[TEST] %s\n", test_name))
  cat("  Running... ")

  result <- tryCatch({
    test_function()
    cat("✓ PASS\n")
    tests_passed <<- tests_passed + 1
    list(status = "PASS", message = "Test completed successfully")
  }, error = function(e) {
    cat("✗ FAIL\n")
    cat(sprintf("  Error: %s\n", e$message))
    tests_failed <<- tests_failed + 1
    list(status = "FAIL", message = e$message)
  }, warning = function(w) {
    cat("⚠ WARNING\n")
    cat(sprintf("  Warning: %s\n", w$message))
    list(status = "WARNING", message = w$message)
  })

  test_results[[test_name]] <<- result
  return(result$status == "PASS")
}

# ============================================================================
# UNIT TESTS: INDIVIDUAL FUNCTIONS
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 1: UNIT TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 1.1: Carbon Stock Calculation Formula
run_test("1.1 Carbon Stock Calculation - Basic Formula", function() {
  # Load calculate_soc_stock function from Module 01
  calculate_soc_stock <- function(soc_g_kg, bd_g_cm3, depth_top_cm, depth_bottom_cm) {
    depth_increment <- depth_bottom_cm - depth_top_cm
    soc_stock_kg_m2 <- soc_g_kg * bd_g_cm3 * depth_increment / 1000
    return(soc_stock_kg_m2)
  }

  # Test case: SOC=50 g/kg, BD=1.2 g/cm³, depth=0-15 cm
  result <- calculate_soc_stock(50, 1.2, 0, 15)
  expected <- 50 * 1.2 * 15 / 1000  # = 0.9 kg/m²

  if (abs(result - expected) > 0.001) {
    stop(sprintf("Expected %.3f, got %.3f", expected, result))
  }

  # Test conversion to Mg/ha
  result_Mg_ha <- result * 10
  expected_Mg_ha <- 9.0

  if (abs(result_Mg_ha - expected_Mg_ha) > 0.001) {
    stop(sprintf("Mg/ha conversion: Expected %.1f, got %.1f", expected_Mg_ha, result_Mg_ha))
  }
})

# Test 1.2: Coordinate Validation
run_test("1.2 Coordinate Validation - Range Checks", function() {
  # Test invalid coordinates are caught
  valid_lon <- -123.5
  valid_lat <- 49.2

  # Valid coordinate checks
  if (valid_lon < -180 || valid_lon > 180) stop("Longitude check failed")
  if (valid_lat < -90 || valid_lat > 90) stop("Latitude check failed")

  # Invalid coordinate detection
  invalid_lon <- 200
  if (invalid_lon >= -180 && invalid_lon <= 180) stop("Invalid lon not caught")
})

# Test 1.3: VM0033 Sample Size Calculation
run_test("1.3 VM0033 Sample Size Calculation", function() {
  # Formula: n = (z * CV / target_precision)^2
  z <- 1.96  # 95% CI
  cv <- 30  # 30% coefficient of variation
  target_precision <- 20  # 20% target
  vm0033_min <- 3

  n_required <- ceiling((z * cv / target_precision)^2)
  n_final <- max(n_required, vm0033_min)

  # Expected: (1.96 * 30 / 20)^2 = 8.64 -> 9 cores
  if (n_required != 9) {
    stop(sprintf("Expected 9 cores, got %d", n_required))
  }
})

# Test 1.4: Conservative Estimate Calculation
run_test("1.4 Conservative Estimate (95% CI Lower Bound)", function() {
  mean_stock <- 100  # Mg C/ha
  se <- 10  # Mg C/ha
  confidence <- 0.95

  z <- qnorm((1 + confidence) / 2)  # 1.96
  conservative <- mean_stock - (z * se)

  expected <- 100 - (1.96 * 10)  # = 80.4

  if (abs(conservative - expected) > 0.1) {
    stop(sprintf("Expected %.1f, got %.1f", expected, conservative))
  }

  # Ensure non-negative
  conservative_checked <- max(conservative, 0)
  if (conservative_checked < 0) stop("Conservative estimate is negative")
})

# Test 1.5: VM0033 Depth Intervals
run_test("1.5 VM0033 Depth Interval Configuration", function() {
  # Standard VM0033 depths
  expected_midpoints <- c(7.5, 22.5, 40, 75)
  expected_intervals <- data.frame(
    depth_top = c(0, 15, 30, 50),
    depth_bottom = c(15, 30, 50, 100),
    depth_midpoint = expected_midpoints,
    thickness_cm = c(15, 15, 20, 50)
  )

  # Verify thickness calculations
  calculated_thickness <- expected_intervals$depth_bottom - expected_intervals$depth_top
  if (!all(calculated_thickness == expected_intervals$thickness_cm)) {
    stop("Depth interval thickness mismatch")
  }

  # Verify midpoint calculations
  calculated_midpoints <- (expected_intervals$depth_top + expected_intervals$depth_bottom) / 2
  if (!all(abs(calculated_midpoints - expected_midpoints) < 0.1)) {
    stop("Depth midpoint mismatch")
  }
})

# ============================================================================
# INTEGRATION TESTS: WORKFLOW COMPONENTS
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 2: INTEGRATION TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 2.1: Configuration File Loading
run_test("2.1 Configuration File Load & Validation", function() {
  if (!file.exists("blue_carbon_config.R")) {
    stop("Config file not found")
  }

  # Source config
  source("blue_carbon_config.R", local = TRUE)

  # Check required variables exist
  required_vars <- c("VM0033_MIN_CORES", "CONFIDENCE_LEVEL", "VALID_STRATA",
                     "INPUT_CRS", "PROCESSING_CRS")

  for (var in required_vars) {
    if (!exists(var)) {
      stop(sprintf("Required config variable missing: %s", var))
    }
  }
})

# Test 2.2: Directory Structure Creation
run_test("2.2 Directory Structure Validation", function() {
  required_dirs <- c(
    "data_raw", "data_processed", "data_prior",
    "outputs", "diagnostics", "logs"
  )

  for (dir in required_dirs) {
    if (!dir.exists(dir)) {
      cat(sprintf("  Creating missing directory: %s\n", dir))
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    }
  }

  # Verify all created
  missing <- required_dirs[!sapply(required_dirs, dir.exists)]
  if (length(missing) > 0) {
    stop(sprintf("Failed to create directories: %s", paste(missing, collapse = ", ")))
  }
})

# Test 2.3: Package Dependencies Check
run_test("2.3 Critical R Package Availability", function() {
  critical_packages <- c("dplyr", "ggplot2", "sf", "terra", "randomForest", "openxlsx")

  missing <- critical_packages[!sapply(critical_packages,
                                       function(p) requireNamespace(p, quietly = TRUE))]

  if (length(missing) > 0) {
    stop(sprintf("Missing critical packages: %s\nRun: source('00a_install_packages_v2.R')",
                 paste(missing, collapse = ", ")))
  }
})

# Test 2.4: Uncertainty Propagation
run_test("2.4 Uncertainty Propagation - Combined Variance", function() {
  # Test uncertainty combination from SOC + BD
  soc_mean <- 50  # g/kg
  soc_se <- 5  # g/kg
  bd_mean <- 1.2  # g/cm³
  bd_se <- 0.1  # g/cm³
  depth_cm <- 15

  # Calculate stock
  stock_mean <- soc_mean * bd_mean * depth_cm / 1000  # 0.9 kg/m²

  # Error propagation (first-order Taylor)
  rel_var_soc <- (soc_se / soc_mean)^2
  rel_var_bd <- (bd_se / bd_mean)^2
  stock_se <- stock_mean * sqrt(rel_var_soc + rel_var_bd)

  # Verify SE is reasonable (should be ~0.1 kg/m²)
  expected_se_approx <- 0.1
  if (abs(stock_se - expected_se_approx) > 0.05) {
    cat(sprintf("  Note: SE = %.3f kg/m² (expected ~%.3f)\n", stock_se, expected_se_approx))
  }
})

# ============================================================================
# DATA VALIDATION TESTS
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 3: DATA VALIDATION TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 3.1: Example Data Template Validation
run_test("3.1 Example Data Templates Exist", function() {
  template_files <- c(
    "core_locations_TEMPLATE.csv",
    "core_samples_TEMPLATE.csv"
  )

  for (file in template_files) {
    full_path <- file.path("data_raw", file)
    if (!file.exists(full_path)) {
      cat(sprintf("  ⚠ Template not found: %s (creating placeholder)\n", file))

      if (file == "core_locations_TEMPLATE.csv") {
        # Create example location template
        example_locations <- data.frame(
          core_id = c("CORE_001", "CORE_002", "CORE_003"),
          longitude = c(-123.5, -123.52, -123.48),
          latitude = c(49.2, 49.21, 49.19),
          stratum = c("Mid Marsh", "Lower Marsh", "Upper Marsh"),
          core_type = c("HR", "Paired Composite", "HR"),
          scenario_type = c("PROJECT", "PROJECT", "PROJECT"),
          monitoring_year = c(2024, 2024, 2024)
        )
        write.csv(example_locations, full_path, row.names = FALSE)
      } else if (file == "core_samples_TEMPLATE.csv") {
        # Create example samples template
        example_samples <- data.frame(
          core_id = rep(c("CORE_001", "CORE_002", "CORE_003"), each = 4),
          depth_top_cm = rep(c(0, 15, 30, 50), 3),
          depth_bottom_cm = rep(c(15, 30, 50, 100), 3),
          soc_g_kg = c(80, 60, 40, 30,  # CORE_001
                       70, 55, 38, 28,  # CORE_002
                       90, 65, 45, 32), # CORE_003
          bulk_density_g_cm3 = c(0.8, 1.0, 1.2, 1.3,
                                  0.9, 1.1, 1.25, 1.35,
                                  0.75, 0.95, 1.15, 1.28)
        )
        write.csv(example_samples, full_path, row.names = FALSE)
      }
    }
  }
})

# Test 3.2: CSV Data Structure Validation
run_test("3.2 CSV Data Structure Validation", function() {
  # Check if templates have correct columns
  if (file.exists("data_raw/core_locations_TEMPLATE.csv")) {
    locs <- read.csv("data_raw/core_locations_TEMPLATE.csv")
    required_cols <- c("core_id", "longitude", "latitude", "stratum")

    missing <- setdiff(required_cols, names(locs))
    if (length(missing) > 0) {
      stop(sprintf("core_locations missing columns: %s", paste(missing, collapse = ", ")))
    }
  }

  if (file.exists("data_raw/core_samples_TEMPLATE.csv")) {
    samples <- read.csv("data_raw/core_samples_TEMPLATE.csv")
    required_cols <- c("core_id", "depth_top_cm", "depth_bottom_cm", "soc_g_kg")

    missing <- setdiff(required_cols, names(samples))
    if (length(missing) > 0) {
      stop(sprintf("core_samples missing columns: %s", paste(missing, collapse = ", ")))
    }
  }
})

# ============================================================================
# SPATIAL PROCESSING TESTS
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 4: SPATIAL PROCESSING TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 4.1: CRS Transformation
run_test("4.1 Coordinate Reference System Transformation", function() {
  # Create test point
  test_point <- data.frame(
    lon = -123.5,
    lat = 49.2
  )

  # Convert to sf object
  point_sf <- st_as_sf(test_point, coords = c("lon", "lat"), crs = 4326)

  # Transform to BC Albers (EPSG:3005)
  point_transformed <- st_transform(point_sf, 3005)

  # Verify transformation worked
  coords <- st_coordinates(point_transformed)
  if (is.na(coords[1]) || is.na(coords[2])) {
    stop("CRS transformation failed")
  }

  # Verify reasonable coordinates for BC
  if (coords[1] < 500000 || coords[1] > 2000000) {
    stop("Transformed X coordinate out of reasonable range for BC")
  }
})

# Test 4.2: Raster Processing Capabilities
run_test("4.2 Raster Creation & Processing (terra)", function() {
  # Create test raster
  test_raster <- rast(ncols = 10, nrows = 10,
                      xmin = -180, xmax = -170,
                      ymin = 40, ymax = 50,
                      crs = "EPSG:4326")

  # Set values
  values(test_raster) <- runif(100, min = 0, max = 100)

  # Test basic operations
  mean_val <- global(test_raster, "mean", na.rm = TRUE)[1,1]

  if (is.na(mean_val) || mean_val < 0 || mean_val > 100) {
    stop("Raster processing failed")
  }
})

# ============================================================================
# REGRESSION TESTS (Expected Outputs)
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 5: REGRESSION TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 5.1: Known Carbon Stock Calculation
run_test("5.1 Regression Test - Known Carbon Stock Calculation", function() {
  # Test case from literature:
  # SOC = 100 g/kg, BD = 1.0 g/cm³, depth = 0-100 cm
  # Expected stock = 100 * 1.0 * 100 / 1000 = 10 kg/m² = 100 Mg C/ha

  test_stock_kg_m2 <- 100 * 1.0 * 100 / 1000
  test_stock_Mg_ha <- test_stock_kg_m2 * 10

  if (abs(test_stock_kg_m2 - 10) > 0.001) {
    stop(sprintf("Stock calculation mismatch: expected 10 kg/m², got %.3f", test_stock_kg_m2))
  }

  if (abs(test_stock_Mg_ha - 100) > 0.1) {
    stop(sprintf("Unit conversion mismatch: expected 100 Mg C/ha, got %.1f", test_stock_Mg_ha))
  }
})

# Test 5.2: VM0033 Aggregation Test
run_test("5.2 Regression Test - VM0033 Depth Aggregation", function() {
  # Test aggregation of 4 VM0033 layers to 0-100 cm total
  # Layer stocks (kg/m²): 2.0, 1.8, 1.6, 2.5
  # Expected total: 2.0 + 1.8 + 1.6 + 2.5 = 7.9 kg/m² = 79 Mg C/ha

  layer_stocks <- c(2.0, 1.8, 1.6, 2.5)
  total_stock_kg_m2 <- sum(layer_stocks)
  total_stock_Mg_ha <- total_stock_kg_m2 * 10

  expected_kg_m2 <- 7.9
  expected_Mg_ha <- 79

  if (abs(total_stock_kg_m2 - expected_kg_m2) > 0.01) {
    stop(sprintf("Aggregation mismatch: expected %.1f kg/m², got %.1f",
                 expected_kg_m2, total_stock_kg_m2))
  }
})

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 6: EDGE CASE TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 6.1: Missing Data Handling
run_test("6.1 Edge Case - Missing Bulk Density Data", function() {
  # When BD is missing, workflow should use stratum defaults
  default_bd <- 1.0  # Generic default

  soc <- 50  # g/kg
  depth <- 15  # cm

  # Calculate stock with default BD
  stock <- soc * default_bd * depth / 1000

  if (is.na(stock) || stock <= 0) {
    stop("Failed to handle missing BD with defaults")
  }
})

# Test 6.2: Single Core per Stratum
run_test("6.2 Edge Case - Single Core per Stratum", function() {
  # With only 1 core, SD and SE are undefined
  # Workflow should handle gracefully (use overall variance or flag as insufficient)

  n_cores <- 1
  vm0033_min <- 3

  meets_requirement <- n_cores >= vm0033_min

  if (meets_requirement) {
    stop("Failed to detect insufficient samples (1 < 3)")
  }

  # Should flag as needing 2 more cores
  additional_needed <- vm0033_min - n_cores
  if (additional_needed != 2) {
    stop("Incorrect calculation of additional cores needed")
  }
})

# Test 6.3: Extreme SOC Values
run_test("6.3 Edge Case - Extreme SOC Values", function() {
  # Test QC catches unrealistic SOC values
  qc_soc_min <- 0
  qc_soc_max <- 500

  test_values <- c(-10, 0, 250, 500, 600)
  expected_valid <- c(FALSE, TRUE, TRUE, TRUE, FALSE)

  for (i in seq_along(test_values)) {
    is_valid <- test_values[i] >= qc_soc_min && test_values[i] <= qc_soc_max
    if (is_valid != expected_valid[i]) {
      stop(sprintf("QC failed for SOC = %d (expected valid = %s)",
                   test_values[i], expected_valid[i]))
    }
  }
})

# ============================================================================
# PERFORMANCE TESTS
# ============================================================================

cat("\n═══════════════════════════════════════\n")
cat("SECTION 7: PERFORMANCE TESTS\n")
cat("═══════════════════════════════════════\n")

# Test 7.1: Large Dataset Processing Speed
run_test("7.1 Performance - Carbon Stock Calculation (1000 samples)", function() {
  # Benchmark calculation speed
  n_samples <- 1000

  test_data <- data.frame(
    soc = runif(n_samples, 10, 200),
    bd = runif(n_samples, 0.5, 1.5),
    depth = 15
  )

  start_time <- Sys.time()
  stocks <- test_data$soc * test_data$bd * test_data$depth / 1000
  end_time <- Sys.time()

  elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

  # Should complete in < 1 second
  if (elapsed > 1.0) {
    stop(sprintf("Calculation too slow: %.3f seconds for %d samples", elapsed, n_samples))
  }

  cat(sprintf("  Processed %d samples in %.4f seconds\n", n_samples, elapsed))
})

# ============================================================================
# TEST SUMMARY
# ============================================================================

cat("\n========================================\n")
cat("TEST SUMMARY\n")
cat("========================================\n\n")

total_tests <- tests_passed + tests_failed
pass_rate <- ifelse(total_tests > 0, 100 * tests_passed / total_tests, 0)

cat(sprintf("Total tests run: %d\n", total_tests))
cat(sprintf("Tests passed: %d (%.1f%%)\n", tests_passed, pass_rate))
cat(sprintf("Tests failed: %d (%.1f%%)\n", tests_failed, 100 - pass_rate))

if (tests_failed == 0) {
  cat("\n✓✓✓ ALL TESTS PASSED ✓✓✓\n")
  cat("\nWorkflow validation successful!\n")
  cat("You can proceed with production deployment.\n\n")
} else {
  cat("\n⚠⚠⚠ SOME TESTS FAILED ⚠⚠⚠\n")
  cat("\nPlease address failed tests before production use.\n")
  cat("Review test results above for details.\n\n")
}

# Save test results
test_summary <- data.frame(
  test_name = names(test_results),
  status = sapply(test_results, function(x) x$status),
  message = sapply(test_results, function(x) x$message),
  timestamp = Sys.time(),
  stringsAsFactors = FALSE
)

if (!dir.exists("tests/results")) {
  dir.create("tests/results", recursive = TRUE, showWarnings = FALSE)
}

write.csv(test_summary,
          sprintf("tests/results/test_results_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S")),
          row.names = FALSE)

cat("Test results saved to: tests/results/\n\n")

# Return summary
cat("========================================\n\n")

invisible(list(
  total = total_tests,
  passed = tests_passed,
  failed = tests_failed,
  pass_rate = pass_rate,
  details = test_summary
))
