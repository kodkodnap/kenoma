class_name ToggleSwitch
extends Interactable
## Interruptor de palanca con tuerca, guarda de goma y placa de leyenda.

signal toggled(on: bool)

@export var label_text: String = ""
@export var on: bool = false

var _pivot: Node3D
var _legend: Label3D
var _name_label: Label3D


func _ready() -> void:
	super._ready()
	_build()
	_apply_state(false)
	focus_changed.connect(_on_focus_changed)


func activate() -> void:
	if not enabled:
		return
	set_on(not on)


func set_on(value: bool) -> void:
	on = value
	_apply_state(true)
	toggled.emit(on)


func _on_focus_changed(focused: bool) -> void:
	if _name_label == null:
		return
	_name_label.modulate = Color(1.0, 0.78, 0.36) if focused else Color(0.82, 0.79, 0.66)
	_name_label.outline_size = 5 if focused else 0


func _apply_state(animated: bool) -> void:
	prompt = "%s: %s" % [label_text, "ON" if on else "OFF"]
	if _legend != null:
		_legend.text = "ON" if on else "OFF"
		_legend.modulate = Color(1.0, 0.7, 0.25) if on else Color(0.5, 0.55, 0.5)
	if _pivot == null:
		return
	var target := -0.55 if on else 0.55
	if not animated:
		_pivot.rotation.x = target
		return
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:x", target, 0.12).set_trans(Tween.TRANS_CUBIC)


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 0.26, 0.18)
	shape.shape = box
	shape.position.z = 0.03
	add_child(shape)

	# Placa atornillada con rebaje y tuerca hexagonal.
	MachineMesh.box(self, Vector3(0.0, 0.0, 0.006), Vector3(0.17, 0.23, 0.014),
		MachineMaterials.steel(), Vector3.ZERO, "Plate")
	MachineMesh.box(self, Vector3(0.0, 0.0, 0.0145), Vector3(0.135, 0.2, 0.006),
		MachineMaterials.dark_panel(), Vector3.ZERO, "Recess")
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.024), 0.035, 0.018,
		MachineMaterials.dark_steel(), Vector3(PI * 0.5, 0.0, 0.0), 6, -1.0, "Nut")
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.039), 0.03, 0.028,
		MachineMaterials.rubber(), Vector3(PI * 0.5, 0.0, 0.0), 16, 0.017, "Boot")

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position.z = 0.052
	add_child(_pivot)

	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.04, 0.0), 0.0075, 0.08,
		MachineMaterials.steel(), Vector3.ZERO, 10, -1.0, "Bat")
	MachineMesh.sphere(_pivot, Vector3(0.0, 0.082, 0.0), 0.0125,
		MachineMaterials.red_grip(), "Tip")

	# Leyenda ON grabada sobre la placa, a la derecha de la palanca.
	var upright := Vector3(PI * 0.5, 0.0, 0.0)
	_legend = MachineMesh.label(self, "OFF", Vector3(0.062, 0.072, 0.012), 0.0012,
		Color(0.5, 0.55, 0.5), 14, upright)
	MachineMesh.label(self, "ON", Vector3(0.062, -0.05, 0.012), 0.0012,
		Color(0.62, 0.6, 0.5), 14, upright)
	_name_label = MachineMesh.label(self, label_text, Vector3(0.0, -0.156, 0.002), 0.0013,
		Color(0.87, 0.82, 0.66), 16, upright)
	MachineMesh.bolts(self, [Vector3(-0.072, -0.1, 0.014), Vector3(0.072, 0.1, 0.014)],
		MachineMaterials.steel(), 0.006, 0.005)
