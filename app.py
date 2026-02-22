from __future__ import annotations

import json
from pathlib import Path

import streamlit as st
from streamlit_folium import st_folium
import folium
from folium.plugins import Draw

from models.calculator import Calculator
from models.database import DatabaseManager
from utils.chm_pipeline import attach_tree_heights_from_chm, generate_chm_from_las_placeholder
from utils.drone_pipeline import detect_tree_crowns_from_orthomosaic
from utils.satellite_pipeline import estimate_carbon_from_aoi_geojson

st.set_page_config(page_title="OpenCarbon MVP", layout="wide")


def init_state() -> None:
    db = DatabaseManager()
    db.create_tables()
    db.seed_defaults()
    st.session_state.setdefault("db", db)
    st.session_state.setdefault("calculator", Calculator(db))


def dashboard_page() -> None:
    st.title("🌳 OpenCarbon Dashboard")
    st.write("Estimate above-ground carbon from drone and satellite data.")
    st.info("Designed for low-bandwidth field teams: lightweight UI, optional heavy processing modules.")


def drone_upload_page() -> None:
    st.header("Drone Analysis")
    ortho = st.file_uploader("Upload orthomosaic (.tif)", type=["tif", "tiff"])
    las = st.file_uploader("Upload point cloud (.las/.laz)", type=["las", "laz"])

    if ortho and st.button("Run crown detection"):
        upload_dir = Path("data/uploads")
        upload_dir.mkdir(parents=True, exist_ok=True)
        ortho_path = upload_dir / ortho.name
        ortho_path.write_bytes(ortho.getbuffer())

        with st.spinner("Running DeepForest crown detection..."):
            result = detect_tree_crowns_from_orthomosaic(str(ortho_path))

        crowns = result.crowns_gdf
        st.success(f"Detected {len(crowns)} potential tree crowns")
        if not crowns.empty:
            calc: Calculator = st.session_state["calculator"]
            crowns["est_carbon_t"] = crowns.apply(
                lambda r: calc.estimate_carbon_tonnes(r["crown_diameter_m"], r.get("max_height_m") or 10.0),
                axis=1,
            )
            st.dataframe(crowns[["crown_area_m2", "crown_diameter_m", "est_carbon_t"]].head(50))
            st.caption("Height defaults to 10m before CHM integration.")
            st.download_button("Download detections as GeoJSON", crowns.to_json(), file_name="tree_crowns.geojson")

    if las and st.button("Run CHM placeholder"):
        upload_dir = Path("data/uploads")
        upload_dir.mkdir(parents=True, exist_ok=True)
        las_path = upload_dir / las.name
        las_path.write_bytes(las.getbuffer())
        chm_path = upload_dir / f"{las_path.stem}_chm.tif"

        out = generate_chm_from_las_placeholder(str(las_path), str(chm_path))
        st.success(f"Created placeholder CHM file at {out}")


def satellite_analysis_page() -> None:
    st.header("Satellite Analysis (Sentinel-2 + Earth Engine)")
    m = folium.Map(location=[49.2, -123.1], zoom_start=7, control_scale=True)
    Draw(export=True, filename="aoi.geojson", position="topleft").add_to(m)
    map_state = st_folium(m, height=500, width=900)

    if map_state and map_state.get("last_active_drawing"):
        feature = {
            "type": "Feature",
            "properties": {},
            "geometry": map_state["last_active_drawing"],
        }
        fc = {"type": "FeatureCollection", "features": [feature]}
        st.code(json.dumps(fc, indent=2), language="json")

        if st.button("Run Sentinel-2 carbon estimation"):
            with st.spinner("Querying Earth Engine..."):
                result = estimate_carbon_from_aoi_geojson(feature)
            st.success(f"Mean estimated carbon: {result.mean_ndvi:.2f} t/ha")
            st_folium(result.map_object, height=500, width=900)


def main() -> None:
    init_state()

    st.sidebar.title("Navigation")
    page = st.sidebar.radio("Go to", ["Dashboard", "Drone Upload", "Satellite Analysis"])

    if page == "Dashboard":
        dashboard_page()
    elif page == "Drone Upload":
        drone_upload_page()
    else:
        satellite_analysis_page()


if __name__ == "__main__":
    main()
