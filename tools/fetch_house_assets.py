#!/usr/bin/env python3
"""Downloads the Poly Haven (CC0) models for the inside of the meadow's little house and records
where each file came from in assets/polyhaven_house/sources.json."""
import hashlib, json, os, urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = "assets/polyhaven_house"
AGENT = {"User-Agent": "NEH-School asset fetch"}
MODELS = ["ArmChair_01", "coffee_table_round_01", "wooden_bookshelf_worn", "book_encyclopedia_set_01",
          "vintage_grandfather_clock_01", "hanging_picture_frame_01", "vintage_oil_lamp", "potted_plant_01", "mantel_clock_01"]
files = []

def get(url, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path):
        with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120) as reply:
            data = reply.read()
        with open(path, "wb") as out:
            out.write(data)
    with open(path, "rb") as done:
        data = done.read()
    files.append({"file": rel, "download": url, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})

for name in MODELS:
    with urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + name, headers=AGENT), timeout=60) as reply:
        entry = json.load(reply)["gltf"]["1k"]["gltf"]
    get(entry["url"], f"{OUT}/{name}/{name}_1k.gltf")
    for relative, item in entry["include"].items():
        get(item["url"], f"{OUT}/{name}/{relative}")
    print("ok", name)

with open(os.path.join(ROOT, OUT, "sources.json"), "w") as out:
    json.dump({"source": "https://polyhaven.com", "license": "CC0 1.0 https://polyhaven.com/license",
               "downloaded": "2026-11-14", "pages": {m: "https://polyhaven.com/a/" + m for m in MODELS}, "files": files}, out, indent=1)
