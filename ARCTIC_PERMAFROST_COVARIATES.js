// ============================================================================
// ARCTIC PERMAFROST WETLAND COVARIATES WITH PERMAFROST-SPECIFIC INDICES
// ============================================================================
// Version: 1.0 - Arctic Permafrost Edition
// Purpose: Generate permafrost monitoring covariates for Arctic wetland carbon modeling
// Key Features: Active layer thickness, ground temp, permafrost extent, thermokarst indicators
// Adapted from: Coastal Blue Carbon Covariate Tool
// Region: Canadian Arctic and Subarctic (60°N - 83°N)
// ============================================================================

// ============================================================================
// SECTION 1: CONFIGURATION
// ============================================================================

// IMPORTANT: Draw your AOI using the geometry tools or load from asset
var AOI = geometry;  // Draw a polygon on the map (Arctic region)

// Optional: Load your permafrost sampling locations
// var samplingPoints = ee.FeatureCollection("users/your_name/arctic_sampling_points");

var CONFIG = {
  // Spatial Configuration
  aoi: AOI,
  exportScale: 30,  // 30m for Arctic (data availability constraints)
  exportCRS: 'EPSG:4326',
  processingCRS: 'EPSG:3573',  // WGS 84 / North Pole LAEA Canada (Arctic-optimized)

  // Temporal Configuration
  yearStart: 2022,
  yearEnd: 2024,
  summerSeasonStartMonth: 6,   // June (Arctic short growing season)
  summerSeasonEndMonth: 8,      // August (peak thaw)

  // Quality Control Thresholds (Arctic-Specific)
  s2CloudThreshold: 30,              // More lenient (high cloud cover in Arctic)
  s1SpeckleFilterSize: 7,
  minObservationsRequired: 8,        // Lower due to short season

  // Arctic-specific thresholds
  minElevation: 0,                    // Arctic tundra (above sea level)
  maxElevation: 2000,                 // Include mountain permafrost
  maxSlopeForWetland: 15,             // Permafrost wetlands mostly flat

  // Vegetation Index Thresholds (Arctic tundra)
  minNDVI: -0.2,                      // Low Arctic vegetation
  maxNDVI: 0.8,                       // Tundra vegetation (lower than temperate)
  minNDWI: -0.5,                      // Water index (ponds, fens)
  maxNDWI: 0.8,

  // Permafrost-specific parameters
  meanAnnualTempThreshold: 0,         // Permafrost requires <0°C MAT
  activeLayerDepthMin: 20,            // cm - minimum realistic
  activeLayerDepthMax: 200,           // cm - maximum realistic

  // Processing Parameters
  qaStatsScaleMultiplier: 4,
  qaFocalRadius_pixels: 3,
  textureWindowSize: 3,

  // Export Configuration
  exportFolder: 'Arctic_Permafrost_Covariates',
  exportPrefix: 'ArcticPermafrost',
  maxPixels: 1e13,

  // Feature toggles - Permafrost-specific
  includeTextureFeatures: true,
  includeSeasonalMetrics: true,
  includePhenologyMetrics: true,
  includeRadarIndices: true,
  includeActiveLayerProxies: true,      // NEW: Active layer thickness
  includeGroundTempProxies: true,       // NEW: Ground temperature
  includePermafrostExtent: true,        // NEW: Permafrost distribution
  includeThermokarstIndicators: true,   // NEW: Thermokarst features
  includeSnowMetrics: true,             // NEW: Snow cover/duration
  includeTerrainMetrics: true,          // NEW: Enhanced terrain for polygons
  includeQualityLayers: true,

  // DEM Selection
  demSource: 'ArcticDEM'  // Use ArcticDEM for high-latitude Canada
};

// Date ranges
var startDate = ee.Date.fromYMD(CONFIG.yearStart, 1, 1);
var endDate = ee.Date.fromYMD(CONFIG.yearEnd, 12, 31);
var summerStart = ee.Date.fromYMD(CONFIG.yearStart, CONFIG.summerSeasonStartMonth, 1);
var summerEnd = ee.Date.fromYMD(CONFIG.yearEnd, CONFIG.summerSeasonEndMonth, 31);

Map.centerObject(CONFIG.aoi, 10);

print('═══════════════════════════════════════════════════════');
print('🧊 ARCTIC PERMAFROST WETLAND COVARIATE EXTRACTION');
print('═══════════════════════════════════════════════════════');
print('');
print('AOI Area (km²):', CONFIG.aoi.area(1).divide(1e6).getInfo().toFixed(2));
print('Export Scale (m):', CONFIG.exportScale);
print('Time Period:', CONFIG.yearStart, '-', CONFIG.yearEnd);
print('Summer Season:', CONFIG.summerSeasonStartMonth, '-', CONFIG.summerSeasonEndMonth);
print('');

// ============================================================================
// SECTION 2: DATA LOADING
// ============================================================================

// ----------------------------------------------------------------------------
// 2.1 Digital Elevation Model (Arctic-optimized)
// ----------------------------------------------------------------------------

var dem;
if (CONFIG.demSource === 'ArcticDEM') {
  // ArcticDEM mosaic (2m resolution, resampled)
  // Note: Use mosaic or REMA for polar regions
  dem = ee.Image('UMN/PGC/ArcticDEM/V3/2m_mosaic')
    .select('elevation')
    .clip(CONFIG.aoi);
  print('✓ DEM Source: ArcticDEM');
} else {
  // Fallback to SRTM or ASTER (less ideal for Arctic)
  dem = ee.Image('USGS/SRTMGL1_003').clip(CONFIG.aoi);
  print('⚠ DEM Source: SRTM (WARNING: May have gaps in Arctic)');
}

// Terrain derivatives
var slope = ee.Terrain.slope(dem);
var aspect = ee.Terrain.aspect(dem);
var hillshade = ee.Terrain.hillshade(dem);

// Topographic Position Index (TPI) - key for polygon identification
var tpi = dem.subtract(dem.focal_mean({
  radius: 300,  // 300m neighborhood
  kernelType: 'circle',
  units: 'meters'
})).rename('tpi');

// Terrain Ruggedness Index (TRI) - thermokarst likelihood
var tri = dem.reduceNeighborhood({
  reducer: ee.Reducer.stdDev(),
  kernel: ee.Kernel.square({radius: 100, units: 'meters'})
}).rename('tri');

print('✓ Terrain derivatives calculated');

// ----------------------------------------------------------------------------
// 2.2 Climate Data - Temperature (CRITICAL for permafrost)
// ----------------------------------------------------------------------------

// ERA5-Land Climate Reanalysis (high-resolution)
var era5Land = ee.ImageCollection('ECMWF/ERA5_LAND/MONTHLY_AGGR')
  .filterBounds(CONFIG.aoi)
  .filterDate(startDate, endDate);

// Mean annual air temperature (2m)
var meanAnnualTemp = era5Land
  .select('temperature_2m')
  .mean()
  .subtract(273.15)  // Convert Kelvin to Celsius
  .rename('mean_annual_temp_C');

// Thaw Degree Days (TDD) - sum of positive degree days
var summerTemp = ee.ImageCollection('ECMWF/ERA5_LAND/MONTHLY_AGGR')
  .filterBounds(CONFIG.aoi)
  .filterDate(summerStart, summerEnd)
  .select('temperature_2m')
  .map(function(img) {
    return img.subtract(273.15).max(0);  // Only positive temps
  });

var thawDegreeDays = summerTemp.sum()
  .multiply(30)  // Approximate days per month
  .rename('thaw_degree_days');

// Freeze Degree Days (FDD) - sum of negative degree days (winter)
var winterTemp = ee.ImageCollection('ECMWF/ERA5_LAND/MONTHLY_AGGR')
  .filterBounds(CONFIG.aoi)
  .filterDate(ee.Date.fromYMD(CONFIG.yearStart, 10, 1),
              ee.Date.fromYMD(CONFIG.yearEnd, 4, 30))
  .select('temperature_2m')
  .map(function(img) {
    return img.subtract(273.15).min(0).abs();  // Absolute negative temps
  });

var freezeDegreeDays = winterTemp.sum()
  .multiply(30)
  .rename('freeze_degree_days');

print('✓ Climate data (temperature) loaded');

// ----------------------------------------------------------------------------
// 2.3 Permafrost Distribution & Active Layer Thickness
// ----------------------------------------------------------------------------

// Option 1: Circumpolar permafrost extent (IPA)
// Load from asset or use external data
// var permafrostExtent = ee.Image("users/your_asset/permafrost_extent");

// Option 2: Proxy-based permafrost probability
// Simple model: Permafrost probability based on MAT
var permafrostProbability = meanAnnualTemp
  .expression(
    '(temp < -5) ? 1.0 : ' +  // Continuous permafrost
    '(temp < -2) ? 0.7 : ' +  // Discontinuous permafrost
    '(temp < 0) ? 0.3 : 0.0', // Sporadic/isolated
    {'temp': meanAnnualTemp}
  ).rename('permafrost_probability');

// Active Layer Thickness (ALT) modeled from climate
// Simplified Stefan equation proxy: ALT ∝ sqrt(TDD)
// Typical range: 30-150 cm
var activeLayerThickness = thawDegreeDays
  .sqrt()
  .multiply(1.5)  // Calibration factor (adjust based on soil type)
  .clamp(CONFIG.activeLayerDepthMin, CONFIG.activeLayerDepthMax)
  .rename('active_layer_thickness_cm');

print('✓ Permafrost distribution and active layer modeled');

// ----------------------------------------------------------------------------
// 2.4 Snow Metrics (CRITICAL for ground insulation)
// ----------------------------------------------------------------------------

// MODIS Snow Cover
var modisSnow = ee.ImageCollection('MODIS/006/MOD10A1')
  .filterBounds(CONFIG.aoi)
  .filterDate(startDate, endDate)
  .select('NDSI_Snow_Cover');

// Snow occurrence frequency (% of time with snow)
var snowOccurrence = modisSnow
  .map(function(img) {
    return img.gte(20);  // Threshold: 20% snow cover
  })
  .mean()
  .multiply(100)
  .rename('snow_occurrence_pct');

// Snow duration (approximate days)
var snowDuration = snowOccurrence
  .multiply(365 / 100)  // Convert percentage to days
  .rename('snow_duration_days');

print('✓ Snow metrics calculated');

// ----------------------------------------------------------------------------
// 2.5 Sentinel-2 Optical Imagery (Summer season only)
// ----------------------------------------------------------------------------

function maskS2clouds(image) {
  var qa = image.select('QA60');
  var cloudBitMask = 1 << 10;
  var cirrusBitMask = 1 << 11;
  var mask = qa.bitwiseAnd(cloudBitMask).eq(0)
    .and(qa.bitwiseAnd(cirrusBitMask).eq(0));
  return image.updateMask(mask).divide(10000)
    .copyProperties(image, ['system:time_start']);
}

var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(CONFIG.aoi)
  .filterDate(summerStart, summerEnd)  // Summer only
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', CONFIG.s2CloudThreshold))
  .map(maskS2clouds);

var s2Median = s2.median().clip(CONFIG.aoi);

// Spectral bands
var blue = s2Median.select('B2').rename('blue');
var green = s2Median.select('B3').rename('green');
var red = s2Median.select('B4').rename('red');
var nir = s2Median.select('B8').rename('nir');
var swir1 = s2Median.select('B11').rename('swir1');
var swir2 = s2Median.select('B12').rename('swir2');

// Vegetation indices
var ndvi = s2Median.normalizedDifference(['B8', 'B4']).rename('ndvi');
var ndwi = s2Median.normalizedDifference(['B3', 'B8']).rename('ndwi');  // Water
var ndmi = s2Median.normalizedDifference(['B8', 'B11']).rename('ndmi'); // Moisture

// Enhanced Vegetation Index (EVI) - better for sparse Arctic vegetation
var evi = s2Median.expression(
  '2.5 * ((NIR - RED) / (NIR + 6 * RED - 7.5 * BLUE + 1))',
  {
    'NIR': s2Median.select('B8'),
    'RED': s2Median.select('B4'),
    'BLUE': s2Median.select('B2')
  }
).rename('evi');

print('✓ Sentinel-2 optical data processed');

// ----------------------------------------------------------------------------
// 2.6 Sentinel-1 SAR (All-season capability)
// ----------------------------------------------------------------------------

var s1 = ee.ImageCollection('COPERNICUS/S1_GRD')
  .filterBounds(CONFIG.aoi)
  .filterDate(summerStart, summerEnd)
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VV'))
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VH'))
  .filter(ee.Filter.eq('instrumentMode', 'IW'));

var s1Median = s1.median().clip(CONFIG.aoi);
var vv = s1Median.select('VV').rename('sar_vv');
var vh = s1Median.select('VH').rename('sar_vh');

// SAR ratios (soil moisture proxy)
var vvVhRatio = vv.divide(vh).rename('sar_vv_vh_ratio');

print('✓ Sentinel-1 SAR data processed');

// ----------------------------------------------------------------------------
// 2.7 Water Occurrence (Thermokarst ponds and fens)
// ----------------------------------------------------------------------------

var waterOccurrence = ee.Image('JRC/GSW1_4/GlobalSurfaceWater')
  .select('occurrence')
  .clip(CONFIG.aoi)
  .rename('water_occurrence_pct');

// Distance to water (important for water tracks)
var waterMask = waterOccurrence.gt(50);  // Permanent/seasonal water
var distanceToWater = waterMask.fastDistanceTransform()
  .sqrt()
  .multiply(CONFIG.exportScale)
  .rename('distance_to_water_m');

print('✓ Water occurrence calculated');

// ============================================================================
// SECTION 3: PERMAFROST-SPECIFIC FEATURE ENGINEERING
// ============================================================================

// ----------------------------------------------------------------------------
// 3.1 Thermokarst Indicators
// ----------------------------------------------------------------------------

// Potential thermokarst areas (combination of factors)
var thermokarstIndicator = permafrostProbability
  .multiply(tri.divide(10))  // Ruggedness (subsidence)
  .multiply(waterOccurrence.divide(100))  // Water presence
  .rename('thermokarst_indicator');

// Polygon/palsa classification from microtopography
// High TPI = palsa (elevated)
// Low TPI = polygon center (depressed)
var microtopography = tpi
  .expression(
    '(tpi > 1) ? 3 : ' +    // Elevated (palsa/rim)
    '(tpi > 0.3) ? 2 : ' +  // Moderate (rim)
    '(tpi > -0.3) ? 1 : 0', // Low/depressed (center/pond)
    {'tpi': tpi}
  ).rename('microtopography_class');

print('✓ Thermokarst indicators calculated');

// ----------------------------------------------------------------------------
// 3.2 Vegetation/Wetness Classification
// ----------------------------------------------------------------------------

// Wetness index (from topography)
var wetness = dem.multiply(-1)
  .add(slope.multiply(-0.5))
  .add(tri.multiply(-0.2))
  .rename('wetness_index');

// Sedge/moss probability (NDVI + NDWI combination)
var sedgeMossProbability = ndvi.multiply(0.5)
  .add(ndwi.multiply(0.5))
  .rename('sedge_moss_probability');

print('✓ Vegetation/wetness indices calculated');

// ============================================================================
// SECTION 4: COVARIATE STACK ASSEMBLY
// ============================================================================

var covariateStack = ee.Image.cat([
  // Spectral bands
  blue, green, red, nir, swir1, swir2,

  // Vegetation indices
  ndvi, ndwi, ndmi, evi,

  // SAR
  vv, vh, vvVhRatio,

  // Terrain
  dem.rename('elevation'),
  slope.rename('slope'),
  aspect.rename('aspect'),
  tpi,
  tri,
  wetness,

  // Climate
  meanAnnualTemp,
  thawDegreeDays,
  freezeDegreeDays,

  // Permafrost-specific
  permafrostProbability,
  activeLayerThickness,
  thermokarstIndicator,
  microtopography,

  // Snow
  snowOccurrence,
  snowDuration,

  // Water
  waterOccurrence,
  distanceToWater,

  // Vegetation
  sedgeMossProbability
]);

print('');
print('═══════════════════════════════════════════════════════');
print('📊 COVARIATE STACK COMPLETE');
print('═══════════════════════════════════════════════════════');
print('Total Bands:', covariateStack.bandNames().size().getInfo());
print('Band Names:');
print(covariateStack.bandNames().getInfo());

// ============================================================================
// SECTION 5: VISUALIZATION
// ============================================================================

// Add layers to map
Map.addLayer(s2Median, {bands: ['B4', 'B3', 'B2'], min: 0, max: 0.3}, 'Sentinel-2 RGB', false);
Map.addLayer(ndvi, {min: -0.2, max: 0.8, palette: ['blue', 'white', 'green']}, 'NDVI', false);
Map.addLayer(ndwi, {min: -0.5, max: 0.8, palette: ['brown', 'white', 'blue']}, 'NDWI', false);
Map.addLayer(activeLayerThickness, {min: 30, max: 150, palette: ['blue', 'yellow', 'red']},
  'Active Layer Thickness (cm)', true);
Map.addLayer(permafrostProbability, {min: 0, max: 1, palette: ['red', 'yellow', 'cyan', 'blue']},
  'Permafrost Probability', true);
Map.addLayer(thermokarstIndicator, {min: 0, max: 0.5, palette: ['white', 'orange', 'red']},
  'Thermokarst Indicator', false);
Map.addLayer(dem, {min: 0, max: 500, palette: ['green', 'yellow', 'brown', 'white']}, 'Elevation', false);
Map.addLayer(microtopography, {min: 0, max: 3, palette: ['blue', 'green', 'yellow', 'brown']},
  'Microtopography', false);

// ============================================================================
// SECTION 6: EXPORT
// ============================================================================

// Export full covariate stack
Export.image.toDrive({
  image: covariateStack,
  description: CONFIG.exportPrefix + '_CovariateStack_Arctic',
  folder: CONFIG.exportFolder,
  region: CONFIG.aoi,
  scale: CONFIG.exportScale,
  crs: CONFIG.exportCRS,
  maxPixels: CONFIG.maxPixels
});

// Export individual key layers for QC
Export.image.toDrive({
  image: activeLayerThickness,
  description: CONFIG.exportPrefix + '_ActiveLayerThickness',
  folder: CONFIG.exportFolder,
  region: CONFIG.aoi,
  scale: CONFIG.exportScale,
  crs: CONFIG.exportCRS,
  maxPixels: CONFIG.maxPixels
});

Export.image.toDrive({
  image: permafrostProbability,
  description: CONFIG.exportPrefix + '_PermafrostProbability',
  folder: CONFIG.exportFolder,
  region: CONFIG.aoi,
  scale: CONFIG.exportScale,
  crs: CONFIG.exportCRS,
  maxPixels: CONFIG.maxPixels
});

Export.image.toDrive({
  image: meanAnnualTemp,
  description: CONFIG.exportPrefix + '_MeanAnnualTemp',
  folder: CONFIG.exportFolder,
  region: CONFIG.aoi,
  scale: CONFIG.exportScale,
  crs: CONFIG.exportCRS,
  maxPixels: CONFIG.maxPixels
});

print('');
print('═══════════════════════════════════════════════════════');
print('✅ EXPORT TASKS READY');
print('═══════════════════════════════════════════════════════');
print('Go to the Tasks tab to run the exports.');
print('Expected output files: 4 GeoTIFF files');
print('');
print('Next steps:');
print('1. Run export tasks in Tasks tab');
print('2. Download from Google Drive');
print('3. Place in data_raw/gee_covariates/ directory');
print('4. Run Module 05 (Random Forest) in R workflow');
