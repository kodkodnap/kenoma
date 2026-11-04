class_name SelectorSwitch
extends Interactable
## Selector de tres posiciones (la dirección de polaridad del panel original):
## placa grabada, aguja corta con trinquete y una leyenda por posición.
## La rueda y E recorren las posiciones en orden y vuelven a la primera.

signal value_changed(value: int)

@export var label_text: String = ""
@export var option_names: Array[String] = ["VERT", "MIXTA", "HORIZ"]
@export var start_index: int = 0

var index: int = 0

var _pivot: Node3D
var _name_label: Label3D
var _option_labels: Array[Label3D] = []


func _ready() -> void:
	super._ready()
	_build()
	sync_index(start_index)
	focus_changed.connect(_on_focus_changed)


func option_count() -> int:
	return option_names.size()


func activate() -> void:
	if enabled:
		step(1)


func step(direction: int) -> void:
	sync_index(index + direction)
	value_changed.emit(index)


func sync_index(new_index: int) -> void:
	var total := maxi(option_names.size(), 1)
	index = posmod(new_index, total)
	if _pivot != null:
		_pivot.rotation.z = lerpf(0.85, -0.85, float(index) / float(maxi(total - 1, 1)))
	prompt = "%s · %s · rueda" % [label_text, option_names[index]]
	for i in _option_labels.size():
		var active := i == index
		_option_labels[i].modulate = Color(1.0, 0.78, 0.36) if active else Color(0.5, 0.49, 0.42)


func _unhandled_input(event: InputEvent) -> void:
	if not focused or not enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step(-1)
			get_viewport().set_input_as_handled()


func _on_focus_changed(focused: bool) -> void:
	if _name_label == null:
		return
	_name_label.modulate = Color(1.0, 0.78, 0.36) if focused else Color(0.82, 0.79, 0.66)
	_name_label.outline_size = 5 if focused else 0


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.28, 0.28, 0.18)
	shape.shape = box
	shape.position.z = 0.03
	add_child(shape)

	# Placa con rebaje cuadrado y escala impresa alrededor del eje.
	MachineMesh.box(self, Vector3(0.0, 0.0, 0.006), Vector3(0.26, 0.26, 0.012),
		MachineMaterials.steel(), Vector3.ZERO, "Plate")
	MachineMesh.box(self, Vector3(0.0, 0.0, 0.0145), Vector3(0.2, 0.2, 0.006),
		MachineMaterials.dark_panel(), Vector3.ZERO, "Recess")
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.02), 0.055, 0.012,
		MachineMaterials.dark_steel(), Vector3(PI * 0.5, 0.0, 0.0), 24, -1.0, "Seat")

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position.z = 0.024
	add_child(_pivot)
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.0, 0.012), 0.03, 0.024,
		MachineMaterials.bakelite(), Vector3(PI * 0.5, 0.0, 0.0), 16, -1.0, "Hub")
	MachineMesh.box(_pivot, Vector3(0.0, 0.05, 0.026), Vector3(0.012, 0.055, 0.012),
		MachineMaterials.pointer(), Vector3.ZERO, "Pointer")
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.0, 0.028), 0.008, 0.006,
		MachineMaterials.pointer(), Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "Cap")

	# Leyendas: una por detente, alrededor de la aguja.
	var upright := Vector3(PI * 0.5, 0.0, 0.0)
	var spots: Array[Vector3] = [
		Vector3(-0.098, 0.0, 0.012), Vector3(0.0, 0.086, 0.012), Vector3(0.098, 0.0, 0.012),
	]
	for i in mini(option_names.size(), spots.size()):
		_option_labels.append(MachineMesh.label(self, option_names[i], spots[i], 0.0011,
			Color(0.5, 0.49, 0.42), 13, upright))
	_name_label = MachineMesh.label(self, label_text, Vector3(0.0, -0.158, 0.002), 0.0013,
		Color(0.87, 0.82, 0.66), 16, upright)
	MachineMesh.bolts(self, [Vector3(-0.112, -0.112, 0.012), Vector3(0.112, 0.112, 0.012)],
		MachineMaterials.steel(), 0.006, 0.005)
