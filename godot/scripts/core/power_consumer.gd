class_name PowerConsumer
extends Node
## Carga conectada a una red. La red decide si recibe energía.

signal power_changed(powered: bool)
signal draw_changed

@export var draw_w: float = 0.0:
	set(value):
		if is_equal_approx(draw_w, value):
			return
		draw_w = value
		draw_changed.emit()

var powered: bool = false:
	set(value):
		if powered == value:
			return
		powered = value
		power_changed.emit(value)
