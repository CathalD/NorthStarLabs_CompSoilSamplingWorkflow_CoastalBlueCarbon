// ============================================================================
// EXTRACT EXISTING GLOBAL MAPS - PRAGMATIC TRANSFER LEARNING
// ============================================================================
// Version: 1.0 - Fast & Memory Efficient
// Purpose: Extract pre-existing global products at core locations
// Approach: No heavy processing - just sample existing rasters
// Time: ~2-5 minutes (vs hours for composites)
// ============================================================================
//
// PHILOSOPHY:
// -----------
// Instead of training a global model from scratch (computationally expensive),
// we extract existing global products that already embed global knowledge:
//
// 1. SoilGrids = Global soil-environment relationships (240k+ profiles)
// 2. WorldClim = Global climate patterns
// 3. SRTM = Topography
// 4. Global Surface Water = Coastal/tidal dynamics
//
// These products ARE the "global model" - we just need to extract them!
//
// TRANSFER LEARNING:
// ------------------
// Your regional RF will learn:
//   Regional_SOC = f(SoilGrids_baseline, Local_covariates)
//
// This captures how blue carbon differs from the global baseline.
//
// ============================================================================

// ============================================================================
// CONFIGURATION
// ============================================================================

// Upload your regional core locations CSV as a GEE asset
// Assets tab → New → Table Upload → core_locations.csv
var cores = ee.FeatureCollection('projects/northstarlabs/assets/janousek_harmonized_bluecarbon');

// Visualize
Map.addLayer(cores, {color: 'red'}, 'Core Locations', true);
Map.centerObject(cores, 6);

print('=== CONFIGURATION ===');
print('Core locations:', cores.size());

var CONFIG = {
  exportFolder: 'Global_Features_Extraction',
  exportDescription: 'regional_cores_with_global_features'
};

// ============================================================================
// SECTION 1: SOILGRIDS (GLOBAL SOIL BASELINE)
// ============================================================================

print('\n=== SoilGrids (Global Baseline) ===');

// SoilGrids 250m - trained on 240,000+ soil profiles worldwide
// This IS the global model!

var soilgrids_soc = ee.Image("projects/soilgrids-isric/soc_mean");
var soilgrids_bdod = ee.Image("projects/soilgrids-isric/bdod_mean");
var soilgrids_clay = ee.Image("projects/soilgrids-isric/clay_mean");
var soilgrids_sand = ee.Image("projects/soilgrids-isric/sand_mean");

// Extract multiple depths (0-5cm, 5-15cm, 15-30cm for blue carbon)
var soilgrids = ee.Image.cat([
  // SOC (convert dg/kg to g/kg)
  soilgrids_soc.select('soc_0-5cm_mean').multiply(0.1).rename('sg_soc_0_5cm_g_kg'),
  soilgrids_soc.select('soc_5-15cm_mean').multiply(0.1).rename('sg_soc_5_15cm_g_kg'),
  soilgrids_soc.select('soc_15-30cm_mean').multiply(0.1).rename('sg_soc_15_30cm_g_kg'),

  // Bulk density (convert cg/cm3 to g/cm3)
  soilgrids_bdod.select('bdod_0-5cm_mean').multiply(0.01).rename('sg_bd_0_5cm_g_cm3'),
  soilgrids_bdod.select('bdod_5-15cm_mean').multiply(0.01).rename('sg_bd_5_15cm_g_cm3'),

  // Texture (convert g/kg to %)
  soilgrids_clay.select('clay_0-5cm_mean').multiply(0.1).rename('sg_clay_0_5cm_pct'),
  soilgrids_sand.select('sand_0-5cm_mean').multiply(0.1).rename('sg_sand_0_5cm_pct')
]);

print('✓ SoilGrids features:', soilgrids.bandNames());

// ============================================================================
// SECTION 2: WORLDCLIM (CLIMATE)
// ============================================================================

print('\n=== WorldClim (Climate) ===');

var worldclim = ee.Image('WORLDCLIM/V1/BIO');

var climate = ee.Image.cat([
  worldclim.select('bio01').divide(10).rename('wc_MAT_C'),              // Mean annual temp
  worldclim.select('bio12').rename('wc_MAP_mm'),                        // Mean annual precip
  worldclim.select('bio04').divide(100).rename('wc_temp_seasonality'),  // Temp seasonality
  worldclim.select('bio15').rename('wc_precip_seasonality'),            // Precip seasonality
  worldclim.select('bio05').divide(10).rename('wc_max_temp_warmest_C'),
  worldclim.select('bio06').divide(10).rename('wc_min_temp_coldest_C')
]);

print('✓ Climate features:', climate.bandNames());

// ============================================================================
// SECTION 3: TOPOGRAPHY (SRTM)
// ============================================================================

print('\n=== Topography ===');

var elevation = ee.Image('USGS/SRTMGL1_003').select('elevation').rename('topo_elevation_m');
var slope = ee.Terrain.slope(elevation).rename('topo_slope_deg');
var aspect = ee.Terrain.aspect(elevation).rename('topo_aspect_deg');

// Aspect transformations
var northness = aspect.subtract(180).abs().divide(180).rename('topo_northness');
var eastness = aspect.subtract(90).abs().divide(90).rename('topo_eastness');

var topography = ee.Image.cat([
  elevation,
  slope,
  aspect,
  northness,
  eastness
]);

print('✓ Topography features:', topography.bandNames());

// ============================================================================
// SECTION 4: GLOBAL SURFACE WATER (COASTAL)
// ============================================================================

print('\n=== Global Surface Water (Coastal) ===');

var gsw = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');

// Water occurrence and seasonality
var coastal = ee.Image.cat([
  gsw.select('occurrence').rename('gsw_water_occurrence_pct'),
  gsw.select('seasonality').rename('gsw_water_seasonality_months'),
  gsw.select('max_extent').rename('gsw_max_extent_flag')
]);

// Distance to permanent water (important for tidal wetlands)
var permanentWater = gsw.select('occurrence').gte(75);  // Water >75% of time
var distanceToWater = permanentWater.fastDistanceTransform()
  .sqrt()
  .multiply(ee.Image.pixelArea().sqrt())
  .rename('gsw_distance_to_water_m');

coastal = coastal.addBands(distanceToWater);

print('✓ Coastal features:', coastal.bandNames());

// ============================================================================
// SECTION 5: COMBINE ALL GLOBAL FEATURES
// ============================================================================

print('\n=== Combining Global Features ===');

var globalFeatures = ee.Image.cat([
  soilgrids,      // 7 bands - THE GLOBAL BASELINE
  climate,        // 6 bands
  topography,     // 5 bands
  coastal         // 4 bands
]);

print('Total global features:', globalFeatures.bandNames().length());
print('All bands:', globalFeatures.bandNames());

// ============================================================================
// SECTION 6: EXTRACT AT CORE LOCATIONS
// ============================================================================

print('\n=== Extracting at Core Locations ===');

// This is FAST because we're just sampling existing rasters
// No composites, no temporal processing, no memory issues!

var coresWithGlobalFeatures = globalFeatures.reduceRegions({
  collection: cores,
  reducer: ee.Reducer.first(),
  scale: 250,           // SoilGrids native resolution
  tileScale: 1          // No chunking needed - very fast
});

print('✓ Extraction complete');
print('Features extracted for', coresWithGlobalFeatures.size(), 'cores');

// Preview first core
print('Sample (first core):', coresWithGlobalFeatures.first());

// ============================================================================
// SECTION 7: EXPORT
// ============================================================================

print('\n=== Exporting Results ===');

Export.table.toDrive({
  collection: coresWithGlobalFeatures,
  description: CONFIG.exportDescription,
  fileNamePrefix: CONFIG.exportDescription,
  folder: CONFIG.exportFolder,
  fileFormat: 'CSV'
});

print('✓ Export task created:', CONFIG.exportDescription);

// ============================================================================
// VISUALIZATION
// ============================================================================

// Visualize the global products
Map.addLayer(soilgrids.select('sg_soc_0_5cm_g_kg'),
  {min: 0, max: 150, palette: ['white', 'yellow', 'orange', 'brown']},
  'SoilGrids SOC (0-5cm)', false);

Map.addLayer(climate.select('wc_MAT_C'),
  {min: -20, max: 30, palette: ['blue', 'white', 'red']},
  'WorldClim MAT', false);

Map.addLayer(coastal.select('gsw_water_occurrence_pct'),
  {min: 0, max: 100, palette: ['white', 'lightblue', 'darkblue']},
  'Water Occurrence', false);

// ============================================================================
// SUMMARY
// ============================================================================

print('\n========================================');
print('GLOBAL FEATURE EXTRACTION READY');
print('========================================\n');

print('✅ Global products loaded:');
print('   • SoilGrids (7 features) - GLOBAL BASELINE');
print('   • WorldClim (6 features)');
print('   • Topography (5 features)');
print('   • Global Surface Water (4 features)');
print('   • Total: 22 features');

print('\n⚡ WHY THIS IS FAST:');
print('• No image compositing');
print('• No temporal processing');
print('• No cloud masking');
print('• Just sampling existing rasters');
print('• Completes in ~2-5 minutes');

print('\n💡 TRANSFER LEARNING EXPLANATION:');
print('SoilGrids is trained on 240,000+ global soil profiles');
print('It already knows global soil-environment relationships');
print('Your regional model will learn how blue carbon differs:');
print('');
print('  Regional_SOC = f(SoilGrids_global, Local_NDVI, Local_climate, ...)');
print('');
print('The model discovers: Blue_Carbon = Global_Baseline + Wetland_Effect');

print('\n📋 NEXT STEPS:');
print('1. Click Tasks tab (top right)');
print('2. Run export: ' + CONFIG.exportDescription);
print('3. Wait ~2-5 minutes');
print('4. Download CSV from Google Drive/' + CONFIG.exportFolder);
print('5. Place in: data_global/ folder');
print('6. Use in Module 05c for regional modeling');

print('\n🎯 INTEGRATION WITH R WORKFLOW:');
print('In your regional Random Forest:');
print('  • SoilGrids SOC becomes a predictor variable');
print('  • The model learns when to trust/adjust the global baseline');
print('  • Features like water_occurrence help identify tidal wetlands');
print('  • Climate features capture regional variation');

print('\n✅ ADVANTAGES:');
print('• Uses peer-reviewed global products');
print('• No computational bottlenecks');
print('• Reproducible & transparent');
print('• Operationally practical');
print('• Scientifically defensible for carbon credits');

print('\n🚀 Ready to extract!');
