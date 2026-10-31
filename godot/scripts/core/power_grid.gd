class_name PowerGrid
extends Node
## Red mínima: reparte energía mientras la carga no supere la capacidad.

signal power_changed

@export var capacity_w: float = 1500.0

var _consumers: Array[PowerConsumer] = []

@export var powered: bool = true:
	set(value):
		if powered == value:
			return
		powered = value
		_refresh()


func register(consumer: PowerConsumer) -> void:
	if consumer == null or consumer in _consumers:
		return
	_consumers.append(consumer)
	consumer.draw_changed.connect(_refresh)
	_refresh()


func total_draw() -> float:
	var total := 0.0
	for consumer in _consumers:
		total += consumer.draw_w
	return total


func _refresh() -> void:
	var supplied := powered and total_draw() <= capacity_w
	for consumer in _consumers:
		consumer.powered = supplied
	power_changed.emit()
