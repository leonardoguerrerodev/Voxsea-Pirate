# Plan de ejecución

Cada fase deja algo que se puede probar. Una fase está terminada cuando cumple su criterio, no cuando el código está escrito. Las reglas técnicas están en `CLAUDE.md`.

## Fase 0 — Proyecto base

- [x] Crear el proyecto Godot 4 con renderer Forward+ en la raíz del repo.
- [x] Activar Jolt Physics en la configuración del proyecto.
- [x] Estructura de carpetas de `CLAUDE.md`: se crea cada carpeta cuando una fase la usa (por ahora `core/` y `sandbox/`).
- [x] Autoloads vacíos: `Game` (reloj del mar, estado global) y `Events` (bus de señales).
- [x] Escena de prueba con cámara orbital y luz direccional (`sandbox/sandbox.tscn`).

**Terminado cuando:** el proyecto abre sin errores, el commit no incluye `.godot/` y la cámara orbita la escena vacía.

## Fase 1 — Océano y objeto flotante

- [x] Recurso `WaveSettings` con 8 ondas (dirección, amplitud, longitud, empinamiento).
- [x] Malla del mar centrada en la cámara (512 m, 1 m por vértice) + falda de horizonte.
- [x] Shader de Gerstner que lee `WaveSettings` y `Game.ocean_time`.
- [x] `WaveSettings.get_wave_height(x, z, t)` en GDScript con la misma fórmula (invierte el desplazamiento horizontal).
- [x] Cubo `RigidBody3D` con 8 puntos de flotabilidad (centros de sus 8 celdas).
- [x] Color por profundidad, espuma en crestas y en contacto, reflejo del cielo.
- [x] Pasada visual: refracción con absorción por canal (Beer-Lambert), espuma por Jacobiano en manchas, franja de contacto animada (ideas de emilje/godot-water-shader y krautdev/GodotOceanWaves).
- [x] Test `tests/test_ocean.gd`: inversión de altura y cubo a nivel de la ola.

**Terminado cuando:** el cubo sigue las olas sin atravesarlas ni flotar por encima, y cambiar `WaveSettings` en el inspector cambia el mar y el comportamiento del cubo a la vez.

## Fase 2 — Datos voxel y mesher

- [x] Prueba de Voxel Tools v1.7x (GDExtension) en 4.7.2: aprobada. `VoxelMesherCubes` con greedy meshing y paleta; la malla es un `ArrayMesh` normal que se mueve con cualquier nodo.
- [x] `VoxelMaterial` (recurso): nombre, densidad, resistencia, color. El id es su índice en `MaterialCatalog` (`ship/data/materials.tres`).
- [x] `ShipData`: grilla en `PackedByteArray` (orden ZXY de `VoxelBuffer`), chunks de 16³, con señal `changed(chunk)`.
- [x] `ShipEditCommand` y `ShipEditor.apply()`, que devuelve el comando inverso (base del deshacer).
- [x] `ShipMesh`: greedy meshing por chunk con `VoxelMesherCubes`. ~~En un hilo aparte~~: no hizo falta (ver medición).
- [x] Barco de prueba generado por código (`sandbox/test_ship.gd`).
- [x] Medir tiempo de remallado por chunk: 0,19 ms un chunk lleno; 6,6 ms el peor caso (ajedrez 3D), en el MacPro.
- [x] Test `tests/test_ship.gd`.

**Terminado cuando:** el barco de prueba se ve, un comando que cambia un voxel remalla solo su chunk, y el remallado de un chunk lleno tarda menos de 8 ms. Si no, se decide el port a GDExtension antes de seguir.

## Fase 3 — Modo construcción

- [ ] Jugador en primera persona (Quality First Person Controller) para recorrer el astillero.
- [ ] Cursor 3D que apunta a la cara del voxel bajo la mira.
- [ ] Colocar y quitar voxels; elegir material.
- [ ] Simetría espejo (babor/estribor).
- [ ] Deshacer y rehacer con la pila de comandos.
- [ ] Herramientas de relleno: línea y caja.
- [ ] Suavizado visual de bordes (surface nets o biselado en el mesher).

**Terminado cuando:** puedes construir un casco de bote en menos de 5 minutos y deshacer cada paso.

## Fase 4 — Flotabilidad desde voxels

- [x] Masa, centro de gravedad e inercia calculados desde los materiales (`ShipHydrostatics`), entregados al `RigidBody3D` como valores propios.
- [x] Aire interior: mirando abajo y a los 4 lados se choca con casco (un bote sin cubierta también tiene interior). Compartimentos = grupos conectados de aire interior; aberturas = voxels que tocan aire exterior.
- [x] Puntos de flotabilidad en celdas de 1 m (2×2×2 voxels); la altura del mar se muestrea por columnas de 2 m.
- [x] Amortiguación lineal y angular en el agua (`water_drag` por kilo desplazado).
- [x] Inundación: por cada abertura sumergida entran `flood_rate` voxels/s, de abajo hacia arriba, hasta el nivel del mar de afuera. Tapar el agujero no achica.
- [x] Máscara de agua: el aire seco se sube como textura 3D y el shader del mar no se dibuja ahí (funciona con la cámara dentro del barco).
- [x] Visualización de depuración (F3): aire seco por compartimento (un color cada uno) y centro de gravedad. La línea de flotación ya se ve en el mar.
- [x] Test `tests/test_hydro.gd` con los cuatro criterios en mar calmo.

**Terminado cuando:** un casco cerrado flota, una balsa plana flota baja, un barco con peso arriba escora, y quitar voxels bajo la línea de flotación hunde ese lado.

## Fase 5 — Navegación

- [ ] Viento global con dirección y fuerza que cambian lento.
- [ ] Pieza vela: fuerza según superficie y ángulo con el viento.
- [ ] Pieza timón: torque proporcional a la velocidad.
- [ ] Resistencia del casco según su forma frontal.
- [ ] Ancla.
- [ ] Caminar sobre la cubierta en movimiento en primera persona y tomar el timón.
- [ ] Estela: espuma persistente que crece y se desvanece (dos texturas alternadas que siguen a la cámara, idea de emilje/godot-water-shader).

**Terminado cuando:** un barco con vela navega, vira contra el viento en zigzag, y uno más largo gira más lento que uno corto.

## Fase 6 — Cañones y daño

- [ ] Pieza cañón con arco de tiro según su orientación.
- [ ] Apuntar por banda y disparar.
- [ ] Proyectil balístico con colisión contra voxels.
- [ ] Daño: arrancar voxels en un radio según resistencia del material.
- [ ] Restos flotantes recolectables.
- [ ] Reparación con tablones en el mar.

**Terminado cuando:** un cañonazo a un barco objetivo abre un agujero, el barco hace agua por ahí, y repararlo lo estabiliza.

## Fase 7 — Primer Abisal

- [ ] Tiburón grande con máquina de estados: patrullar, perseguir, embestir, huir.
- [ ] Embestida que arranca voxels del casco.
- [ ] Vida, daño por cañón y arpón.
- [ ] Botín: hueso y escama.

**Terminado cuando:** se puede ganar y perder una pelea contra el tiburón, y el botín sirve para construir.

## Fase 8 — Pesca

- [ ] Caña con minijuego de tensión.
- [ ] Tablas de peces por zona y hora.
- [ ] Carnada que atrae peces o Abisales.
- [ ] Red de arrastre como pieza del barco.

**Terminado cuando:** pescar con caña y con red da peces distintos, y la carnada hace aparecer al tiburón.

## Hito — Rebanada vertical

Una isla, el astillero y aguas someras. Construir, zarpar, pescar, pelear con el tiburón, volver y mejorar el barco. Se juega de principio a fin en 20 minutos. Antes de seguir, se prueba con otras personas y se ajusta.

## Fase 9 — Astillero, economía y guardado

- [ ] Bartolo: tienda de planos, comentarios sobre el diseño del barco.
- [ ] Inventario y bodega del barco con capacidad.
- [ ] Guardar y cargar partida (barco serializado con RLE).
- [ ] Pérdida parcial de cargamento al hundirse.

## Fase 10 — Zonas del mundo

- [ ] Mar abierto: tormentas, serpientes de marea, Saqueadores.
- [ ] Las fosas: oscuridad, ciudades hundidas, el Coleccionista.
- [ ] El Ojo: remolino y combate final.
- [ ] Ciclo día/noche y clima.

## Fase 11 — Cooperativo online

- [ ] Host autoritativo para física y voxels.
- [ ] Comandos de edición y disparos por red.
- [ ] Sincronización de estado del barco con interpolación.
- [ ] Roles a bordo: timón, cañones, velas, reparación.

## Fuera de alcance por ahora

- Océano FFT (se evalúa después de la rebanada vertical). Candidatos: [2Retr0/GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves) (FFT por espectros JONSWAP/TMA, espuma por Jacobiano, rocío; solo render, Godot 4.3) y su fork [krautdev/GodotOceanWaves](https://github.com/krautdev/GodotOceanWaves) (agrega `get_height` en CPU con lectura síncrona de GPU). Opción preferida: Gerstner sigue siendo la física y FFT agrega detalle visual encima (regla 1 intacta); la alternativa es leer la altura con la lectura asíncrona de GPU de Godot 4.4+.
- Mundo procedural infinito.
- Tripulación controlada por IA.
- Versión móvil.
