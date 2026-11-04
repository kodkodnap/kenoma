class_name PushButton
extends Interactable
## Pulsador de panel: placa atornillada, aro metálico, botón que se hunde y piloto.
## No guarda estado: cada pulsación emite `pressed` y el dueño decide qué hacer.

signal pressed

@export var label_text: String = ""
@export var lamp_color: Color = Color(0.95, 0.6, 0.18)

var _cap: Node3D
var _lamp: StandardMaterial3D
var _name_label: Label3D


func _ready() -> void:
	super._ready()
	_build()
	prompt = label_text
	focus_changed.connect(_on_focus_changed)


func activate() -> void:
	if not enabled:
		return
	_press()
	pressed.emit()


## Destello del piloto: confirma la acción aunque el botón no cambie de estado.
func flash() -> void:
	if _lamp == null:
		return
	var tween := create_tween()
	tween.tween_property(_lamp, "emission_energy_multiplier", 3.4, 0.06)
	tween.tween_property(_lamp, "emission_energy_multiplier", 0.3, 0.4)


func _on_focus_changed(focused: bool) -> void:
	if _name_label == null:
		return
	_name_label.modulate = Color(1.0, 0.78, 0.36) if focused else Color(0.82, 0.79, 0.66)
	_name_label.outline_size = 5 if focused else 0


func _press() -> void:
	if _cap == null:
		return
	var tween := create_tween()
	tween.tween_property(_cap, "position:z", 0.014, 0.05).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_cap, "position:z", 0.03, 0.11).set_trans(Tween.TRANS_CUBIC)


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.22, 0.22, 0.18)
	shape.shape = box
	shape.position.z = 0.03
	add_child(shape)

	MachineMesh.box(self, Vector3(0.0, 0.0, 0.006), Vector3(0.19, 0.19, 0.012),
		MachineMaterials.steel(), Vector3.ZERO, "Plate")
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.012), 0.08, 0.016,
		MachineMaterials.dark_steel(), Vector3(PI * 0.5, 0.0, 0.0), 24, -1.0, "Bezel")
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.019), 0.062, 0.012,
		MachineMaterials.rubber(), Vector3(PI * 0.5, 0.0, 0.0), 24, -1.0, "Boot")

	_cap = Node3D.new()
	_cap.name = "Cap"
	_cap.position = Vector3(0.0, 0.0, 0.03)
	add_child(_cap)
	MachineMesh.cylinder(_cap, Vector3.ZERO, 0.05, 0.028,
		MachineMaterials.red_grip(), Vector3(PI * 0.5, 0.0, 0.0), 20, 0.044, "Button")
	MachineMesh.cylinder(_cap, Vector3(0.0, 0.0, 0.016), 0.022, 0.004,
		MachineMaterials.cream(), Vector3(PI * 0.5, 0.0, 0.0), 20, -1.0, "Legend")

	_lamp = MachineMaterials.led(lamp_color)
	_lamp.emission_energy_multiplier = 0.3
	MachineMesh.cylinder(self, Vector3(0.0, 0.076, 0.014), 0.011, 0.01,
		_lamp, Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "Pilot")
	_name_label = MachineMesh.label(self, label_text, Vector3(0.0, -0.152, 0.002), 0.0013,
		Color(0.87, 0.82, 0.66), 16, Vector3(PI * 0.5, 0.0, 0.0))
	MachineMesh.bolts(self, [Vector3(-0.078, -0.078, 0.012), Vector3(0.078, 0.078, 0.012)],
		MachineMaterials.steel(), 0.006, 0.005)
