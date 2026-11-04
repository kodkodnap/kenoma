class_name Hud
extends CanvasLayer
## HUD diegético mínimo: mira, prompt, progreso de mantener, estado de máquina y red.

var machine: TestMachine
var player: Player:
	set(value):
		if player == value:
			return
		player = value
		if player != null:
			player.inventory.changed.connect(_refresh_inventory)
		_refresh_inventory()

var clock: GameClock:
	set(value):
		clock = value
		_refresh_clock()

var power: PowerSystem:
	set(value):
		if power == value:
			return
		power = value
		if power != null:
			power.stability_changed.connect(_on_stability_changed)
			power.power_changed.connect(_on_power_switch)
			power.circuit_changed.connect(_on_circuit_changed)
			power.warning_changed.connect(_on_warning_changed)
		_refresh_power()

@onready var crosshair: ColorRect = $Crosshair
@onready var prompt: Label = $Prompt
@onready var hold_bar: Control = $HoldBar
@onready var hold_fill: ColorRect = $HoldBar/Fill
@onready var status: Label = $Status
@onready var vitals: Label = $Vitals
@onready var inventory_label: Label = $Inventory
@onready var power_label: Label = $Power
@onready var clock_label: Label = $Clock

var _target: Interactable
var _status_timer: float = 0.0


func set_focus(target: Interactable) -> void:
	_target = target
	if _target == null:
		prompt.text = ""
		hold_bar.visible = false
		crosshair.color = Color(1.0, 1.0, 1.0, 0.45)
	else:
		crosshair.color = Color(1.0, 0.78, 0.3, 0.95) if _target.enabled \
			else Color(1.0, 0.3, 0.25, 0.9)
		_refresh_prompt()


func set_hold_progress(ratio: float) -> void:
	hold_bar.visible = ratio > 0.0
	if hold_bar.visible:
		hold_fill.size.x = hold_bar.size.x * clampf(ratio, 0.0, 1.0)


func _process(delta: float) -> void:
	_refresh_vitals()
	if _target != null:
		_refresh_prompt()

	_status_timer += delta
	if _status_timer < 0.2:
		return
	_status_timer = 0.0
	_refresh_power()
	_refresh_clock()
	if machine == null:
		return
	status.text = machine.get_status_text()


func _refresh_vitals() -> void:
	if player == null:
		return
	var stamina_pct := roundi(clampf(player.stamina / player.balance.stamina_max, 0.0, 1.0) * 100.0)
	var battery_pct := roundi(clampf(player.battery, 0.0, 1.0) * 100.0)
	var text := "Stamina %d%%\nLinterna %d%%" % [stamina_pct, battery_pct]
	if vitals.text != text:
		vitals.text = text


func _refresh_inventory() -> void:
	if player == null or inventory_label == null:
		return
	inventory_label.text = "Mochila %d · %.1f/%.1f m³" % [
		player.inventory.items.size(),
		player.inventory.total_volume(),
		player.inventory.capacity,
	]


## Estabilidad, carga y aviso de la red. Se refresca por tick, no cada frame.
func _refresh_power() -> void:
	if power_label == null or power == null:
		return
	var text := ""
	if power.is_blackout():
		text = "RED APAGADA · estabilidad 0%"
	else:
		text = "Estabilidad %d%% · %.0f/%.0f W" % [
			roundi(power.stability() * 100.0),
			power.demand_w(),
			power.capacity_w(),
		]
		if power.efficiency() < 0.995:
			text += "\nSOBRECARGA: apaga un circuito"
	if power.warning() != "":
		text += "\n" + power.warning()
	if power_label.text != text:
		power_label.text = text


func _refresh_clock() -> void:
	if clock_label == null or clock == null:
		return
	var text := "DÍA %d · %s" % [clock.day, clock.time_string()]
	if clock_label.text != text:
		clock_label.text = text


func _refresh_prompt() -> void:
	if _target == null:
		return
	var text := _target.prompt
	if not _target.enabled:
		text += " (bloqueado)"
	elif _target.hold_time > 0.0:
		text = "Mantén [E] %.1f s — %s" % [_target.hold_time, text]
	else:
		text = "[E] " + text
	if prompt.text != text:
		prompt.text = text


func _on_stability_changed(_value: float) -> void:
	_refresh_power()


func _on_power_switch(_on: bool) -> void:
	_refresh_power()


func _on_circuit_changed(_circuit: int, _powered: bool) -> void:
	_refresh_power()


func _on_warning_changed(_text: String) -> void:
	_refresh_power()
