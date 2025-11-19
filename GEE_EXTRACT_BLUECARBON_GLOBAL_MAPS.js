// ============================================================================
// EXTRACT BLUE CARBON GLOBAL MAPS - CANADA TIDAL WETLANDS
// ============================================================================
// Version: 3.0 - Canadian Blue Carbon (No Mangroves)
// Purpose: Extract blue carbon products for Canadian tidal marshes & seagrass
// Ecosystems: Tidal salt marshes, seagrass meadows, tidal flats
// Region: Pacific coast North America (Janousek dataset)
// ============================================================================
//
// BLUE CARBON GLOBAL PRODUCTS FOR CANADA:
// ----------------------------------------
// 1. Murray et al. 2019 - Tidal wetland extent (Nature)
// 2. Global Surface Water - Inundation dynamics (Nature)
// 3. WorldClim - Climate (temperature, precipitation)
// 4. SRTM - Elevation (tidal zone indicators)
// 5. SoilGrids - Terrestrial comparison (learn marine signal)
//
// TRANSFER LEARNING STRATEGY:
// ---------------------------
// Tidal Marsh → Murray classification + water occurrence
// Seagrass → Water characteristics + depth indicators
// All → Climate + tidal dynamics
//
// ============================================================================

// ============================================================================
// CONFIGURATION
// ============================================================================

var cores = ee.FeatureCollection('projects/northstarlabs/assets/janousek_harmonized_bluecarbon');

Map.addLayer(cores, {color: 'red'}, 'Core Locations', true);
Map.centerObject(cores, 6);

print('=== CANADIAN BLUE CARBON TRANSFER LEARNING ===');
print('Core locations:', cores.size());
print('Ecosystems: Tidal marsh, seagrass, tidal flats');

var CONFIG = {
  exportFolder: 'BlueCarbon_Global_Features',
  exportDescription: 'cores_with_bluecarbon_global_maps'
};

// ============================================================================
// SECTION 1: TIDAL WETLAND EXTENT (MURRAY ET AL. 2019)
// ============================================================================

print('\n=== Tidal Wetland Classification (Murray 2019) ===');

// Murray et al. 2019 - Global intertidal wetland extent
var tidal_wetlands = ee.ImageCollection("UQ/murray/Intertidal/v1_1/global_intertidal");
var tidal_extent = tidal_wetlands.select('classification').mosaic();

var tidal_features = ee.Image.cat([
  tidal_extent.rename('murray_tidal_class'),
  tidal_extent.gt(0).rename('murray_tidal_flag')  // Binary: tidal vs not
]);

print('✓ Tidal wetland features:', tidal_features.bandNames());

// ============================================================================
// SECTION 2: COASTAL/TIDAL CHARACTERISTICS
// ============================================================================

print('\n=== Coastal & Tidal Features (Global Surface Water) ===');

// Global Surface Water - CRITICAL for blue carbon
var gsw = ee.Image('JRC/GSW1_4/GlobalSurfaceWater');

// Ocean/water proximity and inundation frequency
var coastal = ee.Image.cat([
  gsw.select('occurrence').rename('gsw_water_occurrence_pct'),
  gsw.select('seasonality').rename('gsw_water_seasonality_months'),
  gsw.select('max_extent').rename('gsw_max_extent_flag'),
  gsw.select('recurrence').rename('gsw_water_recurrence_pct'),
  gsw.select('transition').rename('gsw_water_transition')
]);

// Distance to permanent water (tidal influence indicator)
var permanentWater = gsw.select('occurrence').gte(50);  // Water >50% of time
var distanceToWater = permanentWater.fastDistanceTransform()
  .sqrt()
  .multiply(ee.Image.pixelArea().sqrt())
  .rename('gsw_distance_to_water_m');

coastal = coastal.addBands(distanceToWater);

print('✓ Coastal features:', coastal.bandNames());

// ============================================================================
// SECTION 3: CLIMATE (WORLDCLIM - Critical for Blue Carbon)
// ============================================================================

print('\n=== Climate (WorldClim) ===');

var worldclim = ee.Image('WORLDCLIM/V1/BIO');

var climate = ee.Image.cat([
  worldclim.select('bio01').divide(10).rename('wc_MAT_C'),                // Mean annual temp
  worldclim.select('bio12').rename('wc_MAP_mm'),                          // Mean annual precip
  worldclim.select('bio04').divide(100).rename('wc_temp_seasonality'),    // Temp seasonality
  worldclim.select('bio15').rename('wc_precip_seasonality'),              // Precip seasonality
  worldclim.select('bio05').divide(10).rename('wc_max_temp_warmest_C'),
  worldclim.select('bio06').divide(10).rename('wc_min_temp_coldest_C'),
  worldclim.select('bio13').rename('wc_precip_wettest_month_mm'),
  worldclim.select('bio14').rename('wc_precip_driest_month_mm')
]);

print('✓ Climate features:', climate.bandNames());

// ============================================================================
// SECTION 4: TOPOGRAPHY (TIDAL ZONE INDICATORS)
// ============================================================================

print('\n=== Topography (SRTM) ===');

var elevation = ee.Image('USGS/SRTMGL1_003').select('elevation').rename('topo_elevation_m');
var slope = ee.Terrain.slope(elevation).rename('topo_slope_deg');
var aspect = ee.Terrain.aspect(elevation).rename('topo_aspect_deg');

// In tidal areas, elevation close to 0 is key indicator
var tidal_elevation_flag = elevation.abs().lt(10).rename('topo_tidal_elevation_flag');

// Aspect transformations (for marsh orientation to sun/wind)
var northness = aspect.subtract(180).abs().divide(180).rename('topo_northness');
var eastness = aspect.subtract(90).abs().divide(90).rename('topo_eastness');

var topography = ee.Image.cat([
  elevation,
  slope,
  aspect,
  tidal_elevation_flag,
  northness,
  eastness
]);

print('✓ Topography features:', topography.bandNames());

// ============================================================================
// SECTION 5: SOILGRIDS (TERRESTRIAL COMPARISON)
// ============================================================================

print('\n=== SoilGrids (Terrestrial Comparison) ===');

// Include SoilGrids as a "terrestrial baseline"
// Helps model learn how tidal wetlands DIFFER from upland soils
var soilgrids_soc = ee.Image("projects/soilgrids-isric/soc_mean");
var soilgrids_bdod = ee.Image("projects/soilgrids-isric/bdod_mean");
var soilgrids_clay = ee.Image("projects/soilgrids-isric/clay_mean");

var soilgrids_comparison = ee.Image.cat([
  // SOC (terrestrial baseline to compare against)
  soilgrids_soc.select('soc_0-5cm_mean').multiply(0.1).rename('sg_terrestrial_soc_0_5cm_g_kg'),
  soilgrids_soc.select('soc_5-15cm_mean').multiply(0.1).rename('sg_terrestrial_soc_5_15cm_g_kg'),

  // Bulk density
  soilgrids_bdod.select('bdod_0-5cm_mean').multiply(0.01).rename('sg_bd_0_5cm_g_cm3'),

  // Clay (affects organic matter retention)
  soilgrids_clay.select('clay_0-5cm_mean').multiply(0.1).rename('sg_clay_0_5cm_pct')
]);

print('✓ SoilGrids (terrestrial comparison):', soilgrids_comparison.bandNames());

// ============================================================================
// SECTION 6: COMBINE ALL BLUE CARBON FEATURES
// ============================================================================

print('\n=== Combining Blue Carbon Global Features ===');

var blueCarbonFeatures = ee.Image.cat([
  tidal_features,           // 2 bands - Tidal wetland classification
  coastal,                  // 6 bands - Water/tidal characteristics
  climate,                  // 8 bands - Climate (affects decomposition)
  topography,               // 6 bands - Elevation (tidal zone indicator)
  soilgrids_comparison      // 4 bands - Terrestrial comparison
]);

print('Total blue carbon features:', blueCarbonFeatures.bandNames().length());
print('All bands:', blueCarbonFeatures.bandNames());

// ============================================================================
// SECTION 7: EXTRACT AT CORE LOCATIONS
// ============================================================================

print('\n=== Extracting at Core Locations ===');

// Fast extraction - just sampling existing rasters
var coresWithBlueCarbonFeatures = blueCarbonFeatures.reduceRegions({
  collection: cores,
  reducer: ee.Reducer.first(),
  scale: 30,                // Fine scale for coastal features
  tileScale: 1
});

print('✓ Extraction complete');
print('Features extracted for', coresWithBlueCarbonFeatures.size(), 'cores');
print('Sample (first core):', coresWithBlueCarbonFeatures.first());

// ============================================================================
// SECTION 8: EXPORT
// ============================================================================

print('\n=== Exporting Results ===');

Export.table.toDrive({
  collection: coresWithBlueCarbonFeatures,
  description: CONFIG.exportDescription,
  fileNamePrefix: CONFIG.exportDescription,
  folder: CONFIG.exportFolder,
  fileFormat: 'CSV'
});

print('✓ Export task created:', CONFIG.exportDescription);

// ============================================================================
// VISUALIZATION
// ============================================================================

// Visualize blue carbon features
Map.addLayer(coastal.select('gsw_water_occurrence_pct'),
  {min: 0, max: 100, palette: ['white', 'lightblue', 'darkblue']},
  'Water Occurrence %', false);

Map.addLayer(tidal_features.select('murray_tidal_flag'),
  {min: 0, max: 1, palette: ['gray', 'cyan']},
  'Tidal Wetland Flag', false);

Map.addLayer(topography.select('topo_tidal_elevation_flag'),
  {min: 0, max: 1, palette: ['white', 'red']},
  'Tidal Elevation Zone (±10m)', false);

Map.addLayer(climate.select('wc_MAT_C'),
  {min: -5, max: 15, palette: ['blue', 'white', 'red']},
  'Mean Annual Temp (Canada)', false);

Map.addLayer(soilgrids_comparison.select('sg_terrestrial_soc_0_5cm_g_kg'),
  {min: 0, max: 100, palette: ['white', 'yellow', 'brown']},
  'SoilGrids SOC (Terrestrial)', false);

// ============================================================================
// SUMMARY
// ============================================================================

print('\n========================================');
print('CANADIAN BLUE CARBON FEATURES READY');
print('========================================\n');

print('✅ Features for Canadian tidal wetlands:');
print('   • Tidal wetland (2): Murray classification, flag');
print('   • Coastal/tidal (6): Water occurrence, seasonality, distance, recurrence');
print('   • Climate (8): Temperature, precipitation, seasonality');
print('   • Topography (6): Elevation, slope, aspect, tidal zone flag');
print('   • Terrestrial comparison (4): SoilGrids SOC, BD, clay');
print('   • Total: 26 features');

print('\n💡 TRANSFER LEARNING FOR CANADIAN BLUE CARBON:');
print('');
print('Tidal Marsh Cores:');
print('  Marsh_SOC = f(murray_tidal_class, water_occurrence,');
print('                 tidal_elevation, climate, sg_comparison)');
print('  → Model learns how marsh differs from upland');
print('');
print('Seagrass Cores:');
print('  Seagrass_SOC = f(water_occurrence, elevation,');
print('                    climate, sg_comparison)');
print('  → Model learns subtidal/marine carbon dynamics');
print('');
print('Tidal Flat Cores:');
print('  TidalFlat_SOC = f(murray_tidal_class, water_seasonality,');
print('                     elevation, sg_comparison)');
print('  → Model learns sediment carbon patterns');

print('\n🎯 KEY FEATURES FOR CANADIAN ECOSYSTEMS:');
print('• Water occurrence: Distinguishes tidal from terrestrial');
print('• Tidal classification: Identifies wetland type');
print('• Elevation: Critical for tidal range/inundation');
print('• Climate: Pacific Northwest has unique temp/precip');
print('• SoilGrids comparison: Learn marine vs upland signal');

print('\n📋 NEXT STEPS:');
print('1. Click Tasks tab');
print('2. Run export: ' + CONFIG.exportDescription);
print('3. Wait ~5 minutes');
print('4. Download CSV from Google Drive/' + CONFIG.exportFolder);
print('5. Place in: data_global/ folder');
print('6. Use in your regional Random Forest model');

print('\n💻 INTEGRATION WITH R WORKFLOW:');
print('In Module 05c, your model will learn:');
print('');
print('rf_model <- ranger(');
print('  SOC ~');
print('    # TIDAL CHARACTERISTICS (transfer learning!)');
print('    murray_tidal_flag +');
print('    gsw_water_occurrence_pct +');
print('    topo_tidal_elevation_flag +');
print('    ');
print('    # CLIMATE CONTEXT');
print('    wc_MAT_C +');
print('    wc_MAP_mm +');
print('    ');
print('    # TERRESTRIAL COMPARISON');
print('    sg_terrestrial_soc_0_5cm +  # Learn how tidal differs');
print('    ');
print('    # LOCAL REFINEMENTS');
print('    local_NDVI +');
print('    local_elevation');
print(')');

print('\n✅ ADVANTAGES:');
print('• Focused on Canadian/Pacific Northwest ecosystems');
print('• No irrelevant mangrove features');
print('• Tidal wetland classification built-in');
print('• Water/inundation dynamics (critical!)');
print('• Climate appropriate for temperate zone');
print('• Terrestrial comparison (learn marine signal)');
print('• Fast extraction (~5 minutes)');

print('\n📚 DATA SOURCES FOR MMRV:');
print('• Murray et al. 2019 - Tidal wetlands (Nature)');
print('• Pekel et al. 2016 - Global Surface Water (Nature)');
print('• Fick & Hijmans 2017 - WorldClim (Int J Climatol)');
print('• Hengl et al. 2017 - SoilGrids (PLOS ONE)');
print('• NASA SRTM - Elevation');

print('\n🌊 Ready for Canadian blue carbon transfer learning!');
