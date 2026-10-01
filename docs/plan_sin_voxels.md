# Plan: quitar los voxels del barco + interruptores gráficos

Decisión de origen: `docs/decisiones.md` (2026-10-01). Planificador: Opus. Ejecutor: Sonnet (`ejecucion-planes`) o quien Leo indique.

## Objetivo
La balandra (`assets/ships/sloop/`) flota, navega y se camina sin ningún código voxel en tiempo de juego (sin `ShipData`, sin Voxel Tools, sin constructor). El menú dev permite alternar tonemapping (incluido AgX), SSR, SSAO, SSIL, SDFGI, glow, niebla volumétrica y ajustes de color para medir en el Nobara.

## Alcance
**Incluye:** perfil de casco precalculado (`HullProfile`), `ShipBody` reescrito sobre ese perfil, piezas como nodos `ShipPart`, colisión desde la malla (`HullCollision`), máscara de agua estática, borrado del sistema voxel y de Voxel Tools, tests adaptados, interruptores gráficos en el menú dev, docs.
**No incluye:** agujeros, fugas, baldes ni tablones (combate, plan siguiente); inundación; escotilla abierta ni escalera a la bodega; modelos de mástil; mejoras del shader del mar; commits (Leo aprueba aparte).

## Entorno
- Godot 4.7.2 estable en `../Godot_v4.7.2-stable_linux.x86_64` desde la raíz del repo. VERIFICADO (los 11 tests corrieron así el 2026-10-01).
- Blender 5.2.0 en `/usr/bin/blender`, con numpy. VERIFICADO (`blender --version`, sesión 2026-10-01).
- Modelo crudo `models/fusion.glb` (fuera de git, solo local en el Nobara). VERIFICADO (`ls models/`).
- Comando de test: `../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- <test>`; código de salida 0 = OK. VERIFICADO (`tests/run.gd`).
- Importar: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import`. VERIFICADO (CLAUDE.md).

## Invariantes
- `test_ocean`, `test_map`, `test_compass`, `test_weather`, `test_step` siguen en OK sin tocarse → paso 13.
- `test_sailing` mantiene **las mismas expectativas** (navega de costado > 2,5 m/s, ancla < 0,3 m/s, ciñe a 50°, el largo gira más lento, zona prohibida 20–50°) → pasos 9 y 13.
- `test_deck`: el personaje viaja con el barco (deriva < 0,5 m, y local 3,9–4,5) → pasos 10 y 13.
- Regla 1 (altura del mar de una sola fuente) y regla 8 (quien camina es hijo del barco, `platform_floor_layers = 0`, colisión cinemática hija) intactas → paso 7 conserva el patrón de `ship/physics/ship_deck.gd`.
- El sandbox abre sin errores de script → paso 12.

## Decisiones tomadas
1. **Flotación por celdas precalculadas, no por puntos a mano** (alternativa: `BuoyantBody` con 8 puntos; descartada porque no da escora ni calado realistas en un casco largo). Las celdas salen de la ocupación del modelo: el `.grid` pasa a guardar `1 = casco, 2 = aire interior` (el aire interior lo calcula Blender una vez). En juego no se edita nada.
2. **El algoritmo de masa y celdas se porta** desde `ship/physics/ship_hydrostatics.gd` (`_compute_mass` y `_compute_cells`) a `HullProfile`, simplificado: celda de 1 m = bloque de 2×2×2 voxels; volumen = voxels ocupados (casco o interior) × 0,125 m³; centro = promedio de los centros de esos voxels; alto = (y máx − y mín + 1) × 0,5 m; columna de muestreo del mar = bloque de 4×4 voxels en x/z (2 m).
3. **Masa del casco = voxels de casco × densidad (600 kg/m³) × 0,125.** Mantiene la calibración actual de la vela (`ShipRig.sail_scale`). Las piezas (`ShipPart.mass`) suman masa y mueven el centro de gravedad; no suman inercia (ponytail: despreciable frente al casco).
4. **Máscara de agua:** se conserva el shader del mar sin cambios; `WaterMask` sube **una vez** una textura 3D con el aire interior del perfil.
5. **Piezas:** nodo `ShipPart` (Node3D) hijo del `ShipBody`, con `kind` (NONE, SAIL, HELM, ANCHOR), `mass`, `sail_area`, `mast_height`. Su `position` es la base apoyada en la cubierta. NONE = carga o prop con masa (base de la decoración futura).
6. **Posiciones de las piezas de la balandra:** se descubren con un rayo contra la colisión del modelo (paso 11), no a ojo.
7. **Se borran las acciones de input `build_*`** de `project.godot` (quedan sin uso).
8. **Tonemapping:** `Sky3D` solo fija ACES al crear el entorno (`addons/sky_3d/src/Sky3D.gd:465-475`, VERIFICADO); cambiarlo en runtime persiste.

## Preguntas abiertas
Ninguna.

## Supuestos globales
- SUPUESTO: `Environment` de Godot 4.7.2 tiene `TONE_MAPPER_AGX` y las propiedades `ssr_enabled`, `ssao_enabled`, `ssil_enabled`, `sdfgi_enabled`, `glow_enabled`, `volumetric_fog_enabled`, `adjustment_enabled`, `adjustment_saturation`, `adjustment_contrast` → se verifica en el paso 1.
- SUPUESTO: `Mesh.get_faces()` devuelve los triángulos de una malla importada de `.glb` (ya se usa en `ship/physics/ship_deck.gd:51` con mallas generadas) → se verifica en el paso 7 (test_deck y paso 11).

## Pasos

### 1. Verificar API de Environment (sin mutar)
- Depende de: —
- Cambio: crear `tests/_probe_env.gd` temporal (extends Node) que imprima `ClassDB.class_get_enum_constants("Environment", "ToneMapper")` y, por cada propiedad del supuesto, `ClassDB.class_has_method`/`"x" in Environment.new()`; luego `get_tree().quit()`. Correr con el comando de test y `-- res://tests/_probe_env.gd`. Borrar el archivo y su `.uid`.
- Verificación: la salida lista `TONE_MAPPER_AGX` y todas las propiedades existen.
- Falla → si falta alguna propiedad, el paso 14 la omite y lo declara en el reporte; si falta `TONE_MAPPER_AGX`, el selector del paso 14 no la incluye.

### 2. Ocupación con aire interior en el `.grid`
- Depende de: —
- Archivos: `tools/hull_to_grid.py`.
- Cambio: después de `voxels = np.maximum(voxels, voxels[:, ::-1, :])` (simetría), escribir el casco como `1` (no `PLANK`) y marcar aire interior como `2`: exterior = relleno desde los bordes de la grilla a través de celdas ≠ casco, conectividad de 6 vecinos, **con el borde superior (y máximo) también abierto**; todo lo que no es casco ni exterior = interior. Implementar con numpy por dilatación iterativa hasta que no cambie. Actualizar el comentario de cabecera (`1 = casco, 2 = aire interior`) y quitar la constante `PLANK`. Imprimir la cantidad de voxels interiores.
- Regenerar: `blender -b --python tools/hull_to_grid.py -- models/fusion.glb assets/ships/sloop/sloop 20 40000`.
- Verificación: la salida imprime `grilla [21, 21, 41]` y un conteo interior > 1000. Con python/numpy, en el corte z = 20 (orden `[z][x][y]`), la fila y = 5 tiene `2` entre los `1` de ambos costados.
- Falla → interior = 0: la cubierta tiene un hueco en la grilla; detener y reportar.

### 3. `HullProfile`
- Depende de: 2.
- Archivos: crear `ship/hull/hull_profile.gd` (`class_name HullProfile extends RefCounted`).
- Cambio: constantes `VOXEL_SIZE = 0.5`, `CELL = 2`, `COLUMN = 4`. Campos: `size: Vector3i`, `interior: PackedByteArray` (1 = interior, orden ZXY índice `y + x·sy + z·sy·sx`), `mass`, `center_of_mass`, `inertia`, `length`, `beam`, `cell_centers`, `cell_heights`, `cell_volumes`, `cell_columns`, `column_points` (mismos tipos que en `ship_hydrostatics.gd`). Funciones:
  - `static func from_occupancy(p_size: Vector3i, occupancy: PackedByteArray, density: float) -> HullProfile`: masa, centro e inercia desde los voxels `1` (portar `_compute_mass`, sin piezas); `length`/`beam` desde la extensión de los voxels `1` en z/x; celdas según la decisión 2 con voxels `1` o `2`; `interior` = 1 donde `occupancy == 2`.
  - `static func from_file(path: String, density: float) -> HullProfile` (no se llama `load` para no tapar la función global): lee 3 int32 + bytes (como `ship/data/hull_grid.gd`) y llama a `from_occupancy`.
  - `static func box(p_size: Vector3i, density: float) -> HullProfile`: caja cerrada de pared simple (casco = caras, interior = resto) → `from_occupancy`. Si `p_size.y == 1`, todo es casco (balsa).
- Verificación: se cubre en el paso 8.

### 4. `ShipPart`
- Depende de: —
- Archivos: crear `sailing/ship_part.gd` (`class_name ShipPart extends Node3D`).
- Cambio: `enum Kind { NONE, SAIL, HELM, ANCHOR }`; `@export var kind`, `@export_range(0, 50000, 1, "suffix:kg") var mass: float = 0.0`, `@export_range(0, 400, 1, "suffix:m²") var sail_area`, `@export_range(0, 30, 0.5, "suffix:m") var mast_height`. Comentario: la posición es la base sobre la cubierta.

### 5. `ShipBody` sin voxels
- Depende de: 3, 4.
- Archivos: `ship/physics/ship_body.gd`.
- Cambio: quitar `catalog`, `data`, `hydro`, `flood_rate`, `FLOOD_INTERVAL`, `_dirty`, `_flood_time` y la inundación. Agregar `@export_file("*.grid") var grid_path: String`, `@export_range(10, 2000, 1, "suffix:kg/m³") var hull_density: float = 600.0`, `var profile: HullProfile`. En `_enter_tree`: si `profile == null`, `profile = HullProfile.from_file(grid_path, hull_density)`. En `_ready`: masa = `profile.mass` + Σ `ShipPart.mass`; centro = promedio ponderado (piezas en su `position`); `center_of_mass_mode = CUSTOM`; `inertia = profile.inertia.max(Vector3.ONE)`. Agregar `func parts(kind: int) -> Array[ShipPart]` (hijos directos `ShipPart` de ese `kind`). `_apply_buoyancy` igual que hoy, leyendo de `profile` en vez de `hydro`. Actualizar el comentario de clase (sin `ShipDeck` ni dique seco: `freeze` sigue saltándose la física).
- Verificación: se cubre en los pasos 8 y 9.

### 6. `ShipRig`, `ShipPartsView`, `HelmControl` sobre `ShipPart`
- Depende de: 5.
- Archivos: `sailing/ship_rig.gd`, `sailing/ship_parts_view.gd`, `sailing/helm_control.gd`.
- Cambio:
  - `ShipRig`: `hydro.length`/`hydro.beam` → `ship.profile.length`/`ship.profile.beam`; el ancla actúa si `not ship.parts(ShipPart.Kind.ANCHOR).is_empty()`; `_apply_sails` itera `ship.parts(ShipPart.Kind.SAIL)`; punto de fuerza local = `part.position + Vector3.UP * part.mast_height * 0.5`; área = `part.sail_area`; `sail_trims` usa la pieza como clave.
  - `ShipPartsView`: dibujar por cada `ShipPart` de `ship` (vela, timón, ancla) con `top = part.position`; `_sails` con la pieza como clave; quitar la conexión a `ship.data.changed` y `_dirty`: construir una vez en `_ready`.
  - `HelmControl._near_helm`: recorrer `ship.parts(ShipPart.Kind.HELM)` y medir contra `part.global_position`.

### 7. `HullCollision`
- Depende de: —
- Archivos: crear `ship/physics/hull_collision.gd` (`class_name HullCollision extends AnimatableBody3D`).
- Cambio: `@export var model: Node3D`. En `_ready`: `sync_to_physics = false`; juntar las caras de cada `MeshInstance3D` descendiente de `model` (`mesh.get_faces()` transformadas por `get_parent().global_transform.affine_inverse() * instance.global_transform`); una `CollisionShape3D` con `ConcavePolygonShape3D.set_faces()`. Comentario: reemplaza a `ShipDeck` (regla 8: cinemática, cóncava, hija del barco).
- Verificación: paso 10 (`test_deck`) y paso 11.

### 8. `test_hull` nuevo
- Depende de: 3, 5.
- Archivos: reemplazar `tests/test_hull.gd`.
- Cambio: chequeos (mismo formato `_expect`, sale con 0/1):
  - masa de `HullProfile.box(Vector3i(4, 2, 4), 600)` = voxels de casco × 600 × 0,125;
  - a los 10 s en mar calmo (`WaveSettings.new()`): caja `box(10, 8, 16)` con base entre 0 y −4 m; balsa `box(8, 1, 16)` con base entre −0,4 y −0,2; caja con un `ShipPart` NONE de 5000 kg en `(0.5, 4.0, 4.0)` escora > 0,05 rad; balandra (`grid_path = "res://assets/ships/sloop/sloop.grid"`) con calado entre 0 y 5,5 m y escora < 0,05 rad.
- Verificación: `test_hull` → `OK`, código 0.
- Falla → detener y reportar valores impresos (no ajustar expectativas).

### 9. `test_sailing` adaptado
- Depende de: 5, 6.
- Archivos: `tests/test_sailing.gd`.
- Cambio: `_hull(size, sail)` crea el `ShipBody` con `profile = HullProfile.box(size, 600)` antes de `add_child`, y agrega hijos `ShipPart`: SAIL (si `sail`) en `(size.x/2 + 0.5, size.y, size.z/3 + 0.5) * 0.5` con `sail_area = 100`, `mast_height = 12`, `mass = 200`; HELM en `(size.x/2 + 0.5, size.y, size.z - 3 + 0.5) * 0.5`; ANCHOR en `(size.x/2 + 0.5, size.y, 2.5) * 0.5`. `_spawn` recibe el `ShipBody` ya armado. Quitar las constantes de ids. **No tocar expectativas.**
- Verificación: `test_sailing` → `OK`.
- Falla → detener y reportar la línea `FALLA` y las velocidades impresas.

### 10. `test_deck` adaptado
- Depende de: 5, 7.
- Archivos: `tests/test_deck.gd`.
- Cambio: `ShipBody` con `profile = HullProfile.box(Vector3i(10, 8, 16), 600)`; hijo `MeshInstance3D` con `BoxMesh` de `size = Vector3(5, 4, 8)` en `position = Vector3(2.5, 2, 4)`; hijo `HullCollision` con `model` = esa malla. Resto igual.
- Verificación: `test_deck` → `OK`.

### 11. Sandbox con piezas y colisión del modelo
- Depende de: 5, 6, 7.
- Archivos: `sandbox/sandbox.tscn`, borrar `sandbox/sloop_ship.gd` (+ `.uid`).
- Cambio: `TestShip` usa `res://ship/physics/ship_body.gd` con `grid_path = "res://assets/ships/sloop/sloop.grid"` (sin `catalog`). Quitar nodos `Hull`, `Deck`, `Debug/DryAir` y `Builder`; quitar sus `ext_resource` (`7_mats`, `8_mesh`, `11_deck`, `13_builder`, `14_hull`) y `sub_resource` (`hull_mat`, `dry_air_mat`). Agregar `Collision` (`HullCollision`, `model = NodePath("../Model")`).
  - Descubrimiento: script temporal que instancia el sandbox, espera 1 frame de física y lanza rayos hacia abajo (`PhysicsRayQueryParameters3D`, desde y local 20 hasta −1, en coordenadas del barco) en x = 5.25 y z = 7.6 (vela), 17.4 (timón), 4.1 (ancla); imprime la y local del impacto.
  - Agregar 3 `ShipPart` hijos de `TestShip` en esas posiciones: `Sail` (SAIL, `sail_area = 100`, `mast_height = 12`, `mass = 200`), `Helm` (HELM), `Anchor` (ANCHOR).
- Verificación: los 3 rayos impactan (si alguno no impacta → detener y reportar). Captura sin `--headless` desde fuera del barco: mástil, timón y ancla apoyados sobre la cubierta.

### 12. Borrar el sistema voxel y Voxel Tools
- Depende de: 5–11.
- Archivos a borrar (con su `.uid`): `ship/data/` completo, `ship/mesh/chunk_mesher.gd`, `ship/mesh/ship_mesh.gd`, `ship/mesh/hull.gdshader`, `ship/physics/ship_hydrostatics.gd`, `ship/physics/ship_deck.gd`, `building/` completo, `sandbox/test_ship.gd`, `tests/test_ship.gd`, `tests/test_build.gd`, `tests/test_hydro.gd`, `addons/zylann.voxel/` completo, `.godot/extension_list.cfg`.
- Editar:
  - `ship/mesh/water_mask.gd`: construir las capas desde `ship.profile.interior`/`ship.profile.size` (código de `ship/mesh/voxel_texture.gd`, dentro de `water_mask.gd`), subir una vez en `_ready`, escala `1 / HullProfile.VOXEL_SIZE`; luego borrar `voxel_texture.gd`.
  - `ship/debug/ship_debug.gd`: solo el centro de gravedad.
  - `ui/game_ui.gd`: `HELP` sin las líneas del constructor y de materiales; F3 = "centro de gravedad".
  - `ui/dev_menu.gd`: quitar la fila `flood_rate`.
  - `project.godot`: borrar `build_toggle`, `build_place`, `build_remove`, `build_tool`, `build_mirror`, `build_undo`, `build_redo`.
  - `tests/run.gd`: el ejemplo del comentario pasa a `test_hull`.
- Verificación: `grep -rnE "ShipData|ShipEditor|ShipEditCommand|ShipHydrostatics|ShipMesh|ChunkMesher|ShipDeck|VoxelTexture|VoxelMaterial|MaterialCatalog|HullGrid|ShipBuilder|BuildHistory|zylann|VoxelBuffer" --include=*.gd --include=*.tscn --include=*.tres --include=*.godot --include=*.gdshader .` → sin resultados. El import headless no imprime `SCRIPT ERROR` ni `Parse Error`.

### 13. Suite completa
- Depende de: 12.
- Verificación: `test_ocean`, `test_step`, `test_deck`, `test_sailing`, `test_map`, `test_compass`, `test_weather`, `test_hull` → los 8 con código 0.

### 14. Interruptores gráficos en el menú dev
- Depende de: 1, 12.
- Archivos: `ui/dev_menu.gd`.
- Cambio: en la sección "Gráficos", con `var env: Environment = sky.environment`: `_option(env, "tonemap_mode", "Tonemapping", [nombres en el orden del enum según el paso 1])`; `_slider(env, "tonemap_exposure", "Exposición", 0.25, 4.0, 0.05)`; `_check` para `ssr_enabled` ("Reflejos SSR"), `ssao_enabled` ("Oclusión SSAO"), `ssil_enabled` ("Luz indirecta SSIL"), `sdfgi_enabled` ("Iluminación global SDFGI"), `glow_enabled` ("Brillo"), `volumetric_fog_enabled` ("Niebla volumétrica"), `adjustment_enabled` ("Ajustes de color"); `_slider` para `adjustment_saturation` y `adjustment_contrast` (0–2, paso 0,05). Una línea por ajuste (regla 10). Omitir lo que el paso 1 haya marcado como inexistente.
- Verificación: import sin errores; captura con el menú dev abierto en Gráficos.

### 15. HUMANO: medir en el Nobara
- Depende de: 14.
- Leo corre `../Godot_v4.7.2-stable_linux.x86_64 --path . --print-fps` a 1440p y anota los FPS con cada interruptor (base, +SSR, +SSAO, +SSIL, +SDFGI, AgX). La ejecución no se detiene: los pasos 16 y 17 no dependen de esto.

### 16. Docs
- Depende de: 12.
- Archivos: `CLAUDE.md` (tabla Stack: fila Voxels → "Casco: modelo + perfil de flotación precalculado (`HullProfile`)"; reglas 2, 4 y 9 reescritas para `ShipPart`/`HullProfile`, sin comandos de edición; Estructura sin `building/` y con `ship/hull/`; lista de tests; Riesgos: quitar los de voxels; Funcionalidades/Roadmap: anotar el cambio), `docs/plan.md` (nota al inicio: fases 2–4 reemplazadas, ver `docs/decisiones.md`).
- Verificación: `grep -n "ShipEditor\|VoxelMesherCubes" CLAUDE.md` → sin resultados.

### 17. Verificación integral
- Repetir el paso 13 y el grep del paso 12; `git status --short` no muestra `models/` agregado. Reportar a Leo el resumen y **no commitear** (lo aprueba él).

## Checkpoints y rollback
- Checkpoint 0: commit `fac9d9d` (estado actual en `origin/main`). Rollback total: `git restore --staged --worktree . && git clean -fd -- ship building sandbox tests tools sailing ui docs` (no toca `models/`).
- Checkpoint A: tras el paso 11, el sandbox corre con la colisión nueva y los archivos viejos todavía existen. Si el paso 12 rompe algo, se vuelve al estado del paso 11 restaurando los archivos borrados con `git restore <ruta>`.
- Sin puntos de no retorno: todo está en git y nada se publica.

## Fuera de alcance
- Agujeros, fugas, nivel de agua, baldes y tablones (plan de combate).
- Escotilla abierta, escalera y bodega jugable.
- Modelos de mástil del set de Tripo, texturas en resolución completa.
- Reflejos propios del mar (el mar es transparente y es probable que SSR no lo afecte; evaluar reflejo planar o SSR en el shader después de medir).
- Mar FFT.
