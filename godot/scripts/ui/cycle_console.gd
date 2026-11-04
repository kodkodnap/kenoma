class_name CycleConsole
extends CanvasLayer
## Terminal del ciclo: reloj, tarea diaria, tienda y dron.
## Vive en un SubViewport y no pausa el mundo.

const TAB_NAMES := ["RELOJ", "TAREA", "TIENDA", "DRON"]

@onready var viewport: SubViewport = $Frame/SubViewportContainer/SubViewport
@onready var ui_root: Control = $Frame/SubViewportContainer/SubViewport/Ui

var _cycle: DailyCycle
var _title_label: Label
var _credits_label: Label
var _content: VBoxContainer
var _status_label: Label
var _time_label: Label
var _current_tab: int = 0
var _status_text: String = ""


func _ready() -> void:
	visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_build_ui()


func setup(cycle: DailyCycle) -> void:
	_cycle = cycle
	if _cycle != null:
		_cycle.task_ready.connect(_on_task_ready)
		_cycle.task_delivered.connect(_on_task_delivered)
		_cycle.task_missed.connect(_on_task_missed)
		_cycle.drone_arrived.connect(_on_drone)
		_cycle.notice.connect(_on_notice)
		_cycle.economy.points_changed.connect(_on_points_changed)
	_refresh()


func tab_count() -> int:
	return TAB_NAMES.size()


func current_tab() -> int:
	return _current_tab


func is_open() -> bool:
	return visible


func open_tab(tab: int) -> void:
	_current_tab = clampi(tab, 0, TAB_NAMES.size() - 1)
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible or _cycle == null or _time_label == null:
		return
	if not is_instance_valid(_time_label):
		_time_label = null
		return
	_time_label.text = "DÍA %d · %s" % [_cycle.clock.day, _cycle.clock.time_string()]


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	ui_root.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	_title_label = _label("TERMINAL KESTREL", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_label = _label("CRÉDITOS 0", 16)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_title_label)
	header.add_child(_credits_label)
	root.add_child(header)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[i]
		button.pressed.connect(open_tab.bind(i))
		tabs.add_child(button)
	root.add_child(tabs)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content)

	_status_label = _label("", 14)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var close_button := Button.new()
	close_button.text = "CERRAR [Esc]"
	close_button.pressed.connect(close)
	root.add_child(close_button)


func _refresh() -> void:
	if _cycle == null:
		return
	_title_label.text = "TERMINAL KESTREL · " + TAB_NAMES[_current_tab]
	_credits_label.text = "CRÉDITOS %d · PUNTOS %d" % [
		_cycle.signals.credits if _cycle.signals != null else 0,
		_cycle.economy.points,
	]
	_status_label.text = _status_text
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()
	_time_label = null
	match _current_tab:
		0:
			_build_reloj()
		1:
			_build_tarea()
		2:
			_build_tienda()
		3:
			_build_dron()


func _build_reloj() -> void:
	_time_label = _label("DÍA %d · %s" % [_cycle.clock.day, _cycle.clock.time_string()], 28)
	_content.add_child(_time_label)
	_content.add_child(_label("Un día completo dura 75 min reales. Velocidad actual ×%d." % roundi(
		_cycle.clock.speed
	)))
	var speeds := HBoxContainer.new()
	for value in [1, 10, 60]:
		speeds.add_child(_button("×%d" % value, _set_speed.bind(float(value))))
	_content.add_child(speeds)
	_content.add_child(_button("DORMIR HASTA LAS 06:00", _sleep))
	_content.add_child(_label("Dormir avanza el reloj hasta las 06:00; la stamina y el sueño llegan en el hito 9.",
		14))
	if _cycle.task != null:
		_content.add_child(_label(_cycle.task.describe(), 16))


func _build_tarea() -> void:
	var task := _cycle.task
	if task == null:
		_content.add_child(_label("No hay tarea activa."))
		return
	var progress := _cycle.qualifying_signals()
	_content.add_child(_label(task.describe(), 18))
	_content.add_child(_label("Señales válidas: %d / %d" % [progress, task.signals_required], 18))
	_content.add_child(_label("Recompensa: %d créditos · %d puntos" % [
		task.reward_credits, task.reward_points,
	]))
	_content.add_child(_label("Multa si no entregas: -%d créditos" % task.fine_credits))
	if task.delivered:
		_content.add_child(_label("TAREA ENTREGADA", 16))
	elif task.missed:
		_content.add_child(_label("TAREA PERDIDA", 16))
	else:
		var deliver := _button("ENTREGAR TAREA", _deliver)
		deliver.disabled = progress < task.signals_required
		_content.add_child(deliver)
	_content.add_child(_label("Hashcodes: %d/%d · Cintas: %d/%d (hitos 8 y 11)." % [
		task.hashcodes_required, task.hashcodes_required,
		task.tapes_required, task.tapes_required,
	], 14))


func _build_tienda() -> void:
	_content.add_child(_label("Créditos disponibles: %d" % (
		_cycle.signals.credits if _cycle.signals != null else 0
	), 18))
	var categories: Array[String] = []
	for item in _cycle.economy.store:
		var category := String(item.get("category", "Otros"))
		if category not in categories:
			categories.append(category)
	for category in categories:
		_content.add_child(_label(category.to_upper(), 16))
		for item in _cycle.economy.store:
			if String(item.get("category", "")) != category:
				continue
			var price := int(item.get("price", 0))
			var row := HBoxContainer.new()
			var name_label := _label("%s — %d créditos" % [item.get("name", ""), price])
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var buy_button := _button("COMPRAR", _buy.bind(String(item.get("id", ""))))
			buy_button.disabled = (_cycle.signals.credits if _cycle.signals != null else 0) < price
			row.add_child(buy_button)
			_content.add_child(row)
	_content.add_child(_label("Los pedidos llegan con el dron a las 06:00."))


func _build_dron() -> void:
	_content.add_child(_label(_cycle.next_drone_text(), 18))
	var pending := _cycle.economy.pending_list()
	_content.add_child(_label("Pedidos pendientes: %d" % pending.size(), 16))
	for order in pending:
		_content.add_child(_label("· " + String(order.get("name", "Pedido"))))
	if _cycle.last_gifts.is_empty():
		_content.add_child(_label("Sin entregas todavía."))
	else:
		_content.add_child(_label("Última entrega:", 16))
		for gift in _cycle.last_gifts:
			_content.add_child(_label("· " + String(gift.get("name", "Bulto"))))
	_content.add_child(_label("El dron deja un disco vacío en cada entrega."))


func _set_speed(value: float) -> void:
	_cycle.clock.speed = value
	_status_text = "Velocidad ×%d" % roundi(value)
	_refresh.call_deferred()


func _sleep() -> void:
	_cycle.clock.sleep_to(6)
	_status_text = "Has dormido hasta las 06:00"
	_refresh.call_deferred()


func _deliver() -> void:
	if _cycle.deliver_task():
		_status_text = "Tarea entregada"
	else:
		_status_text = "No hay señales suficientes para la tarea"
	_refresh.call_deferred()


func _buy(item_id: String) -> void:
	var result := _cycle.buy(item_id)
	if bool(result.get("ok", false)):
		_status_text = "Pedido realizado: %s" % result["item"].get("name", "")
	else:
		_status_text = String(result.get("reason", "No se pudo comprar"))
	_refresh.call_deferred()


func _on_task_ready(new_task: DailyTask) -> void:
	_status_text = "Correo: nueva tarea del día %d" % new_task.day
	_refresh.call_deferred()


func _on_task_delivered(task: DailyTask, credits: int, points: int) -> void:
	_status_text = "Tarea %d entregada: +%d créditos, +%d puntos" % [task.day, credits, points]
	_refresh.call_deferred()


func _on_task_missed(task: DailyTask, fine: int) -> void:
	_status_text = "Tarea %d perdida: -%d créditos" % [task.day, fine]
	_refresh.call_deferred()


func _on_drone(gifts: Array[Dictionary]) -> void:
	_status_text = "El dron ha dejado %d bulto(s)" % gifts.size()
	_refresh.call_deferred()


func _on_notice(text: String) -> void:
	_status_text = text
	_refresh.call_deferred()


func _on_points_changed(_value: int) -> void:
	_refresh.call_deferred()


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _label(text: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.9))
	return label
