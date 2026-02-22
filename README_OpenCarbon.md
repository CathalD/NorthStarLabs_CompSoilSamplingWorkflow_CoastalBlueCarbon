# OpenCarbon MVP (Beginner GIS Tech Guide)

This is a starter tool for indigenous conservation teams to estimate tree carbon using:
- **Drone orthomosaics** (`.tif`) for tree crown detection.
- **Satellite imagery** (Sentinel-2 via Google Earth Engine) for landscape-scale carbon context.
- **Optional point clouds** (`.las/.laz`) for future tree height integration.

## 1) What this MVP does
1. Upload drone imagery in Streamlit.
2. Detect tree crowns with DeepForest.
3. Convert crown boxes from pixels to map coordinates and estimate crown diameter (meters).
4. Draw an AOI on the map and run Sentinel-2 NDVI-based carbon heatmap.
5. Query a local allometric database to estimate carbon tonnage per tree.

## 2) Folder structure
- `app.py` → Streamlit UI (Dashboard / Drone Upload / Satellite Analysis)
- `src/` → light orchestration helpers
- `models/` → database + carbon calculator
- `utils/` → drone, satellite, and CHM processing modules
- `data/` → local SQLite DB and uploaded sample files

## 3) Quick start (local)
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```

Open browser: `http://localhost:8501`

## 4) Earth Engine setup
1. Create a Google Earth Engine account.
2. Authenticate once from terminal:
   ```bash
   python -c "import ee; ee.Authenticate(); ee.Initialize()"
   ```
3. In the app, go to **Satellite Analysis**, draw your AOI, run analysis.

## 5) Coordinate system note (important)
Drone detections start as **pixel coordinates**. We transform them into georeferenced map coordinates using the raster transform and CRS.
- If source CRS is geographic (`EPSG:4326`, degrees), we reproject to UTM for meter-based area and diameter.
- Carbon equations use metric units, so this step is required.

## 6) Low-bandwidth tips
- Use clipped orthomosaics (project area only, not full flight).
- Keep map zoom moderate and AOI focused.
- Earth Engine reduction uses `bestEffort` and limited `tileScale` to avoid heavy requests.

## 7) Docker run
```bash
docker build -t opencarbon .
docker run -p 8501:8501 opencarbon
```

## 8) Next implementation priorities
- Replace placeholder CHM function with full WhiteboxTools LAS → DEM/DSM → CHM chain.
- Replace demo allometric lookup with your community-approved field-calibrated equation.
- Add PostGIS connection string for multi-user deployments.
