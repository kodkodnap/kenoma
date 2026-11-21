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

@export_group("Inventario")
@export var inventory_capacity: float = 24.0

@export_group("Energía")
## Transformadores sanos a estabilidad 1.0. La capacidad total es 3 × 1200 W.
@export var transformer_count: int = 3
@export var transformer_capacity_w: float = 1200.0
## Carga base por circuito: Cálculos, Descargas, Coordenadas, Reproducción, Servicios.
@export var power_circuit_draws: Array[float] = [800.0, 650.0, 550.0, 450.0, 350.0]
@export var power_stability_drain_per_second: float = 0.08
@export var power_stability_recover_per_second: float = 0.05
## Segundos para la segunda pulsación del botón rojo.
@export var power_restart_window: float = 5.0
@export var power_restart_stability: float = 0.35
## Pasos del módulo de control remoto: 30 s → 20 → 12 → 6 → 3 → 1.
@export var power_remote_steps: Array[float] = [30.0, 20.0, 12.0, 6.0, 3.0, 1.0]

@export_group("Procesado")
@export var decode_stability_threshold: float = 0.78
@export var decode_sensitivity: float = 2.5
