extends CanvasLayer
## Overlay de rendimiento (F3). Se refresca 4 veces por segundo para no ensuciar el frame.

@export var update_interval: float = 0.25

@onready var label: Label = $Panel/Margin/Label

var _elapsed: float = 0.0


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	label.text = "FPS %d\nDraw calls %d\nPrimitivas %d\nMemoria %.1f MB\nNodos %d" % [
		int(Performance.get_monitor(Performance.TIME_FPS)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	]
