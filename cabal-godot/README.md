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
| Pausa (continuar / reiniciar / música) | P o Esc; en pausa: R reinicia, Enter continúa, o usá los botones con el mouse |
| Música: silenciar / volumen | M / `-` y `+` (o `[` y `]`); también en el menú de pausa |
| Pantalla completa | F11 |

## Jugabilidad
- **Oleadas 1 a 15 (y más)**, jefe cada 5. La dificultad sale de `K.diff(n)` en `scripts/k.gd`: cantidad de enemigos `6 + 2n` (tope 36, 60% en oleadas de jefe),
  máximo simultáneo `3 + n/3` (tope 8), intervalo de aparición `1.7 s -> 0.7 s`, vida de enemigos hasta +63% en la oleada 15, menos tiempo entre disparos (hasta -35%),
  telégrafo -28% (nunca menos de 0.3 s), balas -22% de vuelo y daño de fusil `8 -> 10.8`. Granaderos desde la oleada 2, corredores desde la 3 y pesados desde la 4.
- El **jefe** (`120 + 8n` de vida) se enfurece por debajo del 50%: dispara más seguido, abanico de 7 balas y 3 granadas.
- Al superar una oleada: bonus `n*250`, +20 de vida y +1 granada (+3 tras un jefe). Los drops tienen "pity" (sube la chance sin premio) y favorecen vida/granadas cuando faltan.
  Los items se recogen disparándoles o caminando encima.
- **Game feel**: hit-stop breve al ser herido, al matar pesados/jefe y con granadas; destello blanco y viñeta roja al recibir daño; marco rojo con vida baja;
  indicador de recarga de esquiva (abajo a la izquierda, pulsa al estar lista); aviso de peligro (círculo en el punto de impacto, "!" sobre el soldado y flecha bajo los corredores).
- **Pausa** con botones (continuar, reiniciar, música, volumen), **resumen de fin de partida** (oleada, bajas, precisión, mejor combo, tiempo) y **ranking local Top 5**
  guardado con `ConfigFile` en `user://cabalhd.cfg` (junto con el volumen y el mute de la música). Reiniciar desde la pausa también registra el puntaje.
  Tras morir, el reinicio por click se habilita a los 0.8 s para evitar reinicios accidentales.
- `Engine.time_scale` (hit-stop/cámara lenta) se maneja con reloj real y se reaplica cada frame: reiniciar, pausar o morir siempre lo deja en 1.0.

## Qué usa del motor
- **Iluminación 2D con relieve**: si existe `<sprite>_n.png` (mapa de normales de la misma medida), `K.tex()` devuelve una `CanvasTexture` (difuso + normales) y el sol
  (`DirectionalLight2D` con `height`) y los destellos/explosiones (`PointLight2D` con altura) iluminan con relieve. Sin normales se usa la iluminación plana de siempre
  (el ambiente y la energía del sol se ajustan solos en `scripts/stage.gd`). `K.lit = false` desactiva las normales.
- **Sombras proyectadas**: cada sprite (enemigos, jugador, barricadas, cajas) tiene una copia aplastada, inclinada según el sol, oscura y desenfocada por mip (`shaders/shadow.gdshader`,
  constantes `K.SHADOW_SKEW` y `K.SHADOW_SQUASH`), más una pequeña elipse de contacto. Las sombras de luz con `LightOccluder2D` se descartaron: en esta vista pseudo-3D las sombras
  planas del motor caerían sobre todo el campo y confundirían la lectura.
- **Fondo en capas con paralaje** (`scripts/stage.gd`): `bg_sky`, `bg_far`, `bg_mid`, `bg_ground` reaccionan al mouse y a la posición del jugador (con balanceo lento en el menú),
  nubes finas que derivan (`shaders/wisps.gdshader`), bruma/desenfoque por capa (`shaders/layer.gdshader`) y primer plano `fg_rubble` con paralaje opuesto por encima de todo.
  Si faltan las capas se usa `background.png` con un paralaje leve.
- **Postproceso** (`shaders/post.gdshader`): bloom por mips con umbral, profundidad de campo suave en la franja lejana, aberración solo en los bordes, corrección de color con
  tono dividido (sombras frías / luces cálidas), recorte suave de luces, grano fino, distorsión de calor sobre los fuegos (fijos y de explosiones), onda de choque de pantalla
  (hasta 3 a la vez, `stage.shock()`), flash blanco y viñeta roja de daño.
- **Animación**: ciclo de caminata de 4 cuadros (walk1, walk3, walk2, walk4), muerte con cuadros `die1..3` (caída, rebote y desvanecido; `Enemy.death_len()`), cuadros de caminata y herido del jugador,
  respiración, rebote al caminar, squash al disparar y retroceso del arma. Todo cae al comportamiento anterior si faltan los cuadros.
- **Efectos** (`scripts/fx.gd`): fogonazo orientado (Kenney `muzzle_*` + `fx_muzzle`), casquillos expulsados con rebote (`fx_shell`), chispas alargadas con estela y estrella (`fx_spark`),
  humo en capas con texturas Kenney `smoke_*` / `fx_smoke_puff`, fuego con `fire_*`/`flame_*`, onda de suelo (`fx_shockwave`), marcas de quemadura (`scorch_*`), estela luminosa en las balas,
  destello de lente sutil del sol (`fx_flare`) y polvo flotando en los haces de luz.
- Partículas (`CPUParticles2D`), `Camera2D` con sacudida por trauma y cámara lenta al matar al jefe.
- **Menú**: fondo animado con paralaje, título con degradado, resplandor y brillo que lo barre (`shaders/title.gdshader`); tipografía Kenney Future (CC0) con respaldo del sistema.
- Audio: efectos con variación de tono y música en loop.

## Estructura
```
scenes/main.tscn   escena principal (solo el nodo con game.gd)
scripts/game.gd    estados, oleadas, disparo, IA y colisiones
scripts/player.gd, enemy.gd, shell.gd, props.gd   entidades
scripts/stage.gd                                   luces, fondo en capas, paralaje, destello de lente y datos de postproceso
scripts/fx.gd, sfx.gd, hud.gd, k.gd               efectos, audio (volumen/mute), interfaz y utilidades (dificultad y texturas en k.gd)
shaders/           flash, post, shadow, layer, wisps, title (.gdshader)
assets/third_party/kenney/  partículas y fuentes CC0 de Kenney (ver su README)
assets/sprites/    PNG en alta resolución (exportados desde el prototipo web en cabal-hd/)
assets/audio/      efectos y música en WAV
tests/             smoke_test.gd (sin cabeza), shot_test.gd y look_test.gd (capturas con render real)
```

## Pruebas
```
godot --headless --path . --script res://tests/smoke_test.gd
```
Simula partidas completas (oleadas 1 a 15 con jefes, reinicio, pausa, game over, ranking en archivo temporal, volumen/mute, `time_scale` en 1.0) e imprime
`RESULT ... fails=0`; sale con código 1 si algún chequeo falla. Capturas con render real:
```
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 --path . --script res://tests/shot_test.gd -- /carpeta/salida
```
(genera menú, juego, jefe, explosión, aviso de peligro, pausa y game over). `--fixed-fps 60` hace que el tiempo avance 1/60 s por cuadro aunque el render por software sea lento.
`look_test.gd` es una versión corta (menú, juego, explosión y muertes) para ajustar el aspecto.

## Arte propio
Todo el arte actual está dibujado por código y exportado a PNG (incluye mapas de normales `_n`, capas de fondo, cuadros de animación y efectos `fx_*`). Para reemplazarlo por arte real (Meshy, packs de Kenney, etc.)
alcanza con sustituir los PNG de `assets/sprites/` conservando el nombre y el punto de anclaje de los pies de cada sprite.
