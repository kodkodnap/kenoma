class_name TerrainBuilder
extends Node3D
## Construye la malla esculpida del valle de Kenoma en 3 anillos (4 m / 12 m / 32 m)
## con shader triplanar PBR de nieve esculpida, granito estratificado, hielo y pistas.

const TERRAIN_SHADER_CODE := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_noise : filter_linear_mipmap, repeat_enable;

varying vec3 v_world_pos;
varying vec3 v_world_norm;
varying vec4 v_mask;

float sample_triplanar(sampler2D tex, vec3 p, vec3 w, float scale) {
	float nx = texture(tex, p.zy * scale).r;
	float ny = texture(tex, p.xz * scale).r;
	float nz = texture(tex, p.xy * scale).r;
	return nx * w.x + ny * w.y + nz * w.z;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_mask = COLOR;
}

void fragment() {
	vec3 nw = normalize(v_world_norm);
	vec3 tw = pow(abs(nw), vec3(4.0));
	tw /= max(tw.x + tw.y + tw.z, 0.0001);

	// El sastrugi solo tiñe el color; el grano fino (isótropo) da el relieve de la nieve.
	vec2 wind_uv = vec2(
		v_world_pos.x * 0.022 + v_world_pos.z * 0.011,
		v_world_pos.z * 0.048 - v_world_pos.x * 0.016
	);
	float sastrugi = texture(snow_noise, wind_uv).r;
	float snow_fine = texture(snow_noise, v_world_pos.xz * 0.16).r;
	float snow_dx = texture(snow_noise, (v_world_pos.xz + vec2(0.10, 0.0)) * 0.16).r - snow_fine;
	float snow_dz = texture(snow_noise, (v_world_pos.xz + vec2(0.0, 0.10)) * 0.16).r - snow_fine;

	// Granito estratificado: bandas horizontales con juntas finas en paredes y crestas.
	float r_tri = sample_triplanar(rock_noise, v_world_pos, tw, 0.032);
	float r_fine = sample_triplanar(rock_noise, v_world_pos, tw, 0.135);
	float strata_wave = sin(v_world_pos.y * 0.8 + r_tri * 4.0 + v_world_pos.x * 0.02);
	float strata = smoothstep(-0.25, 0.55, strata_wave);
	float seam = smoothstep(0.90, 0.99, strata_wave);
	float rock_dx = texture(rock_noise, (v_world_pos.xz + vec2(0.25, 0.0)) * 0.05).r
		- texture(rock_noise, v_world_pos.xz * 0.05).r;
	float rock_dz = texture(rock_noise, (v_world_pos.xz + vec2(0.0, 0.25)) * 0.05).r
		- texture(rock_noise, v_world_pos.xz * 0.05).r;

	float alt_t = clamp((v_world_pos.y + 8.0) / 85.0, 0.0, 1.0);
	vec3 snow_deep = vec3(0.30, 0.39, 0.53);
	vec3 snow_lit = vec3(0.60, 0.69, 0.81);
	vec3 snow_col = mix(snow_deep, snow_lit, clamp(alt_t * 0.70 + sastrugi * 0.28, 0.0, 1.0));
	snow_col *= 0.94 + 0.10 * snow_fine;

	vec3 rock_dark = vec3(0.09, 0.11, 0.14);
	vec3 rock_slate = vec3(0.24, 0.26, 0.30);
	vec3 rock_col = mix(rock_dark, rock_slate, clamp(r_tri * 0.45 + strata * 0.55, 0.0, 1.0));
	rock_col *= (1.0 - seam * 0.16) * (0.86 + 0.24 * r_fine);

	float cliff_t = smoothstep(0.86, 0.63, nw.y + (r_tri - 0.5) * 0.14);
	vec3 col = mix(snow_col, rock_col, cliff_t);
	float rough = mix(mix(0.80, 0.90, snow_fine), 0.94, cliff_t);

	// Cauce helado: hielo azul veteado, liso y especular.
	float ice_t = clamp(v_mask.g, 0.0, 1.0);
	if (ice_t > 0.01) {
		float vein = 0.5 + 0.5 * sin(v_world_pos.x * 0.35 + v_world_pos.z * 0.12 + r_fine * 4.0);
		float crack = smoothstep(0.55, 0.85, r_fine * 0.6 + vein * 0.4);
		vec3 ice_col = mix(vec3(0.20, 0.42, 0.50), vec3(0.42, 0.66, 0.72), crack * 0.60);
		col = mix(col, ice_col, ice_t * 0.95);
		rough = mix(rough, 0.18, ice_t * 0.92);
	}

	// Pista compactada del Snowcat: roderas paralelas y gravilla helada.
	float road_t = clamp(v_mask.r, 0.0, 1.0);
	if (road_t > 0.01) {
		float ruts = 0.5 + 0.5 * cos(v_world_pos.x * 1.6 + v_world_pos.z * 0.6);
		float gravel = smoothstep(0.62, 0.82, snow_fine);
		vec3 road_col = mix(vec3(0.20, 0.20, 0.22), vec3(0.34, 0.33, 0.34), ruts * 0.45 + gravel * 0.4);
		col = mix(col, road_col, road_t * 0.92);
		rough = mix(rough, 0.88, road_t * 0.8);
	}

	// Perturbación de normal: grano fino en nieve, vetas en roca; sin cráteres.
	float bump_strength = mix(0.95, 1.5, cliff_t);
	vec3 n_pert = normalize(nw + vec3(
		mix(snow_dx, rock_dx, cliff_t) * bump_strength,
		0.0,
		mix(snow_dz, rock_dz, cliff_t) * bump_strength
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_pert, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = mix(0.35, 0.65, ice_t);
	AO = clamp(0.75 + 0.25 * v_mask.b, 0.65, 1.0);
}
"""

var _terrain_material: ShaderMaterial
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


func _make_material() -> ShaderMaterial:
	var snow_n := FastNoiseLite.new()
	snow_n.seed = 198311
	snow_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	snow_n.fractal_type = FastNoiseLite.FRACTAL_FBM
	snow_n.fractal_octaves = 4
	snow_n.frequency = 0.045

	var snow_tex := NoiseTexture2D.new()
	snow_tex.width = 512
	snow_tex.height = 512
	snow_tex.seamless = true
	snow_tex.noise = snow_n

	var rock_n := FastNoiseLite.new()
	rock_n.seed = 198329
	rock_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rock_n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	rock_n.fractal_octaves = 4
	rock_n.frequency = 0.075

	var rock_tex := NoiseTexture2D.new()
	rock_tex.width = 512
	rock_tex.height = 512
	rock_tex.seamless = true
	rock_tex.noise = rock_n

	var shader := Shader.new()
	shader.code = TERRAIN_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("snow_noise", snow_tex)
	mat.set_shader_parameter("rock_noise", rock_tex)
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
			# El terreno solo recibe sombras: proyectarlas sobre sí mismo deja franjas negras en la nieve.
			single_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		# El terreno solo recibe sombras: proyectarlas sobre sí mismo deja franjas negras en la nieve.
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			colors[idx] = _vertex_mask(x, y, z, n)

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


func _vertex_mask(x: float, y: float, z: float, n: Vector3) -> Color:
	var road := TerrainMap.road_factor(x, z)
	var ice := 0.0
	var creek_z := -156.0 + sin(x * 0.017) * 28.0 - cos(x * 0.008) * 16.0
	if absf(x) < 500.0 and absf(z - creek_z) < 10.5 and y < -2.0:
		ice = clampf((10.5 - absf(z - creek_z)) / 10.5, 0.0, 1.0)
	var cavity := clampf(n.y * 0.7 + clampf((y + 10.0) / 80.0, 0.0, 0.3), 0.0, 1.0)
	return Color(road, ice, cavity, 1.0)
