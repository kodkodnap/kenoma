class_name BaseBuilder
extends Node3D
## Construye la estación Kenoma con primitivas y MultiMesh por lotes.
## La geometría estática se agrupa por material; las colisiones viven en un solo StaticBody3D.

const WALL_HEIGHT := BaseLayout.WALL_HEIGHT
const WALL_THICKNESS := 0.25
const FLOOR_THICKNESS := 0.2

const ZONE_NAMES := {
	"signal": "SALA DE CONTROL DE SEÑALES",
	"drone_terrace": "TERRAZA DEL DRON",
	"upper_hall": "PASILLO PRINCIPAL",
	"server_room": "SALA DE SERVIDORES",
	"living": "ZONA DE DESCANSO Y COCINA",
	"bath": "BAÑO",
	"garage": "GARAJE DEL SNOWCAT",
	"lobby": "VESTÍBULO DE ENTRADA",
	"storage_ground": "ALMACÉN DE SUMINISTROS",
	"stairwell": "ESCALERA CENTRAL",
	"power_room": "CUARTO DE ENERGÍA Y BREAKER",
	"entrance": "ENTRADA PRINCIPAL",
	"alt_drop_zone": "ENTREGA EXTERIOR",
	"roof_access": "ACCESO AL TEJADO",
	"roof": "TEJADO",
}

const WARM_LIGHT := Color(1.0, 0.75, 0.42)
const NEUTRAL_LIGHT := Color(1.0, 0.84, 0.62)
const COOL_LIGHT := Color(0.68, 0.82, 0.96)
const DIM_HALL_LIGHT := Color(0.95, 0.78, 0.56)

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
	_build_cantilever_structure()
	_build_stairs()
	_build_roof()
	_build_props()
	_build_signal_room()
	_build_exterior()
	_flush_batches()
	_build_lights()


func _make_materials() -> void:
	_materials["wall"] = _material(Color(0.30, 0.32, 0.34), 0.0, 0.88)
	_materials["floor"] = _material(Color(0.16, 0.17, 0.19), 0.0, 0.92)
	_materials["ceiling"] = _material(Color(0.11, 0.12, 0.14), 0.0, 0.96)
	_materials["metal"] = _material(Color(0.28, 0.31, 0.33), 0.55, 0.52)
	_materials["dark_metal"] = _material(Color(0.10, 0.12, 0.14), 0.72, 0.45)
	_materials["screen"] = _material(Color(0.03, 0.18, 0.16), 0.0, 0.35, Color(0.18, 0.96, 0.62), 2.3)
	_materials["light"] = _material(Color(1.0, 0.88, 0.66), 0.0, 0.4, Color(1.0, 0.74, 0.38), 2.8)
	_materials["snow"] = _material(Color(0.45, 0.53, 0.65), 0.0, 0.96)
	_materials["rock"] = _material(Color(0.17, 0.19, 0.22), 0.0, 0.95)
	_materials["pine"] = _material(Color(0.07, 0.12, 0.10), 0.0, 0.94)
	_materials["roof"] = _material(Color(0.18, 0.20, 0.22), 0.0, 0.92)
	_materials["wood"] = _material(Color(0.40, 0.26, 0.15), 0.0, 0.86)
	_materials["rug"] = _material(Color(0.45, 0.18, 0.14), 0.0, 0.96)
	_materials["snowcat"] = _material(Color(0.66, 0.55, 0.30), 0.25, 0.62)
	_materials["led_green"] = _material(Color(0.08, 0.8, 0.25), 0.0, 0.4, Color(0.1, 1.0, 0.3), 2.0)
	_materials["led_red"] = _material(Color(0.85, 0.08, 0.08), 0.0, 0.4, Color(1.0, 0.12, 0.1), 2.8)
	_materials["warning"] = _material(Color(0.78, 0.56, 0.10), 0.0, 0.68, Color(0.85, 0.48, 0.06), 0.5)
	_materials["paper"] = _material(Color(0.76, 0.73, 0.65), 0.0, 0.88)
	_materials["glass"] = MachineMaterials.glass()
	_materials["cold"] = _material(Color(0.10, 0.18, 0.28), 0.0, 0.9, Color(0.12, 0.24, 0.38), 0.75)


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
			_box("ceiling", Vector3(cx, y + WALL_HEIGHT + 0.1, cz), Vector3(w, FLOOR_THICKNESS, d))

		var light_color := NEUTRAL_LIGHT
		var light_energy := 1.5
		var light_range := maxf(w, d)
		match id:
			&"signal":
				light_color = WARM_LIGHT
				light_energy = 1.9
				light_range = 18.0
			&"living":
				light_color = WARM_LIGHT
				light_energy = 1.8
				light_range = 14.0
			&"garage":
				light_color = WARM_LIGHT
				light_energy = 1.7
				light_range = 16.0
			&"upper_hall":
				light_color = DIM_HALL_LIGHT
				light_energy = 0.85
				light_range = 14.0
			&"server_room":
				light_color = COOL_LIGHT
				light_energy = 1.05
				light_range = 14.0
			&"power_room":
				light_color = COOL_LIGHT
				light_energy = 1.25
				light_range = 15.0
			&"drone_terrace":
				light_color = WARM_LIGHT
				light_energy = 1.15
				light_range = 14.0
		_zone(id, String(room["label"]), Vector3(cx, y + 0.15, cz), light_range, light_color, light_energy)

		# Luces complementarias en estancias largas.
		if id == &"signal":
			_zone_light(Vector3(-12.5, 7.6, -19.5), 11.0, 1.4, WARM_LIGHT)
			_zone_light(Vector3(-1.5, 7.6, -19.5), 11.0, 1.4, WARM_LIGHT)
			_zone_light(Vector3(-12.5, 7.6, -13.0), 10.0, 1.1, WARM_LIGHT)
		elif id == &"upper_hall":
			_zone_light(Vector3(-11.0, 7.7, -8.0), 10.0, 1.0, DIM_HALL_LIGHT)
			_zone_light(Vector3(11.0, 7.7, -8.0), 9.0, 0.75, COOL_LIGHT)
		elif id == &"stairwell":
			_zone_light(Vector3(23.0, 3.2, -3.0), 14.0, 1.2, NEUTRAL_LIGHT)
			_zone_light(Vector3(23.0, 7.4, -2.0), 14.0, 1.25, NEUTRAL_LIGHT)
			_zone_light(Vector3(23.0, -1.2, -2.0), 14.0, 1.0, COOL_LIGHT)


func _build_special_zones() -> void:
	for zone_variant in BaseLayout.SPECIAL_ZONES:
		var zone: Dictionary = zone_variant
		var id := StringName(zone["id"])
		var color := COOL_LIGHT if id == &"roof" else WARM_LIGHT
		_zone(id, String(zone["label"]),
			Vector3(float(zone["x"]), float(zone["y"]) + 0.15, float(zone["z"])),
			14.0, color, 1.2)


func _build_walls() -> void:
	for wall_variant in BaseLayout.collect_walls():
		var wall: Dictionary = wall_variant
		var axis := String(wall["axis"])
		var fixed := float(wall["fixed"])
		var start := float(wall["start"])
		var end := float(wall["end"])
		var y := float(wall["y"])
		var wall_height := float(wall.get("wall_height", WALL_HEIGHT))
		var openings: Array = []
		for door_variant in wall["doors"]:
			var door: Dictionary = door_variant
			openings.append({
				"at": float(door["at"]),
				"width": float(door["width"]),
				"bottom": 0.0,
				"height": minf(float(door["height"]), wall_height),
				"window": false,
				"open": bool(door.get("open", false)),
			})
		for window_variant in wall.get("windows", []):
			var window: Dictionary = window_variant
			openings.append({
				"at": float(window["at"]),
				"width": float(window["width"]),
				"bottom": float(window["bottom"]),
				"height": float(window["height"]),
				"window": true,
				"open": false,
			})
		openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["at"]) < float(b["at"]))
		var cursor := start
		for opening_variant in openings:
			var opening: Dictionary = opening_variant
			var half := float(opening["width"]) * 0.5
			var d0 := maxf(start, float(opening["at"]) - half)
			var d1 := minf(end, float(opening["at"]) + half)
			if d0 > cursor + 0.01:
				_wall_segment(axis, fixed, cursor, d0, y, 0.0, wall_height)
			var bottom := float(opening["bottom"])
			var height := float(opening["height"])
			if bottom > 0.01:
				_wall_segment(axis, fixed, d0, d1, y, 0.0, bottom)
			if bottom + height < wall_height - 0.01:
				_wall_segment(axis, fixed, d0, d1, y, bottom + height,
					wall_height - bottom - height)
			if opening["window"]:
				_window_frame(axis, fixed, d0, d1, y, bottom, height)
			elif not bool(opening.get("open", false)):
				_door_frame(axis, fixed, d0, d1, y, height)
			cursor = maxf(cursor, d1)
		if cursor < end - 0.01:
			_wall_segment(axis, fixed, cursor, end, y, 0.0, wall_height)


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
	if axis == "x":
		center = Vector3((from + to) * 0.5, y + height * 0.5, fixed)
		_box("dark_metal", Vector3(from, y + height * 0.5, fixed),
			Vector3(0.1, height, WALL_THICKNESS + 0.06), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(to, y + height * 0.5, fixed),
			Vector3(0.1, height, WALL_THICKNESS + 0.06), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(center.x, y + height - 0.05, fixed),
			Vector3(to - from, 0.1, WALL_THICKNESS + 0.06), Basis.IDENTITY, false)
	else:
		center = Vector3(fixed, y + height * 0.5, (from + to) * 0.5)
		_box("dark_metal", Vector3(fixed, y + height * 0.5, from),
			Vector3(WALL_THICKNESS + 0.06, height, 0.1), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(fixed, y + height * 0.5, to),
			Vector3(WALL_THICKNESS + 0.06, height, 0.1), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(fixed, y + height - 0.05, center.z),
			Vector3(WALL_THICKNESS + 0.06, 0.1, to - from), Basis.IDENTITY, false)


## Hueco de ventana: marco metálico y cristal semitransparente sin colisión.
func _window_frame(axis: String, fixed: float, from: float, to: float,
		y: float, bottom: float, height: float) -> void:
	var center := (from + to) * 0.5
	var mid_y := y + bottom + height * 0.5
	var span := to - from
	var depth := WALL_THICKNESS + 0.08
	if axis == "x":
		_box("dark_metal", Vector3(from, mid_y, fixed), Vector3(0.12, height, depth), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(to, mid_y, fixed), Vector3(0.12, height, depth), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(center, y + bottom + 0.05, fixed), Vector3(span, 0.1, depth), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(center, y + bottom + height - 0.05, fixed), Vector3(span, 0.1, depth), Basis.IDENTITY, false)
		_box("glass", Vector3(center, mid_y, fixed),
			Vector3(span - 0.12, height - 0.1, 0.03), Basis.IDENTITY, false)
	else:
		_box("dark_metal", Vector3(fixed, mid_y, from), Vector3(depth, height, 0.12), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(fixed, mid_y, to), Vector3(depth, height, 0.12), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(fixed, y + bottom + 0.05, center), Vector3(depth, 0.1, span), Basis.IDENTITY, false)
		_box("dark_metal", Vector3(fixed, y + bottom + height - 0.05, center), Vector3(depth, 0.1, span), Basis.IDENTITY, false)
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

	# Barandillas del pozo abierto de escalera en Planta Baja (y = 0.0).
	_railing_x(19.0, 30.0, -6.0, 0.0)
	_railing_z(19.0, -6.0, -5.2, 0.0)
	_railing_z(19.0, -2.8, -1.2, 0.0)
	_railing_z(19.0, 1.2, 6.0, 0.0)

	# Barandillas del pozo abierto de escalera en Planta Alta (y = 4.2).
	_railing_x(19.0, 27.0, -6.0, 4.2)
	_railing_z(19.0, -6.0, 6.0, 4.2)
	_railing_z(27.0, -6.0, -1.2, 4.2)
	_railing_z(27.0, 1.2, 2.8, 4.2)
	_railing_x(19.0, 27.0, 5.9, 4.2)

	# Barandillas en el desembarco superior de RoofRamp dentro de la caseta (y = 8.4).
	_railing_x(19.0, 27.0, 1.55, 8.4)
	_railing_z(19.0, 1.55, 2.8, 8.4)
	_railing_z(19.0, 5.2, 5.9, 8.4)

	# Cubierta de la caseta de azotea (y = 11.4).
	_box("roof", Vector3(23.0, 11.5, 3.75), Vector3(14.3, 0.22, 4.8))


## Estructura exterior del voladizo (vigas y pilares de acero/hormigón hasta y = 0).
func _build_cantilever_structure() -> void:
	# Cenefa gruesa de hormigón bajo el borde del voladizo (y = 3.75..4.2).
	_box("wall", Vector3(-7.0, 3.85, -24.1), Vector3(18.4, 0.55, 0.45))
	_box("wall", Vector3(-16.1, 3.85, -17.0), Vector3(0.45, 0.55, 14.4))
	_box("wall", Vector3(2.1, 3.85, -17.0), Vector3(0.45, 0.55, 14.4))

	# Tres pilares delanteros con zapata cónica y puntal inclinado como en el arte maestro.
	for px in [-14.2, -7.0, 0.2]:
		_box("wall", Vector3(px, 0.55, -22.2), Vector3(1.5, 1.1, 1.5))
		_box("dark_metal", Vector3(px, 2.3, -22.2), Vector3(0.65, 3.4, 0.65))
		# Puntal diagonal de acero desde la zapata hacia el voladizo exterior.
		_box("dark_metal", Vector3(px, 2.3, -22.8), Vector3(0.45, 3.7, 0.45),
			Basis(Vector3.RIGHT, 0.28))

	# Pilares traseros de apoyo cerca del arranque del voladizo.
	for px in [-14.2, -1.2]:
		_box("wall", Vector3(px, 0.45, -12.0), Vector3(1.3, 0.9, 1.3))
		_box("dark_metal", Vector3(px, 2.2, -12.0), Vector3(0.55, 3.5, 0.55))

	# Focos cálidos bajo el voladizo para iluminar el suelo frente al garaje.
	for lx in [-11.0, -3.5]:
		_box("light", Vector3(lx, 3.88, -21.5), Vector3(0.7, 0.1, 0.3), Basis.IDENTITY, false)
		_zone_light(Vector3(lx, 3.6, -21.5), 11.0, 1.15, WARM_LIGHT)


func _build_stairs() -> void:
	# Rampa baja a sótano (y=0.0 -> -4.2), carril norte z = -4.0.
	_make_ramp("StairsDown", Vector3(19.0, 0.0, -4.0), Vector3(27.0, -4.2, -4.0), 2.2)
	# Rampa sube a planta alta (y=0.0 -> +4.2), carril centro z = 0.0.
	_make_ramp("StairsUp", Vector3(19.0, 0.0, 0.0), Vector3(27.0, 4.2, 0.0), 2.2)
	# Rampa sube al tejado (y=4.2 -> +8.4), carril sur z = +4.0.
	_make_ramp("RoofRamp", Vector3(27.0, 4.2, 4.0), Vector3(19.0, 8.4, 4.0), 2.2)


func _make_ramp(ramp_name: String, from: Vector3, to: Vector3, width: float) -> void:
	var direction := to - from
	var length := direction.length()
	var angle := atan2(direction.y, direction.x)
	var basis := Basis(Vector3(0.0, 0.0, 1.0), angle)
	var body := StaticBody3D.new()
	body.name = ramp_name
	body.add_to_group("base_ramp")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.22, width)
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
	var rail_offset := Vector3(0.0, 0.9, width * 0.5)
	_box("metal", (from + to) * 0.5 + basis * rail_offset,
		Vector3(length, 0.08, 0.06), basis, false)
	_box("metal", (from + to) * 0.5 + basis * Vector3(0.0, 0.9, -width * 0.5),
		Vector3(length, 0.08, 0.06), basis, false)


func _railing_x(x0: float, x1: float, z: float, y: float) -> void:
	var length := absf(x1 - x0)
	if length < 0.1:
		return
	var cx := (x0 + x1) * 0.5
	_box("metal", Vector3(cx, y + 0.95, z), Vector3(length, 0.06, 0.06))
	_box("metal", Vector3(cx, y + 0.5, z), Vector3(length, 0.04, 0.04), Basis.IDENTITY, false)
	var posts := maxi(2, int(ceil(length / 2.5)) + 1)
	for i in posts:
		var px := lerpf(x0, x1, float(i) / float(posts - 1))
		_box("dark_metal", Vector3(px, y + 0.48, z), Vector3(0.06, 0.96, 0.06), Basis.IDENTITY, false)


func _railing_z(x: float, z0: float, z1: float, y: float) -> void:
	var length := absf(z1 - z0)
	if length < 0.1:
		return
	var cz := (z0 + z1) * 0.5
	_box("metal", Vector3(x, y + 0.95, cz), Vector3(0.06, 0.06, length))
	_box("metal", Vector3(x, y + 0.5, cz), Vector3(0.04, 0.04, length), Basis.IDENTITY, false)
	var posts := maxi(2, int(ceil(length / 2.5)) + 1)
	for i in posts:
		var pz := lerpf(z0, z1, float(i) / float(posts - 1))
		_box("dark_metal", Vector3(x, y + 0.48, pz), Vector3(0.06, 0.96, 0.06), Basis.IDENTITY, false)


func _build_roof() -> void:
	# Petos y barandillas perimetrales de azotea (y = 8.4) y cubierta de vestíbulo (y = 4.2).
	_railing_x(-16.0, 2.0, -24.0, 8.4)
	_railing_z(-16.0, -24.0, 6.0, 8.4)
	_railing_z(2.0, -24.0, -10.0, 8.4)
	_railing_x(2.0, 16.0, -10.0, 8.4)
	_railing_x(-16.0, 16.0, 6.0, 8.4)
	_railing_x(16.0, 30.0, -10.0, 8.4)
	_railing_z(30.0, -10.0, 1.5, 8.4)

	# Barandilla perimetral de la Terraza del Dron (y = 4.2, sobre el garaje).
	_railing_x(2.2, 15.9, -21.9, 4.2)
	_railing_z(15.9, -21.9, -10.1, 4.2)
	_railing_x(16.0, 25.9, -21.9, 4.2)
	_railing_z(25.9, -21.9, -10.1, 4.2)

	# Plataforma H del dron sobre Terraza del Dron (x=9.0, z=-16.0, y=4.2).
	_box("dark_metal", Vector3(9.0, 4.22, -16.0), Vector3(7.0, 0.04, 7.0), Basis.IDENTITY, false)
	_box("warning", Vector3(9.0, 4.245, -19.2), Vector3(6.6, 0.02, 0.25), Basis.IDENTITY, false)
	_box("warning", Vector3(9.0, 4.245, -12.8), Vector3(6.6, 0.02, 0.25), Basis.IDENTITY, false)
	_box("warning", Vector3(5.8, 4.245, -16.0), Vector3(0.25, 0.02, 6.6), Basis.IDENTITY, false)
	_box("warning", Vector3(12.2, 4.245, -16.0), Vector3(0.25, 0.02, 6.6), Basis.IDENTITY, false)
	_box("paper", Vector3(7.8, 4.245, -16.0), Vector3(0.35, 0.02, 2.8), Basis.IDENTITY, false)
	_box("paper", Vector3(10.2, 4.245, -16.0), Vector3(0.35, 0.02, 2.8), Basis.IDENTITY, false)
	_box("paper", Vector3(9.0, 4.245, -16.0), Vector3(2.2, 0.02, 0.35), Basis.IDENTITY, false)
	var pad := Marker3D.new()
	pad.name = "DronePad"
	pad.position = Vector3(9.0, 4.25, -16.0)
	pad.add_to_group("drone_pad")
	add_child(pad)

	# Parabólica icónica sobre el techo de Sala de Señales + mástil y respiraderos.
	_box("metal", Vector3(-6.0, 8.6, -15.5), Vector3(1.8, 0.4, 1.8))
	_box("dark_metal", Vector3(-6.0, 9.7, -15.5), Vector3(0.55, 2.0, 0.55))
	_dish_transforms.append(Transform3D(Basis(Vector3.RIGHT, -0.55).scaled(Vector3(1.45, 1.45, 1.45)),
		Vector3(-6.0, 10.9, -15.5)))

	_box("dark_metal", Vector3(-11.0, 8.95, -2.0), Vector3(3.2, 1.1, 2.2))
	_box("dark_metal", Vector3(4.0, 8.9, 1.0), Vector3(2.4, 1.0, 2.4))
	_box("metal", Vector3(11.0, 11.4, -4.0), Vector3(0.3, 6.0, 0.3))
	_box("led_red", Vector3(11.0, 14.5, -4.0), Vector3(0.25, 0.25, 0.25), Basis.IDENTITY, false)
	_note("AZOTEA / PARABÓLICA PRINCIPAL", Vector3(-6.0, 11.8, -15.5))


func _build_props() -> void:
	# --- PLANTA BAJA: GARAJE DEL SNOWCAT ---
	_build_snowcat_placeholder(Vector3(9.0, 0.0, -14.2))
	# Dintel enrollable del portón y bolardos amarillos exteriores.
	_box("dark_metal", Vector3(9.0, 3.65, -22.0), Vector3(6.4, 0.35, 0.32))
	_box("warning", Vector3(5.3, 0.65, -22.4), Vector3(0.26, 1.3, 0.26))
	_box("warning", Vector3(12.7, 0.65, -22.4), Vector3(0.26, 1.3, 0.26))
	_box("light", Vector3(9.0, 3.85, -22.25), Vector3(1.2, 0.16, 0.16), Basis.IDENTITY, false)
	_zone_light(Vector3(9.0, 3.7, -23.5), 14.0, 1.6, WARM_LIGHT)
	# Banco de trabajo y herramientas en muro oeste del garaje.
	_box("wood", Vector3(3.0, 0.5, -13.0), Vector3(1.2, 1.0, 4.4))
	_box("dark_metal", Vector3(2.25, 1.75, -13.0), Vector3(0.1, 1.1, 3.8))
	_box("metal", Vector3(3.2, 1.0, -8.0), Vector3(1.4, 2.0, 2.4))
	_note("GARAJE SNOWCAT", Vector3(9.0, 3.2, -21.7))

	# --- PLANTA BAJA: VESTÍBULO DE ENTRADA ---
	_box("light", Vector3(21.0, 3.35, -22.25), Vector3(0.9, 0.16, 0.16), Basis.IDENTITY, false)
	_zone_light(Vector3(21.0, 3.2, -23.4), 12.0, 1.5, WARM_LIGHT)
	_box("wood", Vector3(17.5, 0.42, -19.5), Vector3(2.6, 0.84, 0.7))
	for i in 4:
		_box("metal", Vector3(25.3, 1.05, -20.5 + float(i) * 1.1), Vector3(0.7, 2.1, 0.9))
	var lockers := Node3D.new()
	lockers.name = "Lockers"
	lockers.position = Vector3(25.3, 1.05, -18.8)
	lockers.add_to_group("lockers")
	add_child(lockers)
	_box("dark_metal", Vector3(16.25, 1.8, -11.5), Vector3(0.1, 1.3, 2.2))
	_note("DIRECTORIO\nPLANTA 0: GARAJE / ALMACÉN\nPLANTA 1: CONTROL / SERVIDORES / DESCANSO\nSÓTANO: BREAKER",
		Vector3(16.4, 2.0, -11.5))

	# --- PLANTA BAJA: ALMACÉN DE SUMINISTROS ---
	# Centro (x=6..12, z=0..5) libre para TestMachine y TestItem durante el prototipado.
	for i in 4:
		_box("metal", Vector3(2.8, 1.15, -4.0 + float(i) * 2.5), Vector3(0.9, 2.3, 2.0))
	for i in 3:
		_box("wood", Vector3(8.5 + float(i) * 1.4, 0.5, -4.8), Vector3(1.0, 1.0, 1.0))
	_box("wood", Vector3(9.2, 1.5, -4.8), Vector3(0.9, 1.0, 0.9))
	_note("ALMACÉN DE SUMINISTROS", Vector3(9.0, 2.6, -5.7))

	# --- PLANTA ALTA: PASILLO PRINCIPAL (32 m x 4 m) ---
	for bx in [-12.0, -4.0, 4.0, 12.0]:
		_box("dark_metal", Vector3(bx, 7.95, -8.0), Vector3(7.6, 0.14, 0.65), Basis.IDENTITY, false)
	_box("metal", Vector3(-15.3, 5.3, -8.0), Vector3(0.8, 2.2, 2.8))
	_note("← SERVIDORES (AISLADOS)\nDESCANSO / COCINA / BAÑO →", Vector3(0.0, 6.7, -6.2))

	# --- PLANTA ALTA: SALA DE SERVIDORES (CERRADA, 30 RACKS EN 2 PASILLOS AMPLIOS) ---
	for row in 6:
		for col in 5:
			var sx := -14.0 + float(col) * 2.5
			var sz := -3.8 + float(row) * 1.75
			_box("dark_metal", Vector3(sx, 5.3, sz), Vector3(1.15, 2.2, 0.65))
			_box("led_green", Vector3(sx - 0.3, 6.05, sz + 0.34), Vector3(0.08, 0.08, 0.03), Basis.IDENTITY, false)
			_box("led_red", Vector3(sx + 0.3, 6.05, sz + 0.34), Vector3(0.08, 0.08, 0.03), Basis.IDENTITY, false)
			var marker := Marker3D.new()
			marker.name = "Server_%02d_%02d" % [row, col]
			marker.position = Vector3(sx, 4.2, sz)
			marker.add_to_group("server_placeholder")
			add_child(marker)
	_box("metal", Vector3(-9.0, 5.2, 5.3), Vector3(4.0, 2.0, 0.9))
	_note("CLÚSTER DE SERVIDORES\n30 NODOS", Vector3(-9.0, 7.0, -5.7))

	# --- PLANTA ALTA: ZONA DE DESCANSO & COCINA (REFUGIO CÁLIDO) ---
	_box("rug", Vector3(3.5, 4.22, -0.5), Vector3(5.0, 0.03, 4.0), Basis.IDENTITY, false)
	# Literas para cooperativo (muro oeste).
	_box("wood", Vector3(-0.7, 4.65, -2.2), Vector3(1.8, 0.5, 3.2))
	_box("paper", Vector3(-0.7, 4.96, -2.2), Vector3(1.6, 0.14, 3.0))
	_box("wood", Vector3(-0.7, 5.85, -2.2), Vector3(1.8, 0.4, 3.2))
	_box("paper", Vector3(-0.7, 6.12, -2.2), Vector3(1.6, 0.14, 3.0))
	# Mesa cálida con lámpara y sillas.
	_box("wood", Vector3(3.5, 4.95, -0.5), Vector3(2.2, 0.1, 1.4))
	for lx in [-0.9, 0.9]:
		for lz in [-0.55, 0.55]:
			_box("dark_metal", Vector3(3.5 + lx, 4.55, -0.5 + lz), Vector3(0.08, 0.7, 0.08))
	for cx in [2.1, 4.9]:
		_box("wood", Vector3(cx, 4.65, -0.5), Vector3(0.6, 0.85, 0.6))
	_box("light", Vector3(3.5, 5.2, -0.5), Vector3(0.28, 0.22, 0.28), Basis.IDENTITY, false)
	# Encimera de cocina en L, fogones y nevera.
	_box("wood", Vector3(7.0, 4.7, 4.9), Vector3(5.0, 1.0, 1.2))
	_box("wood", Vector3(9.0, 4.7, 1.5), Vector3(1.2, 1.0, 5.6))
	_box("metal", Vector3(0.2, 5.25, 4.9), Vector3(1.2, 2.1, 1.1))
	_note("DESCANSO / COCINA", Vector3(4.0, 6.9, 5.6))

	# --- PLANTA ALTA: BAÑO ---
	_box("paper", Vector3(14.8, 4.65, 4.5), Vector3(1.2, 0.9, 1.2))
	_box("paper", Vector3(11.4, 4.7, 4.8), Vector3(1.4, 1.0, 1.0))
	_box("paper", Vector3(14.4, 4.55, -1.5), Vector3(2.2, 0.7, 2.4))
	_box("glass", Vector3(13.2, 5.4, -1.5), Vector3(0.05, 2.2, 2.4), Basis.IDENTITY, false)

	# --- SÓTANO: CUARTO DE ENERGÍA Y BREAKER ---
	# Cuadro de breaker en muro norte (z = -10.0), mirando hacia +Z.
	_box("dark_metal", Vector3(9.0, -2.75, -9.55), Vector3(3.0, 2.0, 0.35))
	for i in 5:
		_box("warning", Vector3(7.8 + float(i) * 0.6, -3.25, -9.25), Vector3(0.26, 0.14, 0.12))
	_box("warning", Vector3(9.0, -1.65, -9.45), Vector3(1.6, 0.25, 0.1))
	var breaker := Node3D.new()
	breaker.name = "Breaker"
	breaker.position = Vector3(9.0, -3.7, -9.45)
	breaker.add_to_group("breaker")
	add_child(breaker)
	_note("BREAKER PRINCIPAL\nNO REARMAR CON CARGA", Vector3(9.0, -1.2, -9.4))

	# Dos generadores diésel grandes al oeste del sótano.
	for gz in [-3.5, 2.2]:
		_box("dark_metal", Vector3(5.0, -3.2, gz), Vector3(3.2, 2.0, 1.8))
		_box("warning", Vector3(5.0, -4.15, gz), Vector3(3.6, 0.08, 2.2))
		_box("metal", Vector3(4.0, -1.7, gz), Vector3(0.35, 1.2, 0.35))

	# Armarios interiores de control de transformadores en muro sur (z = 5.3).
	for i in 3:
		_box("dark_metal", Vector3(5.5 + float(i) * 3.5, -2.8, 5.3), Vector3(2.2, 2.4, 0.8))
		_box("screen", Vector3(5.5 + float(i) * 3.5, -2.45, 4.85), Vector3(1.0, 0.5, 0.04), Basis.IDENTITY, false)

	# Depósito de combustible.
	_box("metal", Vector3(13.8, -3.1, -6.5), Vector3(2.0, 2.2, 3.2))


func _build_snowcat_placeholder(pos: Vector3) -> void:
	# Orientado hacia -Z (morro mirando al portón del garaje).
	var marker := Marker3D.new()
	marker.name = "SnowcatPlaceholder"
	marker.position = pos
	marker.add_to_group("snowcat_placeholder")
	add_child(marker)
	# Orugas izquierda y derecha.
	for sx in [-1.25, 1.25]:
		_box("dark_metal", pos + Vector3(sx, 0.45, 0.0), Vector3(0.65, 0.9, 4.8))
	# Chasis y plataforma trasera de carga.
	_box("dark_metal", pos + Vector3(0.0, 0.95, 0.0), Vector3(2.1, 0.45, 4.5))
	_box("metal", pos + Vector3(0.0, 1.45, 1.35), Vector3(2.3, 0.65, 2.1))
	# Cabina delantera cálida con parabrisas.
	_box("snowcat", pos + Vector3(0.0, 1.85, -0.75), Vector3(2.2, 1.55, 2.1))
	_box("glass", pos + Vector3(0.0, 2.1, -1.82), Vector3(1.9, 0.75, 0.06), Basis.IDENTITY, false)
	# Pala quitanieves frontal.
	_box("warning", pos + Vector3(0.0, 0.45, -2.85), Vector3(3.1, 0.85, 0.35))
	# Faros delanteros encendidos.
	_box("light", pos + Vector3(-0.75, 1.25, -1.85), Vector3(0.28, 0.2, 0.08), Basis.IDENTITY, false)
	_box("light", pos + Vector3(0.75, 1.25, -1.85), Vector3(0.28, 0.2, 0.08), Basis.IDENTITY, false)


## Detalle de Sala de Control de Señales (y = 4.2): ventanal en voladizo,
## bancada curva de 4 estaciones, impresora matricial, mesa cálida y vistas exteriores.
func _build_signal_room() -> void:
	var window := _signal_detail("SignalWindow", Vector3(-7.0, 6.5, -24.0))
	window.set_meta("width", BaseLayout.SIGNAL_WINDOW_WIDTH)

	# Parteluces inclinados del ventanal panorámico de 3 paños.
	for mx in [-11.5, -2.5]:
		_box("dark_metal", Vector3(mx, 6.5, -23.92), Vector3(0.16, 2.6, 0.22), Basis.IDENTITY, false)

	# Vigas estructurales de hormigón y bandejas portacables vistas en techo (y = 7.95).
	for bz in [-21.0, -17.5, -14.0]:
		_box("wall", Vector3(-7.0, 8.0, bz), Vector3(17.6, 0.32, 0.45), Basis.IDENTITY, false)
	for cx in [-11.5, -2.5]:
		_box("dark_metal", Vector3(cx, 7.75, -17.0), Vector3(0.75, 0.14, 13.0), Basis.IDENTITY, false)
		_box("light", Vector3(cx, 7.7, -19.0), Vector3(0.2, 0.08, 2.4), Basis.IDENTITY, false)
		_box("light", Vector3(cx, 7.7, -14.5), Vector3(0.2, 0.08, 2.4), Basis.IDENTITY, false)

	# Bancada de 4 máquinas físicas frente al ventanal panorámico (y = 4.2 -> marcadores en 5.45).
	_add_panel(-13.0, 4.2, -22.2, 0)  # CoordinatesPanel
	_add_panel(-9.2, 4.2, -22.9, 1)   # DownloadsPanel
	_add_panel(-5.0, 4.2, -22.9, 2)   # Playback + SellDock
	_add_panel(-1.2, 4.2, -22.2, 3)   # ProcessingPanel

	# Consola física provisional de Reproducción (Panel 3).
	_box("dark_metal", Vector3(-5.0, 4.8, -22.9), Vector3(2.2, 1.2, 0.72))
	_box("screen", Vector3(-5.3, 5.25, -22.52), Vector3(1.1, 0.55, 0.04), Basis.IDENTITY, false)
	_box("metal", Vector3(-3.85, 4.95, -22.65), Vector3(0.45, 0.35, 0.45), Basis.IDENTITY, false)

	# Estación de terminal de gestión (MainComputer) en flanco oeste.
	_box("dark_metal", Vector3(-13.5, 4.7, -15.0), Vector3(2.1, 1.0, 1.1))
	_box("dark_metal", Vector3(-13.5, 5.55, -15.25), Vector3(1.2, 0.75, 0.5))
	_box("screen", Vector3(-13.5, 5.55, -14.98), Vector3(0.9, 0.52, 0.04), Basis.IDENTITY, false)
	_signal_detail("MainComputerMarker", Vector3(-13.5, 5.45, -15.0))

	# Mesa cálida central con alfombra gastada, lámpara de bronce y mapas.
	_signal_detail("TarimaBaja", Vector3(-7.0, 4.22, -16.8))
	_box("rug", Vector3(-7.0, 4.215, -16.8), Vector3(6.8, 0.03, 4.4), Basis.IDENTITY, false)
	_box("wood", Vector3(-7.0, 4.98, -16.8), Vector3(3.4, 0.12, 1.6))
	for lx in [-1.4, 1.4]:
		for lz in [-0.6, 0.6]:
			_box("dark_metal", Vector3(-7.0 + lx, 4.58, -16.8 + lz), Vector3(0.1, 0.76, 0.1))
	_box("paper", Vector3(-7.1, 5.05, -16.75), Vector3(1.3, 0.02, 0.9), Basis(Vector3.UP, 0.12), false)
	_box("dark_metal", Vector3(-8.2, 5.28, -16.4), Vector3(0.18, 0.48, 0.18), Basis.IDENTITY, false)
	_box("light", Vector3(-8.2, 5.54, -16.4), Vector3(0.32, 0.18, 0.32), Basis.IDENTITY, false)
	_zone_light(Vector3(-8.2, 5.65, -16.4), 7.5, 1.5, WARM_LIGHT)
	for cx in [-8.0, -6.0]:
		_box("wood", Vector3(cx, 4.65, -15.4), Vector3(0.65, 0.88, 0.65))

	# Mesa de discos junto a Procesado (MesaDiscos: superficie en y=5.0 -> disco en 5.15).
	_signal_detail("MesaDiscos", Vector3(-2.5, 5.0, -17.5))
	_box("wood", Vector3(-2.5, 4.98, -17.5), Vector3(2.2, 0.12, 1.1))
	for dx in [-0.95, 0.95]:
		for dz in [-0.42, 0.42]:
			_box("dark_metal", Vector3(-2.5 + dx, 4.58, -17.5 + dz), Vector3(0.09, 0.76, 0.09))
	for i in 3:
		_box("metal", Vector3(-3.1 + float(i) * 0.6, 5.06, -17.5),
			Vector3(0.42, 0.03, 0.42), Basis.IDENTITY, false)

	# Impresora matricial física sobre mueble propio en el lado este junto a la terraza.
	_signal_detail("PrinterPlaceholder", Vector3(1.0, 5.0, -14.8))
	_box("metal", Vector3(1.0, 4.6, -14.8), Vector3(1.1, 0.8, 0.9))
	_box("paper", Vector3(1.0, 5.22, -14.8), Vector3(0.75, 0.38, 0.6))
	_box("paper", Vector3(0.62, 5.02, -14.8), Vector3(0.32, 0.03, 0.48), Basis(Vector3.BACK, 0.35), false)
	_box("led_green", Vector3(0.65, 5.38, -14.52), Vector3(0.06, 0.06, 0.04), Basis.IDENTITY, false)
	_note("IMPRESORA MATRICIAL", Vector3(0.95, 5.85, -14.8))

	# Tablones de notas y armarios en muro sur (z = -10.35).
	_box("wood", Vector3(-11.5, 6.2, -10.22), Vector3(2.4, 1.3, 0.08), Basis.IDENTITY, false)
	_box("paper", Vector3(-11.8, 6.3, -10.17), Vector3(0.6, 0.5, 0.02), Basis.IDENTITY, false)
	_box("paper", Vector3(-10.9, 6.1, -10.17), Vector3(0.55, 0.7, 0.02), Basis.IDENTITY, false)
	_box("dark_metal", Vector3(-1.2, 5.3, -10.45), Vector3(3.4, 2.2, 0.7))
	_signal_detail("RadarPared", Vector3(-15.7, 6.2, -12.0))


func _signal_detail(detail_name: String, pos: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = detail_name
	marker.position = pos
	marker.add_to_group("signal_room_detail")
	add_child(marker)
	return marker


func _add_panel(px: float, floor_y: float, pz: float, index: int) -> void:
	var panel := Node3D.new()
	panel.name = "SignalPanel%d" % (index + 1)
	panel.position = Vector3(px, floor_y + 1.25, pz)
	panel.add_to_group("signal_panel")
	add_child(panel)


func _build_exterior() -> void:
	# Explanada de hormigón exterior (bajo el voladizo, acceso al garaje, vestíbulo y entrega alt.).
	_box("floor", Vector3(2.0, -0.1, -26.5), Vector3(36.0, 0.2, 9.0))
	_box("floor", Vector3(-7.0, -0.1, -16.0), Vector3(18.0, 0.2, 12.0))
	_box("floor", Vector3(28.0, -0.1, -16.0), Vector3(4.0, 0.2, 12.0))
	_box("warning", Vector3(28.0, 0.015, -16.0), Vector3(3.2, 0.02, 4.4), Basis.IDENTITY, false)

	# Suelo de nieve continuo en anillo de 1,4 km alrededor del edificio (sin hueco bajo voladizo).
	# Huella cerrada del edificio: x:[2..30], z:[-22..6].
	_box("snow", Vector3(0.0, -0.2, -361.0), Vector3(1400.0, 0.4, 678.0))
	_box("snow", Vector3(0.0, -0.2, 353.0), Vector3(1400.0, 0.4, 694.0))
	_box("snow", Vector3(-349.0, -0.2, -8.0), Vector3(702.0, 0.4, 28.0))
	_box("snow", Vector3(365.0, -0.2, -8.0), Vector3(670.0, 0.4, 28.0))

	# Ladera rocosa y nevada abrazando la parte trasera y flanco oeste de la estación.
	_box("rock", Vector3(7.0, 2.2, 13.0), Vector3(58.0, 4.8, 13.0))
	_box("snow", Vector3(7.0, 4.7, 14.0), Vector3(58.0, 0.5, 11.0))
	_box("rock", Vector3(7.0, 6.2, 23.0), Vector3(64.0, 7.6, 14.0))
	_box("snow", Vector3(7.0, 10.1, 24.0), Vector3(64.0, 0.6, 12.0))
	_box("rock", Vector3(-24.0, 2.0, 1.0), Vector3(14.0, 4.4, 16.0))
	_box("snow", Vector3(-24.0, 4.3, 1.0), Vector3(14.0, 0.5, 16.0))

	# Camino apisonado desde el garaje hacia el claro norte (-Z) y postes de luz de madera.
	for i in 5:
		var pz := -35.0 - float(i) * 18.0
		var px := 9.0 + float(i) * 7.5
		_box("wood", Vector3(px, 3.2, pz), Vector3(0.28, 6.4, 0.28))
		_box("wood", Vector3(px, 6.0, pz), Vector3(1.8, 0.2, 0.2))
		_box("dark_metal", Vector3(px, 5.75, pz), Vector3(0.32, 0.45, 0.32), Basis.IDENTITY, false)

	# Bosque de pinos en el borde del claro (batcheado en Batch_pine/wood, 0 draws extra).
	var rng := RandomNumberGenerator.new()
	rng.seed = 198304
	for i in 48:
		var angle := TAU * float(i) / 48.0 + rng.randf_range(-0.04, 0.04)
		# Mantener la parte trasera detrás de la ladera más alejada y el claro frontal despejado.
		var radius := rng.randf_range(46.0, 115.0)
		var tx := cos(angle) * radius
		var tz := -18.0 + sin(angle) * radius
		if absf(tx - 9.0) < 12.0 and tz > -55.0 and tz < -15.0:
			continue
		if tx > -28.0 and tx < 38.0 and tz > -28.0 and tz < 32.0:
			continue
		var h := rng.randf_range(7.0, 13.0)
		_box("wood", Vector3(tx, h * 0.18, tz), Vector3(0.45, h * 0.36, 0.45))
		_box("pine", Vector3(tx, h * 0.45, tz), Vector3(3.4, h * 0.32, 3.4), Basis.IDENTITY, false)
		_box("pine", Vector3(tx, h * 0.68, tz), Vector3(2.4, h * 0.28, 2.4), Basis.IDENTITY, false)
		_box("snow", Vector3(tx, h * 0.88, tz), Vector3(1.2, h * 0.16, 1.2), Basis.IDENTITY, false)

	# Pico lejano al norte con domo radar y baliza roja visible desde el ventanal de Señales.
	var peak_pos := Vector3(45.0, 0.0, -185.0)
	_box("rock", peak_pos + Vector3(0.0, 14.0, 0.0), Vector3(72.0, 28.0, 56.0), Basis(Vector3.UP, 0.22), false)
	_box("snow", peak_pos + Vector3(0.0, 28.0, 0.0), Vector3(52.0, 8.0, 40.0), Basis(Vector3.UP, 0.18), false)
	_box("rock", peak_pos + Vector3(0.0, 35.0, 0.0), Vector3(30.0, 12.0, 24.0), Basis.IDENTITY, false)
	_box("snow", peak_pos + Vector3(0.0, 41.5, 0.0), Vector3(16.0, 3.0, 14.0), Basis.IDENTITY, false)
	_box("wall", peak_pos + Vector3(0.0, 44.5, 0.0), Vector3(4.5, 3.5, 4.5), Basis.IDENTITY, false)
	_box("paper", peak_pos + Vector3(0.0, 47.8, 0.0), Vector3(4.0, 3.4, 4.0), Basis.IDENTITY, false)
	_box("led_red", peak_pos + Vector3(0.0, 50.2, 0.0), Vector3(0.9, 0.9, 0.9), Basis.IDENTITY, false)
	var peak_beacon := OmniLight3D.new()
	peak_beacon.position = peak_pos + Vector3(0.0, 50.5, 0.0)
	peak_beacon.light_color = Color(1.0, 0.12, 0.1)
	peak_beacon.light_energy = 4.5
	peak_beacon.omni_range = 24.0
	peak_beacon.shadow_enabled = false
	add_child(peak_beacon)

	# 24 platos satelitales en anillo de 250 m.
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var px := cos(angle) * 250.0
		var pz := sin(angle) * 250.0
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

	# 3 transformadores exteriores al noreste del vestíbulo.
	for i in 3:
		var tx := 36.0
		var tz := -18.0 + float(i) * 5.5
		var transformer := Node3D.new()
		transformer.name = "Transformer%d" % (i + 1)
		transformer.position = Vector3(tx, 0.0, tz)
		transformer.add_to_group("transformer")
		add_child(transformer)
		_box("metal", Vector3(tx, 0.2, tz), Vector3(3.0, 0.4, 2.2))
		_box("dark_metal", Vector3(tx, 1.4, tz), Vector3(2.4, 2.2, 1.6))
		for fin in 4:
			_box("metal", Vector3(tx - 0.8 + float(fin) * 0.55, 1.4, tz + 0.85),
				Vector3(0.35, 1.8, 0.1))
		_box("warning", Vector3(tx, 2.2, tz + 0.82), Vector3(0.8, 0.4, 0.08))
		_note("TRAFO %s" % ["A", "B", "C"][i], Vector3(tx, 3.2, tz))

	# 3 radares de coordenadas.
	var radar_positions := [Vector3(-260.0, 0.0, -260.0), Vector3(260.0, 0.0, -260.0),
		Vector3(0.0, 0.0, 300.0)]
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

	# 4 turbinas eólicas.
	var turbine_positions := [Vector3(-560.0, 0.0, -560.0), Vector3(560.0, 0.0, -560.0),
		Vector3(-560.0, 0.0, 560.0), Vector3(560.0, 0.0, 560.0)]
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

	# Torre de radio principal.
	var tower_pos := Vector3(400.0, 0.0, -150.0)
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

	# Iluminación exterior del claro y transformadores.
	_zone_light(Vector3(36.0, 4.0, -12.5), 14.0, 1.4, WARM_LIGHT)
	_zone_light(Vector3(16.0, 6.0, -28.0), 20.0, 1.6, COOL_LIGHT)


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
		multimesh.custom_aabb = AABB(Vector3(-720.0, -20.0, -720.0), Vector3(1440.0, 90.0, 1440.0))
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
		dish_multimesh.custom_aabb = AABB(Vector3(-300.0, 0.0, -300.0), Vector3(600.0, 20.0, 600.0))
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


func _zone(id: StringName, label: String, pos: Vector3, range_value: float,
		light_color := NEUTRAL_LIGHT, light_energy := 1.5) -> void:
	if zones.has(id):
		return
	var marker := Marker3D.new()
	marker.name = "Zone_" + String(id)
	marker.position = pos
	marker.add_to_group("base_zone")
	add_child(marker)
	var label3d := Label3D.new()
	label3d.text = label
	label3d.font_size = 28
	label3d.pixel_size = 0.005
	label3d.modulate = Color(0.86, 0.90, 0.96)
	label3d.outline_size = 7
	label3d.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.position = Vector3(0.0, 2.9, 0.0)
	marker.add_child(label3d)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0.0, 3.1, 0.0)
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = clampf(range_value * 0.8, 7.0, 28.0)
	light.shadow_enabled = false
	marker.add_child(light)
	zones[id] = marker


func _zone_light(pos: Vector3, range_value: float, energy := 1.4,
		color := NEUTRAL_LIGHT) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = clampf(range_value, 6.0, 30.0)
	light.shadow_enabled = false
	add_child(light)


func _note(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.pixel_size = 0.006
	label.modulate = Color(0.92, 0.88, 0.76)
	label.outline_size = 5
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)
