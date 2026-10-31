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
	var test_item := main.get_node_or_null("TestItem") as Grabbable
	var test_panel := main.get_node_or_null("TestPanel") as ScreenPanel
	var director := main.get_node_or_null("EventDirector") as EventDirector
	var base := main.get_node_or_null("Base")

	_check(player != null, "Player es CharacterBody3D", failures)
	_check(machine != null, "TestMachine presente", failures)
	_check(grid != null, "PowerGrid presente", failures)
	_check(hud != null, "HUD presente", failures)
	_check(test_item != null, "item de prueba presente", failures)
	_check(test_panel != null, "panel de prueba presente", failures)
	_check(director != null, "EventDirector presente", failures)

	if player == null or machine == null or grid == null or hud == null:
		_finish(failures)
		return

	_check(player.balance != null, "balance.tres cargado", failures)
	_check(player.get_node_or_null("Head/Camera3D") is Camera3D, "cámara en Head", failures)
	_check(player.flashlight is SpotLight3D and player.flashlight.light_energy > 0.0, "linterna encendida", failures)
	var base_collision := base.get_node_or_null("Collision") as StaticBody3D if base != null else null
	_check(base_collision != null and base_collision.get_child_count() > 0,
		"suelo con colisión", failures)
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

	_reset_player(player, Vector3(25.0, 0.05, 6.0))
	Input.action_press("move_right")
	for i in 40:
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x < 26.2, "el jugador no atraviesa la pared", failures)

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

	# Hito 2: ítems, inventario y contenedores por volumen.
	var item_def := load("res://data/items/test_item.tres") as ItemDef
	_check(item_def != null and item_def.volume > 0.0, "ItemDef de prueba cargado", failures)
	_check(is_equal_approx(_number(balance, "inventory_capacity", 0.0), 24.0),
		"balance: capacidad de inventario 24", failures)

	var bag := Inventory.new(6.0)
	_check(bag.add(item_def), "el inventario acepta un ítem que cabe", failures)
	_check(not bag.add(item_def), "el inventario rechaza un ítem que no cabe", failures)
	_check(bag.items.size() == 1 and is_equal_approx(bag.total_volume(), item_def.volume),
		"el inventario conserva solo el ítem aceptado", failures)

	var container := ItemContainer.new()
	container.capacity = 4.0
	main.add_child(container)
	await process_frame
	_check(container.inventory != null, "Container crea su inventario", failures)
	_check(container.add_item(item_def), "Container acepta el ítem que cabe", failures)
	_check(not container.add_item(item_def), "Container rechaza el ítem que no cabe", failures)
	_check(container.remove_item(item_def) and container.inventory.items.is_empty(),
		"Container permite sacar el ítem", failures)

	# Hito 2: agarrar, rotar, soltar y lanzar.
	_check(test_item.item == item_def, "el ítem de prueba referencia su ItemDef", failures)
	_reset_player(player, Vector3(0.0, 0.05, 0.0))
	_stand_and_aim(player, test_item.interactable, 1.2)
	for i in 3:
		await physics_frame
	_check(player.current_interactable == test_item.interactable,
		"raycast enfoca el ítem agarrable", failures)
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	_check(player.held == test_item and test_item.freeze, "E agarra el ítem", failures)

	var rotation_before := test_item.rotation
	var right_press := InputEventMouseButton.new()
	right_press.button_index = MOUSE_BUTTON_RIGHT
	right_press.pressed = true
	player._unhandled_input(right_press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120.0, 0.0)
	player._unhandled_input(motion)
	var right_release := InputEventMouseButton.new()
	right_release.button_index = MOUSE_BUTTON_RIGHT
	right_release.pressed = false
	player._unhandled_input(right_release)
	_check(test_item.rotation != rotation_before, "el ítem agarrado rota con el ratón", failures)

	player.drop_held(0.0)
	await physics_frame
	_check(player.held == null and not test_item.freeze, "soltar devuelve el ítem a la física", failures)

	player.grab(test_item)
	await physics_frame
	player.drop_held(8.0)
	await physics_frame
	_check(test_item.linear_velocity.length() > 2.0, "lanzar aplica impulso", failures)

	# Hito 2: panel con SubViewport, sin pausar el mundo.
	_check(test_panel.viewport is SubViewport, "el panel usa SubViewport", failures)
	_check(not test_panel.is_open, "el panel empieza cerrado", failures)
	test_panel.open()
	_check(test_panel.is_open and test_panel.visible, "el panel se abre", failures)
	_check(not paused, "abrir el panel no pausa el mundo", failures)
	test_panel.test_button.emit_signal("pressed")
	_check(test_panel.test_count == 1, "el panel opera su botón", failures)
	test_panel.close()
	_check(not test_panel.is_open and not test_panel.visible, "el panel se cierra", failures)

	# Hito 2: HUD de inventario.
	_check(hud.inventory_label is Label, "HUD tiene inventario", failures)
	player.inventory.add(item_def)
	await process_frame
	_check(hud.inventory_label.text.contains("4.0"), "el HUD muestra el volumen del inventario", failures)
	player.inventory.clear()
	await process_frame
	_check(hud.inventory_label.text.contains("0"), "el HUD se vacía con el inventario", failures)

	# Hito 2: bases de entidad y eventos, sin IA.
	var entity_def := EntityDef.new()
	entity_def.id = &"test_entity"
	entity_def.display_name = "Entidad de prueba"
	entity_def.max_health = 10.0
	var entity := Entity.new()
	main.add_child(entity)
	entity.setup(entity_def)
	_check(entity.definition == entity_def, "Entity recibe su EntityDef", failures)
	entity.activate()
	_check(entity.active, "Entity se activa", failures)
	entity.deactivate()
	_check(not entity.active, "Entity se desactiva", failures)
	entity.queue_free()

	var event_def := EventDef.new()
	event_def.id = &"test_event"
	event_def.display_name = "Evento de prueba"
	event_def.duration = 1.0
	director.events.append(event_def)
	_check(director.trigger(&"test_event"), "EventDirector inicia un evento", failures)
	_check(director.active_event == event_def, "EventDirector guarda el evento activo", failures)
	_check(not director.trigger(&"test_event"), "EventDirector no solapa eventos", failures)
	director.finish_current()
	_check(director.active_event == null, "EventDirector cierra el evento", failures)

	# Hito 3: Alpha Root Base, zonas, props, recorrido y presupuesto.
	_check(base != null, "Base de Alpha Root presente", failures)
	if base != null:
		var zones_variant: Variant = base.get("zones")
		var zones: Dictionary = zones_variant if zones_variant is Dictionary else {}
		var required_zones := [
			&"entrance", &"reception", &"utility", &"lobby", &"loading", &"garage",
			&"break_room", &"signal", &"server_room", &"stairwell",
			&"basement_hall", &"breaker", &"crematory", &"lockers", &"transformer",
			&"basement_storage", &"upper_hall", &"dorm", &"bath", &"storage",
			&"balcony", &"roof_access", &"roof",
		]
		var missing: Array[String] = []
		var unlit: Array[String] = []
		for id in required_zones:
			var marker := zones.get(id) as Node3D
			if marker == null:
				missing.append(String(id))
			elif marker.get_node_or_null("Light") == null:
				unlit.append(String(id))
		_check(missing.is_empty(), "zonas requeridas presentes " + str(missing), failures)
		_check(unlit.is_empty(), "todas las zonas tienen luz " + str(unlit), failures)
		_check(int(base.get("room_count")) >= 20, "la base tiene al menos 20 habitaciones", failures)

		_check(get_nodes_in_group("server_placeholder").size() == 30,
			"30 servidores placeholder", failures)
		_check(get_nodes_in_group("signal_panel").size() == 4,
			"4 paneles de la estación de señales", failures)
		_check(get_nodes_in_group("transformer").size() == 3,
			"3 transformadores exteriores", failures)
		_check(get_nodes_in_group("satellite_dish").size() == 24,
			"24 platos de satélite", failures)
		_check(get_nodes_in_group("coordinate_radar").size() == 3,
			"3 radares de coordenadas", failures)
		_check(get_nodes_in_group("wind_turbine").size() == 4,
			"4 turbinas eólicas", failures)
		_check(get_nodes_in_group("radio_tower").size() == 1,
			"torre de radio presente", failures)
		_check(get_nodes_in_group("breaker").size() == 1, "breaker presente", failures)
		_check(get_nodes_in_group("crematory").size() == 1, "crematorio presente", failures)
		_check(get_nodes_in_group("lockers").size() == 1, "taquillas presentes", failures)

		var breaker := base.get_node_or_null("Breaker") as Node3D
		_check(breaker != null and breaker.global_position.y < -3.0,
			"el breaker está en el sótano", failures)
		var stairs_up := base.get_node_or_null("StairsUp") as StaticBody3D
		var stairs_down := base.get_node_or_null("StairsDown") as StaticBody3D
		_check(stairs_up != null and stairs_up.get_node_or_null("Collision") is CollisionShape3D,
			"rampa superior con colisión", failures)
		_check(stairs_down != null and stairs_down.get_node_or_null("Collision") is CollisionShape3D,
			"rampa del sótano con colisión", failures)
		_check(base.get_node_or_null("RoofRamp") is StaticBody3D,
			"rampa al tejado presente", failures)

		# Recorrido real: pasillo y entrada a Signal Processing.
		_reset_player(player, Vector3(0.0, 0.05, 0.0))
		for i in 2:
			await physics_frame
		Input.action_press("move_forward")
		for i in 70:
			await physics_frame
		Input.action_release("move_forward")
		_check(player.global_position.z < -3.0,
			"se entra al Signal Processing desde el pasillo", failures)

		_reset_player(player, Vector3(-24.0, 0.05, 0.0))
		for i in 2:
			await physics_frame
		Input.action_press("move_right")
		for i in 70:
			await physics_frame
		Input.action_release("move_right")
		_check(player.global_position.x > -20.0, "el pasillo central es recorrible", failures)

		# Rampas: subir a la planta superior y bajar al sótano.
		_reset_player(player, Vector3(25.0, 0.05, -1.0))
		for i in 2:
			await physics_frame
		Input.action_press("move_right")
		for i in 140:
			await physics_frame
		Input.action_release("move_right")
		_check(player.global_position.y > 3.0,
			"la rampa sube a la planta superior (y=%.2f)" % player.global_position.y, failures)

		_reset_player(player, Vector3(25.0, 0.05, 1.0))
		for i in 2:
			await physics_frame
		Input.action_press("move_right")
		for i in 140:
			await physics_frame
		Input.action_release("move_right")
		_check(player.global_position.y < -3.0,
			"la rampa baja al sótano (y=%.2f)" % player.global_position.y, failures)

		var budget := _count_budget(main)
		_check(int(budget.get("triangles", 0)) < 150000,
			"presupuesto: menos de 150k triángulos (%d)" % int(budget.get("triangles", 0)), failures)
		_check(int(budget.get("draws", 0)) < 250,
			"presupuesto: menos de 250 draw calls (%d)" % int(budget.get("draws", 0)), failures)

	_finish(failures)


func _measure_speed(player: Player, action: String) -> float:
	_reset_player(player, Vector3(-24.0, 0.05, 0.0))
	for i in 2:
		await physics_frame
	Input.action_press("move_right")
	if action != "":
		Input.action_press(action)
	for i in 24:
		await physics_frame
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_right")
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
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "crouch",
			"jump", "interact", "drop", "toggle_test_panel"]:
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
		print("SMOKE OK: hitos 0, 1, 2 y 3")
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


func _count_budget(root_node: Node) -> Dictionary:
	var triangles := 0
	var draws := 0
	for node in root_node.find_children("*", "", true, false):
		if node is MultiMeshInstance3D:
			var multimesh := (node as MultiMeshInstance3D).multimesh
			if multimesh != null and multimesh.mesh != null:
				triangles += _mesh_triangles(multimesh.mesh) * multimesh.instance_count
				draws += 1
		elif node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				triangles += _mesh_triangles(mesh)
				draws += 1
		elif node is Label3D:
			draws += 1
	return {"triangles": triangles, "draws": draws}


func _mesh_triangles(mesh: Mesh) -> int:
	return mesh.get_faces().size() / 3
