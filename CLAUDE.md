# Voxsea Pirate — contexto del proyecto

Archivo de contexto para sesiones con Claude Code. Léelo completo antes de tocar código. Actualiza el roadmap y el pie al cerrar cada sesión.

## 👤 Usuario

Leonardo (Obsi). Desarrollador solo, autodidacta, estudiante de Ingeniería en Informática. Trabaja en español.

## 🎯 Objetivo

Juego 3D de supervivencia naval con humor. Construcción voxel del barco al estilo Enshrouded, mar realista, pesca y combate a cañonazos contra monstruos marinos. Un jugador primero; cooperativo online después, sin reescribir la base.

## 📦 Stack

| Componente | Elección |
|---|---|
| Motor | Godot 4.x estable, renderer Forward+ |
| Lenguaje | GDScript con tipado estático. C++ (GDExtension) solo si el mesher no rinde |
| Física | Jolt Physics (integrado en Godot) |
| Océano | Olas de Gerstner en shader + misma fórmula en CPU. FFT más adelante |
| Voxels | Mesher propio, chunks de 16³, voxel de 0,5 m |
| Versiones | Git + Git LFS, repo privado en GitHub |

| Convención | Valor |
|---|---|
| Identificadores de código | Inglés (`ShipData`, `get_wave_height`) |
| Comentarios y docs | Español |
| Unidades de física | Metros, kilogramos, segundos |
| Tamaño de voxel | 0,5 m |
| Grilla máxima del barco | 64 × 32 × 128 voxels (32 × 16 × 64 m) |

## ⚠️ Reglas críticas

1. **La altura del mar sale de una sola fuente.** El shader y `Ocean.get_wave_height(x, z, t)` en CPU usan la misma fórmula y los mismos parámetros (`WaveSettings`). Si divergen, el barco flota sobre una ola que no se ve.
2. **Toda edición del barco es un comando.** Nada escribe en `ShipData` directo; todo pasa por `ShipEditCommand` → `ShipEditor.apply()`. En coop, esos comandos viajan por red.
3. **La simulación no conoce la presentación.** `ShipData`, la flotabilidad y la IA no referencian nodos visuales. La presentación escucha señales.
4. **La flotabilidad usa volumen desplazado.** Cuenta el casco más el aire interior estanco (detectado por flood fill desde el exterior). Un compartimento con brecha se inunda y deja de flotar.
5. **El tiempo del mar es global.** CPU y GPU leen el mismo reloj (`Game.ocean_time`), nunca `Time` por separado.
6. **Ningún binario sin LFS.** Revisa `.gitattributes` antes de agregar un tipo de archivo nuevo.
7. **GDScript siempre tipado.** `var speed: float = 0.0`, funciones con tipo de retorno.

## 🏗️ Estructura

```
res://
├── core/          # autoloads: Game, Events, WaveSettings
├── ocean/         # shader Gerstner, malla del mar, get_wave_height
├── ship/
│   ├── data/      # ShipData, VoxelMaterial, ShipEditCommand
│   ├── mesh/      # mesher por chunk (greedy / surface nets)
│   └── physics/   # flotabilidad, compartimentos, inundación
├── building/      # modo construcción, cursor, UI de bloques
├── sailing/       # velas, timón, viento
├── combat/        # cañones, proyectiles, daño a voxels
├── creatures/     # Abisales y su IA
├── fishing/       # caña, red, arpón, tablas de peces
├── world/         # zonas, islas, ruinas, astillero
├── ui/
└── assets/        # modelos, texturas, audio (LFS)
```

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
| Océano Gerstner | Pendiente |
| Datos voxel y mesher | Pendiente |
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

- [ ] Fase 0 — Proyecto base
- [ ] Fase 1 — Océano y objeto flotante
- [ ] Fase 2 — Datos voxel y mesher
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
| Mesher en GDScript demasiado lento | Medir en fase 2. Si remallar un chunk pasa de 8 ms, portar a GDExtension |
| FFT requiere leer altura desde GPU | Gerstner hasta tener la física estable; FFT con readback asíncrono después |
| Muchos puntos de flotabilidad en barcos grandes | Muestreo en celdas de 1 m (2×2×2 voxels) y límite de puntos por barco |
| Física autoritativa en coop | Host simula; clientes reciben estado e interpolan. Se diseña en fase 11 |

## 🔗 Referencias

- Documentación de Godot 4: https://docs.godotengine.org
- Olas de Gerstner: GPU Gems, capítulo 1 ("Effective Water Simulation from Physical Models")
- Océano FFT: Tessendorf, "Simulating Ocean Water"

---

Última actualización: Sesión 1 — concepto, lore y plan definidos; repo creado.
