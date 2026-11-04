class_name DownloadsPanel
extends Node3D
## Consola física de descargas: chasis atornillado, cubierta inclinada, CRT de fósforo,
## vúmetro, LEDs, cables y seis perillas reales. La pantalla solo muestra lecturas.

const KNOB_IDS := [&"frequency", &"polarity", &"gain", &"bandwidth", &"filter", &"squelch"]
const KNOB_LABELS := ["FREC", "POL", "GANANCIA", "ANCHO", "FILTRO", "SQUELCH"]
const KNOB_STEPS := [10.0, 1.0, 5.0, 5.0, 5.0, 5.0]
const KNOB_MAX := [1000.0, 2.0, 100.0, 100.0, 100.0, 100.0]

const DECK_TILT := 0.28
const SCREEN_SIZE := Vector2i(640, 360)

var _system: SignalSystem

var _knobs: Array[RotaryKnob] = []
var _detector: ToggleSwitch
var _lever: Lever

var _viewport: SubViewport
var _screen: CrtScreen
var _screen_material: StandardMaterial3D
var _title: Label
var _tuning: Label
var _alignment: Label
var _status: Label
var _progress_text: Label
var _footer: Label

var _needle_pivot: Node3D
var _signal_led: StandardMaterial3D
var _rec_led: StandardMaterial3D
var _detector_on: bool = true

var _time: float = 0.0
var _refresh_timer: float = 0.0
var _needle_value: float = 0.0


func _ready() -> void:
	add_to_group("downloads_panel")
	_build_chassis()
	_build_head()
	_build_deck()
	_build_dressing()
	_build_lamp()
	_build_screen()
	_build_collision()


func setup(system: SignalSystem) -> void:
	_system = system
	if _system != null:
		_system.scan_completed.connect(_on_scan_completed)
		_system.download_progress.connect(_on_download_progress)
		_system.download_completed.connect(_on_download_completed)
		_system.error_raised.connect(_on_error)
	sync_knobs()
	_refresh()


func knob_count() -> int:
	return _knobs.size()


func get_knob(index: int) -> RotaryKnob:
	return _knobs[index] if index >= 0 and index < _knobs.size() else null


func get_lever() -> Lever:
	return _lever


func get_detector() -> ToggleSwitch:
	return _detector


func screen_title() -> String:
	if _title == null or _title.text == "":
		return "SIN PORTADORA"
	return _title.text


func sync_knobs() -> void:
	if _system == null:
		return
	for i in _knobs.size():
		_knobs[i].sync_value(float(_system.knob(KNOB_IDS[i])))
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_animate_needle(delta)
	_animate_leds()
	if _screen != null:
		_screen.signal_level = _system.alignment() if _system != null else 0.0
		_screen.stability = 0.3 + 0.7 * _screen.signal_level
		_screen.downloading = _system.is_downloading() if _system != null else false
		_screen.progress = _system.download_ratio() if _system != null else 0.0
	if _screen_material != null:
		_screen_material.emission_energy_multiplier = 1.12 + 0.05 * sin(_time * 29.0)
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.15
		_refresh_status()


# --- Construcción -------------------------------------------------------------

func _build_chassis() -> void:
	var chassis := Node3D.new()
	chassis.name = "Chassis"
	add_child(chassis)
	MachineMesh.begin_batch(chassis)

	var body := MachineMaterials.body()
	var steel := MachineMaterials.steel()
	var dark := MachineMaterials.dark_steel()
	var panel := MachineMaterials.panel()
	var rubber := MachineMaterials.rubber()

	MachineMesh.box(chassis, Vector3(0.0, -0.58, 0.0), Vector3(2.45, 1.12, 0.66),
		body, Vector3.ZERO, "Cabinet")
	MachineMesh.box(chassis, Vector3(0.0, -0.16, 0.0), Vector3(2.5, 0.07, 0.7),
		steel, Vector3.ZERO, "TopRail")

	# Patas y zócalo retranqueado.
	MachineMesh.box(chassis, Vector3(0.0, -1.185, -0.02), Vector3(2.3, 0.13, 0.58),
		dark, Vector3.ZERO, "Plinth")
	for foot_x in [-1.02, 1.02]:
		for foot_z in [-0.24, 0.24]:
			MachineMesh.cylinder(chassis, Vector3(foot_x, -1.225, foot_z), 0.045, 0.05,
				rubber, Vector3.ZERO, 12, -1.0, "Foot")

	# Carteras laterales con rejilla de ventilación.
	for side in [-1.0, 1.0]:
		MachineMesh.box(chassis, Vector3(float(side) * 1.235, -0.58, 0.0),
			Vector3(0.05, 1.16, 0.7), dark, Vector3.ZERO, "Cheek")
		var transforms: Array[Transform3D] = []
		for i in 9:
			transforms.append(Transform3D(Basis.IDENTITY,
				Vector3(float(side) * 1.262, -0.94 + float(i) * 0.055, 0.04)))
		MachineMesh.slats(chassis, transforms, Vector3(0.008, 0.012, 0.26), dark,
			"SideVent")

	# Puerta de acceso con marco, bisagras y manilla.
	MachineMesh.box(chassis, Vector3(0.0, -0.66, 0.336), Vector3(2.02, 0.78, 0.025),
		panel, Vector3.ZERO, "Door")
	MachineMesh.box(chassis, Vector3(-1.02, -0.66, 0.343), Vector3(0.04, 0.86, 0.03),
		steel, Vector3.ZERO, "DoorFrameLeft")
	MachineMesh.box(chassis, Vector3(1.02, -0.66, 0.343), Vector3(0.04, 0.86, 0.03),
		steel, Vector3.ZERO, "DoorFrameRight")
	MachineMesh.box(chassis, Vector3(0.0, -0.24, 0.343), Vector3(2.08, 0.04, 0.03),
		steel, Vector3.ZERO, "DoorFrameTop")
	MachineMesh.box(chassis, Vector3(0.0, -1.08, 0.343), Vector3(2.08, 0.04, 0.03),
		steel, Vector3.ZERO, "DoorFrameBottom")
	for hinge_y in [-0.42, -0.9]:
		MachineMesh.box(chassis, Vector3(-0.995, float(hinge_y), 0.356),
			Vector3(0.05, 0.12, 0.045), steel, Vector3.ZERO, "Hinge")
		MachineMesh.cylinder(chassis, Vector3(-0.995, float(hinge_y) + 0.06, 0.36),
			0.014, 0.07, steel, Vector3.ZERO, 10, -1.0, "HingePin")
	MachineMesh.box(chassis, Vector3(0.86, -0.66, 0.397), Vector3(0.035, 0.2, 0.035),
		steel, Vector3.ZERO, "Handle")
	for mount_y in [-0.74, -0.58]:
		MachineMesh.box(chassis, Vector3(0.86, float(mount_y), 0.371),
			Vector3(0.04, 0.035, 0.05), steel, Vector3.ZERO, "HandleMount")

	# Rejilla inferior de la puerta.
	var door_slats: Array[Transform3D] = []
	for i in 7:
		door_slats.append(Transform3D(Basis.IDENTITY,
			Vector3(0.0, -0.98 + float(i) * 0.022, 0.352)))
	MachineMesh.slats(chassis, door_slats, Vector3(1.3, 0.01, 0.012), dark, "DoorVent")

	# Placa de identificación atornillada.
	MachineMesh.box(chassis, Vector3(-0.62, -0.32, 0.352), Vector3(0.42, 0.075, 0.006),
		MachineMaterials.cream(), Vector3.ZERO, "DoorPlate")
	MachineMesh.label(chassis, "ACCESO 2  ·  220 V", Vector3(-0.62, -0.32, 0.357),
		0.0012, Color(0.12, 0.11, 0.09), 18)
	MachineMesh.bolts(chassis, [
		Vector3(-0.9, -0.27, 0.354), Vector3(-0.27, -0.27, 0.354),
		Vector3(-0.995, -0.24, 0.346), Vector3(0.995, -0.24, 0.346),
		Vector3(-0.995, -1.08, 0.346), Vector3(0.995, -1.08, 0.346),
	], steel, 0.009, 0.006)
	MachineMesh.end_batch(chassis)


func _build_head() -> void:
	var head := Node3D.new()
	head.name = "Head"
	add_child(head)
	MachineMesh.begin_batch(head)

	var body := MachineMaterials.body()
	var steel := MachineMaterials.steel()
	var dark := MachineMaterials.dark_steel()
	var panel := MachineMaterials.dark_panel()

	MachineMesh.box(head, Vector3(0.0, 0.32, 0.0), Vector3(2.06, 0.72, 0.58),
		body, Vector3.ZERO, "Housing")
	MachineMesh.box(head, Vector3(0.0, -0.03, 0.2), Vector3(1.98, 0.07, 0.42),
		steel, Vector3.ZERO, "LowerLip")
	MachineMesh.box(head, Vector3(0.0, 0.695, 0.0), Vector3(2.1, 0.05, 0.6),
		panel, Vector3.ZERO, "Hood")
	MachineMesh.box(head, Vector3(0.0, 0.718, -0.22), Vector3(2.1, 0.05, 0.18),
		body, Vector3(0.35, 0.0, 0.0), "HoodLip")
	MachineMesh.box(head, Vector3(0.0, 0.33, 0.298), Vector3(1.98, 0.64, 0.02),
		panel, Vector3.ZERO, "Face")
	# Visera sobre el CRT: da sombra al tubo y rompe la cara plana.
	MachineMesh.box(head, Vector3(-0.34, 0.675, 0.39), Vector3(1.36, 0.03, 0.18),
		dark, Vector3(0.42, 0.0, 0.0), "Visor")
	# Junta vertical entre el CRT y la columna de instrumentos.
	MachineMesh.box(head, Vector3(0.235, 0.34, 0.308), Vector3(0.018, 0.58, 0.014),
		dark, Vector3.ZERO, "ColumnSeam")
	# Asas laterales para mover la consola.
	for side in [-1.0, 1.0]:
		MachineMesh.box(head, Vector3(float(side) * 1.045, 0.42, 0.0),
			Vector3(0.03, 0.05, 0.24), steel, Vector3.ZERO, "SideHandle")
		for handle_z in [-0.1, 0.1]:
			MachineMesh.box(head, Vector3(float(side) * 1.03, 0.42, float(handle_z)),
				Vector3(0.05, 0.05, 0.04), steel, Vector3.ZERO, "HandleMount")

	# Cubeta del CRT y bisel atornillado. El fondo queda detrás del cristal.
	MachineMesh.box(head, Vector3(-0.34, 0.335, 0.288), Vector3(1.0, 0.54, 0.03),
		MachineMaterials.rubber(), Vector3.ZERO, "CrtWell")
	MachineMesh.box(head, Vector3(-0.34, 0.60, 0.336), Vector3(1.3, 0.05, 0.06),
		dark, Vector3.ZERO, "BezelTop")
	MachineMesh.box(head, Vector3(-0.34, 0.075, 0.336), Vector3(1.3, 0.05, 0.06),
		dark, Vector3.ZERO, "BezelBottom")
	MachineMesh.box(head, Vector3(-0.8625, 0.34, 0.336), Vector3(0.065, 0.58, 0.06),
		dark, Vector3.ZERO, "BezelLeft")
	MachineMesh.box(head, Vector3(0.1825, 0.34, 0.336), Vector3(0.065, 0.58, 0.06),
		dark, Vector3.ZERO, "BezelRight")
	MachineMesh.bolts(head, [
		Vector3(-0.86, 0.585, 0.368), Vector3(0.18, 0.585, 0.368),
		Vector3(-0.86, 0.09, 0.368), Vector3(0.18, 0.09, 0.368),
	], steel, 0.008, 0.006)

	# Columna derecha: vúmetro, LEDs y altavoz.
	MachineMesh.box(head, Vector3(0.72, 0.33, 0.3), Vector3(0.66, 0.62, 0.015),
		panel, Vector3.ZERO, "RightPanel")
	MachineMesh.box(head, Vector3(0.72, 0.46, 0.312), Vector3(0.37, 0.24, 0.012),
		MachineMaterials.cream(), Vector3.ZERO, "VuPlate")
	MachineMesh.quad(head, Vector3(0.72, 0.46, 0.3195), Vector2(0.33, 0.2),
		MachineMaterials.vu_dial(), Vector3.ZERO, "VuDial")

	_needle_pivot = Node3D.new()
	_needle_pivot.name = "VuNeedle"
	_needle_pivot.position = Vector3(0.72, 0.385, 0.3225)
	head.add_child(_needle_pivot)
	MachineMesh.box(_needle_pivot, Vector3(0.0, 0.075, 0.0), Vector3(0.0035, 0.15, 0.0025),
		MachineMaterials.pointer(), Vector3.ZERO, "Needle")
	MachineMesh.quad(head, Vector3(0.72, 0.46, 0.3255), Vector2(0.34, 0.21),
		MachineMaterials.glass(), Vector3.ZERO, "VuGlass")
	MachineMesh.label(head, "VU", Vector3(0.72, 0.588, 0.322), 0.0011,
		Color(0.68, 0.66, 0.55), 12)

	var led_colors: Array[Color] = [Color(0.25, 1.0, 0.4), Color(1.0, 0.66, 0.16),
		Color(1.0, 0.16, 0.12)]
	var led_materials: Array[StandardMaterial3D] = []
	for i in 3:
		var led_x := 0.56 + float(i) * 0.16
		MachineMesh.cylinder(head, Vector3(led_x, 0.27, 0.308), 0.019, 0.008,
			dark, Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "LedBezel")
		var material := MachineMaterials.led(led_colors[i])
		led_materials.append(material)
		MachineMesh.cylinder(head, Vector3(led_x, 0.27, 0.314), 0.012, 0.012,
			material, Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "Led")
	_signal_led = led_materials[1]
	_rec_led = led_materials[2]
	MachineMesh.label(head, "PWR    SIG    REC", Vector3(0.72, 0.233, 0.322), 0.0009,
		Color(0.6, 0.58, 0.48), 10)

	MachineMesh.box(head, Vector3(0.72, 0.12, 0.304), Vector3(0.42, 0.11, 0.012),
		MachineMaterials.rubber(), Vector3.ZERO, "SpeakerWell")
	var speaker_slats: Array[Transform3D] = []
	for i in 5:
		speaker_slats.append(Transform3D(Basis.IDENTITY,
			Vector3(0.72, 0.08 + float(i) * 0.02, 0.312)))
	MachineMesh.slats(head, speaker_slats, Vector3(0.36, 0.008, 0.008), dark, "Speaker")

	# Placas de serie.
	MachineMesh.box(head, Vector3(0.72, 0.035, 0.31), Vector3(0.3, 0.045, 0.006),
		MachineMaterials.cream(), Vector3.ZERO, "SerialPlate")
	MachineMesh.label(head, "SN 0117-K", Vector3(0.72, 0.035, 0.314), 0.0009,
		Color(0.14, 0.12, 0.1), 10)
	MachineMesh.end_batch(head)


func _build_deck() -> void:
	var deck := Node3D.new()
	deck.name = "Deck"
	deck.position = Vector3(0.0, 0.0, 0.29)
	deck.rotation.x = DECK_TILT
	add_child(deck)
	MachineMesh.begin_batch(deck)

	var steel := MachineMaterials.steel()

	MachineMesh.box(deck, Vector3.ZERO, Vector3(2.32, 0.075, 0.6),
		MachineMaterials.deck(), Vector3.ZERO, "Slab")
	MachineMesh.box(deck, Vector3(0.0, 0.006, 0.295), Vector3(2.32, 0.045, 0.035),
		steel, Vector3.ZERO, "FrontTrim")
	for side in [-1.0, 1.0]:
		MachineMesh.box(deck, Vector3(float(side) * 1.14, 0.006, 0.0),
			Vector3(0.045, 0.05, 0.6), steel, Vector3.ZERO, "SideTrim")

	# Placa grabada de la estación, tumbada sobre la cubierta.
	MachineMesh.box(deck, Vector3(0.0, 0.042, -0.245), Vector3(0.86, 0.006, 0.07),
		MachineMaterials.cream(), Vector3.ZERO, "DeckPlate")
	MachineMesh.label(deck, "STATION 2  ·  DOWNLINK", Vector3(0.0, 0.047, -0.245),
		0.0012, Color(0.14, 0.12, 0.09), 16, Vector3(-PI * 0.5, 0.0, 0.0))

	# Seis perillas en la cubierta inclinada.
	for i in KNOB_IDS.size():
		var knob := RotaryKnob.new()
		knob.name = "Knob%d" % i
		knob.position = Vector3(-0.85 + float(i) * 0.34, 0.045, 0.09)
		knob.rotation.x = -PI * 0.5
		knob.min_value = 0.0
		knob.max_value = float(KNOB_MAX[i])
		knob.step = float(KNOB_STEPS[i])
		knob.label_text = KNOB_LABELS[i]
		knob.value_suffix = " Hz" if KNOB_IDS[i] == &"frequency" else ""
		# La afinación es la perilla principal; el resto baja de tamaño.
		knob.scale = Vector3.ONE * (1.24 if i == 0 else (1.08 if i == 1 else 0.96))
		deck.add_child(knob)
		knob.value_changed.connect(_on_knob_changed.bind(KNOB_IDS[i]))
		_knobs.append(knob)

	_detector = ToggleSwitch.new()
	_detector.name = "Detector"
	_detector.position = Vector3(-1.0, 0.045, 0.09)
	_detector.rotation.x = -PI * 0.5
	_detector.label_text = "DETECTOR"
	_detector.on = true
	deck.add_child(_detector)
	_detector.toggled.connect(_on_detector_toggled)

	_lever = Lever.new()
	_lever.name = "DownloadLever"
	_lever.position = Vector3(1.0, 0.045, 0.09)
	_lever.rotation.x = -PI * 0.5
	_lever.label_text = "DESCARGA"
	_lever.hold_time = 0.7
	deck.add_child(_lever)
	_lever.pulled.connect(_on_lever_pulled)

	# Conectores de antena en el borde izquierdo de la cubierta.
	for i in 2:
		MachineMesh.cylinder(deck, Vector3(-1.09, 0.04, -0.16 + float(i) * 0.055),
			0.017, 0.03, steel, Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "Bnc")
		MachineMesh.cylinder(deck, Vector3(-1.09, 0.04, -0.16 + float(i) * 0.055),
			0.006, 0.034, MachineMaterials.bakelite(),
			Vector3(PI * 0.5, 0.0, 0.0), 8, -1.0, "BncPin")
	MachineMesh.end_batch(deck)


func _build_dressing() -> void:
	var chassis := get_node_or_null("Chassis") as Node3D
	if chassis == null:
		return
	MachineMesh.begin_batch(chassis)
	var steel := MachineMaterials.steel()

	# Nota pegada con cinta en la puerta.
	MachineMesh.quad(chassis, Vector3(-0.86, -0.62, 0.352), Vector2(0.19, 0.23),
		MachineMaterials.cream(), Vector3(0.0, 0.0, 0.035), "Note")
	MachineMesh.label(chassis, "NO TOCAR\nCALIBRADO\n11/26", Vector3(-0.86, -0.62, 0.355),
		0.0011, Color(0.16, 0.12, 0.1), 14, Vector3(0.0, 0.0, 0.035))
	MachineMesh.quad(chassis, Vector3(-0.86, -0.5, 0.354), Vector2(0.2, 0.035),
		MachineMaterials.rubber(), Vector3(0.0, 0.0, 0.035))

	# Estarcido grande y desgastado en la puerta.
	MachineMesh.label(chassis, "RHEA", Vector3(0.0, -0.52, 0.352), 0.0017,
		Color(0.23, 0.22, 0.18), 52)
	# Junta horizontal de la puerta con dos pestillos.
	MachineMesh.box(chassis, Vector3(0.0, -0.62, 0.352), Vector3(2.0, 0.012, 0.01),
		MachineMaterials.dark_steel(), Vector3.ZERO, "DoorSeam")
	for latch_x in [-0.45, 0.45]:
		MachineMesh.box(chassis, Vector3(float(latch_x), -0.62, 0.36),
			Vector3(0.075, 0.026, 0.016), MachineMaterials.dark_steel(),
			Vector3.ZERO, "Latch")
	# Breaker de la consola a la derecha de la puerta.
	MachineMesh.box(chassis, Vector3(0.86, -0.95, 0.352), Vector3(0.1, 0.14, 0.02),
		MachineMaterials.dark_panel(), Vector3.ZERO, "BreakerPlate")
	MachineMesh.box(chassis, Vector3(0.86, -0.95, 0.368), Vector3(0.022, 0.06, 0.02),
		MachineMaterials.warning(), Vector3(0.0, 0.0, 0.3), "BreakerLever")

	# Chapa de aviso junto al borde derecho.
	MachineMesh.box(chassis, Vector3(0.68, -0.17, 0.348), Vector3(0.19, 0.07, 0.005),
		MachineMaterials.warning(), Vector3.ZERO, "WarningPlate")
	MachineMesh.label(chassis, "ALTO VOLTAJE", Vector3(0.68, -0.17, 0.352), 0.0008,
		Color(0.06, 0.06, 0.05), 9)

	# Cable de red que cuelga por el costado y baja al suelo.
	MachineMesh.tube(chassis, [
		Vector3(1.19, 0.02, 0.45), Vector3(1.31, -0.14, 0.5),
		Vector3(1.35, -0.45, 0.45), Vector3(1.34, -0.78, 0.36),
		Vector3(1.3, -1.05, 0.28), Vector3(1.24, -1.22, 0.18),
	], 0.014, MachineMaterials.rubber(), 7, "PowerCable")
	MachineMesh.tube(chassis, [
		Vector3(-0.98, 0.05, 0.36), Vector3(-1.07, -0.16, 0.4),
		Vector3(-1.19, -0.52, 0.32), Vector3(-1.23, -0.94, 0.22),
		Vector3(-1.22, -1.2, 0.12),
	], 0.009, MachineMaterials.rubber(), 6, "SignalCable")
	MachineMesh.cylinder(chassis, Vector3(1.19, 0.03, 0.45), 0.02, 0.05,
		MachineMaterials.steel(), Vector3(PI * 0.5, 0.0, 0.0), 12, -1.0, "CableGland")

	# Luz propia del instrumento: el CRT tiñe de verde el frente.
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0.0, 0.3, 0.9)
	glow.light_color = Color(0.62, 1.0, 0.8)
	glow.light_energy = 0.55
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	add_child(glow)
	MachineMesh.end_batch(chassis)


func _build_lamp() -> void:
	# Lámpara de cuello de ganso: ilumina la cubierta y rompe la simetría.
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	add_child(lamp)
	MachineMesh.begin_batch(lamp)

	var steel := MachineMaterials.dark_steel()
	MachineMesh.box(lamp, Vector3(-1.0, 0.69, 0.06), Vector3(0.16, 0.045, 0.11),
		steel, Vector3.ZERO, "Clamp")
	MachineMesh.cylinder(lamp, Vector3(-1.0, 0.66, 0.06), 0.018, 0.08, steel,
		Vector3.ZERO, 10, -1.0, "ClampScrew")
	MachineMesh.tube(lamp, [
		Vector3(-1.0, 0.71, 0.06), Vector3(-1.03, 0.88, 0.12),
		Vector3(-0.99, 1.03, 0.24), Vector3(-0.86, 1.1, 0.4),
		Vector3(-0.69, 1.04, 0.54), Vector3(-0.61, 0.95, 0.61),
	], 0.015, MachineMaterials.steel(), 8, "Gooseneck")
	MachineMesh.cylinder(lamp, Vector3(-0.6, 0.87, 0.62), 0.11, 0.13,
		MachineMaterials.panel(), Vector3(PI * 0.94, 0.0, 0.0), 16, 0.028, "Shade")
	var bulb := MachineMaterials.led(Color(1.0, 0.83, 0.55))
	bulb.emission_energy_multiplier = 0.9
	MachineMesh.sphere(lamp, Vector3(-0.6, 0.815, 0.63), 0.033, bulb, "Bulb")

	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.position = Vector3(-0.58, 0.76, 0.66)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 1.9
	light.omni_range = 3.2
	light.shadow_enabled = false
	lamp.add_child(light)
	MachineMesh.end_batch(lamp)


func _build_screen() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "ScreenViewport"
	_viewport.size = SCREEN_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_screen = CrtScreen.new()
	_screen.name = "Crt"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_screen_text("RHEA  RX-4   //   DOWNLINK TERMINAL", Vector2(28.0, 16.0),
		Vector2(460.0, 22.0), 14, Color(0.92, 0.68, 0.32))
	_screen_text("BUF 12 s", Vector2(500.0, 16.0), Vector2(112.0, 22.0), 14,
		Color(0.45, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)

	_title = _screen_text("SIN PORTADORA", Vector2(28.0, 168.0), Vector2(584.0, 34.0),
		26, Color(0.62, 1.0, 0.74))
	_tuning = _screen_text("", Vector2(28.0, 204.0), Vector2(584.0, 24.0), 16,
		Color(0.55, 0.88, 0.66))
	_alignment = _screen_text("", Vector2(28.0, 232.0), Vector2(584.0, 24.0), 16,
		Color(0.55, 0.88, 0.66))
	_status = _screen_text("", Vector2(28.0, 260.0), Vector2(584.0, 24.0), 15,
		Color(0.72, 0.84, 0.7))
	_progress_text = _screen_text("EN ESPERA", Vector2(300.0, 294.0), Vector2(312.0, 24.0),
		16, Color(0.62, 1.0, 0.74))
	_footer = _screen_text("RHEA INSTRUMENTS  ·  PHOSPHOR P1  ·  640×360",
		Vector2(28.0, 332.0), Vector2(584.0, 18.0), 11, Color(0.36, 0.62, 0.46))

	var screen := MachineMesh.quad(self, Vector3(-0.34, 0.335, 0.3115), Vector2(0.84, 0.4725),
		_screen_material_for_viewport(), Vector3.ZERO, "CrtScreen")
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MachineMesh.quad(self, Vector3(-0.34, 0.335, 0.318), Vector2(0.85, 0.48),
		MachineMaterials.glass(), Vector3.ZERO, "CrtGlass")


func _screen_material_for_viewport() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.emission_enabled = true
	material.emission_texture = _viewport.get_texture()
	material.emission_energy_multiplier = 0.9
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_screen_material = material
	return material


func _screen_text(text: String, pos: Vector2, box: Vector2, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = box
	label.horizontal_alignment = align
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.2, 0.7, 0.4, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_screen.add_child(label)
	return label


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	_add_collision_box(body, Vector3(0.0, -0.58, 0.0), Vector3(2.45, 1.12, 0.68))
	_add_collision_box(body, Vector3(0.0, 0.28, 0.0), Vector3(2.06, 0.66, 0.6))
	var deck_shape := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(2.32, 0.1, 0.6)
	deck_shape.shape = deck_box
	deck_shape.position = Vector3(0.0, 0.07, 0.4)
	deck_shape.rotation.x = DECK_TILT
	body.add_child(deck_shape)


func _add_collision_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)


# --- Estado -------------------------------------------------------------------

func _on_knob_changed(value: float, knob_id: StringName) -> void:
	if _system == null:
		return
	_system.set_knob(knob_id, roundi(value))
	_refresh()


func _on_detector_toggled(value: bool) -> void:
	_detector_on = value
	_refresh()


func _on_lever_pulled(active: bool) -> void:
	if _system == null:
		return
	if active:
		if not _system.start_download():
			_lever.set_on(false)
	else:
		_system.stop_download()
	_refresh()


func _on_scan_completed(_found: bool, _message: String) -> void:
	sync_knobs()


func _on_download_progress(value: float) -> void:
	if _screen != null:
		_screen.progress = value
	_refresh_status()


func _on_download_completed(_copy: Dictionary) -> void:
	if _lever != null:
		_lever.set_on(false)
	_refresh()


func _on_error(message: String) -> void:
	if _status != null:
		_status.text = message
	if _lever != null:
		_lever.set_on(false)


func _refresh() -> void:
	if _system == null or _title == null:
		return
	var def := _system.selected_def
	if def == null:
		_title.text = "SIN PORTADORA"
		_tuning.text = "AJUSTA EL PANEL 1 Y LANZA UN PING"
		_alignment.text = ""
		_status.text = ""
		_progress_text.text = "EN ESPERA"
		_screen.signal_level = 0.0
		return
	_title.text = def.display_name.to_upper()
	_tuning.text = "FREC %04d Hz    POL %s    AGC %02d" % [
		_system.frequency, _polarity_text(_system.polarity), _system.gain,
	]
	_alignment.text = "LOCK %3d%%    DETECTOR %s    ANCHO %02d" % [
		roundi(_system.alignment() * 100.0),
		"ON" if _detector_on else "OFF",
		_system.bandwidth,
	]
	_status.text = _system.condition_text(def)
	_progress_text.text = "%d%%" % roundi(_system.download_ratio() * 100.0)


func _refresh_status() -> void:
	if _system == null or _status == null:
		return
	if _system.is_downloading():
		_status.text = "DESCARGANDO  %d%%" % roundi(_system.download_ratio() * 100.0)
		_progress_text.text = "%d%%" % roundi(_system.download_ratio() * 100.0)
	_footer.text = "RHEA INSTRUMENTS  ·  PHOSPHOR P1  ·  LN %s" % _polarity_text(_system.polarity)


func _animate_needle(delta: float) -> void:
	if _needle_pivot == null or _system == null:
		return
	var target := _system.alignment()
	if _system.is_downloading():
		target = lerpf(target, 0.55 + 0.35 * sin(_time * 9.0), 0.35)
	_needle_value = lerpf(_needle_value, clampf(target, 0.0, 1.0), clampf(delta * 9.0, 0.0, 1.0))
	_needle_pivot.rotation.z = lerpf(-0.62, 0.62, _needle_value)


func _animate_leds() -> void:
	if _signal_led == null or _rec_led == null:
		return
	var locked := _detector_on and _system != null and _system.alignment() > 0.12
	_signal_led.emission_energy_multiplier = 2.6 if locked else 0.15
	_signal_led.albedo_color = Color(0.55, 0.25, 0.05) if not locked else Color(0.5, 0.32, 0.06)
	var recording := _system != null and _system.is_downloading()
	var blink := 2.8 if (recording and fmod(_time, 0.7) < 0.35) else 0.12
	_rec_led.emission_energy_multiplier = blink
	_rec_led.albedo_color = Color(0.5, 0.08, 0.06) if blink < 0.5 else Color(0.45, 0.1, 0.08)


func _polarity_text(value: int) -> String:
	return String(["VERT", "MIXTA", "HORIZ"][clampi(value, 0, 2)])
