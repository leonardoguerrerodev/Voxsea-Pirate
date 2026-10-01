# Voxsea Pirate — contexto del proyecto

Archivo de contexto para sesiones con Claude Code. Léelo completo antes de tocar código. Actualiza el roadmap y el pie al cerrar cada sesión.

## 👤 Usuario

Leonardo (Obsi). Desarrollador solo, autodidacta, estudiante de Ingeniería en Informática. Trabaja en español.

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
| Versiones | Git + Git LFS, repo privado en GitHub |

| Convención | Valor |
|---|---|
| Identificadores de código | Inglés (`ShipData`, `get_wave_height`) |
| Comentarios y docs | Español |
| Unidades de física | Metros, kilogramos, segundos |
| Tamaño de voxel | 0,5 m |
| Grilla máxima del barco | 64 × 32 × 128 voxels (32 × 16 × 64 m) |

## ⚠️ Reglas críticas

1. **La altura del mar sale de una sola fuente.** `ocean/ocean.gdshader` y `WaveSettings.get_wave_height(x, z, t)` en CPU usan la misma fórmula y los mismos parámetros (`ocean/default_waves.tres`). Si divergen, el barco flota sobre una ola que no se ve.
2. **Toda edición del barco es un comando.** Nada escribe en `ShipData` directo; todo pasa por `ShipEditCommand` → `ShipEditor.apply()`. En coop, esos comandos viajan por red.
3. **La simulación no conoce la presentación.** `ShipData`, la flotabilidad y la IA no referencian nodos visuales. La presentación escucha señales.
4. **La flotabilidad usa volumen desplazado.** Cuenta el casco más el aire interior estanco (detectado por flood fill desde el exterior). Un compartimento con brecha se inunda y deja de flotar.
5. **El tiempo del mar es global.** CPU y GPU leen el mismo reloj (`Game.ocean_time`), nunca `Time` por separado.
6. **Ningún binario sin LFS.** Revisa `.gitattributes` antes de agregar un tipo de archivo nuevo.
7. **GDScript siempre tipado.** `var speed: float = 0.0`, funciones con tipo de retorno.

## 🏗️ Estructura

```
res://
├── core/          # autoloads: Game, Events
├── sandbox/       # escena de pruebas (escena principal por ahora) y cámara orbital
├── ocean/         # WaveSettings (get_wave_height), shader Gerstner, OceanSurface, BuoyantBody
├── addons/        # zylann.voxel (Voxel Tools, binarios por LFS)
├── ship/
│   ├── data/      # ShipData, ShipEditCommand, ShipEditor, VoxelMaterial, MaterialCatalog (materials.tres)
│   ├── mesh/      # ShipMesh: una malla por chunk con VoxelMesherCubes
│   └── physics/   # flotabilidad, compartimentos, inundación
├── building/      # modo construcción, cursor, UI de bloques
├── sailing/       # velas, timón, viento
├── combat/        # cañones, proyectiles, daño a voxels
├── creatures/     # Abisales y su IA
├── fishing/       # caña, red, arpón, tablas de peces
├── world/         # zonas, islas, ruinas, astillero
├── ui/
└── assets/        # modelos, texturas, audio (LFS)
tests/             # chequeos headless (SceneTree), ver cabecera de cada uno
```

Las carpetas se crean cuando una fase las usa por primera vez (git no versiona carpetas vacías).

Verificación sin editor: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import` (importa y reporta errores de scripts). Los `*.gd.uid` que genera Godot se commitean.

Tests: `../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s res://tests/<test>.gd` con `test_ocean.gd` y `test_ship.gd` (salen con código ≠ 0 si fallan).

Render (headless no compila shaders): correr la escena con un script `-s` que guarde `root.get_texture().get_image()`. **En el MacPro (Ivy Bridge) siempre a `--resolution 480x270`**; el Nobara aguanta resoluciones altas.

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
| Modo construcción | Pendiente |
| Flotabilidad e inundación | Pendiente |
| Navegación | Pendiente |
| Cañones y daño | Pendiente |
| Abisales | Pendiente |
| Pesca | Pendiente |
| Astillero, economía, guardado | Pendiente |
| Zonas del mundo | Pendiente |
| Cooperativo | Pendiente |

## 🗺️ Roadmap

Detalle y criterios de "terminado" en `docs/plan.md`.

- [x] Fase 0 — Proyecto base (falta confirmar a mano que la cámara orbita)
- [x] Fase 1 — Océano y objeto flotante (falta probar a mano: editar `default_waves.tres` en el inspector remoto con el juego corriendo)
- [x] Fase 2 — Datos voxel y mesher
- [ ] Fase 3 — Modo construcción
- [ ] Fase 4 — Flotabilidad desde voxels
- [ ] Fase 5 — Navegación
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
| Reloj del mar a 60 Hz (física) | En pantallas de más Hz las olas saltan levemente; interpolar si se nota |
| FFT requiere leer altura desde GPU | Gerstner hasta tener la física estable; FFT con readback asíncrono después |
| Muchos puntos de flotabilidad en barcos grandes | Muestreo en celdas de 1 m (2×2×2 voxels) y límite de puntos por barco |
| Física autoritativa en coop | Host simula; clientes reciben estado e interpolan. Se diseña en fase 11 |

## 🔗 Referencias

- Documentación de Godot 4: https://docs.godotengine.org
- Olas de Gerstner: GPU Gems, capítulo 1 ("Effective Water Simulation from Physical Models")
- Océano FFT: Tessendorf, "Simulating Ocean Water"

---

Última actualización: Sesión 2 (2026-10-01) — Fases 0, 1 y 2: proyecto Godot 4.7.2 + Jolt, océano Gerstner propio con test, cubo flotante. Decidido: primera persona, Voxel Tools a prueba, Quality FPC. Fase 2: Voxel Tools aprobado (VoxelMesherCubes), ShipData/comandos/ShipMesh con test. Siguiente: Fase 3.
