class_name DailyTask
extends RefCounted
## Tarea diaria: señales a entregar, recompensa y multa.
## Hashcodes y cintas se activarán en los hitos 8 y 11.

var day: int = 1
var signals_required: int = 1
var min_level: int = 1
var hashcodes_required: int = 0
var tapes_required: int = 0
var reward_credits: int = 120
var reward_points: int = 35
var fine_credits: int = 60
var delivered: bool = false
var missed: bool = false


static func generate(day_number: int, rng: RandomNumberGenerator) -> DailyTask:
	var task := DailyTask.new()
	task.day = day_number
	task.signals_required = 1 + floori(float(day_number) / 3.0)
	task.min_level = clampi(1 + floori(float(day_number - 1) / 4.0), 1, 3)
	task.hashcodes_required = 0
	task.tapes_required = 0
	task.reward_credits = 100 + day_number * 20 + rng.randi_range(0, 20)
	task.reward_points = 30 + day_number * 5
	task.fine_credits = 50 + day_number * 10
	return task


func describe() -> String:
	return "Tarea del día %d: entrega %d señal(es) de nivel %d o superior." % [
		day, signals_required, min_level,
	]


func can_deliver(qualifying_signals: int, hashcodes: int = 0, tapes: int = 0) -> bool:
	return qualifying_signals >= signals_required \
		and hashcodes >= hashcodes_required \
		and tapes >= tapes_required


func deliver() -> bool:
	if delivered or missed:
		return false
	delivered = true
	return true


func to_dict() -> Dictionary:
	return {
		"day": day,
		"signals_required": signals_required,
		"min_level": min_level,
		"hashcodes_required": hashcodes_required,
		"tapes_required": tapes_required,
		"reward_credits": reward_credits,
		"reward_points": reward_points,
		"fine_credits": fine_credits,
		"delivered": delivered,
		"missed": missed,
	}


static func from_dict(data: Dictionary) -> DailyTask:
	var task := DailyTask.new()
	task.day = int(data.get("day", 1))
	task.signals_required = int(data.get("signals_required", 1))
	task.min_level = int(data.get("min_level", 1))
	task.hashcodes_required = int(data.get("hashcodes_required", 0))
	task.tapes_required = int(data.get("tapes_required", 0))
	task.reward_credits = int(data.get("reward_credits", 120))
	task.reward_points = int(data.get("reward_points", 35))
	task.fine_credits = int(data.get("fine_credits", 60))
	task.delivered = bool(data.get("delivered", false))
	task.missed = bool(data.get("missed", false))
	return task
