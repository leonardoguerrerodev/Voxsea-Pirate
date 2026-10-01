# Voxsea Pirate — contexto del proyecto

Archivo de contexto para sesiones con Claude Code. Léelo completo antes de tocar código. Actualiza el roadmap y el pie al cerrar cada sesión.

## 👤 Usuario

Leonardo (Obsi). Desarrollador solo, autodidacta, estudiante de Ingeniería en Informática. Trabaja en español.

## 📍 Estado actual y cómo seguir (2026-10-01)

Hecho: fases 0 a 5 (océano Gerstner, barco voxel con Voxel Tools, flotabilidad e inundación, modo construcción en primera persona, navegación a vela) más coordenadas de mapa, brújula, ciclo día/noche (Sky3D), clima conectado a viento y olas, y menú dev. 10 tests en verde. Todo desarrollado en el MacPro (Ivy Bridge, renders a 480×270).

**Retomar en otro equipo (p. ej. el Nobara, 2560×1440):**
1. `git lfs install` y clonar `leonardoguerrerodev/Voxsea-Pirate` dentro de `~/Documentos/!GitHub/!Obsedium/`.
2. Poner el ejecutable de **Godot 4.7.2 estable (estándar, no .NET)** en `!Obsedium/Godot_v4.7.2-stable_linux.x86_64` (los comandos de este archivo usan `../` desde el repo). Opcional: symlink dentro del repo (ignorado por git).
3. No crear `override.cfg`: ese archivo achica la ventana solo en el Mac.
4. Importar una vez: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import`.
5. Correr los tests (ver "Tests" abajo): los 10 deben dar OK.
6. Jugar y medir: `../Godot_v4.7.2-stable_linux.x86_64 --path . --print-fps`.

**Pendientes inmediatos:**
- Medir FPS en el Nobara a 1440p y 1080p (en el Mac: 17 fps a 480×270; Sky3D y el mar son lo más caro). Si falta, menú dev → Gráficos.
- Pruebas a mano que ningún test cubre: construir un casco de bote en menos de 5 min (fase 3), sensación de navegación (`ShipRig.sail_scale`), brillo de la noche, editar `default_waves.tres` en el inspector remoto (fase 1).
- Fase 5: falta la estela (espuma persistente).
- Siguiente fase del plan: **6 — Cañones y daño**.
- Riesgos abiertos: tabla "Riesgos y problemas conocidos" al final.

## 🎯 Objetivo

Juego 3D de supervivencia naval con humor, en primera persona. Construcción voxel del barco al estilo Enshrouded, mar realista, pesca y combate a cañonazos contra monstruos marinos. Un jugador primero; cooperativo online después, sin reescribir la base.

## 📦 Stack

| Componente | Elección |
|---|---|
| Motor | Godot 4.7.2 estable, renderer Forward+ (ejecutable en `../Godot_v4.7.2-stable_linux.x86_64`) |
| Lenguaje | GDScript con tipado estático. C++ (GDExtension) solo si el mesher no rinde |
| Física | Jolt Physics (integrado en Godot) |
| Océano | Olas de Gerstner en shader + misma fórmula en CPU. FFT más adelante |
| Voxels | Datos propios (`ShipData`); mallado con `VoxelMesherCubes` (greedy) de Voxel Tools de Zylann, GDExtension v1.7x en `addons/zylann.voxel/` (solo binarios Linux x86_64; otras plataformas se agregan desde el zip del release al exportar). Chunks de 16³, voxel de 0,5 m |
| Jugador | Primera persona: Quality First Person Controller (Colormatic, MIT), adaptado a cubierta móvil |
| Cielo | Sky3D v2.1.0 (TokisanGames, MIT; `addons/sky_3d`): sol, luna, estrellas, nubes, niebla. Su reloj va apagado: lo maneja `Game.hour` vía `WeatherView` |
| Clima | Propio: autoload `Weather` (estados que escalan viento y olas) + `WeatherView` (Sky3D y lluvia) |
| Versiones | Git + Git LFS, repo privado en GitHub |

| Convención | Valor |
|---|---|
| Identificadores de código | Inglés (`ShipData`, `get_wave_height`) |
| Comentarios y docs | Español |
| Unidades de física | Metros, kilogramos, segundos |
| Coordenadas de mapa | `MapCoords` (world/): X = este (+x), Y = norte (-z), en metros; rumbo en grados desde el norte, horario. Toda conversión mundo ↔ mapa pasa por ahí. Ojo: `Vector2.UP` de Godot es (0, -1); el norte del mapa es `Vector2(0, 1)` |
| Resolución | Base 1920×1080 con estiramiento `canvas_items`/`expand`: la UI se diseña en 1080p y escala; el 3D va a resolución nativa. Objetivos: 1080p y 1440p (Nobara) |
| Tamaño de voxel | 0,5 m |
| Grilla máxima del barco | 64 × 32 × 128 voxels (32 × 16 × 64 m) |

## ⚠️ Reglas críticas

1. **La altura del mar sale de una sola fuente.** `ocean/ocean.gdshader` y `WaveSettings.get_wave_height(x, z, t)` en CPU usan la misma fórmula y los mismos parámetros (`ocean/default_waves.tres`). Si divergen, el barco flota sobre una ola que no se ve.
2. **Toda edición del barco es un comando.** Nada escribe en `ShipData` directo; todo pasa por `ShipEditCommand` → `ShipEditor.apply()`. En coop, esos comandos viajan por red.
3. **La simulación no conoce la presentación.** `ShipData`, la flotabilidad y la IA no referencian nodos visuales. La presentación escucha señales.
4. **La flotabilidad usa volumen desplazado.** Cuenta el casco más el aire interior seco. Aire interior = mirando abajo y a los 4 lados se choca con casco (así un bote sin cubierta tiene interior). El agua entra por las aberturas sumergidas de cada compartimento y sube hasta el nivel de afuera.
5. **El tiempo del mar es global.** CPU y GPU leen el mismo reloj (`Game.ocean_time`), nunca `Time` por separado.
6. **Ningún binario sin LFS.** Revisa `.gitattributes` antes de agregar un tipo de archivo nuevo.
7. **GDScript siempre tipado.** `var speed: float = 0.0`, funciones con tipo de retorno.
10. **Todo ajuste en vivo va al menú dev** (`ui/dev_menu.gd`): una línea por ajuste. Las perillas de calibración son `@export var`, no `const`.
9. **Las piezas funcionales son ids del catálogo** (`VoxelMaterial.part`): viajan en la misma grilla, así comandos, deshacer, espejo y guardado las cubren. Su base es un voxel; `ShipPartsView` dibuja lo demás.
8. **Quien camina sobre un barco es hijo del barco** y no toma velocidad de plataforma (`platform_floor_layers = 0`). La colisión detallada va en un `ShipDeck` (cinemático, cóncavo) hijo del `ShipBody`, que no tiene formas propias. Probado en `test_deck`: con velocidad de plataforma el movimiento se suma dos veces o el jugador atraviesa la malla.

## 🏗️ Estructura

```
res://
├── core/          # autoloads: Game (reloj del mar, hora del día), Events
├── sandbox/       # escena de pruebas (escena principal por ahora) y cámara orbital
├── ocean/         # WaveSettings (get_wave_height), shader Gerstner, OceanSurface, BuoyantBody
├── addons/        # zylann.voxel (Voxel Tools, binarios por LFS) fpc (Quality First Person Controller, MIT) y sky_3d (Sky3D, MIT); código ajeno, sin tipado estricto
├── ship/
│   ├── data/      # ShipData, ShipEditCommand, ShipEditor, VoxelMaterial, MaterialCatalog (materials.tres)
│   ├── mesh/      # ChunkMesher (Voxel Tools), ShipMesh + hull.gdshader (bisel), WaterMask, VoxelTexture
│   ├── physics/   # ShipHydrostatics (masa, compartimentos, inundación, celdas), ShipBody (RigidBody3D) y ShipDeck (colisión)
│   └── debug/     # vista F3: aire seco por compartimento y centro de gravedad
├── building/      # ShipBuilder (modo construcción) y BuildHistory (deshacer/rehacer)
├── player/        # Player (subclase del FPC: camina hacia la cámara, sube escalones de 1 voxel, reaparece), player.tscn y Compass (brújula en la mano, Q)
├── sailing/       # Wind (autoload, determinista), ShipRig (velas, timón, casco, ancla), HelmControl (E), ShipPartsView
├── combat/        # cañones, proyectiles, daño a voxels
├── creatures/     # Abisales y su IA
├── fishing/       # caña, red, arpón, tablas de peces
├── world/         # MapCoords, Weather (autoload), WeatherView; zonas, islas, ruinas, astillero
├── ui/            # game_ui.gd (ayuda F1, coordenadas, pausa Esc) y dev_menu.gd (botón Dev en la pausa), temporales
└── assets/        # modelos, texturas, audio (LFS)
tests/             # chequeos headless; corren dentro de tests/run.tscn
```

Las carpetas se crean cuando una fase las usa por primera vez (git no versiona carpetas vacías).

Verificación sin editor: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import` (importa y reporta errores de scripts). Los `*.gd.uid` que genera Godot se commitean.

Tests: `../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- <test>` con `test_ocean`, `test_ship`, `test_hydro`, `test_build`, `test_deck`, `test_step`, `test_sailing`, `test_map`, `test_compass` y `test_weather` (salen con código ≠ 0 si fallan). No usar `-s`: esos scripts compilan antes que los autoloads y cualquier clase que use `Game` falla. `run.tscn` también acepta una ruta `res://` (scripts de captura).

Equipos: el **Nobara** (2560×1440) es donde se mide rendimiento real (`--print-fps`). El **MacPro** se trabaja solo en baja resolución: su `override.cfg` local (ignorado por git) fuerza la ventana a 480×270. Nunca cambiar `viewport_width/height` para achicar la ventana: es la resolución base del juego. F3 = depuración del barco.

Render (headless no compila shaders): correr `run.tscn -- res://<script>.gd` sin `--headless` y guardar `get_viewport().get_texture().get_image()`. **En el MacPro (Ivy Bridge) siempre a `--resolution 480x270`**; el Nobara aguanta resoluciones altas.

Assets: se buscan en el Godot Asset Store (store.godotengine.org) y Leo elige antes de integrar. Descartado: Godot-MCP (exige Godot .NET y backend en la nube).

## 🔄 Flujo

```
Input ──► ShipEditCommand ──► ShipEditor.apply()
                                   │
                                   ▼
                              ShipData (simulación)
                                   │ señal changed(chunk)
                     ┌─────────────┼──────────────┐
                     ▼             ▼              ▼
               ChunkMesher    MassProperties   Compartments
             (presentación)   (masa, CoG)     (aire estanco)
                                   │              │
                                   └──────┬───────┘
                                          ▼
WaveSettings ──► get_wave_height() ──► Buoyancy ──► RigidBody3D
      │
      └────────► shader del mar (GPU)
```

## 🧩 Funcionalidades

| Sistema | Estado |
|---|---|
| Océano Gerstner | Hecho (fase 1): 8 ondas, falda de horizonte, flotabilidad por celdas |
| Datos voxel y mesher | Hecho (fase 2): ShipData + comandos + VoxelMesherCubes; 0,19 ms por chunk lleno |
| Modo construcción | Hecho (fase 3): primera persona, dique seco, voxel/línea/caja, espejo, deshacer, bisel |
| Flotabilidad e inundación | Hecho (fase 4): celdas de 1 m, compartimentos con aberturas, inundación por vasos comunicantes, máscara de agua |
| Navegación | Hecho (fase 5): viento, vela que se orienta sola, quilla, timón, ancla, tomar el timón con E |
| Cañones y daño | Pendiente |
| Abisales | Pendiente |
| Pesca | Pendiente |
| Astillero, economía, guardado | Pendiente |
| Zonas del mundo | Pendiente (día/noche y clima ya hechos) |
| Cooperativo | Pendiente |

## 🗺️ Roadmap

Detalle y criterios de "terminado" en `docs/plan.md`.

- [x] Fase 0 — Proyecto base (falta confirmar a mano que la cámara orbita)
- [x] Fase 1 — Océano y objeto flotante (falta probar a mano: editar `default_waves.tres` en el inspector remoto con el juego corriendo)
- [x] Fase 2 — Datos voxel y mesher
- [x] Fase 3 — Modo construcción (falta la prueba a mano: casco de bote en menos de 5 minutos)
- [x] Fase 4 — Flotabilidad desde voxels
- [x] Fase 5 — Navegación (falta la estela visual)
- [ ] Fase 6 — Cañones y daño
- [ ] Fase 7 — Primer Abisal
- [ ] Fase 8 — Pesca
- [ ] Hito: rebanada vertical jugable
- [ ] Fase 9 — Astillero, economía y guardado
- [ ] Fase 10 — Zonas del mundo
- [ ] Fase 11 — Cooperativo online

## 🔧 Riesgos y problemas conocidos

| Riesgo | Plan |
|---|---|
| Voxel Tools GDExtension "poco probada" (aviso del autor) | Solo usamos `VoxelBuffer` + `VoxelMesherCubes`, aislados en `ShipMesh`. Si falla, reemplazar ese archivo por un mesher propio; `ShipData` no depende del addon |
| Remallado en el hilo principal | Medido: 0,15–0,19 ms chunk realista, 6,6 ms peor caso (MacPro). Pasar a `WorkerThreadPool` si una edición grande se nota |
| Caminar sobre una cubierta que se mueve y cabecea | El controlador FPS hereda la velocidad del barco; se resuelve en fase 3/5 |
| Recalcular la hidrostática: 175 ms al salir del dique seco (grilla 32×24×64, MacPro) | Una vez por botadura, aceptable. Incremental si se vuelve a editar en el mar (reparaciones, fase 6) |
| La grilla del barco tiene tamaño fijo | Construir fuera de ella no hace nada; agrandar ShipData cuando un diseño lo pida |
| Jugador siempre hijo del barco | Reparentar al bajar a tierra o al agua. Hoy, si cae al agua, reaparece en la cubierta (no hay nado) |
| Flotabilidad: 2,3 ms por paso físico (casco de prueba, MacPro) | Columnas de 2 m para muestrear el mar; agrandarlas o bajar INVERT_STEPS si hay varios barcos |
| Máscara de agua: un barco por océano | Arreglo de transformaciones + atlas 3D cuando haya más barcos (Saqueadores, fase 10) |
| Fuerza de vela calibrada a ojo (`ShipRig.SAIL_SCALE` = 6, `DRAG_FORWARD`, `KEEL_LIFT`) | Los cascos de voxel pesan ~10× uno real. Ajustar jugando; `test_sailing` fija los mínimos |
| Piezas dibujadas con primitivas (mástil, vela, rueda, ancla) | Modelos cuando haya arte |
| Sky3D en el MacPro: 24 → 17 fps (las nubes son lo más caro) | Menú dev: apagar nubes/niebla o bajar la escala de render. En el Nobara medir |
| Lluvia: partículas con un "techo" de alturas que sigue a la cámara | Si se ve lluvia bajo techos chicos, subir la resolución del heightfield |
| Reloj del mar a 60 Hz (física) | En pantallas de más Hz las olas saltan levemente; interpolar si se nota |
| FFT requiere leer altura desde GPU | Gerstner hasta tener la física estable; FFT con readback asíncrono después |
| Muchos puntos de flotabilidad en barcos grandes | Muestreo en celdas de 1 m (2×2×2 voxels) y límite de puntos por barco |
| Física autoritativa en coop | Host simula; clientes reciben estado e interpolan. Se diseña en fase 11 |

## 🔗 Referencias

- Documentación de Godot 4: https://docs.godotengine.org
- Olas de Gerstner: GPU Gems, capítulo 1 ("Effective Water Simulation from Physical Models")
- Océano FFT: Tessendorf, "Simulating Ocean Water"

---

Última actualización: Sesión 2 (2026-10-01, MacPro) — Fases 0 a 5 + coordenadas, brújula, día/noche (Sky3D), clima y menú dev. Siguiente: medir en el Nobara y Fase 6.
