# Troubleshooting Guide

Common issues and solutions for the Drone Pipeline.

## Installation Issues

### R Package Installation Fails

**Error:** `installation of package 'terra' had non-zero exit status`

**Cause:** Missing system libraries (GDAL, PROJ, GEOS)

**Solution - Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y libgdal-dev libgeos-dev libproj-dev libudunits2-dev libcurl4-openssl-dev libssl-dev
```

**Solution - MacOS:**
```bash
brew install gdal geos proj udunits
```

**Solution - Windows:**
- Install RTools: https://cran.r-project.org/bin/windows/Rtools/
- Restart R and try again

---

### Docker Not Found

**Error:** `docker: command not found`

**Solution:**
1. Install Docker Desktop: https://docs.docker.com/get-docker/
2. Start Docker Desktop application
3. Verify: `docker --version`
4. Pull ODM image: `docker pull opendronemap/odm`

---

### ExifTool Not Found

**Error:** `ExifTool not found`

**Solution - Ubuntu:**
```bash
sudo apt-get install libimage-exiftool-perl
```

**Solution - MacOS:**
```bash
brew install exiftool
```

**Solution - Windows:**
- Download from: https://exiftool.org/
- Extract to C:\\exiftool
- Add to system PATH

---

## Data Input Issues

### No Images Found

**Error:** `No image files found in: data_input/images`

**Checklist:**
1. Images are in correct directory? `ls data_input/images/`
2. Files have correct extension? (`.jpg`, `.jpeg`, `.JPG`, `.JPEG`)
3. `IMAGE_DIR` path correct in config?

**Solution:**
```bash
# Check files
ls -lh data_input/images/

# Should see:
# DJI_0001.JPG, DJI_0002.JPG, etc.

# If in subdirectory:
mv data_input/images/subfolder/*.JPG data_input/images/
```

---

### GPS Coordinates Not Found

**Error:** `No images have GPS coordinates`

**Cause:** Images not geotagged

**Check if geotagged:**
```bash
exiftool data_input/images/DJI_0001.JPG | grep GPS
# Should show: GPSLatitude, GPSLongitude, GPSAltitude
```

**Solutions:**

1. **If DJI drone** - Ensure GPS was locked before takeoff (green status icon)

2. **If images not geotagged** - Can geotag using flight logs:
   ```r
   # Use exiftoolr package
   library(exiftoolr)
   # Process with flight log (advanced)
   ```

3. **If GPS data in separate file** - Use ODM's geo.txt format

4. **Last resort** - ODM can still process but orthomosaic won't be georeferenced

---

## ODM Processing Issues

### Insufficient Image Overlap

**Warning:** `Estimated overlap: 45% (below recommended 60%)`

**Impact:** Poor 3D reconstruction, gaps in orthomosaic

**Solutions:**

1. **Refly survey** with mission planning app:
   - Front overlap: 75-80%
   - Side overlap: 65-70%
   - Recommended apps: DJI GS Pro, Pix4D Capture

2. **Adjust ODM parameters** (less reliable):
   ```r
   ODM_PARAMS$min_num_features <- 5000  # More lenient feature matching
   ODM_PARAMS$feature_quality <- "medium"  # Faster, may help with few images
   ```

3. **Reduce survey area** - Process subset with better coverage

---

### ODM Docker Out of Memory

**Error:** `Killed` or `OOM (Out Of Memory)`

**Cause:** Insufficient RAM allocated to Docker

**Solution - Increase Docker Memory:**

**Docker Desktop (Mac/Windows):**
1. Open Docker Desktop
2. Settings → Resources → Memory
3. Increase to at least 8 GB (16 GB recommended)
4. Apply & Restart

**Linux:**
```bash
# Docker uses all available RAM by default on Linux
# Check system memory:
free -h

# If insufficient, reduce image count or use cloud processing
```

**Alternative - Reduce Processing Demands:**
```r
# In config file:
ODM_PARAMS$pc_quality <- "low"  # Lower point cloud density
ODM_PARAMS$orthophoto_resolution <- 5  # Lower resolution (5 cm instead of 2 cm)
ODM_PARAMS$feature_quality <- "medium"  # Reduce feature detection
```

---

### ODM Processing Takes Forever

**Issue:** Processing has been running for >12 hours

**Expected Times:**
- 50 images: 30-60 min
- 100 images: 1-2 hours
- 200 images: 2-4 hours
- 300+ images: 4-8 hours

**If much slower:**

1. **Check Docker resources** - increase CPU cores:
   - Docker Desktop → Settings → Resources → CPUs
   - Set to max-1 (leave one core for system)

2. **Check disk space**:
   ```bash
   df -h
   # Need at least 20 GB free for processing
   ```

3. **Use WebODM** for large datasets:
   - Cloud-based processing
   - https://www.opendronemap.org/webodm/
   - Faster for 300+ images

---

## Classification Issues

### Classification Shows Only 1-2 Classes

**Issue:** Expected 5 classes, but output shows only 2

**Cause:** Vegetation is more homogeneous than expected

**Solutions:**

1. **Reduce class count**:
   ```r
   N_CLASSES_UNSUPERVISED <- 3
   ```

2. **Check spectral indices** - may lack variability:
   ```r
   # View NDVI range
   library(terra)
   ndvi <- rast("outputs/data_processed/classifications/spectral_indices/NDVI.tif")
   summary(values(ndvi))

   # If range < 0.3, vegetation is uniform
   ```

3. **Try supervised classification** with field training samples

---

### Classification Accuracy Is Low

**Issue:** Accuracy assessment shows <60% accuracy

**For supervised classification:**

1. **Collect more training samples**:
   - Need at least 50 samples per class
   - Well-distributed across study area
   - Avoid mixed pixels (class boundaries)

2. **Check training data quality**:
   ```r
   # Ensure training polygons labeled correctly
   library(sf)
   training <- st_read("data_input/training/training_polygons.shp")
   table(training$class)  # Should show all classes
   ```

3. **Add more spectral indices**:
   ```r
   SPECTRAL_INDICES <- c("NDVI", "ExG", "VARI", "GLI", "GRVI", "VDVI")
   ```

**For unsupervised:**
- Ground-truth in field to interpret clusters
- Clusters represent spectral similarity, not ecological classes

---

## Tree Detection Issues

### Few Trees Detected (Underestimation)

**Issue:** Expected ~500 trees, but only 150 detected

**Causes & Solutions:**

1. **Height threshold too high**:
   ```r
   MIN_TREE_HEIGHT <- 1.0  # Lower to include shrubs
   ```

2. **CHM quality poor** - Check:
   ```r
   chm <- rast("outputs/data_processed/tree_detections/chm.tif")
   plot(chm)  # Visual inspection
   summary(values(chm))  # Check range
   ```

   If CHM shows only 0-2m range on forested site:
   - May need DTM for sloped terrain
   - DSM might have elevation artifacts

3. **Detection method not suitable**:
   ```r
   # Try alternative:
   TREE_DETECTION_METHOD <- "local_maxima"  # Instead of watershed
   ```

4. **Dense forest** - Trees too close:
   ```r
   # Watershed works better for dense stands
   TREE_DETECTION_METHOD <- "watershed"
   WATERSHED_PARAMS$tolerance <- 0.3  # More sensitive
   ```

---

### Too Many False Positives

**Issue:** Detecting 5,000 "trees" in area with only ~500 actual trees

**Causes & Solutions:**

1. **Detecting noise**:
   ```r
   MIN_TREE_HEIGHT <- 2.5  # Increase threshold
   ```

2. **Crown size filter**:
   ```r
   CROWN_PARAMS$min_crown_area <- 2  # Minimum 2 m² crown
   CROWN_PARAMS$max_crown_area <- 50  # Filter outliers
   ```

3. **Smooth CHM more**:
   - Edit `03_tree_shrub_detection.R`
   - Increase focal filter window (line ~95):
   ```r
   chm_smooth <- focal(chm, w = 5, fun = "mean", na.rm = TRUE)  # Larger window
   ```

---

## Change Detection Issues

### Co-registration Errors

**Error:** Rasters don't align properly

**Solution - Ensure consistent CRS:**
```r
# Check CRS of both surveys
library(terra)
current <- rast("outputs/geotiff/orthomosaic.tif")
previous <- rast("data_input/previous_surveys/2023_orthomosaic.tif")

crs(current)
crs(previous)

# If different, reproject previous:
previous_proj <- project(previous, current)
writeRaster(previous_proj, "data_input/previous_surveys/2023_orthomosaic_projected.tif")

# Update config:
PREVIOUS_ORTHOMOSAIC <- "data_input/previous_surveys/2023_orthomosaic_projected.tif"
```

---

### No Significant Changes Detected

**Issue:** Change map shows all "Stable" even though changes occurred

**Solution - Adjust thresholds:**
```r
CHANGE_THRESHOLDS <- list(
  ndvi_change = 0.10,     # More sensitive (was 0.15)
  height_change = 0.3,    # More sensitive (was 0.5)
  cover_change = 5        # More sensitive (was 10)
)
```

**Also check:**
- Surveys done in same season? (phenological changes confound analysis)
- Image quality consistent? (lighting, shadows affect NDVI)

---

## Report Generation Issues

### PDF Generation Fails

**Error:** `Error: LaTeX not found`

**Solution - Install TinyTeX:**
```r
install.packages('tinytex')
tinytex::install_tinytex()

# Then regenerate report:
source("R/06_generate_report.R")
```

**Alternative - Generate HTML only:**
```r
# In config:
REPORT_FORMAT <- "HTML"
```

---

### Plots Not Showing in Report

**Issue:** Report renders but figures are blank

**Cause:** Output paths incorrect

**Solution:**
1. Check file paths in R Markdown template
2. Ensure all modules completed successfully
3. Verify outputs exist:
   ```bash
   ls outputs/data_processed/classifications/
   ls outputs/data_processed/tree_detections/
   ```

---

## Performance Issues

### Pipeline Very Slow

**Optimization checklist:**

1. **Parallel processing** - Increase cores:
   ```r
   MAX_CORES <- parallel::detectCores() - 1
   ```

2. **Memory management**:
   ```r
   MEMORY_SETTINGS$downsample_large_rasters <- TRUE
   MEMORY_SETTINGS$max_ram_gb <- 16  # If you have RAM available
   ```

3. **Process subset first** (testing):
   ```r
   PROCESSING_EXTENT <- c(xmin, xmax, ymin, ymax)  # Crop to smaller area
   ```

4. **Reduce output resolution**:
   ```r
   ODM_PARAMS$orthophoto_resolution <- 5  # 5 cm instead of 2 cm
   ```

---

## Error Messages

### "Configuration validation failed"

**Cause:** Required files missing or paths incorrect

**Solution:**
1. Read error messages carefully - they specify which file/path is missing
2. Check paths are absolute or relative to working directory
3. Ensure IMAGE_DIR contains images before running

---

### "Module X failed"

**Cause:** Error in specific module

**Solution:**
1. Check error message for details
2. Enable verbose logging:
   ```r
   VERBOSE <- TRUE
   ```
3. Run module individually to debug:
   ```r
   source("R/0X_module_name.R")
   ```
4. Check intermediate outputs in `data_processed/`

---

## Getting Help

### Before Asking for Help

1. **Check this troubleshooting guide**
2. **Read error messages carefully** - often self-explanatory
3. **Check file paths** - 80% of errors are path issues
4. **Review configuration** - syntax errors or missing commas

### Where to Get Help

**ODM-specific issues:**
- OpenDroneMap Forum: https://community.opendronemap.org/
- ODM GitHub Issues: https://github.com/OpenDroneMap/ODM/issues

**R-specific issues:**
- Stack Overflow (tag: `[r]`, `[terra]`, `[sf]`)
- RStudio Community: https://community.rstudio.com/

**ForestTools issues:**
- GitHub: https://github.com/andrew-plowright/ForestTools/issues

### Information to Include

When asking for help, provide:
1. **Operating system** and version
2. **R version**: `R.version.string`
3. **Package versions**: `packageVersion("terra")`
4. **Error message** - complete text
5. **Configuration settings** - relevant section
6. **What you tried** - solutions already attempted

---

## Preventive Measures

### Best Practices to Avoid Issues

**Survey Planning:**
- Use mission planning app (DJI GS Pro, Pix4D Capture)
- Ensure 75% front, 65% side overlap
- Fly in good lighting (avoid midday harsh shadows)
- Lock GPS before takeoff
- Check camera settings (auto-exposure OK, but consistent)

**Data Management:**
- Organize images by date/location
- Back up raw images before processing
- Use descriptive project names
- Document survey conditions (weather, time, altitude)

**System Preparation:**
- Check disk space before processing
- Close unnecessary applications
- Ensure stable internet for Docker image downloads
- Update software regularly

**Processing:**
- Start with small test area (50 images)
- Validate configuration before full run
- Save intermediate outputs for debugging
- Archive completed projects

---

**Still Stuck?**

If you've tried solutions above and still have issues:

1. Simplify: Try with default settings and smaller dataset
2. Isolate: Identify which specific module fails
3. Document: Note exact error message and steps to reproduce
4. Seek help: Post on appropriate forum with details

---

**Last Updated:** November 2024
