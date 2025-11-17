////////////////////////////////////////////////////////////////////////////////
// GOOGLE EARTH ENGINE - FOREST CARBON REMOTE SENSING
////////////////////////////////////////////////////////////////////////////////
// Purpose: Extract GEDI LiDAR + Sentinel-2 for forest carbon mapping
// Outputs:
//   1. GEDI footprints with forest structure metrics
//   2. Sentinel-2 composites and vegetation indices
//   3. Integrated biomass prediction layers
// Author: NorthStar Labs
// Date: 2025-11-17
////////////////////////////////////////////////////////////////////////////////

// ===========================================================================
// 1. CONFIGURATION
// ===========================================================================

// Study Area - MODIFY THIS
// Option A: Draw a polygon in GEE and import as 'studyArea'
// Option B: Define coordinates here

var studyArea = ee.Geometry.Rectangle({
  coords: [[-125.5, 49.0], [-124.5, 50.0]],  // [xmin, ymin, xmax, ymax]
  geodesic: false
});

// Alternatively, import from asset:
// var studyArea = ee.FeatureCollection('users/YOUR_USERNAME/study_area');

// Center map
Map.centerObject(studyArea, 10);
Map.addLayer(studyArea, {color: 'red'}, 'Study Area', false);

// Time Periods
var START_DATE = '2020-06-01';  // Summer period for vegetation
var END_DATE = '2023-09-15';

var GEDI_START = '2019-04-01';  // GEDI mission start
var GEDI_END = '2023-12-31';

// Processing Parameters
var CLOUD_COVER_MAX = 20;  // Maximum cloud cover (%)
var GEDI_QUALITY_FLAG = 1;  // Only high-quality GEDI shots
var SENTINEL2_RESOLUTION = 10;  // meters

// Export Configuration
var EXPORT_SCALE = 30;  // Export resolution (m)
var EXPORT_CRS = 'EPSG:3005';  // BC Albers (change to your region)
var EXPORT_FOLDER = 'GEE_Forest_Carbon';  // Google Drive folder

// ===========================================================================
// 2. LOAD GEDI DATA (LIDAR FROM SPACE)
// ===========================================================================

print('===== LOADING GEDI DATA =====');

// GEDI L2A - Elevation and Height Metrics
var gedi = ee.ImageCollection('LARSE/GEDI/GEDI02_A_002_MONTHLY')
  .filterBounds(studyArea)
  .filterDate(GEDI_START, GEDI_END)
  .filter(ee.Filter.eq('degrade_flag', 0))  // Not degraded
  .select([
    'rh98',    // 98th percentile height (close to canopy top)
    'rh95',    // 95th percentile
    'rh75',    // 75th percentile (upper canopy)
    'rh50',    // 50th percentile (median height)
    'rh25',    // 25th percentile
    'cover',   // Canopy cover fraction
    'pai',     // Plant Area Index
    'fhd_normal',  // Foliage Height Diversity
    'quality_flag',
    'sensitivity'
  ]);

// Filter by quality
var gediQuality = gedi.map(function(img) {
  return img.updateMask(img.select('quality_flag').eq(GEDI_QUALITY_FLAG));
});

// Composite GEDI (mean values)
var gediComposite = gediQuality.mean().clip(studyArea);

print('GEDI date range:', GEDI_START, 'to', GEDI_END);
print('GEDI composite bands:', gediComposite.bandNames());

// Visualize GEDI canopy height
var gediVis = {
  min: 0,
  max: 40,
  palette: ['#FFFFCC', '#A1DAB4', '#41B6C4', '#2C7FB8', '#253494']
};
Map.addLayer(gediComposite.select('rh98'), gediVis, 'GEDI Canopy Height (RH98)', false);

// ===========================================================================
// 3. LOAD SENTINEL-2 DATA
// ===========================================================================

print('===== LOADING SENTINEL-2 DATA =====');

// Sentinel-2 Surface Reflectance
var s2 = ee.ImageCollection('COPERNICUS/S2_SR')
  .filterBounds(studyArea)
  .filterDate(START_DATE, END_DATE)
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', CLOUD_COVER_MAX))
  .select(['B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B8A', 'B11', 'B12', 'QA60']);

// Cloud masking function
function maskS2clouds(image) {
  var qa = image.select('QA60');

  // Bits 10 and 11 are clouds and cirrus
  var cloudBitMask = 1 << 10;
  var cirrusBitMask = 1 << 11;

  var mask = qa.bitwiseAnd(cloudBitMask).eq(0)
      .and(qa.bitwiseAnd(cirrusBitMask).eq(0));

  return image.updateMask(mask).divide(10000)  // Scale to reflectance
    .copyProperties(image, ['system:time_start']);
}

// Apply cloud mask
var s2Masked = s2.map(maskS2clouds);

// Create seasonal composites
var s2Summer = s2Masked
  .filter(ee.Filter.calendarRange(6, 9, 'month'))  // June-September
  .median()
  .clip(studyArea);

var s2Annual = s2Masked.median().clip(studyArea);

print('Sentinel-2 images:', s2Masked.size());
print('Sentinel-2 bands:', s2Summer.bandNames());

// ===========================================================================
// 4. CALCULATE VEGETATION INDICES
// ===========================================================================

print('===== CALCULATING VEGETATION INDICES =====');

// Function to calculate indices
function addIndices(image) {

  // NDVI - Normalized Difference Vegetation Index
  var ndvi = image.normalizedDifference(['B8', 'B4']).rename('NDVI');

  // EVI - Enhanced Vegetation Index
  var evi = image.expression(
    '2.5 * ((NIR - RED) / (NIR + 6 * RED - 7.5 * BLUE + 1))',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4'),
      'BLUE': image.select('B2')
    }
  ).rename('EVI');

  // NDMI - Normalized Difference Moisture Index
  var ndmi = image.normalizedDifference(['B8', 'B11']).rename('NDMI');

  // SAVI - Soil-Adjusted Vegetation Index
  var savi = image.expression(
    '((NIR - RED) / (NIR + RED + 0.5)) * 1.5',
    {
      'NIR': image.select('B8'),
      'RED': image.select('B4')
    }
  ).rename('SAVI');

  // NBR - Normalized Burn Ratio (disturbance detection)
  var nbr = image.normalizedDifference(['B8', 'B12']).rename('NBR');

  // Chlorophyll Index (Red Edge)
  var ci = image.expression(
    '(NIR / REDEDGE) - 1',
    {
      'NIR': image.select('B8'),
      'REDEDGE': image.select('B5')
    }
  ).rename('CI_RedEdge');

  return image.addBands([ndvi, evi, ndmi, savi, nbr, ci]);
}

// Apply to composites
var s2SummerWithIndices = addIndices(s2Summer);
var s2AnnualWithIndices = addIndices(s2Annual);

// Visualize NDVI
var ndviVis = {min: 0.2, max: 0.9, palette: ['red', 'yellow', 'green']};
Map.addLayer(s2SummerWithIndices.select('NDVI'), ndviVis, 'NDVI (Summer)', false);

// ===========================================================================
// 5. TERRAIN ANALYSIS
// ===========================================================================

print('===== TERRAIN ANALYSIS =====');

// Load SRTM DEM (30m)
var srtm = ee.Image('USGS/SRTMGL1_003').clip(studyArea);
var elevation = srtm.select('elevation');

// Calculate terrain derivatives
var slope = ee.Terrain.slope(elevation).rename('slope');
var aspect = ee.Terrain.aspect(elevation).rename('aspect');
var hillshade = ee.Terrain.hillshade(elevation).rename('hillshade');

// Topographic Position Index (TPI)
var tpi = elevation.subtract(
  elevation.focal_mean({radius: 100, units: 'meters'})
).rename('TPI');

// Topographic Wetness Index (TWI)
// TWI = ln(A / tan(slope))
// where A is upslope contributing area

var slopeRad = slope.multiply(Math.PI / 180);
var flowAccumulation = elevation.multiply(-1).cumulativeCost({
  source: ee.Image.constant(1),
  maxDistance: 1000
});

var twi = flowAccumulation.divide(slopeRad.tan()).log().rename('TWI');

// Combine terrain
var terrain = elevation
  .addBands(slope)
  .addBands(aspect)
  .addBands(tpi)
  .addBands(twi);

Map.addLayer(elevation, {min: 0, max: 2000, palette: ['green', 'yellow', 'brown']}, 'Elevation', false);

// ===========================================================================
// 6. INTEGRATE GEDI + SENTINEL-2 + TERRAIN
// ===========================================================================

print('===== CREATING INTEGRATED FEATURE STACK =====');

// Combine all layers
var featureStack = s2SummerWithIndices
  .select(['B2', 'B3', 'B4', 'B8', 'B11', 'B12', 'NDVI', 'EVI', 'NDMI', 'SAVI', 'NBR', 'CI_RedEdge'])
  .addBands(terrain)
  .addBands(gediComposite.select(['rh98', 'rh95', 'rh75', 'rh50', 'cover', 'pai', 'fhd_normal']));

print('Integrated feature stack bands:', featureStack.bandNames());

// ===========================================================================
// 7. BIOMASS PREDICTION (GEDI-BASED)
// ===========================================================================

print('===== CALCULATING BIOMASS ESTIMATES =====');

// Simple biomass model based on GEDI RH98 and canopy cover
// Based on literature (Duncanson et al. 2022, Potapov et al. 2021)
// AGB (Mg/ha) = a + b * RH98 + c * cover + d * RH98 * cover

// Boreal/Temperate coefficients (calibrate with local data if available)
var biomassPrediction = featureStack.expression(
  'exp(2.3 + 0.038 * RH98 + 0.015 * cover + 0.0003 * RH98 * cover)',
  {
    'RH98': featureStack.select('rh98'),
    'cover': featureStack.select('cover')
  }
).rename('AGB_Mg_ha');

// Convert to carbon (biomass * 0.5 for aboveground, * 1.24 for total including roots)
var carbonStock = biomassPrediction.multiply(0.5).multiply(1.24).rename('Carbon_Mg_ha');

// Add to feature stack
featureStack = featureStack.addBands(biomassPrediction).addBands(carbonStock);

// Visualize biomass
var biomassVis = {
  min: 0,
  max: 300,
  palette: ['#FFFFCC', '#A1DAB4', '#41B6C4', '#2C7FB8', '#253494']
};
Map.addLayer(biomassPrediction, biomassVis, 'Aboveground Biomass (Mg/ha)');
Map.addLayer(carbonStock, {min: 0, max: 200, palette: biomassVis.palette}, 'Carbon Stock (Mg C/ha)');

// ===========================================================================
// 8. STRATIFICATION FOR SAMPLING
// ===========================================================================

print('===== CREATING STRATIFICATION LAYERS =====');

// Simple stratification based on canopy height and NDVI
var strataHeight = featureStack.select('rh98').where(
  featureStack.select('rh98').lt(10), 1)  // Low
  .where(featureStack.select('rh98').gte(10).and(featureStack.select('rh98').lt(20)), 2)  // Medium
  .where(featureStack.select('rh98').gte(20), 3)  // High
  .rename('height_class');

var strataNDVI = featureStack.select('NDVI').where(
  featureStack.select('NDVI').lt(0.5), 1)  // Low vigor
  .where(featureStack.select('NDVI').gte(0.5).and(featureStack.select('NDVI').lt(0.7)), 2)  // Medium
  .where(featureStack.select('NDVI').gte(0.7), 3)  // High
  .rename('ndvi_class');

// Combined stratification
var strataCombined = strataHeight.multiply(10).add(strataNDVI).rename('stratum');

Map.addLayer(strataCombined, {min: 11, max: 33, palette: ['yellow', 'lightgreen', 'green', 'darkgreen', 'blue']}, 'Strata', false);

// ===========================================================================
// 9. EXPORT LAYERS
// ===========================================================================

print('===== EXPORTING LAYERS =====');

// Define export region
var exportRegion = studyArea.bounds();

// Export 1: GEDI Composite
Export.image.toDrive({
  image: gediComposite.float(),
  description: 'GEDI_Composite',
  folder: EXPORT_FOLDER,
  region: exportRegion,
  scale: EXPORT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e10
});

// Export 2: Sentinel-2 Summer Composite with Indices
Export.image.toDrive({
  image: s2SummerWithIndices.select(['B2', 'B3', 'B4', 'B8', 'NDVI', 'EVI', 'NDMI']).float(),
  description: 'Sentinel2_Summer_Composite',
  folder: EXPORT_FOLDER,
  region: exportRegion,
  scale: 10,  // Native Sentinel-2 resolution
  crs: EXPORT_CRS,
  maxPixels: 1e10
});

// Export 3: Terrain
Export.image.toDrive({
  image: terrain.float(),
  description: 'Terrain_Derivatives',
  folder: EXPORT_FOLDER,
  region: exportRegion,
  scale: EXPORT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e10
});

// Export 4: Biomass and Carbon
Export.image.toDrive({
  image: biomassPrediction.addBands(carbonStock).float(),
  description: 'Biomass_Carbon_Stock',
  folder: EXPORT_FOLDER,
  region: exportRegion,
  scale: EXPORT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e10
});

// Export 5: Full Feature Stack (for modeling)
Export.image.toDrive({
  image: featureStack.float(),
  description: 'Forest_Carbon_Feature_Stack',
  folder: EXPORT_FOLDER,
  region: exportRegion,
  scale: EXPORT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e10
});

// Export 6: Stratification Layer
Export.image.toDrive({
  image: strataCombined.byte(),
  description: 'Stratification_Map',
  folder: EXPORT_FOLDER,
  region: exportRegion,
  scale: EXPORT_SCALE,
  crs: EXPORT_CRS,
  maxPixels: 1e10
});

// ===========================================================================
// 10. EXTRACT GEDI FOOTPRINTS AS POINTS (VECTOR)
// ===========================================================================

print('===== EXTRACTING GEDI FOOTPRINTS =====');

// Convert GEDI to vector points (sample every 25m footprint)
var gediPoints = gediComposite.select(['rh98', 'rh95', 'rh75', 'rh50', 'cover'])
  .sample({
    region: studyArea,
    scale: 25,  // GEDI footprint diameter
    numPixels: 10000,
    geometries: true
  });

print('GEDI footprints extracted:', gediPoints.size());

// Add Sentinel-2 values to GEDI points
var gediPointsWithS2 = s2SummerWithIndices.select(['NDVI', 'EVI', 'NDMI'])
  .sampleRegions({
    collection: gediPoints,
    scale: 10,
    geometries: true
  });

// Export GEDI footprints as shapefile/CSV
Export.table.toDrive({
  collection: gediPointsWithS2,
  description: 'GEDI_Footprints_with_Sentinel2',
  folder: EXPORT_FOLDER,
  fileFormat: 'CSV'
});

// ===========================================================================
// 11. SUMMARY STATISTICS
// ===========================================================================

print('===== SUMMARY STATISTICS =====');

// Calculate zonal stats
var stats = featureStack.select(['rh98', 'NDVI', 'AGB_Mg_ha', 'Carbon_Mg_ha'])
  .reduceRegion({
    reducer: ee.Reducer.mean().combine({
      reducer2: ee.Reducer.stdDev(),
      sharedInputs: true
    }).combine({
      reducer2: ee.Reducer.minMax(),
      sharedInputs: true
    }),
    geometry: studyArea,
    scale: 100,
    maxPixels: 1e10
  });

print('Study Area Statistics:', stats);

// Calculate total carbon stock
var totalCarbon = carbonStock.multiply(ee.Image.pixelArea()).divide(10000)  // Mg C per pixel
  .reduceRegion({
    reducer: ee.Reducer.sum(),
    geometry: studyArea,
    scale: 100,
    maxPixels: 1e10
  });

print('Total Carbon Stock (Mg C):', totalCarbon);

// ===========================================================================
// 12. INTERACTIVE TOOLS
// ===========================================================================

// Add inspector tool
print('Click on map to inspect pixel values');

Map.onClick(function(coords) {
  var point = ee.Geometry.Point(coords.lon, coords.lat);
  var sample = featureStack.select(['rh98', 'NDVI', 'AGB_Mg_ha', 'Carbon_Mg_ha'])
    .reduceRegion({
      reducer: ee.Reducer.first(),
      geometry: point,
      scale: 30
    });

  print('=== PIXEL INSPECTION ===');
  print('Coordinates:', coords);
  print('Canopy Height (RH98):', sample.get('rh98'), 'm');
  print('NDVI:', sample.get('NDVI'));
  print('Biomass:', sample.get('AGB_Mg_ha'), 'Mg/ha');
  print('Carbon Stock:', sample.get('Carbon_Mg_ha'), 'Mg C/ha');
});

// ===========================================================================
// COMPLETION
// ===========================================================================

print('===== SCRIPT COMPLETE =====');
print('Study Area:', studyArea.area().divide(10000), 'hectares');
print('Date Range (Sentinel-2):', START_DATE, 'to', END_DATE);
print('Date Range (GEDI):', GEDI_START, 'to', GEDI_END);
print('');
print('NEXT STEPS:');
print('1. Click "Run" to execute all exports (check Tasks tab)');
print('2. Exports will be saved to Google Drive folder:', EXPORT_FOLDER);
print('3. Download exported files');
print('4. Run R scripts: REMOTE_01_gedi_processing.R and REMOTE_02_3d_carbon_mapping.R');
print('');
print('LAYERS AVAILABLE ON MAP:');
print('  - GEDI Canopy Height (RH98)');
print('  - Sentinel-2 NDVI (Summer)');
print('  - Elevation');
print('  - Aboveground Biomass (Mg/ha)');
print('  - Carbon Stock (Mg C/ha)');
print('  - Stratification Map');
