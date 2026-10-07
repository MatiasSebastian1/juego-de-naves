# Cabal 3D

Shooter de **tercera persona 3D** (estilo "Gears of War", pero chico) hecho en **Godot 4.2+** con el renderer
**GL Compatibility** (corre en cualquier PC; no usa Forward+, glow, SSAO ni SSR). Sobrevivi 15 oleadas en una
**aldea del desierto al atardecer** (la arena **"Oasis Market Village", generada con Meshy AI**): usa la cobertura, rodá,
tirá granadas y derribá a los jefes (cada 5 oleadas).

Es un proyecto independiente: no depende de `cabal-godot/` (el juego 2D) ni de nada fuera de esta carpeta.

> Estilo visual: personajes y props **low-poly estilizados** (Kenney) sobre una arena de Meshy con material PBR
> (textura + normal + rugosidad). Si falta el GLB de Meshy el juego cae al patio industrial de Kenney (ver abajo).

## Como abrirlo

1. Instala Godot **4.2 o superior** (version estandar, no hace falta .NET).
2. En el gestor de proyectos: **Importar** -> elegi `cabal-3d/project.godot`.
3. Esperá a que importe los assets (la primera vez tarda un poco) y apretá **F5**.

Por consola: `godot --path cabal-3d` (o `godot --headless --import --path cabal-3d` para solo importar).

## Controles

| Tecla / mouse | Accion |
|---|---|
| **WASD** | mover (relativo a la camara) |
| **Mouse** | apuntar (el mouse queda capturado) |
| **Click izquierdo** | disparar (hitscan con dispersion y retroceso) |
| **Click derecho** (mantener) | apuntar: zoom, mas precision, menos velocidad |
| **Shift** | correr (al disparar o apuntar se corta el sprint) |
| **Espacio** | **rodar** (esquiva con invulnerabilidad corta) si te estas moviendo; **saltar** si estas quieto |
| **C** (alterna) / **Ctrl** (mantener) | agacharse / cubrirse detras de cobertura baja |
| **R** | recargar (cargador de 30, con reserva) |
| **G** | granada (arco parabolico, explosion en area; ojo, el fuego propio duele un poco) |
| **P / Esc** | pausa (libera el mouse; botones continuar / reiniciar / musica / menu) |
| **M**, **- / +** | silenciar / volumen de la musica |
| **[ / ]** | sensibilidad del mouse |
| **F11** | pantalla completa |

En la pausa: **R** reinicia y **Q** vuelve al menu. Si la ventana pierde el foco, el juego se pausa solo.

## Como se juega

* **Cobertura**: los muros de las casas, las rocas del terreno y las cajas, barriles y paneles repartidos por los
  espacios abiertos tienen colisiones y **bloquean los disparos de ambos bandos**. Agachate (C) detras de una cobertura baja y quedas tapado ("EN COBERTURA": -30% de dano).
* **Enemigos** (todos son personajes Blocky distintos, con anillo de color bajo los pies y barra de vida):
  * **Fusilero** (rojo): busca cobertura, asoma, **telegrafa** (brilla en rojo + "!") y dispara rafagas con punteria limitada.
  * **Corredor** (amarillo): sprint hacia vos y ataque cuerpo a cuerpo (se esquiva rodando).
  * **Pesado** (naranja, x1.35): muchisima vida, rafagas largas mientras avanza.
  * **Granadero** (verde): lanza granadas con un **indicador en el suelo**; la HUD avisa la direccion.
  * **Jefe** (violeta, x2.2, cada 5 oleadas): abanico de disparos (la cobertura lo frena), granadas y rafagas; se enfurece por debajo del 50%.
* **Drops** (se recogen caminando encima): vida, municion, granadas y armas temporales (**escopeta** y **rafaga**).
* **Cabezazo** = dano x2 con aviso "HEADSHOT". Hitmarker blanco (impacto), amarillo (baja), rojo (cabeza).
* **Puntaje y combo**: bajas encadenadas (3.8 s) suben el multiplicador (hasta x5). Al terminar ves bajas,
  precision, mejor combo, oleada y el **Top 5** local (se guarda con `ConfigFile` en `user://cabal3d.cfg`).
* Dificultad creciente en 15 oleadas, spawn por los bordes de la zona jugable y tope de enemigos simultaneos.

## Estructura

```
cabal-3d/
  project.godot            Compatibility, 1280x720, MSAA 3D x2, sombras direccionales 4096; capas de fisica: 1 mundo, 2 jugador, 3 enemigos, 4 limite
  scenes/main.tscn         nodo raiz con game.gd (todo lo demas se arma por codigo)
  tools/slim_glb.py        achica los GLB de Meshy (reescribe solo las texturas embebidas); no se exporta
  scripts/
    game.gd                estados (menu/juego/pausa/game over), oleadas, puntaje, drops, ranking, entrada
    player.gd              movimiento, camara SpringArm3D sobre el hombro, disparo hitscan, recarga, rodar, granadas
    enemy.gd               IA de los 5 tipos (cobertura, telegrafo, melee, granadas, jefe), muerte con fade
    level.gd               arena Meshy (escala, colision trimesh, horneado de navegacion, cobertura, horizonte) o patio Kenney de respaldo; cielo/niebla/luces
    model.gd               personaje Blocky: animaciones mezcladas (piernas + brazos con arma), arma, destello
    fx.gd                  pools de efectos: trazadoras, chispas, polvo, fogonazos, explosiones, humo, fuego
    grenade.gd, pickup.gd  granada parabolica con rebotes / items de drop
    hud.gd                 interfaz 2D (barra de vida, municion, mira dinamica, hitmarker, indicadores, pantallas)
    sfx.gd                 efectos (globales y 3D posicionales) y musica en loop
    assets.gd              carga de GLB, materiales con luz, cajas envolventes, punto de extension del personaje Meshy
  shaders/                 ground (suelo del patio de respaldo), sand (horizonte), post (vineta, grano, aberracion, dano), ring (avisos)
  tests/                   smoke_test.gd, shot_test.gd, fire_test.gd
  assets/
    audio/                 WAV (de cabal-godot/); los largos se importan en ADPCM para achicar el export
    meshy/                 oasis_village.glb (arena generada con Meshy AI, ver README.md de esa carpeta)
    third_party/kenney/    personajes, armas, props de cobertura, particulas y fuente (CC0, ver README.md de esa carpeta)
```

### Notas tecnicas

* **Render**: Compatibility. Sol calido bajo con sombras (unica luz con sombras; en la aldea se orienta a ~55 grados a la
  izquierda de la vista inicial y con `shadow_bias`/`normal_bias` altos para evitar el "acne" en el terreno rasante) +
  relleno frio sin sombras, cielo procedural de atardecer, niebla de profundidad calida, tonemap filmico. Fuegos con `CPUParticles3D` + `OmniLight3D`
  parpadeante; polvo ambiente, chispas y humo con pools reutilizados. Postproceso: un `ColorRect` con shader
  (vineta, grano fino, aberracion solo en bordes, color y flash rojo de dano) debajo de la HUD.
* **Personajes**: los Blocky de Kenney **no tienen `Skeleton3D`** (cada parte es un nodo rigido animado por pistas).
  Por eso el arma no usa `BoneAttachment3D`: se cuelga del nodo `torso` y el modelo mezcla en codigo las piernas de
  `idle/walk/sprint` con los brazos de `holding-both`. El torso/cabeza "apuntan" girando el modelo hacia la direccion de la camara.
* **IA / movimiento**: en lugar de `NavigationAgent3D` (el horneado en runtime no es fiable sin cabeza) se usa una
  grilla `AStarGrid2D` de 1 m, con suavizado de caminos por linea de vision, separacion entre enemigos y deteccion de
  atoranques (si un enemigo sigue atascado tras 4 intentos reaparece en un punto libre). Los puntos de cobertura se
  calculan en el nivel y los enemigos eligen el que queda tapado respecto del jugador; la linea de vision se comprueba
  con raycasts. En la arena Meshy la grilla se **hornea al arrancar** (`Level.bake()`, ~0.5 s) muestreando la fisica:
  desde el punto de inicio se inunda el terreno celda a celda (rayos verticales multi-impacto para hallar el suelo,
  una capsula de 0.6 m de radio contra paredes/props, rayos horizontales contra paredes finas y muestreo cada 0.25 m
  de la pendiente; escalones > 0.3 m por tramo o pendientes > ~49 grados se tratan como no transitables; las celdas
  de textura celeste = agua tambien). Lo que no se alcanza (techos, huecos, el estanque) queda solido. De ahi salen
  las alturas del suelo por celda, el inicio del jugador (celda abierta con la mejor vista despejada al centro), los
  puntos de aparicion (celdas abiertas del borde jugable, repartidas por angulo), la cobertura sobre espacio abierto
  (cajas, barriles, paneles y vallas apoyados en el suelo real) y puntos de cobertura pegados a muros de edificios.
* **Fisica del terreno**: la aldea es un `ConcavePolygonShape3D` (trimesh del propio mesh, capa 1 "mundo"). Jugador y
  enemigos son `CharacterBody3D` con `floor_snap_length=0.55` y `floor_max_angle=50`; los disparos (rayos), la camara
  (`SpringArm3D`) y las granadas chocan con los edificios. Los **limites invisibles** del area jugable estan en la capa 4
  ("limite"), que solo frenan a los personajes (los disparos y la camara no los ven).
* **Horizonte**: el diorama termina en un borde seco; se rodea con un marco de arena con dunas (`SandFrame`,
  `shaders/sand.gdshader`), un anillo de montanas lejanas y niebla, de modo que no se ve el vacio.
* **GLB de Kenney**: los `.glb.import` llevan `force_disable_compression=true` (la compresion de mallas de Godot 4.2
  rompe las UV > 1 de estos modelos). Los materiales "unlit" originales se reemplazan por materiales con luz.
* En ejecucion sin cabeza (`--headless`) no hay renderer: los efectos visuales se desactivan (`Assets.headless`).

## Arena Meshy: como cambiarla

La arena es `assets/meshy/oasis_village.glb`. Se carga en `scripts/level.gd`, constante **`ARENA`**:

| Clave | Valor actual | Para que sirve |
|---|---|---|
| `path` | `res://assets/meshy/oasis_village.glb` | GLB de la arena (un mesh estatico; si no existe se usa el patio Kenney de respaldo) |
| `scale` | `52.0` | factor de escala. El diorama de Meshy mide ~1.9 u de lado -> ~99 m. Con 52 las puertas miden ~2 m frente a los 1.84 m del Blocky; con 30 (57 m) las casas quedaban a la altura de un personaje |
| `yaw` | `0.0` | giro del mesh en grados |
| `play_half` | `41.0` | semilado del cuadrado jugable (metros, ya escalados); el resto es borde/horizonte |
| `start_hint` | `(8, 22)` | el inicio se elige entre las celdas abiertas a 14-34 m de `look_at` con mejor vista; este punto solo desempata |
| `look_at` | `(0, 0)` | hacia donde mira el jugador al empezar |
| `sun_az`, `sun_el` | `55`, `28` | azimut (respecto de la vista inicial, + = izquierda) y elevacion del sol |
| `cover_count` | `30` | grupos de cobertura baja (Survival Kit) sobre espacio abierto |
| `water` | `true` | trata como inaccesibles las celdas con textura celeste (estanque) |

Pasos para usar **otra arena** (por ejemplo otro GLB de Meshy):

1. Si pesa mucho, `python3 tools/slim_glb.py original.glb assets/meshy/mi_arena.glb` (texturas a 2048/1024).
2. Copialo a `assets/meshy/` y abri el proyecto (o `godot --headless --import --path cabal-3d`) para que se importe. Copia
   los `.import` de `oasis_village*` (lossy, sin VRAM, sin LODs) si queres el mismo peso en el export.
3. En `ARENA` cambia `path`, ajusta `scale` (mira capturas con `tests/shot_test.gd`: el Blocky mide 1.84 m) y `play_half`
   (que el borde del mesh quede ~5-8 m fuera). Si el terreno es muy irregular o con escalones, `STEP_MAX`, `MIN_NY` y
   `CAP_R` (arriba de `level.gd`) controlan que celdas se consideran transitables.
4. Corre `tests/smoke_test.gd`: comprueba que hay zona alcanzable, puntos de aparicion libres con ruta al jugador, que los
   enemigos aparecen sobre el suelo y fuera de edificios, y que el jugador recorre rutas sin atorarse.

El mesh debe ser **estatico** y con las normales consistentes (la colision solo usa las caras frontales). Sin GLB de Meshy
el juego usa el **patio Kenney** de antes (60x60 m con cobertura, sin los edificios del City Kit, que se retiraron del
proyecto para achicar el export). Probarlo: `SMOKE_ARENA=kenney godot --headless ... smoke_test.gd`.

## Personaje Meshy (punto de extension)

Todavia **no hay personaje de Meshy**: el jugador y los enemigos siguen siendo los Blocky de Kenney. Para cuando llegue:

* **Ruta**: `assets/meshy/character.glb` (`Assets.MESHY_CHARACTER`; `Assets.meshy_character_available()` dice si existe).
* **Escala**: `Assets.MESHY_CHARACTER_SCALE` (que mida ~1.8 m; el Blocky mide ~2.7 u de modelo x `Model.UNIT`=0.68).
* **Rotacion**: `Assets.MESHY_CHARACTER_YAW_DEG` (el frente del modelo debe mirar a +Z local, como los Blocky).
* **Donde enchufarlo**: `Model.setup()` en `scripts/model.gd`: ahi se instancia `character-m.glb` y se arma el rig. Habria que
  instanciar el GLB de Meshy (con su `Skeleton3D` y `AnimationPlayer`), centrarlo en los pies (el nodo del jugador tiene el
  origen en los pies; `model.position.y = -0.9` compensa el pivote de la capsula), mapear las animaciones a los nombres que
  usa el codigo (`idle_h`, `walk_h`, `sprint_h`, `die`, `attack-melee-right`; los Blocky mezclan piernas y brazos por
  pistas, un personaje con esqueleto puede reproducir una animacion completa) y colgar el arma de un `BoneAttachment3D`
  de la mano derecha (en `give_weapon`, hoy se cuelga del nodo `torso`). `make_unique_lit` hace los materiales propios
  para el destello de dano; con materiales PBR de Meshy hay que duplicarlos y animar `emission` igual.
* No esta implementado: si el archivo no existe no pasa nada.

## Pruebas

```
# humo sin cabeza (simula partidas con un piloto automatico; imprime RESULT ... fails=0, codigo de salida != 0 si falla)
godot --headless --path cabal-3d --script res://tests/smoke_test.gd

# capturas con render real (necesita GPU o xvfb + llvmpipe); genera g_menu, g_play, g_aerial, g_enemies, g_combat,
# g_cover, g_boss, g_boom, g_pause y g_over (.png) en la carpeta indicada
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 \
  --path cabal-3d --script res://tests/shot_test.gd -- /ruta/salida
```

Con `SMOKE_ARENA=kenney` el mismo test corre contra el patio de respaldo. Con la arena Meshy ademas comprueba la
navegacion horneada (zona alcanzable, agua, puntos de aparicion libres/sobre el suelo/fuera de edificios/con ruta al
jugador, 300 apariciones al azar, rutas aleatorias, muros reales, rayos bloqueados por edificios, enemigos de 8 oleadas
apoyados en el suelo, limite invisible, el jugador recorre rutas sin atorarse, y una escuadra de 16 enemigos que debe
llegar a ver al jugador en un porcentaje alto sin atorarse).

El smoke test cubre: menu, inicio, todos los tipos de enemigo y el jefe (enfurecido y muerte con camara lenta), composicion
de las 15 oleadas, victoria al completar la 15, drops y armas temporales, granadas, agacharse/rodar/saltar, pausa
(los enemigos no se mueven), reinicio (limpia todo), game over, ranking persistido y que `Engine.time_scale` siempre vuelva a su valor.

## Licencias

Codigo del juego: el mismo del repositorio. Assets de terceros: **CC0** (Kenney), ver `assets/third_party/kenney/README.md`.
La arena `assets/meshy/oasis_village.glb` la genero el usuario con **Meshy AI**: su licencia depende del plan de Meshy
con que se genero (ver `assets/meshy/README.md`).

## Peso del ejecutable

El export de Windows (`godot --headless --path cabal-3d --export-release "Windows Desktop" build/Cabal3D.exe`, con
`export_presets.cfg` excluyendo `tests/*`, `tools/*`, `*.md`) pesa ~75.5 MB (la plantilla de Godot son 69.7 MB) y el ZIP con
`zip -9` ~29.7 MiB. Para llegar ahi: texturas de la aldea recomprimidas (WebP con pérdida en el import, sin VRAM-compression),
audio largo en ADPCM, particulas a 256 px y se borraron los modelos de Kenney que ya no se usan.
