# Decisiones

## 2026-10-01 — Barco: casco fijo modelado, sin voxels en tiempo de juego

**Estado:** DECISIÓN (ratificada por Leo, 2026-10-01).

**Contexto:** el barco era una grilla voxel construible (fases 2–4). Se probó un
casco modelado (Tripo) con la física voxel invisible y funcionó (commit `fac9d9d`),
pero Leo prefiere enfocar el proyecto en combate, pesca, cocina y decoración, al
estilo Sea of Thieves. UN-SOLO-SENTIDO en diseño (cambia el pitch y el lore de
"construir el barco"); el código voxel queda recuperable desde `fac9d9d`.

**Decisión:** cascos fijos modelados. Se eliminan la grilla editable, el mesher
(Voxel Tools), la hidrostática por voxels, la inundación por compartimentos y el
constructor. La flotación usa celdas de 1 m precalculadas una sola vez desde el
modelo (`tools/hull_to_grid.py`), la colisión sale de la malla, y las piezas
(vela, timón, ancla, carga) son nodos `ShipPart`.

**Se pierde:** inundación por compartimentos, construir el casco, consecuencias
físicas de la forma. **Se gana:** ~1.500 líneas y una dependencia menos; combate,
coop y varios barcos mucho más simples.

**Steelman de lo descartado:** "construyes tu barco y la física te juzga" era el
gancho diferenciador y ya funcionaba.

**Reversión:** se reabre si en la rebanada vertical el barco fijo se siente sin
progresión (nada que mejorar en él). Volver = partir de `fac9d9d`.
