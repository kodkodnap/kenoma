class_name DiskMedia
extends Grabbable
## Disco físico que transporta una señal exportada entre máquinas.

@export var disk_index: int = -1

var signals: SignalSystem

@onready var label: Label3D = $Label


func _ready() -> void:
	super._ready()
	add_to_group("disk_media")
	refresh_label()


func setup(source: SignalSystem, index: int) -> void:
	signals = source
	disk_index = index
	refresh_label()


func refresh_label() -> void:
	if label == null or signals == null:
		return
	var disks: Array = signals.disks
	if disk_index < 0 or disk_index >= disks.size():
		label.text = "SIN DATOS"
		return
	var data: Dictionary = disks[disk_index]
	var def_id := str(data.get("def_id", ""))
	var value := int(data.get("value", 0))
	var level := signals.copy_level(int(data.get("copy_index", -1)))
	label.text = "%s\nNIVEL %d\n%d" % [def_id, level, value]
