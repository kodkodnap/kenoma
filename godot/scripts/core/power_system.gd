class_name PowerSystem
extends RefCounted
## Red eléctrica: tres transformadores, cinco breakers y apagón.
## Lógica pura y determinista: no conoce escenas ni nodos. Máquinas, luces y
## puertas se enganchan con PowerConsumer y obedecen `powered`.
##
## Reglas:
## - Cada circuito consume una carga base; los consumidores registrados suman.
## - La capacidad sale de los transformadores sanos, escalada por su estabilidad.
## - Con demanda > capacidad hay sobrecarga: la estabilidad baja y los circuitos
##   van más lentos (efficiency). Apagar un circuito libera carga y acelera el resto.
## - Si un transformador llega a estabilidad 0 se quema y la base se apaga.
## - El rearme exige dos pulsaciones del botón rojo y ningún transformador dañado.

signal power_changed(on: bool)
signal stability_changed(value: float)
signal circuit_changed(circuit: int, powered: bool)
signal blackout_started()
signal power_restored()
signal warning_changed(text: String)

enum Circuit { CALCULATIONS, DOWNLOADING, COORDINATES, PLAYING, UTILITIES }

const CIRCUIT_COUNT := 5
const CIRCUIT_NAMES := ["CÁLCULOS", "DESCARGAS", "COORDENADAS", "REPRODUCCIÓN", "SERVICIOS"]
## El transformador C trabaja más y se quema antes: da una avería concreta que reparar.
const DRAIN_WEIGHTS := [0.6, 1.0, 1.4]

var capacity_per_transformer_w: float = 1200.0
var stability_drain_per_second: float = 0.08
var stability_recover_per_second: float = 0.05
var restart_window_seconds: float = 5.0
var restart_stability: float = 0.35
var remote_steps: Array[float] = [30.0, 20.0, 12.0, 6.0, 3.0, 1.0]

var _draws: Array[float] = [800.0, 650.0, 550.0, 450.0, 350.0]
var _enabled: Array[bool] = []
var _powered_circuits: Array[bool] = []
var _consumers: Array[Array] = []
var _transformers: Array[Dictionary] = []
var _efficiency: float = 1.0
var _powered: bool = true
var _blackout: bool = false
var _restart_armed: bool = false
var _restart_window_left: float = 0.0
var _remote_remaining: float = -1.0
var _remote_step: int = 0
var _warning: String = ""


func setup(balance: GameBalance = null) -> void:
	if balance != null:
		capacity_per_transformer_w = balance.transformer_capacity_w
		stability_drain_per_second = balance.power_stability_drain_per_second
		stability_recover_per_second = balance.power_stability_recover_per_second
		restart_window_seconds = balance.power_restart_window
		restart_stability = balance.power_restart_stability
		remote_steps = balance.power_remote_steps.duplicate()
		var source := balance.power_circuit_draws
		for i in CIRCUIT_COUNT:
			_draws[i] = source[i] if i < source.size() else 0.0
		_build_transformers(balance.transformer_count)
	else:
		_build_transformers(3)
	_reset_state()
	_apply_power()


## Avanza estabilidad, ventana de rearme y control remoto.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if _blackout:
		_tick_remote(delta)
		return

	if _restart_armed:
		_restart_window_left -= delta
		if _restart_window_left <= 0.0:
			_restart_armed = false
			_set_warning("")

	_update_stability(delta)
	_calculate()
	if not _blackout:
		stability_changed.emit(stability())


func demand_w() -> float:
	var total := 0.0
	for i in CIRCUIT_COUNT:
		if not _enabled[i]:
			continue
		total += _draws[i]
		for consumer in _consumers[i]:
			if is_instance_valid(consumer):
				total += (consumer as PowerConsumer).draw_w
	return total


func capacity_w() -> float:
	var total := 0.0
	for transformer in _transformers:
		if bool(transformer["damaged"]):
			continue
		total += capacity_per_transformer_w * float(transformer["stability"])
	return total


func efficiency() -> float:
	return _efficiency


## Estabilidad del transformador más débil: es la que decide el apagón.
func stability() -> float:
	var weakest := 0.0
	var found := false
	for transformer in _transformers:
		if bool(transformer["damaged"]):
			continue
		var value := float(transformer["stability"])
		if not found or value < weakest:
			weakest = value
			found = true
	return weakest if found else 0.0


func is_blackout() -> bool:
	return _blackout


func is_restart_armed() -> bool:
	return _restart_armed


func warning() -> String:
	return _warning


func transformer_count() -> int:
	return _transformers.size()


func circuit_count() -> int:
	return CIRCUIT_COUNT


func is_transformer_damaged(index: int) -> bool:
	return index >= 0 and index < _transformers.size() and bool(_transformers[index]["damaged"])


func transformer_stability(index: int) -> float:
	if index < 0 or index >= _transformers.size():
		return 0.0
	return float(_transformers[index]["stability"])


func damaged_transformers() -> int:
	var count := 0
	for transformer in _transformers:
		if bool(transformer["damaged"]):
			count += 1
	return count


func is_circuit_enabled(circuit: int) -> bool:
	return circuit >= 0 and circuit < CIRCUIT_COUNT and _enabled[circuit]


func is_circuit_powered(circuit: int) -> bool:
	return circuit >= 0 and circuit < CIRCUIT_COUNT and _powered_circuits[circuit]


## 0 si el circuito está apagado; si no, la eficiencia de la red (0–1).
func circuit_speed(circuit: int) -> float:
	if not is_circuit_powered(circuit):
		return 0.0
	return _efficiency


func set_circuit_enabled(circuit: int, enabled: bool) -> bool:
	if circuit < 0 or circuit >= CIRCUIT_COUNT:
		return false
	if _enabled[circuit] == enabled:
		return false
	_enabled[circuit] = enabled
	_calculate()
	return true


func toggle_circuit(circuit: int) -> bool:
	return set_circuit_enabled(circuit, not is_circuit_enabled(circuit))


func register_consumer(consumer: PowerConsumer, circuit: int) -> void:
	if consumer == null or circuit < 0 or circuit >= CIRCUIT_COUNT:
		return
	if consumer in _consumers[circuit]:
		return
	_consumers[circuit].append(consumer)
	consumer.draw_changed.connect(_calculate)
	_apply_power()


func press_restart() -> bool:
	if not _blackout:
		_set_warning("La red ya está en marcha")
		return false
	if damaged_transformers() > 0:
		_restart_armed = false
		_set_warning("Transformador dañado: repáralo antes de rearmar")
		return false
	if not _restart_armed:
		_restart_armed = true
		_restart_window_left = restart_window_seconds
		_set_warning("Pulsa otra vez para rearmar")
		return false
	return _restore()


func trigger_blackout() -> void:
	if _blackout:
		return
	_blackout = true
	_restart_armed = false
	_restart_window_left = 0.0
	_remote_remaining = -1.0
	_efficiency = 0.0
	_set_warning("APAGÓN: rearma el breaker en el sótano")
	_apply_power()
	blackout_started.emit()


func damage_transformer(index: int, reason: String = "") -> void:
	if index < 0 or index >= _transformers.size():
		return
	var transformer: Dictionary = _transformers[index]
	if bool(transformer["damaged"]):
		return
	transformer["damaged"] = true
	transformer["stability"] = 0.0
	_set_warning(reason if reason != "" else "Transformador %s dañado" % _transformer_name(index))
	_calculate()


func repair_transformer(index: int) -> void:
	if index < 0 or index >= _transformers.size():
		return
	var transformer: Dictionary = _transformers[index]
	if not bool(transformer["damaged"]):
		return
	transformer["damaged"] = false
	transformer["stability"] = maxf(0.5, restart_stability)
	_set_warning("")
	_calculate()


func repair_all() -> void:
	for i in _transformers.size():
		repair_transformer(i)


## El módulo de control remoto tarda `remote_seconds()` y se mejora por pasos.
func remote_seconds() -> float:
	return remote_steps[_remote_step]


func remote_remaining() -> float:
	return _remote_remaining


func is_remote_restart_running() -> bool:
	return _remote_remaining > 0.0


func start_remote_restart() -> bool:
	if not _blackout or is_remote_restart_running():
		return false
	_remote_remaining = remote_seconds()
	_set_warning("Control remoto: %d s para rearmar" % roundi(_remote_remaining))
	return true


func upgrade_remote() -> float:
	_remote_step = mini(_remote_step + 1, remote_steps.size() - 1)
	return remote_seconds()


func _build_transformers(count: int) -> void:
	_transformers.clear()
	for i in maxi(count, 1):
		_transformers.append({"stability": 1.0, "damaged": false})


func _reset_state() -> void:
	_enabled.clear()
	_powered_circuits.clear()
	_consumers.clear()
	for i in CIRCUIT_COUNT:
		_enabled.append(true)
		_powered_circuits.append(false)
		_consumers.append([])
	_efficiency = 1.0
	_powered = true
	_blackout = false
	_restart_armed = false
	_restart_window_left = 0.0
	_remote_remaining = -1.0
	_remote_step = 0
	_warning = ""


func _compute_efficiency() -> float:
	var demand := demand_w()
	if demand <= 0.0:
		return 1.0
	return clampf(capacity_w() / demand, 0.0, 1.0)


func _calculate() -> void:
	_efficiency = _compute_efficiency()
	_apply_power()


func _update_stability(delta: float) -> void:
	var efficiency_now := _compute_efficiency()
	var overloaded := efficiency_now < 0.995
	for i in _transformers.size():
		var transformer: Dictionary = _transformers[i]
		if bool(transformer["damaged"]):
			continue
		var value := float(transformer["stability"])
		if overloaded:
			var weight := float(DRAIN_WEIGHTS[i % DRAIN_WEIGHTS.size()])
			var deficit := 1.0 - efficiency_now + 0.1
			value = maxf(0.0, value - stability_drain_per_second * weight * deficit * delta)
		else:
			value = minf(1.0, value + stability_recover_per_second * delta)
		transformer["stability"] = value
		if value <= 0.0:
			_burn(i)


func _burn(index: int) -> void:
	_transformers[index]["damaged"] = true
	_transformers[index]["stability"] = 0.0
	_set_warning("Transformador %s quemado: repáralo y rearma" % _transformer_name(index))
	trigger_blackout()


func _restore() -> bool:
	_blackout = false
	_restart_armed = false
	_restart_window_left = 0.0
	_remote_remaining = -1.0
	for transformer in _transformers:
		if not bool(transformer["damaged"]):
			transformer["stability"] = maxf(float(transformer["stability"]), restart_stability)
	_efficiency = _compute_efficiency()
	_set_warning("")
	_apply_power()
	power_restored.emit()
	return true


func _tick_remote(delta: float) -> void:
	if _remote_remaining <= 0.0:
		return
	_remote_remaining = maxf(0.0, _remote_remaining - delta)
	if _remote_remaining > 0.0:
		return
	if damaged_transformers() > 0:
		_remote_remaining = -1.0
		_set_warning("Control remoto: transformador dañado")
		return
	_restore()


func _apply_power() -> void:
	var on := not _blackout
	if on != _powered:
		_powered = on
		power_changed.emit(on)
	for circuit in CIRCUIT_COUNT:
		var powered := on and _enabled[circuit] and _efficiency > 0.05
		if powered != _powered_circuits[circuit]:
			_powered_circuits[circuit] = powered
			circuit_changed.emit(circuit, powered)
		for consumer in _consumers[circuit]:
			if is_instance_valid(consumer):
				(consumer as PowerConsumer).powered = powered


func _transformer_name(index: int) -> String:
	return ["A", "B", "C"][index] if index >= 0 and index < 3 else str(index + 1)


func _set_warning(text: String) -> void:
	if _warning == text:
		return
	_warning = text
	warning_changed.emit(text)
