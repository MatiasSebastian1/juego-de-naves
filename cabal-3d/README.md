# Cabal 3D

Shooter de **tercera persona 3D** (estilo "Gears of War", pero chico) hecho en **Godot 4.2+** con el renderer
**GL Compatibility** (corre en cualquier PC; no usa Forward+, glow, SSAO ni SSR). Sobrevivi 15 oleadas en un
patio industrial en ruinas al atardecer: usa la cobertura, rodá, tirá granadas y derribá a los jefes (cada 5 oleadas).

Es un proyecto independiente: no depende de `cabal-godot/` (el juego 2D) ni de nada fuera de esta carpeta.

> Estilo visual: **low-poly estilizado** (personajes de cubos, props simples). No busca ser realista.

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

* **Cobertura**: cajas, barriles, paneles, contenedores y rocas tienen colisiones y **bloquean los disparos de
  ambos bandos**. Agachate (C) detras de una cobertura baja y quedas tapado ("EN COBERTURA": -30% de dano).
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
* Dificultad creciente en 15 oleadas, spawn por los bordes del patio y tope de enemigos simultaneos.

## Estructura

```
cabal-3d/
  project.godot            Compatibility, 1280x720, MSAA 3D x2, sombras direccionales 4096
  scenes/main.tscn         nodo raiz con game.gd (todo lo demas se arma por codigo)
  scripts/
    game.gd                estados (menu/juego/pausa/game over), oleadas, puntaje, drops, ranking, entrada
    player.gd              movimiento, camara SpringArm3D sobre el hombro, disparo hitscan, recarga, rodar, granadas
    enemy.gd               IA de los 5 tipos (cobertura, telegrafo, melee, granadas, jefe), muerte con fade
    level.gd               patio 60x60: suelo, cobertura con colision, edificios, fuego, cielo/niebla/luces, grilla A*
    model.gd               personaje Blocky: animaciones mezcladas (piernas + brazos con arma), arma, destello
    fx.gd                  pools de efectos: trazadoras, chispas, polvo, fogonazos, explosiones, humo, fuego
    grenade.gd, pickup.gd  granada parabolica con rebotes / items de drop
    hud.gd                 interfaz 2D (barra de vida, municion, mira dinamica, hitmarker, indicadores, pantallas)
    sfx.gd                 efectos (globales y 3D posicionales) y musica en loop
    assets.gd              carga de GLB, materiales con luz, cajas envolventes
  shaders/                 ground (suelo procedural), post (vineta, grano, aberracion, dano), ring (avisos)
  tests/                   smoke_test.gd, shot_test.gd
  assets/
    audio/                 WAV (de cabal-godot/)
    third_party/kenney/    modelos GLB, particulas y fuente (CC0, ver README.md de esa carpeta)
```

### Notas tecnicas

* **Render**: Compatibility. Sol calido con sombras (unica luz con sombras) + relleno frio sin sombras, cielo
  procedural de atardecer, niebla de profundidad calida, tonemap filmico. Fuegos con `CPUParticles3D` + `OmniLight3D`
  parpadeante; polvo ambiente, chispas y humo con pools reutilizados. Postproceso: un `ColorRect` con shader
  (vineta, grano fino, aberracion solo en bordes, color y flash rojo de dano) debajo de la HUD.
* **Personajes**: los Blocky de Kenney **no tienen `Skeleton3D`** (cada parte es un nodo rigido animado por pistas).
  Por eso el arma no usa `BoneAttachment3D`: se cuelga del nodo `torso` y el modelo mezcla en codigo las piernas de
  `idle/walk/sprint` con los brazos de `holding-both`. El torso/cabeza "apuntan" girando el modelo hacia la direccion de la camara.
* **IA / movimiento**: en lugar de `NavigationAgent3D` (el horneado en runtime no es fiable sin cabeza) se usa una
  grilla `AStarGrid2D` de 1 m generada desde las coberturas, con suavizado de caminos por linea de vision,
  separacion entre enemigos y deteccion de atoranques. Los puntos de cobertura se calculan en el nivel y los enemigos
  eligen el que queda tapado respecto del jugador; la linea de vision se comprueba con raycasts.
* **GLB de Kenney**: los `.glb.import` llevan `force_disable_compression=true` (la compresion de mallas de Godot 4.2
  rompe las UV > 1 de estos modelos). Los materiales "unlit" originales se reemplazan por materiales con luz.
* En ejecucion sin cabeza (`--headless`) no hay renderer: los efectos visuales se desactivan (`Assets.headless`).

## Pruebas

```
# humo sin cabeza (simula partidas con un piloto automatico; imprime RESULT ... fails=0, codigo de salida != 0 si falla)
godot --headless --path cabal-3d --script res://tests/smoke_test.gd

# capturas con render real (necesita GPU o xvfb + llvmpipe); genera g_menu, g_play, g_enemies, g_combat, g_cover,
# g_boss, g_boom, g_pause y g_over (.png) en la carpeta indicada
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 \
  --path cabal-3d --script res://tests/shot_test.gd -- /ruta/salida
```

El smoke test cubre: menu, inicio, todos los tipos de enemigo y el jefe (enfurecido y muerte con camara lenta), composicion
de las 15 oleadas, victoria al completar la 15, drops y armas temporales, granadas, agacharse/rodar/saltar, pausa
(los enemigos no se mueven), reinicio (limpia todo), game over, ranking persistido y que `Engine.time_scale` siempre vuelva a su valor.

## Licencias

Codigo del juego: el mismo del repositorio. Assets de terceros: **CC0** (Kenney), ver `assets/third_party/kenney/README.md`.
