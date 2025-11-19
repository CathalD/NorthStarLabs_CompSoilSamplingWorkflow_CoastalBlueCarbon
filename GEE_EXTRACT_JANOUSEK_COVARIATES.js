// ============================================================================
// JANOUSEK BLUE CARBON CORES - MEMORY-OPTIMIZED COVARIATE EXTRACTION
// ============================================================================
// Version: 2.0 - Memory Optimized for Point Extraction
// Purpose: Extract covariates at 1,284 Pacific coast blue carbon cores
// Dataset: Janousek et al. 2025, Global Biogeochemical Cycles
// Optimization: Designed to avoid GEE memory limits
// ============================================================================

// ============================================================================
// SECTION 1: CONFIGURATION
// ============================================================================

// IMPORTANT: Upload your CSV to GEE as an asset first
// Assets tab → New → Table Upload → janousek_harmonized_bluecarbon.csv
var cores = ee.FeatureCollection('users/YOUR_USERNAME/janousek_cores');

// Visualize
Map.addLayer(cores, {color: 'red'}, 'Core Locations', true);
Map.centerObject(cores, 5);

print('=== CORE LOCATIONS ===');
print('Total cores:', cores.size());

var CONFIG = {
  cores: cores,

  // MEMORY OPTIMIZATION: Use larger scale for extraction
  extractionScale: 100,              // 100m resolution (reduces memory)
  tileScale: 4,                      // Process in smaller tiles
  bestEffort: true,                  // Allow GEE to reduce resolution if needed

  // Temporal (keep narrow to reduce memory)
  yearStart: 2021,                   // Narrowed from 2020
  yearEnd: 2023,
  growingSeasonStart: 6,             // June
  growingSeasonEnd: 8,               // August

  // Quality thresholds
  s2CloudThreshold: 30,              // Relaxed to get more images
  s1SpeckleFilterSize: 5,            // Smaller filter = less memory

  // Export
  exportFolder: 'Janousek_Covariates'
};

var startDate = ee.Date.fromYMD(CONFIG.yearStart, 1, 1);
var endDate = ee.Date.fromYMD(CONFIG.yearEnd, 12, 31);
var growingStart = ee.Date.fromYMD(CONFIG.yearStart, CONFIG.growingSeasonStart, 1);
var growingEnd = ee.Date.fromYMD(CONFIG.yearEnd, CONFIG.growingSeasonEnd, 30);

print('Date range:', CONFIG.yearStart, '-', CONFIG.yearEnd);
print('Extraction scale:', CONFIG.extractionScale, 'm');

// ============================================================================
// SECTION 2: STATIC COVARIATES (LOW MEMORY)
// ============================================================================
// These are single images, very memory efficient

print('\n=== Processing Static Covariates ===');

// Climate (WorldClim)
var worldclim = ee.Image('WORLDCLIM/V1/BIO');
var climate = ee.Image.cat([
  worldclim.select('bio01').divide(10).rename('MAT_C'),
  worldclim.select('bio12').rename('MAP_mm'),
  worldclim.select('bio04').divide(100).rename('temp_seasonality'),
  worldclim.select('bio15').rename('precip_seasonality')
]);

// Topography - Use SRTM (simpler than NASADEM for memory)
var elevation = ee.Image('USGS/SRTMGL1_003').select('elevation').rename('elevation_m');
var slope = ee.Terrain.slope(elevation).rename('slope_deg');
var aspect = ee.Terrain.aspect(elevation).rename('aspect_deg');

var topo = ee.Image.cat([
  elevation,
  slope,
  aspect,
  aspect.subtract(180).abs().divide(180).rename('northness'),
  aspect.subtract(90).abs().divide(90).rename('eastness')
]);

// SoilGrids (only 0-5cm to reduce memory)
var soilgrids = ee.Image("projects/soilgrids-isric/bdod_mean")
  .addBands(ee.Image("projects/soilgrids-isric/clay_mean"))
  .addBands(ee.Image("projects/soilgrids-isric/sand_mean"))
  .addBands(ee.Image("projects/soilgrids-isric/soc_mean"));

var soil = ee.Image.cat([
  soilgrids.select('bdod_0-5cm_mean').multiply(0.01).rename('sg_bd_kg_dm3'),
  soilgrids.select('clay_0-5cm_mean').multiply(0.1).rename('sg_clay_pct'),
  soilgrids.select('sand_0-5cm_mean').multiply(0.1).rename('sg_sand_pct'),
  soilgrids.select('soc_0-5cm_mean').multiply(0.1).rename('sg_soc_g_kg')
]);

// Coastal features
var gsw = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');
var coastal = ee.Image.cat([
  gsw.select('occurrence').rename('water_occurrence_pct'),
  gsw.select('seasonality').rename('water_seasonality_months')
]);

// Combine static features
var staticFeatures = ee.Image.cat([
  climate,
  topo,
  soil,
  coastal
]);

print('✓ Static features (15 bands):', staticFeatures.bandNames());

// ============================================================================
// SECTION 3: OPTICAL FEATURES (MEMORY OPTIMIZED)
// ============================================================================

print('\n=== Processing Sentinel-2 (Memory Optimized) ===');

// OPTIMIZATION: Only load images that intersect core locations
// Use filterBounds(cores) to reduce collection size
var s2 = ee.ImageCollection('COPERNICUS/S2_SR_HARMONIZED')
  .filterBounds(cores)  // KEY: Only load images intersecting points
  .filterDate(startDate, endDate)
  .filter(ee.Filter.lt('CLOUDY_PIXEL_PERCENTAGE', CONFIG.s2CloudThreshold))
  .map(function(img) {
    // Cloud mask
    var qa = img.select('QA60');
    var mask = qa.bitwiseAnd(1 << 10).eq(0)
        .and(qa.bitwiseAnd(1 << 11).eq(0));

    var masked = img.updateMask(mask).divide(10000);

    // Calculate indices (server-side)
    var ndvi = masked.normalizedDifference(['B8', 'B4']).rename('NDVI');
    var evi = masked.expression(
      '2.5 * ((NIR - RED) / (NIR + 6 * RED - 7.5 * BLUE + 1))',
      {NIR: masked.select('B8'), RED: masked.select('B4'), BLUE: masked.select('B2')}
    ).rename('EVI');
    var ndmi = masked.normalizedDifference(['B8', 'B11']).rename('NDMI');
    var ndwi = masked.normalizedDifference(['B3', 'B8']).rename('NDWI');

    return masked.addBands([ndvi, evi, ndmi, ndwi]);
  });

print('S2 images available:', s2.size());

var s2_growing = s2.filterDate(growingStart, growingEnd);

// OPTIMIZATION: Create composites ONLY for the indices we need
// Don't create separate composites for each metric - do it in one go
var optical = ee.Image.cat([
  s2.select('NDVI').median().rename('NDVI_median'),
  s2.select('EVI').median().rename('EVI_median'),
  s2.select('NDMI').median().rename('NDMI_median'),
  s2.select('NDWI').median().rename('NDWI_median'),
  s2_growing.select('NDVI').median().rename('NDVI_grow_median'),
  s2_growing.select('EVI').median().rename('EVI_grow_median'),
  s2.select('EVI').reduce(ee.Reducer.stdDev()).rename('EVI_stddev'),
  s2.select('EVI').reduce(ee.Reducer.percentile([10, 90]))
    .rename(['EVI_p10', 'EVI_p90'])
]);

print('✓ Optical features (9 bands):', optical.bandNames());

// ============================================================================
// SECTION 4: THERMAL FEATURES (MEMORY OPTIMIZED)
// ============================================================================

print('\n=== Processing Landsat Thermal (Memory Optimized) ===');

// OPTIMIZATION: Only load Landsat intersecting cores
var landsat = ee.ImageCollection('LANDSAT/LC08/C02/T1_L2')
  .merge(ee.ImageCollection('LANDSAT/LC09/C02/T1_L2'))
  .filterBounds(cores)  // KEY: Only load images intersecting points
  .filterDate(startDate, endDate)
  .map(function(img) {
    var qa = img.select('QA_PIXEL');
    var mask = qa.bitwiseAnd(1 << 3).eq(0).and(qa.bitwiseAnd(1 << 4).eq(0));
    var lst = img.select('ST_B10').updateMask(mask)
      .multiply(0.00341802).add(149.0).subtract(273.15);
    return img.addBands(lst.rename('LST_C'));
  });

print('Landsat images available:', landsat.size());

var landsat_growing = landsat.filterDate(growingStart, growingEnd);

// OPTIMIZATION: Minimal thermal metrics
var thermal = ee.Image.cat([
  landsat.select('LST_C').median().rename('LST_median_C'),
  landsat.select('LST_C').mean().rename('LST_mean_C'),
  landsat_growing.select('LST_C').median().rename('LST_grow_median_C')
]);

print('✓ Thermal features (3 bands):', thermal.bandNames());

// ============================================================================
// SECTION 5: SAR FEATURES (MEMORY OPTIMIZED)
// ============================================================================

print('\n=== Processing Sentinel-1 SAR (Memory Optimized) ===');

// OPTIMIZATION: Only load SAR intersecting cores, smaller speckle filter
var s1 = ee.ImageCollection('COPERNICUS/S1_GRD')
  .filterBounds(cores)  // KEY: Only load images intersecting points
  .filterDate(startDate, endDate)
  .filter(ee.Filter.eq('instrumentMode', 'IW'))
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VV'))
  .filter(ee.Filter.listContains('transmitterReceiverPolarisation', 'VH'))
  .map(function(img) {
    // Smaller speckle filter to reduce memory
    var vv = img.select('VV').focal_median(CONFIG.s1SpeckleFilterSize, 'circle', 'pixels');
    var vh = img.select('VH').focal_median(CONFIG.s1SpeckleFilterSize, 'circle', 'pixels');
    var rvi = vh.divide(vv).rename('RVI');
    return img.addBands(vv, null, true).addBands(vh, null, true).addBands(rvi);
  });

print('S1 images available:', s1.size());

// OPTIMIZATION: Minimal SAR metrics
var sar = ee.Image.cat([
  s1.select('VV').median().rename('VV_median'),
  s1.select('VH').median().rename('VH_median'),
  s1.select('RVI').median().rename('RVI_median'),
  s1.select('VV').reduce(ee.Reducer.stdDev()).rename('VV_stddev')
]);

print('✓ SAR features (4 bands):', sar.bandNames());

// ============================================================================
// SECTION 6: COMBINE ALL FEATURES
// ============================================================================

print('\n=== Combining All Features ===');

var allFeatures = ee.Image.cat([
  staticFeatures,  // 15 bands
  optical,         // 9 bands
  thermal,         // 3 bands
  sar              // 4 bands
]);

print('Total features:', allFeatures.bandNames().length(), 'bands');
print('All bands:', allFeatures.bandNames());

// ============================================================================
// SECTION 7: EXTRACT AT CORE LOCATIONS (MEMORY OPTIMIZED)
// ============================================================================

print('\n=== Extracting at Core Locations (Optimized) ===');

// OPTIMIZATION: Use higher scale, tileScale, and bestEffort
var coresWithCovariates = allFeatures.reduceRegions({
  collection: cores,
  reducer: ee.Reducer.first(),
  scale: CONFIG.extractionScale,      // 100m instead of 30m
  tileScale: CONFIG.tileScale,        // Process in smaller tiles
  bestEffort: CONFIG.bestEffort       // Allow GEE to optimize
});

print('✓ Extraction complete');
print('Cores with covariates:', coresWithCovariates.size());

// Check first feature
print('Sample feature (first core):', coresWithCovariates.first());

// ============================================================================
// SECTION 8: EXPORT (SINGLE CSV)
// ============================================================================

print('\n=== Exporting Results ===');

Export.table.toDrive({
  collection: coresWithCovariates,
  description: 'Janousek_cores_with_covariates',
  fileNamePrefix: 'janousek_cores_with_covariates',
  folder: CONFIG.exportFolder,
  fileFormat: 'CSV',
  selectors: null  // Export all properties
});

print('✓ Export task created: Janousek_cores_with_covariates.csv');

// ============================================================================
// SECTION 9: VISUALIZATION (OPTIONAL)
// ============================================================================

Map.addLayer(elevation, {min: 0, max: 100, palette: ['blue', 'green', 'yellow']}, 'Elevation', false);
Map.addLayer(optical.select('NDVI_median'), {min: 0, max: 1, palette: ['brown', 'yellow', 'green']}, 'NDVI', false);
Map.addLayer(coastal.select('water_occurrence_pct'), {min: 0, max: 100, palette: ['white', 'blue']}, 'Water', false);

// ============================================================================
// SUMMARY
// ============================================================================

print('\n========================================');
print('MEMORY-OPTIMIZED EXTRACTION READY');
print('========================================\n');

print('✅ Core locations:', cores.size());
print('✅ Total covariates: 31 features');
print('   • Climate: 4 features');
print('   • Topography: 5 features');
print('   • Soil: 4 features');
print('   • Coastal: 2 features');
print('   • Optical: 9 features');
print('   • Thermal: 3 features');
print('   • SAR: 4 features');

print('\n⚡ MEMORY OPTIMIZATIONS:');
print('• Extraction scale: 100m (reduces pixels)');
print('• Tile scale: 4 (smaller chunks)');
print('• Best effort: enabled');
print('• Filtered collections by point locations');
print('• Narrowed date range: 2021-2023');
print('• Reduced composite complexity');
print('• Smaller speckle filter for SAR');

print('\n📋 NEXT STEPS:');
print('1. Go to Tasks tab (top right)');
print('2. Click RUN on: Janousek_cores_with_covariates');
print('3. Wait for completion (~10-20 minutes)');
print('4. Download CSV from Google Drive/' + CONFIG.exportFolder);
print('5. Place in: data_global/ folder');
print('6. Run: source("00d_bluecarbon_large_scale_training.R")');

print('\n💡 TROUBLESHOOTING:');
print('If still getting memory errors:');
print('• Increase extractionScale to 200 or 250');
print('• Increase tileScale to 8 or 16');
print('• Reduce date range further (2022-2023 only)');
print('• Remove some covariate groups (e.g., thermal or SAR)');

print('\n🚀 Ready to extract!');
