class_name SignalSystem
extends RefCounted
## Cadena de señal: Coordinates → Download → Playback → Processing → Disco.
## Lógica pura y determinista: no conoce escenas, nodos ni UI.

signal scan_completed(found: bool, message: String)
signal download_progress(value: float)
signal download_completed(copy: Dictionary)
signal playback_changed(playing: bool)
signal copy_updated(copy: Dictionary)
signal disk_exported(index: int)
signal credits_changed(value: int)
signal error_raised(message: String)

enum Condition { OK, WEAK, SATELLITE_DOWN, STORM, INVALID }

const SCAN_TOLERANCE := 12.0
const DOWNLOAD_MIN_ALIGNMENT := 0.55
const PROCESS_THRESHOLDS := [0.5, 0.65, 0.78]
const CONDITION_LABELS := [
	"Portadora estable",
	"Señal débil: la calidad no pasará del 45%",
	"Satélite caído: no hay enlace",
	"Tormenta: la descarga pierde calidad",
	"Objeto no válido: no es una señal",
]

var azimuth: float = 0.0
var elevation: float = 0.0
var frequency: int = 500
var polarity: int = 1
var selected_def: SignalDef = null
var decode_tuning: float = 0.0
var decode_sensitivity: float = 2.5
var decode_ready_stability: float = 0.78
var downloads: Array[Dictionary] = []
var disks: Array[Dictionary] = []
var credits: int = 0

var _catalog: Array[SignalDef] = []
var _downloading: bool = false
var _progress: float = 0.0
var _duration: float = 4.0
var _playing: int = -1
var _export_counts: Dictionary = {}
var _status: String = ""


static func load_catalog(path: String) -> Array[SignalDef]:
	var out: Array[SignalDef] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el catálogo de señales: " + path)
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("Catálogo de señales inválido: " + path)
		return out
	for entry in parsed:
		if entry is Dictionary:
			out.append(SignalDef.from_dict(entry))
	return out


func setup(catalog: Array[SignalDef]) -> void:
	_catalog.clear()
	for def in catalog:
		_catalog.append(def)
	downloads.clear()
	disks.clear()
	_export_counts.clear()
	credits = 0
	playing_stop()


func catalog_size() -> int:
	return _catalog.size()


func catalog_def(index: int) -> SignalDef:
	return _catalog[index] if index >= 0 and index < _catalog.size() else null


func select_by_id(id: StringName) -> SignalDef:
	for def in _catalog:
		if def.id == id:
			selected_def = def
			_status = "%s — %s" % [def.display_name, condition_text(def)]
			return def
	return null


func select_def(def: SignalDef) -> void:
	selected_def = def
	if def != null:
		_status = "%s — %s" % [def.display_name, condition_text(def)]


func status() -> String:
	return _status


func condition_text(def: SignalDef) -> String:
	if def == null:
		return "Sin portadora"
	return String(CONDITION_LABELS[clampi(def.condition, 0, CONDITION_LABELS.size() - 1)])


## Rumbos de los tres radares: pistas hacia el catálogo, no una solución exacta.
func radar_bearing(index: int) -> float:
	if _catalog.is_empty():
		return 0.0
	var offsets := [3.0, -4.0, 2.0]
	var def := _catalog[(index * 2) % _catalog.size()]
	return fposmod(def.azimuth + float(offsets[clampi(index, 0, 2)]), 360.0)


func set_azimuth(value: float) -> void:
	azimuth = fposmod(value, 360.0)


func set_elevation(value: float) -> void:
	elevation = clampf(value, 0.0, 80.0)


func set_knob(knob: StringName, value: int) -> void:
	match knob:
		&"frequency":
			frequency = clampi(value, 0, 1000)
		&"polarity":
			polarity = clampi(value, 0, 2)


func knob(id: StringName) -> int:
	match id:
		&"frequency":
			return frequency
		&"polarity":
			return polarity
	return 0


func nudge_knob(knob: StringName, delta: int) -> void:
	set_knob(knob, knob(knob) + delta)


## 1.0 = frecuencia y polaridad exactas; 0.0 = nada alineado.
## Solo dos controles, como el panel original: el resto de la cadena es del aparato.
func alignment() -> float:
	if selected_def == null:
		return 0.0
	var def := selected_def
	var error := 0.0
	error += absf(float(frequency - def.frequency)) / 1000.0 * 0.7
	error += absf(float(polarity - def.polarity)) / 2.0 * 0.3
	return clampf(1.0 - error, 0.0, 1.0)


func configure_balance(balance: GameBalance) -> void:
	if balance == null:
		return
	decode_sensitivity = balance.decode_sensitivity
	decode_ready_stability = balance.decode_stability_threshold


func set_decode_tuning(value: float) -> void:
	decode_tuning = clampf(value, 0.0, 1.0)


## Estabilidad de la onda en tiempo real: 1.0 en la fase de la copia que se procesará.
## Sin copia guardada no hay nada que decodificar y la traza queda en ruido.
func decode_stability() -> float:
	var index := last_saved_index()
	if index < 0:
		return 0.0
	var def: SignalDef = downloads[index]["def"]
	var error := absf(decode_tuning - def.decode_target) * decode_sensitivity
	return clampf(1.0 - error, 0.0, 1.0)


func last_saved_index() -> int:
	for i in range(downloads.size() - 1, -1, -1):
		if bool(downloads[i]["saved"]):
			return i
	return -1


## Consume la última copia guardada si la onda ya está lo bastante estable.
func confirm_decode() -> bool:
	var index := last_saved_index()
	if index < 0:
		return _fail("NO HAY COPIA GUARDADA EN LA BASE DE DATOS")
	if decode_stability() < decode_ready_stability:
		return _fail("FASE INESTABLE · AJUSTA LA ONDA")
	if copy_level(index) >= 3:
		return _fail("COPIA YA PROCESADA AL NIVEL 3")
	return process_copy(index, copy_level(index) + 1)


## Busca la portadora más cercana al azimut/elevación actuales.
func scan() -> Dictionary:
	if _catalog.is_empty():
		return {"found": false, "message": "Catálogo vacío"}
	var best: SignalDef = null
	var best_distance := INF
	for def in _catalog:
		var bearing_error := absf(rad_to_deg(angle_difference(
			deg_to_rad(azimuth), deg_to_rad(def.azimuth))))
		var vertical_error := absf(elevation - def.elevation)
		var distance := bearing_error + vertical_error * 1.5
		if distance < best_distance:
			best_distance = distance
			best = def
	if best == null or best_distance > SCAN_TOLERANCE:
		selected_def = null
		_status = "Sin portadora: corrige azimut y elevación"
		scan_completed.emit(false, _status)
		return {"found": false, "message": _status}
	selected_def = best
	_status = "%s — %s" % [best.display_name, condition_text(best)]
	scan_completed.emit(true, _status)
	return {"found": true, "message": _status}


func is_downloading() -> bool:
	return _downloading


func download_ratio() -> float:
	return _progress if _downloading else 0.0


func start_download() -> bool:
	if selected_def == null:
		return _fail("Sin portadora: usa Coordenadas primero")
	if _downloading:
		return false
	match selected_def.condition:
		Condition.SATELLITE_DOWN:
			return _fail("Satélite caído: no hay enlace")
		Condition.INVALID:
			return _fail("Objeto no válido: no es una señal")
	if alignment() < DOWNLOAD_MIN_ALIGNMENT:
		return _fail("Alinea las perillas (mínimo 55%)")
	_downloading = true
	_progress = 0.0
	_duration = lerpf(6.0, 2.5, alignment())
	_status = "Descargando %s…" % selected_def.display_name
	download_progress.emit(0.0)
	return true


func stop_download() -> void:
	if not _downloading:
		return
	_downloading = false
	_progress = 0.0
	_status = "Descarga cancelada"
	download_progress.emit(0.0)


func tick(delta: float) -> void:
	if not _downloading or delta <= 0.0:
		return
	_progress = minf(1.0, _progress + delta / _duration)
	download_progress.emit(_progress)
	if _progress < 1.0:
		return
	_complete_download()


func download_count() -> int:
	return downloads.size()


func quality_of(index: int) -> float:
	if index < 0 or index >= downloads.size():
		return 0.0
	return float(downloads[index]["quality"])


func copy_is_saved(index: int) -> bool:
	return index >= 0 and index < downloads.size() and bool(downloads[index]["saved"])


func play_copy(index: int) -> bool:
	if index < 0 or index >= downloads.size():
		return false
	_playing = index
	playback_changed.emit(true)
	return true


func playing_index() -> int:
	return _playing


func is_playing() -> bool:
	return _playing >= 0


func stop_playback() -> void:
	playing_stop()


func playing_stop() -> void:
	_playing = -1
	playback_changed.emit(false)


func save_copy(index: int) -> bool:
	if index < 0 or index >= downloads.size():
		return false
	var copy: Dictionary = downloads[index]
	if bool(copy["saved"]):
		return false
	copy["saved"] = true
	copy_updated.emit(copy)
	return true


func saved_count() -> int:
	var total := 0
	for copy in downloads:
		if bool(copy["saved"]):
			total += 1
	return total


## Procesa un nivel (1–3) de una copia guardada. Devuelve si tuvo éxito.
func process_copy(index: int, level: int) -> bool:
	if index < 0 or index >= downloads.size() or level < 1 or level > 3:
		return false
	var copy: Dictionary = downloads[index]
	if not bool(copy["saved"]):
		return _fail("Guarda la señal en la base de datos antes de procesarla")
	if int(copy["level"]) != level - 1:
		return _fail("Procesa los niveles en orden")
	var threshold := float(PROCESS_THRESHOLDS[level - 1])
	if float(copy["quality"]) < threshold:
		return _fail("Calidad insuficiente para el nivel %d (%.0f%%)" % [level, threshold * 100.0])
	copy["level"] = level
	copy_updated.emit(copy)
	_status = "%s procesada a nivel %d" % [copy["def"].display_name, level]
	return true


func copy_level(index: int) -> int:
	if index < 0 or index >= downloads.size():
		return 0
	return int(downloads[index]["level"])


func copy_value(index: int) -> int:
	if index < 0 or index >= downloads.size():
		return 0
	return _value_of(downloads[index])


func export_copy(index: int) -> Dictionary:
	if index < 0 or index >= downloads.size():
		return {}
	var copy: Dictionary = downloads[index]
	if int(copy["level"]) < 1:
		_status = "PROCESA LA COPIA ANTES DE EXPORTARLA A DISCO"
		error_raised.emit(_status)
		return {}
	var key: StringName = copy["id"]
	var previous := int(_export_counts.get(key, 0))
	_export_counts[key] = previous + 1
	var disk := {
		"copy_index": index,
		"def_id": key,
		"value": _value_of(copy) if previous == 0 else 0,
		"copy": previous > 0,
		"sold": false,
	}
	disks.append(disk)
	_status = "Disco exportado: %s (%d créditos)" % [copy["def"].display_name, int(disk["value"])]
	disk_exported.emit(disks.size() - 1)
	return disk


func disk_count() -> int:
	return disks.size()


func disk_value(index: int) -> int:
	if index < 0 or index >= disks.size():
		return 0
	return int(disks[index]["value"])


func sell_disk(index: int) -> int:
	if index < 0 or index >= disks.size():
		return 0
	var disk: Dictionary = disks[index]
	if bool(disk["sold"]):
		return 0
	disk["sold"] = true
	var earned := int(disk["value"])
	set_credits(credits + earned)
	_status = "Disco vendido: %d créditos" % earned
	return earned


func unsold_disk_index() -> int:
	for i in range(disks.size() - 1, -1, -1):
		if not bool(disks[i]["sold"]):
			return i
	return -1


func set_credits(value: int) -> void:
	credits = maxi(0, value)
	credits_changed.emit(credits)


func add_credits(amount: int) -> void:
	set_credits(credits + amount)


func _complete_download() -> void:
	var def := selected_def
	_downloading = false
	if def == null:
		return
	var quality := clampf(alignment() * def.quality, 0.0, 1.0)
	match def.condition:
		Condition.WEAK:
			quality = minf(quality, 0.45)
		Condition.STORM:
			quality *= 0.6
	var copy := {
		"def": def,
		"id": def.id,
		"quality": quality,
		"level": 0,
		"saved": false,
	}
	downloads.append(copy)
	_progress = 1.0
	_status = "Descarga completa: %s (%.0f%%)" % [def.display_name, quality * 100.0]
	download_completed.emit(copy)


func _value_of(copy: Dictionary) -> int:
	var def: SignalDef = copy["def"]
	var quality := float(copy["quality"])
	var level := int(copy["level"])
	return roundi(float(def.base_value) * (0.5 + quality) * (1.0 + 0.6 * level))


func _fail(message: String) -> bool:
	_status = message
	error_raised.emit(message)
	return false
