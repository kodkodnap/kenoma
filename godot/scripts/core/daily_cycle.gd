class_name DailyCycle
extends RefCounted
## Director puro del ciclo diario: reloj, tarea, tienda, dron y guardado provisional.
## La UI y el mundo solo escuchan señales y leen estado.

signal task_ready(task: DailyTask)
signal task_delivered(task: DailyTask, credits: int, points: int)
signal task_missed(task: DailyTask, fine: int)
signal drone_arrived(gifts: Array[Dictionary])
signal notice(text: String)

var clock := GameClock.new()
var economy := Economy.new()
var task: DailyTask
var signals: SignalSystem
var rng := RandomNumberGenerator.new()
var last_gifts: Array[Dictionary] = []


func setup(signal_system: SignalSystem, store_path: String, seed_value: int) -> void:
	signals = signal_system
	rng.seed = seed_value
	economy.setup(Economy.load_store(store_path))
	clock.day = 1
	clock.minute_of_day = 18.0 * 60.0
	clock.midnight_reached.connect(_on_midnight)
	clock.drone_hour_reached.connect(_on_drone)
	task = DailyTask.generate(1, rng)
	task_ready.emit(task)


func advance(delta: float) -> void:
	clock.advance(delta)


func qualifying_signals() -> int:
	if signals == null or task == null:
		return 0
	var count := 0
	for i in signals.download_count():
		if signals.copy_is_saved(i) and signals.copy_level(i) >= task.min_level:
			count += 1
	return count


func deliver_task() -> bool:
	if task == null or task.delivered or task.missed:
		return false
	if not task.can_deliver(qualifying_signals()):
		return false
	task.deliver()
	signals.add_credits(task.reward_credits)
	economy.add_points(task.reward_points)
	economy.log.append("Tarea %d entregada: +%d créditos" % [task.day, task.reward_credits])
	task_delivered.emit(task, task.reward_credits, task.reward_points)
	return true


func buy(item_id: String) -> Dictionary:
	if signals == null:
		return {"ok": false, "credits": 0, "reason": "Sin economía"}
	var result := economy.buy(item_id, signals.credits)
	if bool(result.get("ok", false)):
		signals.set_credits(int(result.get("credits", signals.credits)))
		economy.log.append("Pedido: %s (%d créditos)" % [
			result["item"].get("name", "Artículo"), int(result["item"].get("price", 0)),
		])
	return result


func next_drone_text() -> String:
	return "Próxima llegada: 06:00 del día %d" % clock.next_drone_day()


## Guardado provisional en memoria (el guardado real llega en el hito 15).
func snapshot() -> Dictionary:
	return {
		"clock": {"day": clock.day, "minute": clock.minute_of_day, "speed": clock.speed},
		"points": economy.points,
		"credits": signals.credits if signals != null else 0,
		"orders": economy.orders.duplicate(true),
		"task": task.to_dict() if task != null else {},
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var clock_data: Dictionary = data.get("clock", {})
	clock.day = int(clock_data.get("day", 1))
	clock.minute_of_day = float(clock_data.get("minute", 0.0))
	clock.speed = float(clock_data.get("speed", 1.0))
	economy.points = int(data.get("points", 0))
	economy.orders.clear()
	for order in data.get("orders", []):
		if order is Dictionary:
			economy.orders.append(order)
	if signals != null:
		signals.set_credits(int(data.get("credits", 0)))
	var task_data: Dictionary = data.get("task", {})
	task = DailyTask.from_dict(task_data) if not task_data.is_empty() else null
	points_emit()


func points_emit() -> void:
	economy.points_changed.emit(economy.points)


func _on_midnight(day_number: int) -> void:
	if task != null and not task.delivered and not task.missed:
		task.missed = true
		signals.add_credits(-task.fine_credits)
		economy.add_points(-task.reward_points)
		economy.log.append("Tarea %d perdida: -%d créditos" % [task.day, task.fine_credits])
		task_missed.emit(task, task.fine_credits)
	task = DailyTask.generate(day_number, rng)
	task_ready.emit(task)
	notice.emit("Correo: tarea del día %d" % day_number)


func _on_drone(day_number: int) -> void:
	var delivered := economy.deliver_orders()
	var gifts: Array[Dictionary] = []
	for order in delivered:
		gifts.append(order)
	if day_number % 7 == 0:
		var bonus := economy.weekly_bonus(int(floor(float(day_number) / 7.0)))
		if bonus > 0:
			gifts.append({
				"id": "weekly_bonus",
				"name": "Bonus semanal: %d puntos" % bonus,
				"price": 0,
				"delivered": true,
			})
	gifts.append({
		"id": "empty_disk",
		"name": "Disco vacío",
		"price": 0,
		"item_path": "res://data/items/disk.tres",
		"delivered": true,
	})
	last_gifts = gifts
	drone_arrived.emit(gifts)
	notice.emit("El dron ha llegado: %d bulto(s)" % gifts.size())
