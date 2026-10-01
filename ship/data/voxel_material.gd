class_name VoxelMaterial
extends Resource
## Material de construcción. Su id es su índice en el MaterialCatalog.

@export var display_name: String = ""
## Densidad del voxel lleno. El agua es 1000: más liviano flota.
@export_range(10.0, 10000.0, 1.0, "suffix:kg/m³") var density: float = 500.0
## Daño que aguanta un voxel antes de romperse.
@export_range(0.1, 20.0, 0.1) var resistance: float = 1.0
@export var color: Color = Color.WHITE
