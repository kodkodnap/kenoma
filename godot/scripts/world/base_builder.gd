class_name BaseBuilder
extends Node3D
## Construye Alpha Root Base con primitivas y MultiMesh.
## La geometría estática se agrupa por material; las colisiones viven en un solo StaticBody3D.

const WALL_HEIGHT := BaseLayout.WALL_HEIGHT
const WALL_THICKNESS := 0.25
const FLOOR_THICKNESS := 0.2

const ZONE_NAMES := {
	"corridor": "PASILLO",
	"reception": "RECEPCIÓN / ADMINISTRACIÓN",
	"utility": "UTILITY CLOSET",
	"lobby": "ENTRADA / LOBBY",
	"loading": "LOADING BAY",
	"break_room": "BREAK ROOM",
	"signal": "SIGNAL PROCESSING & RESEARCH",
	"server_room": "SERVER NETWORK ROOM",
	"stairwell": "ESCALERA",
	"upper_hall": "PLANTA SUPERIOR",
	"dorm": "DORMITORIO",
	"bath": "BAÑO",
	"storage": "ALMACÉN SUPERIOR",
	"roof_access": "ACCESO AL TEJADO",
	"balcony": "BALCÓN",
	"basement_hall": "SÓTANO",
	"breaker": "BREAKER",
	"crematory": "CREMATORIO",
	"lockers": "TAQUILLAS",
	"transformer": "TRANSFORMADORES",
	"basement_storage": "ALMACÉN DEL SÓTANO",
	"basement_utility": "TALLER",
}

var zones: Dictionary = {}
var room_count: int = 0

var _materials: Dictionary = {}
var _box_batches: Dictionary = {}
var _dish_transforms: Array[Transform3D] = []
var _collision: StaticBody3D


func _ready() -> void:
	room_count = BaseLayout.room_count()
	_make_materials()
	_collision = StaticBody3D.new()
	_collision.name = "Collision"
	add_child(_collision)
	_build_rooms()
	_build_special_zones()
	_build_walls()
	_build_platforms()
	_build_stairs()
	_build_roof()
	_build_props()
	_build_signal_room()
	_build_exterior()
	_flush_batches()
	_build_lights()


func _make_materials() -> void:
	_materials["wall"] = _material(Color(0.26, 0.27, 0.28), 0.0, 0.9)
	_materials["floor"] = _material(Color(0.14, 0.15, 0.16), 0.0, 0.95)
	_materials["ceiling"] = _material(Color(0.09, 0.1, 0.11), 0.0, 1.0)
	_materials["metal"] = _material(Color(0.24, 0.27, 0.28), 0.55, 0.55)
	_materials["dark_metal"] = _material(Color(0.1, 0.12, 0.13), 0.7, 0.45)
	_materials["screen"] = _material(Color(0.03, 0.18, 0.16), 0.0, 0.35, Color(0.1, 1.0, 0.72), 2.4)
	_materials["light"] = _material(Color(1.0, 0.92, 0.75), 0.0, 0.4, Color(1.0, 0.85, 0.62), 3.0)
	_materials["snow"] = _material(Color(0.48, 0.55, 0.62), 0.0, 1.0)
	_materials["roof"] = _material(Color(0.17, 0.18, 0.2), 0.0, 0.92)
	_materials["wood"] = _material(Color(0.32, 0.22, 0.14), 0.0, 0.9)
	_materials["led_green"] = _material(Color(0.08, 0.8, 0.25), 0.0, 0.4, Color(0.1, 1.0, 0.3), 2.0)
	_materials["led_red"] = _material(Color(0.85, 0.08, 0.08), 0.0, 0.4, Color(1.0, 0.1, 0.1), 2.0)
	_materials["warning"] = _material(Color(0.75, 0.55, 0.08), 0.0, 0.7, Color(0.8, 0.45, 0.05), 0.6)
	_materials["paper"] = _material(Color(0.72, 0.7, 0.62), 0.0, 0.9)
	_materials["glass"] = MachineMaterials.glass()
	_materials["cold"] = _material(Color(0.06, 0.12, 0.2), 0.0, 1.0,
		Color(0.04, 0.12, 0.24), 0.8)


func _material(color: Color, metallic: float, roughness: float,
		emission := Color.BLACK, emission_energy := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


func _build_rooms() -> void:
	for room_variant in BaseLayout.ROOMS:
		var room: Dictionary = room_variant
		var id := StringName(room["id"])
		var x := float(room["x"])
		var z := float(room["z"])
		var w := float(room["w"])
		var d := float(room["d"])
		var y := float(room["y"])
		var cx := x + w * 0.5
		var cz := z + d * 0.5
		if bool(room.get("floor", true)):
			_box("floor", Vector3(cx, y - 0.1, cz), Vector3(w, FLOOR_THICKNESS, d))
		if bool(room.get("ceiling", true)):
			_box("ceiling", Vector3(cx, y + WALL_HEIGHT + 0.1, cz), Vector3(w, 0.2, d))
		_zone(id, String(room["label"]), Vector3(cx, y + 0.15, cz), maxf(w, d))
		if id == &"stairwell":
			_zone_light(Vector3(30.0, 2.7, 0.0), 10.0)
		elif id == &"corridor":
			for lx in [-18.0, 0.0, 18.0]:
				_zone_light(Vector3(lx, 2.9, 0.0), 11.0)
		elif id == &"signal":
			for lx in [-8.0, 8.0]:
				_zone_light(Vector3(lx, 2.9, -10.0), 13.0)
		elif id == &"upper_hall":
			for lx in [-10.0, 14.0]:
				_zone_light(Vector3(lx, 6.9, 0.0), 12.0)
		elif id == &"basement_hall":
			for lx in [-10.0, 14.0]:
				_zone_light(Vector3(lx, -1.1, 0.0), 12.0)


func _build_special_zones() -> void:
	for zone_variant in BaseLayout.SPECIAL_ZONES:
		var zone: Dictionary = zone_variant
		_zone(StringName(zone["id"]), String(zone["label"]),
			Vector3(float(zone["x"]), float(zone["y"]) + 0.15, float(zone["z"])), 14.0)


func _build_walls() -> void:
	for wall_variant in BaseLayout.collect_walls():
		var wall: Dictionary = wall_variant
		var axis := String(wall["axis"])
		var fixed := float(wall["fixed"])
		var start := float(wall["start"])
		var end := float(wall["end"])
		var y := float(wall["y"])
		var openings: Array = []
		for door_variant in wall["doors"]:
			var door: Dictionary = door_variant
			openings.append({
				"at": float(door["at"]),
				"width": float(door["width"]),
				"bottom": 0.0,
				"height": float(door["height"]),
				"window": false,
			})
		for window_variant in wall.get("windows", []):
			var window: Dictionary = window_variant
			openings.append({
				"at": float(window["at"]),
				"width": float(window["width"]),
				"bottom": float(window["bottom"]),
				"height": float(window["height"]),
				"window": true,
			})
		openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["at"]) < float(b["at"]))
		var cursor := start
		for opening_variant in openings:
			var opening: Dictionary = opening_variant
			var half := float(opening["width"]) * 0.5
			var d0 := float(opening["at"]) - half
			var d1 := float(opening["at"]) + half
			if d0 > cursor + 0.01:
				_wall_segment(axis, fixed, cursor, d0, y, 0.0, WALL_HEIGHT)
			var bottom := float(opening["bottom"])
			var height := float(opening["height"])
			if bottom > 0.01:
				_wall_segment(axis, fixed, d0, d1, y, 0.0, bottom)
			if bottom + height < WALL_HEIGHT - 0.01:
				_wall_segment(axis, fixed, d0, d1, y, bottom + height,
					WALL_HEIGHT - bottom - height)
			if opening["window"]:
				_window_frame(axis, fixed, d0, d1, y, bottom, height)
			else:
				_door_frame(axis, fixed, d0, d1, y, height)
			cursor = maxf(cursor, d1)
		if cursor < end - 0.01:
			_wall_segment(axis, fixed, cursor, end, y, 0.0, WALL_HEIGHT)


func _wall_segment(axis: String, fixed: float, from: float, to: float,
		y: float, bottom: float, height: float) -> void:
	if to - from < 0.02 or height < 0.02:
		return
	var center := Vector3.ZERO
	var size := Vector3.ZERO
	if axis == "x":
		center = Vector3((from + to) * 0.5, y + bottom + height * 0.5, fixed)
		size = Vector3(to - from, height, WALL_THICKNESS)
	else:
		center = Vector3(fixed, y + bottom + height * 0.5, (from + to) * 0.5)
		size = Vector3(WALL_THICKNESS, height, to - from)
	_box("wall", center, size)


func _door_frame(axis: String, fixed: float, from: float, to: float,
		y: float, height: float) -> void:
	var center := Vector3.ZERO
	var size := Vector3.ZERO
	if axis == "x":
		center = Vector3((from + to) * 0.5, y + height * 0.5, fixed)
		size = Vector3(to - from, height, WALL_THICKNESS)
	else:
		center = Vector3(fixed, y + height * 0.5, (from + to) * 0.5)
		size = Vector3(WALL_THICKNESS, height, to - from)
	if axis == "x":
		_box("metal", Vector3(from, y + height * 0.5, fixed),
			Vector3(0.1, height, WALL_THICKNESS + 0.06), Basis.IDENTITY, false)
		_box("metal", Vector3(to, y + height * 0.5, fixed),
			Vector3(0.1, height, WALL_THICKNESS + 0.06), Basis.IDENTITY, false)
		_box("metal", Vector3(center.x, y + height - 0.05, fixed),
			Vector3(to - from, 0.1, WALL_THICKNESS + 0.06), Basis.IDENTITY, false)
	else:
		_box("metal", Vector3(fixed, y + height * 0.5, from),
			Vector3(WALL_THICKNESS + 0.06, height, 0.1), Basis.IDENTITY, false)
		_box("metal", Vector3(fixed, y + height * 0.5, to),
			Vector3(WALL_THICKNESS + 0.06, height, 0.1), Basis.IDENTITY, false)
		_box("metal", Vector3(fixed, y + height - 0.05, center.z),
			Vector3(WALL_THICKNESS + 0.06, 0.1, to - from), Basis.IDENTITY, false)


## Hueco de ventana: marco metálico y cristal semitransparente sin colisión.
func _window_frame(axis: String, fixed: float, from: float, to: float,
		y: float, bottom: float, height: float) -> void:
	var center := (from + to) * 0.5
	var mid_y := y + bottom + height * 0.5
	var span := to - from
	var depth := WALL_THICKNESS + 0.08
	if axis == "x":
		_box("metal", Vector3(from, mid_y, fixed), Vector3(0.12, height, depth), Basis.IDENTITY, false)
		_box("metal", Vector3(to, mid_y, fixed), Vector3(0.12, height, depth), Basis.IDENTITY, false)
		_box("metal", Vector3(center, y + bottom + 0.05, fixed), Vector3(span, 0.1, depth), Basis.IDENTITY, false)
		_box("metal", Vector3(center, y + bottom + height - 0.05, fixed), Vector3(span, 0.1, depth), Basis.IDENTITY, false)
		_box("glass", Vector3(center, mid_y, fixed),
			Vector3(span - 0.12, height - 0.1, 0.03), Basis.IDENTITY, false)
	else:
		_box("metal", Vector3(fixed, mid_y, from), Vector3(depth, height, 0.12), Basis.IDENTITY, false)
		_box("metal", Vector3(fixed, mid_y, to), Vector3(depth, height, 0.12), Basis.IDENTITY, false)
		_box("metal", Vector3(fixed, y + bottom + 0.05, center), Vector3(depth, 0.1, span), Basis.IDENTITY, false)
		_box("metal", Vector3(fixed, y + bottom + height - 0.05, center), Vector3(depth, 0.1, span), Basis.IDENTITY, false)
		_box("glass", Vector3(fixed, mid_y, center),
			Vector3(0.03, height - 0.1, span - 0.12), Basis.IDENTITY, false)


func _build_platforms() -> void:
	for platform_variant in BaseLayout.PLATFORMS:
		var platform: Dictionary = platform_variant
		var x := float(platform["x"])
		var z := float(platform["z"])
		var w := float(platform["w"])
		var d := float(platform["d"])
		var y := float(platform["y"])
		_box("floor", Vector3(x + w * 0.5, y - 0.1, z + d * 0.5),
			Vector3(w, FLOOR_THICKNESS, d))
	# Barandillas de las plataformas superiores.
	_box("metal", Vector3(30.0, 5.0, 0.08), Vector3(8.0, 1.0, 0.1))
	_box("metal", Vector3(33.0, 5.0, 2.0), Vector3(14.0, 1.0, 0.1))
	_box("metal", Vector3(40.0, 5.0, 0.0), Vector3(0.1, 1.0, 4.0))
	_box("metal", Vector3(37.0, 5.0, -2.0), Vector3(6.0, 1.0, 0.1))
	# Pozo del sótano: muros que cierran la excavación.
	_box("wall", Vector3(40.0, -2.0, 0.0), Vector3(0.3, 4.0, 4.0))
	_box("wall", Vector3(37.0, -2.0, -2.0), Vector3(6.0, 4.0, 0.3))
	_box("wall", Vector3(37.0, -2.0, 2.0), Vector3(6.0, 4.0, 0.3))
	# Pozo de la escalera superior y cubierta del hueco.
	_box("wall", Vector3(40.0, 6.0, 0.0), Vector3(0.3, 5.0, 4.0))
	_box("wall", Vector3(33.0, 6.0, -2.0), Vector3(14.0, 5.0, 0.3))
	_box("wall", Vector3(33.0, 6.0, 2.0), Vector3(14.0, 5.0, 0.3))
	_box("roof", Vector3(33.0, 8.4, 0.0), Vector3(14.0, 0.2, 4.0))


func _build_stairs() -> void:
	_make_ramp("StairsUp", Vector3(26.0, 0.0, -1.0), Vector3(34.0, 4.0, -1.0), 1.6)
	_make_ramp("StairsDown", Vector3(26.0, 0.0, 1.0), Vector3(34.0, -4.0, 1.0), 1.6)
	_make_ramp("RoofRamp", Vector3(12.0, 4.0, 7.0), Vector3(24.0, 7.6, 7.0), 1.6)


func _make_ramp(ramp_name: String, from: Vector3, to: Vector3, width: float) -> void:
	var direction := to - from
	var length := direction.length()
	var angle := atan2(direction.y, direction.x)
	var basis := Basis(Vector3(0.0, 0.0, 1.0), angle)
	var body := StaticBody3D.new()
	body.name = ramp_name
	body.add_to_group("base_ramp")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.2, width)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _materials["metal"]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	body.transform = Transform3D(basis, (from + to) * 0.5)
	add_child(body)
	var rail_offset := Vector3(0.0, 0.85, width * 0.5)
	_box("metal", (from + to) * 0.5 + basis * rail_offset,
		Vector3(length, 0.06, 0.06), basis, false)
	_box("metal", (from + to) * 0.5 + basis * Vector3(0.0, 0.85, -width * 0.5),
		Vector3(length, 0.06, 0.06), basis, false)


func _build_roof() -> void:
	# Tejado con un hueco para la rampa de acceso.
	_box("roof", Vector3(-4.0, 7.5, 0.0), Vector3(32.0, 0.2, 32.0))
	_box("roof", Vector3(19.0, 7.5, -5.0), Vector3(14.0, 0.2, 22.0))
	_box("roof", Vector3(19.0, 7.5, 12.0), Vector3(14.0, 0.2, 8.0))
	_box("roof", Vector3(25.0, 7.5, 7.0), Vector3(2.0, 0.2, 2.0))
	# Peto perimetral.
	_box("metal", Vector3(3.0, 8.2, -16.0), Vector3(46.0, 1.0, 0.12))
	_box("metal", Vector3(3.0, 8.2, 16.0), Vector3(46.0, 1.0, 0.12))
	_box("metal", Vector3(-20.0, 8.2, 0.0), Vector3(0.12, 1.0, 32.0))
	_box("metal", Vector3(26.0, 8.2, 0.0), Vector3(0.12, 1.0, 32.0))
	# Equipos de cubierta.
	_box("dark_metal", Vector3(-8.0, 8.0, -8.0), Vector3(3.0, 1.2, 2.0))
	_box("dark_metal", Vector3(4.0, 8.0, 10.0), Vector3(2.0, 1.0, 2.0))
	_box("metal", Vector3(-2.0, 8.2, 6.0), Vector3(0.3, 1.4, 0.3))
	_box("dark_metal", Vector3(1.0, 8.7, 6.0), Vector3(2.0, 0.4, 2.0))
	_zone(&"roof", "TEJADO", Vector3(0.0, 7.8, 0.0), 18.0)
	_zone_light(Vector3(0.0, 9.0, 0.0), 16.0, 3.5)
	_zone_light(Vector3(-14.0, 9.0, -12.0), 14.0, 3.0)
	_zone_light(Vector3(22.0, 9.0, 12.0), 14.0, 3.0)


func _build_props() -> void:
	# Recepción / administración.
	_box("wood", Vector3(-21.0, 0.65, 7.0), Vector3(3.2, 1.2, 1.2))
	_box("dark_metal", Vector3(-21.0, 1.35, 7.0), Vector3(1.2, 0.5, 0.08))
	_box("wood", Vector3(-21.0, 0.45, 8.4), Vector3(0.7, 0.8, 0.7))
	_box("metal", Vector3(-25.2, 1.0, 14.0), Vector3(0.8, 1.8, 2.2))
	_box("metal", Vector3(-25.2, 1.0, 16.5), Vector3(0.8, 1.8, 2.2))
	_note("INVENTARIO\nPENDIENTE", Vector3(-22.0, 2.4, 2.2))
	# Utility closet: el TestMachine vive aquí, dejar el centro libre.
	_box("metal", Vector3(-12.6, 0.9, 6.0), Vector3(0.6, 1.8, 3.0))
	_box("metal", Vector3(-12.6, 0.9, 14.0), Vector3(0.6, 1.8, 3.0))
	_box("warning", Vector3(-10.0, 2.6, 17.7), Vector3(1.2, 0.5, 0.1))
	_note("PIEZAS DE REPUESTO", Vector3(-10.0, 2.4, 17.5))
	# Lobby.
	_box("wood", Vector3(-5.0, 0.45, 11.0), Vector3(2.6, 0.8, 0.8))
	_box("wood", Vector3(-5.0, 0.9, 11.0), Vector3(2.6, 0.1, 0.8))
	_box("wood", Vector3(7.2, 0.55, 16.2), Vector3(1.0, 1.1, 1.0))
	_box("led_green", Vector3(7.2, 1.0, 16.7), Vector3(0.5, 0.08, 0.05), Basis.IDENTITY, false)
	_box("dark_metal", Vector3(8.8, 1.7, 9.0), Vector3(0.08, 1.2, 2.0))
	_note("DIRECTORIO\nPLANTA 0", Vector3(8.6, 2.2, 9.0))
	# Loading bay / garaje.
	for i in 3:
		_box("wood", Vector3(11.2 + i * 1.3, 0.55, 5.0), Vector3(1.0, 1.1, 1.0))
	_box("wood", Vector3(12.0, 1.55, 5.0), Vector3(1.0, 1.0, 1.0))
	_box("metal", Vector3(21.0, 0.6, 4.5), Vector3(3.2, 1.2, 1.0))
	_box("dark_metal", Vector3(21.0, 1.5, 4.5), Vector3(2.4, 0.5, 0.6))
	# ATV placeholder.
	_box("warning", Vector3(21.0, 0.75, 13.0), Vector3(2.2, 0.5, 1.2))
	_box("dark_metal", Vector3(21.0, 1.1, 13.0), Vector3(1.2, 0.55, 0.6))
	for wheel_x in [20.0, 22.0]:
		for wheel_z in [12.5, 13.5]:
			_box("dark_metal", Vector3(wheel_x, 0.45, wheel_z), Vector3(0.45, 0.45, 0.25))
	# Break room.
	_box("wood", Vector3(-20.0, 0.65, -10.0), Vector3(3.0, 1.2, 1.5))
	for chair_x in [-21.4, -18.6]:
		_box("dark_metal", Vector3(chair_x, 0.45, -8.8), Vector3(0.6, 0.8, 0.6))
	_box("metal", Vector3(-25.0, 0.95, -16.0), Vector3(1.2, 1.9, 1.0))
	_box("dark_metal", Vector3(-15.0, 1.0, -16.2), Vector3(1.4, 1.8, 1.0))
	_box("led_green", Vector3(-15.0, 1.5, -15.7), Vector3(0.7, 0.4, 0.05), Basis.IDENTITY, false)
	_note("NO USAR EL MICROONDAS\nDESPUÉS DE LAS 03:00", Vector3(-22.0, 2.2, -17.7))
	# Signal Processing: cuatro paneles y consola de radar.
	# Los 1 y 2 (Coordinates y Descargas) son consolas físicas completas: no llevan caja de relleno.
	for i in 4:
		var px := -9.0 + i * 6.0
		if i > 1 and i < 3:
			_box("dark_metal", Vector3(px, 1.25, -17.55), Vector3(2.1, 1.5, 0.5))
			_box("screen", Vector3(px, 1.35, -17.25), Vector3(1.7, 0.95, 0.05),
				Basis.IDENTITY, false)
		_add_panel(px, -17.2, i)
		if i > 1 and i < 3:
			_note("PANEL %d" % (i + 1), Vector3(px, 2.45, -17.4))
	_box("dark_metal", Vector3(0.0, 0.85, -9.0), Vector3(2.4, 1.7, 1.8))
	_box("screen", Vector3(0.0, 1.1, -8.05), Vector3(1.6, 1.0, 0.05), Basis.IDENTITY, false)
	_box("dark_metal", Vector3(0.0, 1.8, -9.0), Vector3(2.0, 0.2, 1.4))
	for chair_x in [-2.0, 2.0]:
		_box("dark_metal", Vector3(chair_x, 0.45, -7.4), Vector3(0.6, 0.8, 0.6))
	# Servidores: 30 racks y sus marcadores.
	for row in 6:
		for col in 5:
			var sx := 15.6 + col * 2.2
			var sz := -16.5 + row * 2.2
			_box("dark_metal", Vector3(sx, 1.0, sz), Vector3(1.2, 2.0, 0.6))
			_box("led_green", Vector3(sx - 0.3, 1.65, sz + 0.31), Vector3(0.08, 0.08, 0.03), Basis.IDENTITY, false)
			_box("led_red", Vector3(sx + 0.3, 1.65, sz + 0.31), Vector3(0.08, 0.08, 0.03), Basis.IDENTITY, false)
			var marker := Marker3D.new()
			marker.name = "Server_%02d_%02d" % [row, col]
			marker.position = Vector3(sx, 0.0, sz)
			marker.add_to_group("server_placeholder")
			add_child(marker)
	_note("RED DE SERVIDORES\n30 NODOS", Vector3(20.0, 2.4, -17.7))
	# Sótano: breaker y cables.
	_box("dark_metal", Vector3(-13.0, -2.55, -13.55), Vector3(2.8, 1.8, 0.35))
	for i in 5:
		var sy := -3.1 + i * 0.3
		_box("warning", Vector3(-14.0 + i * 0.5, sy, -13.3), Vector3(0.28, 0.12, 0.12))
	_box("warning", Vector3(-13.0, -1.5, -13.5), Vector3(1.4, 0.25, 0.1))
	var breaker := Node3D.new()
	breaker.name = "Breaker"
	breaker.position = Vector3(-13.0, -3.5, -13.45)
	breaker.add_to_group("breaker")
	add_child(breaker)
	_note("BREAKER PRINCIPAL\nNO REARMAR CON CARGA", Vector3(-17.0, -1.5, -13.4))
	# Transformadores interiores (control).
	for i in 3:
		_box("dark_metal", Vector3(-18.0 + i * 5.0, -2.55, 11.55), Vector3(2.2, 2.4, 0.8))
		_box("screen", Vector3(-18.0 + i * 5.0, -2.2, 11.1), Vector3(1.0, 0.5, 0.04), Basis.IDENTITY, false)
	# Crematorio.
	_box("dark_metal", Vector3(4.0, -2.6, -11.0), Vector3(3.0, 2.6, 2.4))
	_box("warning", Vector3(4.0, -2.6, -9.7), Vector3(1.2, 1.2, 0.1))
	_box("metal", Vector3(4.0, -0.8, -11.0), Vector3(0.6, 2.0, 0.6))
	var crematory := Node3D.new()
	crematory.name = "Crematory"
	crematory.position = Vector3(4.0, -2.6, -11.0)
	crematory.add_to_group("crematory")
	add_child(crematory)
	# Taquillas.
	for i in 6:
		_box("metal", Vector3(8.7, -2.75, -12.0 + i * 1.4), Vector3(0.6, 2.2, 1.1))
	var lockers := Node3D.new()
	lockers.name = "Lockers"
	lockers.position = Vector3(8.7, -2.75, -9.0)
	lockers.add_to_group("lockers")
	add_child(lockers)
	_box("wood", Vector3(13.0, -3.45, -7.0), Vector3(3.0, 0.5, 0.8))
	# Almacenes y taller.
	for i in 3:
		_box("wood", Vector3(-4.0 + i * 2.0, -3.3, 11.3), Vector3(1.6, 1.2, 0.8))
		_box("wood", Vector3(10.0 + i * 2.0, -3.2, 11.2), Vector3(1.6, 1.4, 0.8))
	_box("metal", Vector3(14.0, -3.0, 7.0), Vector3(3.0, 2.0, 1.0))
	# Dormitorio.
	_box("wood", Vector3(-17.0, 4.3, -10.0), Vector3(2.2, 0.5, 3.5))
	_box("paper", Vector3(-17.0, 4.62, -10.0), Vector3(2.0, 0.12, 3.3))
	_box("wood", Vector3(-6.0, 4.55, -13.0), Vector3(2.2, 0.8, 1.0))
	_box("wood", Vector3(-19.0, 5.0, -5.0), Vector3(1.2, 2.0, 2.6))
	_note("TURNO DE NOCHE\n06:00", Vector3(-17.0, 5.4, -15.7))
	# Baño.
	_box("paper", Vector3(-18.0, 4.4, 9.0), Vector3(0.7, 0.8, 1.0))
	_box("paper", Vector3(-18.0, 4.5, 4.0), Vector3(1.2, 0.4, 0.8))
	_box("paper", Vector3(-6.0, 4.3, 9.0), Vector3(2.4, 0.6, 3.8))
	# Almacén superior.
	for i in 4:
		_box("metal", Vector3(-3.0 + i * 2.2, 5.0, -15.4), Vector3(1.4, 2.0, 0.6))
	_box("wood", Vector3(7.0, 4.45, -10.0), Vector3(1.2, 1.0, 1.2))
	# Acceso al tejado: rampa y armario de control.
	_box("dark_metal", Vector3(11.0, 4.7, 3.5), Vector3(1.2, 1.4, 0.6))
	_box("warning", Vector3(18.0, 6.9, 3.6), Vector3(0.8, 0.4, 0.1))
	# Balcón.
	_box("metal", Vector3(-8.0, 4.5, -21.8), Vector3(8.0, 1.0, 0.1))
	_box("metal", Vector3(-11.9, 4.5, -19.0), Vector3(0.1, 1.0, 6.0))
	_box("metal", Vector3(-4.1, 4.5, -19.0), Vector3(0.1, 1.0, 6.0))
	_box("wood", Vector3(-8.0, 4.45, -20.8), Vector3(2.2, 0.5, 0.5))
	# Cubierta: antena y respiraderos.
	for i in 4:
		_box("metal", Vector3(-12.0 + i * 7.0, 8.0, 0.0), Vector3(0.4, 0.6, 0.4))


## Detalle propio de Signal Processing: ventanal, mobiliario y luz fría/ámbar.
func _build_signal_room() -> void:
	var window := _signal_detail("SignalWindow", Vector3(0.0, 2.3, -18.0))
	window.set_meta("width", BaseLayout.SIGNAL_WINDOW_WIDTH)
	# Exterior frío tras el cristal: campo de nieve, horizonte y picos recortados.
	# Antes había un panel opaco aquí y el hueco se leía como una pantalla azul.
	_box("snow", Vector3(0.0, -0.05, -32.0), Vector3(70.0, 0.3, 28.0), Basis.IDENTITY, false)
	_box("cold", Vector3(0.0, 5.0, -72.0), Vector3(90.0, 10.0, 0.5), Basis.IDENTITY, false)
	for peak_variant in [{"x": -9.0, "h": 6.0, "z": -52.0},
			{"x": 0.0, "h": 4.0, "z": -44.0}, {"x": 9.0, "h": 7.0, "z": -58.0}]:
		var peak: Dictionary = peak_variant
		var px := float(peak["x"])
		var ph := float(peak["h"])
		var pz := float(peak["z"])
		var tilt := atan(ph / 5.0)
		var slope := sqrt(ph * ph + 25.0)
		_box("dark_metal", Vector3(px - 2.5, ph * 0.5, pz),
			Vector3(slope, 0.7, 1.2), Basis(Vector3.BACK, tilt), false)
		_box("dark_metal", Vector3(px + 2.5, ph * 0.5, pz),
			Vector3(slope, 0.7, 1.2), Basis(Vector3.BACK, -tilt), false)

	_signal_detail("TarimaBaja", Vector3(0.0, 0.07, -14.0))
	_box("wood", Vector3(0.0, 0.06, -14.0), Vector3(24.0, 0.12, 6.0), Basis.IDENTITY, false)

	_signal_detail("ArcoConsolas", Vector3(0.0, 2.85, -16.4))
	for i in 5:
		var ax := -10.0 + i * 5.0
		var az := -16.2 - 0.5 * cos(TAU * float(i) / 8.0)
		var tilt := 0.12 * (float(i) - 2.0)
		_box("dark_metal", Vector3(ax, 2.85, az), Vector3(5.0, 0.16, 0.16),
			Basis(Vector3.UP, tilt), false)

	_signal_detail("RadarPared", Vector3(-13.7, 2.0, -9.0))
	_box("dark_metal", Vector3(-13.85, 2.0, -9.0), Vector3(0.22, 1.1, 1.1), Basis.IDENTITY, false)
	_box("screen", Vector3(-13.7, 2.1, -9.0), Vector3(0.05, 0.8, 0.8), Basis.IDENTITY, false)
	_box("metal", Vector3(-13.5, 2.0, -9.0), Vector3(0.06, 0.9, 0.06), Basis.IDENTITY, false)

	_signal_detail("MesaDiscos", Vector3(-8.0, 0.8, -12.0))
	_box("wood", Vector3(-8.0, 0.8, -12.0), Vector3(2.6, 0.12, 1.2), Basis.IDENTITY, false)
	for dx in [-1.1, 1.1]:
		for dz in [-0.45, 0.45]:
			_box("dark_metal", Vector3(-8.0 + dx, 0.4, -12.0 + dz),
				Vector3(0.1, 0.8, 0.1), Basis.IDENTITY, false)
	for i in 3:
		_box("metal", Vector3(-8.8 + i * 0.8, 0.88, -12.0),
			Vector3(0.5, 0.03, 0.5), Basis.IDENTITY, false)

	_signal_detail("Papeles", Vector3(8.0, 0.9, -12.0))
	_box("wood", Vector3(8.0, 0.75, -12.0), Vector3(2.2, 0.1, 1.0), Basis.IDENTITY, false)
	for i in 4:
		_box("paper", Vector3(7.4 + i * 0.4, 0.82, -12.0 + 0.1 * float(i % 2)),
			Vector3(0.3, 0.01, 0.42), Basis(Vector3.UP, 0.2 * float(i) - 0.3), false)

	_signal_detail("Cableado", Vector3(6.0, 0.12, -15.5))
	for i in 3:
		_box("dark_metal", Vector3(-3.0 + i * 6.0, 0.05, -15.6),
			Vector3(6.0, 0.05, 0.05), Basis.IDENTITY, false)
	_box("dark_metal", Vector3(-13.7, 1.2, -9.0), Vector3(0.05, 2.4, 0.05), Basis.IDENTITY, false)

	_signal_detail("LamparaAmbar", Vector3(-11.0, 2.6, -15.0))
	_box("metal", Vector3(-11.0, 2.2, -15.0), Vector3(0.06, 0.7, 0.06), Basis.IDENTITY, false)
	_box("light", Vector3(-11.0, 2.6, -15.0), Vector3(0.3, 0.18, 0.3), Basis.IDENTITY, false)
	_signal_detail("LamparaAzul", Vector3(11.0, 2.6, -15.0))
	_box("metal", Vector3(11.0, 2.2, -15.0), Vector3(0.06, 0.7, 0.06), Basis.IDENTITY, false)
	_box("cold", Vector3(11.0, 2.6, -15.0), Vector3(0.3, 0.18, 0.3), Basis.IDENTITY, false)


func _signal_detail(detail_name: String, position: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = detail_name
	marker.position = position
	marker.add_to_group("signal_room_detail")
	add_child(marker)
	return marker


func _add_panel(px: float, pz: float, index: int) -> void:
	var panel := Node3D.new()
	panel.name = "SignalPanel%d" % (index + 1)
	panel.position = Vector3(px, 1.25, pz)
	panel.add_to_group("signal_panel")
	if index > 1:
		var label := Label3D.new()
		label.text = "SIG %d" % (index + 1)
		label.font_size = 28
		label.pixel_size = 0.007
		label.modulate = Color(0.4, 1.0, 0.8)
		label.position = Vector3(0.0, 0.85, 0.05)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		panel.add_child(label)
	add_child(panel)


func _build_exterior() -> void:
	# Suelo de nieve en anillo, sin cubrir la base ni la escalera.
	_box("snow", Vector3(0.0, -0.2, -69.0), Vector3(240.0, 0.4, 102.0))
	_box("snow", Vector3(0.0, -0.2, 69.0), Vector3(240.0, 0.4, 102.0))
	_box("snow", Vector3(-73.0, -0.2, 0.0), Vector3(94.0, 0.4, 36.0))
	_box("snow", Vector3(80.0, -0.2, 0.0), Vector3(80.0, 0.4, 36.0))
	_box("snow", Vector3(33.0, -0.2, -10.0), Vector3(14.0, 0.4, 16.0))
	_box("snow", Vector3(33.0, -0.2, 10.0), Vector3(14.0, 0.4, 16.0))
	# Valla perimetral.
	_box("metal", Vector3(0.0, 1.2, -110.0), Vector3(220.0, 2.4, 0.2))
	_box("metal", Vector3(0.0, 1.2, 110.0), Vector3(220.0, 2.4, 0.2))
	_box("metal", Vector3(-110.0, 1.2, 0.0), Vector3(0.2, 2.4, 220.0))
	_box("metal", Vector3(110.0, 1.2, 0.0), Vector3(0.2, 2.4, 220.0))
	# 24 platos.
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var px := cos(angle) * 55.0
		var pz := sin(angle) * 55.0
		var dish := Marker3D.new()
		dish.name = "Dish%02d" % (i + 1)
		dish.position = Vector3(px, 0.0, pz)
		dish.add_to_group("satellite_dish")
		add_child(dish)
		_box("metal", Vector3(px, 0.15, pz), Vector3(1.2, 0.3, 1.2))
		_box("metal", Vector3(px, 1.5, pz), Vector3(0.28, 3.0, 0.28))
		_dish_transforms.append(Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.55),
			Vector3(px, 3.25, pz)))
		if i < 3:
			_note("SAT-%02d" % (i + 1), Vector3(px, 4.8, pz))
	# Transformadores exteriores.
	for i in 3:
		var tx := 32.0
		var tz := 4.0 + i * 5.0
		var transformer := Node3D.new()
		transformer.name = "Transformer%d" % (i + 1)
		transformer.position = Vector3(tx, 0.0, tz)
		transformer.add_to_group("transformer")
		add_child(transformer)
		_box("metal", Vector3(tx, 0.2, tz), Vector3(3.0, 0.4, 2.2))
		_box("dark_metal", Vector3(tx, 1.4, tz), Vector3(2.4, 2.2, 1.6))
		for fin in 4:
			_box("metal", Vector3(tx - 0.8 + fin * 0.55, 1.4, tz + 0.85),
				Vector3(0.35, 1.8, 0.1))
		_box("warning", Vector3(tx, 2.2, tz + 0.82), Vector3(0.8, 0.4, 0.08))
		_note("TRAFO %s" % ["A", "B", "C"][i], Vector3(tx, 3.2, tz))
	# Radares de coordenadas.
	var radar_positions := [Vector3(-45.0, 0.0, -35.0), Vector3(45.0, 0.0, -35.0),
		Vector3(0.0, 0.0, 50.0)]
	for i in 3:
		var rp: Vector3 = radar_positions[i]
		var radar := Node3D.new()
		radar.name = "CoordinateRadar%d" % (i + 1)
		radar.position = rp
		radar.add_to_group("coordinate_radar")
		add_child(radar)
		_box("metal", Vector3(rp.x, 0.2, rp.z), Vector3(2.0, 0.4, 2.0))
		_box("metal", Vector3(rp.x, 3.0, rp.z), Vector3(0.5, 6.0, 0.5))
		_box("dark_metal", Vector3(rp.x, 6.0, rp.z), Vector3(2.6, 0.2, 2.6))
		_note("RADAR %d" % (i + 1), Vector3(rp.x, 7.2, rp.z))
	# Turbinas eólicas.
	var turbine_positions := [Vector3(-70.0, 0.0, -70.0), Vector3(70.0, 0.0, -70.0),
		Vector3(-70.0, 0.0, 70.0), Vector3(70.0, 0.0, 70.0)]
	for i in 4:
		var tp: Vector3 = turbine_positions[i]
		var turbine := Node3D.new()
		turbine.name = "WindTurbine%d" % (i + 1)
		turbine.position = tp
		turbine.add_to_group("wind_turbine")
		add_child(turbine)
		_box("metal", Vector3(tp.x, 9.0, tp.z), Vector3(1.2, 18.0, 1.2))
		_box("dark_metal", Vector3(tp.x, 18.2, tp.z), Vector3(2.4, 1.0, 1.4))
		for blade in 3:
			var blade_angle := TAU * float(blade) / 3.0
			var blade_basis := Basis(Vector3(0.0, 0.0, 1.0), blade_angle)
			_box("metal", Vector3(tp.x, 18.2, tp.z + 1.0) + blade_basis * Vector3(0.0, 3.5, 0.0),
				Vector3(0.25, 7.0, 0.08), blade_basis)
	# Torre de radio.
	var tower_pos := Vector3(75.0, 0.0, -10.0)
	var tower := Node3D.new()
	tower.name = "RadioTower"
	tower.position = tower_pos
	tower.add_to_group("radio_tower")
	add_child(tower)
	_box("metal", Vector3(tower_pos.x, 15.0, tower_pos.z), Vector3(1.0, 30.0, 1.0))
	_box("metal", Vector3(tower_pos.x, 8.0, tower_pos.z + 1.2), Vector3(0.15, 16.0, 0.15))
	_box("metal", Vector3(tower_pos.x, 22.0, tower_pos.z - 1.0), Vector3(0.15, 12.0, 0.15))
	_box("led_red", Vector3(tower_pos.x, 30.4, tower_pos.z), Vector3(0.5, 0.5, 0.5), Basis.IDENTITY, false)
	var tower_light := OmniLight3D.new()
	tower_light.position = Vector3(tower_pos.x, 30.4, tower_pos.z)
	tower_light.light_color = Color(1.0, 0.1, 0.08)
	tower_light.light_energy = 3.0
	tower_light.omni_range = 12.0
	tower_light.shadow_enabled = false
	add_child(tower_light)
	_note("TORRE DE RADIO", Vector3(tower_pos.x, 31.5, tower_pos.z))
	# Luces exteriores.
	for light_pos in [Vector3(1.0, 3.0, 20.0), Vector3(26.0, 3.0, 10.0),
			Vector3(32.0, 3.0, 9.0)]:
		_zone_light(light_pos, 14.0, 3.0)
	_zone_light(Vector3(0.0, 6.0, 24.0), 26.0, 3.5)
	_zone_light(Vector3(20.0, 6.0, 22.0), 22.0, 3.0)


func _build_lights() -> void:
	pass


func _flush_batches() -> void:
	for key_variant in _box_batches.keys():
		var key := String(key_variant)
		var transforms: Array = _box_batches[key]
		if transforms.is_empty():
			continue
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		multimesh.custom_aabb = AABB(Vector3(-130.0, -12.0, -130.0), Vector3(260.0, 40.0, 260.0))
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Batch_" + key
		instance.multimesh = multimesh
		instance.material_override = _materials[key]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	if not _dish_transforms.is_empty():
		var dish_mesh := CylinderMesh.new()
		dish_mesh.top_radius = 2.0
		dish_mesh.bottom_radius = 0.2
		dish_mesh.height = 0.3
		dish_mesh.radial_segments = 12
		var dish_multimesh := MultiMesh.new()
		dish_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		dish_multimesh.mesh = dish_mesh
		dish_multimesh.instance_count = _dish_transforms.size()
		dish_multimesh.custom_aabb = AABB(Vector3(-80.0, 0.0, -80.0), Vector3(160.0, 10.0, 160.0))
		for i in _dish_transforms.size():
			dish_multimesh.set_instance_transform(i, _dish_transforms[i])
		var dish_instance := MultiMeshInstance3D.new()
		dish_instance.name = "SatelliteDishMesh"
		dish_instance.multimesh = dish_multimesh
		dish_instance.material_override = _materials["metal"]
		dish_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dish_instance)


func _box(material_key: String, center: Vector3, size: Vector3,
		basis := Basis.IDENTITY, collide := true) -> void:
	if not _box_batches.has(material_key):
		_box_batches[material_key] = []
	var transforms: Array = _box_batches[material_key]
	transforms.append(Transform3D(basis.scaled(size), center))
	_box_batches[material_key] = transforms
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(basis, center)
		_collision.add_child(collision)


func _zone(id: StringName, label: String, position: Vector3, range_value: float) -> void:
	if zones.has(id):
		return
	var marker := Marker3D.new()
	marker.name = "Zone_" + String(id)
	marker.position = position
	marker.add_to_group("base_zone")
	add_child(marker)
	var label3d := Label3D.new()
	label3d.text = label
	label3d.font_size = 28
	label3d.pixel_size = 0.005
	label3d.modulate = Color(0.75, 0.88, 1.0)
	label3d.outline_size = 7
	label3d.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.position = Vector3(0.0, 2.9, 0.0)
	marker.add_child(label3d)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 2.6, 0.0)
	light.light_color = Color(1.0, 0.86, 0.68)
	light.light_energy = 1.5
	light.omni_range = clampf(range_value * 0.7, 6.0, 28.0)
	light.shadow_enabled = false
	marker.add_child(light)
	zones[id] = marker


func _zone_light(position: Vector3, range_value: float, energy := 1.4) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = Color(1.0, 0.86, 0.68)
	light.light_energy = energy
	light.omni_range = clampf(range_value, 6.0, 30.0)
	light.shadow_enabled = false
	add_child(light)


func _note(text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.pixel_size = 0.006
	label.modulate = Color(0.88, 0.86, 0.74)
	label.outline_size = 5
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position
	add_child(label)
