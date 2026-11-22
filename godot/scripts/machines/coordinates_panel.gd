class_name CoordinatesPanel
extends Node3D
## Consola de coordenadas: el gabinete Meshy tal cual, con una pantalla CRT viva
## encajada sobre el cristal horneado y las perillas de azimut/elevación y el
## pulsador de ping como zonas invisibles en los mandos que ya dibuja el modelo.
## El resto del tablero (medidores, joystick, interruptores, displays) es decoración.

const CONSOLE_MODEL := preload("res://assets/models/coordinates-console.glb")
const SCREEN_SIZE := Vector2i(720, 480)

# Modelo: origen en la base y frente +Z. Se apoya en el suelo y se retrasa hasta
# dejar el frente a 0,36 m del marcador del panel.
const MODEL_POS := Vector3(0.0, -1.25, -0.20)

# Cristal medido sobre el render ortográfico del modelo (1 px = 2 mm).
const SCREEN_CENTER := Vector3(-0.126, -0.0194, 0.1700)
const SCREEN_W := 0.70
const SCREEN_H := 0.458
const SCREEN_SAG := 0.40  # parábola del CRT: 7 cm del centro al borde

# Centros de los mandos horneados, en coordenadas del panel.
const KNOB_AZ := Vector3(-0.427, -0.582, 0.2822)
const KNOB_EL := Vector3(-0.202, -0.574, 0.2921)
const PING_POS := Vector3(0.35, -0.49, 0.1811)

var _system: SignalSystem
var _viewport: SubViewport
var _screen: CoordinatesScreen
var _screen_material: StandardMaterial3D

var _azimuth_knob: RotaryKnob
var _elevation_knob: RotaryKnob
var _ping_button: PushButton

var _time: float = 0.0


func _ready() -> void:
	add_to_group("coordinates_panel")
	_build_cabinet()
	_build_screen()
	_build_controls()
	_build_collision()


func setup(system: SignalSystem) -> void:
	_system = system
	if _system != null:
		_screen.setup(system)
	sync_knobs()


func get_azimuth_knob() -> RotaryKnob:
	return _azimuth_knob


func get_elevation_knob() -> RotaryKnob:
	return _elevation_knob


func get_ping_button() -> PushButton:
	return _ping_button


func sync_knobs() -> void:
	if _system == null:
		return
	_azimuth_knob.sync_value(_system.azimuth)
	_elevation_knob.sync_value(_system.elevation)


func _process(delta: float) -> void:
	_time += delta
	if _screen_material != null:
		_screen_material.emission_energy_multiplier = 1.0 + 0.04 * sin(_time * 29.0)


# --- Construcción --------------------------------------------------------------

func _build_cabinet() -> void:
	var cabinet := CONSOLE_MODEL.instantiate()
	cabinet.name = "Cabinet"
	cabinet.position = MODEL_POS
	add_child(cabinet)


func _build_screen() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "ScreenViewport"
	_viewport.size = SCREEN_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_screen = CoordinatesScreen.new()
	_screen.name = "Crt"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_screen)

	var mesh := MeshInstance3D.new()
	mesh.name = "CrtScreen"
	mesh.mesh = _curved_screen_mesh()
	mesh.position = SCREEN_CENTER
	mesh.material_override = _screen_material_for_viewport()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

	var glow := OmniLight3D.new()
	glow.name = "CrtGlow"
	glow.light_color = Color(0.45, 1.0, 0.65)
	glow.light_energy = 0.12
	glow.omni_range = 0.9
	glow.shadow_enabled = false
	glow.position = SCREEN_CENTER + Vector3(0.0, 0.0, 0.30)
	add_child(glow)


func _curved_screen_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 18
	var ny := 12
	var half_w := SCREEN_W * 0.5
	var half_h := SCREEN_H * 0.5
	for j in ny + 1:
		var v := float(j) / float(ny)
		for i in nx + 1:
			var u := float(i) / float(nx)
			var dx := (u - 0.5) * SCREEN_W
			var dy := (0.5 - v) * SCREEN_H
			var z := -SCREEN_SAG * (dx * dx + dy * dy)
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(dx, dy, z))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := (j + 1) * (nx + 1) + i
			var c := a + 1
			var d := b + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
	return st.commit()


func _screen_material_for_viewport() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.emission_enabled = true
	material.emission_texture = _viewport.get_texture()
	material.emission_energy_multiplier = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_screen_material = material
	return material


func _build_controls() -> void:
	# Las perillas y el pulsador son zonas invisibles: el modelo ya trae sus mandos
	# horneados y así el gabinete conserva el aspecto de la referencia.
	_azimuth_knob = _make_knob("AzimuthKnob", KNOB_AZ, "AZIMUT", 360.0, 5.0, "°")
	_elevation_knob = _make_knob("ElevationKnob", KNOB_EL, "ELEVACIÓN", 80.0, 2.0, "°")

	_ping_button = PushButton.new()
	_ping_button.name = "PingButton"
	_ping_button.position = PING_POS
	_ping_button.scale = Vector3.ONE * 0.7
	_ping_button.label_text = "BUSCAR"
	_ping_button.lamp_color = Color(0.95, 0.7, 0.25)
	add_child(_ping_button)
	_ping_button.visible = false

	_azimuth_knob.value_changed.connect(func(v: float) -> void:
		if _system != null:
			_system.set_azimuth(v))
	_elevation_knob.value_changed.connect(func(v: float) -> void:
		if _system != null:
			_system.set_elevation(v))
	_ping_button.pressed.connect(_on_ping)


func _make_knob(node_name: String, pos: Vector3, label: String, max_value: float,
		step: float, suffix: String) -> RotaryKnob:
	var knob := RotaryKnob.new()
	knob.name = node_name
	knob.position = pos
	knob.scale = Vector3.ONE * 0.5
	knob.min_value = 0.0
	knob.max_value = max_value
	knob.step = step
	knob.label_text = label
	knob.value_suffix = suffix
	add_child(knob)
	knob.visible = false
	return knob


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.243, 1.576, 1.127)
	shape.shape = box
	shape.position = Vector3(0.0, MODEL_POS.y + 0.788, MODEL_POS.z)
	body.add_child(shape)


# --- Estado --------------------------------------------------------------------

func _on_ping() -> void:
	if _system == null:
		return
	_system.scan()
