// ============================================================================
// JANOUSEK BLUE CARBON CORE LOCATIONS - COVARIATE EXTRACTION WITH QA/QC
// ============================================================================
// Version: 1.0 - Transfer Learning Global Model
// Purpose: Extract covariates at 1,284 Pacific coast blue carbon cores
// Dataset: Janousek et al. 2025, Global Biogeochemical Cycles
// Use: Training large-scale model for transfer learning (Module 00d)
// ============================================================================

// ============================================================================
// SECTION 1: CONFIGURATION
// ============================================================================

// IMPORTANT: Upload your Janousek core locations CSV to GEE as an asset first
// Go to Assets tab → New → Table Upload → janousek_harmonized_bluecarbon.csv
// Then replace 'users/YOUR_USERNAME/janousek_cores' below with your asset path

var cores = ee.FeatureCollection('users/YOUR_USERNAME/janousek_cores');

// If you don't have the asset uploaded yet, you can create points manually:
// var cores = ee.FeatureCollection([
//   ee.Feature(ee.Geometry.Point([-122.5, 37.8]), {sample_id: 'test1'}),
//   // ... add more points
// ]);

// Visualize core locations
Map.addLayer(cores, {color: 'red'}, 'Janousek Core Locations', true);
Map.centerObject(cores, 5);

print('Core locations loaded:', cores.size());

var CONFIG = {
  // Spatial Configuration
  cores: cores,
  bufferRadius: 50,                  // Buffer around each point (meters) for neighborhood stats
  exportScale: 30,                   // Resolution for imagery-based covariates
  exportCRS: 'EPSG:4326',

  // Temporal Configuration
  yearStart: 2020,                   // Match Janousek data collection period
  yearEnd: 2023,
  growingSeasonStartMonth: 5,
  growingSeasonEndMonth: 9,

  // Quality Control Thresholds
  s2CloudThreshold: 20,
  s1SpeckleFilterSize: 7,
  minObservationsRequired: 5,        // Lower for coastal areas with frequent clouds

  // Vegetation Index Thresholds
  minNDVI: -0.2,
  maxNDVI: 1.0,
  minEVI: -0.5,
  maxEVI: 1.5,

  // SAR Thresholds (dB)
  minVV: -30,
  maxVV: 5,
  minVH: -35,
  maxVH: 0,

  // Temperature Thresholds (Celsius)
  minLST: -50,
  maxLST: 60,

  // Export Configuration
  exportFolder: 'Janousek_Covariates_Individual_Bands',
  exportPrefix: 'Janousek',

  // Feature toggles
  includeClimate: true,
  includeTopography: true,
  includeOptical: true,
  includeThermal: true,
  includeSAR: true,
  includeSoilGrids: true,
  includeCoastal: true,
  includeQualityLayers: true,

  // DEM Selection (for coastal areas, use best available)
  demSource: 'NASADEM'  // Options: 'NASADEM', 'SRTM', 'ALOS'
};

// Date ranges
var startDate = ee.Date.fromYMD(CONFIG.yearStart, 1, 1);
var endDate = ee.Date.fromYMD(CONFIG.yearEnd, 12, 31);
var growingSeasonStart = ee.Date.fromYMD(CONFIG.yearStart, CONFIG.growingSeasonStartMonth, 1);
var growingSeasonEnd = ee.Date.fromYMD(CONFIG.yearEnd, CONFIG.growingSeasonEndMonth, 30);

print('=== CONFIGURATION ===');
print('Cores:', CONFIG.cores.size());
print('Date Range:', CONFIG.yearStart, '-', CONFIG.yearEnd);
print('Export Scale:', CONFIG.exportScale, 'm');
print('QA/QC: ENABLED');

// ============================================================================
// SECTION 2: CLIMATE FEATURES (WORLDCLIM)
// ============================================================================

print('\n=== Processing Climate Features ===');

var worldclim = ee.Image('WORLDCLIM/V1/BIO');

var climateFeatures = ee.Image.cat([
  worldclim.select('bio01').divide(10).rename('MAT_C'),           // Mean Annual Temperature
  worldclim.select('bio12').rename('MAP_mm'),                     // Mean Annual Precipitation
  worldclim.select('bio04').divide(100).rename('temp_seasonality'), // Temperature seasonality
  worldclim.select('bio15').rename('precip_seasonality'),         // Precipitation seasonality
  worldclim.select('bio05').divide(10).rename('max_temp_warmest_month_C'),
  worldclim.select('bio06').divide(10).rename('min_temp_coldest_month_C'),
  worldclim.select('bio13').rename('precip_wettest_month_mm'),
  worldclim.select('bio14').rename('precip_driest_month_mm')
]);

print('✓ Climate features:', climateFeatures.bandNames());

// ============================================================================
// SECTION 3: TOPOGRAPHIC FEATURES WITH QA
// ============================================================================

print('\n=== Processing Topographic Features ===');

var elevation, dem;

if (CONFIG.demSource === 'NASADEM') {
  dem = ee.Image('NASA/NASADEM_HGT/001');
  elevation = dem.select('elevation').rename('elevation_m');
} else if (CONFIG.demSource === 'SRTM') {
  dem = ee.Image('USGS/SRTMGL1_003');
  elevation = dem.select('elevation').rename('elevation_m');
} else if (CONFIG.demSource === 'ALOS') {
  dem = ee.Image('JAXA/ALOS/AW3D30/V3_2');
  elevation = dem.select('DSM').rename('elevation_m');
}

// Calculate terrain derivatives
var slope = ee.Terrain.slope(elevation).rename('slope_degrees');
var aspect = ee.Terrain.aspect(elevation).rename('aspect_degrees');

// Topographic Position Index
var tpi = elevation.subtract(
  elevation.focal_mean(500, 'circle', 'meters')
).rename('TPI_500m');

// Terrain Ruggedness Index
var tri = elevation.subtract(
  elevation.focal_median(3, 'square', 'pixels')
).abs().rename('TRI');

// Aspect transformations
var aspectNorth = aspect.subtract(180).abs().divide(180).rename('aspect_northness');
var aspectEast = aspect.subtract(90).abs().divide(90).rename('aspect_eastness');

var topographicFeatures = ee.Image.cat([
  elevation, slope, aspect, tpi, tri, aspectNorth, aspectEast
]);

print('✓ Topographic features:', topographicFeatures.bandNames());

// ============================================================================
// SECTION 4: SENTINEL-2 OPTICAL FEATURES WITH QA
// ============================================================================

print('\n=== Processing Sentinel-2 Optical ===');

function maskS2clouds(image) {
  var qa = image.select('QA60');
  var cloudBitMask = 1 << 10;
  var cirrusBitMask = 1 << 11;
  var mask = qa.bitwiseAnd(cloudBitMask).eq(0)
      .and(qa.bitwiseAnd(cirrusBitMask).eq(0));
  return image.updateMask(mask).divide(10000);
}

function addS2Indices(image) {
  // Enhanced Vegetation Index (EVI)
  var evi = image.expression(
    '2.5 * ((NIR - RED) / (NIR + 6 * RED - 7.5 * BLUE + 1))',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4'),
      'BLUE': image.select('B2')
    }).rename('EVI');

  var ndvi = image.normalizedDifference(['B8', 'B4']).rename('NDVI');
  var ndmi = image.normalizedDifference(['B8', 'B11']).rename('NDMI');
  var ndre = image.normalizedDifference(['B8', 'B5']).rename('NDRE');
  var ndwi = image.normalizedDifference(['B3', 'B8']).rename('NDWI');

  // Green Chlorophyll Index
  var gci = image.expression('(NIR / GREEN) - 1', {
    'NIR': image.select('B8'),
    'GREEN': image.select('B3')
  }).rename('GCI');

  // Soil-Adjusted Vegetation Index
  var savi = image.expression(
    '((NIR - RED) / (NIR + RED + 0.5)) * 1.5',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4')
    }).rename('SAVI');

  return image.addBands([evi, ndvi, ndmi, ndre, ndwi, gci, savi]);
}

var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(CONFIG.cores)
  .filterDate(startDate, endDate)
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', CONFIG.s2CloudThreshold))
  .map(maskS2clouds)
  .map(addS2Indices);

print('Sentinel-2 images:', s2.size());

var s2_growing = s2.filterDate(growingSeasonStart, growingSeasonEnd);

var opticalMetrics = ee.Image.cat([
  // Annual metrics
  s2.select('EVI').median().rename('EVI_median_annual'),
  s2.select('NDVI').median().rename('NDVI_median_annual'),
  s2.select('NDMI').median().rename('NDMI_median_annual'),
  s2.select('NDRE').median().rename('NDRE_median_annual'),
  s2.select('NDWI').median().rename('NDWI_median_annual'),
  s2.select('GCI').median().rename('GCI_median_annual'),
  s2.select('SAVI').median().rename('SAVI_median_annual'),

  // Growing season metrics
  s2_growing.select('EVI').median().rename('EVI_median_growing'),
  s2_growing.select('NDVI').median().rename('NDVI_median_growing'),
  s2_growing.select('NDVI').mean().rename('NDVI_mean_growing'),

  // Variability metrics
  s2.select('EVI').reduce(ee.Reducer.stdDev()).rename('EVI_stddev_annual'),
  s2.select('NDVI').reduce(ee.Reducer.stdDev()).rename('NDVI_stddev_annual'),

  // Phenology metrics
  s2.select('EVI').reduce(ee.Reducer.percentile([10, 25, 75, 90]))
    .rename(['EVI_p10', 'EVI_p25', 'EVI_p75', 'EVI_p90']),

  // Amplitude
  s2.select('EVI').max().subtract(s2.select('EVI').min()).rename('EVI_amplitude'),

  // Observation count
  s2.select('EVI').count().rename('S2_obs_count')
]);

print('✓ Optical metrics:', opticalMetrics.bandNames());

// ============================================================================
// SECTION 5: LANDSAT THERMAL FEATURES WITH QA
// ============================================================================

print('\n=== Processing Landsat Thermal ===');

function maskLandsatClouds(image) {
  var qa = image.select('QA_PIXEL');
  var cloudMask = qa.bitwiseAnd(1 << 3).eq(0)
    .and(qa.bitwiseAnd(1 << 4).eq(0));
  return image.updateMask(cloudMask);
}

function calculateLST(image) {
  var lst = image.select('ST_B10').multiply(0.00341802).add(149.0).subtract(273.15);
  return image.addBands(lst.rename('LST_C'));
}

var landsat8 = ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
  .merge(ee.ImageCollection('LANDSAT/LC09/C02/T1_L2'))
  .filterBounds(CONFIG.cores)
  .filterDate(startDate, endDate)
  .map(maskLandsatClouds)
  .map(calculateLST);

print('Landsat images:', landsat8.size());

var landsat8_growing = landsat8.filterDate(growingSeasonStart, growingSeasonEnd);

var thermalMetrics = ee.Image.cat([
  landsat8.select('LST_C').median().rename('LST_median_annual_C'),
  landsat8.select('LST_C').mean().rename('LST_mean_annual_C'),
  landsat8.select('LST_C').reduce(ee.Reducer.stdDev()).rename('LST_stddev_annual_C'),
  landsat8.select('LST_C').reduce(ee.Reducer.percentile([10, 90]))
    .rename(['LST_p10_annual_C', 'LST_p90_annual_C']),
  landsat8_growing.select('LST_C').median().rename('LST_median_growing_C'),
  landsat8_growing.select('LST_C').mean().rename('LST_mean_growing_C'),
  landsat8.select('LST_C').count().rename('L8_obs_count')
]);

print('✓ Thermal metrics:', thermalMetrics.bandNames());

// ============================================================================
// SECTION 6: SENTINEL-1 SAR FEATURES WITH QA
// ============================================================================

print('\n=== Processing Sentinel-1 SAR ===');

function applySpeckleFilter(image) {
  var vv = image.select('VV').focal_median(
    CONFIG.s1SpeckleFilterSize, 'circle', 'pixels'
  );
  var vh = image.select('VH').focal_median(
    CONFIG.s1SpeckleFilterSize, 'circle', 'pixels'
  );
  return image.addBands(vv, null, true).addBands(vh, null, true);
}

function addSARIndices(image) {
  var vv = image.select('VV');
  var vh = image.select('VH');

  var rvi = vh.divide(vv).rename('RVI');
  var ratio = vv.divide(vh).rename('VV_VH_ratio');
  var diff = vv.subtract(vh).rename('VV_VH_diff');

  return image.addBands([rvi, ratio, diff]);
}

var s1 = ee.ImageCollection('COPERNICUS/S1_GRD')
  .filterBounds(CONFIG.cores)
  .filterDate(startDate, endDate)
  .filter(ee.Filter.eq('instrumentMode', 'IW'))
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VV'))
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VH'))
  .map(applySpeckleFilter)
  .map(addSARIndices);

print('Sentinel-1 images:', s1.size());

var sarFeatures = ee.Image.cat([
  s1.select('VV').median().rename('VV_median'),
  s1.select('VH').median().rename('VH_median'),
  s1.select('VV').mean().rename('VV_mean'),
  s1.select('VH').mean().rename('VH_mean'),
  s1.select('RVI').median().rename('RVI_median'),
  s1.select('VV_VH_ratio').median().rename('VV_VH_ratio_median'),
  s1.select('VV').reduce(ee.Reducer.stdDev()).rename('VV_stddev'),
  s1.select('VH').reduce(ee.Reducer.stdDev()).rename('VH_stddev'),
  s1.select('VV').count().rename('S1_obs_count')
]);

print('✓ SAR features:', sarFeatures.bandNames());

// ============================================================================
// SECTION 7: SOILGRIDS FEATURES
// ============================================================================

print('\n=== Processing SoilGrids Features ===');

// SoilGrids 250m - soil properties at standard depths
var soilgrids = ee.Image("projects/soilgrids-isric/bdod_mean")
  .addBands(ee.Image("projects/soilgrids-isric/clay_mean"))
  .addBands(ee.Image("projects/soilgrids-isric/sand_mean"))
  .addBands(ee.Image("projects/soilgrids-isric/silt_mean"))
  .addBands(ee.Image("projects/soilgrids-isric/soc_mean"))
  .addBands(ee.Image("projects/soilgrids-isric/phh2o_mean"));

// Extract surface layer (0-5cm)
var soilFeatures = ee.Image.cat([
  soilgrids.select('bdod_0-5cm_mean').multiply(0.01).rename('sg_bd_0_5cm_kg_dm3'),
  soilgrids.select('clay_0-5cm_mean').multiply(0.1).rename('sg_clay_0_5cm_pct'),
  soilgrids.select('sand_0-5cm_mean').multiply(0.1).rename('sg_sand_0_5cm_pct'),
  soilgrids.select('silt_0-5cm_mean').multiply(0.1).rename('sg_silt_0_5cm_pct'),
  soilgrids.select('soc_0-5cm_mean').multiply(0.1).rename('sg_soc_0_5cm_g_kg'),
  soilgrids.select('phh2o_0-5cm_mean').multiply(0.1).rename('sg_ph_0_5cm')
]);

print('✓ SoilGrids features:', soilFeatures.bandNames());

// ============================================================================
// SECTION 8: COASTAL/TIDAL FEATURES
// ============================================================================

print('\n=== Processing Coastal Features ===');

// Global Surface Water - inundation frequency
var gsw = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');

// Distance to permanent water
var permanentWater = gsw.select('occurrence').gte(75);
var distanceToWater = permanentWater.fastDistanceTransform().sqrt()
  .multiply(ee.Image.pixelArea().sqrt()).rename('distance_to_water_m');

var coastalFeatures = ee.Image.cat([
  gsw.select('occurrence').rename('water_occurrence_pct'),
  gsw.select('seasonality').rename('water_seasonality_months'),
  gsw.select('max_extent').rename('water_max_extent_flag'),
  distanceToWater.clip(CONFIG.cores.geometry().buffer(50000))  // Clip to reasonable extent
]);

print('✓ Coastal features:', coastalFeatures.bandNames());

// ============================================================================
// SECTION 9: QUALITY ASSESSMENT LAYERS
// ============================================================================

print('\n=== Generating Quality Assessment Layers ===');

var ndviQA = opticalMetrics.select('NDVI_median_annual')
  .gte(CONFIG.minNDVI)
  .and(opticalMetrics.select('NDVI_median_annual').lte(CONFIG.maxNDVI))
  .rename('NDVI_valid_flag');

var eviQA = opticalMetrics.select('EVI_median_annual')
  .gte(CONFIG.minEVI)
  .and(opticalMetrics.select('EVI_median_annual').lte(CONFIG.maxEVI))
  .rename('EVI_valid_flag');

var thermalQA = thermalMetrics.select('LST_median_annual_C')
  .gte(CONFIG.minLST)
  .and(thermalMetrics.select('LST_median_annual_C').lte(CONFIG.maxLST))
  .rename('LST_valid_flag');

var sarQA = sarFeatures.select('VV_median')
  .gte(CONFIG.minVV)
  .and(sarFeatures.select('VV_median').lte(CONFIG.maxVV))
  .rename('VV_valid_flag');

var qualityLayers = ee.Image.cat([
  opticalMetrics.select('S2_obs_count'),
  thermalMetrics.select('L8_obs_count'),
  sarFeatures.select('S1_obs_count'),
  ndviQA,
  eviQA,
  thermalQA,
  sarQA
]);

print('✓ Quality layers:', qualityLayers.bandNames());

// ============================================================================
// SECTION 10: COMBINE ALL FEATURES
// ============================================================================

print('\n=== Combining All Features ===');

var allFeatures = ee.Image.cat([
  climateFeatures,
  topographicFeatures,
  opticalMetrics,
  thermalMetrics,
  sarFeatures,
  soilFeatures,
  coastalFeatures,
  qualityLayers
]);

print('Total feature bands:', allFeatures.bandNames().length());
print('All bands:', allFeatures.bandNames());

// ============================================================================
// SECTION 11: VISUALIZATION
// ============================================================================

print('\n=== Adding Visualization Layers ===');

Map.addLayer(elevation, {min: 0, max: 100, palette: ['blue', 'green', 'yellow']}, 'Elevation', false);
Map.addLayer(opticalMetrics.select('NDVI_median_annual'),
  {min: 0, max: 1, palette: ['brown', 'yellow', 'green']}, 'NDVI', false);
Map.addLayer(coastalFeatures.select('water_occurrence_pct'),
  {min: 0, max: 100, palette: ['white', 'lightblue', 'darkblue']}, 'Water Occurrence', false);
Map.addLayer(sarFeatures.select('VV_median'),
  {min: -20, max: 0, palette: ['blue', 'white', 'red']}, 'SAR VV', false);

// ============================================================================
// SECTION 12: EXTRACT VALUES AT CORE LOCATIONS
// ============================================================================

print('\n=== Extracting Values at Core Locations ===');

// Sample all features at core locations
var coresWithCovariates = allFeatures.reduceRegions({
  collection: CONFIG.cores,
  reducer: ee.Reducer.first(),
  scale: CONFIG.exportScale
});

print('Cores with covariates:', coresWithCovariates.size());
print('First core (check properties):', coresWithCovariates.first());

// ============================================================================
// SECTION 13: EXPORT COVARIATE TABLE
// ============================================================================

print('\n=== EXPORTING COVARIATE TABLE ===');

// Export as CSV
Export.table.toDrive({
  collection: coresWithCovariates,
  description: 'Janousek_cores_with_covariates',
  fileNamePrefix: 'janousek_cores_with_covariates',
  folder: CONFIG.exportFolder,
  fileFormat: 'CSV'
});

print('✓ Export task created: Janousek_cores_with_covariates.csv');

// ============================================================================
// SECTION 14: OPTIONAL - EXPORT RASTER BANDS FOR REGIONAL PREDICTION
// ============================================================================

print('\n=== OPTIONAL: Export Individual Raster Bands ===');

// Get spatial extent for export (buffer around all cores)
var exportRegion = CONFIG.cores.geometry().buffer(10000).bounds();

/**
 * Export individual bands as separate GeoTIFF files
 * Only run this if you need rasters for regional prediction
 */
function exportIndividualBands() {
  print('\n=== EXPORTING INDIVIDUAL BANDS ===');

  var bandNames = allFeatures.bandNames().getInfo();

  print('Total bands to export:', bandNames.length);
  print('Export folder:', CONFIG.exportFolder);
  print('\nCreating export tasks...\n');

  for (var i = 0; i < bandNames.length; i++) {
    var bandName = bandNames[i];
    var singleBand = allFeatures.select(bandName);
    var cleanName = 'Janousek_' + bandName.replace(/[^a-zA-Z0-9_]/g, '_');

    Export.image.toDrive({
      image: singleBand.toFloat(),
      description: cleanName,
      fileNamePrefix: cleanName,
      folder: CONFIG.exportFolder,
      region: exportRegion,
      scale: CONFIG.exportScale,
      crs: CONFIG.exportCRS,
      maxPixels: 1e13,
      fileFormat: 'GeoTIFF',
      formatOptions: {
        cloudOptimized: true
      }
    });

    if ((i + 1) % 10 === 0 || i === bandNames.length - 1) {
      print('  Created tasks:', (i + 1), '/', bandNames.length);
    }
  }

  print('\n✓ All raster band export tasks created!');
}

// Uncomment to export rasters (not needed for point-based modeling)
// exportIndividualBands();

// ============================================================================
// SECTION 15: SUMMARY
// ============================================================================

print('\n========================================');
print('READY TO EXTRACT COVARIATES');
print('========================================\n');

print('✅ Core locations loaded:', CONFIG.cores.size());
print('✅ Covariates extracted:', allFeatures.bandNames().length(), 'features');
print('✅ Export task created: CSV with all covariates at core locations');

print('\n📋 NEXT STEPS:');
print('1. Go to Tasks tab (top right)');
print('2. Run the export task: Janousek_cores_with_covariates');
print('3. Wait for export to complete (~5-10 minutes)');
print('4. Download janousek_cores_with_covariates.csv from Google Drive/' + CONFIG.exportFolder);
print('5. Place CSV in: data_global/ folder in your R project');
print('6. Re-run 00d_bluecarbon_large_scale_training.R');

print('\n💡 COVARIATE CATEGORIES:');
print('• Climate (8): Temperature, precipitation, seasonality');
print('• Topography (7): Elevation, slope, aspect, TPI, TRI');
print('• Optical (18): NDVI, EVI, NDMI, NDRE, NDWI, phenology');
print('• Thermal (7): Land surface temperature metrics');
print('• SAR (9): VV, VH polarization, radar indices');
print('• Soil (6): Texture, bulk density, SOC priors');
print('• Coastal (4): Water occurrence, distance to water');
print('• Quality (7): Observation counts, validity flags');

print('\n🌊 Dataset: Janousek et al. 2025');
print('📍 Extent: Pacific coast North America');
print('🎯 Use: Transfer learning - large scale model training');

print('\n🚀 Ready to extract!');
