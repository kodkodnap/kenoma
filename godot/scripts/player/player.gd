class_name Player
extends CharacterBody3D
## Jugador en primera persona: movimiento, mirada, linterna con batería.

signal focus_changed(target: Interactable)
signal hold_changed(ratio: float)

const DEFAULT_BALANCE: GameBalance = preload("res://data/balance.tres")

@export var balance: GameBalance = DEFAULT_BALANCE
@export var mouse_sensitivity: float = 0.0022
@export var gamepad_look_sensitivity: float = 2.5
@export var interact_range: float = 2.4
@export var interact_mask: int = 2
@export var hold_distance: float = 1.3

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var collision: CollisionShape3D = $Collision

var current_interactable: Interactable = null
var held: Grabbable = null
var inventory: Inventory
var stamina: float = 100.0
var crouched: bool = false
var battery: float = 1.0

var _pitch: float = 0.0
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _hold_target: Interactable = null
var _hold_elapsed: float = 0.0
var _capsule: CapsuleShape3D
var _rotating_held: bool = false
var _interact_lock: float = 0.0


func _ready() -> void:
	add_to_group("player")
	inventory = Inventory.new(balance.inventory_capacity)
	_capsule = collision.shape.duplicate() as CapsuleShape3D
	collision.shape = _capsule
	_apply_stance()
	stamina = balance.stamina_max
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if held != null:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			_rotating_held = event.pressed
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_interact_lock = 0.25
			drop_held(8.0)
			return
		if event is InputEventMouseMotion and _rotating_held:
			rotate_held(event.relative)
			return
		if event.is_action_pressed("drop"):
			drop_held(0.0)
			return
	if event is InputEventMouseMotion and not _mouse_look_blocked() \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
		head.rotation.x = _pitch
	elif event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	elif event.is_action_pressed("ui_cancel"):
		if _mouse_look_blocked():
			current_interactable.call("release")
			return
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed and _can_recapture_mouse() \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _mouse_look_blocked() -> bool:
	return current_interactable != null and current_interactable.get("grabbed") == true


func _can_recapture_mouse() -> bool:
	return not _mouse_look_blocked()


func _physics_process(delta: float) -> void:
	_set_crouched(Input.is_action_pressed("crouch"))

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = balance.jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var moving := input_dir.length() > 0.1
	var can_sprint := Input.is_action_pressed("sprint") and moving and not crouched \
		and stamina >= balance.stamina_sprint_min and is_on_floor()

	var speed := balance.walk_speed
	if crouched:
		speed = balance.crouch_speed
	elif can_sprint:
		speed = balance.sprint_speed

	if can_sprint:
		stamina = maxf(0.0, stamina - balance.stamina_drain_per_second * delta)
	else:
		stamina = minf(balance.stamina_max, stamina + balance.stamina_regen_per_second * delta)

	var acceleration := balance.ground_acceleration if is_on_floor() else balance.air_acceleration
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()

	if held != null:
		_update_held()
		_clear_focus()
		return

	_interact_lock = maxf(0.0, _interact_lock - delta)
	_update_focus()
	if _interact_lock <= 0.0:
		_update_interaction(delta)


func _set_crouched(value: bool) -> void:
	if crouched == value:
		return
	# shortcut: al levantarse no comprueba techo; añadir con los conductos del hito 3.
	crouched = value
	_apply_stance()


func _apply_stance() -> void:
	var height := balance.crouch_height if crouched else balance.stand_height
	_capsule.height = height
	collision.position.y = height * 0.5
	head.position.y = balance.crouch_head_height if crouched else balance.head_height


func grab(grabbable: Grabbable) -> void:
	if grabbable == null or held != null:
		return
	held = grabbable
	held.grab(self)
	_clear_focus()


func toggle_grab(grabbable: Grabbable) -> void:
	if held == grabbable:
		drop_held(0.0)
	elif held == null:
		grab(grabbable)


func drop_held(throw_force: float = 0.0) -> void:
	if held == null:
		return
	held.release(-camera.global_basis.z * throw_force)
	held = null
	_rotating_held = false


func rotate_held(relative: Vector2) -> void:
	if held == null:
		return
	held.rotate_object_local(Vector3.UP, -relative.x * 0.01)
	held.rotate_object_local(Vector3.RIGHT, -relative.y * 0.01)


func _update_held() -> void:
	# shortcut: el objeto sostenido no comprueba paredes; añadir con la base del hito 3.
	held.global_position = camera.global_position - camera.global_basis.z * hold_distance


func _clear_focus() -> void:
	if current_interactable == null and _hold_target == null:
		return
	if current_interactable != null:
		current_interactable.set_focused(false)
	current_interactable = null
	focus_changed.emit(null)
	_cancel_hold()


func _process(delta: float) -> void:
	_apply_gamepad_look(delta)
	if not flashlight.visible:
		return
	battery = maxf(0.0, battery - balance.flashlight_drain_per_second * delta)
	if battery == 0.0:
		flashlight.visible = false


func _apply_gamepad_look(delta: float) -> void:
	if _mouse_look_blocked():
		return
	var x := Input.get_axis("look_left", "look_right")
	var y := Input.get_axis("look_up", "look_down")
	if absf(x) < 0.05 and absf(y) < 0.05:
		return
	if held != null:
		rotate_held(Vector2(x, y) * delta * 240.0)
		return
	rotate_y(-x * gamepad_look_sensitivity * delta)
	_pitch = clampf(_pitch - y * gamepad_look_sensitivity * delta, -1.45, 1.45)
	head.rotation.x = _pitch


func _toggle_flashlight() -> void:
	if battery > 0.0:
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
