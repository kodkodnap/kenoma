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

	# Hito 1: contrato de movimiento, stamina y linterna.
	var balance := player.balance
	_check(is_equal_approx(_number(balance, "walk_speed", 0.0), 4.0), "balance: andar 4 m/s", failures)
	_check(is_equal_approx(_number(balance, "sprint_speed", 0.0), 8.0), "balance: correr 8 m/s", failures)
	_check(is_equal_approx(_number(balance, "crouch_speed", 0.0), 1.5), "balance: agachado 1.5 m/s", failures)
	_check(player.get("stamina") != null, "jugador expone stamina", failures)
	_check(player.get("crouched") != null, "jugador expone estado agachado", failures)
	_check(player.get("battery") != null, "jugador expone batería de linterna", failures)
	_check(hud.get("vitals") is Label, "HUD tiene panel de vitales", failures)

	# Hito 1: movimiento, stamina, agacharse y salto.
	var walk_speed := await _measure_speed(player, "")
	_check(walk_speed > 3.7 and walk_speed < 4.3, "andar a ~4 m/s", failures)

	var stamina_before := player.stamina
	var sprint_speed := await _measure_speed(player, "sprint")
	_check(sprint_speed > 7.5, "correr a ~8 m/s", failures)
	_check(player.stamina < stamina_before, "correr consume stamina", failures)

	player.stamina = 10.0
	var tired_speed := await _measure_speed(player, "sprint")
	_check(tired_speed < 5.0, "stamina baja bloquea correr", failures)

	player.stamina = 40.0
	_reset_player(player, Vector3(0.0, 0.05, 0.0))
	for i in 30:
		await physics_frame
	_check(player.stamina > 40.0, "stamina se recupera al parar", failures)

	player.stamina = 100.0
	_reset_player(player, Vector3(0.0, 0.05, 0.0))
	Input.action_press("crouch")
	for i in 3:
		await physics_frame
	var collision := player.get_node("Collision") as CollisionShape3D
	_check(player.crouched, "agacharse activa el estado", failures)
	_check(player.head.position.y < 1.3, "agacharse baja la cámara", failures)
	_check((collision.shape as CapsuleShape3D).height < 1.5, "agacharse reduce la cápsula", failures)
	Input.action_release("crouch")
	for i in 3:
		await physics_frame
	_check(not player.crouched, "soltar agacharse se pone de pie", failures)

	var crouch_speed := await _measure_speed(player, "crouch")
	_check(crouch_speed < 2.2, "agachado a ~1.5 m/s", failures)

	_reset_player(player, Vector3(0.0, 0.05, 0.0))
	for i in 5:
		await physics_frame
	var jump_start := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for i in 5:
		await physics_frame
	_check(player.global_position.y > jump_start + 0.04, "el jugador salta", failures)

	_reset_player(player, Vector3(18.5, 0.05, 6.0))
	Input.action_press("move_right")
	for i in 40:
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x < 19.8, "el jugador no atraviesa la pared", failures)

	player.stamina = 42.0
	hud._refresh_vitals()
	_check(hud.vitals.text.contains("42"), "HUD muestra la stamina", failures)
	_check(hud.vitals.text.contains("Linterna"), "HUD muestra la linterna", failures)
	player.stamina = 100.0

	# La linterna es la del prototipo: se conserva y se comprueba que sigue funcionando.
	var light := player.flashlight
	var light_was_on := light.visible
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_F
	toggle.pressed = true
	player._unhandled_input(toggle)
	_check(light.visible != light_was_on, "F enciende y apaga la linterna", failures)
	player._unhandled_input(toggle)
	player.battery = 0.001
	light.visible = true
	player._process(1.0)
	_check(player.battery == 0.0 and not light.visible, "la linterna se apaga sin batería", failures)
	player.battery = 1.0
	light.visible = true

	_reset_player(player, Vector3(0.0, 0.05, 6.0))
	for i in 2:
		await physics_frame

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


func _measure_speed(player: Player, action: String) -> float:
	_reset_player(player, Vector3(0.0, 0.05, 0.0))
	for i in 2:
		await physics_frame
	Input.action_press("move_forward")
	if action != "":
		Input.action_press(action)
	for i in 24:
		await physics_frame
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	if action != "":
		Input.action_release(action)
	for i in 2:
		await physics_frame
	return speed


func _reset_player(player: Player, position: Vector3) -> void:
	_release_actions()
	player.global_position = position
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO


func _release_actions() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch", "jump", "interact"]:
		Input.action_release(action)


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


func _number(object: Object, property: StringName, fallback: float) -> float:
	var value: Variant = object.get(property)
	if value == null:
		return fallback
	return float(value)
