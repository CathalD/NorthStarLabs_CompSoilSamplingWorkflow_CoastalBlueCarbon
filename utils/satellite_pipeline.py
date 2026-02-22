from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import folium


@dataclass
class SatelliteResult:
    map_object: folium.Map
    mean_ndvi: float


def estimate_carbon_from_aoi_geojson(aoi_geojson: dict[str, Any], start_date: str = "2023-01-01", end_date: str = "2024-12-31") -> SatelliteResult:
    """Fetch cloud-masked Sentinel-2 composite and create NDVI-derived carbon layer.

    Low-bandwidth optimization:
    - Use reduced resolution map tiles via a moderate zoom start.
    - Use `bestEffort=True` and `tileScale=2` for lightweight server-side reductions.
    """
    import ee

    try:
        ee.Initialize()
    except Exception:
        ee.Authenticate()
        ee.Initialize()

    aoi = ee.Geometry(aoi_geojson["geometry"])
    s2 = (
        ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
        .filterBounds(aoi)
        .filterDate(start_date, end_date)
        .filter(ee.Filter.lt("CLOUDY_PIXEL_PERCENTAGE", 20))
    )
    composite = s2.median().clip(aoi)
    ndvi = composite.normalizedDifference(["B8", "B4"]).rename("ndvi")

    # Example linear conversion; swap with calibrated project regression when available.
    carbon = ndvi.multiply(12).add(2).rename("carbon_t_ha")

    stats = carbon.reduceRegion(
        reducer=ee.Reducer.mean(),
        geometry=aoi,
        scale=20,
        bestEffort=True,
        tileScale=2,
    ).getInfo()
    mean_carbon = float(stats.get("carbon_t_ha", 0.0))

    map_center = [0, 0]
    if "coordinates" in aoi_geojson["geometry"]:
        coords = aoi_geojson["geometry"]["coordinates"][0]
        lat = sum(pt[1] for pt in coords) / len(coords)
        lon = sum(pt[0] for pt in coords) / len(coords)
        map_center = [lat, lon]

    m = folium.Map(location=map_center, zoom_start=11, control_scale=True)

    map_id_dict = ee.Image(carbon).getMapId({"min": 0, "max": 20, "palette": ["#2c7bb6", "#ffff8c", "#d7191c"]})
    folium.TileLayer(
        tiles=map_id_dict["tile_fetcher"].url_format,
        attr="Google Earth Engine",
        name="Estimated carbon t/ha",
        overlay=True,
        control=True,
    ).add_to(m)

    folium.GeoJson(aoi_geojson, name="AOI").add_to(m)
    folium.LayerControl().add_to(m)
    return SatelliteResult(map_object=m, mean_ndvi=mean_carbon)
