class_name DiskDock
extends Interactable
## Bandeja donde se inserta y extrae un disco de señal.

signal disk_inserted(disk: DiskMedia)
signal disk_ejected(disk: DiskMedia)

var disk: DiskMedia = null


func _ready() -> void:
	super._ready()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.12, 0.22)
	shape.shape = box
	add_child(shape)
	activated.connect(_on_activated)


func insert(value: DiskMedia) -> void:
	if value == null or disk != null or value == disk:
		return
	disk = value
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
