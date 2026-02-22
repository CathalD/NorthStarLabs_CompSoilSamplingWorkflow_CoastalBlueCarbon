from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import geopandas as gpd
import numpy as np
import pandas as pd
import rasterio
from pyproj import CRS
from shapely.geometry import box


@dataclass
class DroneDetectionResult:
    crowns_gdf: gpd.GeoDataFrame
    source_crs: CRS


def _load_deepforest_model():
    """Lazily import DeepForest because model download is heavy in low-bandwidth settings."""
    from deepforest import main

    model = main.deepforest()
    model.use_release(check_release=False)
    return model


def detect_tree_crowns_from_orthomosaic(orthomosaic_path: str) -> DroneDetectionResult:
    """Run 2D crown detection and convert pixel boxes to map coordinates.

    CRS transformation note:
    - DeepForest predicts bounding boxes in **pixel coordinates** for the image array.
    - Rasterio transform converts those pixels to projected map coordinates (often UTM meters).
    - If the raster is in geographic CRS (degrees), downstream workflows should reproject to
      a metric CRS before using area/diameter calculations.
    """
    raster_path = Path(orthomosaic_path)
    with rasterio.open(raster_path) as src:
        transform = src.transform
        crs = CRS.from_user_input(src.crs)

    model = _load_deepforest_model()
    detections_df = model.predict_file(str(raster_path))
    if detections_df is None or detections_df.empty:
        empty = gpd.GeoDataFrame(pd.DataFrame(columns=["xmin", "ymin", "xmax", "ymax"]), geometry=[], crs=crs)
        return DroneDetectionResult(crowns_gdf=empty, source_crs=crs)

    polygons = []
    for _, row in detections_df.iterrows():
        xmin, ymin, xmax, ymax = float(row.xmin), float(row.ymin), float(row.xmax), float(row.ymax)

        # Pixel -> map coordinate conversion. Pixel-space origin is top-left; raster transform handles orientation.
        x1, y1 = rasterio.transform.xy(transform, ymin, xmin, offset="ul")
        x2, y2 = rasterio.transform.xy(transform, ymax, xmax, offset="ul")
        polygons.append(box(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2)))

    crowns = gpd.GeoDataFrame(detections_df.copy(), geometry=polygons, crs=crs)

    # Ensure metric units for area and crown diameter.
    if crowns.crs and crowns.crs.is_geographic:
        centroid = crowns.unary_union.centroid
        utm_zone = int((centroid.x + 180) // 6) + 1
        utm_epsg = 32600 + utm_zone if centroid.y >= 0 else 32700 + utm_zone
        crowns = crowns.to_crs(epsg=utm_epsg)

    crowns["centroid"] = crowns.geometry.centroid
    crowns["crown_area_m2"] = crowns.geometry.area
    crowns["crown_diameter_m"] = 2.0 * np.sqrt(crowns["crown_area_m2"] / np.pi)

    return DroneDetectionResult(crowns_gdf=crowns, source_crs=crs)
