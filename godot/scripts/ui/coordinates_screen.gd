class_name CoordinatesScreen
extends Control
## KM-77 — PPI de la consola de coordenadas celestes.
## Radar grande y centrado (720×480); lecturas en la franja inferior.

const BG := Color(0.018, 0.060, 0.030)
const HEADER := Color(0.035, 0.095, 0.048)
const PHOSPHOR := Color(0.45, 1.0, 0.62)
const DIM := Color(0.17, 0.38, 0.24)
const BRIGHT := Color(0.75, 1.0, 0.85)
const AMBER := Color(1.0, 0.78, 0.32)

const SCOPE_CENTER := Vector2(360.0, 204.0)
const SCOPE_RADIUS := 164.0

var _system: SignalSystem
var _sweep: float = 0.0
var _time: float = 0.0
var _flash: float = 0.0
var _scan_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(system: SignalSystem) -> void:
	_system = system
	if _system != null:
		_system.scan_completed.connect(_on_scan_completed)


func _on_scan_completed(_found: bool, message: String) -> void:
	_flash = 1.4
	_scan_text = message


func _process(delta: float) -> void:
	_time += delta
	_sweep = fposmod(_sweep + delta * 0.9, TAU)
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	# Halo de fósforo y líneas de barrido del tubo.
	for i in range(6, 0, -1):
		draw_circle(SCOPE_CENTER, SCOPE_RADIUS + float(i) * 26.0, Color(0.10, 0.34, 0.17, 0.035))
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(0.0, float(y)), Vector2(size.x, float(y)), Color(0.0, 0.0, 0.0, 0.09), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), HEADER, false, 2.0)
	draw_rect(Rect2(0.0, 0.0, size.x, 30.0), HEADER)
	_text(font, Vector2(14.0, 20.0), "KM-77 · COORDENADAS CELESTES", 14, PHOSPHOR)
	var led := AMBER if int(_time * 2.0) % 2 == 0 else PHOSPHOR
	draw_circle(Vector2(692.0, 15.0), 5.0, led)
	_draw_scope(font)
	_draw_readouts(font)


func _draw_scope(font: Font) -> void:
	var c := SCOPE_CENTER
	var r := SCOPE_RADIUS
	draw_circle(c, r + 12.0, Color(0.02, 0.06, 0.032))
	draw_circle(c, r, Color(0.016, 0.048, 0.026))
	draw_arc(c, r, 0.0, TAU, 128, PHOSPHOR, 2.5, true)
	for factor in [0.33, 0.66]:
		draw_arc(c, r * factor, 0.0, TAU, 96, Color(PHOSPHOR, 0.38), 1.2, true)
	# Cruz de enfilado y marcas cardinales.
	draw_line(c - Vector2(r, 0.0), c + Vector2(r, 0.0), Color(PHOSPHOR, 0.35), 1.2)
	draw_line(c - Vector2(0.0, r), c + Vector2(0.0, r), Color(PHOSPHOR, 0.35), 1.2)
	_text(font, c + Vector2(-5.0, -r + 20.0), "N", 14, DIM)
	_text(font, c + Vector2(r - 22.0, 5.0), "E", 14, DIM)
	_text(font, c + Vector2(-5.0, r - 9.0), "S", 14, DIM)
	_text(font, c + Vector2(-r + 8.0, 5.0), "O", 14, DIM)
	# Huellas de los tres radares (convergen hacia la portadora).
	for i in 3:
		var bearing := _system.radar_bearing(i) if _system != null else 0.0
		var a := -PI / 2.0 + deg_to_rad(bearing)
		var dir := Vector2(cos(a), sin(a))
		var end := c + dir * (r - 8.0)
		draw_line(c, end, Color(PHOSPHOR, 0.7 - float(i) * 0.18), 2.5 - float(i) * 0.5)
		draw_circle(end, 4.0 - float(i) * 0.7, AMBER if _flash > 0.0 else PHOSPHOR)
	# Barrido con estela.
	for trail in range(5):
		var a := _sweep - float(trail) * 0.13
		var alpha := 1.0 - float(trail) * 0.22
		draw_line(c, c + Vector2(cos(a), sin(a)) * (r - 4.0), Color(PHOSPHOR, alpha), 2.0)
	draw_circle(c, 3.0, BRIGHT)
	# Sello LOCK cuando la portadora queda alineada.
	if _system != null and _system.selected_def != null and _system.alignment() >= 0.55:
		var box := Rect2(c + Vector2(-56.0, r * 0.42), Vector2(112.0, 28.0))
		draw_rect(box, Color(AMBER, 0.18))
		draw_rect(box, AMBER, false, 2.0)
		_text(font, box.position + Vector2(28.0, 20.0), "LOCK", 18, AMBER)


func _draw_readouts(font: Font) -> void:
	var line_y := 384.0
	draw_line(Vector2(14.0, line_y), Vector2(706.0, line_y), DIM, 1.0)

	_text(font, Vector2(16.0, 400.0), "AZIMUT", 11, DIM)
	_text(font, Vector2(16.0, 422.0), "%05.1f°" % (_system.azimuth if _system != null else 0.0),
		20, BRIGHT)
	_text(font, Vector2(180.0, 400.0), "ELEVACIÓN", 11, DIM)
	_text(font, Vector2(180.0, 422.0), "%04.1f°" % (_system.elevation if _system != null else 0.0),
		20, BRIGHT)

	var def: SignalDef = _system.selected_def if _system != null else null
	_text(font, Vector2(300.0, 400.0), "PORTADORA", 11, DIM)
	var name := def.display_name if def != null else "SIN PORTADORA"
	_text(font, Vector2(300.0, 422.0), name, 17, PHOSPHOR if def != null else DIM)

	# Tres ruedas de radar en una sola línea.
	for i in 3:
		var bearing := _system.radar_bearing(i) if _system != null else 0.0
		var x := 16.0 + float(i) * 138.0
		draw_circle(Vector2(x + 5.0, 444.0), 4.5, [PHOSPHOR, AMBER, Color(0.6, 0.8, 1.0)][i])
		_text(font, Vector2(x + 16.0, 449.0), "RADAR %d  %05.1f°" % [i + 1, bearing], 12, PHOSPHOR)

	# Barra de alineación de la cadena, a la derecha de los radares.
	_text(font, Vector2(512.0, 441.0), "ALINEACIÓN", 9, DIM)
	var bar := Rect2(Vector2(512.0, 446.0), Vector2(174.0, 10.0))
	draw_rect(bar, Color(0.05, 0.12, 0.07))
	var fill := _system.alignment() if _system != null else 0.0
	if fill > 0.0:
		var tone := PHOSPHOR if fill >= 0.55 else AMBER
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), tone)
	draw_rect(bar, DIM, false, 1.0)

	var foot := _scan_text
	if foot == "" and _system != null:
		foot = _system.status()
	_text(font, Vector2(16.0, 472.0), foot, 11, BRIGHT if _flash > 0.0 else DIM)


func _text(font: Font, pos: Vector2, text: String, size_px: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
