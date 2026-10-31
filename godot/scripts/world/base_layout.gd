class_name BaseLayout
extends RefCounted
## Plano de Alpha Root Base. Datos puros: sin escena ni geometría.

const WALL_HEIGHT := 3.5
const DOOR_WIDTH := 2.4
const DOOR_HEIGHT := 2.8

## Habitaciones. x/z son la esquina mínima; w/d el tamaño; y la altura del suelo.
## Las puertas se expresan con side + at (x en muros norte/sur, z en este/oeste).
const ROOMS := [
	{
		"id": "corridor", "label": "PASILLO", "x": -26.0, "z": -2.0, "w": 52.0, "d": 4.0, "y": 0.0,
		"doors": [
			{"side": "south", "at": -19.5}, {"side": "south", "at": -10.0},
			{"side": "south", "at": 1.0}, {"side": "south", "at": 17.5},
			{"side": "north", "at": -20.0}, {"side": "north", "at": 0.0},
			{"side": "north", "at": 20.0},
			{"side": "east", "at": 0.0, "width": 3.0, "height": 3.0},
		],
	},
	{
		"id": "reception", "label": "RECEPCIÓN / ADMINISTRACIÓN",
		"x": -26.0, "z": 2.0, "w": 13.0, "d": 16.0, "y": 0.0,
		"doors": [{"side": "north", "at": -19.5}],
	},
	{
		"id": "utility", "label": "UTILITY CLOSET",
		"x": -13.0, "z": 2.0, "w": 6.0, "d": 16.0, "y": 0.0,
		"doors": [{"side": "north", "at": -10.0}],
	},
	{
		"id": "lobby", "label": "ENTRADA / LOBBY",
		"x": -7.0, "z": 2.0, "w": 16.0, "d": 16.0, "y": 0.0,
		"doors": [
			{"side": "north", "at": 1.0},
			{"side": "south", "at": 1.0, "width": 3.0},
		],
	},
	{
		"id": "loading", "label": "LOADING BAY",
		"x": 9.0, "z": 2.0, "w": 17.0, "d": 16.0, "y": 0.0,
		"doors": [
			{"side": "north", "at": 17.5},
			{"side": "east", "at": 10.0, "width": 4.2, "height": 3.2},
		],
	},
	{
		"id": "break_room", "label": "BREAK ROOM",
		"x": -26.0, "z": -18.0, "w": 12.0, "d": 16.0, "y": 0.0,
		"doors": [{"side": "south", "at": -20.0}],
	},
	{
		"id": "signal", "label": "SIGNAL PROCESSING & RESEARCH",
		"x": -14.0, "z": -18.0, "w": 28.0, "d": 16.0, "y": 0.0,
		"doors": [{"side": "south", "at": 0.0}],
	},
	{
		"id": "server_room", "label": "SERVER NETWORK ROOM",
		"x": 14.0, "z": -18.0, "w": 12.0, "d": 16.0, "y": 0.0,
		"doors": [{"side": "south", "at": 20.0}],
	},
	{
		"id": "stairwell", "label": "ESCALERA",
		"x": 26.0, "z": -2.0, "w": 14.0, "d": 4.0, "y": 0.0,
		"doors": [{"side": "west", "at": 0.0, "width": 3.0, "height": 3.0}],
		"floor": false, "ceiling": false,
	},
	{
		"id": "upper_hall", "label": "PLANTA SUPERIOR",
		"x": -20.0, "z": -2.0, "w": 46.0, "d": 4.0, "y": 4.0,
		"doors": [
			{"side": "east", "at": 1.0, "width": 1.8},
			{"side": "north", "at": -12.0}, {"side": "north", "at": 3.0},
			{"side": "south", "at": -12.0}, {"side": "south", "at": 18.0},
		],
		"ceiling": false,
	},
	{
		"id": "dorm", "label": "DORMITORIO",
		"x": -20.0, "z": -16.0, "w": 16.0, "d": 14.0, "y": 4.0,
		"doors": [
			{"side": "south", "at": -12.0},
			{"side": "north", "at": -8.0, "width": 2.0},
		],
		"ceiling": false,
	},
	{
		"id": "bath", "label": "BAÑO",
		"x": -20.0, "z": 2.0, "w": 16.0, "d": 10.0, "y": 4.0,
		"doors": [{"side": "north", "at": -12.0}],
		"ceiling": false,
	},
	{
		"id": "storage", "label": "ALMACÉN SUPERIOR",
		"x": -4.0, "z": -16.0, "w": 14.0, "d": 14.0, "y": 4.0,
		"doors": [{"side": "south", "at": 3.0}],
		"ceiling": false,
	},
	{
		"id": "roof_access", "label": "ACCESO AL TEJADO",
		"x": 10.0, "z": 2.0, "w": 16.0, "d": 10.0, "y": 4.0,
		"doors": [{"side": "north", "at": 18.0}],
		"ceiling": false,
	},
	{
		"id": "balcony", "label": "BALCÓN",
		"x": -12.0, "z": -22.0, "w": 8.0, "d": 6.0, "y": 4.0,
		"doors": [], "walls": false, "ceiling": false,
	},
	{
		"id": "basement_hall", "label": "SÓTANO",
		"x": -20.0, "z": -2.0, "w": 46.0, "d": 4.0, "y": -4.0,
		"doors": [
			{"side": "east", "at": 1.0, "width": 1.8},
			{"side": "north", "at": -13.0}, {"side": "north", "at": 1.0},
			{"side": "north", "at": 14.0},
			{"side": "south", "at": -13.0}, {"side": "south", "at": 1.0},
		],
	},
	{
		"id": "breaker", "label": "BREAKER",
		"x": -20.0, "z": -14.0, "w": 14.0, "d": 12.0, "y": -4.0,
		"doors": [{"side": "south", "at": -13.0}],
	},
	{
		"id": "crematory", "label": "CREMATORIO",
		"x": -6.0, "z": -14.0, "w": 14.0, "d": 12.0, "y": -4.0,
		"doors": [{"side": "south", "at": 1.0}],
	},
	{
		"id": "lockers", "label": "TAQUILLAS",
		"x": 8.0, "z": -14.0, "w": 12.0, "d": 12.0, "y": -4.0,
		"doors": [{"side": "south", "at": 14.0}],
	},
	{
		"id": "transformer", "label": "TRANSFORMADORES",
		"x": -20.0, "z": 2.0, "w": 14.0, "d": 10.0, "y": -4.0,
		"doors": [{"side": "north", "at": -13.0}],
	},
	{
		"id": "basement_storage", "label": "ALMACÉN DEL SÓTANO",
		"x": -6.0, "z": 2.0, "w": 14.0, "d": 10.0, "y": -4.0,
		"doors": [{"side": "north", "at": 1.0}],
	},
	{
		"id": "basement_utility", "label": "TALLER",
		"x": 8.0, "z": 2.0, "w": 12.0, "d": 10.0, "y": -4.0,
		"doors": [{"side": "north", "at": 14.0}],
	},
]

const SPECIAL_ZONES := [
	{"id": "entrance", "label": "ENTRADA PRINCIPAL", "x": 1.0, "y": 0.0, "z": 17.2},
	{"id": "garage", "label": "GARAJE", "x": 21.0, "y": 0.0, "z": 14.0},
	{"id": "roof", "label": "TEJADO", "x": 0.0, "y": 7.7, "z": 0.0},
]

## Plataformas de circulación que no son habitaciones completas.
const PLATFORMS := [
	{"id": "upper_stair_hall", "x": 26.0, "z": 0.0, "w": 8.0, "d": 2.0, "y": 4.0},
	{"id": "upper_landing", "x": 34.0, "z": -2.0, "w": 6.0, "d": 4.0, "y": 4.0},
	{"id": "basement_stair_hall", "x": 26.0, "z": 0.0, "w": 8.0, "d": 2.0, "y": -4.0},
	{"id": "basement_landing", "x": 34.0, "z": -2.0, "w": 6.0, "d": 4.0, "y": -4.0},
]


static func all_rooms() -> Array:
	return ROOMS.duplicate(true)


static func room_count() -> int:
	return ROOMS.size()


static func special_zones() -> Array:
	return SPECIAL_ZONES.duplicate(true)


static func platforms() -> Array:
	return PLATFORMS.duplicate(true)


## Reúne los cuatro lados de cada habitación, deduplicando muros compartidos.
## Devuelve muros con sus huecos de puerta ya fusionados.
static func collect_walls() -> Array:
	var walls: Dictionary = {}
	for room_variant in ROOMS:
		var room: Dictionary = room_variant
		if not bool(room.get("walls", true)):
			continue
		var x := float(room["x"])
		var z := float(room["z"])
		var w := float(room["w"])
		var d := float(room["d"])
		var y := float(room["y"])
		_add_edge(walls, "x", z, x, x + w, y)
		_add_edge(walls, "x", z + d, x, x + w, y)
		_add_edge(walls, "z", x, z, z + d, y)
		_add_edge(walls, "z", x + w, z, z + d, y)

	for room_variant in ROOMS:
		var room: Dictionary = room_variant
		if not bool(room.get("walls", true)):
			continue
		for door_variant in room.get("doors", []):
			var door: Dictionary = door_variant
			var key := _door_key(room, door)
			if not walls.has(key):
				continue
			var wall: Dictionary = walls[key]
			var doors: Array = wall["doors"]
			var exists := false
			for existing_variant in doors:
				var existing: Dictionary = existing_variant
				if is_equal_approx(float(existing["at"]), float(door["at"])) \
						and is_equal_approx(float(existing["width"]), float(door.get("width", DOOR_WIDTH))):
					exists = true
					break
			if not exists:
				doors.append({
					"at": float(door["at"]),
					"width": float(door.get("width", DOOR_WIDTH)),
					"height": float(door.get("height", DOOR_HEIGHT)),
				})
	return walls.values()


static func _add_edge(walls: Dictionary, axis: String, fixed: float,
		start: float, end: float, y: float) -> void:
	var key := _edge_key(axis, fixed, start, end, y)
	if walls.has(key):
		return
	walls[key] = {
		"axis": axis,
		"fixed": fixed,
		"start": minf(start, end),
		"end": maxf(start, end),
		"y": y,
		"doors": [],
	}


static func _edge_key(axis: String, fixed: float, start: float, end: float, y: float) -> String:
	return "%s|%.2f|%.2f|%.2f|%.2f" % [
		axis, fixed, minf(start, end), maxf(start, end), y,
	]


static func _door_key(room: Dictionary, door: Dictionary) -> String:
	var x := float(room["x"])
	var z := float(room["z"])
	var w := float(room["w"])
	var d := float(room["d"])
	var y := float(room["y"])
	match String(door["side"]):
		"north":
			return _edge_key("x", z, x, x + w, y)
		"south":
			return _edge_key("x", z + d, x, x + w, y)
		"west":
			return _edge_key("z", x, z, z + d, y)
		"east":
			return _edge_key("z", x + w, z, z + d, y)
	return ""
