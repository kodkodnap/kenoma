extends Node3D
## Escena principal: conecta jugador, HUD, red, máquina y prototipos del hito 2.

const TEST_ITEM := preload("res://scenes/items/test_item.tscn")
const TEST_PANEL := preload("res://scenes/ui/test_panel.tscn")

@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var machine: TestMachine = $TestMachine
@onready var grid: PowerGrid = $PowerGrid


func _ready() -> void:
	hud.machine = machine
	hud.grid = grid
	hud.player = player
	grid.register(machine.consumer)
	player.focus_changed.connect(hud.set_focus)
	player.hold_changed.connect(hud.set_hold_progress)

	var item := TEST_ITEM.instantiate()
	item.name = "TestItem"
	add_child(item)
	item.global_position = Vector3(2.5, 0.4, 4.0)

	add_child(TEST_PANEL.instantiate())

	var director := EventDirector.new()
	director.name = "EventDirector"
	add_child(director)
