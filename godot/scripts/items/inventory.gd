class_name Inventory
extends RefCounted
## Inventario por volumen. Lógica pura: no conoce nodos ni UI.

signal changed

const EPSILON := 0.001

var capacity: float
var items: Array[ItemDef] = []


func _init(capacity_: float = 0.0) -> void:
	capacity = maxf(0.0, capacity_)


func total_volume() -> float:
	var total := 0.0
	for item in items:
		total += item.volume
	return total


func can_add(item: ItemDef) -> bool:
	return item != null and total_volume() + item.volume <= capacity + EPSILON


func add(item: ItemDef) -> bool:
	if not can_add(item):
		return false
	items.append(item)
	changed.emit()
	return true


func remove(item: ItemDef) -> bool:
	var index := items.find(item)
	if index < 0:
		return false
	items.remove_at(index)
	changed.emit()
	return true


func clear() -> void:
	if items.is_empty():
		return
	items.clear()
	changed.emit()
