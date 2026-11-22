class_name BaseBuilder
extends Node3D
## Construye la estación Kenoma (+20 % ampliada, ala en voladizo elevada) sobre el valle
## terraformado de TerrainBuilder, agrupando geometría por material y colisión única.

const WALL_HEIGHT := BaseLayout.WALL_HEIGHT
const LEVEL_HEIGHT := BaseLayout.LEVEL_HEIGHT
const SIGNAL_Y := BaseLayout.SIGNAL_Y
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

	var terrain := TerrainBuilder.new()
	terrain.name = "Terrain"
	add_child(terrain)

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
	_materials["snow"] = _material(Color(0.47, 0.55, 0.68), 0.0, 0.96)
	_materials["rock"] = _material(Color(0.15, 0.17, 0.21), 0.0, 0.95)
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
		var light_energy := 1.55
		var light_range := maxf(w, d)
		match id:
			&"signal":
				light_color = WARM_LIGHT
				light_energy = 2.0
				light_range = 22.0
			&"living":
				light_color = WARM_LIGHT
				light_energy = 1.9
				light_range = 16.0
			&"garage":
				light_color = WARM_LIGHT
				light_energy = 1.85
				light_range = 19.0
			&"upper_hall":
				light_color = DIM_HALL_LIGHT
				light_energy = 0.9
				light_range = 16.0
			&"server_room":
				light_color = COOL_LIGHT
				light_energy = 1.15
				light_range = 17.0
			&"power_room":
				light_color = COOL_LIGHT
				light_energy = 1.3
				light_range = 18.0
			&"drone_terrace":
				light_color = WARM_LIGHT
				light_energy = 1.2
				light_range = 16.0
		_zone(id, String(room["label"]), Vector3(cx, y + 0.15, cz), light_range, light_color, light_energy)

		# Luces complementarias en estancias grandes.
		if id == &"signal":
			_zone_light(Vector3(-15.0, SIGNAL_Y + 3.6, -24.0), 13.0, 1.5, WARM_LIGHT)
			_zone_light(Vector3(-2.0, SIGNAL_Y + 3.6, -24.0), 13.0, 1.5, WARM_LIGHT)
			_zone_light(Vector3(-15.0, SIGNAL_Y + 3.6, -16.0), 12.0, 1.2, WARM_LIGHT)
		elif id == &"upper_hall":
			_zone_light(Vector3(-13.5, 8.1, -9.5), 11.0, 1.0, DIM_HALL_LIGHT)
			_zone_light(Vector3(13.5, 8.1, -9.5), 10.0, 0.8, COOL_LIGHT)
		elif id == &"stairwell":
			_zone_light(Vector3(27.5, 3.4, -3.0), 16.0, 1.25, NEUTRAL_LIGHT)
			_zone_light(Vector3(27.5, 7.8, -2.0), 16.0, 1.3, NEUTRAL_LIGHT)
			_zone_light(Vector3(27.5, -1.2, -2.0), 16.0, 1.05, COOL_LIGHT)


func _build_special_zones() -> void:
	for zone_variant in BaseLayout.SPECIAL_ZONES:
		var zone: Dictionary = zone_variant
		var id := StringName(zone["id"])
		var color := COOL_LIGHT if id == &"roof" else WARM_LIGHT
		_zone(id, String(zone["label"]),
			Vector3(float(zone["x"]), float(zone["y"]) + 0.15, float(zone["z"])),
			15.0, color, 1.25)


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

	# Barandillas del pozo de acceso central en Sala de Señales (y = 6.0).
	_railing_z(-9.5, -15.5, -12.0, SIGNAL_Y)
	_railing_z(-5.5, -15.5, -12.0, SIGNAL_Y)

	# Barandillas del desembarco exterior hacia Terraza del Dron (y = 6.0).
	_railing_z(4.55, -16.9, -14.1, SIGNAL_Y)
	_railing_x(2.05, 4.55, -14.15, SIGNAL_Y)

	# Barandillas del pozo abierto de escalera en Planta Baja (y = 0.0).
	_railing_x(22.5, 36.0, -7.0, 0.0)
	_railing_z(22.5, -7.0, -5.9, 0.0)
	_railing_z(22.5, -3.1, -1.4, 0.0)
	_railing_z(22.5, 1.4, 7.4, 0.0)

	# Barandillas del pozo abierto de escalera en Planta Alta (y = 4.4).
	_railing_x(22.5, 32.5, -7.0, 4.4)
	_railing_z(22.5, -7.0, 7.4, 4.4)
	_railing_z(32.5, -7.0, -1.4, 4.4)
	_railing_z(32.5, 1.4, 3.4, 4.4)
	_railing_z(32.5, 6.2, 7.4, 4.4)
	_railing_x(22.5, 32.5, 7.4, 4.4)

	# Barandillas en el desembarco superior de RoofRamp dentro de la caseta (y = 8.8).
	_railing_x(22.5, 32.5, 2.05, 8.8)
	_railing_z(22.5, 2.05, 3.4, 8.8)
	_railing_z(22.5, 6.2, 7.4, 8.8)
	_railing_z(32.5, 2.05, 7.4, 8.8)

	# Cubierta de la caseta de azotea (y = 12.0).
	_box("roof", Vector3(27.5, 12.1, 4.75), Vector3(17.3, 0.22, 5.8))


## Estructura exterior del voladizo elevado (vigas y pilares anclados al terreno real).
func _build_cantilever_structure() -> void:
	var soffit_y := SIGNAL_Y - 0.35
	# Cenefa gruesa de hormigón bajo el borde del voladizo (y = 5.4..6.0).
	_box("wall", Vector3(-8.5, soffit_y, -29.1), Vector3(21.4, 0.62, 0.45))
	_box("wall", Vector3(-19.1, soffit_y, -20.5), Vector3(0.45, 0.62, 17.4))
	_box("wall", Vector3(2.1, soffit_y, -20.5), Vector3(0.45, 0.62, 17.4))

	# Vigas transversales bajo la losa del voladizo.
	for vx in [-16.8, -8.5, -0.2]:
		_box("dark_metal", Vector3(vx, soffit_y - 0.15, -20.5), Vector3(0.55, 0.42, 16.5))

	# Tres pilares delanteros con zapata asentada sobre la ladera real y puntal inclinado.
	for px in [-16.8, -8.5, -0.2]:
		var ground_y := TerrainMap.height_at(px, -26.8)
		var foot_base := ground_y - 0.5
		var top_y := soffit_y - 0.1
		var pillar_h := maxf(2.0, top_y - (foot_base + 1.1))
		_box("wall", Vector3(px, foot_base + 0.65, -26.8), Vector3(1.85, 1.3, 1.85))
		_box("dark_metal", Vector3(px, foot_base + 1.1 + pillar_h * 0.5, -26.8),
			Vector3(0.78, pillar_h, 0.78))
		_box("dark_metal", Vector3(px, foot_base + 1.1 + pillar_h * 0.5, -27.55),
			Vector3(0.5, pillar_h * 1.06, 0.5), Basis(Vector3.RIGHT, 0.24))

	# Pilares traseros de apoyo cerca del arranque del voladizo.
	for px in [-16.8, -1.4]:
		var ground_y := TerrainMap.height_at(px, -14.2)
		var foot_base := ground_y - 0.5
		var top_y := soffit_y - 0.1
		var pillar_h := maxf(2.0, top_y - (foot_base + 0.9))
		_box("wall", Vector3(px, foot_base + 0.55, -14.2), Vector3(1.6, 1.1, 1.6))
		_box("dark_metal", Vector3(px, foot_base + 0.9 + pillar_h * 0.5, -14.2),
			Vector3(0.66, pillar_h, 0.66))

	# Zócalo de cimentación bajo Server/Living/Bath (y = -0.6..4.4) para cerrar el apoyo en ladera.
	_box("wall", Vector3(-8.5, 2.0, 7.5), Vector3(21.2, 5.2, 0.35))
	_box("wall", Vector3(-19.0, 2.0, -2.25), Vector3(0.35, 5.2, 19.5))

	# Focos cálidos bajo el voladizo iluminando el claro frontal.
	for lx in [-13.0, -4.0]:
		_box("light", Vector3(lx, soffit_y - 0.25, -26.0), Vector3(0.95, 0.1, 0.34), Basis.IDENTITY, false)
		_zone_light(Vector3(lx, soffit_y - 0.55, -26.0), 15.0, 1.35, WARM_LIGHT)


func _build_stairs() -> void:
	# Rampas anchas (2.6 m) del núcleo central de escaleras.
	_make_ramp("StairsDown", Vector3(22.5, 0.0, -4.5), Vector3(32.5, -4.4, -4.5), 2.6)
	_make_ramp("StairsUp", Vector3(22.5, 0.0, 0.0), Vector3(32.5, 4.4, 0.0), 2.6)
	_make_ramp("RoofRamp", Vector3(32.5, 4.4, 4.8), Vector3(22.5, 8.8, 4.8), 2.6)

	# Rampa puente central desde Pasillo Principal (y=4.4) hacia el ala elevada (y=6.0).
	_make_ramp("SignalBridgeRamp", Vector3(-7.5, 4.4, -12.0), Vector3(-7.5, SIGNAL_Y, -15.5), 4.0)
	# Escalera exterior desde la puerta este de Sala de Señales (y=6.0) a Terraza del Dron (y=4.4).
	_make_ramp("TerraceRamp", Vector3(3.3, SIGNAL_Y, -16.9), Vector3(3.3, 4.4, -21.0), 2.4)
	# Rampa de azotea conectando cubierta trasera (y=8.8) con cubierta del voladizo (y=10.4).
	_make_ramp("RoofStepRamp", Vector3(-0.3, 8.8, -8.5), Vector3(-0.3, 10.4, -12.0), 2.4)


func _make_ramp(ramp_name: String, from: Vector3, to: Vector3, width: float) -> void:
	var direction := to - from
	var length := direction.length()
	var horiz_len := Vector2(direction.x, direction.z).length()
	var yaw := atan2(-direction.z, direction.x)
	var pitch := atan2(direction.y, horiz_len)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)

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
	var posts := maxi(2, int(ceil(length / 2.8)) + 1)
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
	var posts := maxi(2, int(ceil(length / 2.8)) + 1)
	for i in posts:
		var pz := lerpf(z0, z1, float(i) / float(posts - 1))
		_box("dark_metal", Vector3(x, y + 0.48, pz), Vector3(0.06, 0.96, 0.06), Basis.IDENTITY, false)


func _build_roof() -> void:
	var signal_roof_y := SIGNAL_Y + WALL_HEIGHT + 0.2  # 10.4
	# Barandillas de la cubierta elevada del voladizo (y = 10.4).
	_railing_x(-19.0, 2.0, -29.0, signal_roof_y)
	_railing_z(-19.0, -29.0, -12.0, signal_roof_y)
	_railing_z(2.0, -29.0, -12.0, signal_roof_y)
	_railing_x(-19.0, -1.55, -12.0, signal_roof_y)
	_railing_x(0.95, 2.0, -12.0, signal_roof_y)

	# Barandillas del cuerpo trasero (y = 8.8).
	_railing_z(-19.0, -12.0, 7.5, 8.8)
	_railing_x(2.0, 19.0, -12.0, 8.8)
	_railing_x(-19.0, 19.0, 7.5, 8.8)
	_railing_x(19.0, 36.0, -12.0, 8.8)
	_railing_z(36.0, -12.0, 2.0, 8.8)

	# Barandilla perimetral de la Terraza del Dron (y = 4.4, sobre el garaje).
	_railing_x(2.2, 18.9, -26.4, 4.4)
	_railing_z(18.9, -26.4, -12.1, 4.4)
	_railing_x(19.0, 30.9, -26.4, 4.4)
	_railing_z(30.9, -26.4, -12.1, 4.4)

	# Plataforma H del dron sobre Terraza del Dron (x=10.5, z=-19.2, y=4.4).
	_box("dark_metal", Vector3(10.5, 4.42, -19.2), Vector3(8.2, 0.04, 8.2), Basis.IDENTITY, false)
	_box("warning", Vector3(10.5, 4.445, -23.0), Vector3(7.8, 0.02, 0.28), Basis.IDENTITY, false)
	_box("warning", Vector3(10.5, 4.445, -15.4), Vector3(7.8, 0.02, 0.28), Basis.IDENTITY, false)
	_box("warning", Vector3(6.7, 4.445, -19.2), Vector3(0.28, 0.02, 7.8), Basis.IDENTITY, false)
	_box("warning", Vector3(14.3, 4.445, -19.2), Vector3(0.28, 0.02, 7.8), Basis.IDENTITY, false)
	_box("paper", Vector3(9.1, 4.445, -19.2), Vector3(0.4, 0.02, 3.2), Basis.IDENTITY, false)
	_box("paper", Vector3(11.9, 4.445, -19.2), Vector3(0.4, 0.02, 3.2), Basis.IDENTITY, false)
	_box("paper", Vector3(10.5, 4.445, -19.2), Vector3(2.6, 0.02, 0.4), Basis.IDENTITY, false)
	var pad := Marker3D.new()
	pad.name = "DronePad"
	pad.position = Vector3(10.5, 4.45, -19.2)
	pad.add_to_group("drone_pad")
	add_child(pad)

	# Parabólica icónica sobre la cubierta elevada de Sala de Señales (y = 10.4) + respiraderos.
	_box("metal", Vector3(-7.5, signal_roof_y + 0.2, -18.5), Vector3(2.0, 0.45, 2.0))
	_box("dark_metal", Vector3(-7.5, signal_roof_y + 1.35, -18.5), Vector3(0.6, 2.1, 0.6))
	_dish_transforms.append(Transform3D(Basis(Vector3.RIGHT, -0.55).scaled(Vector3(1.6, 1.6, 1.6)),
		Vector3(-7.5, signal_roof_y + 2.6, -18.5)))

	_box("dark_metal", Vector3(-13.0, 9.35, -2.0), Vector3(3.6, 1.1, 2.6))
	_box("dark_metal", Vector3(5.0, 9.3, 1.0), Vector3(2.8, 1.0, 2.8))
	_box("metal", Vector3(13.0, 11.8, -4.0), Vector3(0.32, 6.0, 0.32))
	_box("led_red", Vector3(13.0, 14.9, -4.0), Vector3(0.28, 0.28, 0.28), Basis.IDENTITY, false)
	_note("AZOTEA / PARABÓLICA PRINCIPAL", Vector3(-7.5, signal_roof_y + 3.4, -18.5))


func _build_props() -> void:
	# --- PLANTA BAJA: GARAJE DEL SNOWCAT ---
	_build_snowcat_placeholder(Vector3(10.5, 0.0, -16.8))
	_box("dark_metal", Vector3(10.5, 3.95, -26.5), Vector3(7.6, 0.35, 0.32))
	_box("warning", Vector3(6.2, 0.65, -26.9), Vector3(0.28, 1.3, 0.28))
	_box("warning", Vector3(14.8, 0.65, -26.9), Vector3(0.28, 1.3, 0.28))
	_box("light", Vector3(10.5, 4.05, -26.75), Vector3(1.4, 0.16, 0.16), Basis.IDENTITY, false)
	_zone_light(Vector3(10.5, 3.85, -28.0), 16.0, 1.7, WARM_LIGHT)
	_box("wood", Vector3(3.1, 0.5, -16.0), Vector3(1.4, 1.0, 5.2))
	_box("dark_metal", Vector3(2.25, 1.85, -16.0), Vector3(0.1, 1.2, 4.4))
	_box("metal", Vector3(3.3, 1.05, -9.5), Vector3(1.6, 2.1, 2.8))
	_note("GARAJE SNOWCAT", Vector3(10.5, 3.4, -26.2))

	# --- PLANTA BAJA: VESTÍBULO DE ENTRADA ---
	_box("light", Vector3(25.0, 3.55, -26.75), Vector3(1.0, 0.16, 0.16), Basis.IDENTITY, false)
	_zone_light(Vector3(25.0, 3.4, -28.0), 13.0, 1.6, WARM_LIGHT)
	_box("wood", Vector3(21.0, 0.44, -23.5), Vector3(3.2, 0.88, 0.8))
	for i in 4:
		_box("metal", Vector3(30.2, 1.05, -24.5 + float(i) * 1.25), Vector3(0.75, 2.1, 1.0))
	var lockers := Node3D.new()
	lockers.name = "Lockers"
	lockers.position = Vector3(30.2, 1.05, -22.5)
	lockers.add_to_group("lockers")
	add_child(lockers)
	_box("dark_metal", Vector3(19.25, 1.9, -13.8), Vector3(0.1, 1.4, 2.6))
	_note("DIRECTORIO\nPLANTA 0: GARAJE / ALMACÉN\nPLANTA 1: SERVIDORES / DESCANSO\nPUENTE: CONTROL DE SEÑALES\nSÓTANO: BREAKER",
		Vector3(19.4, 2.1, -13.8))

	# --- PLANTA BAJA: ALMACÉN DE SUMINISTROS ---
	for i in 4:
		_box("metal", Vector3(2.9, 1.2, -4.8 + float(i) * 3.0), Vector3(1.0, 2.4, 2.4))
	for i in 3:
		_box("wood", Vector3(9.5 + float(i) * 1.6, 0.55, -5.6), Vector3(1.1, 1.1, 1.1))
	_box("wood", Vector3(10.3, 1.65, -5.6), Vector3(1.0, 1.1, 1.0))
	_note("ALMACÉN DE SUMINISTROS", Vector3(10.5, 2.8, -6.7))

	# --- PLANTA ALTA: PASILLO PRINCIPAL (38 m x 5 m) ---
	for bx in [-14.0, -4.5, 5.0, 14.5]:
		_box("dark_metal", Vector3(bx, 8.35, -9.5), Vector3(9.0, 0.14, 0.75), Basis.IDENTITY, false)
	_box("metal", Vector3(-18.2, 5.5, -9.5), Vector3(0.9, 2.2, 3.4))
	_note("← SERVIDORES | ↑ PUENTE SEÑALES | DESCANSO / BAÑO →", Vector3(0.0, 7.0, -7.2))

	# --- PLANTA ALTA: SALA DE SERVIDORES (CERRADA, 30 RACKS EN PASILLOS AMPLIOS) ---
	for row in 6:
		for col in 5:
			var sx := -16.5 + float(col) * 3.0
			var sz := -4.2 + float(row) * 2.1
			_box("dark_metal", Vector3(sx, 5.5, sz), Vector3(1.25, 2.25, 0.72))
			_box("led_green", Vector3(sx - 0.35, 6.25, sz + 0.38), Vector3(0.08, 0.08, 0.03), Basis.IDENTITY, false)
			_box("led_red", Vector3(sx + 0.35, 6.25, sz + 0.38), Vector3(0.08, 0.08, 0.03), Basis.IDENTITY, false)
			var marker := Marker3D.new()
			marker.name = "Server_%02d_%02d" % [row, col]
			marker.position = Vector3(sx, 4.4, sz)
			marker.add_to_group("server_placeholder")
			add_child(marker)
	_box("metal", Vector3(-10.5, 5.4, 6.7), Vector3(4.8, 2.0, 1.0))
	_note("CLÚSTER DE SERVIDORES\n30 NODOS", Vector3(-10.5, 7.2, -6.7))

	# --- PLANTA ALTA: ZONA DE DESCANSO & COCINA (REFUGIO CÁLIDO) ---
	_box("rug", Vector3(4.5, 4.42, 0.0), Vector3(6.0, 0.03, 4.8), Basis.IDENTITY, false)
	_box("wood", Vector3(-0.6, 4.85, -2.5), Vector3(2.0, 0.5, 3.6))
	_box("paper", Vector3(-0.6, 5.16, -2.5), Vector3(1.8, 0.14, 3.3))
	_box("wood", Vector3(-0.6, 6.05, -2.5), Vector3(2.0, 0.4, 3.6))
	_box("paper", Vector3(-0.6, 6.32, -2.5), Vector3(1.8, 0.14, 3.3))
	_box("wood", Vector3(4.5, 5.15, 0.0), Vector3(2.6, 0.12, 1.6))
	for lx in [-1.05, 1.05]:
		for lz in [-0.62, 0.62]:
			_box("dark_metal", Vector3(4.5 + lx, 4.75, 0.0 + lz), Vector3(0.09, 0.72, 0.09))
	for cx in [2.9, 6.1]:
		_box("wood", Vector3(cx, 4.85, 0.0), Vector3(0.68, 0.88, 0.68))
	_box("light", Vector3(4.5, 5.4, 0.0), Vector3(0.32, 0.24, 0.32), Basis.IDENTITY, false)
	_box("wood", Vector3(8.5, 4.9, 6.2), Vector3(6.0, 1.0, 1.3))
	_box("wood", Vector3(10.8, 4.9, 2.0), Vector3(1.3, 1.0, 6.6))
	_box("metal", Vector3(0.2, 5.45, 6.2), Vector3(1.3, 2.1, 1.2))
	_note("DESCANSO / COCINA", Vector3(5.0, 7.1, 7.0))

	# --- PLANTA ALTA: BAÑO ---
	_box("paper", Vector3(17.6, 4.85, 5.8), Vector3(1.3, 0.9, 1.3))
	_box("paper", Vector3(13.6, 4.9, 6.1), Vector3(1.6, 1.0, 1.1))
	_box("paper", Vector3(17.1, 4.75, -1.8), Vector3(2.6, 0.7, 2.8))
	_box("glass", Vector3(15.7, 5.6, -1.8), Vector3(0.05, 2.3, 2.8), Basis.IDENTITY, false)

	# --- SÓTANO: CUARTO DE ENERGÍA Y BREAKER ---
	_box("dark_metal", Vector3(10.5, -2.95, -11.55), Vector3(3.4, 2.1, 0.35))
	for i in 5:
		_box("warning", Vector3(9.3 + float(i) * 0.6, -3.45, -11.25), Vector3(0.26, 0.14, 0.12))
	_box("warning", Vector3(10.5, -1.8, -11.45), Vector3(1.8, 0.25, 0.1))
	var breaker := Node3D.new()
	breaker.name = "Breaker"
	breaker.position = Vector3(10.5, -3.9, -11.45)
	breaker.add_to_group("breaker")
	add_child(breaker)
	_note("BREAKER PRINCIPAL\nNO REARMAR CON CARGA", Vector3(10.5, -1.3, -11.4))

	for gz in [-4.5, 2.5]:
		_box("dark_metal", Vector3(5.8, -3.4, gz), Vector3(3.6, 2.1, 2.0))
		_box("warning", Vector3(5.8, -4.35, gz), Vector3(4.0, 0.08, 2.4))
		_box("metal", Vector3(4.6, -1.85, gz), Vector3(0.38, 1.3, 0.38))

	for i in 3:
		_box("dark_metal", Vector3(6.2 + float(i) * 4.2, -3.0, 6.7), Vector3(2.4, 2.5, 0.85))
		_box("screen", Vector3(6.2 + float(i) * 4.2, -2.65, 6.22), Vector3(1.1, 0.55, 0.04), Basis.IDENTITY, false)

	_box("metal", Vector3(16.2, -3.3, -7.5), Vector3(2.4, 2.3, 3.8))


func _build_snowcat_placeholder(pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = "SnowcatPlaceholder"
	marker.position = pos
	marker.add_to_group("snowcat_placeholder")
	add_child(marker)
	for sx in [-1.35, 1.35]:
		_box("dark_metal", pos + Vector3(sx, 0.48, 0.0), Vector3(0.72, 0.96, 5.2))
	_box("dark_metal", pos + Vector3(0.0, 1.0, 0.0), Vector3(2.3, 0.48, 4.9))
	_box("metal", pos + Vector3(0.0, 1.52, 1.45), Vector3(2.5, 0.7, 2.3))
	_box("snowcat", pos + Vector3(0.0, 1.95, -0.85), Vector3(2.4, 1.65, 2.3))
	_box("glass", pos + Vector3(0.0, 2.2, -2.02), Vector3(2.05, 0.8, 0.06), Basis.IDENTITY, false)
	_box("warning", pos + Vector3(0.0, 0.48, -3.1), Vector3(3.4, 0.9, 0.38))
	_box("light", pos + Vector3(-0.82, 1.3, -2.05), Vector3(0.3, 0.22, 0.08), Basis.IDENTITY, false)
	_box("light", pos + Vector3(0.82, 1.3, -2.05), Vector3(0.3, 0.22, 0.08), Basis.IDENTITY, false)


## Detalle de Sala de Control de Señales elevada (y = 6.0): ventanal en voladizo,
## bancada de 4 estaciones, impresora matricial, mesa cálida central y vistas exteriores.
func _build_signal_room() -> void:
	var y := SIGNAL_Y
	var window := _signal_detail("SignalWindow", Vector3(-8.5, y + 2.4, -29.0))
	window.set_meta("width", BaseLayout.SIGNAL_WINDOW_WIDTH)

	for mx in [-14.0, -3.0]:
		_box("dark_metal", Vector3(mx, y + 2.4, -28.92), Vector3(0.18, 2.8, 0.24), Basis.IDENTITY, false)

	for bz in [-25.0, -21.0, -17.0]:
		_box("wall", Vector3(-8.5, y + 3.95, bz), Vector3(20.6, 0.34, 0.48), Basis.IDENTITY, false)
	for cx in [-13.5, -3.5]:
		_box("dark_metal", Vector3(cx, y + 3.7, -20.5), Vector3(0.85, 0.14, 15.6), Basis.IDENTITY, false)
		_box("light", Vector3(cx, y + 3.65, -23.0), Vector3(0.22, 0.08, 2.8), Basis.IDENTITY, false)
		_box("light", Vector3(cx, y + 3.65, -17.5), Vector3(0.22, 0.08, 2.8), Basis.IDENTITY, false)

	# Bancada de 4 máquinas físicas frente al ventanal panorámico (y = 6.0 -> marcadores en 7.25).
	_add_panel(-15.5, y, -27.2, 0)
	_add_panel(-10.8, y, -27.9, 1)
	_add_panel(-5.8, y, -27.9, 2)
	_add_panel(-1.2, y, -27.2, 3)

	_box("dark_metal", Vector3(-5.8, y + 0.6, -27.9), Vector3(2.4, 1.2, 0.78))
	_box("screen", Vector3(-6.1, y + 1.05, -27.49), Vector3(1.2, 0.58, 0.04), Basis.IDENTITY, false)
	_box("metal", Vector3(-4.65, y + 0.75, -27.65), Vector3(0.48, 0.36, 0.48), Basis.IDENTITY, false)

	# Estación de terminal de gestión (MainComputer) en flanco oeste.
	_box("dark_metal", Vector3(-16.0, y + 0.5, -18.5), Vector3(2.2, 1.0, 1.2))
	_box("dark_metal", Vector3(-16.0, y + 1.35, -18.78), Vector3(1.3, 0.78, 0.52))
	_box("screen", Vector3(-16.0, y + 1.35, -18.49), Vector3(0.96, 0.54, 0.04), Basis.IDENTITY, false)
	_signal_detail("MainComputerMarker", Vector3(-16.0, y + 1.25, -18.5))

	# Mesa cálida central con alfombra gastada, lámpara de bronce y mapas.
	_signal_detail("TarimaBaja", Vector3(-8.5, y + 0.02, -20.0))
	_box("rug", Vector3(-8.5, y + 0.015, -20.0), Vector3(7.8, 0.03, 5.0), Basis.IDENTITY, false)
	_box("wood", Vector3(-8.5, y + 0.78, -20.0), Vector3(4.0, 0.12, 1.8))
	for lx in [-1.65, 1.65]:
		for lz in [-0.7, 0.7]:
			_box("dark_metal", Vector3(-8.5 + lx, y + 0.38, -20.0 + lz), Vector3(0.1, 0.76, 0.1))
	_box("paper", Vector3(-8.6, y + 0.85, -19.95), Vector3(1.5, 0.02, 1.0), Basis(Vector3.UP, 0.12), false)
	_box("dark_metal", Vector3(-9.9, y + 1.08, -19.55), Vector3(0.18, 0.48, 0.18), Basis.IDENTITY, false)
	_box("light", Vector3(-9.9, y + 1.34, -19.55), Vector3(0.34, 0.18, 0.34), Basis.IDENTITY, false)
	_zone_light(Vector3(-9.9, y + 1.45, -19.55), 8.5, 1.6, WARM_LIGHT)
	for cx in [-9.6, -7.4]:
		_box("wood", Vector3(cx, y + 0.45, -18.4), Vector3(0.7, 0.9, 0.7))

	# Mesa de discos junto a Procesado (MesaDiscos: superficie en y=6.8 -> disco en 6.95).
	_signal_detail("MesaDiscos", Vector3(-2.8, y + 0.8, -20.5))
	_box("wood", Vector3(-2.8, y + 0.78, -20.5), Vector3(2.4, 0.12, 1.2))
	for dx in [-1.05, 1.05]:
		for dz in [-0.46, 0.46]:
			_box("dark_metal", Vector3(-2.8 + dx, y + 0.38, -20.5 + dz), Vector3(0.09, 0.76, 0.09))
	for i in 3:
		_box("metal", Vector3(-3.4 + float(i) * 0.65, y + 0.86, -20.5),
			Vector3(0.44, 0.03, 0.44), Basis.IDENTITY, false)

	# Impresora matricial física en el lado este junto a la puerta de terraza.
	_signal_detail("PrinterPlaceholder", Vector3(0.9, y + 0.8, -17.5))
	_box("metal", Vector3(0.9, y + 0.4, -17.5), Vector3(1.2, 0.8, 1.0))
	_box("paper", Vector3(0.9, y + 1.02, -17.5), Vector3(0.8, 0.4, 0.65))
	_box("paper", Vector3(0.5, y + 0.82, -17.5), Vector3(0.34, 0.03, 0.52), Basis(Vector3.BACK, 0.35), false)
	_box("led_green", Vector3(0.52, y + 1.18, -17.2), Vector3(0.06, 0.06, 0.04), Basis.IDENTITY, false)
	_note("IMPRESORA MATRICIAL", Vector3(0.85, y + 1.65, -17.5))

	# Tablones de notas y armarios en los laterales del muro sur.
	_box("wood", Vector3(-13.8, y + 2.0, -12.22), Vector3(2.8, 1.4, 0.08), Basis.IDENTITY, false)
	_box("paper", Vector3(-14.2, y + 2.1, -12.17), Vector3(0.7, 0.55, 0.02), Basis.IDENTITY, false)
	_box("paper", Vector3(-13.1, y + 1.9, -12.17), Vector3(0.65, 0.75, 0.02), Basis.IDENTITY, false)
	_box("dark_metal", Vector3(-1.8, y + 1.1, -12.45), Vector3(4.0, 2.2, 0.75))
	_signal_detail("RadarPared", Vector3(-18.7, y + 2.0, -14.2))


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
	# Explanada de hormigón frente al garaje, vestíbulo y zona alternativa de entrega.
	_box("floor", Vector3(19.0, -0.09, -31.75), Vector3(34.0, 0.2, 10.5))
	_box("floor", Vector3(33.5, -0.09, -19.25), Vector3(5.0, 0.2, 14.5))
	_box("warning", Vector3(33.5, 0.025, -19.25), Vector3(3.8, 0.02, 5.2), Basis.IDENTITY, false)
	# Muros de contención exteriores de hormigón alrededor del sótano hasta y = 0.0.
	_box("wall", Vector3(2.0, -2.2, -2.25), Vector3(0.4, 4.6, 19.5))
	_box("wall", Vector3(19.0, -2.2, 7.5), Vector3(34.0, 4.6, 0.4))

	# Afloramientos de roca junto a la embocadura del garaje y ladera oeste (estilo concept art).
	var rock_clusters := [
		{"pos": Vector3(0.2, 0.4, -27.8), "size": Vector3(3.6, 2.4, 4.2), "yaw": 0.25},
		{"pos": Vector3(-1.2, 1.2, -13.0), "size": Vector3(4.5, 3.2, 5.0), "yaw": -0.35},
		{"pos": Vector3(-22.5, 1.6, -6.0), "size": Vector3(8.0, 5.0, 12.0), "yaw": 0.18},
		{"pos": Vector3(4.0, 2.2, 11.5), "size": Vector3(18.0, 5.2, 7.0), "yaw": -0.08},
	]
	for rc_variant in rock_clusters:
		var rc: Dictionary = rc_variant
		var rp: Vector3 = rc["pos"]
		_box("rock", rp, rc["size"], Basis(Vector3.UP, float(rc["yaw"])))

	# Postes de luz de madera siguiendo la pista del Snowcat en el valle norte (-Z).
	var pole_points := [
		Vector2(17.5, -42.0),
		Vector2(21.5, -66.0),
		Vector2(35.0, -96.0),
		Vector2(22.0, -132.0),
		Vector2(-10.0, -172.0),
	]
	for pt_variant in pole_points:
		var pt: Vector2 = pt_variant
		var py := TerrainMap.height_at(pt.x, pt.y)
		_box("wood", Vector3(pt.x, py + 3.2, pt.y), Vector3(0.28, 6.4, 0.28))
		_box("wood", Vector3(pt.x, py + 6.0, pt.y), Vector3(1.8, 0.2, 0.2))
		_box("dark_metal", Vector3(pt.x, py + 5.75, pt.y), Vector3(0.32, 0.45, 0.32), Basis.IDENTITY, false)

	# Bosque de pinos anclado a la cota real del terreno en los bordes de pista y laderas.
	var rng := RandomNumberGenerator.new()
	rng.seed = 198304
	for i in 120:
		var angle := TAU * float(i) / 120.0 + rng.randf_range(-0.04, 0.04)
		var radius := rng.randf_range(56.0, 210.0)
		var tx := cos(angle) * radius
		var tz := -30.0 + sin(angle) * radius
		if TerrainMap.road_factor(tx, tz) > 0.08:
			continue
		if tx > -32.0 and tx < 50.0 and tz > -42.0 and tz < 32.0:
			continue
		var ty := TerrainMap.height_at(tx, tz)
		if ty > 28.0:
			continue
		var h := rng.randf_range(7.5, 14.5)
		_box("wood", Vector3(tx, ty + h * 0.18, tz), Vector3(0.45, h * 0.36, 0.45))
		_box("pine", Vector3(tx, ty + h * 0.45, tz), Vector3(3.4, h * 0.32, 3.4), Basis.IDENTITY, false)
		_box("pine", Vector3(tx, ty + h * 0.68, tz), Vector3(2.4, h * 0.28, 2.4), Basis.IDENTITY, false)
		_box("snow", Vector3(tx, ty + h * 0.88, tz), Vector3(1.2, h * 0.16, 1.2), Basis.IDENTITY, false)

	# Domo radar y baliza roja en la cima real del pico norte (TerrainMap.PEAK_CENTER).
	var peak_xz := TerrainMap.PEAK_CENTER
	var peak_y := TerrainMap.height_at(peak_xz.x, peak_xz.y)
	var peak_pos := Vector3(peak_xz.x, peak_y, peak_xz.y)
	_box("wall", peak_pos + Vector3(0.0, 1.75, 0.0), Vector3(4.8, 3.5, 4.8), Basis.IDENTITY, false)
	_box("paper", peak_pos + Vector3(0.0, 5.1, 0.0), Vector3(4.1, 3.4, 4.1), Basis.IDENTITY, false)
	_box("led_red", peak_pos + Vector3(0.0, 7.4, 0.0), Vector3(0.95, 0.95, 0.95), Basis.IDENTITY, false)
	var peak_beacon := OmniLight3D.new()
	peak_beacon.position = peak_pos + Vector3(0.0, 7.8, 0.0)
	peak_beacon.light_color = Color(1.0, 0.12, 0.1)
	peak_beacon.light_energy = 4.5
	peak_beacon.omni_range = 24.0
	peak_beacon.shadow_enabled = false
	add_child(peak_beacon)

	# 24 platos satelitales en anillo de 250 m, apoyados en sus claros del terreno.
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var px := cos(angle) * 250.0
		var pz := sin(angle) * 250.0
		var py := TerrainMap.height_at(px, pz)
		var dish := Marker3D.new()
		dish.name = "Dish%02d" % (i + 1)
		dish.position = Vector3(px, py, pz)
		dish.add_to_group("satellite_dish")
		add_child(dish)
		_box("metal", Vector3(px, py + 0.15, pz), Vector3(1.2, 0.3, 1.2))
		_box("metal", Vector3(px, py + 1.5, pz), Vector3(0.28, 3.0, 0.28))
		_dish_transforms.append(Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.55),
			Vector3(px, py + 3.25, pz)))
		if i < 3:
			_note("SAT-%02d" % (i + 1), Vector3(px, py + 4.8, pz))

	# 3 transformadores exteriores al noreste del vestíbulo.
	for i in 3:
		var tx := 42.0
		var tz := -21.0 + float(i) * 6.5
		var ty := TerrainMap.height_at(tx, tz)
		var transformer := Node3D.new()
		transformer.name = "Transformer%d" % (i + 1)
		transformer.position = Vector3(tx, ty, tz)
		transformer.add_to_group("transformer")
		add_child(transformer)
		_box("metal", Vector3(tx, ty + 0.2, tz), Vector3(3.0, 0.4, 2.2))
		_box("dark_metal", Vector3(tx, ty + 1.4, tz), Vector3(2.4, 2.2, 1.6))
		for fin in 4:
			_box("metal", Vector3(tx - 0.8 + float(fin) * 0.55, ty + 1.4, tz + 0.85),
				Vector3(0.35, 1.8, 0.1))
		_box("warning", Vector3(tx, ty + 2.2, tz + 0.82), Vector3(0.8, 0.4, 0.08))
		_note("TRAFO %s" % ["A", "B", "C"][i], Vector3(tx, ty + 3.2, tz))

	# 3 radares de coordenadas anclados al terreno.
	var radar_positions := [Vector2(-260.0, -260.0), Vector2(260.0, -260.0), Vector2(0.0, 300.0)]
	for i in 3:
		var r2: Vector2 = radar_positions[i]
		var rp := Vector3(r2.x, TerrainMap.height_at(r2.x, r2.y), r2.y)
		var radar := Node3D.new()
		radar.name = "CoordinateRadar%d" % (i + 1)
		radar.position = rp
		radar.add_to_group("coordinate_radar")
		add_child(radar)
		_box("metal", Vector3(rp.x, rp.y + 0.2, rp.z), Vector3(2.0, 0.4, 2.0))
		_box("metal", Vector3(rp.x, rp.y + 3.0, rp.z), Vector3(0.5, 6.0, 0.5))
		_box("dark_metal", Vector3(rp.x, rp.y + 6.0, rp.z), Vector3(2.6, 0.2, 2.6))
		_note("RADAR %d" % (i + 1), Vector3(rp.x, rp.y + 7.2, rp.z))

	# 4 turbinas eólicas en lomas altas.
	var turbine_positions := [Vector2(-560.0, -560.0), Vector2(560.0, -560.0),
		Vector2(-560.0, 560.0), Vector2(560.0, 560.0)]
	for i in 4:
		var t2: Vector2 = turbine_positions[i]
		var tp := Vector3(t2.x, TerrainMap.height_at(t2.x, t2.y), t2.y)
		var turbine := Node3D.new()
		turbine.name = "WindTurbine%d" % (i + 1)
		turbine.position = tp
		turbine.add_to_group("wind_turbine")
		add_child(turbine)
		_box("metal", Vector3(tp.x, tp.y + 9.0, tp.z), Vector3(1.2, 18.0, 1.2))
		_box("dark_metal", Vector3(tp.x, tp.y + 18.2, tp.z), Vector3(2.4, 1.0, 1.4))
		for blade in 3:
			var blade_angle := TAU * float(blade) / 3.0
			var blade_basis := Basis(Vector3(0.0, 0.0, 1.0), blade_angle)
			_box("metal", Vector3(tp.x, tp.y + 18.2, tp.z + 1.0) + blade_basis * Vector3(0.0, 3.5, 0.0),
				Vector3(0.25, 7.0, 0.08), blade_basis)

	# Torre de radio principal en cota alta este.
	var tower_xz := TerrainMap.RADIO_TOWER_POS
	var tower_pos := Vector3(tower_xz.x, TerrainMap.height_at(tower_xz.x, tower_xz.y), tower_xz.y)
	var tower := Node3D.new()
	tower.name = "RadioTower"
	tower.position = tower_pos
	tower.add_to_group("radio_tower")
	add_child(tower)
	_box("metal", Vector3(tower_pos.x, tower_pos.y + 15.0, tower_pos.z), Vector3(1.0, 30.0, 1.0))
	_box("metal", Vector3(tower_pos.x, tower_pos.y + 8.0, tower_pos.z + 1.2), Vector3(0.15, 16.0, 0.15))
	_box("metal", Vector3(tower_pos.x, tower_pos.y + 22.0, tower_pos.z - 1.0), Vector3(0.15, 12.0, 0.15))
	_box("led_red", Vector3(tower_pos.x, tower_pos.y + 30.4, tower_pos.z), Vector3(0.5, 0.5, 0.5), Basis.IDENTITY, false)
	var tower_light := OmniLight3D.new()
	tower_light.position = Vector3(tower_pos.x, tower_pos.y + 30.4, tower_pos.z)
	tower_light.light_color = Color(1.0, 0.1, 0.08)
	tower_light.light_energy = 3.0
	tower_light.omni_range = 12.0
	tower_light.shadow_enabled = false
	add_child(tower_light)
	_note("TORRE DE RADIO", Vector3(tower_pos.x, tower_pos.y + 31.5, tower_pos.z))

	# Iluminación exterior del claro y transformadores.
	_zone_light(Vector3(42.0, 4.0, -14.5), 15.0, 1.5, WARM_LIGHT)
	_zone_light(Vector3(18.0, 6.0, -33.0), 22.0, 1.6, COOL_LIGHT)


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
		multimesh.custom_aabb = AABB(Vector3(-900.0, -30.0, -900.0), Vector3(1800.0, 160.0, 1800.0))
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
		dish_multimesh.custom_aabb = AABB(Vector3(-350.0, -30.0, -350.0), Vector3(700.0, 100.0, 700.0))
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
	light.position = Vector3(0.0, 3.2, 0.0)
	light.light_color = light_color
	light.light_energy = light_energy
	light.omni_range = clampf(range_value * 0.85, 8.0, 30.0)
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
