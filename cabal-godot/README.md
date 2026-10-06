# Cabal HD (Godot 4)

Shooter arcade 2D al estilo *Cabal*, hecho en Godot 4.2+ (renderer `GL Compatibility`, corre en casi cualquier PC).

## Abrir y jugar
1. Abrir Godot 4.2 o superior, "Importar" y elegir `cabal-godot/project.godot`.
2. Esperar a que importe los assets la primera vez y apretar **F5**.

## Controles
| Acción | Control |
|---|---|
| Moverte | WASD / flechas |
| Apuntar / disparar | Mouse / click |
| Granada | Click derecho o G |
| Esquivar (invulnerable) | Espacio |
| Pausa / pantalla completa | P o Esc / F11 |

## Qué usa del motor
- Iluminación 2D (`PointLight2D`, `DirectionalLight2D`, `CanvasModulate`): los disparos y explosiones iluminan la escena.
- Partículas (`CPUParticles2D`): chispas, fuego, humo, escombros y brasas ambientales.
- Shaders: destello de impacto en los sprites y postproceso (aberración cromática, viñeta, grano, flash de daño).
- `Camera2D` con sacudida por trauma y paralaje leve según el mouse, cámara lenta al matar al jefe.
- Audio: efectos con variación de tono y música en loop (generados con numpy, ver abajo).

## Estructura
```
scenes/main.tscn   escena principal (solo el nodo con game.gd)
scripts/game.gd    estados, oleadas, disparo, IA y colisiones
scripts/player.gd, enemy.gd, shell.gd, props.gd   entidades
scripts/fx.gd, sfx.gd, hud.gd, k.gd               efectos, audio, interfaz y utilidades
shaders/           flash.gdshader, post.gdshader
assets/sprites/    PNG en alta resolución (exportados desde el prototipo web en cabal-hd/)
assets/audio/      efectos y música en WAV
tests/             smoke_test.gd (sin cabeza) y shot_test.gd (capturas con render real)
```

## Pruebas
```
godot --headless --path . --script res://tests/smoke_test.gd
```

## Arte propio
Todo el arte actual está dibujado por código y exportado a PNG. Para reemplazarlo por arte real (Meshy, packs de Kenney, etc.)
alcanza con sustituir los PNG de `assets/sprites/` conservando el nombre y el punto de anclaje de los pies de cada sprite.
