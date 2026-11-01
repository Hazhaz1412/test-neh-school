#!/usr/bin/env python3
"""Downloads the open-licence assets of the town map and records where each came from."""
import concurrent.futures, hashlib, json, os, re, subprocess, sys, tempfile, urllib.request

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
AGENT = {"User-Agent": "NEH-School asset fetch"}
TEXTURES = ["laminate_floor_02", "asphalt_02", "concrete_pavers", "white_plaster_02", "peeling_painted_wall", "painted_metal_shutter",
            "rusty_metal_shutter", "corrugated_iron", "rusty_corrugated_iron", "clay_roof_tiles", "square_tiled_wall",
            "dirt", "brown_mud"]
MODELS = ["plastic_monobloc_chair_01", "plastic_crate_01", "street_lamp_02", "potted_plant_02", "potted_plant_04",
          "planter_pot_clay", "concrete_road_barrier", "CoffeeCart_01", "bananas", "cardboard_box_01", "utility_box_01",
          "chess_set", "Sofa_01", "dining_table", "dining_chair_02", "electric_stove", "television_02", "vintage_microwave"]
SKIES = ["qwantani_morning_puresky", "qwantani_noon_puresky", "qwantani_late_afternoon_puresky", "qwantani_dusk_1_puresky"]
PEOPLE = {"Adults": ["Female_Adult_02", "Female_Adult_05", "Female_Adult_07", "Female_Adult_12", "Male_Adult_01",
                     "Male_Adult_06", "Male_Adult_08", "Male_Adult_14"], "Professions": ["Security_Male_01"], "Children": ["Male_Child_01"]}
CLIPS = ["static/f_idle_neutral_01", "static/f_gestic_talk_neutral_01", "static/f_sit_chair_idle_neutral_01",
         "static/m_gestic_talk_neutral_01", "static/m_sit_chair_idle_neutral_01", "xy/f_walk_slow_01"]
ROCKETBOX = "https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/master/"
SCOOTER = "https://static.poly.pizza/98e3c49f-0ec8-42c6-8613-6859423309a7.glb"
# CC0 on Poly Pizza; each was checked on its model page.
HOME = {"bed": "44976488-9b2d-4ffb-b07d-b64c2768a1bc", "fridge": "f4b6db1d-0eed-48b1-9a59-df879aaee393", "toilet": "68e03d0b-fd3e-4954-9852-8b3cf63c536d", "basin": "f847ce7f-46d7-4ee7-92cd-fcf1cad5a7c2"}
sources = []

def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path):
        with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120) as reply:
            data = reply.read()
        with open(path, "wb") as out:
            out.write(data)
    with open(path, "rb") as done:
        sources.append({"file": os.path.relpath(path, ROOT), "url": url, "sha256": hashlib.sha256(done.read()).hexdigest()})

def poly_files(name):
    with urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + name, headers=AGENT), timeout=60) as reply:
        return json.load(reply)

def poly_texture(name):
    files = poly_files(name)
    get(files["Diffuse"]["1k"]["jpg"]["url"], f"{ROOT}/polyhaven_town/textures/{name}_diff.jpg")
    get(files["nor_gl"]["1k"]["jpg"]["url"], f"{ROOT}/polyhaven_town/textures/{name}_nor.jpg")

def poly_model(name):
    entry = poly_files(name)["gltf"]["1k"]["gltf"]
    get(entry["url"], f"{ROOT}/polyhaven_town/models/{name}/{name}.gltf")
    for relative, item in entry["include"].items():
        get(item["url"], f"{ROOT}/polyhaven_town/models/{name}/{relative}")

def poly_sky(name):
    get(poly_files(name)["hdri"]["2k"]["hdr"]["url"], f"{ROOT}/polyhaven_town/sky/{name}.hdr")

def person(group, name, tree):
    base = f"Assets/Avatars/{group}/{name}"
    get(f"{ROOT_URL(base)}/Export/{name}.fbx", f"{ROOT}/rocketbox/townsfolk/{name}.fbx")
    for part in ("body", "head"):
        tga = next(p for p in tree if p.startswith(base + "/Textures/") and p.endswith(f"_{part}_color.tga"))
        target = f"{ROOT}/rocketbox/townsfolk/textures/{name}_{part}.jpg"
        if not os.path.exists(target):
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with tempfile.TemporaryDirectory() as folder:
                raw = os.path.join(folder, "source.tga")
                with urllib.request.urlopen(ROCKETBOX + tga, timeout=120) as reply, open(raw, "wb") as out:
                    out.write(reply.read())
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-vf", "scale=1024:-1", "-q:v", "4", target], check=True)
        sources.append({"file": os.path.relpath(target, ROOT), "url": ROCKETBOX + tga, "note": "resized to 1024 JPG"})

def ROOT_URL(path):
    return ROCKETBOX + path

def clip(spec, tree):
    folder, name = spec.split("/")
    match = next(p for p in tree if f"motextr_{folder}/" in p and p.endswith(f"/{name}.max.fbx"))
    get(ROCKETBOX + match, f"{ROOT}/rocketbox/animations/{name}.fbx")

def main():
    with urllib.request.urlopen(urllib.request.Request("https://api.github.com/repos/microsoft/Microsoft-Rocketbox/git/trees/master?recursive=1", headers=AGENT), timeout=60) as reply:
        tree = [item["path"] for item in json.load(reply)["tree"]]
    jobs = [(poly_texture, t) for t in TEXTURES] + [(poly_model, m) for m in MODELS] + [(poly_sky, s) for s in SKIES]
    jobs += [(person, g, n, tree) for g, names in PEOPLE.items() for n in names]
    jobs += [(clip, c, tree) for c in CLIPS]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        for job in [pool.submit(*j) for j in jobs]:
            job.result()
    get(SCOOTER, f"{ROOT}/polypizza_town/low_poly_scooter.glb")
    for name, asset in HOME.items():
        get(f"https://static.poly.pizza/{asset}.glb", f"{ROOT}/home/{name}.glb")
    with open(f"{ROOT}/town_sources.json", "w") as out:
        json.dump(sorted(sources, key=lambda s: s["file"]), out, indent=1)
    print(len(sources), "files")

main()
