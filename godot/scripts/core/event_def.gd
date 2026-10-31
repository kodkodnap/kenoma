class_name EventDef
extends Resource
## Datos base de un evento. Las condiciones y acciones llegan en el hito 10/13.

@export var id: StringName = &""
@export var display_name: String = "Evento"
@export var weight: float = 1.0
@export var min_day: int = 1
@export var max_day: int = 999
@export var duration: float = 0.0
@export var once: bool = false
