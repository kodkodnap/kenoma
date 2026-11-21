class_name SignalConsole
extends CanvasLayer
## Único panel que sigue en terminal: Reproducción.
## Downloads y Coordinates son físicos (`DownloadsPanel` / `CoordinatesPanel`) y no se abren desde aquí.

const TAB_NAMES := ["REPRODUCCIÓN"]

@onready var viewport: SubViewport = $Frame/SubViewportContainer/SubViewport
@onready var ui_root: Control = $Frame/SubViewportContainer/SubViewport/Ui

var _system: SignalSystem
var _audio: SignalAudio
var _header: HBoxContainer
var _title_label: Label
var _credits_label: Label
var _tabs: HBoxContainer
var _content: VBoxContainer
var _status_label: Label
var _current_tab: int = 0
var _status_text: String = ""
var _selected_download: int = 0


func _ready() -> void:
	visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_audio = SignalAudio.new()
	_audio.name = "SignalAudio"
	add_child(_audio)
	_build_ui()


func setup(system: SignalSystem) -> void:
	_system = system
	if _system != null:
		_system.download_completed.connect(_on_download_completed)
		_system.playback_changed.connect(_on_playback_changed)
		_system.credits_changed.connect(_on_credits_changed)
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


func get_audio() -> SignalAudio:
	return _audio


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	ui_root.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_header = HBoxContainer.new()
	_title_label = _label("ESTACIÓN DE SEÑALES", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credits_label = _label("CRÉDITOS 0", 16)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header.add_child(_title_label)
	_header.add_child(_credits_label)
	root.add_child(_header)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[i]
		button.pressed.connect(open_tab.bind(i))
		_tabs.add_child(button)
	root.add_child(_tabs)

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
	if _system == null:
		return
	_title_label.text = "ESTACIÓN DE SEÑALES · " + TAB_NAMES[_current_tab]
	_credits_label.text = "CRÉDITOS %d" % _system.credits
	_status_label.text = _status_text if _status_text != "" else _system.status()
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()
	match _current_tab:
		0:
			_build_playback()


func _build_playback() -> void:
	if _system.download_count() == 0:
		_content.add_child(_label("Todavía no hay señales descargadas."))
		return
	_selected_download = clampi(_selected_download, 0, _system.download_count() - 1)
	var list := ItemList.new()
	list.custom_minimum_size.y = 120
	for i in _system.download_count():
		var copy: Dictionary = _system.downloads[i]
		list.add_item("%s · %.0f%% · nivel %d%s" % [
			copy["def"].display_name,
			float(copy["quality"]) * 100.0,
			int(copy["level"]),
			" · DB" if bool(copy["saved"]) else "",
		])
	list.select(_selected_download)
	list.item_selected.connect(_on_download_selected)
	_content.add_child(list)

	var def: SignalDef = _system.downloads[_selected_download]["def"]
	var preview := TextureRect.new()
	preview.texture = SignalArt.texture_for(def)
	preview.custom_minimum_size = Vector2(128, 128)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content.add_child(preview)
	_content.add_child(_label(def.description))

	var buttons := HBoxContainer.new()
	buttons.add_child(_button("REPRODUCIR", _on_play))
	buttons.add_child(_button("DETENER", _on_stop_playback))
	buttons.add_child(_button("GUARDAR EN DB", _on_save))
	buttons.add_child(_button("EXPORTAR DISCO", _on_export))
	_content.add_child(buttons)

	var sell_index := _system.unsold_disk_index()
	if sell_index >= 0:
		_content.add_child(_button("VENDER DISCO (%d créditos)" % _system.disk_value(sell_index),
			_on_sell.bind(sell_index)))
	_content.add_child(_label("Discos: %d · En la base de datos: %d" % [
		_system.disk_count(), _system.saved_count(),
	]))


func _on_download_selected(index: int) -> void:
	_selected_download = index
	_refresh.call_deferred()


func _on_play() -> void:
	_system.play_copy(_selected_download)
	_status_text = "Reproduciendo..." if _system.is_playing() else "Sin reproducción"
	_refresh.call_deferred()


func _on_stop_playback() -> void:
	_system.stop_playback()
	_refresh.call_deferred()


func _on_save() -> void:
	_system.save_copy(_selected_download)
	_status_text = _system.status()
	_refresh.call_deferred()


func _on_export() -> void:
	_system.export_copy(_selected_download)
	_status_text = _system.status()
	_refresh.call_deferred()


func _on_sell(index: int) -> void:
	_system.sell_disk(index)
	_status_text = _system.status()
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


func _on_download_completed(_copy: Dictionary) -> void:
	_status_text = _system.status()
	_refresh.call_deferred()


func _on_playback_changed(playing: bool) -> void:
	if _audio != null:
		if playing:
			var index := _system.playing_index()
			if index >= 0 and index < _system.download_count():
				var copy: Dictionary = _system.downloads[index]
				_audio.play((copy["def"] as SignalDef).audio_tone)
		else:
			_audio.stop()
	_refresh.call_deferred()


func _on_credits_changed(_value: int) -> void:
	_refresh.call_deferred()
