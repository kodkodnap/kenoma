class_name DiskDock
extends Interactable
## Bandeja donde se inserta y extrae un disco de señal.

signal disk_inserted(disk: DiskMedia)
signal disk_ejected(disk: DiskMedia)

var disk: DiskMedia = null
var _interactable_layer: int = 2


func _ready() -> void:
	super._ready()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.12, 0.22)
	shape.shape = box
	add_child(shape)
	activated.connect(_on_activated)


func insert(value: DiskMedia) -> void:
	if value == null or disk != null or value == disk or value.held_by != null:
		return
	disk = value
	if disk.interactable != null:
		_interactable_layer = disk.interactable.collision_layer
		disk.interactable.enabled = false
		disk.interactable.collision_layer = 0
	disk.freeze = true
	disk.visible = false
	disk_inserted.emit(disk)


func eject() -> DiskMedia:
	if disk == null:
		return null
	var ejected := disk
	disk = null
	ejected.freeze = false
	ejected.visible = true
	if ejected.interactable != null:
		ejected.interactable.collision_layer = _interactable_layer
		ejected.interactable.enabled = true
	disk_ejected.emit(ejected)
	return ejected


func _on_activated(_source: Interactable) -> void:
	if disk != null:
		eject()
		return
	for candidate in get_tree().get_nodes_in_group("disk_media"):
		var media := candidate as DiskMedia
		if media != null and media.interactable != null and media.interactable.focused:
			insert(media)
			return
