from __future__ import annotations

from pathlib import Path

import geopandas as gpd


def generate_chm_from_las_placeholder(las_path: str, output_chm_tif: str) -> str:
    """Placeholder CHM generation.

    Intended production workflow with WhiteboxTools:
    1) Classify ground points from LAS/LAZ.
    2) Create DEM and DSM rasters.
    3) CHM = DSM - DEM.
    """
    from whitebox import WhiteboxTools

    wbt = WhiteboxTools()
    wbt.set_compress_rasters(True)
    # Placeholder: copy path to indicate expected output contract.
    # Replace with wbt.lidar_tin_gridding + raster_calculator pipeline in implementation phase.
    Path(output_chm_tif).touch(exist_ok=True)
    return output_chm_tif


def attach_tree_heights_from_chm(tree_boxes: gpd.GeoDataFrame, chm_path: str) -> gpd.GeoDataFrame:
    """Sample CHM max value per tree polygon."""
    import rasterio
    from rasterstats import zonal_stats

    stats = zonal_stats(tree_boxes.geometry, chm_path, stats=["max"], nodata=-9999)
    tree_boxes = tree_boxes.copy()
    tree_boxes["max_height_m"] = [s.get("max") if s else None for s in stats]
    return tree_boxes
