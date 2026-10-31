class_name Player
extends CharacterBody3D
## Jugador en primera persona: movimiento, mirada, linterna con batería.

signal focus_changed(target: Interactable)
signal hold_changed(ratio: float)

const DEFAULT_BALANCE: GameBalance = preload("res://data/balance.tres")

@export var balance: GameBalance = DEFAULT_BALANCE
@export var mouse_sensitivity: float = 0.0022
@export var interact_range: float = 2.4
@export var interact_mask: int = 2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

var current_interactable: Interactable = null

var _pitch: float = 0.0
var _battery: float = 1.0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _hold_target: Interactable = null
var _hold_elapsed: float = 0.0


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

	_update_focus()
	_update_interaction(delta)


func _process(delta: float) -> void:
	if not flashlight.visible:
		return
	_battery = maxf(0.0, _battery - balance.flashlight_drain_per_second * delta)
	if _battery == 0.0:
		flashlight.visible = false


func _toggle_flashlight() -> void:
	if _battery > 0.0:
		flashlight.visible = not flashlight.visible


func _update_focus() -> void:
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_basis.z * interact_range,
		interact_mask
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var target: Interactable = null
	if not hit.is_empty():
		target = hit.get("collider") as Interactable

	if target == current_interactable:
		return

	if current_interactable != null:
		current_interactable.set_focused(false)
	current_interactable = target
	if current_interactable != null:
		current_interactable.set_focused(true)
	focus_changed.emit(current_interactable)
	if _hold_target != null and _hold_target != current_interactable:
		_cancel_hold()


func _update_interaction(delta: float) -> void:
	if Input.is_action_just_pressed("interact") and current_interactable != null \
			and current_interactable.enabled:
		if current_interactable.hold_time <= 0.0:
			current_interactable.activate()
		else:
			_hold_target = current_interactable
			_hold_elapsed = 0.0

	if _hold_target == null:
		return

	if not Input.is_action_pressed("interact"):
		_cancel_hold()
		return

	_hold_elapsed += delta
	hold_changed.emit(clampf(_hold_elapsed / _hold_target.hold_time, 0.0, 1.0))
	if _hold_elapsed >= _hold_target.hold_time:
		var target := _hold_target
		_hold_target = null
		_hold_elapsed = 0.0
		hold_changed.emit(0.0)
		target.activate()


func _cancel_hold() -> void:
	_hold_target = null
	_hold_elapsed = 0.0
	hold_changed.emit(0.0)
