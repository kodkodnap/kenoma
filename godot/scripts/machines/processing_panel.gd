class_name ProcessingPanel
extends Node3D
## Estación de Procesado: gabinete exportado desde Blender, CRT vivo sobre el
## cristal horneado y perilla/pulsador invisibles alineados con los mandos del
## modelo. La fase de la perilla gobierna la estabilidad de la onda en cada frame.

const CONSOLE_MODEL := preload("res://assets/models/signal-processing-console.glb")
const SCREEN_SIZE := Vector2i(640, 360)

# El marcador está a 1,25 m del suelo; el modelo se baja hasta apoyarse en él.
const MODEL_POS := Vector3(0.0, -1.25, 0.0)

# Cotas de respaldo en coordenadas del panel (Blender X,Y,Z → Godot X,-Z,Y).
const FALLBACK_DIAL := Vector3(-0.02, -0.6248, 0.2042)
const FALLBACK_JOG := Vector3(0.16, -0.6248, 0.2042)
const FALLBACK_SLOT := Vector3(0.0, -0.4913, -0.2455)
const FALLBACK_SCREEN := Vector3(-0.27, -0.554, -0.044)

var _system: SignalSystem
var _cabinet: Node3D
var _viewport: SubViewport
var _screen: CrtScreen
var _screen_material: StandardMaterial3D
var _status_label: Label
var _decode_knob: RotaryKnob
var _confirm_button: PushButton
var _lock_material: StandardMaterial3D
var _locked: bool = false
var _time: float = 0.0


func _ready() -> void:
	add_to_group("processing_panel")
	_build_cabinet()
	_build_screen()
	_build_controls()
	_build_lock_led()
	_build_collision()


func setup(system: SignalSystem) -> void:
	_system = system


func get_decode_knob() -> RotaryKnob:
	return _decode_knob


func get_confirm_button() -> PushButton:
	return _confirm_button


func get_crt() -> CrtScreen:
	return _screen


func is_locked() -> bool:
	return _locked


func _process(delta: float) -> void:
	_time += delta
	if _system != null and _decode_knob != null:
		# Sondear el valor también cubre sync_value() programático, que no emite.
		_system.set_decode_tuning(_decode_knob.value)
		if _screen != null:
			_screen.stability = _system.decode_stability()
			_screen.signal_level = 1.0
			_screen.powered = true
	if _screen_material != null:
		_screen_material.emission_energy_multiplier = 1.0 + 0.04 * sin(_time * 27.0)


# --- Construcción --------------------------------------------------------------

func _build_cabinet() -> void:
	_cabinet = CONSOLE_MODEL.instantiate() as Node3D
	_cabinet.name = "Cabinet"
	_cabinet.position = MODEL_POS
	add_child(_cabinet)


func _build_screen() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "ScreenViewport"
	_viewport.size = SCREEN_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_screen = CrtScreen.new()
	_screen.name = "Crt"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_screen)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = "FASE · ESTABILIZA LA ONDA"
	_status_label.position = Vector2(18, 12)
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", CrtScreen.GREEN)
	_viewport.add_child(_status_label)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.46, 0.26)
	var mesh := MeshInstance3D.new()
	mesh.name = "CrtScreen"
	mesh.mesh = quad
	mesh.material_override = _screen_material_for_viewport()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var bezel := _cabinet.find_child("SIG_crt_bezel", true, false)
	if bezel is Node3D:
		# 40 mm de grosor del bisel: la cara delantera está a +20 mm locales.
		mesh.position = Vector3(0.0, 0.0, 0.021)
		bezel.add_child(mesh)
	else:
		mesh.position = FALLBACK_SCREEN
		add_child(mesh)


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
	_decode_knob = RotaryKnob.new()
	_decode_knob.name = "DecodeKnob"
	_decode_knob.position = _node_pos("SIG_dial_freq", FALLBACK_DIAL)
	_decode_knob.scale = Vector3.ONE * 0.5
	_decode_knob.min_value = 0.0
	_decode_knob.max_value = 1.0
	_decode_knob.step = 0.005
	_decode_knob.label_text = "FASE"
	_decode_knob.value_suffix = ""
	add_child(_decode_knob)
	_decode_knob.visible = false
	_decode_knob.value_changed.connect(func(v: float) -> void:
		if _system != null:
			_system.set_decode_tuning(v))

	_confirm_button = PushButton.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.position = _node_pos("SIG_slot_housing", FALLBACK_SLOT)
	_confirm_button.scale = Vector3.ONE * 0.7
	_confirm_button.label_text = "CONFIRMAR"
	_confirm_button.lamp_color = CrtScreen.GREEN
	add_child(_confirm_button)
	_confirm_button.visible = false
	_confirm_button.pressed.connect(_on_confirm)


func _node_pos(node_name: String, fallback: Vector3) -> Vector3:
	var node := _cabinet.find_child(node_name, true, false)
	if node is Node3D:
		return to_local((node as Node3D).global_position)
	return fallback


func _build_lock_led() -> void:
	_lock_material = StandardMaterial3D.new()
	_lock_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lock_material.albedo_color = CrtScreen.GREEN
	_lock_material.emission_enabled = true
	_lock_material.emission = CrtScreen.GREEN
	_lock_material.emission_energy_multiplier = 0.12

	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	var led := MeshInstance3D.new()
	led.name = "LockLed"
	led.mesh = sphere
	led.material_override = _lock_material
	led.position = _node_pos("SIG_slot_housing", FALLBACK_SLOT) + Vector3(0.28, 0.0, 0.02)
	add_child(led)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.788, 0.619)
	shape.shape = box
	shape.position = Vector3(0.0, MODEL_POS.y + box.size.y * 0.5, 0.0)
	body.add_child(shape)


func _on_confirm() -> void:
	if _system == null:
		return
	if _system.confirm_decode():
		_locked = true
		_lock_material.emission_energy_multiplier = 2.8
		_status_label.text = _system.status() + " · DISCO DISPONIBLE"
		_confirm_button.flash()
	else:
		_status_label.text = _system.status()
