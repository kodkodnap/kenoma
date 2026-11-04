class_name Lever
extends Interactable
## Palanca industrial de recorrido corto: se mantiene E y conmuta al soltar.
## Tiene guía, brazo, mango estriado y bola para que se lea como un control real.

signal pulled(on: bool)

@export var label_text: String = ""
@export var on: bool = false

var _pivot: Node3D
var _name_label: Label3D


func _ready() -> void:
	super._ready()
	hold_time = 0.7 if hold_time <= 0.0 else hold_time
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
	pulled.emit(on)


func _on_focus_changed(focused: bool) -> void:
	if _name_label == null:
		return
	_name_label.modulate = Color(1.0, 0.78, 0.36) if focused else Color(0.82, 0.79, 0.66)
	_name_label.outline_size = 5 if focused else 0


func _apply_state(animated: bool) -> void:
	prompt = "%s: %s" % [label_text, "ACTIVA" if on else "PARADA"]
	if _pivot == null:
		return
	var target := -0.65 if on else 0.65
	if not animated:
		_pivot.rotation.x = target
		return
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:x", target, 0.18).set_trans(Tween.TRANS_CUBIC)


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.34, 0.22)
	shape.shape = box
	shape.position.z = 0.04
	add_child(shape)

	# Base con guía de dos paredes y fondo oscuro para el recorrido.
	MachineMesh.box(self, Vector3(0.0, 0.0, 0.006), Vector3(0.21, 0.29, 0.02),
		MachineMaterials.steel(), Vector3.ZERO, "Plate")
	MachineMesh.box(self, Vector3(0.0, 0.0, 0.025), Vector3(0.11, 0.21, 0.03),
		MachineMaterials.dark_panel(), Vector3.ZERO, "Gap")
	MachineMesh.box(self, Vector3(-0.083, 0.0, 0.04), Vector3(0.04, 0.2, 0.06),
		MachineMaterials.dark_steel(), Vector3.ZERO, "CheekLeft")
	MachineMesh.box(self, Vector3(0.083, 0.0, 0.04), Vector3(0.04, 0.2, 0.06),
		MachineMaterials.dark_steel(), Vector3.ZERO, "CheekRight")
	MachineMesh.box(self, Vector3(0.0, -0.1, 0.04), Vector3(0.16, 0.02, 0.05),
		MachineMaterials.steel(), Vector3.ZERO, "Stop")

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = Vector3(0.0, 0.02, 0.06)
	add_child(_pivot)

	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.115, 0.0), 0.015, 0.23,
		MachineMaterials.steel(), Vector3.ZERO, 12, -1.0, "Arm")
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.2, 0.0), 0.034, 0.11,
		MachineMaterials.red_grip(), Vector3.ZERO, 16, -1.0, "Grip")
	for ring_y in [0.155, 0.2, 0.245]:
		MachineMesh.cylinder(_pivot, Vector3(0.0, float(ring_y), 0.0), 0.037, 0.008,
			MachineMaterials.dark_steel(), Vector3.ZERO, 16, -1.0)
	MachineMesh.sphere(_pivot, Vector3(0.0, 0.263, 0.0), 0.041,
		MachineMaterials.red_grip(), "Ball")
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.0, 0.0), 0.026, 0.05,
		MachineMaterials.dark_steel(), Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "Hub")

	_name_label = MachineMesh.label(self, label_text, Vector3(0.0, -0.168, 0.002), 0.0013,
		Color(0.87, 0.82, 0.66), 16, Vector3(PI * 0.5, 0.0, 0.0))
	MachineMesh.bolts(self, [Vector3(-0.088, -0.122, 0.016), Vector3(0.088, 0.122, 0.016),
			Vector3(-0.088, 0.122, 0.016), Vector3(0.088, -0.122, 0.016)],
		MachineMaterials.steel(), 0.006, 0.005)
