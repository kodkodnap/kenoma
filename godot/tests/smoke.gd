extends SceneTree
## Smoke test del hito 0:
## godot --headless --path . --script res://tests/smoke.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("FALLO: no se pudo cargar scenes/main.tscn")
		quit(1)
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var player := main.get_node_or_null("Player") as Player
	_check(player != null, "Player es CharacterBody3D", failures)

	if player != null:
		_check(player.balance != null, "balance.tres cargado", failures)
		_check(player.get_node_or_null("Head/Camera3D") is Camera3D, "cámara en Head", failures)
		_check(player.flashlight is SpotLight3D and player.flashlight.light_energy > 0.0, "linterna encendida", failures)

		var start := player.global_position
		Input.action_press("move_forward")
		for i in 30:
			await physics_frame
		Input.action_release("move_forward")
		_check(player.global_position.distance_to(start) > 0.5, "el jugador se mueve con WASD", failures)

	_check(main.get_node_or_null("Level/Floor/Collision") is CollisionShape3D, "suelo con colisión", failures)
	_check(main.get_node_or_null("PerfOverlay") != null, "overlay de rendimiento presente", failures)

	if failures.is_empty():
		print("SMOKE OK: hito 0")
		quit(0)
	else:
		for failure in failures:
			push_error("FALLO: " + failure)
		quit(1)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if condition:
		print("OK  " + label)
	else:
		failures.append(label)
