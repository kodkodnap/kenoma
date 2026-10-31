class_name GameBalance
extends Resource
## Parámetros de balance del juego. Se editan en data/balance.tres, nunca en los scripts.

@export_group("Jugador")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.6
@export var ground_acceleration: float = 40.0
@export var air_acceleration: float = 8.0

@export_group("Linterna")
## Fracción de batería consumida por segundo (0.006 ≈ 2 min 45 s de luz).
@export var flashlight_drain_per_second: float = 0.006
