class_name TerrainBuilder
extends Node3D
## Construye la malla esculpida del valle de Kenoma en 3 anillos (4 m / 12 m / 32 m)
## con relieve alpino, detalle normal triplanar y colisión exacta dentro del presupuesto Forward+.

const SNOW_LIGHT := Color(0.56, 0.64, 0.77)
const SNOW_DEEP := Color(0.35, 0.44, 0.58)
const ROAD_COLOR := Color(0.22, 0.27, 0.34)
const ROCK_COLOR := Color(0.14, 0.16, 0.20)
const ICE_COLOR := Color(0.18, 0.30, 0.44)

var _terrain_material: StandardMaterial3D
var _collision: StaticBody3D


func _ready() -> void:
	_terrain_material = _make_material()
	_collision = StaticBody3D.new()
	_collision.name = "TerrainCollision"
	add_child(_collision)

	var collision_faces := PackedVector3Array()
	# Anillo interior de detalle fino (4 m) alrededor de la base y el valle cercano.
	_build_ring("Inner", -144.0, 144.0, 4.0, 0.0, 0.0, collision_faces, true, true)
	# Anillo medio del valle, platos y picos cercanos (12 m).
	_build_ring("Mid", -528.0, 528.0, 12.0, 132.0, -0.14, collision_faces, false, false)
	# Cordón montañoso perimetral hasta 1.1 km de radio (32 m).
	_build_ring("Outer", -1088.0, 1088.0, 32.0, 480.0, -0.45, collision_faces, false, false)

	if not collision_faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		var col := CollisionShape3D.new()
		col.name = "TerrainShape"
		col.shape = shape
		_collision.add_child(col)


func _make_material() -> StandardMaterial3D:
	var grain_noise := FastNoiseLite.new()
	grain_noise.seed = 198311
	grain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grain_noise.fractal_octaves = 4
	grain_noise.frequency = 0.075

	var normal_tex := NoiseTexture2D.new()
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 4.5
	normal_tex.noise = grain_noise

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.90
	mat.metallic = 0.0
	mat.normal_enabled = true
	mat.normal_scale = 0.55
	mat.normal_texture = normal_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.055, 0.055, 0.055)
	return mat


func _build_ring(tag: String, min_coord: float, max_coord: float, step: float,
		inner_skip_half: float, overlap_drop: float,
		collision_faces: PackedVector3Array, carve_base: bool, split_quads: bool) -> void:
	if not split_quads:
		var single := _build_quad_mesh(
			min_coord, max_coord, min_coord, max_coord,
			step, inner_skip_half, overlap_drop, collision_faces, carve_base
		)
		if single != null:
			var single_inst := MeshInstance3D.new()
			single_inst.name = "Terrain_" + tag
			single_inst.mesh = single
			single_inst.material_override = _terrain_material
			single_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(single_inst)
		return
	var quads := [
		{"suffix": "NW", "x0": min_coord, "x1": 0.0, "z0": min_coord, "z1": 0.0},
		{"suffix": "NE", "x0": 0.0, "x1": max_coord, "z0": min_coord, "z1": 0.0},
		{"suffix": "SW", "x0": min_coord, "x1": 0.0, "z0": 0.0, "z1": max_coord},
		{"suffix": "SE", "x0": 0.0, "x1": max_coord, "z0": 0.0, "z1": max_coord},
	]
	for q_variant in quads:
		var q: Dictionary = q_variant
		var mesh := _build_quad_mesh(
			float(q["x0"]), float(q["x1"]), float(q["z0"]), float(q["z1"]),
			step, inner_skip_half, overlap_drop, collision_faces, carve_base
		)
		if mesh == null:
			continue
		var inst := MeshInstance3D.new()
		inst.name = "Terrain_%s_%s" % [tag, String(q["suffix"])]
		inst.mesh = mesh
		inst.material_override = _terrain_material
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(inst)


func _build_quad_mesh(x0: float, x1: float, z0: float, z1: float, step: float,
		inner_skip_half: float, overlap_drop: float,
		collision_faces: PackedVector3Array, carve_base: bool) -> ArrayMesh:
	var cols := int(round((x1 - x0) / step))
	var rows := int(round((z1 - z0) / step))
	if cols <= 0 or rows <= 0:
		return null

	var stride := cols + 1
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	positions.resize((cols + 1) * (rows + 1))
	normals.resize((cols + 1) * (rows + 1))
	colors.resize((cols + 1) * (rows + 1))

	for rz in rows + 1:
		var z := z0 + float(rz) * step
		for rx in cols + 1:
			var x := x0 + float(rx) * step
			var idx := rz * stride + rx
			var y := TerrainMap.height_at(x, z)
			if overlap_drop < 0.0 and absf(x) < inner_skip_half + step * 1.1 \
					and absf(z) < inner_skip_half + step * 1.1:
				y += overlap_drop
			var n := TerrainMap.normal_at(x, z)
			positions[idx] = Vector3(x, y, z)
			normals[idx] = n
			colors[idx] = _vertex_color(x, y, z, n)

	var indices := PackedInt32Array()
	for rz in rows:
		var zc := z0 + (float(rz) + 0.5) * step
		for rx in cols:
			var xc := x0 + (float(rx) + 0.5) * step
			if inner_skip_half > 0.0 and absf(xc) < inner_skip_half and absf(zc) < inner_skip_half:
				continue
			if carve_base and TerrainMap.is_inside_building_cutout(xc, zc):
				continue
			var i00 := rz * stride + rx
			var i10 := i00 + 1
			var i01 := i00 + stride
			var i11 := i01 + 1
			indices.append(i00)
			indices.append(i10)
			indices.append(i11)
			indices.append(i00)
			indices.append(i11)
			indices.append(i01)

			collision_faces.append(positions[i00])
			collision_faces.append(positions[i10])
			collision_faces.append(positions[i11])
			collision_faces.append(positions[i00])
			collision_faces.append(positions[i11])
			collision_faces.append(positions[i01])

	if indices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _vertex_color(x: float, y: float, z: float, n: Vector3) -> Color:
	var snow := SNOW_DEEP.lerp(SNOW_LIGHT, clampf((y + 6.0) / 70.0, 0.0, 1.0))
	var slope := clampf((0.88 - n.y) / 0.22, 0.0, 1.0)
	var col := snow.lerp(ROCK_COLOR, slope)

	var creek_z := -156.0 + sin(x * 0.017) * 28.0 - cos(x * 0.008) * 16.0
	if absf(x) < 500.0 and absf(z - creek_z) < 9.5 and y < -2.2:
		var ice_t := clampf((9.5 - absf(z - creek_z)) / 9.5, 0.0, 1.0)
		col = col.lerp(ICE_COLOR, ice_t * 0.80)

	var road := TerrainMap.road_factor(x, z)
	if road > 0.01:
		col = col.lerp(ROAD_COLOR, road * 0.86)
	return col
