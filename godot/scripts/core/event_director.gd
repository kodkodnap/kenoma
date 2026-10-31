class_name EventDirector
extends Node
## Director base: registra eventos y garantiza que no se solapen.

signal event_started(id: StringName)
signal event_finished(id: StringName)

@export var events: Array[EventDef] = []
var active_event: EventDef


func get_event(id: StringName) -> EventDef:
	for event in events:
		if event.id == id:
			return event
	return null


func trigger(id: StringName) -> bool:
	if active_event != null:
		return false
	var event := get_event(id)
	if event == null:
		return false
	active_event = event
	event_started.emit(id)
	return true


func finish_current() -> void:
	if active_event == null:
		return
	var id := active_event.id
	active_event = null
	event_finished.emit(id)
