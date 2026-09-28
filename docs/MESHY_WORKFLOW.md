# Integrar modelos de Meshy

Hoy todo el arte 3D es placeholder (primitivas generadas por codigo en
`_build_visual()` de cada script). Cuando Matias pase los `.glb`
exportados de Meshy, el flujo es:

## 1. Importar

- Poner el `.glb` en `assets/models/<categoria>/<nombre>.glb` (crear las
  carpetas si no existen, por ejemplo `assets/models/ships/interceptor.glb`).
- Godot lo importa solo al abrir el proyecto.

## 2. Medir y escalar (regla: nunca viene en metros reales)

1. Instanciar el `.glb` en una escena de prueba vacia.
2. Seleccionar el nodo raiz, ver el AABB (Editor > pestania "MeshInstance3D"
   o con un script: `print(mesh_instance.get_aabb())`).
3. Comparar contra el tamanio esperado en este proyecto (unidades de
   mundo, definidas en `core/Constants.gd`):
   - Nave de jugador: pensada para un AABB de referencia ~0.6 x 0.35 x 0.9
     (ver `Player._build_visual()`, `PrismMesh.size`).
   - Enemigos chicos (caza basico/rapido, dron): ~0.5-0.6 de lado.
   - Enemigos grandes (bombardero, porta-naves): ~1.1-1.4 de lado.
   - Jefes: 2.0-2.8 de lado (ver cada `_build_visual()` en
     `scenes/bosses/`).
4. Escalar con el **minimo de los cocientes** (ancho esperado / ancho real,
   alto esperado / alto real, profundidad esperada / profundidad real) para
   no deformar el modelo, y pegar contra el borde que importa (para una
   nave, generalmente la base/panza contra el plano de vuelo, no el centro
   ciego).

## 3. Reemplazar el placeholder

Cada script de gameplay tiene un metodo `_build_visual()` que hoy arma la
primitiva. Para reemplazarlo:

```gdscript
func _build_visual() -> void:
	var model := preload("res://assets/models/ships/interceptor.glb").instantiate()
	model.scale = Vector3(FACTOR, FACTOR, FACTOR) # el que salio del paso 2
	add_child(model)
```

No hace falta tocar nada mas: la colision, el movimiento y el combate no
dependen del mesh visual (son shapes separados armados en
`_build_collision()`), asi que se puede cambiar el arte sin romper la
logica. Si el modelo tiene una escala/orientacion rara "de fabrica",
corregirla en este mismo punto (rotation_degrees, position offset) en vez
de tocar el resto del script.

## 4. Verificar caminando (o volando), no con el render

Cargar el nivel real y jugar unos segundos con esa nave/enemigo puesto.
Cosas que un render no muestra:

- Si la escala quedo mal, se nota comparando el nuevo modelo contra el
  ancho del playfield (`Constants.PLAYFIELD_HALF_WIDTH * 2`, hoy 7 unidades)
  y contra los otros enemigos ya en pantalla.
- Si el modelo "flota" o esta enterrado, se nota en movimiento, no en una
  captura estatica.

## Notas sobre los prompts de Meshy (reglas ya aprendidas)

- Tope ~800 caracteres. Encuadre primero, contenido, escala al final.
- Pedir proporciones un poco mas anchas de lo necesario (ej. 9x7 si se
  necesita 8x8): Meshy no las garantiza.
- No pedirle a Meshy que "saque una pared" o geometria puntual: probar el
  modelo integrado tal cual antes de pedir una regeneracion.
