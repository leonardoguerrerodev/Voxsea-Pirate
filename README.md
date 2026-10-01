# Voxsea Pirate

Juego 3D de supervivencia naval hecho en Godot 4. Construyes tu barco bloque a bloque, navegas un mar con olas reales, pescas y combates a cañonazos contra los Abisales, los monstruos que despertaron con la Gran Crecida.

El barco es tu personaje. No mejoras al pirata: mejoras el barco.

## Estado

Fases 0 a 4 listas: océano, barco voxel que flota y se inunda, y modo construcción en primera persona.

Controles: WASD, espacio, Shift, C · B construir (dique seco) · clic izq./der. poner/quitar · T herramienta · 1-6 material · M espejo · Ctrl+Z/Y · F3 depuración · F1 ayuda · Esc pausa. El concepto, el lore y el plan están en `docs/`.

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
