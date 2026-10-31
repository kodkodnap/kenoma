class_name ScreenPanel
extends CanvasLayer
## Base de panel con SubViewport. No pausa el árbol: solo muestra su UI.

signal opened
signal closed
signal action_pressed(action: StringName)

@export var title: String = "Panel de prueba"

@onready var viewport: SubViewport = $Frame/SubViewportContainer/SubViewport
@onready var title_label: Label = $Frame/SubViewportContainer/SubViewport/Ui/Title
@onready var count_label: Label = $Frame/SubViewportContainer/SubViewport/Ui/Count
@onready var test_button: Button = $Frame/SubViewportContainer/SubViewport/Ui/TestButton
@onready var close_button: Button = $Frame/SubViewportContainer/SubViewport/Ui/CloseButton

var is_open: bool = false
var test_count: int = 0


func _ready() -> void:
	visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	title_label.text = title
	test_button.pressed.connect(_on_test_pressed)
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_test_panel"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func press_test() -> void:
	test_count += 1
	count_label.text = "Pulsaciones: %d" % test_count
	action_pressed.emit(&"test")


func _on_test_pressed() -> void:
	press_test()
