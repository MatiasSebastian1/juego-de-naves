#!/usr/bin/env python3
"""Arma el modelo del personaje del juego a partir de un GLB de Meshy (con malla + esqueleto).

    python3 tools/build_character.py original_idle.glb assets/meshy/character.glb [--albedo 2048] [--normal 1024] [--mr 1024]

* Descarta las animaciones (las animaciones se guardan aparte con tools/build_anims.gd en un AnimationLibrary) y todo
  lo que ya no se referencia (accesores y bufferViews de las animaciones).
* Recomprime las texturas embebidas como slim_glb.py: albedo JPEG q88 (2048), normal JPEG q92 (1024, sin submuestreo de
  color) y metallic-roughness JPEG q85 (1024).  La geometria no se toca.
Los 4 GLB de Meshy (idle, walk, run, shot) comparten la misma malla: basta con pasar cualquiera de ellos.
Requiere Pillow.
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
    j.pop("animations", None)

    # roles de las imagenes
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

    # accesores que siguen en uso (malla + skin)
    used = []
    def use(i):
        if i not in used:
            used.append(i)
        return used.index(i)
    for me in j["meshes"]:
        for p in me["primitives"]:
            p["attributes"] = {k: use(v) for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = use(p["indices"])
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = use(s["inverseBindMatrices"])
    old_acc = j["accessors"]
    new_acc = [dict(old_acc[i]) for i in used]

    # bufferViews en uso (accesores + imagenes), reescritos en un BIN nuevo y compacto
    newbin = bytearray()
    views = []
    vmap = {}
    def add_view(old_idx, data=None):
        if old_idx in vmap and data is None:
            return vmap[old_idx]
        bv = j["bufferViews"][old_idx]
        if data is None:
            data = b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        while len(newbin) % 4:
            newbin.append(0)
        nv = {k: v for k, v in bv.items() if k not in ("byteOffset", "byteLength")}
        nv["buffer"] = 0
        nv["byteOffset"] = len(newbin)
        nv["byteLength"] = len(data)
        newbin.extend(data)
        views.append(nv)
        vmap[old_idx] = len(views) - 1
        return vmap[old_idx]
    for ac in new_acc:
        ac["bufferView"] = add_view(ac["bufferView"])
    for idx, im in enumerate(j.get("images", [])):
        data = b[j["bufferViews"][im["bufferView"]].get("byteOffset", 0):][:j["bufferViews"][im["bufferView"]]["byteLength"]]
        r = role.get(idx, "mr")
        I = Image.open(io.BytesIO(data))
        size = size_of.get(r, a.mr)
        if max(I.size) > size:
            k = size / max(I.size)
            I = I.resize((max(1, round(I.size[0] * k)), max(1, round(I.size[1] * k))), Image.LANCZOS)
        out = io.BytesIO()
        q, ss = {"albedo": (88, 2), "normal": (92, 0)}.get(r, (85, 2))
        I.convert("RGB").save(out, "JPEG", quality=q, optimize=True, subsampling=ss)
        im["mimeType"] = "image/jpeg"
        print("imagen %d (%s): %s -> %d KB" % (idx, r, I.size, len(out.getvalue()) // 1024))
        im["bufferView"] = add_view(im["bufferView"], out.getvalue())
    while len(newbin) % 4:
        newbin.append(0)
    j["accessors"] = new_acc
    j["bufferViews"] = views
    j["buffers"] = [{"byteLength": len(newbin)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(newbin)
    with open(a.dst, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(newbin), 0x004E4942) + bytes(newbin))
    print("%s: %.2f MB (%d accesores, %d bufferViews)" % (a.dst, total / 1e6, len(new_acc), len(views)))


if __name__ == "__main__":
    main()
