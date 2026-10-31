class_name Player
extends CharacterBody3D
## Jugador en primera persona: movimiento, mirada, linterna con batería.

const DEFAULT_BALANCE: GameBalance = preload("res://data/balance.tres")

@export var balance: GameBalance = DEFAULT_BALANCE
@export var mouse_sensitivity: float = 0.0022

@onready var head: Node3D = $Head
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

var _pitch: float = 0.0
var _battery: float = 1.0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
		head.rotation.x = _pitch
	elif event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := balance.sprint_speed if Input.is_action_pressed("sprint") else balance.walk_speed
	var acceleration := balance.ground_acceleration if is_on_floor() else balance.air_acceleration

	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()


func _process(delta: float) -> void:
	if not flashlight.visible:
		return
	_battery = maxf(0.0, _battery - balance.flashlight_drain_per_second * delta)
	if _battery == 0.0:
		flashlight.visible = false


func _toggle_flashlight() -> void:
	if _battery > 0.0:
		flashlight.visible = not flashlight.visible
