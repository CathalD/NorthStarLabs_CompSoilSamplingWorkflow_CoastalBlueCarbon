// ============================================================================
// GOOGLE EARTH ENGINE: EXPORT HYDROLOGY DATA FOR DOWNSTREAM IMPACT MODELING
// ============================================================================
// Purpose: Export DEM, climate, and hydrological data for downstream impact analysis
//
// Exports:
//   1. Digital Elevation Model (DEM) - SRTM 30m or ALOS 12.5m
//   2. Rainfall erosivity (optional - from CHIRPS precipitation)
//   3. Soil properties (optional - from SoilGrids)
//
// Instructions:
//   1. Draw your study area (or upload shapefile boundary)
//   2. Run script
//   3. Download exports from Google Drive
//   4. Place files in: data_raw/hydrology/
//
// Author: NorthStar Labs Blue Carbon Team
// Date: 2024-11
// ============================================================================

// ============================================================================
// 1. DEFINE STUDY AREA
// ============================================================================

// Option A: Draw a polygon manually using the geometry tools above
// (Name the geometry "studyArea")

// Option B: Load from existing asset
// var studyArea = ee.FeatureCollection('users/YOUR_USERNAME/YOUR_BOUNDARY');

// Option C: Use coordinates to create a rectangle
var studyArea = ee.Geometry.Rectangle([
  -123.76, 49.14,  // [west, south]
  -123.73, 49.16   // [east, north]
]);

// Set export CRS (should match PROCESSING_CRS in blue_carbon_config.R)
var exportCRS = 'EPSG:3347';  // Canada Albers Equal Area
// Alternatives:
// - EPSG:3005 (NAD83 / BC Albers)
// - EPSG:32610 (WGS 84 / UTM zone 10N for BC coast)

// Export resolution (meters)
var exportScale = 30;  // 30m for SRTM, or 12.5 for ALOS

// ============================================================================
// 2. LOAD & EXPORT DEM
// ============================================================================

// Option A: SRTM 30m (global coverage, adequate for most analyses)
var dem = ee.Image('USGS/SRTMGL1_003');

// Option B: ALOS PALSAR 12.5m (higher resolution, better for small catchments)
// var dem = ee.Image('JAXA/ALOS/AW3D30/V3_2').select('DSM');

// Option C: NASADEM 30m (improved version of SRTM)
// var dem = ee.Image('NASA/NASADEM_HGT/001').select('elevation');

// Clip to study area
dem = dem.clip(studyArea);

// Visualize
Map.centerObject(studyArea, 12);
Map.addLayer(dem, {min: 0, max: 200, palette: ['blue', 'green', 'yellow', 'red']}, 'DEM');
Map.addLayer(studyArea, {color: 'red'}, 'Study Area', false);

// Export DEM
Export.image.toDrive({
  image: dem,
  description: 'DEM_export',
  folder: 'BlueCarbon_Hydrology',
  fileNamePrefix: 'dem',
  region: studyArea,
  scale: exportScale,
  crs: exportCRS,
  maxPixels: 1e9
});

print('✓ DEM export task created');

// ============================================================================
// 3. COMPUTE & EXPORT TOPOGRAPHIC DERIVATIVES
// ============================================================================

// Slope (degrees)
var slope = ee.Terrain.slope(dem);

Export.image.toDrive({
  image: slope,
  description: 'Slope_export',
  folder: 'BlueCarbon_Hydrology',
  fileNamePrefix: 'slope',
  region: studyArea,
  scale: exportScale,
  crs: exportCRS,
  maxPixels: 1e9
});

print('✓ Slope export task created');

// Aspect (degrees)
var aspect = ee.Terrain.aspect(dem);

Export.image.toDrive({
  image: aspect,
  description: 'Aspect_export',
  folder: 'BlueCarbon_Hydrology',
  fileNamePrefix: 'aspect',
  region: studyArea,
  scale: exportScale,
  crs: exportCRS,
  maxPixels: 1e9
});

print('✓ Aspect export task created');

// ============================================================================
// 4. RAINFALL EROSIVITY (OPTIONAL - for RUSLE R factor)
// ============================================================================

// Compute rainfall erosivity from CHIRPS precipitation
// R factor approximation: R ≈ 38.5 + 0.35 × MAP (where MAP = mean annual precip)
// More accurate: use Brown & Foster (1987) or regional equations

var chirps = ee.ImageCollection('UCSB-CHG/CHIRPS/DAILY')
  .filterBounds(studyArea)
  .filterDate('2015-01-01', '2024-12-31');  // 10-year climatology

var totalPrecip = chirps.sum();
var meanAnnualPrecip = totalPrecip.divide(10);  // mm/yr

// Simple R factor approximation for temperate regions
var rainfallErosivity = meanAnnualPrecip.multiply(0.35).add(38.5);

rainfallErosivity = rainfallErosivity.clip(studyArea);

Map.addLayer(rainfallErosivity, {min: 300, max: 800, palette: ['white', 'blue', 'darkblue']},
             'Rainfall Erosivity (R factor)', false);

Export.image.toDrive({
  image: rainfallErosivity,
  description: 'RainfallErosivity_export',
  folder: 'BlueCarbon_Hydrology',
  fileNamePrefix: 'rainfall_erosivity',
  region: studyArea,
  scale: exportScale,
  crs: exportCRS,
  maxPixels: 1e9
});

print('✓ Rainfall erosivity export task created');

// ============================================================================
// 5. SOIL PROPERTIES (OPTIONAL - from SoilGrids)
// ============================================================================

// Soil texture / erodibility proxy (clay content at 0-5 cm depth)
var soilGrids = ee.Image('projects/soilgrids-isric/clay_0-5cm_mean');
var clayCont = soilGrids.clip(studyArea);

Export.image.toDrive({
  image: clayCont,
  description: 'SoilClay_export',
  folder: 'BlueCarbon_Hydrology',
  fileNamePrefix: 'soil_clay_content',
  region: studyArea,
  scale: 250,  // SoilGrids native resolution
  crs: exportCRS,
  maxPixels: 1e9
});

print('✓ Soil clay content export task created');

// ============================================================================
// 6. LAND COVER (if not already exported from main workflow)
// ============================================================================

// Sentinel-2 composite for landcover context
var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(studyArea)
  .filterDate('2023-01-01', '2023-12-31')
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', 20))
  .select(['B2', 'B3', 'B4', 'B8']);

var s2Composite = s2.median().clip(studyArea);

var visParams = {bands: ['B4', 'B3', 'B2'], min: 0, max: 3000};
Map.addLayer(s2Composite, visParams, 'Sentinel-2 Composite', false);

Export.image.toDrive({
  image: s2Composite,
  description: 'Sentinel2_Composite_export',
  folder: 'BlueCarbon_Hydrology',
  fileNamePrefix: 'sentinel2_composite',
  region: studyArea,
  scale: 10,
  crs: exportCRS,
  maxPixels: 1e9
});

print('✓ Sentinel-2 composite export task created');

// ============================================================================
// 7. INSTRUCTIONS
// ============================================================================

print('');
print('═══════════════════════════════════════════════════════');
print('  HYDROLOGY DATA EXPORT READY');
print('═══════════════════════════════════════════════════════');
print('');
print('Export tasks have been created. To run them:');
print('  1. Click "Tasks" tab in the right panel');
print('  2. Click "RUN" for each export task');
print('  3. Confirm export settings');
print('  4. Wait for exports to complete (check Google Drive)');
print('  5. Download all files from "BlueCarbon_Hydrology" folder');
print('  6. Place files in: data_raw/hydrology/');
print('');
print('Required files for Module 11:');
print('  ✓ dem.tif              (required)');
print('  ✓ slope.tif            (recommended)');
print('  ○ rainfall_erosivity.tif  (optional - use default if missing)');
print('  ○ soil_clay_content.tif   (optional)');
print('');
print('After downloading, proceed with:');
print('  source("11_downstream_impacts.R")');
print('');
print('═══════════════════════════════════════════════════════');
