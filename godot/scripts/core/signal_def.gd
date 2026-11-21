class_name SignalDef
extends Resource
## Datos de una señal. El catálogo vive en data/signals/catalog.json.

@export var id: StringName = &""
@export var display_name: String = "Señal"
@export var condition: int = 0
@export var azimuth: float = 0.0
@export var elevation: float = 0.0
@export var frequency: int = 500
@export var polarity: int = 1
@export var quality: float = 0.8
@export var base_value: int = 100
@export var image_seed: int = 1
@export var audio_tone: float = 220.0
@export var decode_target: float = 0.5
@export var description: String = ""


static func from_dict(data: Dictionary) -> SignalDef:
	var def := SignalDef.new()
	def.id = StringName(str(data.get("id", "")))
	def.display_name = str(data.get("display_name", "Señal"))
	def.condition = int(data.get("condition", 0))
	def.azimuth = float(data.get("azimuth", 0.0))
	def.elevation = float(data.get("elevation", 0.0))
	def.frequency = int(data.get("frequency", 500))
	def.polarity = int(data.get("polarity", 1))
	def.quality = float(data.get("quality", 0.8))
	def.base_value = int(data.get("base_value", 100))
	def.image_seed = int(data.get("image_seed", 1))
	def.audio_tone = float(data.get("audio_tone", 220.0))
	def.decode_target = float(data.get("decode_target", 0.5))
	def.description = str(data.get("description", ""))
	return def
