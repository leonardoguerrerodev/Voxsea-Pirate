# Voxsea Pirate — contexto del proyecto

Archivo de contexto para sesiones con Claude Code. Léelo completo antes de tocar código. Actualiza el roadmap y el pie al cerrar cada sesión.

## 👤 Usuario

Leonardo (Obsi). Desarrollador solo, autodidacta, estudiante de Ingeniería en Informática. Trabaja en español.

## 📍 Estado actual y cómo seguir (2026-10-01)

Hecho: océano Gerstner, barco de casco fijo modelado (balandra de 20 m) que flota, navega y se camina, navegación a vela, coordenadas de mapa, brújula, ciclo día/noche (Sky3D), clima conectado a viento y olas, y menú dev (con interruptores gráficos: tonemapping/AgX, SSR, SSAO, SSIL, SDFGI, glow, niebla volumétrica), mar con ondas finas, destellos del sol, luz en las crestas y claridad ajustable, 27 props importados con íconos (cofre, caldero, estufa y barril armados con su parte móvil; 3 cañones), inventario (Tab) y decoración: colocar objetos del inventario en el barco (con masa), abrirlos (E) y recogerlos (F). 10 tests en verde. Las fases 2–4 (barco voxel construible) se reemplazaron el 2026-10-01: ver `docs/decisiones.md`; el código voxel queda en el commit `fac9d9d`.

**Retomar en otro equipo (p. ej. el Nobara, 2560×1440):**
1. `git lfs install` y clonar `leonardoguerrerodev/Voxsea-Pirate` dentro de `~/Documentos/!GitHub/!Obsedium/`.
2. Poner el ejecutable de **Godot 4.7.2 estable (estándar, no .NET)** en `!Obsedium/Godot_v4.7.2-stable_linux.x86_64` (los comandos de este archivo usan `../` desde el repo). Opcional: symlink dentro del repo (ignorado por git).
3. No crear `override.cfg`: ese archivo achica la ventana solo en el Mac.
4. Importar una vez: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import`.
5. Correr los tests (ver "Tests" abajo): los 10 deben dar OK.
6. Jugar y medir: `../Godot_v4.7.2-stable_linux.x86_64 --path . --print-fps`.

**Cascos (2026-10-01):** fijos y modelados, estilo Sea of Thieves. `tools/hull_to_grid.py` (Blender) toma un `.glb` (Tripo), lo orienta (proa a -z), escala, simetriza, alinea la cubierta con un borde de 0,5 m, lo pinta por pieza (`<casco>.materials.json`, texturas en `assets/textures/`) y escribe la malla + la ocupación `.grid` (1 = casco, 2 = aire interior). `HullProfile` calcula de ahí, una vez, masa, inercia y celdas de flotación; en juego no hay grilla. La colisión sale de la malla (`HullCollision`) y las piezas son nodos `ShipPart`. Los `.glb` crudos de Tripo viven en `models/` (fuera de git). Plan ejecutado: `docs/plan_sin_voxels.md`.

**Pendientes inmediatos:**
- Medir FPS en el Nobara a 1440p con cada interruptor de menú dev → Gráficos (base, SSR, SSAO, SSIL, SDFGI, AgX). El mar es transparente: SSR probablemente no lo refleja; evaluar reflejos propios del mar después.
- Balandra: abrir la escotilla y una escalera a la bodega; mástiles con modelo (verga, mástiles y cofa de la primera hoja de utilería).
- Props: un material por prop (Tripo los entregó en una sola malla); los de varios materiales (cofre con fierro, botella de vidrio) piden reexportar "por piezas" o pintar a mano. Falta la tela de la hamaca (plano curvo con lona, como la vela).
- Inventario: falta de dónde salen los objetos (pesca, cocina, botín) y guardar la partida (lo colocado y el inventario se pierden al salir).
- Cañones: hoy son decoración (tubo y cureña fundidos en una malla). Para disparar y apuntar hace falta el tubo aparte: pasar la hoja de piezas de cañones por Tripo "por piezas".
- Pruebas a mano que ningún test cubre: sensación de navegación (`ShipRig.sail_scale`), brillo de la noche, editar `default_waves.tres` en el inspector remoto (fase 1).
- Fase 5: falta la estela (espuma persistente).
- Siguiente: **combate** al estilo Sea of Thieves (cañones, agujeros en el punto de impacto, nivel de agua por barco, balde y tablones); después pesca, cocina y decoración.
- Riesgos abiertos: tabla "Riesgos y problemas conocidos" al final.

## 🎯 Objetivo

Juego 3D de supervivencia naval con humor, en primera persona. Barcos de casco fijo al estilo Sea of Thieves que se decoran y equipan por dentro, mar realista, pesca, cocina y combate a cañonazos contra monstruos marinos. Un jugador primero; cooperativo online después, sin reescribir la base.

## 📦 Stack

| Componente | Elección |
|---|---|
| Motor | Godot 4.7.2 estable, renderer Forward+ (ejecutable en `../Godot_v4.7.2-stable_linux.x86_64`) |
| Lenguaje | GDScript con tipado estático. C++ (GDExtension) solo si algo medido no rinde |
| Física | Jolt Physics (integrado en Godot) |
| Océano | Olas de Gerstner en shader + misma fórmula en CPU. FFT más adelante |
| Casco | Modelo `.glb` + perfil de flotación precalculado (`HullProfile`, desde la ocupación en voxels de 0,5 m que deja `tools/hull_to_grid.py`). Colisión cóncava desde la malla (`HullCollision`) |
| Jugador | Primera persona: Quality First Person Controller (Colormatic, MIT), adaptado a cubierta móvil |
| Cielo | Sky3D v2.1.0 (TokisanGames, MIT; `addons/sky_3d`): sol, luna, estrellas, nubes, niebla. Su reloj va apagado: lo maneja `Game.hour` vía `WeatherView` |
| Clima | Propio: autoload `Weather` (estados que escalan viento y olas) + `WeatherView` (Sky3D y lluvia) |
| Versiones | Git + Git LFS, repo privado en GitHub |

| Convención | Valor |
|---|---|
| Identificadores de código | Inglés (`HullProfile`, `get_wave_height`) |
| Comentarios y docs | Español |
| Unidades de física | Metros, kilogramos, segundos |
| Coordenadas de mapa | `MapCoords` (world/): X = este (+x), Y = norte (-z), en metros; rumbo en grados desde el norte, horario. Toda conversión mundo ↔ mapa pasa por ahí. Ojo: `Vector2.UP` de Godot es (0, -1); el norte del mapa es `Vector2(0, 1)` |
| Resolución | Base 1920×1080 con estiramiento `canvas_items`/`expand`: la UI se diseña en 1080p y escala; el 3D va a resolución nativa. Objetivos: 1080p y 1440p (Nobara) |
| Ocupación del casco (offline) | Voxels de 0,5 m; celdas de flotación de 1 m |

## ⚠️ Reglas críticas

1. **La altura del mar sale de una sola fuente.** `ocean/ocean.gdshader` y `WaveSettings.get_wave_height(x, z, t)` en CPU usan la misma fórmula y los mismos parámetros (`ocean/default_waves.tres`). Si divergen, el barco flota sobre una ola que no se ve.
2. **El casco no se edita en juego.** Su perfil físico (`HullProfile`) se calcula una vez al cargar; lo que cambia (piezas, carga, daño) son nodos `ShipPart` o estado del `ShipBody`, nunca la ocupación.
3. **La simulación no conoce la presentación.** `HullProfile`, la flotabilidad y la IA no referencian nodos visuales. La presentación escucha señales.
4. **La flotabilidad usa volumen desplazado.** Cuenta el casco más el aire interior (la bodega), por celdas de 1 m. El aire interior lo calcula `tools/hull_to_grid.py`: lo que el aire de afuera no alcanza sin cruzar casco.
5. **El tiempo del mar es global.** CPU y GPU leen el mismo reloj (`Game.ocean_time`), nunca `Time` por separado.
6. **Ningún binario sin LFS.** Revisa `.gitattributes` antes de agregar un tipo de archivo nuevo.
7. **GDScript siempre tipado.** `var speed: float = 0.0`, funciones con tipo de retorno.
10. **Todo ajuste en vivo va al menú dev** (`ui/dev_menu.gd`): una línea por ajuste. Las perillas de calibración son `@export var`, no `const`.
9. **Las piezas son nodos `ShipPart` hijos del `ShipBody`** (vela, timón, ancla o carga con masa). Su posición es la base sobre la cubierta: se mide con un rayo contra la colisión del casco, nunca a ojo. Su masa suma al barco; `ShipPartsView` las dibuja.
8. **Quien camina sobre un barco es hijo del barco** y no toma velocidad de plataforma (`platform_floor_layers = 0`). La colisión detallada va en un `HullCollision` (cinemático, cóncavo, desde la malla) hijo del `ShipBody`, que no tiene formas propias. Probado en `test_deck`: con velocidad de plataforma el movimiento se suma dos veces o el jugador atraviesa la malla.

## 🏗️ Estructura

```
res://
├── core/          # autoloads: Game (reloj del mar, hora del día), Events
├── sandbox/       # escena de pruebas (escena principal por ahora) y cámara orbital
├── ocean/         # WaveSettings (get_wave_height), shader Gerstner, OceanSurface, BuoyantBody
├── addons/        # fpc (Quality First Person Controller, MIT) y sky_3d (Sky3D, MIT); código ajeno, sin tipado estricto
├── ship/
│   ├── hull/      # HullProfile (masa, inercia, celdas de flotación desde la ocupación .grid)
│   ├── mesh/      # WaterMask (el mar no se dibuja en la bodega)
│   ├── physics/   # ShipBody (RigidBody3D) y HullCollision (colisión desde la malla)
│   └── debug/     # vista F3: centro de gravedad
├── player/        # Player (subclase del FPC: camina hacia la cámara, sube escalones de 0,5 m, reaparece), player.tscn y Compass (brújula en la mano, Q)
├── sailing/       # Wind (autoload, determinista), ShipRig (velas, timón, casco, ancla), ShipPart, HelmControl (E), ShipPartsView, sail.gdshader
├── combat/        # cañones, proyectiles, agujeros y fugas
├── creatures/     # Abisales y su IA
├── fishing/       # caña, red, arpón, tablas de peces
├── world/         # MapCoords, Weather (autoload), WeatherView; zonas, islas, ruinas, astillero
├── tools/         # hull_to_grid.py (casco → malla pintada + ocupación), props_import.py (hoja de Tripo → un .glb por prop, según assets/props/*.json) y render_icons.gd (íconos desde los props)
├── items/         # ItemData (recurso, con masa y modelo), Inventory (casillas apilables) y data/*.tres (un objeto por archivo)
├── props/         # OpenableProp: props de dos piezas armados (base + tapa/puerta con bisagra o que se levanta)
├── decor/         # DecorPlacer (colocar, abrir con E, recoger con F) y DecorPiece (objeto colocado: ShipPart con masa y colisión)
├── ui/            # game_ui.gd (ayuda F1, coordenadas, pausa Esc), dev_menu.gd (botón Dev en la pausa) e inventory_ui.gd (Tab)
└── assets/        # ships/, props/ (+ specs .json), icons/, textures/ (paleta de 16 materiales de 512 px); todo por LFS
tests/             # chequeos headless; corren dentro de tests/run.tscn
```

Las carpetas se crean cuando una fase las usa por primera vez (git no versiona carpetas vacías).

Verificación sin editor: `../Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import` (importa y reporta errores de scripts). Los `*.gd.uid` que genera Godot se commitean.

Tests: `../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- <test>` con `test_ocean`, `test_hull`, `test_deck`, `test_step`, `test_sailing`, `test_map`, `test_compass`, `test_weather`, `test_inventory` y `test_decor` (salen con código ≠ 0 si fallan). No usar `-s`: esos scripts compilan antes que los autoloads y cualquier clase que use `Game` falla. `run.tscn` también acepta una ruta `res://` (scripts de captura).

Equipos: el **Nobara** (2560×1440) es donde se mide rendimiento real (`--print-fps`). El **MacPro** se trabaja solo en baja resolución: su `override.cfg` local (ignorado por git) fuerza la ventana a 480×270. Nunca cambiar `viewport_width/height` para achicar la ventana: es la resolución base del juego. F3 = centro de gravedad del barco.

Render (headless no compila shaders): correr `run.tscn -- res://<script>.gd` sin `--headless` y guardar `get_viewport().get_texture().get_image()`. **En el MacPro (Ivy Bridge) siempre a `--resolution 480x270`**; el Nobara aguanta resoluciones altas.

Assets: se buscan en el Godot Asset Store (store.godotengine.org) y Leo elige antes de integrar. Modelos propios: hojas de imágenes (ChatGPT/Canva) → Tripo (exportar por piezas; hojas de ≤ 13 objetos, con más funde y omite) → `models/` (fuera de git, con `.gdignore`) → `tools/props_import.py`. Los modelos crudos no traen buena textura: se pintan con la paleta de `assets/textures/`. Descartado: Godot-MCP (exige Godot .NET y backend en la nube).

## 🔄 Flujo

```
tools/hull_to_grid.py (Blender, offline) ──► <casco>.glb + <casco>.grid
                                                 │           │
                                     HullCollision (malla)   HullProfile (masa, celdas)
                                                 │           │
ShipPart (vela, timón, ancla, carga) ──────────► ShipBody ◄──┘
                                                 ▲
WaveSettings ──► get_wave_height() ──► flotación ┘   ShipRig (vela, timón, casco)
      │
      └────────► shader del mar (GPU) ◄── WaterMask (bodega)
```

## 🧩 Funcionalidades

| Sistema | Estado |
|---|---|
| Océano Gerstner | Hecho (fase 1): 8 ondas, falda de horizonte, flotabilidad por celdas |
| Casco fijo modelado | Hecho (reemplaza fases 2–4): balandra de 20 m pintada por pieza, flotación por celdas de 1 m, colisión desde la malla, máscara de agua en la bodega |
| Navegación | Hecho (fase 5): viento, vela que se orienta sola, quilla, timón, ancla, tomar el timón con E |
| Cañones y daño (agujeros, nivel de agua, balde, tablones) | Pendiente |
| Abisales | Pendiente |
| Pesca | Pendiente |
| Cocina | Pendiente |
| Decoración (props con masa) | Pendiente |
| Astillero, economía, guardado | Pendiente |
| Zonas del mundo | Pendiente (día/noche y clima ya hechos) |
| Cooperativo | Pendiente |

## 🗺️ Roadmap

Detalle y criterios de "terminado" en `docs/plan.md`; lista viva de lo que falta en `docs/pendientes.md`.

- [x] Fase 0 — Proyecto base (falta confirmar a mano que la cámara orbita)
- [x] Fase 1 — Océano y objeto flotante (falta probar a mano: editar `default_waves.tres` en el inspector remoto con el juego corriendo)
- [x] Fases 2–4 — Barco voxel construible (hecho y reemplazado por casco fijo modelado, 2026-10-01; ver `docs/decisiones.md`)
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
| Modelos de Tripo en plan gratis: licencia no comercial (sin confirmar en la página oficial). `assets/ships/sloop/sloop.glb` deriva de uno | Antes de vender: plan pago de Tripo o rehacer los modelos en Blender |
| Jugador siempre hijo del barco | Reparentar al bajar a tierra o al agua. Hoy, si cae al agua, reaparece en la cubierta (no hay nado) |
| Flotabilidad: 2,3 ms por paso físico (casco de prueba, MacPro) | Columnas de 2 m para muestrear el mar; agrandarlas o bajar INVERT_STEPS si hay varios barcos |
| Máscara de agua: un barco por océano | Arreglo de transformaciones + atlas 3D cuando haya más barcos (Saqueadores, fase 10) |
| Fuerza de vela calibrada a ojo (`ShipRig.sail_scale` = 6, `drag_forward`, `keel_lift`) | El casco pesa como madera maciza de 0,5 m (~10× uno real; balandra: 223 t). Ajustar jugando; `test_sailing` fija los mínimos |
| Piezas dibujadas con primitivas (mástil, rueda, ancla; la vela ya tiene lona) | Modelos de las hojas de piezas separadas (Tripo) |
| Sky3D en el MacPro: 24 → 17 fps (las nubes son lo más caro) | Menú dev: apagar nubes/niebla o bajar la escala de render. En el Nobara medir |
| Lluvia: partículas con un "techo" de alturas que sigue a la cámara | Si se ve lluvia bajo techos chicos, subir la resolución del heightfield |
| Reloj del mar a 60 Hz (física) | En pantallas de más Hz las olas saltan levemente; interpolar si se nota |
| FFT requiere leer altura desde GPU | Gerstner hasta tener la física estable; FFT con readback asíncrono después |
| Muchas celdas de flotación en barcos grandes (balandra: 1023) | Celdas más grandes para barcos lejanos o enemigos |
| Física autoritativa en coop | Host simula; clientes reciben estado e interpolan. Se diseña en fase 11 |

## 🔗 Referencias

- Documentación de Godot 4: https://docs.godotengine.org
- Olas de Gerstner: GPU Gems, capítulo 1 ("Effective Water Simulation from Physical Models")
- Océano FFT: Tessendorf, "Simulating Ocean Water"

---

Última actualización: Sesión 3 (2026-10-01, Nobara) — Sin voxels en juego (casco fijo con `HullProfile`, `HullCollision`, `ShipPart`); mar más translúcido con ondas finas, destellos y luz en las crestas; paleta de texturas y balandra repintada; 27 props (con piezas armadas y cañones) e íconos; inventario (Tab) y decoración; 10 tests en verde. Siguiente: medir FPS, escotilla y bodega, guardado; después combate (con cañones por piezas).
