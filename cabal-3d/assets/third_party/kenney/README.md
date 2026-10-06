# Assets de terceros: Kenney (CC0)

Todo lo de esta carpeta es de [Kenney](https://kenney.nl) y esta publicado bajo licencia
**CC0 1.0 (dominio publico)**: se puede usar libremente, incluso en proyectos comerciales, sin atribucion
obligatoria (igual se agradece: gracias, Kenney!). Cada pack trae su `LICENSE_*.txt` original.

El estilo visual del juego es **low-poly estilizado** (personajes de cubos, props simples con una sola textura de
color): no busca realismo. Los modelos se convirtieron a materiales con luz en tiempo de ejecucion (los GLB
originales vienen "unlit").

| Carpeta | Pack | Uso |
|---|---|---|
| `characters/` | Blocky Characters | jugador y enemigos (`character-m/k/d/g/o/h.glb` + `Textures/`) |
| `blasters/` | Blaster Kit | armas del jugador y enemigos, granada, items de drop |
| `survival/` | Survival Kit | cajas, barriles, paneles metalicos, vallas, rocas, escombros, fogatas |
| `city/` | City Kit (Industrial) | edificios, chimeneas, contenedores, tanques, torre de agua, molino |
| `particles/` | Particle Pack | fogonazos, llamas, humo, chispas, resplandores, marcas de quemadura |
| `fonts/` | Kenney Fonts | Kenney Future (interfaz) |

Los efectos de sonido (`assets/audio/*.wav`) son los mismos de `cabal-godot/` (sintetizados y mezclados con
Impact Sounds / Sci-fi Sounds de Kenney, tambien CC0).

Nota tecnica: los `.glb.import` de estos modelos tienen `meshes/force_disable_compression=true`. Con la
compresion de mallas de Godot 4.2 (renderer Compatibility) las coordenadas UV mayores a 1 que usan los GLB de
Kenney se estropean y las texturas se ven mal. No lo cambies.
