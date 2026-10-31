class_name GameBalance
extends Resource
## Parámetros de balance del juego. Se editan en data/balance.tres, nunca en los scripts.

@export_group("Jugador")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 1.5
@export var jump_velocity: float = 4.5
@export var ground_acceleration: float = 40.0
@export var air_acceleration: float = 8.0
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.2
@export var head_height: float = 1.62
@export var crouch_head_height: float = 1.0

@export_group("Stamina")
@export var stamina_max: float = 100.0
@export var stamina_drain_per_second: float = 12.0
@export var stamina_regen_per_second: float = 10.0
@export var stamina_sprint_min: float = 15.0

@export_group("Linterna")
## Fracción de batería consumida por segundo (0.006 ≈ 2 min 45 s de luz).
@export var flashlight_drain_per_second: float = 0.006
