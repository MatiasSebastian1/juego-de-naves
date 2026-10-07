# Assets generados con Meshy AI

El contenido de esta carpeta lo **generó el usuario con [Meshy AI](https://www.meshy.ai)**. No es de Kenney ni CC0:
**la licencia y los permisos de uso (comercial, atribución, redistribución) dependen del plan de Meshy con el que se
generó cada asset** (revisá los términos vigentes de Meshy y el plan usado antes de publicar o distribuir el juego).

| Archivo | Qué es |
|---|---|
| `oasis_village.glb` | **Oasis Market Village**: la arena del juego. Un solo mesh estático (`output_unwrapped`), 100.806 triángulos, 133.046 vértices, sin esqueleto ni animaciones, un material PBR (albedo + normal + metallic-roughness). Diorama de ~1.9 x 0.21 x 1.9 unidades que el juego escala x52 (~99 m de lado). |
| `oasis_village_*.jpg` (+ `.import`) | Texturas del GLB extraídas por el importador de Godot (`gltf/embedded_image_handling=1`). Son las mismas que lleva el GLB; el `.import` de cada una las guarda en el ejecutable como WebP con pérdida (calidad 0.8) y sin VRAM-compression, para achicar el export. |
| `*.glb.import` | Ajustes de importación: normales/tangentes sí, LODs y mallas de sombra no (el mesh es estático y chico), compresión de mallas de Godot activa (sin problemas visuales con este mesh; los GLB de Kenney sí necesitan `force_disable_compression=true`). |

## Cómo se preparó el GLB

El archivo original de Meshy pesa 26 MB (texturas PNG: normal 2048, albedo 2048, metallic-roughness **4096**) y **no está en
el repositorio**. Se achicó con `tools/slim_glb.py` (no toca la geometría):

```
python3 tools/slim_glb.py village_original.glb assets/meshy/oasis_village.glb      # albedo 2048, normal 1024, mr 1024
```

Resultado: 7.2 MB (albedo JPEG 2048 q88, normal JPEG 1024 q92, metallic-roughness JPEG 1024 q85). Tras importarlo, en el
ejecutable de Windows la aldea ocupa ~3.7 MB.

## Qué hace el juego con el GLB

`scripts/level.gd` (constante `ARENA`) lo escala, lo baja para que el suelo típico quede en y=0, le crea colisión
(`ConcavePolygonShape3D` del propio mesh, capa de física 1 "mundo") y hornea al arrancar una grilla de navegación
muestreando la física (ver el README de `cabal-3d/`). Para usar otra arena basta con reemplazar este GLB (o apuntar
`ARENA.path` a otro) y ajustar `scale`, `play_half` y `start_hint`.

## Personaje de Meshy (todavía no entregado)

Cuando exista `assets/meshy/character.glb`, ver la sección "Personaje Meshy (punto de extensión)" del README de `cabal-3d/`.
