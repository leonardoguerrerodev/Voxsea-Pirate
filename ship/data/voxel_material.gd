class_name VoxelMaterial
extends Resource
## Material de construcción o pieza funcional. Su id es su índice en el
## MaterialCatalog. Una pieza ocupa una celda como un voxel (su base) y la capa
## visual le agrega lo demás (mástil y vela, rueda, ancla).

enum Part { NONE, SAIL, HELM, ANCHOR }

@export var display_name: String = ""
## Densidad del voxel lleno. El agua es 1000: más liviano flota. En una pieza,
## masa total = densidad · 0,125 m³.
@export_range(10.0, 10000.0, 1.0, "suffix:kg/m³") var density: float = 500.0
## Daño que aguanta un voxel antes de romperse.
@export_range(0.1, 20.0, 0.1) var resistance: float = 1.0
@export var color: Color = Color.WHITE
@export var part: Part = Part.NONE
## Solo velas: superficie de lona y alto del mástil.
@export_range(0.0, 400.0, 1.0, "suffix:m²") var sail_area: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var mast_height: float = 0.0
