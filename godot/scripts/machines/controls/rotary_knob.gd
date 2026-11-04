class_name RotaryKnob
extends Interactable
## Perilla física con escala impresa, falda estriada y puntero.
## Se gira con la rueda del ratón o con E (un paso por pulsación).

signal value_changed(new_value: float)

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
@export var start_value: float = 0.0
@export var label_text: String = ""
@export var value_suffix: String = ""

var value: float = 0.0

var _pivot: Node3D
var _label: Label3D


func _ready() -> void:
	super._ready()
	step = maxf(step, 0.001)
	_build()
	sync_value(start_value)
	focus_changed.connect(_on_focus_changed)


func turn(direction: int) -> void:
	sync_value(value + step * float(direction))
	value_changed.emit(value)


func sync_value(new_value: float) -> void:
	value = clampf(new_value, min_value, max_value)
	if _pivot != null:
		var ratio := inverse_lerp(min_value, max_value, value)
		_pivot.rotation.z = lerpf(-2.2, 2.2, ratio)
	prompt = "%s · %s%s · rueda" % [label_text, _value_text(), value_suffix]


func activate() -> void:
	if enabled:
		turn(1)


func _unhandled_input(event: InputEvent) -> void:
	if not focused or not enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			turn(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			turn(-1)
			get_viewport().set_input_as_handled()


func _on_focus_changed(focused: bool) -> void:
	if _label == null:
		return
	_label.modulate = Color(1.0, 0.78, 0.36) if focused else Color(0.82, 0.79, 0.66)
	_label.outline_size = 5 if focused else 0


func _value_text() -> String:
	if step >= 1.0:
		return "%d" % roundi(value)
	return "%.1f" % value


func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.26, 0.26, 0.2)
	shape.shape = box
	shape.position.z = 0.03
	add_child(shape)

	# Escala impresa en geometría: aro claro con marcas, sin texturas con alfa.
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.004), 0.152, 0.008,
		MachineMaterials.cream(), Vector3(PI * 0.5, 0.0, 0.0), 32, -1.0, "ScaleRing")
	MachineMesh.cylinder(self, Vector3(0.0, 0.0, 0.006), 0.118, 0.012,
		MachineMaterials.dark_steel(), Vector3(PI * 0.5, 0.0, 0.0), 24, -1.0, "Plate")
	var ticks: Array[Transform3D] = []
	var red_ticks: Array[Transform3D] = []
	for i in 22:
		var ratio := float(i) / 21.0
		var angle := lerpf(-2.15, 2.15, ratio)
		var spot := Vector3(sin(angle), cos(angle), 0.0) * 0.137 + Vector3(0.0, 0.0, 0.0085)
		var tick := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -angle), spot)
		if ratio > 0.8:
			red_ticks.append(tick)
		else:
			ticks.append(tick)
	MachineMesh.slats(self, ticks, Vector3(0.005, 0.02, 0.003), MachineMaterials.cream(), "Ticks")
	MachineMesh.slats(self, red_ticks, Vector3(0.006, 0.022, 0.003), MachineMaterials.red_grip(),
		"RedTicks")

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position.z = 0.016
	add_child(_pivot)

	# Falda estriada, tapa y puntero: la perilla tiene volumen y se ve girar.
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.0, 0.03), 0.072, 0.05,
		MachineMaterials.knurled(), Vector3(PI * 0.5, 0.0, 0.0), 24, -1.0, "Skirt")
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.0, 0.06), 0.05, 0.022,
		MachineMaterials.bakelite(), Vector3(PI * 0.5, 0.0, 0.0), 24, -1.0, "Cap")
	MachineMesh.box(_pivot, Vector3(0.0, 0.037, 0.073), Vector3(0.007, 0.058, 0.006),
		MachineMaterials.pointer(), Vector3.ZERO, "Pointer")
	MachineMesh.cylinder(_pivot, Vector3(0.0, 0.0, 0.074), 0.012, 0.006,
		MachineMaterials.pointer(), Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "Hub")

	# Tornillos del plato: dos, para que no parezca pegado.
	MachineMesh.bolts(self, [Vector3(-0.098, 0.098, 0.008), Vector3(0.098, -0.098, 0.008)],
		MachineMaterials.steel(), 0.006, 0.005)

	# La perilla puede ir tumbada en una cubierta inclinada: la leyenda se endereza.
	_label = MachineMesh.label(self, label_text, Vector3(0.0, -0.196, 0.002), 0.0013,
		Color(0.87, 0.82, 0.66), 16, Vector3(PI * 0.5, 0.0, 0.0))
