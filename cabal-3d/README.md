# Cabal 3D

Shooter de **tercera persona 3D** (estilo "Gears of War", pero chico) hecho en **Godot 4.2+** con el renderer
**GL Compatibility** (corre en cualquier PC; no usa Forward+, glow, SSAO ni SSR). Sobrevivi 15 oleadas en una
**aldea del desierto al atardecer** (la arena **"Oasis Market Village", generada con Meshy AI**): usa la cobertura, rodá,
tirá granadas y derribá a los jefes (cada 5 oleadas).

Es un proyecto independiente: no depende de `cabal-godot/` (el juego 2D) ni de nada fuera de esta carpeta.

> Estilo visual: el **soldado** (jugador) y el **zombi** (todos los enemigos) son personajes generados con **Meshy AI**
> (con esqueleto y animaciones de Meshy) sobre una arena de Meshy con material PBR (textura + normal + rugosidad); las armas,
> cajas y barriles son low-poly de Kenney. Si falta el GLB de la arena el juego cae al patio de Kenney (ver abajo).

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
* **Enemigos**: todos son el **mismo zombi** (Meshy), distinguidos por tinte, tamano y un anillo de color bajo los pies
  (y barra de vida). Los que atacan de lejos **lanzan proyectiles toxicos** (escupitajo / bola de acido verde, bolsas
  toxicas en lugar de granadas) con el gesto de la animacion "attack"; no hay sangre (salpicaduras verdes):
  * **Fusilero** (rojo): busca cobertura, asoma, **telegrafa** (brilla en rojo + "!") y escupe rafagas con punteria limitada.
  * **Corredor** (amarillo): corre hacia vos y te golpea cuerpo a cuerpo (el golpe cae cuando la animacion llega al impacto; se esquiva rodando).
  * **Pesado** (naranja, x1.25): muchisima vida, rafagas largas mientras avanza.
  * **Granadero** (verde): lanza bolsas de acido con un **indicador en el suelo**; la HUD avisa la direccion.
  * **Jefe** (violeta, x2.1, cada 5 oleadas): abanico de escupitajos (la cobertura lo frena), bolsas toxicas y rafagas; se enfurece por debajo del 50%.
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
  tools/slim_glb.py        achica un GLB de Meshy estatico (arena): reescribe solo las texturas embebidas; no se exporta
  tools/build_character.py arma el modelo de un personaje (malla + esqueleto + texturas reducidas, sin animaciones)
  tools/build_anims.gd     extrae las animaciones de los GLB de Meshy a un AnimationLibrary .res (sin malla ni texturas)
  tools/LEEME.txt          copia del LEEME que va en el ZIP de datos del export
  scripts/
    game.gd                estados (menu/juego/pausa/game over), oleadas, puntaje, drops, ranking, entrada
    player.gd              movimiento, camara SpringArm3D sobre el hombro, disparo hitscan, recarga, rodar, granadas
    enemy.gd               IA de los 5 tipos de zombi (cobertura, telegrafo, melee, proyectiles toxicos, jefe), muerte con fade
    level.gd               arena Meshy (escala, colision trimesh, horneado de navegacion, cobertura, horizonte) o patio Kenney de respaldo; cielo/niebla/luces
    model.gd               personajes Meshy con Skeleton3D: animaciones, IK de brazos y arma en la mano, agacharse/rodar/morir procedurales, destello
    fx.gd                  pools de efectos: trazadoras, chispas, polvo, fogonazos, explosiones, humo, fuego
    grenade.gd, pickup.gd  granada parabolica con rebotes / items de drop
    hud.gd                 interfaz 2D (barra de vida, municion, mira dinamica, hitmarker, indicadores, pantallas)
    sfx.gd                 efectos (globales y 3D posicionales) y musica en loop
    assets.gd              carga de GLB, materiales con luz, cajas envolventes, punto de extension del personaje Meshy
  shaders/                 ground (suelo del patio de respaldo), sand (horizonte), post (vineta, grano, aberracion, dano), ring (avisos)
  tests/                   smoke_test.gd, shot_test.gd, fire_test.gd
  assets/
    audio/                 WAV (de cabal-godot/); los largos se importan en ADPCM para achicar el export
    meshy/                 oasis_village.glb (arena), character.glb + player_anims.res (soldado), zombie.glb + zombie_anims.res (ver README.md de esa carpeta)
    third_party/kenney/    armas, props de cobertura, particulas y fuente (CC0, ver README.md de esa carpeta)
```

### Notas tecnicas

* **Render**: Compatibility. Sol calido bajo con sombras (unica luz con sombras; en la aldea se orienta a ~55 grados a la
  izquierda de la vista inicial y con `shadow_bias`/`normal_bias` altos para evitar el "acne" en el terreno rasante) +
  relleno frio sin sombras, cielo procedural de atardecer, niebla de profundidad calida, tonemap filmico. Fuegos con `CPUParticles3D` + `OmniLight3D`
  parpadeante; polvo ambiente, chispas y humo con pools reutilizados. Postproceso: un `ColorRect` con shader
  (vineta, grano fino, aberracion solo en bordes, color y flash rojo de dano) debajo de la HUD.
* **Personajes**: `Model` (scripts/model.gd) instancia `assets/meshy/character.glb` (soldado) o `zombie.glb` (zombi): una malla de
  ~10.3k triangulos con 1 material PBR y el esqueleto estilo Mixamo de 28 huesos (en Godot los nombres llevan `_` en lugar de
  `:`, p. ej. `mixamorig_RightHand`). Las animaciones viven aparte (`player_anims.res`: idle, walk, run, shot; `zombie_anims.res`:
  idle, walk, run, attack) y el `AnimationPlayer` se avanza a mano para poder poner poses procedurales encima en el mismo
  cuadro. El movimiento lo gobierna siempre el `CharacterBody3D`: el "root motion" se anulo al extraer las animaciones.
  Locomocion: idle / walk / run segun la velocidad real, con la velocidad de la animacion proporcional a la velocidad
  (`Model.locomote`). **Jugador**: el torso y la cabeza giran hacia la mira (rotaciones de los huesos Spine/Spine1/Spine2/Neck/Head)
  y los brazos usan **IK analitico de dos huesos** (`_ik2`) hacia el arma: la mano derecha en la empunadura y la izquierda en el
  guardamano; el arma cuelga de un `BoneAttachment3D` en `mixamorig_RightHand` y el `muzzle` (de donde salen trazadoras y
  fogonazo) es un `Marker3D` en la punta del canon. Agacharse/cubrirse (cadera baja + IK de piernas para no deslizar los pies),
  voltereta (cuerpo encogido que gira alrededor de su centro) y muerte (rodillas que ceden y caida alrededor de los pies) son
  **procedurales** porque Meshy no entrego esas animaciones; el `shot` ("Side_Shot") es en realidad una agachada con la mano
  en el rifle colgado, no una pose de tiro, y no se usa. **Zombis**: gesto de lanzar = tramo 0.35-1.40 s de `attack` (brazos
  arriba y golpe), sincronizado para que el impacto/lanzamiento coincida con el final del telegrafo; el muzzle es la cara
  (`headfront`); velocidad y fase de animacion aleatorias por individuo; los lejanos actualizan su animacion cada 2-3 cuadros (`Model.lod`).
  Nota: el modelo del soldado trae un fusil colgado al pecho **dentro de la malla** (no se puede quitar sin editarla).
  Los GLB de Kenney que quedan (armas, props) llevan `force_disable_compression=true` (ver mas abajo).
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
| `scale` | `52.0` | factor de escala. El diorama de Meshy mide ~1.9 u de lado -> ~99 m. Con 52 las puertas miden ~2 m frente a los 1.8 m del personaje; con 30 (57 m) las casas quedaban a la altura de un personaje |
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
3. En `ARENA` cambia `path`, ajusta `scale` (mira capturas con `tests/shot_test.gd`: el personaje mide 1.8 m) y `play_half`
   (que el borde del mesh quede ~5-8 m fuera). Si el terreno es muy irregular o con escalones, `STEP_MAX`, `MIN_NY` y
   `CAP_R` (arriba de `level.gd`) controlan que celdas se consideran transitables.
4. Corre `tests/smoke_test.gd`: comprueba que hay zona alcanzable, puntos de aparicion libres con ruta al jugador, que los
   enemigos aparecen sobre el suelo y fuera de edificios, y que el jugador recorre rutas sin atorarse.

El mesh debe ser **estatico** y con las normales consistentes (la colision solo usa las caras frontales). Sin GLB de Meshy
el juego usa el **patio Kenney** de antes (60x60 m con cobertura, sin los edificios del City Kit, que se retiraron del
proyecto para achicar el export). Probarlo: `SMOKE_ARENA=kenney godot --headless ... smoke_test.gd`.

## Personajes Meshy: como cambiarlos y agregar animaciones

Detalle de archivos y de la preparacion en `assets/meshy/README.md`. Resumen:

1. **Reemplazar el soldado o el zombi**: generar el personaje en Meshy con rigging y animaciones (cualquier GLB sirve para la
   malla: todos traen la misma), `python3 tools/build_character.py idle.glb assets/meshy/character.glb` (o `zombie.glb`) y abrir
   Godot para que importe. Copiar los `.import` de `character*` (texturas lossy 0.85, sin VRAM, sin LODs). Si el esqueleto no es
   el de 28 huesos Mixamo, ajustar `BN` (nombres de huesos) en `model.gd`. La escala sale sola (`HEIGHT` = 1.8 m / altura de la malla).
2. **Agregar animaciones de Meshy** (por ejemplo `death`, `reload`, `crouch`): descargar el GLB de la animacion y volver a correr
   `build_anims.gd` con TODAS las animaciones (genera de nuevo el .res):
   ```
   godot --headless --path cabal-3d --script res://tools/build_anims.gd -- /carpeta/glb res://assets/meshy/player_anims.res \
         res://assets/meshy/character.glb idle=idle:Idle_02:loop walk=walk:Walking:loop run=run:Running:loop shot=shot:Side_Shot death=death:Dying
   ```
   (cada argumento es `nombre=archivo:AnimacionDelGLB[:loop]`). Luego usarla: `model.play("death")` / `model.play_once(...)`;
   para reemplazar la muerte procedural, llamar a esa animacion en `Model.die()` en lugar de congelar la pose.
3. **Zombi**: `zombie_anims.res` se genera igual (`attack=attack:Attack`, etc.); el gesto de lanzar usa `ATTACK_FROM/HIT/END`
   en `enemy.gd` (instantes de la animacion `attack`).
4. **Tintes de los zombis**: `tint` de cada tipo en `Enemy.TYPES` (se multiplica con la textura del material); `scale` y `col` (anillo).
5. Agarre del arma: constantes `GRIP_*`, `SUPPORT_*`, `AIM_OFFSET`, `READY_OFFSET` al principio de `model.gd`
   (`tests/rig_test.gd` genera contactos del rig para ajustarlas viendo las poses).

## Pruebas

```
# humo sin cabeza (simula partidas con un piloto automatico; imprime RESULT ... fails=0, codigo de salida != 0 si falla)
godot --headless --path cabal-3d --script res://tests/smoke_test.gd

# capturas con render real (necesita GPU o xvfb + llvmpipe); genera g_menu, g_play, g_aerial, g_enemies, g_combat,
# g_cover, g_boss, g_boom, g_pause y g_over (.png) en la carpeta indicada
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 \
  --path cabal-3d --script res://tests/shot_test.gd -- /ruta/salida

# personaje: c_idle, c_fire, c_run, c_crouch, c_aim, c_zombies, c_spit en la aldea (char_shot) y contactos del rig con
# poses sueltas (rig_test: idle, apuntar de frente/lado/espalda/arriba/abajo, caminar, correr, agachado, voltereta, muerte; zombi)
... --script res://tests/char_shot.gd -- /ruta/salida
... --script res://tests/rig_test.gd -- /ruta/salida [player|zombie|all]
```

Con `SMOKE_ARENA=kenney` el mismo test corre contra el patio de respaldo. Con la arena Meshy ademas comprueba la
navegacion horneada (zona alcanzable, agua, puntos de aparicion libres/sobre el suelo/fuera de edificios/con ruta al
jugador, 300 apariciones al azar, rutas aleatorias, muros reales, rayos bloqueados por edificios, enemigos de 8 oleadas
apoyados en el suelo, limite invisible, el jugador recorre rutas sin atorarse, y una escuadra de 16 enemigos que debe
llegar a ver al jugador en un porcentaje alto sin atorarse).

El smoke test (177 comprobaciones) cubre ademas el personaje: esqueleto de 28 huesos, animaciones presentes, escala a 1.8 m,
arma sujeta a la mano derecha por un `BoneAttachment3D`, muzzle valido, un tinte distinto por tipo de zombi, sin T-pose / raiz
desplazada / pies hundidos o flotando (jugador, agachado y zombis), ataque melee del corredor que daña, proyectil toxico que daña,
muerte procedural del zombi y del jugador y `revive()`. Cubre: menu, inicio, todos los tipos de enemigo y el jefe (enfurecido y muerte con camara lenta), composicion
de las 15 oleadas, victoria al completar la 15, drops y armas temporales, granadas, agacharse/rodar/saltar, pausa
(los enemigos no se mueven), reinicio (limpia todo), game over, ranking persistido y que `Engine.time_scale` siempre vuelva a su valor.

## Licencias

Codigo del juego: el mismo del repositorio. Assets de terceros: **CC0** (Kenney: armas, props, particulas, fuente), ver
`assets/third_party/kenney/README.md`. La arena `oasis_village.glb`, el soldado (`character.glb`) y el zombi (`zombie.glb`)
con sus animaciones los genero el usuario con **Meshy AI**: su licencia depende del plan de Meshy con que se generaron
(ver `assets/meshy/README.md`).

## Peso del ejecutable y entrega en dos ZIPs

`export_presets.cfg` tiene `binary_format/embed_pck=false`: el export de Windows
(`godot --headless --path cabal-3d --export-release "Windows Desktop" build/Cabal3D.exe`, excluye `tests/*`, `tools/*`, `*.md`)
genera **dos archivos**: `Cabal3D.exe` (la plantilla de Godot, 69.7 MB) y `Cabal3D.pck` (~9 MB: juego + arena + personajes + audio).
El canal de entrega limita cada archivo a 30 MiB, asi que se entregan dos ZIPs (`zip -9`): `Cabal3D_parte1_exe.zip` (solo el .exe,
~24.5 MiB) y `Cabal3D_parte2_datos.zip` (el .pck y `tools/LEEME.txt`, ~8.3 MiB). Hay que descomprimir **ambos en la misma carpeta**.
Para llegar a ese peso: texturas de la aldea y de los personajes recomprimidas (JPEG al armar el GLB y WebP con perdida en el import,
sin VRAM-compression), audio largo en ADPCM, particulas a 256 px, animaciones en un `.res` comprimido sin malla ni texturas y se
borraron los modelos de Kenney que ya no se usan (Blocky, blasters de los enemigos).
