extends Node3D
## Escena principal: conecta jugador, HUD, energía, máquina de prueba y prototipos.

const TEST_ITEM := preload("res://scenes/items/test_item.tscn")
const TEST_PANEL := preload("res://scenes/ui/test_panel.tscn")
const SIGNAL_CONSOLE := preload("res://scenes/ui/signal_console.tscn")
const SIGNAL_CATALOG := "res://data/signals/catalog.json"
const CYCLE_CONSOLE := preload("res://scenes/ui/cycle_console.tscn")
const STORE_CATALOG := "res://data/store/catalog.json"

@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var machine: TestMachine = $TestMachine
@onready var base: Node3D = $Base

## Núcleos puros: no son nodos y no conocen la escena.
var power: PowerSystem = PowerSystem.new()
var signals: SignalSystem = SignalSystem.new()
var cycle: DailyCycle = DailyCycle.new()
var signal_console: SignalConsole
var cycle_console: CycleConsole


func _ready() -> void:
	hud.machine = machine
	hud.player = player
	power.setup(player.balance)
	power.register_consumer(machine.consumer, PowerSystem.Circuit.CALCULATIONS)
	hud.power = power
	_wire_power_nodes()
	power.power_changed.connect(_on_power_changed)
	power.circuit_changed.connect(_on_circuit_changed)
	_apply_base_lights()

	signals.setup(SignalSystem.load_catalog(SIGNAL_CATALOG))
	signal_console = SIGNAL_CONSOLE.instantiate() as SignalConsole
	signal_console.name = "SignalConsole"
	add_child(signal_console)
	signal_console.setup(signals)
	_wire_signal_panels()

	cycle.setup(signals, STORE_CATALOG, 20261101)
	cycle_console = CYCLE_CONSOLE.instantiate() as CycleConsole
	cycle_console.name = "CycleConsole"
	add_child(cycle_console)
	cycle_console.setup(cycle)
	cycle.drone_arrived.connect(_on_drone_arrived)
	hud.clock = cycle.clock
	_wire_cycle_terminal()

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


## Engancha el breaker del sótano y los tres transformadores exteriores.
func _wire_power_nodes() -> void:
	var breaker := get_tree().get_first_node_in_group("breaker") as Node3D
	if breaker != null:
		var panel := BreakerPanel.new()
		panel.name = "BreakerPanel"
		breaker.add_child(panel)
		panel.setup(power)

	var markers := get_tree().get_nodes_in_group("transformer")
	markers.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for i in mini(markers.size(), power.transformer_count()):
		var unit := PowerTransformer.new()
		unit.name = "Unit%d" % (i + 1)
		(markers[i] as Node3D).add_child(unit)
		unit.setup(i, power)


## Utilities alimenta las luces de zona: en apagón la base queda a oscuras.
func _apply_base_lights() -> void:
	if base == null:
		return
	var zones_variant: Variant = base.get("zones")
	if not zones_variant is Dictionary:
		return
	var zones := zones_variant as Dictionary
	var on := power.is_circuit_powered(PowerSystem.Circuit.UTILITIES)
	for id in zones:
		var marker := zones[id] as Node3D
		if marker == null:
			continue
		var light := marker.get_node_or_null("Light") as Light3D
		if light != null:
			light.visible = on


func _on_power_changed(_on: bool) -> void:
	_apply_base_lights()


func _on_circuit_changed(circuit: int, _powered: bool) -> void:
	if circuit == PowerSystem.Circuit.UTILITIES:
		_apply_base_lights()


func _process(delta: float) -> void:
	signals.tick(delta)
	cycle.advance(delta)


## Engancha los paneles de Signal Processing. Descargas es físico; el resto, terminal.
## `tabs[i] == -1` significa que ese panel no abre el overlay.
func _wire_signal_panels() -> void:
	var markers := get_tree().get_nodes_in_group("signal_panel")
	markers.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	var panel_names := ["Coordenadas", "Descargas", "Reproducción", "Procesado"]
	var tabs := [0, -1, 1, 2]
	for i in mini(markers.size(), panel_names.size()):
		var marker := markers[i] as Node3D
		if marker == null:
			continue
		if tabs[i] < 0:
			var downloads := DownloadsPanel.new()
			downloads.name = "DownloadsPanel"
			marker.add_child(downloads)
			downloads.setup(signals)
			continue
		var opener := Interactable.new()
		opener.name = "SignalPanelInteract"
		opener.position = Vector3(0.0, 0.1, 0.45)
		opener.prompt = "Abrir %s" % panel_names[i]
		opener.activated.connect(_on_signal_panel.bind(tabs[i]))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 1.2, 0.5)
		shape.shape = box
		opener.add_child(shape)
		marker.add_child(opener)


func _on_signal_panel(_source: Interactable, tab: int) -> void:
	signal_console.open_tab(tab)


## Terminal del ciclo en la consola central de Signal Processing.
func _wire_cycle_terminal() -> void:
	if base == null:
		return
	var terminal := Interactable.new()
	terminal.name = "MainComputer"
	terminal.position = Vector3(0.0, 1.3, -7.6)
	terminal.prompt = "Abrir terminal"
	terminal.activated.connect(_on_terminal_activated)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 0.5)
	shape.shape = box
	terminal.add_child(shape)
	base.add_child(terminal)


func _on_terminal_activated(_source: Interactable) -> void:
	cycle_console.open_tab(0)


## El dron entrega los pedidos y deja un disco vacío; se añaden a la mochila.
func _on_drone_arrived(gifts: Array[Dictionary]) -> void:
	for gift in gifts:
		var path := String(gift.get("item_path", ""))
		if path == "":
			continue
		var def := ResourceLoader.load(path) as ItemDef
		if def != null:
			player.inventory.add(def)
