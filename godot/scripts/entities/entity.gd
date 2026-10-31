class_name Entity
extends Node3D
## Base vacía de entidad: activar, desactivar y recibir su definición.

signal active_changed(active: bool)

@export var definition: EntityDef
var active: bool = false


func setup(def: EntityDef) -> void:
	definition = def


func activate() -> void:
	if active:
		return
	active = true
	active_changed.emit(true)


func deactivate() -> void:
	if not active:
		return
	active = false
	active_changed.emit(false)
