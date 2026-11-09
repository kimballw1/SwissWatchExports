"""Build interactive/index.html from the project's clean data and tables.

Run from the project root:   python3 interactive/build.py

It reads data/clean, output/tables and the rendered write-up, packs what the page
needs into one JSON blob, and inlines that plus the scripts in interactive/src
into a single self-contained index.html.
"""
import json
import shutil
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "interactive" / "src"
OUT = ROOT / "interactive"
# Natural Earth 110m countries. This copy ships with the pyogrio package.
import pyogrio
SHP = Path(pyogrio.__file__).parent / "tests/fixtures/naturalearth_lowres/naturalearth_lowres.shp"

N_SPHERE = 90000     # candidate dots on the sphere before the land mask

# Where each destination's spike sits (lat, lon). Countries not listed use a point inside their polygon.
ANCHOR = {
    "US": (39, -98), "HK": (22.3, 114.2), "CN": (33, 108), "JP": (36, 138), "SG": (1.3, 103.8), "GB": (53, -1.5),
    "IT": (42.8, 12.5), "FR": (46.6, 2.4), "DE": (51, 10.3), "AE": (24.3, 54.4), "KR": (36.5, 127.9), "ES": (40, -3.7),
    "TW": (23.7, 121), "SA": (24, 45), "AU": (-25, 134), "MX": (23.5, -102), "AT": (47.5, 14.5), "NL": (52.2, 5.5),
    "RU": (56, 40), "TR": (39, 35), "CA": (54, -100), "QA": (25.3, 51.2), "IN": (22, 79), "TH": (15, 101),
    "KW": (29.3, 47.7), "BE": (50.6, 4.6), "PT": (39.5, -8), "GR": (39, 22), "BH": (26.1, 50.55), "IL": (31.5, 34.9),
    "MY": (4, 102), "BR": (-10, -52), "ID": (-2, 113), "PH": (13, 122), "LB": (33.9, 35.8), "PA": (8.5, -80),
    "MO": (22.16, 113.56), "SE": (60, 15), "DK": (56, 9.5), "NO": (61, 9), "IE": (53.2, -8), "PL": (52, 19),
    "ZA": (-29, 24), "NZ": (-42, 172), "AR": (-35, -65), "OM": (21, 57), "EG": (27, 30), "LI": (47.15, 9.55),
    "CH": (46.8, 8.2),
}
# Small territories the 110m base map has no polygon for, and old or special customs codes.
SMALL = {
    "VI": (18.34, -64.9), "KY": (19.3, -81.25), "VG": (18.43, -64.62), "AN": (12.2, -69), "MT": (35.9, 14.4), "AW": (12.5, -69.97),
    "SX": (18.04, -63.07), "SC": (-4.68, 55.49), "GU": (13.45, 144.78), "BL": (17.9, -62.83), "BB": (13.17, -59.55), "GP": (16.25, -61.55),
    "MU": (-20.3, 57.6), "BM": (32.3, -64.75), "TC": (21.75, -71.6), "GI": (36.14, -5.35), "LC": (13.9, -60.97), "AG": (17.08, -61.8),
    "AD": (42.55, 1.58), "KN": (17.3, -62.73), "CW": (12.17, -68.98), "MV": (3.2, 73.2), "RE": (-21.1, 55.5), "MH": (7.1, 171.2),
    "DM": (15.42, -61.35), "YU": (44, 20.5), "BQ": (12.18, -68.25), "XK": (42.6, 20.9), "SM": (43.94, 12.46), "CS": (44, 20.9),
    "XS": (44, 20.9), "XM": (42.7, 19.3), "XC": (35.89, -5.3), "XL": (35.29, -2.94), "AS": (-14.3, -170.7), "WS": (-13.8, -172.1),
    "PF": (-17.6, -149.5), "ST": (0.3, 6.6), "VA": (41.9, 12.45), "AI": (18.22, -63.05), "GF": (4, -53), "TK": (-9.2, -171.8),
    "GD": (12.1, -61.68), "VC": (13.25, -61.2), "MQ": (14.65, -61), "IO": (-7.3, 72.4), "MP": (15.2, 145.75), "CV": (15.1, -23.6),
    "PM": (46.8, -56.3), "YT": (-12.8, 45.15), "TP": (-8.8, 125.7), "FM": (6.9, 158.2), "SH": (-15.95, -5.7), "CC": (-12.15, 96.85),
    "PN": (-25.07, -130.1), "CX": (-10.48, 105.63), "FO": (62, -6.8), "NR": (-0.53, 166.93), "NF": (-29.03, 167.95), "CK": (-21.2, -159.8),
    "PW": (7.5, 134.6), "GS": (-54.4, -36.6), "BV": (-54.42, 3.35), "HM": (-53.1, 73.5), "UM": (19.3, 166.6),
}
ANCHOR.update(SMALL)
OLD_NAMES = {"AN": "Netherlands Antilles", "YU": "Yugoslavia", "CS": "Serbia and Montenegro", "XS": "Serbia", "XM": "Montenegro",
             "XK": "Kosovo", "XC": "Ceuta", "XL": "Melilla", "TP": "East Timor", "NA": "Namibia", "UM": "US Minor Outlying Islands"}
SHORT = {"HK": "Hong Kong", "US": "United States", "GB": "United Kingdom", "AE": "United Arab Emirates", "KR": "South Korea",
         "RU": "Russia", "TW": "Taiwan", "MO": "Macau", "CZ": "Czechia", "TR": "Turkey", "VN": "Vietnam"}
TIERS = ["steel_quartz", "steel_mech", "precious_quartz", "precious_mech"]


def decompose(line_year):
    """Volume / price / mix split of the log change in value, same steps as code/02 decomposition.

    line_year: rows of (year, tariff_line, exports_chf, units). Returns one row per year after the first.
    """
    tot = line_year.groupby("year")[["exports_chf", "units"]].sum().sort_index()
    tot = tot.reindex(range(2000, 2026))
    if (tot.fillna(0) <= 0).any().any():
        return None
    avg = tot.exports_chf / tot.units
    lines = line_year.copy()
    lines["share"] = lines.exports_chf / lines.groupby("year").exports_chf.transform("sum")
    lines["uv"] = lines.exports_chf / lines.units
    lines = lines.sort_values(["tariff_line", "year"])
    grp = lines.groupby("tariff_line")
    consecutive = grp.year.diff() == 1
    dlog_uv = (np.log(lines.uv) - np.log(grp.uv.shift())).where(consecutive)
    avg_share = ((lines.share + grp.share.shift()) / 2).where(consecutive)
    term = (avg_share * dlog_uv).replace([np.inf, -np.inf], np.nan)
    price = term.groupby(lines.year).sum().reindex(tot.index).fillna(0)
    out = pd.DataFrame({
        "value": np.log(tot.exports_chf).diff(),
        "volume": np.log(tot.units).diff(),
        "price": price,
    })
    out["mix"] = np.log(avg).diff() - out.price
    return out.iloc[1:]


def main():
    d = pd.read_csv(ROOT / "data/clean/clean_watch_exports_monthly.csv", na_values=[""], keep_default_na=False)
    d["month"] = pd.to_datetime(d["month"])
    d["year"] = d.month.dt.year
    full = d[d.year <= 2025]
    years = list(range(2000, 2026))
    iso_map = pd.read_csv(SRC / "iso_map.csv", na_values=[""], keep_default_na=False).set_index("iso2")
    data = {"years": years}

    # ---- world map: borders and land dots -------------------------------------------------
    world = gpd.read_file(SHP)
    world.loc[world.name == "France", "iso_a3"] = "FRA"
    world.loc[world.name == "Norway", "iso_a3"] = "NOR"

    top = d.groupby("iso2").exports_chf.sum().sort_values(ascending=False)
    dest, unplaced = [], []
    for iso in top.index:
        iso3 = "NAM" if iso == "NA" else iso_map.iso3.get(iso)
        poly = world[world.iso_a3 == iso3]
        if iso in ANCHOR:
            lat, lon = ANCHOR[iso]
        elif len(poly):
            p = poly.geometry.iloc[0].representative_point()
            lat, lon = p.y, p.x
        else:
            unplaced.append(iso)
            continue
        name = SHORT.get(iso) or OLD_NAMES.get(iso) or iso_map.name.get(iso) or iso
        if name == "NA":
            name = iso
        dest.append({"iso": iso, "iso3": iso3, "name": name, "lat": round(lat, 2), "lon": round(lon, 2)})
    iso3_to_k = {x["iso3"]: k for k, x in enumerate(dest) if isinstance(x["iso3"], str) and x["iso3"] != "NA"}

    i = np.arange(N_SPHERE)
    y = 1 - 2 * (i + 0.5) / N_SPHERE
    lat = np.degrees(np.arcsin(y))
    lon = (np.degrees(i * 2.399963229728653) + 180) % 360 - 180
    pts = gpd.GeoDataFrame(geometry=gpd.points_from_xy(lon, lat), crs=world.crs)
    hit = gpd.sjoin(pts, world[["iso_a3", "geometry"]], predicate="within", how="inner")
    hit = hit[~hit.index.duplicated()]
    dots = []
    for idx, iso3 in zip(hit.index, hit.iso_a3):
        dots += [int(round(lat[idx] * 100)), int(round(lon[idx] * 100)), iso3_to_k.get(iso3, -1)]
    borders = []
    for geom in world.geometry.simplify(0.15):
        for poly in (geom.geoms if geom.geom_type == "MultiPolygon" else [geom]):
            ring = []
            for x, yy in poly.exterior.coords:
                ring += [int(round(x * 10)), int(round(yy * 10))]
            borders.append(ring)
    data["globe"] = {"dots": dots, "borders": borders}

    # ---- destination series: 12-month rolling, sampled every quarter -----------------------
    months = pd.date_range("2000-01-01", "2026-09-01", freq="MS")
    keep = list(range(11, len(months), 3))
    data["months"] = [months[k].strftime("%Y-%m") for k in keep]
    world_m = d.groupby("month")[["exports_chf", "units"]].sum().reindex(months).fillna(0).rolling(12).sum()
    data["world"] = {"value": (world_m.exports_chf.values[keep] / 1e5).round().astype(int).tolist(),
                     "units": world_m.units.values[keep].round().astype(int).tolist()}

    panel = pd.read_csv(ROOT / "data/clean/merged_data/panel_annual.csv", na_values=[""], keep_default_na=False)
    for x in dest:
        g = d[d.iso2 == x["iso"]]
        m = g.groupby("month")[["exports_chf", "units"]].sum().reindex(months).fillna(0).rolling(12).sum()
        x["value"] = (m.exports_chf.values[keep] / 1e5).round().astype(int).tolist()   # CHF 100k
        x["units"] = m.units.values[keep].round().astype(int).tolist()
        # tier split of value and pieces, first and last full year
        gt = g[g.year.isin([2000, 2025])].groupby(["year", "tier"])[["exports_chf", "units"]].sum()
        x["tiers"] = {str(yr): {t: [int(gt.exports_chf.get((yr, t), 0)), int(gt.units.get((yr, t), 0))] for t in TIERS} for yr in (2000, 2025)}
        # volume / price / mix for this destination
        ly = g[g.year <= 2025].groupby(["year", "tariff_line"], as_index=False)[["exports_chf", "units"]].sum()
        dec = decompose(ly[ly.units > 0])
        if dec is not None:
            x["dec"] = {c: dec[c].round(4).tolist() for c in ["value", "volume", "price", "mix"]}
        # the regression covariates, where the panel has them
        p = panel[panel.iso2 == x["iso"]].drop_duplicates("year").set_index("year").reindex(range(2000, 2025))
        if p.top1_income.notna().any():
            x["top1"] = [None if pd.isna(v) else round(float(v), 4) for v in p.top1_income]
            x["gdp_pc"] = [None if pd.isna(v) else int(v) for v in p.gdp_pc_ppp]
            x["equity"] = [None if pd.isna(v) else round(float(v), 1) for v in p.equity_index]
    for x in dest:
        del x["iso3"]
    data["dest"] = dest

    # ---- totals by tier (annual) ------------------------------------------------------------
    tiers = {}
    for name in TIERS:
        a = full[full.tier == name].groupby("year")[["exports_chf", "units"]].sum().reindex(years).fillna(0)
        tiers[name] = {"value": a.exports_chf.astype(int).tolist(), "units": a.units.astype(int).tolist()}
    data["tiers"] = tiers
    tot = full.groupby("year")[["exports_chf", "units"]].sum().reindex(years)
    data["tot"] = {"value": tot.exports_chf.astype(int).tolist(), "units": tot.units.astype(int).tolist()}

    # ---- unit value distribution by year, weighted by money and by pieces ------------------
    lo, hi, nb = 1.3, 5.3, 96
    cells = full[(full.units > 0) & (full.exports_chf > 0)].copy()
    cells["lu"] = np.log10(cells.exports_chf / cells.units).clip(lo, hi - 1e-9)
    uv = {"lo": lo, "hi": hi, "money": [], "pieces": []}
    for yr in years:
        c = cells[cells.year == yr]
        for key, wcol in [("money", "exports_chf"), ("pieces", "units")]:
            h, _ = np.histogram(c.lu, bins=nb, range=(lo, hi), weights=c[wcol])
            uv[key].append((h / h.sum()).round(5).tolist())
    data["uv"] = uv

    # ---- the decomposition table the project already wrote ---------------------------------
    dec = pd.read_csv(ROOT / "output/tables/decomposition_annual.csv")
    data["dec"] = {"year": dec.year.tolist(), "value": dec.value_change.round(4).tolist(), "volume": dec.volume_effect.round(4).tolist(),
                   "price": dec.price_effect.round(4).tolist(), "mix": dec.mix_effect.round(4).tolist()}
    mine = decompose(full.groupby(["year", "tariff_line"], as_index=False)[["exports_chf", "units"]].sum())
    gap = float(np.abs(mine[["value", "volume", "price", "mix"]].values - dec[["value_change", "volume_effect", "price_effect", "mix_effect"]].values).max())

    # ---- the paper ---------------------------------------------------------------------------
    paper = ROOT / "WriteUp_draft.html"
    data["paper"] = False
    if paper.exists():
        shutil.copyfile(paper, OUT / "paper.html")
        files = ROOT / "WriteUp_draft_files"
        if files.exists():
            shutil.copytree(files, OUT / "WriteUp_draft_files", dirs_exist_ok=True)
        data["paper"] = True

    # ---- assemble ----------------------------------------------------------------------------
    html = (SRC / "template.html").read_text()
    js = "\n".join((SRC / f).read_text() for f in ["core.js", "globe.js", "surface.js", "particles.js", "main.js"])
    html = html.replace("/*DATA*/", json.dumps(data, separators=(",", ":"))).replace("/*SCRIPTS*/", js)
    (OUT / "index.html").write_text(html)

    print(f"index.html {len(html) // 1024} KB · land dots {len(dots) // 3} · border rings {len(borders)} · destinations {len(dest)}")
    print("decomposition check against output/tables/decomposition_annual.csv, max abs gap:", round(gap, 6))
    print("destinations with a decomposition:", sum("dec" in x for x in dest), "· with wealth data:", sum("top1" in x for x in dest))
    print("share of all export value on the globe:", round(float(top.loc[[x["iso"] for x in dest]].sum() / top.sum()), 5), "· codes not placed:", unplaced)


if __name__ == "__main__":
    main()
