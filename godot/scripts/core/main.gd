extends Node3D
## Escena principal: conecta jugador, HUD, red y máquina de prueba.

@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var machine: TestMachine = $TestMachine
@onready var grid: PowerGrid = $PowerGrid


func _ready() -> void:
	hud.machine = machine
	hud.grid = grid
	grid.register(machine.consumer)
	player.focus_changed.connect(hud.set_focus)
	player.hold_changed.connect(hud.set_hold_progress)
