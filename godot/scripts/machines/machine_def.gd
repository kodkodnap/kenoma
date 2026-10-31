class_name MachineDef
extends Resource
## Datos de una máquina. Los valores viven en .tres, no en el script.

@export var display_name: String = "Máquina"
@export var max_heat: float = 100.0
@export var restart_heat: float = 30.0
@export var cool_per_second: float = 8.0
@export var heat_per_second: PackedFloat32Array = PackedFloat32Array([5.0, 9.0, 14.0])
@export var power_draw_w: PackedFloat32Array = PackedFloat32Array([400.0, 800.0, 1400.0])
@export var mode_names: PackedStringArray = PackedStringArray(["BAJA", "MEDIA", "ALTA"])
