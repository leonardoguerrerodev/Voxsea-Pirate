# Plan de ejecución

Cada fase deja algo que se puede probar. Una fase está terminada cuando cumple su criterio, no cuando el código está escrito. Las reglas técnicas están en `CLAUDE.md`.

## Fase 0 — Proyecto base

- [ ] Crear el proyecto Godot 4 con renderer Forward+ en la raíz del repo.
- [ ] Activar Jolt Physics en la configuración del proyecto.
- [ ] Crear la estructura de carpetas de `CLAUDE.md`.
- [ ] Autoloads vacíos: `Game` (reloj del mar, estado global) y `Events` (bus de señales).
- [ ] Escena de prueba con cámara orbital y luz direccional.

**Terminado cuando:** el proyecto abre sin errores, el commit no incluye `.godot/` y la cámara orbita la escena vacía.

## Fase 1 — Océano y objeto flotante

- [ ] Recurso `WaveSettings` con 8 ondas (dirección, amplitud, longitud, empinamiento).
- [ ] Malla del mar centrada en la cámara.
- [ ] Shader de Gerstner que lee `WaveSettings` y `Game.ocean_time`.
- [ ] `Ocean.get_wave_height(x, z, t)` en GDScript con la misma fórmula.
- [ ] Cubo `RigidBody3D` con 8 puntos de flotabilidad en sus esquinas.
- [ ] Color por profundidad, espuma en crestas, reflejo del cielo.

**Terminado cuando:** el cubo sigue las olas sin atravesarlas ni flotar por encima, y cambiar `WaveSettings` en el inspector cambia el mar y el comportamiento del cubo a la vez.

## Fase 2 — Datos voxel y mesher

- [ ] `VoxelMaterial` (recurso): id, nombre, densidad, resistencia, color.
- [ ] `ShipData`: grilla en `PackedByteArray`, dividida en chunks de 16³, con señal `changed(chunk)`.
- [ ] `ShipEditCommand` y `ShipEditor.apply()`.
- [ ] Mesher con greedy meshing por chunk, en un hilo aparte.
- [ ] Barco de prueba generado por código (casco simple).
- [ ] Medir tiempo de remallado por chunk.

**Terminado cuando:** el barco de prueba se ve, un comando que cambia un voxel remalla solo su chunk, y el remallado de un chunk lleno tarda menos de 8 ms. Si no, se decide el port a GDExtension antes de seguir.

## Fase 3 — Modo construcción

- [ ] Cursor 3D que apunta a la cara del voxel bajo el mouse.
- [ ] Colocar y quitar voxels; elegir material.
- [ ] Simetría espejo (babor/estribor).
- [ ] Deshacer y rehacer con la pila de comandos.
- [ ] Herramientas de relleno: línea y caja.
- [ ] Suavizado visual de bordes (surface nets o biselado en el mesher).

**Terminado cuando:** puedes construir un casco de bote en menos de 5 minutos y deshacer cada paso.

## Fase 4 — Flotabilidad desde voxels

- [ ] Masa y centro de gravedad calculados desde los materiales.
- [ ] Flood fill desde el exterior para detectar aire interior estanco.
- [ ] Puntos de flotabilidad en celdas de 1 m (2×2×2 voxels).
- [ ] Amortiguación lineal y angular en el agua.
- [ ] Inundación: un compartimento con brecha bajo el agua se llena con el tiempo.
- [ ] Visualización de depuración: línea de flotación, centro de gravedad, compartimentos.

**Terminado cuando:** un casco cerrado flota, una balsa plana flota baja, un barco con peso arriba escora, y quitar voxels bajo la línea de flotación hunde ese lado.

## Fase 5 — Navegación

- [ ] Viento global con dirección y fuerza que cambian lento.
- [ ] Pieza vela: fuerza según superficie y ángulo con el viento.
- [ ] Pieza timón: torque proporcional a la velocidad.
- [ ] Resistencia del casco según su forma frontal.
- [ ] Ancla.
- [ ] Cámara de navegación en tercera persona.

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

- Océano FFT (se evalúa después de la rebanada vertical).
- Mundo procedural infinito.
- Tripulación controlada por IA.
- Versión móvil.
