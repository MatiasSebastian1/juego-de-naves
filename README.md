# Requiem

Shoot 'em up vertical en 3D estilizado, camara cenital pura. Prototipo
mediano hecho en Godot 4.x (probado con el binario 4.2.2; el `project.godot`
es compatible con Godot 4.7 al abrirlo, Godot migra el formato solo).

## Como abrir el proyecto

1. Abrir Godot 4.7.
2. "Importar" y seleccionar la carpeta de este repo (el archivo `project.godot`).
3. Godot va a escanear los scripts la primera vez (tarda unos segundos) y
   generar la cache de clases. Si algo tira "Identifier X not declared",
   cerrar y volver a abrir el proyecto una vez (fuerza el rescaneo).
4. Correr la escena principal (F5). Arranca en `scenes/boot/Boot.tscn`,
   que pasa directo al menu principal.

No hay assets 3D reales todavia: todas las naves, enemigos, jefes y el
fondo se dibujan con primitivas (capsulas, cajas, esferas) coloreadas por
codigo. Ver `docs/MESHY_WORKFLOW.md` para el plan de reemplazo cuando
lleguen los `.glb` de Meshy.

## Estructura

```
autoload/         GameManager, InputManager, SaveManager, AudioManager
core/              Constants, ShipDatabase, PowerUpSpawner, BackgroundLayer,
                   UIHelper, StoryData (utilidades sin estado de nodo)
scenes/
  boot/            Punto de entrada
  main_menu/       Menu principal
  ship_select/     Eleccion de nave + esquema de control por jugador
  game/            Game.gd (controlador de partida), HUD, PauseMenu,
                   ResultsScreen
  player/          Player.gd (nave del jugador, 3 naves via ShipDatabase)
  bullets/         PlayerBullet, EnemyBullet
  enemies/         EnemyBase + 6 tipos de enemigo
  bosses/          BossBase + 3 jefes con fases
  powerups/        PowerUpBase + 4 power-ups
  levels/          LevelBase (scroll + oleadas) + Nivel 1/2/3
  dialogue/        DialogueBox (modo historia)
  ranking/         Ranking local
tests/             Smoke tests y pruebas de comportamiento (ver abajo)
docs/              Documentacion de arquitectura y flujo de trabajo
```

## Que esta implementado

- **3 naves** (Interceptor / Bombardero / Prototipo) con stats propias y
  power-up de arma escalable (3 niveles, recalculado siempre desde cero).
- **6 enemigos**: caza basico, caza rapido (zigzag), bombardero (abanico),
  torreta fija (circulo, estatica en el scroll), dron kamikaze (persigue y
  se autodestruye al tocar), porta-naves (libera cazas).
- **4 power-ups**: mejora de arma, escudo (3 golpes), velocidad (15s),
  bomba (limpia pantalla).
- **3 jefes con fases**: Guardian de la Nube (frontal/abanico/laser),
  Ruina Flotante (torretas/misiles/nucleo expuesto), Nucleo de la Invasion
  (escudo/invocacion/laser/enrage).
- **3 niveles** con timeline de oleadas propia, scroll continuo y fondo
  procedural con tinte distinto por nivel.
- **Modo historia**: dialogos cortos (texto + retrato placeholder) antes
  del nivel 1, entre niveles y al terminar.
- **1-2 jugadores** en la misma pantalla (cooperativo local), cada uno con
  su nave, vidas y puntaje.
- **Controles**: teclado (WASD/flechas), mouse + teclado (apunta al mouse,
  dispara con click), gamepad (por dispositivo, P1=0, P2=1), tactil
  (arrastrar el dedo mueve la nave). Se elige por jugador en la pantalla
  de seleccion de nave.
- **Guardado**: historial rotativo de 6 checkpoints, "volver a punto
  anterior" desde pausa, verificacion por lista blanca al leer de disco,
  valores derivados recalculados de cero (nunca incrementados).
- **Ranking local** (top 10, persistido en `user://requiem_ranking.json`).
- **Audio**: efectos generados por codigo (sin assets externos todavia).
  `AudioManager.play_music()` esta listo para recibir un archivo real
  cuando lo tengan.

## Que falta / limitaciones conocidas

- Sin assets 3D ni de audio reales (todo placeholder, ver Meshy workflow).
- El fondo es un layer de quads translucidos reciclados, no terreno real.
- No se probo en un dispositivo movil real ni con gamepad fisico (solo
  simulado en headless); recomendable probar ambos en el editor antes de
  exportar.
- Sin export presets (Android/iOS/PC) configurados todavia.
- El balance de dificultad (HP, cadencia, cantidad de oleadas) es un
  primer numero, no esta jugado a mano todavia.

## Tests automaticos

No hay GUI para correrlos porque este entorno no tiene editor grafico, asi
que se armaron como escenas que corren solas en modo headless y terminan
solas (`get_tree().quit()`), imprimiendo PASS/FAIL por consola:

```bash
godot --headless --path . res://tests/BehaviorTests.tscn
godot --headless --path . res://tests/SmokeTest.tscn
godot --headless --path . res://tests/LevelSmokeTest.tscn
godot --headless --path . res://tests/CoopSmokeTest.tscn
```

`BehaviorTests.tscn` es el mas importante: simula input real (no llama a
metodos internos "a mano") para probar movimiento en los dos ejes, pickup
de power-up corrido del centro verificado por overlap real, que la zona
este lista antes de que aparezca contenido, y que el dialogo bloquee el
juego de verdad con texto real (no un placeholder marcado como "mostrado"
sin haberse mostrado). Sigue las reglas de testing que se definieron para
Dia Blanco, adaptadas a un shmup.

Si algo se rompe despues de un cambio, correr esos 4 comandos: si tiran
`SCRIPT ERROR` o algun `[FAIL]`, hay que revisar antes de seguir.

## Proximos pasos sugeridos

1. Reemplazar primitivas por los primeros `.glb` de Meshy (nave del
   jugador primero, es lo que mas se ve).
2. Configurar export presets y probar en un celular real (tactil) y con
   un gamepad fisico.
3. Agregar musica real y reemplazar `AudioManager._build_sfx_cache()`
   por sonidos definitivos si los sintetizados no convencen.
4. Jugar los 3 niveles de punta a punta y ajustar HP/cadencia de jefes y
   enemigos a mano.
