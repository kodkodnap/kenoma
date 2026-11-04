class_name CrtScreen
extends Control
## Fondo animado de un CRT de fósforo verde: rejilla, traza, barrido, parpadeo y viñeta.
## No dibuja texto: las etiquetas se superponen como hijos del panel.

const GREEN := Color(0.55, 1.0, 0.7)
const AMBER := Color(1.0, 0.72, 0.3)

var trace_rect := Rect2(28.0, 54.0, 584.0, 104.0)
var progress_rect := Rect2(28.0, 300.0, 260.0, 14.0)
var signal_level: float = 0.0
var stability: float = 0.4
var downloading: bool = false
var progress: float = 0.0
var powered: bool = true

var _phase: float = 0.0
var _blink: float = 0.0


func _process(delta: float) -> void:
	_phase += delta
	_blink += delta
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color(0.012, 0.03, 0.021) if powered else Color(0.008, 0.012, 0.01))
	if not powered:
		return
	# Resplandor general del tubo.
	draw_rect(area, Color(0.08, 0.18, 0.12, 0.18))
	_draw_grid()
	_draw_trace()
	_draw_progress()
	_draw_scanlines(area)
	_draw_vignette(area)
	_draw_band(area)


func _draw_grid() -> void:
	var step := 32.0
	var column := trace_rect.position.x
	while column <= trace_rect.end.x:
		draw_line(Vector2(column, trace_rect.position.y), Vector2(column, trace_rect.end.y),
			Color(0.3, 1.0, 0.55, 0.07), 1.0)
		column += step
	var row := trace_rect.position.y
	while row <= trace_rect.end.y:
		draw_line(Vector2(trace_rect.position.x, row), Vector2(trace_rect.end.x, row),
			Color(0.3, 1.0, 0.55, 0.07), 1.0)
		row += step
	draw_line(Vector2(trace_rect.position.x, trace_rect.get_center().y),
		Vector2(trace_rect.end.x, trace_rect.get_center().y), Color(0.4, 1.0, 0.6, 0.16), 1.0)
	draw_line(Vector2(28.0, 42.0), Vector2(612.0, 42.0), Color(0.4, 1.0, 0.6, 0.22), 1.0)
	draw_line(Vector2(28.0, 322.0), Vector2(612.0, 322.0), Color(0.4, 1.0, 0.6, 0.16), 1.0)
	# Esquinas del marco de la traza.
	var corner := Color(0.45, 1.0, 0.6, 0.45)
	var length := 10.0
	for point in [trace_rect.position, Vector2(trace_rect.end.x, trace_rect.position.y),
			trace_rect.end, Vector2(trace_rect.position.x, trace_rect.end.y)]:
		var horizontal := 1.0 if point.x < trace_rect.get_center().x else -1.0
		var vertical := 1.0 if point.y < trace_rect.get_center().y else -1.0
		draw_line(point, point + Vector2(length * horizontal, 0.0), corner, 1.5)
		draw_line(point, point + Vector2(0.0, length * vertical), corner, 1.5)


func _draw_trace() -> void:
	var amplitude := lerpf(0.08, 1.0, clampf(signal_level, 0.0, 1.0))
	var jitter := lerpf(0.16, 0.01, clampf(stability, 0.0, 1.0))
	var points := PackedVector2Array()
	var samples := 140
	for i in samples:
		var t := float(i) / float(samples - 1)
		var x := trace_rect.position.x + t * trace_rect.size.x
		var wave := sin(t * TAU * 2.6 + _phase * 4.2) * 0.5
		wave += sin(t * TAU * 9.0 - _phase * 7.0) * 0.22
		wave += sin(t * TAU * 23.0 + _phase * 2.0) * 0.08
		wave += sin(t * TAU * 71.0 + _phase * 11.0) * jitter
		var y := trace_rect.get_center().y - wave * amplitude * trace_rect.size.y * 0.38
		points.append(Vector2(x, y))
	draw_polyline(points, Color(GREEN, 0.14), 5.0, true)
	draw_polyline(points, Color(GREEN, 0.35), 3.0, true)
	draw_polyline(points, Color(GREEN, 0.95), 1.4, true)
	# Retención del fósforo: la traza anterior, desplazada.
	var ghost := PackedVector2Array()
	for point in points:
		ghost.append(point + Vector2(-6.0, 2.0))
	draw_polyline(ghost, Color(GREEN, 0.1), 1.0, true)


func _draw_progress() -> void:
	var blocks := 18
	var gap := 3.0
	var width := (progress_rect.size.x - gap * float(blocks - 1)) / float(blocks)
	var filled := int(round(clampf(progress, 0.0, 1.0) * float(blocks)))
	for i in blocks:
		var rect := Rect2(progress_rect.position.x + float(i) * (width + gap),
			progress_rect.position.y, width, progress_rect.size.y)
		if i < filled:
			draw_rect(rect, Color(GREEN, 0.82))
		else:
			draw_rect(rect, Color(GREEN, 0.1))
			draw_rect(rect, Color(GREEN, 0.28), false, 1.0)
	if downloading and fmod(_blink, 0.8) < 0.4:
		draw_rect(Rect2(progress_rect.end.x + 14.0, progress_rect.position.y + 1.0, 9.0,
			progress_rect.size.y - 2.0), Color(AMBER, 0.9))


func _draw_scanlines(area: Rect2) -> void:
	var y := 0.0
	while y < area.size.y:
		draw_line(Vector2(0.0, y), Vector2(area.size.x, y), Color(0.0, 0.02, 0.01, 0.20), 1.0)
		y += 3.0
	# Línea de sincronía vertical muy tenue que nunca está quieta.
	var drift := fmod(_phase * 34.0, area.size.x)
	draw_line(Vector2(drift, 0.0), Vector2(drift, area.size.y), Color(GREEN, 0.035), 2.0)


func _draw_vignette(area: Rect2) -> void:
	var bands := 10
	for i in bands:
		var inset := float(i) * 4.0
		var alpha := 0.055 * (1.0 - float(i) / float(bands))
		var rect := Rect2(inset, inset, area.size.x - inset * 2.0, area.size.y - inset * 2.0)
		draw_rect(rect, Color(0.0, 0.01, 0.005, alpha), false, 4.5)
	# Parpadeo lento del tubo.
	var flicker := 0.012 + 0.01 * sin(_phase * 17.0) + 0.006 * sin(_phase * 41.0)
	draw_rect(area, Color(0.7, 1.0, 0.8, maxf(0.0, flicker)))


func _draw_band(area: Rect2) -> void:
	var band_y := fmod(_phase * 26.0, area.size.y)
	draw_rect(Rect2(0.0, band_y, area.size.x, 18.0), Color(0.5, 1.0, 0.7, 0.014))
