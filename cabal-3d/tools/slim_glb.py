#!/usr/bin/env python3
"""Achica un GLB (p. ej. de Meshy AI) reescribiendo solo las texturas embebidas; la geometria no se toca.

    python3 tools/slim_glb.py original.glb assets/meshy/oasis_village.glb [--albedo 2048] [--normal 1024] [--mr 1024]

* albedo: JPEG calidad 88 (PNG si tiene transparencia); normal: JPEG calidad 92 sin submuestreo de color;
  metallic-roughness / oclusion / emision: JPEG calidad 85. Los lados se reducen al tamano indicado (si son mayores).
* Reescribe los bufferViews de las imagenes, sus offsets/largos y el chunk BIN. Requiere Pillow.
La version usada para la aldea del juego: 100.806 triangulos intactos, texturas 2048 / 1024 / 1024 (26.7 MB -> 7.2 MB).
"""
import argparse
import io
import json
import struct

from PIL import Image


def read_glb(path):
    data = open(path, "rb").read()
    magic, version, _length = struct.unpack("<4sII", data[:12])
    if magic != b"glTF" or version != 2:
        raise SystemExit("no es un GLB 2.0")
    off, js, binc = 12, None, b""
    while off < len(data):
        clen, ctype = struct.unpack("<II", data[off:off + 8])
        chunk = data[off + 8:off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen
    return js, binc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--albedo", type=int, default=2048)
    ap.add_argument("--normal", type=int, default=1024)
    ap.add_argument("--mr", type=int, default=1024)
    a = ap.parse_args()
    j, b = read_glb(a.src)
    # rol de cada imagen segun los materiales
    role = {}
    tex = j.get("textures", [])
    for m in j.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        for key, r in (("baseColorTexture", "albedo"), ("metallicRoughnessTexture", "mr")):
            if key in pbr:
                role[tex[pbr[key]["index"]]["source"]] = r
        if "normalTexture" in m:
            role[tex[m["normalTexture"]["index"]]["source"]] = "normal"
    size_of = {"albedo": a.albedo, "normal": a.normal, "mr": a.mr}
    img_view = {im["bufferView"]: (i, im) for i, im in enumerate(j.get("images", [])) if "bufferView" in im}
    newbin = bytearray()
    views = []
    for i, bv in enumerate(j["bufferViews"]):
        data = b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        if i in img_view:
            idx, im = img_view[i]
            r = role.get(idx, "mr")
            I = Image.open(io.BytesIO(data))
            has_alpha = I.mode in ("RGBA", "LA") or "transparency" in I.info
            size = size_of.get(r, a.mr)
            if max(I.size) > size:
                k = size / max(I.size)
                I = I.resize((max(1, round(I.size[0] * k)), max(1, round(I.size[1] * k))), Image.LANCZOS)
            out = io.BytesIO()
            if has_alpha and r == "albedo":
                I.convert("RGBA").save(out, "PNG", optimize=True)
                im["mimeType"] = "image/png"
            else:
                q, ss = {"albedo": (88, 2), "normal": (92, 0)}.get(r, (85, 2))
                I.convert("RGB").save(out, "JPEG", quality=q, optimize=True, subsampling=ss)
                im["mimeType"] = "image/jpeg"
            data = out.getvalue()
            print("imagen %d (%s): %s -> %d KB" % (idx, r, I.size, len(data) // 1024))
        while len(newbin) % 4:
            newbin.append(0)
        nv = dict(bv)
        nv["byteOffset"] = len(newbin)
        nv["byteLength"] = len(data)
        views.append(nv)
        newbin += data
    while len(newbin) % 4:
        newbin.append(0)
    j["bufferViews"] = views
    j["buffers"][0]["byteLength"] = len(newbin)
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(newbin)
    with open(a.dst, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(newbin), 0x004E4942) + bytes(newbin))
    print("%s: %.2f MB" % (a.dst, total / 1e6))


if __name__ == "__main__":
    main()
