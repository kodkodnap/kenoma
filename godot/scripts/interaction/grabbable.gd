class_name Grabbable
extends RigidBody3D
## Objeto físico que el jugador puede coger, rotar, soltar y lanzar.

signal grabbed(by: Node3D)
signal released(by: Node3D)

const ITEM_LAYER := 4

@export var item: ItemDef
@export var interactable: Interactable

var held_by: Node3D


func _ready() -> void:
	collision_layer = ITEM_LAYER
	collision_mask = 1
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable != null:
		interactable.activated.connect(_on_activated)


func grab(by: Node3D) -> void:
	if held_by != null:
		return
	held_by = by
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	if interactable != null:
		interactable.enabled = false
	grabbed.emit(by)


func release(impulse: Vector3 = Vector3.ZERO) -> void:
	if held_by == null:
		return
	var by := held_by
	held_by = null
	freeze = false
	gravity_scale = 1.0
	collision_layer = ITEM_LAYER
	collision_mask = 1
	sleeping = false
	if interactable != null:
		interactable.enabled = true
	apply_central_impulse(impulse)
	released.emit(by)


func _on_activated(_source: Interactable) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("toggle_grab"):
		player.toggle_grab(self)
