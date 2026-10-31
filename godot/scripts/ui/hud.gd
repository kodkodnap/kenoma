class_name Hud
extends CanvasLayer
## HUD diegético mínimo: mira, prompt, progreso de mantener y estado de máquina.

var machine: TestMachine
var grid: PowerGrid
var player: Player

@onready var crosshair: ColorRect = $Crosshair
@onready var prompt: Label = $Prompt
@onready var hold_bar: Control = $HoldBar
@onready var hold_fill: ColorRect = $HoldBar/Fill
@onready var status: Label = $Status
@onready var vitals: Label = $Vitals

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
	if machine == null:
		return

	var text := machine.get_status_text()
	if grid != null:
		text += "\nRed %.0f / %.0f W" % [grid.total_draw(), grid.capacity_w]
	status.text = text


func _refresh_vitals() -> void:
	if player == null:
		return
	var stamina_pct := roundi(clampf(player.stamina / player.balance.stamina_max, 0.0, 1.0) * 100.0)
	var battery_pct := roundi(clampf(player.battery, 0.0, 1.0) * 100.0)
	var text := "Stamina %d%%\nLinterna %d%%" % [stamina_pct, battery_pct]
	if vitals.text != text:
		vitals.text = text


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
