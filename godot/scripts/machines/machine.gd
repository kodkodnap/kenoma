class_name Machine
extends Node3D
## Base de máquina: energía, calor y estados. La subclase pone los controles.

enum State { OFF, ON, OVERHEATED, NO_POWER }

signal state_changed(new_state: State)
signal heat_changed(ratio: float)
signal mode_changed(new_mode: int)

@export var definition: MachineDef
@export var consumer: PowerConsumer

var state: State = State.OFF
var heat: float = 0.0
var mode: int = 0


func _ready() -> void:
	assert(definition != null, "Machine necesita un MachineDef")
	if consumer != null:
		consumer.power_changed.connect(_on_power_changed)
		_apply_power_draw()


func _physics_process(delta: float) -> void:
	if state == State.ON:
		heat = minf(definition.max_heat, heat + definition.heat_per_second[mode] * delta)
		if heat >= definition.max_heat:
			_set_state(State.OVERHEATED)
	elif heat > 0.0:
		heat = maxf(0.0, heat - definition.cool_per_second * delta)
	heat_changed.emit(heat / definition.max_heat)


func toggle_power() -> void:
	match state:
		State.ON:
			_set_state(State.OFF)
		State.OFF:
			if consumer != null and not consumer.powered:
				_set_state(State.NO_POWER)
			else:
				_set_state(State.ON)


func reset() -> void:
	if can_reset():
		_set_state(State.OFF)


func can_reset() -> bool:
	return state == State.OVERHEATED and heat <= definition.restart_heat


func cycle_mode() -> void:
	mode = (mode + 1) % definition.heat_per_second.size()
	_apply_power_draw()
	mode_changed.emit(mode)


func _apply_power_draw() -> void:
	if consumer != null:
		consumer.draw_w = definition.power_draw_w[mode]


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _on_power_changed(powered: bool) -> void:
	if not powered and state == State.ON:
		_set_state(State.NO_POWER)
	elif powered and state == State.NO_POWER:
		_set_state(State.OFF)
