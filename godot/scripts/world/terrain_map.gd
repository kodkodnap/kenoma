class_name TerrainMap
extends RefCounted
## Topografía determinista del valle alpino de Kenoma (2.2 km x 2.2 km).
## Relieve multifractal con crestas rocosas, lomas continuas, micro-dunas de nieve,
## cauce helado y pistas apisonadas para el Snowcat.

const WORLD_HALF_SIZE := 1088.0
const PEAK_CENTER := Vector2(52.0, -335.0)
const CRAG_CENTER := Vector2(-205.0, -295.0)
const RADIO_TOWER_POS := Vector2(390.0, -150.0)
const GATE_POS := Vector2(-190.0, -720.0)

static var _noise_ridge: FastNoiseLite
static var _noise_hills: FastNoiseLite
static var _noise_drift: FastNoiseLite
static var _cached_pads: Array = []


static func _ensure_noise() -> void:
	if _noise_ridge != null:
		return
	_noise_ridge = FastNoiseLite.new()
	_noise_ridge.seed = 19830419
	_noise_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise_ridge.fractal_octaves = 4
	_noise_ridge.fractal_lacunarity = 2.05
	_noise_ridge.fractal_gain = 0.52
	_noise_ridge.frequency = 0.0024

	_noise_hills = FastNoiseLite.new()
	_noise_hills.seed = 19830711
	_noise_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_hills.fractal_octaves = 4
	_noise_hills.frequency = 0.0052

	_noise_drift = FastNoiseLite.new()
	_noise_drift.seed = 19830907
	_noise_drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_drift.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise_drift.fractal_octaves = 3
	_noise_drift.frequency = 0.026


## Altura del terreno en coordenadas mundo (x, z). Determinista para co-op y props.
static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)
	var dist_base := p.distance_to(Vector2(6.0, -14.0))

	# 1. Ruido continuo de colinas y ventisqueros desde pocos metros fuera de la base.
	var ridge_val := clampf(_noise_ridge.get_noise_2d(x, z), 0.0, 1.0)
	var hills_val := _noise_hills.get_noise_2d(x, z)
	var drift_val := _noise_drift.get_noise_2d(x, z)

	var near_relief := _smoothstep(24.0, 120.0, dist_base)
	var mid_relief := _smoothstep(65.0, 260.0, dist_base)

	var valley := drift_val * lerpf(0.6, 2.8, near_relief)
	valley += hills_val * lerpf(3.2, 26.0, near_relief)
	valley += pow(ridge_val, 1.45) * 42.0 * mid_relief

	# Depresión suave del claro inmediato al norte frente al voladizo para abrir vista al valle.
	var clearing_t := 1.0 - _smoothstep(45.0, 155.0, p.distance_to(Vector2(0.0, -78.0)))
	valley -= clearing_t * 3.8

	# 2. Cordón alpino en anfiteatro (crestas grandes visibles desde la estación, 60..220 m).
	var rim_t := clampf((dist_base - 250.0) / 560.0, 0.0, 1.45)
	var alpine_wall := pow(rim_t, 1.55) * (75.0 + 135.0 * pow(ridge_val, 1.15))
	valley += alpine_wall

	# 3. Macizo trasero y flanco oeste abrazando la estación de forma orgánica (sin cajas cuadradas).
	var south_slope := _smoothstep(6.0, 145.0, z) * (1.0 - _smoothstep(180.0, 420.0, absf(x - 5.0)))
	var west_slope := _smoothstep(-22.0, -155.0, x) * (1.0 - _smoothstep(120.0, 320.0, absf(z + 10.0)))
	var flank_noise := 0.55 + 0.65 * ridge_val + 0.25 * hills_val
	valley = maxf(valley, (south_slope * 62.0 + west_slope * 44.0) * flank_noise - 1.5)

	# 4. Pico principal del domo radar al norte (~78 m) y segundo espolón rocoso al noroeste (~68 m).
	var peak_dist := p.distance_to(PEAK_CENTER)
	if peak_dist < 170.0:
		var pt := 1.0 - peak_dist / 170.0
		var peak_h := 78.0 * pow(pt, 1.55)
		var peak_crag := _noise_drift.get_noise_2d(x * 1.3, z * 1.3) * 5.2 * pt
		if peak_dist < 10.0:
			peak_crag = 0.0
		valley = maxf(valley, peak_h + peak_crag)

	var crag_dist := p.distance_to(CRAG_CENTER)
	if crag_dist < 155.0:
		var ct_crag := 1.0 - crag_dist / 155.0
		valley = maxf(valley, 66.0 * pow(ct_crag, 1.5) + ridge_val * 14.0 * ct_crag)

	# 5. Cauce/hondonada helada serpenteando por el valle medio (z ~ -140..-195).
	var creek_z := -156.0 + sin(x * 0.017) * 28.0 - cos(x * 0.008) * 16.0
	var creek_dist := absf(z - creek_z)
	if creek_dist < 32.0 and absf(x) < 520.0:
		valley -= _smoothstep(32.0, 0.0, creek_dist) * 6.5

	# 6. Aplanado suave de claros para platos, radares, turbinas y torre.
	for site_variant in structure_pads():
		var site: Dictionary = site_variant
		var center: Vector2 = site["pos"]
		var radius: float = float(site["radius"])
		var d := p.distance_to(center)
		if d < radius * 2.2:
			var pad_y := float(site["y"])
			var w := _smoothstep(radius * 2.2, radius, d)
			valley = lerpf(valley, pad_y, w)

	# 7. Red de pistas apisonadas del Snowcat (ancha lo justo, sin aplanar el resto del claro).
	var road := road_factor(x, z)
	if road > 0.001:
		var road_target := _road_elevation(x, z)
		valley = lerpf(valley, road_target, road * 0.85)

	# 8. Integración ajustada exclusivamente a la huella de la estación:
	# Explanada frontal estrecha frente al garaje/vestíbulo (x: 2..36, z: -34.5..-25.5).
	var apron_dist := _box_distance(p, Vector2(2.0, -34.5), Vector2(36.0, -25.5))
	if apron_dist < 6.5:
		var aw := _smoothstep(6.5, 0.5, apron_dist)
		valley = lerpf(valley, -0.18, aw)

	# Terraza pequeña para los 3 transformadores (x: 38..46, z: -24..-5).
	var trafo_dist := _box_distance(p, Vector2(38.0, -24.0), Vector2(46.0, -5.0))
	if trafo_dist < 7.5:
		var tw := _smoothstep(7.5, 0.8, trafo_dist)
		valley = lerpf(valley, -0.18, tw)

	# Pendiente esculpida bajo el ala en voladizo (x: -20..2, z: -30..-11.5) para lucir pilares altos.
	var under_cantilever := _box_distance(p, Vector2(-20.0, -30.0), Vector2(2.0, -11.5))
	if under_cantilever < 6.0:
		var cw := _smoothstep(6.0, 0.5, under_cantilever)
		var slope_x := clampf((-x + 2.0) / 21.0, 0.0, 1.0)
		var target_under := lerpf(-0.35, -3.1, slope_x) + drift_val * 0.35
		valley = lerpf(valley, target_under, cw)

	# Vaciado estricto del sótano [2..36] x [-12..7.5].
	var basement_dist := _box_distance(p, Vector2(2.0, -12.0), Vector2(36.0, 7.5))
	if basement_dist < 3.0:
		var bw := _smoothstep(3.0, 0.3, basement_dist)
		valley = lerpf(valley, -5.1, bw)

	# Protección bajo Server/Living/Bath (y=4.4) para que la ladera no invada las habitaciones.
	if x >= -20.5 and x <= 2.5 and z >= -12.5 and z <= 7.8:
		valley = minf(valley, 3.3)

	return valley


## Factor [0..1] indicando si (x, z) pertenece a la pista del Snowcat.
static func road_factor(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var min_d := 999.0

	var main_road := [
		Vector2(10.5, -33.0),
		Vector2(13.0, -64.0),
		Vector2(28.0, -104.0),
		Vector2(10.0, -148.0),
		Vector2(-36.0, -198.0),
		Vector2(-86.0, -258.0),
		Vector2(-128.0, -365.0),
		Vector2(-168.0, -525.0),
		GATE_POS,
	]
	min_d = minf(min_d, _polyline_distance(p, main_road))

	var ring_r := p.length()
	min_d = minf(min_d, absf(ring_r - 250.0))

	var trafo_road := [
		Vector2(25.0, -31.0),
		Vector2(42.0, -29.0),
		Vector2(42.0, -14.0),
	]
	min_d = minf(min_d, _polyline_distance(p, trafo_road))

	return _smoothstep(4.6, 2.0, min_d)


static func normal_at(x: float, z: float) -> Vector3:
	var eps := 1.4
	var hl := height_at(x - eps, z)
	var hr := height_at(x + eps, z)
	var hd := height_at(x, z - eps)
	var hu := height_at(x, z + eps)
	return Vector3(hl - hr, 2.0 * eps, hd - hu).normalized()


## Indica si el punto cae dentro del hueco estructural de la base cerrada.
static func is_inside_building_cutout(x: float, z: float) -> bool:
	return x >= 2.2 and x <= 35.8 and z >= -11.8 and z <= 7.3


## Lista cacheada de claros nivelados para platos, radares, turbinas y torre.
static func structure_pads() -> Array:
	if not _cached_pads.is_empty():
		return _cached_pads
	var pads: Array = []
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var px := cos(angle) * 250.0
		var pz := sin(angle) * 250.0
		pads.append({"pos": Vector2(px, pz), "radius": 8.0, "y": _raw_pad_elevation(px, pz)})
	for rp in [Vector2(-260.0, -260.0), Vector2(260.0, -260.0), Vector2(0.0, 300.0)]:
		pads.append({"pos": rp, "radius": 9.5, "y": _raw_pad_elevation(rp.x, rp.y) + 8.0})
	for tp in [Vector2(-560.0, -560.0), Vector2(560.0, -560.0),
			Vector2(-560.0, 560.0), Vector2(560.0, 560.0)]:
		pads.append({"pos": tp, "radius": 13.0, "y": _raw_pad_elevation(tp.x, tp.y) + 28.0})
	pads.append({"pos": RADIO_TOWER_POS, "radius": 11.0, "y": 44.0})
	_cached_pads = pads
	return _cached_pads


static func _road_elevation(x: float, z: float) -> float:
	_ensure_noise()
	var p := Vector2(x, z)
	var d := p.length()
	if d < 46.0:
		return -0.18
	var creek_z := -156.0 + sin(x * 0.017) * 28.0 - cos(x * 0.008) * 16.0
	var creek_dip := _smoothstep(32.0, 0.0, absf(z - creek_z)) * 5.4 if absf(x) < 520.0 else 0.0
	var gentle := _noise_hills.get_noise_2d(x * 0.65, z * 0.65) * 14.0
	var rim_t := clampf((d - 280.0) / 560.0, 0.0, 1.0)
	return clampf(gentle - 2.0 - creek_dip + rim_t * 36.0, -10.0, 48.0)


static func _raw_pad_elevation(x: float, z: float) -> float:
	_ensure_noise()
	var d := Vector2(x, z).length()
	var rim_t := clampf((d - 260.0) / 560.0, 0.0, 1.3)
	var ridge := clampf(_noise_ridge.get_noise_2d(x, z), 0.0, 1.0)
	return _noise_hills.get_noise_2d(x, z) * 18.0 + pow(rim_t, 1.4) * 90.0 * (0.45 + 0.55 * ridge)


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
