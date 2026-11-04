class_name GameClock
extends RefCounted
## Reloj de partida: día, hora y velocidad. Un día completo dura 75 min reales
## en Normal (1440 min de juego / 4500 s reales = 0,32 min por segundo).

signal hour_changed(hour: int)
signal day_changed(day_number: int)
signal midnight_reached(day_number: int)
signal drone_hour_reached(day_number: int)

const MINUTES_PER_DAY := 1440
const DRONE_HOUR := 6
const DAY_REAL_MINUTES := 75.0

var day: int = 1
var minute_of_day: float = 18.0 * 60.0
var speed: float = 1.0
var paused: bool = false
var minutes_per_second: float = float(MINUTES_PER_DAY) / (DAY_REAL_MINUTES * 60.0)


func advance(delta: float) -> void:
	if paused or delta <= 0.0:
		return
	var before_abs := absolute_minutes()
	var after_abs := before_abs + delta * minutes_per_second * speed
	var before_hour := hour()
	day = int(floor(after_abs / float(MINUTES_PER_DAY))) + 1
	minute_of_day = fmod(after_abs, float(MINUTES_PER_DAY))
	var before_day := int(floor(before_abs / float(MINUTES_PER_DAY))) + 1
	if day != before_day:
		day_changed.emit(day)
	_emit_crossings(before_abs, after_abs)
	if hour() != before_hour:
		hour_changed.emit(hour())


## Avanza hasta la próxima vez que sean las `target_hour` (dormir).
func sleep_to(target_hour: int) -> void:
	var now := absolute_minutes()
	var base := int(floor(now / float(MINUTES_PER_DAY))) * MINUTES_PER_DAY
	var target := float(base + clampi(target_hour, 0, 23) * 60)
	if target <= now:
		target += float(MINUTES_PER_DAY)
	var saved_speed := speed
	speed = 1.0
	advance((target - now) / minutes_per_second)
	speed = saved_speed


func absolute_minutes() -> float:
	return float(day - 1) * float(MINUTES_PER_DAY) + minute_of_day


func hour() -> int:
	return int(minute_of_day / 60.0) % 24


func minute() -> int:
	return int(minute_of_day) % 60


func time_string() -> String:
	return "%02d:%02d" % [hour(), minute()]


func next_drone_day() -> int:
	return day if hour() < DRONE_HOUR else day + 1


func _emit_crossings(before_abs: float, after_abs: float) -> void:
	var first := int(floor(before_abs / float(MINUTES_PER_DAY)))
	var last := int(floor(after_abs / float(MINUTES_PER_DAY)))
	for index in range(first, last + 1):
		var midnight := float(index * MINUTES_PER_DAY)
		if midnight > before_abs and midnight <= after_abs:
			midnight_reached.emit(index + 1)
		var drone := float(index * MINUTES_PER_DAY + DRONE_HOUR * 60)
		if drone > before_abs and drone <= after_abs:
			drone_hour_reached.emit(index + 1)
