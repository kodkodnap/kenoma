extends SceneTree
## Smoke test de los hitos 0 y 1:
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
	var machine := main.get_node_or_null("TestMachine") as TestMachine
	var grid := main.get_node_or_null("PowerGrid") as PowerGrid
	var hud := main.get_node_or_null("HUD") as Hud

	_check(player != null, "Player es CharacterBody3D", failures)
	_check(machine != null, "TestMachine presente", failures)
	_check(grid != null, "PowerGrid presente", failures)
	_check(hud != null, "HUD presente", failures)

	if player == null or machine == null or grid == null or hud == null:
		_finish(failures)
		return

	_check(player.balance != null, "balance.tres cargado", failures)
	_check(player.get_node_or_null("Head/Camera3D") is Camera3D, "cámara en Head", failures)
	_check(player.flashlight is SpotLight3D and player.flashlight.light_energy > 0.0, "linterna encendida", failures)
	_check(main.get_node_or_null("Level/Floor/Collision") is CollisionShape3D, "suelo con colisión", failures)
	_check(main.get_node_or_null("PerfOverlay") != null, "overlay de rendimiento presente", failures)
	_check(machine.definition != null, "definición de máquina cargada", failures)

	var start := player.global_position
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start) > 0.5, "el jugador se mueve con WASD", failures)

	# Interruptor: foco por raycast y mantener E.
	_stand_and_aim(player, machine.switch_interactable, 1.5)
	for i in 3:
		await physics_frame
	_check(player.current_interactable == machine.switch_interactable, "raycast enfoca el interruptor", failures)
	_check(hud.prompt.text.contains("Mantén"), "HUD pide mantener para el interruptor", failures)

	Input.action_press("interact")
	for i in 90:
		await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check(machine.state == Machine.State.ON, "mantener E enciende la máquina", failures)

	var heat_before := machine.heat
	for i in 30:
		await physics_frame
	_check(machine.heat > heat_before, "la máquina calienta encendida", failures)

	machine.heat = machine.definition.max_heat - 0.1
	for i in 5:
		await physics_frame
	_check(machine.state == Machine.State.OVERHEATED, "sobrecalentamiento apaga la máquina", failures)
	_check(not machine.switch_interactable.enabled, "interruptor bloqueado tras la avería", failures)

	machine.heat = 0.0
	for i in 2:
		await physics_frame
	_check(machine.can_reset(), "la máquina fría permite reinicio", failures)
	_check(machine.button_interactable.enabled, "botón de reinicio habilitado", failures)

	# Botón: reinicio instantáneo.
	_stand_and_aim(player, machine.button_interactable, 1.5)
	for i in 3:
		await physics_frame
	_check(player.current_interactable == machine.button_interactable, "raycast enfoca el botón", failures)
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check(machine.state == Machine.State.OFF, "el botón reinicia tras enfriar", failures)

	# Perilla: cambia de modo.
	_stand_and_aim(player, machine.knob_interactable, 1.5)
	for i in 3:
		await physics_frame
	_check(player.current_interactable == machine.knob_interactable, "raycast enfoca la perilla", failures)
	var mode_before := machine.mode
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check(machine.mode != mode_before, "la perilla cambia de modo", failures)

	# Energía: el corte apaga y no se rearma solo.
	machine.toggle_power()
	_check(machine.state == Machine.State.ON, "la máquina enciende de nuevo", failures)
	grid.powered = false
	await physics_frame
	_check(machine.state == Machine.State.NO_POWER, "el corte de energía apaga la máquina", failures)
	grid.powered = true
	await physics_frame
	_check(machine.state == Machine.State.OFF, "al volver la energía queda apagada", failures)

	# Capacidad: una carga extra por encima del límite corta la red entera.
	machine.cycle_mode()
	machine.toggle_power()
	var extra := PowerConsumer.new()
	extra.draw_w = 200.0
	grid.add_child(extra)
	grid.register(extra)
	await physics_frame
	_check(machine.state == Machine.State.NO_POWER, "la red corta por sobrecarga", failures)
	extra.draw_w = 0.0
	await physics_frame
	_check(machine.state == Machine.State.OFF, "la red se recupera al bajar la carga", failures)

	_finish(failures)


func _stand_and_aim(player: Player, target: Node3D, distance: float) -> void:
	var target_pos := target.global_position
	player.global_position = Vector3(target_pos.x, 0.05, target_pos.z + distance)
	var eye := player.global_position + Vector3(0, 1.62, 0)
	var direction := (target_pos - eye).normalized()
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.head.rotation.x = asin(clampf(direction.y, -1.0, 1.0))


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SMOKE OK: hitos 0 y 1")
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
