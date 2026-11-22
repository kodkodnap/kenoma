class_name BaseLayout
extends RefCounted
## Plano de la estación Kenoma. Datos puros: sin escena ni geometría.
## Arquitectura en ladera con ala de mando en voladizo (y=4.2), garaje amplio
## debajo (y=0.0), sótano técnico (y=-4.2) y núcleo abierto de escaleras.

const WALL_HEIGHT := 4.0
const LEVEL_HEIGHT := 4.2
const DOOR_WIDTH := 2.4
const DOOR_HEIGHT := 2.8
const SIGNAL_WINDOW_WIDTH := 15.0

## Habitaciones. x/z son la esquina mínima; w/d el tamaño; y la altura del suelo.
## Las puertas/ventanas se expresan con side + at (x en muros norte/sur, z en este/oeste).
const ROOMS := [
	# --- PLANTA ALTA (y = 4.2): ALA EN VOLADIZO Y CUERPO PRINCIPAL ---
	{
		"id": "signal", "label": "SALA DE CONTROL DE SEÑALES",
		"x": -16.0, "z": -24.0, "w": 18.0, "d": 14.0, "y": 4.2,
		"doors": [
			{"side": "south", "at": -6.0, "width": 3.2, "height": 3.0},
			{"side": "east", "at": -12.5, "width": 2.2, "height": 2.8},
		],
		"windows": [
			{"side": "north", "at": -7.0, "width": SIGNAL_WINDOW_WIDTH,
				"bottom": 1.0, "height": 2.6},
			{"side": "east", "at": -18.0, "width": 5.2,
				"bottom": 1.05, "height": 2.2},
			{"side": "west", "at": -17.0, "width": 4.4,
				"bottom": 1.5, "height": 1.3},
		],
	},
	{
		"id": "drone_terrace", "label": "TERRAZA DEL DRON",
		"x": 2.0, "z": -22.0, "w": 14.0, "d": 12.0, "y": 4.2,
		"doors": [], "walls": false, "ceiling": false,
	},
	{
		"id": "upper_hall", "label": "PASILLO PRINCIPAL",
		"x": -16.0, "z": -10.0, "w": 32.0, "d": 4.0, "y": 4.2,
		"doors": [
			{"side": "north", "at": -6.0, "width": 3.2, "height": 3.0},
			{"side": "north", "at": 7.0, "width": 2.4, "height": 2.8},
			{"side": "south", "at": -10.5, "width": 2.2, "height": 2.8},
			{"side": "south", "at": 4.0, "width": 2.2, "height": 2.8},
			{"side": "south", "at": 13.0, "width": 1.8, "height": 2.8},
			{"side": "east", "at": -8.0, "width": 3.6, "height": 3.4, "open": true},
		],
		"windows": [
			{"side": "north", "at": 12.2, "width": 3.6, "bottom": 1.1, "height": 2.0},
			{"side": "south", "at": -5.5, "width": 2.8, "bottom": 1.45, "height": 1.2},
		],
	},
	{
		"id": "server_room", "label": "SALA DE SERVIDORES",
		"x": -16.0, "z": -6.0, "w": 14.0, "d": 12.0, "y": 4.2,
		"doors": [{"side": "north", "at": -10.5, "width": 2.2, "height": 2.8}],
		"windows": [{"side": "north", "at": -5.5, "width": 2.8, "bottom": 1.45, "height": 1.2}],
	},
	{
		"id": "living", "label": "ZONA DE DESCANSO Y COCINA",
		"x": -2.0, "z": -6.0, "w": 12.0, "d": 12.0, "y": 4.2,
		"doors": [{"side": "north", "at": 4.0, "width": 2.2, "height": 2.8}],
	},
	{
		"id": "bath", "label": "BAÑO",
		"x": 10.0, "z": -6.0, "w": 6.0, "d": 12.0, "y": 4.2,
		"doors": [{"side": "north", "at": 13.0, "width": 1.8, "height": 2.8}],
	},

	# --- PLANTA BAJA (y = 0.0): GARAJE SNOWCAT, VESTÍBULO Y ALMACÉN ---
	{
		"id": "garage", "label": "GARAJE DEL SNOWCAT",
		"x": 2.0, "z": -22.0, "w": 14.0, "d": 16.0, "y": 0.0,
		"doors": [
			{"side": "north", "at": 9.0, "width": 6.4, "height": 3.5},
			{"side": "east", "at": -15.0, "width": 2.4, "height": 2.8},
			{"side": "south", "at": 9.0, "width": 2.8, "height": 2.8},
		],
		"ceiling": false,
	},
	{
		"id": "lobby", "label": "VESTÍBULO DE ENTRADA",
		"x": 16.0, "z": -22.0, "w": 10.0, "d": 12.0, "y": 0.0,
		"doors": [
			{"side": "north", "at": 21.0, "width": 3.4, "height": 3.0},
			{"side": "west", "at": -15.0, "width": 2.4, "height": 2.8},
			{"side": "east", "at": -16.0, "width": 2.4, "height": 2.8},
			{"side": "south", "at": 21.0, "width": 6.0, "height": 3.4, "open": true},
		],
	},
	{
		"id": "storage_ground", "label": "ALMACÉN DE SUMINISTROS",
		"x": 2.0, "z": -6.0, "w": 14.0, "d": 12.0, "y": 0.0,
		"doors": [
			{"side": "north", "at": 9.0, "width": 2.8, "height": 2.8},
			{"side": "east", "at": -1.5, "width": 2.6, "height": 2.8},
		],
		"ceiling": false,
	},
	{
		"id": "stairwell", "label": "ESCALERA CENTRAL",
		"x": 16.0, "z": -10.0, "w": 14.0, "d": 16.0, "y": 0.0,
		"doors": [
			{"side": "north", "at": 21.0, "width": 6.0, "height": 3.4, "open": true},
			{"side": "west", "at": -1.5, "width": 2.6, "height": 2.8},
		],
		"windows": [
			{"side": "east", "at": -2.0, "width": 5.0, "bottom": 1.1, "height": 2.1},
		],
		"floor": false, "ceiling": false,
	},

	# --- SÓTANO (y = -4.2): ENERGÍA Y BREAKER (SIN VENTANAS) ---
	{
		"id": "power_room", "label": "CUARTO DE ENERGÍA Y BREAKER",
		"x": 2.0, "z": -10.0, "w": 14.0, "d": 16.0, "y": -4.2,
		"doors": [
			{"side": "east", "at": 2.0, "width": 2.8, "height": 3.0},
		],
		"ceiling": false,
	},
]

## Cajas perimetrales adicionales (cerramiento de escalera en sótano/planta alta y caseta de azotea).
const EXTRA_WALL_RECTS := [
	# Pozo de escalera en sótano (y = -4.2); el lado oeste lo aporta power_room con su puerta.
	{
		"x": 16.0, "z": -10.0, "w": 14.0, "d": 16.0, "y": -4.2,
		"sides": ["north", "east", "south"],
		"doors": [], "windows": [],
	},
	# Pozo de escalera en planta alta (y = 4.2); el lado oeste lo cubren upper_hall + bath.
	{
		"x": 16.0, "z": -10.0, "w": 14.0, "d": 16.0, "y": 4.2,
		"sides": ["north", "east", "south"],
		"doors": [],
		"windows": [
			{"side": "north", "at": 23.0, "width": 5.6, "bottom": 1.1, "height": 2.1},
			{"side": "east", "at": -2.0, "width": 5.2, "bottom": 1.1, "height": 2.1},
		],
	},
	# Caseta de salida a la azotea (y = 8.4).
	{
		"x": 16.0, "z": 1.5, "w": 14.0, "d": 4.5, "y": 8.4,
		"wall_height": 3.0,
		"sides": ["north", "south", "west", "east"],
		"doors": [{"side": "west", "at": 3.8, "width": 2.4, "height": 2.4}],
		"windows": [{"side": "north", "at": 23.0, "width": 3.6, "bottom": 1.0, "height": 1.2}],
	},
]

const SPECIAL_ZONES := [
	{"id": "entrance", "label": "ENTRADA PRINCIPAL", "x": 21.0, "y": 0.0, "z": -25.0},
	{"id": "alt_drop_zone", "label": "ENTREGA EXTERIOR", "x": 28.0, "y": 0.0, "z": -16.0},
	{"id": "roof_access", "label": "ACCESO AL TEJADO", "x": 17.5, "y": 8.4, "z": 3.8},
	{"id": "roof", "label": "TEJADO", "x": 0.0, "y": 8.4, "z": -4.0},
]

## Plataformas de circulación y forjados parciales en el núcleo de escaleras.
const PLATFORMS := [
	# Sótano escalera completo (y = -4.2).
	{"id": "basement_stair_floor", "x": 16.0, "z": -10.0, "w": 14.0, "d": 16.0, "y": -4.2},
	# Planta baja escalera: galería oeste y antesala norte desde lobby (deja hueco central hacia sótano).
	{"id": "ground_stair_west", "x": 16.0, "z": -10.0, "w": 3.0, "d": 16.0, "y": 0.0},
	{"id": "ground_stair_north", "x": 19.0, "z": -10.0, "w": 11.0, "d": 4.0, "y": 0.0},
	# Planta alta escalera: anillo galería con hueco abierto en el centro (x: 19..27, z: -6..6).
	{"id": "upper_stair_west", "x": 16.0, "z": -10.0, "w": 3.0, "d": 16.0, "y": 4.2},
	{"id": "upper_stair_north", "x": 19.0, "z": -10.0, "w": 11.0, "d": 4.0, "y": 4.2},
	{"id": "upper_stair_east", "x": 27.0, "z": -6.0, "w": 3.0, "d": 12.0, "y": 4.2},
	# Azotea escalera: desembarco oeste y cubierta norte de escalera (deja hueco para RoofRamp en x:19..27, z:1.5..6).
	{"id": "roof_stair_west", "x": 16.0, "z": -10.0, "w": 3.0, "d": 16.0, "y": 8.4},
	{"id": "roof_stair_north", "x": 19.0, "z": -10.0, "w": 11.0, "d": 11.5, "y": 8.4},
	{"id": "roof_stair_east", "x": 27.0, "z": 1.5, "w": 3.0, "d": 4.5, "y": 8.4},
]


static func all_rooms() -> Array:
	return ROOMS.duplicate(true)


static func room_count() -> int:
	return ROOMS.size()


static func special_zones() -> Array:
	return SPECIAL_ZONES.duplicate(true)


static func platforms() -> Array:
	return PLATFORMS.duplicate(true)


## Reúne los muros de todas las habitaciones y cajas extra, fusionando tramos colineales
## en cada línea (eje, coordenada fija, altura, y) para evitar muros dobles o puertas tapadas.
static func collect_walls() -> Array:
	var lines: Dictionary = {}
	for room_variant in ROOMS:
		var room: Dictionary = room_variant
		if not bool(room.get("walls", true)):
			continue
		var sides: Array = room.get("sides", ["north", "south", "west", "east"])
		_add_rect_to_lines(lines, room, sides)

	for extra_variant in EXTRA_WALL_RECTS:
		var extra: Dictionary = extra_variant
		var sides: Array = extra.get("sides", ["north", "south", "west", "east"])
		_add_rect_to_lines(lines, extra, sides)

	var result: Array = []
	for line_variant in lines.values():
		var line: Dictionary = line_variant
		var merged_spans := _merge_spans(line["spans"])
		var all_doors: Array = line["doors"]
		var all_windows: Array = line["windows"]
		for span_variant in merged_spans:
			var span: Array = span_variant
			var u0 := float(span[0])
			var u1 := float(span[1])
			var span_doors: Array = []
			for door_variant in all_doors:
				var door: Dictionary = door_variant
				var at := float(door["at"])
				if at > u0 + 0.05 and at < u1 - 0.05:
					span_doors.append(door)
			var span_windows: Array = []
			for win_variant in all_windows:
				var win: Dictionary = win_variant
				var at := float(win["at"])
				if at > u0 + 0.05 and at < u1 - 0.05:
					span_windows.append(win)
			result.append({
				"axis": line["axis"],
				"fixed": float(line["fixed"]),
				"start": u0,
				"end": u1,
				"y": float(line["y"]),
				"wall_height": float(line["wall_height"]),
				"doors": span_doors,
				"windows": span_windows,
			})
	return result


static func _add_rect_to_lines(lines: Dictionary, rect: Dictionary, sides: Array) -> void:
	var x := float(rect["x"])
	var z := float(rect["z"])
	var w := float(rect["w"])
	var d := float(rect["d"])
	var y := float(rect["y"])
	var wall_height := float(rect.get("wall_height", WALL_HEIGHT))

	for side_variant in sides:
		var side := String(side_variant)
		var spec := _side_spec(side, x, z, w, d)
		if spec.is_empty():
			continue
		var axis := String(spec["axis"])
		var fixed := float(spec["fixed"])
		var start := float(spec["start"])
		var end := float(spec["end"])
		var key := _line_key(axis, fixed, y, wall_height)
		if not lines.has(key):
			lines[key] = {
				"axis": axis,
				"fixed": fixed,
				"y": y,
				"wall_height": wall_height,
				"spans": [],
				"doors": [],
				"windows": [],
			}
		(lines[key]["spans"] as Array).append([minf(start, end), maxf(start, end)])

	for door_variant in rect.get("doors", []):
		var door: Dictionary = door_variant
		var side := String(door["side"])
		var spec := _side_spec(side, x, z, w, d)
		if spec.is_empty():
			continue
		var key := _line_key(String(spec["axis"]), float(spec["fixed"]), y, wall_height)
		if not lines.has(key):
			continue
		var doors: Array = lines[key]["doors"]
		var at := float(door["at"])
		var width := float(door.get("width", DOOR_WIDTH))
		var height := float(door.get("height", DOOR_HEIGHT))
		var exists := false
		for existing_variant in doors:
			var existing: Dictionary = existing_variant
			if is_equal_approx(float(existing["at"]), at) \
					and is_equal_approx(float(existing["width"]), width):
				exists = true
				break
		if not exists:
			doors.append({
				"at": at,
				"width": width,
				"height": height,
				"open": bool(door.get("open", false)),
			})

	for window_variant in rect.get("windows", []):
		var window: Dictionary = window_variant
		var side := String(window["side"])
		var spec := _side_spec(side, x, z, w, d)
		if spec.is_empty():
			continue
		var key := _line_key(String(spec["axis"]), float(spec["fixed"]), y, wall_height)
		if not lines.has(key):
			continue
		var windows: Array = lines[key]["windows"]
		var at := float(window["at"])
		var width := float(window["width"])
		var exists := false
		for existing_variant in windows:
			var existing: Dictionary = existing_variant
			if is_equal_approx(float(existing["at"]), at) \
					and is_equal_approx(float(existing["width"]), width):
				exists = true
				break
		if not exists:
			windows.append({
				"at": at,
				"width": width,
				"bottom": float(window.get("bottom", 1.2)),
				"height": float(window.get("height", 1.8)),
			})


static func _side_spec(side: String, x: float, z: float, w: float, d: float) -> Dictionary:
	match side:
		"north":
			return {"axis": "x", "fixed": z, "start": x, "end": x + w}
		"south":
			return {"axis": "x", "fixed": z + d, "start": x, "end": x + w}
		"west":
			return {"axis": "z", "fixed": x, "start": z, "end": z + d}
		"east":
			return {"axis": "z", "fixed": x + w, "start": z, "end": z + d}
	return {}


static func _line_key(axis: String, fixed: float, y: float, wall_height: float) -> String:
	return "%s|%.2f|%.2f|%.2f" % [axis, fixed, y, wall_height]


static func _merge_spans(raw_spans: Array) -> Array:
	if raw_spans.is_empty():
		return []
	var sorted := raw_spans.duplicate(true)
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var merged: Array = [sorted[0]]
	for i in range(1, sorted.size()):
		var cur: Array = sorted[i]
		var last: Array = merged[merged.size() - 1]
		if float(cur[0]) <= float(last[1]) + 0.02:
			last[1] = maxf(float(last[1]), float(cur[1]))
		else:
			merged.append(cur)
	return merged
