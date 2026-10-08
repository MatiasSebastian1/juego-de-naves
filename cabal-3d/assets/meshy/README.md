# Assets generados con Meshy AI

El contenido de esta carpeta lo **generó el usuario con [Meshy AI](https://www.meshy.ai)**. No es de Kenney ni CC0:
**la licencia y los permisos de uso (comercial, atribución, redistribución) dependen del plan de Meshy con el que se
generó cada asset** (revisá los términos vigentes de Meshy y el plan usado antes de publicar o distribuir el juego).

| Archivo | Qué es |
|---|---|
| `oasis_village.glb` | **Oasis Market Village**: la arena del juego. Un solo mesh estático (`output_unwrapped`), 100.806 triángulos, 133.046 vértices, sin esqueleto ni animaciones, un material PBR (albedo + normal + metallic-roughness). Diorama de ~1.9 x 0.21 x 1.9 unidades que el juego escala x52 (~99 m de lado). |
| `oasis_village_*.jpg` (+ `.import`) | Texturas del GLB extraídas por el importador de Godot (`gltf/embedded_image_handling=1`). Son las mismas que lleva el GLB; el `.import` de cada una las guarda en el ejecutable como WebP con pérdida (calidad 0.8) y sin VRAM-compression, para achicar el export. |
| `character.glb` (+ `character_*.jpg`) | **Soldado (jugador)**: malla `output_unwrapped` de 10.343 triangulos, 1 material PBR (albedo 2048 + normal 1024 + metallic-roughness 1024, JPEG) y esqueleto Mixamo de 28 huesos. **Sin animaciones** (van en `player_anims.res`). Mide 1.75 u de alto (el juego lo escala a 1.8 m). Trae un fusil colgado al pecho dentro de la malla. |
| `player_anims.res` | AnimationLibrary (91 KB, sin malla ni texturas): `idle` (Idle_02, 1.96 s), `walk` (Walking, 1.08 s), `run` (Running, 0.71 s), `shot` (Side_Shot, 4.08 s; en realidad una agachada con la mano en el fusil, no se usa). |
| `zombie.glb` (+ `zombie_*.jpg`) | **Zombi (todos los enemigos)**: mismo rig de 28 huesos, ~10.372 triangulos, 1.70 u de alto. |
| `zombie_anims.res` | `idle`, `walk`, `run` y `attack` (Attack, 2.88 s: brazos arriba y golpe hacia adelante, impacto en ~1.4 s). No hay animacion de muerte, apuntar, recargar ni agacharse: son procedurales (`scripts/model.gd`). |
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

## Personajes: soldado y zombi

Los originales de Meshy (4 GLB de ~20 MB por personaje: idle, walk, run + shot/attack; cada uno repite la malla y 3 texturas PNG de
hasta 4096 px) **no estan en el repositorio**. Se redujeron asi:

```
# modelo: malla + esqueleto + texturas (albedo JPEG 2048 q88, normal JPEG 1024 q92, metallic-roughness JPEG 1024 q85); sin animaciones
python3 tools/build_character.py idle.glb assets/meshy/character.glb          # 2.6 MB (de 20 MB)
python3 tools/build_character.py idle.glb assets/meshy/zombie.glb
# animaciones: un AnimationLibrary por personaje, sin malla ni texturas (root motion anulado, todos los huesos con pista)
godot --headless --path cabal-3d --script res://tools/build_anims.gd -- /carpeta/meshychar res://assets/meshy/player_anims.res \
      res://assets/meshy/character.glb idle=idle:Idle_02:loop walk=walk:Walking:loop run=run:Running:loop shot=shot:Side_Shot
godot --headless --path cabal-3d --script res://tools/build_anims.gd -- /carpeta/meshyzombie res://assets/meshy/zombie_anims.res \
      res://assets/meshy/zombie.glb idle=idle:Idle_02:loop walk=walk:Walking:loop run=run:Running:loop attack=attack:Attack
```

Importacion (`*.import`): texturas extraidas del GLB (`gltf/embedded_image_handling=1`) y guardadas como WebP con perdida
(calidad 0.85, sin VRAM-compression), mallas sin LODs ni mallas de sombra. En el ejecutable cada personaje ocupa ~1.8 MB.

Como los usa el juego (`scripts/model.gd`, `scripts/enemy.gd`, `scripts/player.gd`): ver "Personajes Meshy" en el README de
`cabal-3d/` (IK de brazos, arma en la mano derecha por `BoneAttachment3D`, poses procedurales, tintes del zombi por tipo).

**Para agregar animaciones nuevas de Meshy** (muerte, recargar, apuntar...): bajar el GLB de la animacion, copiarlo a la carpeta de
originales y volver a ejecutar `build_anims.gd` agregando `nombre=archivo:Animacion` (ver el README de `cabal-3d/`).
