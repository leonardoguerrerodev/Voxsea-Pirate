# Voxsea Pirate

Juego 3D de supervivencia naval hecho en Godot 4. Construyes tu barco bloque a bloque, navegas un mar con olas reales, pescas y combates a cañonazos contra los Abisales, los monstruos que despertaron con la Gran Crecida.

El barco es tu personaje. No mejoras al pirata: mejoras el barco.

## Estado

Fases 0 a 5 listas: océano, barco voxel que flota y se inunda, modo construcción en primera persona y navegación a vela.

Controles: WASD, espacio, Shift, C · E timón (A/D timón, W/S velas, R ancla) · B construir (dique seco) · clic izq./der. poner/quitar · T herramienta · 1-6 material · 7-0 piezas (vela chica, vela grande, timón, ancla) · M espejo · Ctrl+Z/Y · Q brújula · F3 depuración · F1 ayuda · Esc pausa (con menú Dev para ajustar tiempo, clima, viento, mar, barco y jugador).

Arriba a la derecha: coordenadas de mapa (X este, Y norte, en metros) y rumbo de la mirada. El concepto, el lore y el plan están en `docs/`.

## Documentación

- [`docs/concepto.md`](docs/concepto.md): ciclo de juego, reglas de diseño y sistemas.
- [`docs/lore.md`](docs/lore.md): mundo, zonas, personajes y Abisales.
- [`docs/plan.md`](docs/plan.md): plan de ejecución por fases.
- [`CLAUDE.md`](CLAUDE.md): contexto técnico para sesiones con Claude Code.

## Requisitos

- Godot 4.7.2 estable (edición estándar, no .NET).
- Git LFS. Ejecuta `git lfs install` una vez antes de clonar: los binarios de Voxel Tools (`addons/zylann.voxel/bin/`), modelos, texturas y audio van por LFS. Las extensiones que van por LFS están en `.gitattributes`.

## Cómo abrir

1. Clona el repo.
2. En Godot, usa Importar y elige `project.godot`.

## Créditos

- [Voxel Tools](https://github.com/Zylann/godot_voxel) — Zylann, MIT.
- [Quality First Person Controller](https://github.com/ColormaticStudios/quality-godot-first-person-2) — Colormatic Studios, MIT.
- [Sky3D](https://github.com/TokisanGames/Sky3D) — TokisanGames y contribuidores, MIT.
- Textura de la Vía Láctea de Sky3D: "[The Milky Way panorama](https://www.eso.org/public/images/eso0932a/)" por ESO/S. Brunier, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
