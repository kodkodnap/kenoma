class_name PowerTransformer
extends Node3D
## Transformador exterior: estabilidad, avería y reparación manual con mantener E.
## La geometría la pone BaseBuilder; este nodo añade el interactuable de reparación.

const REPAIR_HOLD := 2.5

var _system: PowerSystem
var _index: int = 0
var _interactable: Interactable


func _ready() -> void:
	add_to_group("power_transformer")
	_interactable = Interactable.new()
	_interactable.name = "Repair"
	_interactable.position = Vector3(-1.5, 1.3, 0.0)
	_interactable.prompt = "Reparar transformador"
	_interactable.hold_time = REPAIR_HOLD
	_interactable.activated.connect(_on_activated)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.7, 1.8)
	shape.shape = box
	_interactable.add_child(shape)
	add_child(_interactable)


func setup(index: int, system: PowerSystem) -> void:
	_index = index
	_system = system
	if _system != null:
		_system.warning_changed.connect(_on_warning_changed)
		_system.power_changed.connect(_on_power_changed)
		_system.power_restored.connect(_on_power_restored)
	_refresh()


func get_interactable() -> Interactable:
	return _interactable


func transformer_index() -> int:
	return _index


func _on_activated(_source: Interactable) -> void:
	if _system == null or not _system.is_transformer_damaged(_index):
		return
	_system.repair_transformer(_index)
	_refresh()


func _on_warning_changed(_text: String) -> void:
	_refresh()


func _on_power_changed(_on: bool) -> void:
	_refresh()


func _on_power_restored() -> void:
	_refresh()


func _refresh() -> void:
	if _interactable == null or _system == null:
		return
	var damaged := _system.is_transformer_damaged(_index)
	_interactable.enabled = damaged
	_interactable.prompt = "Reparar TRAFO %s" % _letter()


func _letter() -> String:
	return ["A", "B", "C"][_index] if _index >= 0 and _index < 3 else str(_index + 1)
