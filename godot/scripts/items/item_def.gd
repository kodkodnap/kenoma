class_name ItemDef
extends Resource
## Datos de un objeto. El mundo y el inventario solo leen este recurso.

@export var id: StringName = &""
@export var display_name: String = "Objeto"
@export var category: StringName = &"misc"
@export_range(0.0, 100.0, 0.1) var volume: float = 1.0
@export var price: int = 0
@export var model: PackedScene
