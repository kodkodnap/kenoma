class_name BreakerPanel
extends Node3D
## Breaker principal: cinco circuitos y el botón rojo de rearme.
## El panel vive en el marcador "Breaker" que construye BaseBuilder.

var _system: PowerSystem
var _switches: Array[Interactable] = []
var _restart: Interactable


func _ready() -> void:
	add_to_group("breaker_panel")
	for i in PowerSystem.CIRCUIT_COUNT:
		var switch := Interactable.new()
		switch.name = "Circuit%d" % i
		switch.position = Vector3(-1.2 + i * 0.6, 0.45, 0.3)
		switch.prompt = String(PowerSystem.CIRCUIT_NAMES[i])
		switch.activated.connect(_on_switch_activated)
		var switch_shape := CollisionShape3D.new()
		var switch_box := BoxShape3D.new()
		switch_box.size = Vector3(0.4, 0.45, 0.3)
		switch_shape.shape = switch_box
		switch.add_child(switch_shape)
		add_child(switch)
		_switches.append(switch)

	_restart = Interactable.new()
	_restart.name = "Restart"
	_restart.position = Vector3(0.0, 1.05, 0.3)
	_restart.prompt = "Rearmar la red"
	_restart.activated.connect(_on_restart_activated)
	var restart_shape := CollisionShape3D.new()
	var restart_box := BoxShape3D.new()
	restart_box.size = Vector3(0.55, 0.55, 0.3)
	restart_shape.shape = restart_box
	_restart.add_child(restart_shape)
	add_child(_restart)


func setup(system: PowerSystem) -> void:
	_system = system
	if _system != null:
		_system.circuit_changed.connect(_on_circuit_changed)
		_system.power_changed.connect(_on_power_changed)
		_system.warning_changed.connect(_on_warning_changed)
	_refresh()


func switch_count() -> int:
	return _switches.size()


func get_switch(circuit: int) -> Interactable:
	if circuit < 0 or circuit >= _switches.size():
		return null
	return _switches[circuit]


func get_restart_button() -> Interactable:
	return _restart


func restart_enabled() -> bool:
	return _restart != null and _restart.enabled


func press_restart() -> bool:
	if _system == null:
		return false
	var restored := _system.press_restart()
	_refresh()
	return restored


func _on_switch_activated(source: Interactable) -> void:
	if _system == null:
		return
	var circuit := _switches.find(source)
	if circuit >= 0:
		_system.toggle_circuit(circuit)
	_refresh()


func _on_restart_activated(_source: Interactable) -> void:
	press_restart()


func _on_circuit_changed(_circuit: int, _powered: bool) -> void:
	_refresh()


func _on_power_changed(_on: bool) -> void:
	_refresh()


func _on_warning_changed(_text: String) -> void:
	_refresh()


func _refresh() -> void:
	if _system == null:
		return
	for i in _switches.size():
		var state := "ON" if _system.is_circuit_enabled(i) else "OFF"
		_switches[i].prompt = "%s (%s)" % [PowerSystem.CIRCUIT_NAMES[i], state]
	if _restart != null:
		_restart.enabled = _system.is_blackout()
		_restart.prompt = "Pulsa otra vez para rearmar" if _system.is_restart_armed() \
			else "Rearmar la red"
