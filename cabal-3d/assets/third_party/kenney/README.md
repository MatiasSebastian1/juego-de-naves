# Assets de terceros: Kenney (CC0)

Todo lo de esta carpeta es de [Kenney](https://kenney.nl) y esta publicado bajo licencia
**CC0 1.0 (dominio publico)**: se puede usar libremente, incluso en proyectos comerciales, sin atribucion
obligatoria (igual se agradece: gracias, Kenney!). Cada pack trae su `LICENSE_*.txt` original.

Los personajes ya no son de Kenney: el soldado y el zombi son de Meshy (`assets/meshy/`). Estos props son **low-poly estilizados**
(una sola textura de color). Los modelos se convirtieron a materiales con luz en tiempo de ejecucion (los GLB
originales vienen "unlit").

| Carpeta | Pack | Uso |
|---|---|---|
| `blasters/` | Blaster Kit | armas del jugador (blaster-a/d/e), granada del jugador, items de drop |
| `survival/` | Survival Kit | cajas, barriles, paneles metalicos, vallas, rocas y fogatas (cobertura baja de la arena) |
| `particles/` | Particle Pack | fogonazos, llamas, humo, chispas, resplandores, marcas de quemadura |
| `fonts/` | Kenney Fonts | Kenney Future (interfaz) |

Los efectos de sonido (`assets/audio/*.wav`) son los mismos de `cabal-godot/` (sintetizados y mezclados con
Impact Sounds / Sci-fi Sounds de Kenney, tambien CC0).

Se retiraron del proyecto los modelos que ya no se usan (City Kit completo, parte del Survival Kit, los Blocky Characters y los blasters de los enemigos) para achicar
el ejecutable: la arena actual es la aldea de Meshy (`assets/meshy/`).

Nota tecnica: los `.glb.import` de estos modelos tienen `meshes/force_disable_compression=true`. Con la
compresion de mallas de Godot 4.2 (renderer Compatibility) las coordenadas UV mayores a 1 que usan los GLB de
Kenney se estropean y las texturas se ven mal. No lo cambies.
