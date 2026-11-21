extends SceneTree
## Smoke test de los hitos 0–6:
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
	var power := main.get("power") as PowerSystem
	var signals := main.get("signals") as SignalSystem
	var console := main.get_node_or_null("SignalConsole") as SignalConsole
	var cycle := main.get("cycle") as DailyCycle
	var cycle_console := main.get_node_or_null("CycleConsole") as CycleConsole
	var hud := main.get_node_or_null("HUD") as Hud
	var test_item := main.get_node_or_null("TestItem") as Grabbable
	var test_panel := main.get_node_or_null("TestPanel") as ScreenPanel
	var director := main.get_node_or_null("EventDirector") as EventDirector
	var base := main.get_node_or_null("Base")

	_check(player != null, "Player es CharacterBody3D", failures)
	_check(machine != null, "TestMachine presente", failures)
	_check(power != null, "PowerSystem presente", failures)
	_check(hud != null, "HUD presente", failures)
	_check(test_item != null, "item de prueba presente", failures)
	_check(test_panel != null, "panel de prueba presente", failures)
	_check(director != null, "EventDirector presente", failures)

	if player == null or machine == null or power == null or hud == null:
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

	# Hito 4: el circuito de Calculations alimenta la máquina de prueba.
	machine.toggle_power()
	_check(machine.state == Machine.State.ON, "la máquina enciende de nuevo", failures)
	power.set_circuit_enabled(PowerSystem.Circuit.CALCULATIONS, false)
	await physics_frame
	_check(machine.state == Machine.State.NO_POWER,
		"apagar Calculations deja la máquina sin energía", failures)
	power.set_circuit_enabled(PowerSystem.Circuit.CALCULATIONS, true)
	await physics_frame
	_check(machine.state == Machine.State.OFF, "al volver el circuito la máquina queda apagada", failures)

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

	# Hito 4: energía, transformadores, breakers y apagón.
	_check(hud.power_label is Label, "HUD tiene panel de red", failures)
	hud._refresh_power()
	_check(hud.power_label.text.contains("Estabilidad"), "el HUD muestra la estabilidad", failures)
	_check(is_equal_approx(balance.transformer_capacity_w, 1200.0),
		"balance: 1200 W por transformador", failures)
	_check(balance.transformer_count == 3, "balance: 3 transformadores", failures)
	_check(balance.power_circuit_draws.size() == PowerSystem.CIRCUIT_COUNT,
		"balance: una carga por circuito", failures)

	# Núcleo puro: capacidad, eficiencia y circuitos.
	var plant := PowerSystem.new()
	plant.setup(balance)
	_check(plant.transformer_count() == 3, "PowerSystem crea 3 transformadores", failures)
	_check(plant.circuit_count() == 5, "PowerSystem tiene 5 circuitos", failures)
	_check(plant.efficiency() >= 0.999, "la red arranca sin sobrecarga", failures)
	_check(plant.is_circuit_powered(PowerSystem.Circuit.DOWNLOADING),
		"los circuitos arrancan con energía", failures)

	# Un transformador dañado baja la capacidad y frena los circuitos.
	plant.damage_transformer(0)
	_check(plant.capacity_w() < plant.demand_w(), "un trafo dañado deja la red corta", failures)
	_check(plant.efficiency() < 0.999, "la sobrecarga baja la eficiencia", failures)
	var slow_speed := plant.circuit_speed(PowerSystem.Circuit.DOWNLOADING)
	_check(slow_speed < 0.999, "la sobrecarga frena los circuitos", failures)

	# Apagar Calculations libera energía y acelera el resto.
	plant.set_circuit_enabled(PowerSystem.Circuit.CALCULATIONS, false)
	_check(plant.efficiency() >= 0.999, "apagar Calculations libera energía", failures)
	_check(plant.circuit_speed(PowerSystem.Circuit.DOWNLOADING) > slow_speed,
		"los circuitos restantes se aceleran", failures)
	_check(not plant.is_circuit_powered(PowerSystem.Circuit.CALCULATIONS),
		"el circuito apagado no recibe energía", failures)

	# La sobrecarga sostenida quema un transformador y corta la base.
	plant.set_circuit_enabled(PowerSystem.Circuit.CALCULATIONS, true)
	var stability_before := plant.stability()
	for i in 10:
		plant.tick(1.0)
	_check(plant.stability() < stability_before, "la sobrecarga gasta estabilidad", failures)
	var guard := 0
	while not plant.is_blackout() and guard < 4000:
		plant.tick(1.0)
		guard += 1
	_check(plant.is_blackout(), "estabilidad 0 corta toda la base", failures)
	_check(plant.damaged_transformers() >= 1, "el transformador quemado queda dañado", failures)
	_check(not plant.is_circuit_powered(PowerSystem.Circuit.UTILITIES),
		"en apagón ningún circuito recibe energía", failures)

	# El daño bloquea el rearme; después, dos pulsaciones.
	_check(not plant.press_restart() and plant.is_blackout(),
		"un transformador dañado bloquea el rearme", failures)
	_check(plant.warning().contains("dañado"), "el aviso nombra el transformador dañado", failures)
	plant.repair_all()
	_check(not plant.press_restart(), "la primera pulsación solo arma", failures)
	_check(plant.is_restart_armed(), "el breaker queda armado", failures)
	_check(plant.press_restart() and not plant.is_blackout(),
		"la segunda pulsación rearma la red", failures)
	_check(plant.is_circuit_powered(PowerSystem.Circuit.DOWNLOADING),
		"los circuitos vuelven tras el rearme", failures)

	# Control remoto: 30 s y mejora hasta 1 s.
	var remote := PowerSystem.new()
	remote.setup(balance)
	remote.trigger_blackout()
	_check(is_equal_approx(remote.remote_seconds(), 30.0),
		"el control remoto tarda 30 s", failures)
	_check(remote.start_remote_restart(), "el control remoto arranca en apagón", failures)
	remote.tick(29.0)
	_check(remote.is_blackout(), "a los 29 s sigue el apagón", failures)
	remote.tick(1.1)
	_check(not remote.is_blackout(), "a los 30 s el control remoto rearma", failures)
	remote.upgrade_remote()
	_check(remote.remote_seconds() < 30.0 and remote.remote_seconds() >= 1.0,
		"la mejora reduce el tiempo del control remoto", failures)
	for i in 10:
		remote.upgrade_remote()
	_check(is_equal_approx(remote.remote_seconds(), 1.0),
		"el control remoto llega a 1 s", failures)

	# Consumidores: una carga registrada obedece al circuito.
	var consumer := PowerConsumer.new()
	consumer.draw_w = 100.0
	remote.register_consumer(consumer, PowerSystem.Circuit.UTILITIES)
	_check(consumer.powered, "el consumidor recibe energía del circuito", failures)
	remote.trigger_blackout()
	_check(not consumer.powered, "el apagón deja al consumidor sin energía", failures)
	remote.press_restart()
	remote.press_restart()
	_check(consumer.powered, "el rearme devuelve la energía al consumidor", failures)
	consumer.free()

	# Escena: breaker, transformadores, luces y rearme con el botón rojo.
	var panel := main.find_child("BreakerPanel", true, false) as BreakerPanel
	_check(panel != null and panel.switch_count() == 5, "el breaker tiene 5 circuitos", failures)
	_check(get_nodes_in_group("power_transformer").size() == 3,
		"3 transformadores con interactuable", failures)
	_check(power.is_circuit_powered(PowerSystem.Circuit.UTILITIES),
		"Utilities alimenta las luces", failures)

	if panel != null:
		var switch := panel.get_switch(PowerSystem.Circuit.PLAYING)
		var enabled_before := power.is_circuit_enabled(PowerSystem.Circuit.PLAYING)
		_stand_and_aim(player, switch, 1.2, -3.95)
		for i in 4:
			await physics_frame
		_check(player.current_interactable == switch, "el raycast enfoca un breaker", failures)
		Input.action_press("interact")
		await physics_frame
		Input.action_release("interact")
		await physics_frame
		_check(power.is_circuit_enabled(PowerSystem.Circuit.PLAYING) != enabled_before,
			"E conmuta el circuito", failures)
		power.set_circuit_enabled(PowerSystem.Circuit.PLAYING, enabled_before)

		var zones: Dictionary = base.get("zones")
		var zone_light: Light3D = null
		if not zones.is_empty():
			zone_light = (zones.values()[0] as Node3D).get_node_or_null("Light") as Light3D
		_check(zone_light != null and zone_light.visible,
			"las luces de zona están encendidas", failures)

		power.trigger_blackout()
		await physics_frame
		_check(zone_light != null and not zone_light.visible,
			"el apagón deja la base a oscuras", failures)
		_check(panel.restart_enabled(), "el botón rojo se habilita en apagón", failures)
		_check(not panel.press_restart(), "la primera pulsación del botón arma", failures)
		_check(power.is_restart_armed(), "el botón rojo arma el breaker", failures)
		_check(panel.press_restart() and not power.is_blackout(),
			"dos pulsaciones rearman la base", failures)
		_check(zone_light != null and zone_light.visible, "las luces vuelven al rearmar", failures)

	# Hito 5: estación de señales.
	_check(signals != null, "SignalSystem presente", failures)
	_check(console != null, "consola de señales presente", failures)
	if signals != null and console != null:
		_check(signals.catalog_size() == 8, "catálogo con 8 señales", failures)
		var relay := signals.select_by_id(&"relay_hum")
		_check(relay != null and relay.condition == SignalSystem.Condition.OK,
			"la señal de prueba es válida", failures)
		_check(signals.radar_bearing(0) != signals.radar_bearing(1),
			"los tres radares dan rumbos distintos", failures)

		signals.set_azimuth(0.0)
		signals.set_elevation(0.0)
		_check(not bool(signals.scan().get("found", true)),
			"el ping falla lejos de la portadora", failures)
		signals.set_azimuth(relay.azimuth)
		signals.set_elevation(relay.elevation)
		_check(bool(signals.scan().get("found", false)),
			"el ping encuentra la portadora", failures)

		_align_signal(signals, relay)
		_check(signals.alignment() >= 0.99, "las seis perillas alinean la señal", failures)
		_check(signals.start_download(), "la descarga arranca alineada", failures)
		signals.tick(8.0)
		_check(signals.download_count() == 1, "la descarga completa una señal", failures)
		_check(signals.quality_of(0) > 0.8, "la calidad depende de la alineación", failures)

		_check(signals.play_copy(0) and signals.is_playing(), "la señal se reproduce", failures)
		signals.stop_playback()
		_check(not signals.is_playing(), "la reproducción se detiene", failures)
		_check(signals.save_copy(0), "la señal se guarda en la base de datos", failures)
		_check(not signals.save_copy(0), "no se guarda dos veces la misma señal", failures)

		var value_before := signals.copy_value(0)
		_check(signals.process_copy(0, 1), "procesa nivel 1", failures)
		_check(not signals.process_copy(0, 3), "no se salta un nivel de procesado", failures)
		_check(signals.process_copy(0, 2), "procesa nivel 2", failures)
		_check(signals.process_copy(0, 3), "procesa nivel 3", failures)
		_check(signals.copy_value(0) > value_before, "procesar sube el valor", failures)

		var disk := signals.export_copy(0)
		_check(int(disk.get("value", 0)) > 0, "exportar a disco calcula el valor", failures)
		var earned := signals.sell_disk(signals.disk_count() - 1)
		_check(earned == int(disk.get("value", 0)) and signals.credits == earned,
			"vender el disco paga créditos", failures)
		var copy_disk := signals.export_copy(0)
		_check(int(copy_disk.get("value", -1)) == 0, "una copia vale 0", failures)

		var satellite := signals.select_by_id(&"silent_satellite")
		_align_signal(signals, satellite)
		_check(not signals.start_download(), "un satélite caído no descarga", failures)
		var invalid := signals.select_by_id(&"false_object")
		_align_signal(signals, invalid)
		_check(not signals.start_download(), "un objeto inválido no descarga", failures)

		var weak := signals.select_by_id(&"weak_transmission")
		_align_signal(signals, weak)
		_check(signals.start_download(), "la señal débil arranca", failures)
		signals.tick(8.0)
		_check(signals.quality_of(signals.download_count() - 1) <= 0.45,
			"la señal débil limita la calidad al 45%", failures)

		var storm := signals.select_by_id(&"storm_echo")
		_align_signal(signals, storm)
		_check(signals.start_download(), "la tormenta deja descargar", failures)
		signals.tick(8.0)
		_check(signals.quality_of(signals.download_count() - 1) < storm.quality,
			"la tormenta resta calidad", failures)

		var art := SignalArt.texture_for(relay)
		_check(art is ImageTexture and art.get_width() == 64, "la señal genera su imagen", failures)
		_check(console.tab_count() == 1, "una sola pestaña en terminal", failures)
		console.open_tab(0)
		_check(console.is_open() and console.current_tab() == 0,
			"la consola abre Reproducción", failures)
		console.close()
		_check(not console.is_open(), "la consola se cierra", failures)

		_check(get_nodes_in_group("signal_panel").size() == 4, "4 paneles físicos", failures)
		var panels := get_nodes_in_group("signal_panel")
		panels.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))

		# Fase A de la estación física: Descargas con perillas, detector y palanca.
		var downloads := (panels[1] as Node3D).get_node_or_null("DownloadsPanel") as DownloadsPanel
		_check(downloads != null, "panel de Descargas físico", failures)
		if downloads != null:
			_check(downloads.knob_count() == 1, "una sola perilla de frecuencia", failures)
			_check(downloads.get_polarity_switch() != null,
				"selector de polaridad de tres posiciones", failures)
			_check(downloads.get_detector() != null and downloads.get_save_button() != null,
				"detector y pulsador de guardado", failures)
			_check(downloads.screen_title() != "", "la pantalla de Descargas da lectura", failures)
			_check(downloads.get_node_or_null("Chassis") != null
				and downloads.get_node_or_null("Chassis/ChassisBatch0") != null,
				"la consola tiene chasis con geometría fusionada", failures)
			_check(downloads.get_node_or_null("Head") != null
				and downloads.get_node_or_null("Head/VuNeedle") != null,
				"la consola tiene cabezal y vúmetro", failures)
			_check(downloads.find_child("CrtScreen", true, false) != null
				and downloads.get_node_or_null("Lamp") != null,
				"la consola tiene CRT y lámpara", failures)
			# Encaje del mueble: cubierta, zócalo y cabezal comparten aristas.
			_check(downloads.deck_front_edge().distance_to(
				Vector3(0.0, DownloadsPanel.CABINET_TOP, DownloadsPanel.DECK_FRONT_Z)) < 0.02,
				"la cubierta muere en la arista frontal del chasis", failures)
			_check(absf(downloads.deck_back_edge().y - DownloadsPanel.RISER_TOP) < 0.01
				and absf(downloads.deck_back_edge().z - downloads.head_front_bottom().z) < 0.01,
				"la cubierta arranca en el zócalo del cabezal", failures)
			_check(absf(downloads.head_front_bottom().y - DownloadsPanel.RISER_TOP) < 0.02,
				"el cabezal se apoya en el zócalo", failures)
			var knob := downloads.get_knob(0)
			_check(knob != null, "la perilla de frecuencia existe", failures)
			if knob != null:
				var deck := downloads.get_node("Deck") as Node3D
				var seat := deck.global_transform.affine_inverse() * knob.global_position
				_check(absf(seat.y) < 0.006 and seat.z > 0.02 and seat.z < 0.33,
					"la perilla se apoya en la cubierta", failures)
				signals.select_by_id(&"relay_hum")
				_stand_and_aim(player, knob, 1.1, 0.05)
				for i in 4:
					await physics_frame
				_check(player.current_interactable == knob,
					"el raycast enfoca una perilla", failures)
				var frequency_before := signals.frequency
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_UP
				wheel.pressed = true
				knob._unhandled_input(wheel)
				_check(signals.frequency != frequency_before,
					"la rueda gira la perilla", failures)
				_align_signal(signals, signals.selected_def)
				downloads.sync_knobs()
				_check(signals.alignment() >= 0.99, "la perilla y el selector alinean la señal", failures)
				var lever := downloads.get_lever()
				_check(lever != null, "la palanca de descarga existe", failures)
				if lever != null:
					var detector := downloads.get_detector()
					detector.set_on(false)
					lever.activate()
					_check(not signals.is_downloading(),
						"sin detector no arranca la descarga", failures)
					detector.set_on(true)
					lever.activate()
					_check(signals.is_downloading(), "la palanca inicia la descarga", failures)
					lever.activate()
					_check(not signals.is_downloading(), "la palanca detiene la descarga", failures)

			# El pulsador guarda la copia recién descargada en la base de datos.
			signals.select_by_id(&"relay_hum")
			_align_signal(signals, signals.selected_def)
			signals.start_download()
			signals.tick(8.0)
			var saved_before := signals.saved_count()
			downloads.get_save_button().activate()
			_check(signals.saved_count() == saved_before + 1,
				"el pulsador guarda la copia en la base", failures)

		# Fase B de la estación física: Coordenadas con perillas y pulsador de ping.
		var coordinates := (panels[0] as Node3D).get_node_or_null("CoordinatesPanel") as CoordinatesPanel
		_check(coordinates != null, "panel de Coordenadas físico", failures)
		_check(panels[0].get_node_or_null("SignalPanelInteract") == null,
			"el panel físico no abre el terminal", failures)
		if coordinates != null:
			_check(coordinates.get_azimuth_knob() != null
					and coordinates.get_elevation_knob() != null
					and coordinates.get_ping_button() != null,
				"el panel tiene perillas y pulsador de ping", failures)
			_check(coordinates.find_child("CrtScreen", true, false) != null,
				"el panel tiene CRT", failures)
			var az := coordinates.get_azimuth_knob()
			var el := coordinates.get_elevation_knob()
			var ping := coordinates.get_ping_button()
			if az != null and el != null and ping != null:
				signals.select_by_id(&"relay_hum")
				signals.set_azimuth(relay.azimuth)
				signals.set_elevation(relay.elevation)
				coordinates.sync_knobs()
				_stand_and_aim(player, ping, 1.3, 0.05)
				for i in 4:
					await physics_frame
				_check(player.current_interactable == ping,
					"el raycast enfoca el pulsador de ping", failures)
				Input.action_press("interact")
				await physics_frame
				Input.action_release("interact")
				await physics_frame
				_check(signals.selected_def == relay,
					"el ping fija portadora con azimut y elevación alineados", failures)
		_check(power.is_circuit_powered(PowerSystem.Circuit.CALCULATIONS),
			"la estación no altera la energía", failures)

		# Fase D: Procesado ya es una máquina física en el marcador 4.
		var processing_physical := (panels[3] as Node3D).get_node_or_null("ProcessingPanel") as ProcessingPanel
		_check(processing_physical != null, "panel de Procesado físico", failures)
		_check(panels[3].get_node_or_null("SignalPanelInteract") == null,
			"sin overlay en Procesado", failures)
		console.open_tab(0)
		_check(console.current_tab() == 0,
			"la terminal sigue abriendo Reproducción", failures)
		console.close()

		# Fase D: contrato del modelo exportado desde Blender.
		var processing_model := load("res://assets/models/signal-processing-console.glb") as PackedScene
		_check(processing_model != null, "modelo de Procesado importado", failures)
		if processing_model != null:
			var processing_model_inst := processing_model.instantiate()
			_check(processing_model_inst.find_child("SIG_dial_freq", true, false) != null,
				"rueda central exportada", failures)
			_check(processing_model_inst.find_child("SIG_slot_housing", true, false) != null,
				"ranura exportada", failures)
			_check(processing_model_inst.find_child("SIG_crt_screen", true, false) == null,
				"sin CRT literal en el GLB", failures)
			processing_model_inst.free()

		# Fase D: lógica pura de decodificación, aislada del estado de la partida.
		var decode_system := SignalSystem.new()
		decode_system.setup(SignalSystem.load_catalog("res://data/signals/catalog.json"))
		decode_system.configure_balance(load("res://data/balance.tres") as GameBalance)
		_check(is_equal_approx(decode_system.decode_ready_stability, 0.78),
			"umbral de estabilidad desde balance", failures)
		_check(decode_system.decode_stability() == 0.0,
			"sin portadora no hay estabilidad", failures)
		var decode_def := decode_system.select_by_id(&"relay_hum")
		_check(decode_def != null and is_equal_approx(decode_def.decode_target, 0.5),
			"objetivo de fase en el catálogo", failures)
		if decode_def != null:
			decode_system.set_decode_tuning(0.5)
			_check(decode_system.decode_stability() == 0.0,
				"sin copia guardada la onda no se estabiliza", failures)
			decode_system.set_decode_tuning(0.0)
			_check(decode_system.decode_stability() == 0.0,
				"fase lejana da estabilidad 0", failures)
			_check(decode_system.last_saved_index() == -1,
				"sin copias no hay índice guardado", failures)
			_check(not decode_system.confirm_decode(),
				"sin copia guardada no se procesa", failures)
			_align_signal(decode_system, decode_def)
			_check(decode_system.start_download(), "la copia de prueba se descarga", failures)
			decode_system.tick(8.0)
			_check(decode_system.save_copy(0), "la copia de prueba se guarda", failures)
			_check(decode_system.last_saved_index() == 0,
				"la última copia guardada es la que se procesa", failures)
			decode_system.set_decode_tuning(0.5)
			_check(decode_system.confirm_decode(), "con fase y calidad se procesa", failures)
			_check(decode_system.copy_level(0) == 1,
				"confirmar ejecuta el nivel siguiente", failures)
			decode_system.downloads[0]["quality"] = 0.1
			_check(not decode_system.confirm_decode(),
				"calidad insuficiente bloquea el nivel siguiente", failures)
			_check(decode_system.copy_level(0) == 1,
				"el nivel no sube cuando falla la calidad", failures)

			# Fase D: panel físico con perilla, pulsador y CRT vivo.
			decode_system.downloads[0]["quality"] = 0.9
			var panel_root := Node3D.new()
			root.add_child(panel_root)
			var processing := ProcessingPanel.new()
			panel_root.add_child(processing)
			processing.setup(decode_system)
			_check(processing.get_decode_knob() != null
					and not processing.get_decode_knob().visible,
				"perilla de fase invisible sobre el modelo", failures)
			_check(processing.get_confirm_button() != null
					and not processing.get_confirm_button().visible,
				"pulsador de confirmar invisible sobre el modelo", failures)
			_check(processing.get_crt() != null, "el panel tiene CRT vivo", failures)
			_check(not processing.is_locked(), "el panel arranca sin bloqueo", failures)
			var phase_knob := processing.get_decode_knob()
			phase_knob.sync_value(0.5)
			await process_frame
			await process_frame
			_check(is_equal_approx(decode_system.decode_tuning, 0.5),
				"girar la perilla cambia la fase en el mismo frame", failures)
			_check(is_equal_approx(processing.get_crt().stability, 1.0),
				"la onda del CRT se estabiliza al girar la perilla", failures)
			processing.get_confirm_button().activate()
			_check(processing.is_locked(), "confirmar enciende el LED LOCK", failures)
			processing.get_confirm_button().activate()
			_check(decode_system.copy_level(0) == 3,
				"el panel permite procesar los tres niveles", failures)

		# Fase D: la fase objetivo pertenece a la copia que se va a procesar.
		var mismatch_system := SignalSystem.new()
		mismatch_system.setup(SignalSystem.load_catalog("res://data/signals/catalog.json"))
		mismatch_system.configure_balance(load("res://data/balance.tres") as GameBalance)
		var saved_def := mismatch_system.select_by_id(&"distant_choir")
		_align_signal(mismatch_system, saved_def)
		mismatch_system.start_download()
		mismatch_system.tick(8.0)
		mismatch_system.save_copy(0)
		var other_def := mismatch_system.select_by_id(&"relay_hum")
		mismatch_system.set_decode_tuning(other_def.decode_target)
		_check(mismatch_system.decode_stability() < mismatch_system.decode_ready_stability,
			"la fase objetivo sigue a la copia guardada, no al escaneo actual", failures)
		_check(not mismatch_system.confirm_decode(),
			"no se procesa una copia ajena a la fase sintonizada", failures)
		_check(mismatch_system.copy_level(0) == 0, "la copia ajena no sube de nivel", failures)

		var no_copy_system := SignalSystem.new()
		no_copy_system.setup(SignalSystem.load_catalog("res://data/signals/catalog.json"))
		no_copy_system.configure_balance(load("res://data/balance.tres") as GameBalance)
		no_copy_system.select_by_id(&"relay_hum")
		no_copy_system.set_decode_tuning(0.5)
		_check(not no_copy_system.confirm_decode(), "sin copia no se confirma", failures)
		_check(no_copy_system.status().contains("COPIA"),
			"sin copia explica el motivo", failures)

		var gate_system := SignalSystem.new()
		gate_system.setup(SignalSystem.load_catalog("res://data/signals/catalog.json"))
		gate_system.configure_balance(load("res://data/balance.tres") as GameBalance)
		var gate_def := gate_system.select_by_id(&"relay_hum")
		_align_signal(gate_system, gate_def)
		gate_system.start_download()
		gate_system.tick(8.0)
		gate_system.save_copy(0)
		_check(gate_system.export_copy(0).is_empty(),
			"sin procesar no se exporta a disco", failures)
		_check(gate_system.status().contains("PROCESA"),
			"exportar sin procesar explica el motivo", failures)

	# Hito 6: ciclo diario, tarea, tienda y dron.
	_check(cycle != null, "DailyCycle presente", failures)
	_check(cycle_console != null, "terminal del ciclo presente", failures)
	if cycle != null and cycle_console != null:
		_check(is_equal_approx(cycle.clock.minutes_per_second, 0.32),
			"un día dura 75 min reales", failures)
		_check(cycle.clock.day == 1 and cycle.clock.hour() >= 18,
			"el día arranca a las 18:00", failures)
		_check(cycle.task != null and cycle.task.day == 1, "la tarea del día 1 existe", failures)

		var task := cycle.task
		_check(cycle.qualifying_signals() >= task.signals_required,
			"hay señales que cumplen la tarea", failures)
		var credits_before := signals.credits
		var points_before := cycle.economy.points
		_check(cycle.deliver_task(), "la tarea se entrega", failures)
		_check(signals.credits == credits_before + task.reward_credits,
			"la tarea paga créditos", failures)
		_check(cycle.economy.points == points_before + task.reward_points,
			"la tarea paga puntos", failures)
		_check(not cycle.deliver_task(), "no se entrega dos veces", failures)

		# Tienda: rechazo sin créditos, cobro y pedido pendiente.
		var poor := cycle.economy.buy("empty_disk", 0)
		_check(not bool(poor.get("ok", true)), "la tienda rechaza sin créditos", failures)
		var credits_store := signals.credits
		var purchase := cycle.buy("empty_disk")
		_check(bool(purchase.get("ok", false)) and signals.credits == credits_store - 25,
			"la tienda cobra el pedido", failures)
		_check(cycle.economy.pending_orders() == 1, "el pedido espera al dron", failures)

		# Dormir cruza medianoche y el dron entrega a las 06:00.
		cycle.clock.sleep_to(6)
		_check(cycle.clock.hour() == 6 and cycle.clock.day == 2,
			"dormir avanza a las 06:00 del día siguiente", failures)
		_check(cycle.economy.pending_orders() == 0, "el dron entrega el pedido", failures)
		_check(cycle.last_gifts.size() >= 2, "el dron trae el pedido y un disco vacío", failures)
		_check(cycle.task != null and cycle.task.day == 2, "la tarea se renueva a medianoche", failures)
		_check(player.inventory.items.size() >= 2, "el dron deja los bultos en la mochila", failures)

		# No entregar la tarea del día 2 aplica multa.
		var points_fine := cycle.economy.points
		cycle.clock.sleep_to(6)
		_check(cycle.economy.points < points_fine, "no entregar aplica multa", failures)

		# Bonus semanal: paga una vez y no se repite.
		var points_bonus := cycle.economy.points
		var bonus := cycle.economy.weekly_bonus(1)
		_check(bonus == 100 and cycle.economy.points == points_bonus + 100,
			"el bonus semanal paga puntos", failures)
		_check(cycle.economy.weekly_bonus(1) == 0, "el bonus no se cobra dos veces", failures)

		# Guardado provisional en memoria.
		var snap := cycle.snapshot()
		var saved_day := cycle.clock.day
		cycle.clock.day = 9
		cycle.restore(snap)
		_check(cycle.clock.day == saved_day, "el guardado provisional restaura el día", failures)
		_check(cycle.task != null and cycle.task.day == saved_day,
			"el guardado provisional restaura la tarea", failures)

		# HUD y terminal.
		hud._refresh_clock()
		_check(hud.clock_label is Label and hud.clock_label.text.contains("DÍA"),
			"el HUD muestra el reloj", failures)
		_check(cycle_console.tab_count() == 4, "la terminal tiene cuatro pestañas", failures)
		cycle_console.open_tab(1)
		_check(cycle_console.is_open() and cycle_console.current_tab() == 1,
			"la terminal abre Tarea", failures)
		cycle_console.close()
		_check(not cycle_console.is_open(), "la terminal se cierra", failures)

		var terminal := base.get_node_or_null("MainComputer") as Interactable
		_check(terminal != null, "la terminal física existe", failures)
		if terminal != null:
			_stand_and_aim(player, terminal, 1.3, 0.05)
			for i in 4:
				await physics_frame
			_check(player.current_interactable == terminal,
				"el raycast enfoca la terminal", failures)
			Input.action_press("interact")
			await physics_frame
			Input.action_release("interact")
			await physics_frame
			_check(cycle_console.is_open(), "E abre la terminal", failures)
			cycle_console.close()

	_finish(failures)


func _align_signal(system: SignalSystem, def: SignalDef) -> void:
	if def == null:
		return
	system.set_knob(&"frequency", def.frequency)
	system.set_knob(&"polarity", def.polarity)


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


func _stand_and_aim(player: Player, target: Node3D, distance: float,
		floor_y: float = 0.05) -> void:
	var target_pos := target.global_position
	player.global_position = Vector3(target_pos.x, floor_y, target_pos.z + distance)
	var eye := player.global_position + Vector3(0, 1.62, 0)
	var direction := (target_pos - eye).normalized()
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.head.rotation.x = asin(clampf(direction.y, -1.0, 1.0))


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SMOKE OK: hitos 0, 1, 2, 3, 4, 5 y 6")
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
