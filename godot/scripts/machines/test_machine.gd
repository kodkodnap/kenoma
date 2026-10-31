class_name TestMachine
extends Machine
## Máquina de prueba del hito 1: interruptor con mantener, botón y perilla.

const KNOB_ANGLES := [-0.6, 0.0, 0.6]
const SWITCH_ON_ANGLE := -0.55
const SWITCH_OFF_ANGLE := 0.55
const STATE_NAMES := ["APAGADO", "ENCENDIDO", "SOBRECALENTADO", "SIN ENERGÍA"]

@onready var switch_interactable: Interactable = $Switch
@onready var button_interactable: Interactable = $Button
@onready var knob_interactable: Interactable = $Knob
@onready var lever_pivot: Node3D = $Switch/Pivot
@onready var button_mesh: MeshInstance3D = $Button/Mesh
@onready var knob_pivot: Node3D = $Knob/Pivot
@onready var status_lamp: MeshInstance3D = $StatusLamp

var _lamp_material: StandardMaterial3D
var _button_rest_z: float


func _ready() -> void:
	# Referencia explícita: el export NodePath del .tscn no se resolvió.
	if consumer == null:
		consumer = $Consumer as PowerConsumer
	super._ready()
	_lamp_material = (status_lamp.material_override as StandardMaterial3D).duplicate()
	status_lamp.material_override = _lamp_material
	_button_rest_z = button_mesh.position.z
	switch_interactable.activated.connect(_on_switch_activated)
	button_interactable.activated.connect(_on_button_activated)
	knob_interactable.activated.connect(_on_knob_activated)
	state_changed.connect(_on_state_changed)
	heat_changed.connect(_on_heat_changed)
	mode_changed.connect(_on_mode_changed)
	lever_pivot.rotation.x = SWITCH_OFF_ANGLE
	_refresh_controls()
	_refresh_lamp()


func _on_switch_activated(_source: Interactable) -> void:
	toggle_power()
	_move_lever()
	_refresh_controls()


func _on_button_activated(_source: Interactable) -> void:
	if not can_reset():
		return
	reset()
	var tween := create_tween()
	tween.tween_property(button_mesh, "position:z", _button_rest_z - 0.02, 0.05)
	tween.tween_property(button_mesh, "position:z", _button_rest_z, 0.1)


func _on_knob_activated(_source: Interactable) -> void:
	cycle_mode()


func _on_state_changed(_new_state: int) -> void:
	_refresh_controls()
	_refresh_lamp()


func _on_heat_changed(_ratio: float) -> void:
	if state == State.OVERHEATED:
		button_interactable.enabled = can_reset()


func _on_mode_changed(new_mode: int) -> void:
	var tween := create_tween()
	tween.tween_property(knob_pivot, "rotation:z", KNOB_ANGLES[new_mode], 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_refresh_controls()


func _refresh_controls() -> void:
	switch_interactable.prompt = "Apagar" if state == State.ON else "Encender"
	switch_interactable.enabled = state == State.OFF or state == State.ON
	button_interactable.enabled = can_reset()
	knob_interactable.prompt = "Ganancia %s" % definition.mode_names[mode]


func _refresh_lamp() -> void:
	var color := Color(0.15, 0.16, 0.15)
	var energy := 0.0
	match state:
		State.ON:
			color = Color(0.2, 1.0, 0.4)
			energy = 3.0
		State.OVERHEATED:
			color = Color(1.0, 0.15, 0.1)
			energy = 3.0
		State.NO_POWER:
			color = Color(1.0, 0.6, 0.1)
			energy = 2.0
	_lamp_material.albedo_color = color
	_lamp_material.emission = color
	_lamp_material.emission_energy_multiplier = energy
	_lamp_material.emission_enabled = energy > 0.0


func _move_lever() -> void:
	var target := SWITCH_ON_ANGLE if state == State.ON else SWITCH_OFF_ANGLE
	var tween := create_tween()
	tween.tween_property(lever_pivot, "rotation:x", target, 0.15).set_trans(Tween.TRANS_CUBIC)


func get_status_text() -> String:
	var heat_pct := int(round(heat / definition.max_heat * 100.0))
	return "%s\n%s · Calor %d%% · Ganancia %s" % [
		definition.display_name,
		STATE_NAMES[state],
		heat_pct,
		definition.mode_names[mode],
	]
