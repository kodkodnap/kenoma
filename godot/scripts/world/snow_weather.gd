class_name SnowWeather
extends GPUParticles3D
## Nieve alpina en 3D (1 draw call) que sigue a la cámara activa y se oculta en interiores.

const PARTICLE_COUNT := 900
const EMITTER_HEIGHT_OFFSET := 8.5

const SNOW_SHADER_CODE := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

varying float v_alpha;

bool inside_box(vec3 p, vec3 bmin, vec3 bmax) {
	return all(greaterThanEqual(p, bmin)) && all(lessThanEqual(p, bmax));
}

bool inside_base(vec3 p) {
	if (inside_box(p, vec3(-19.0, 5.85, -29.0), vec3(2.0, 10.45, -12.0))) return true;
	if (inside_box(p, vec3(-9.5, 4.35, -15.5), vec3(-5.5, 6.05, -12.0))) return true;
	if (inside_box(p, vec3(-19.0, 4.35, -12.0), vec3(19.0, 8.85, 7.5))) return true;
	if (inside_box(p, vec3(2.0, -0.05, -26.5), vec3(19.0, 4.45, 7.5))) return true;
	if (inside_box(p, vec3(19.0, -0.05, -26.5), vec3(31.0, 4.45, -12.0))) return true;
	if (inside_box(p, vec3(2.0, -4.5, -12.0), vec3(36.0, 8.85, 7.5))) return true;
	if (inside_box(p, vec3(19.0, 8.75, 2.0), vec3(36.0, 12.1, 7.5))) return true;
	return false;
}

void vertex() {
	vec3 world_pos = MODEL_MATRIX[3].xyz;
	float p_scale = max(length(MODEL_MATRIX[0].xyz), 0.01);
	vec3 view_pos = (VIEW_MATRIX * vec4(world_pos, 1.0)).xyz;
	float dist = length(view_pos);
	float near_fade = smoothstep(0.65, 2.1, dist);
	float far_fade = 1.0 - smoothstep(18.0, 27.5, dist);
	v_alpha = near_fade * far_fade;
	if (inside_base(world_pos) || v_alpha <= 0.005) {
		VERTEX = vec3(0.0);
		v_alpha = 0.0;
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(INV_VIEW_MATRIX[0].xyz * p_scale, 0.0),
			vec4(INV_VIEW_MATRIX[1].xyz * p_scale, 0.0),
			vec4(INV_VIEW_MATRIX[2].xyz * p_scale, 0.0),
			MODEL_MATRIX[3]
		);
	}
}

void fragment() {
	if (v_alpha <= 0.005) {
		discard;
	}
	float r = length(UV - vec2(0.5)) * 2.0;
	float radial = smoothstep(1.0, 0.12, r);
	ALBEDO = vec3(0.76, 0.85, 0.96);
	ALPHA = radial * radial * 0.72 * v_alpha;
}
"""


func _ready() -> void:
	amount = PARTICLE_COUNT
	lifetime = 5.5
	preprocess = 2.5
	local_coords = false
	emitting = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-36.0, -22.0, -36.0), Vector3(72.0, 44.0, 72.0))

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(28.0, 14.0, 28.0)
	proc.gravity = Vector3(-1.35, -2.55, 0.75)
	proc.initial_velocity_min = 0.25
	proc.initial_velocity_max = 0.85
	proc.turbulence_enabled = true
	proc.turbulence_noise_strength = 1.65
	proc.turbulence_noise_scale = 2.6
	proc.turbulence_noise_speed = Vector3(0.45, 0.2, 0.35)
	proc.scale_min = 0.6
	proc.scale_max = 1.45
	process_material = proc

	var shader := Shader.new()
	shader.code = SNOW_SHADER_CODE
	var flake_mat := ShaderMaterial.new()
	flake_mat.shader = shader

	var quad := QuadMesh.new()
	quad.size = Vector2(0.085, 0.085)
	quad.material = flake_mat
	draw_pass_1 = quad


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position + Vector3(0.0, EMITTER_HEIGHT_OFFSET, 0.0)
