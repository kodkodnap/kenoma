class_name ItemContainer
extends Node3D
## Contenedor del mundo. La lógica de volumen vive en Inventory.

@export var capacity: float = 12.0

var inventory: Inventory


func _ready() -> void:
	inventory = Inventory.new(capacity)


func add_item(item: ItemDef) -> bool:
	return inventory != null and inventory.add(item)


func remove_item(item: ItemDef) -> bool:
	return inventory != null and inventory.remove(item)
