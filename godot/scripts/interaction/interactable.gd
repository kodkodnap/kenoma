class_name Interactable
extends Area3D
## Zona que el jugador puede enfocar y accionar con E o clic.

signal activated(source: Interactable)
signal focus_changed(focused: bool)

@export var prompt: String = "Usar"
@export var hold_time: float = 0.0
@export var enabled: bool = true

var focused: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0


func set_focused(value: bool) -> void:
	if focused == value:
		return
	focused = value
	focus_changed.emit(value)


func activate() -> void:
	if enabled:
		activated.emit(self)
