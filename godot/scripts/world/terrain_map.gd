class_name TerrainMap
extends RefCounted
## Topografía determinista del valle alpino de Kenoma (2 km x 2 km).
## Lógica pura sin nodos: base, pistas del Snowcat, cauce helado, pico del radar y anclaje en cota.

const WORLD_HALF_SIZE := 1000.0
const PEAK_CENTER := Vector2(45.0, -325.0)
const RADIO_TOWER_POS := Vector2(390.0, -150.0)
const GATE_POS := Vector2(-190.0, -720.0)

static var _noise_large: FastNoiseLite
static var _noise_detail: FastNoiseLite
static var _cached_pads: Array = []


static func _ensure_noise() -> void:
	if _noise_large != null:
		return
	_noise_large = FastNoiseLite.new()
	_noise_large.seed = 19830419
	_noise_large.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_large.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_large.fractal_octaves = 4
	_noise_large.frequency = 0.0042

	_noise_detail = FastNoiseLite.new()
	_noise_detail.seed = 19830907
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_detail.fractal_octaves = 3
	_noise_detail.frequency = 0.022


## Altura del terreno en coordenadas mundo (x, z). Determinista para co-op y colocación de props.
static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)

	# 1. Relieve base del valle: ondulaciones suaves + micro-detalle.
	var valley := _noise_large.get_noise_2d(x, z) * 14.0
	valley += _noise_detail.get_noise_2d(x, z) * 2.4

	# El claro norte frente al voladizo empieza ligeramente deprimido (-2..-4 m) y sube hacia los bordes.
	var dist_center := p.length()
	var basin_dish := clampf((dist_center - 95.0) / 360.0, 0.0, 1.0)
	valley *= lerpf(0.28, 1.0, basin_dish)
	valley -= (1.0 - basin_dish) * 2.2

	# 2. Cordón montañoso perimetral (anfiteatro natural a partir de r = 460 m).
	var rim_t := clampf((dist_center - 440.0) / 480.0, 0.0, 1.35)
	var rim_ridge := (0.65 + 0.35 * _noise_large.get_noise_2d(x * 0.55 + 120.0, z * 0.55 - 80.0))
	valley += pow(rim_t, 1.65) * 125.0 * maxf(0.45, rim_ridge)

	# 3. Pico del domo radar lejano al norte (visible desde el ventanal de 18 m).
	var peak_dist := p.distance_to(PEAK_CENTER)
	if peak_dist < 130.0:
		var pt := 1.0 - peak_dist / 130.0
		var peak_h := 50.0 * pow(pt, 1.55)
		var peak_crag := _noise_detail.get_noise_2d(x * 1.4, z * 1.4) * 3.5 * pt * (1.0 - pt * 0.6)
		# Meseta pequeña en la cima para asentar la caseta del domo radar.
		if peak_dist < 8.5:
			peak_crag = 0.0
		valley = maxf(valley, peak_h + peak_crag)

	# 4. Cauce/hondonada helada serpenteando por el valle medio (z ~ -140..-195).
	var creek_z := -152.0 + sin(x * 0.018) * 26.0 - cos(x * 0.008) * 14.0
	var creek_dist := absf(z - creek_z)
	if creek_dist < 34.0 and absf(x) < 480.0:
		var ct := _smoothstep(34.0, 0.0, creek_dist)
		valley -= ct * 5.2

	# 5. Alomado de la torre de radio al este.
	var tower_dist := p.distance_to(RADIO_TOWER_POS)
	if tower_dist < 85.0:
		var tt := _smoothstep(85.0, 12.0, tower_dist)
		valley = lerpf(valley, 26.0, tt)

	# 6. Aplanado suave bajo los platos satelitales, radares y turbinas.
	for site_variant in structure_pads():
		var site: Dictionary = site_variant
		var center: Vector2 = site["pos"]
		var radius: float = float(site["radius"])
		var d := p.distance_to(center)
		if d < radius * 2.1:
			var pad_y: float = float(site["y"])
			var w := _smoothstep(radius * 2.1, radius, d)
			valley = lerpf(valley, pad_y, w)

	# 7. Red de pistas del Snowcat (suaviza laderas y abre rasantes transitables).
	var road := road_factor(x, z)
	if road > 0.001:
		var road_target := _road_elevation(x, z)
		valley = lerpf(valley, road_target, road * 0.88)

	# 8. Integración exacta de la estación en la ladera:
	# - Frente del garaje/vestíbulo/transformadores plano a y = -0.15.
	# - Bajo el ala en voladizo (x: -22..2, z: -32..-12) baja suavemente hacia -2.4 m para lucir pilares altos.
	# - Ladera trasera y oeste abrazando el edificio (z > 8 y x < -20).
	var back_hill := 0.0
	if z > 4.0 and x > -75.0 and x < 75.0:
		var bz := clampf((z - 6.0) / 42.0, 0.0, 1.0)
		var bx := 1.0 - clampf((absf(x - 6.0) - 34.0) / 40.0, 0.0, 1.0)
		back_hill = bz * bx * 22.0
	var west_hill := 0.0
	if x < -18.0 and z > -24.0 and z < 35.0:
		var wx := clampf((-18.0 - x) / 36.0, 0.0, 1.0)
		var wz := 1.0 - clampf((absf(z - 4.0) - 20.0) / 22.0, 0.0, 1.0)
		west_hill = wx * wz * 14.0
	valley = maxf(valley, back_hill + west_hill - 1.5)

	# Explanada frontal del garaje, vestíbulo y zona de transformadores (y ~ -0.18).
	var apron_dist := _box_distance(p, Vector2(-1.0, -40.0), Vector2(49.0, -10.0))
	if apron_dist < 18.0:
		var aw := _smoothstep(18.0, 2.0, apron_dist)
		valley = lerpf(valley, -0.18, aw)

	# Pendiente esculpida bajo el voladizo para despejar pilares altos (x: -22..2, z: -34..-11).
	var under_cantilever := _box_distance(p, Vector2(-21.0, -32.0), Vector2(2.0, -11.5))
	if under_cantilever < 10.0:
		var cw := _smoothstep(10.0, 1.5, under_cantilever)
		var slope_x := clampf((-x + 2.0) / 22.0, 0.0, 1.0)
		var target_under := lerpf(-0.25, -2.55, slope_x)
		valley = lerpf(valley, target_under, cw)

	# Excavación estricta del sótano y huella cerrada del edificio [1.8..36.2] x [-12.2..7.7].
	var basement_dist := _box_distance(p, Vector2(2.0, -12.0), Vector2(36.0, 7.5))
	if basement_dist < 3.5:
		var bw := _smoothstep(3.5, 0.4, basement_dist)
		valley = lerpf(valley, -5.0, bw)

	# Lado sur de Server/Living/Bath (z: -7..7.5, x: -19..2) apoyado a cota ~ 3.8..4.0 m o libre.
	# No debe rebasar el techo ni invadir el pasillo superior (y=4.4).
	if x >= -21.0 and x <= 2.5 and z >= -12.5 and z <= 8.0:
		valley = minf(valley, 3.6)

	return valley


## Factor [0..1] indicando si (x, z) pertenece a una pista apisonada para el Snowcat.
static func road_factor(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var min_d := 999.0

	# Pista principal: desde el garaje hacia el norte, rodeando el pico y rumbo a la entrada futura.
	var main_road := [
		Vector2(10.5, -34.0),
		Vector2(14.0, -68.0),
		Vector2(30.0, -108.0),
		Vector2(12.0, -148.0),
		Vector2(-32.0, -195.0),
		Vector2(-82.0, -255.0),
		Vector2(-125.0, -360.0),
		Vector2(-165.0, -520.0),
		GATE_POS,
	]
	min_d = minf(min_d, _polyline_distance(p, main_road))

	# Ramal de enlace hacia el anillo de 24 platos (radio ~250 m).
	var ring_r := p.length()
	min_d = minf(min_d, absf(ring_r - 250.0))

	# Ramal corto hacia el transformador exterior y entrada este.
	var trafo_road := [
		Vector2(25.0, -32.0),
		Vector2(42.0, -30.0),
		Vector2(45.0, -14.0),
	]
	min_d = minf(min_d, _polyline_distance(p, trafo_road))

	return _smoothstep(5.8, 2.4, min_d)


static func normal_at(x: float, z: float) -> Vector3:
	var eps := 1.5
	var hl := height_at(x - eps, z)
	var hr := height_at(x + eps, z)
	var hd := height_at(x, z - eps)
	var hu := height_at(x, z + eps)
	return Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()


## Indica si el punto cae dentro del hueco estructural de la base cerrada (no generar suelo ahí).
static func is_inside_building_cutout(x: float, z: float) -> bool:
	return x >= 2.2 and x <= 35.8 and z >= -11.8 and z <= 7.3


## Lista determinista de plataformas/claros nivelados para platos, radares, turbinas y torre.
static func structure_pads() -> Array:
	if not _cached_pads.is_empty():
		return _cached_pads
	var pads: Array = []
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var px := cos(angle) * 250.0
		var pz := sin(angle) * 250.0
		var base_y := _raw_pad_elevation(px, pz)
		pads.append({"pos": Vector2(px, pz), "radius": 9.0, "y": base_y})
	for rp in [Vector2(-260.0, -260.0), Vector2(260.0, -260.0), Vector2(0.0, 300.0)]:
		pads.append({"pos": rp, "radius": 10.0, "y": _raw_pad_elevation(rp.x, rp.y) + 4.5})
	for tp in [Vector2(-560.0, -560.0), Vector2(560.0, -560.0),
			Vector2(-560.0, 560.0), Vector2(560.0, 560.0)]:
		pads.append({"pos": tp, "radius": 14.0, "y": _raw_pad_elevation(tp.x, tp.y) + 12.0})
	pads.append({"pos": RADIO_TOWER_POS, "radius": 12.0, "y": 26.0})
	_cached_pads = pads
	return _cached_pads


static func _road_elevation(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)
	var d := p.length()
	if d < 55.0:
		return -0.18
	var creek_z := -152.0 + sin(x * 0.018) * 26.0 - cos(x * 0.008) * 14.0
	var creek_dip := _smoothstep(32.0, 0.0, absf(z - creek_z)) * 4.5 if absf(x) < 480.0 else 0.0
	var gentle := _noise_large.get_noise_2d(x * 0.6, z * 0.6) * 8.0
	var rim_t := clampf((d - 440.0) / 480.0, 0.0, 1.0)
	return clampf(gentle - 1.5 - creek_dip + rim_t * 28.0, -8.0, 35.0)


static func _raw_pad_elevation(x: float, z: float) -> float:
	_ensure_noise()
	var d := Vector2(x, z).length()
	var rim_t := clampf((d - 440.0) / 480.0, 0.0, 1.2)
	return _noise_large.get_noise_2d(x, z) * 11.0 + pow(rim_t, 1.5) * 85.0


static func _polyline_distance(p: Vector2, pts: Array) -> float:
	var best := 99999.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(closest))
	return best


static func _box_distance(p: Vector2, bmin: Vector2, bmax: Vector2) -> float:
	var dx := maxf(bmin.x - p.x, maxf(0.0, p.x - bmax.x))
	var dz := maxf(bmin.y - p.y, maxf(0.0, p.y - bmax.y))
	return sqrt(dx * dx + dz * dz)


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
