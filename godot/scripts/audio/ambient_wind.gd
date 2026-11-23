class_name AmbientWind
extends Node
## Viento alpino ambiental sintetizado en tiempo real (0 draw calls, sin archivos externos).
## Se amortigua al entrar en la base según la cámara activa para respetar co-op online.

const MIX_RATE := 22050.0
const BUFFER_SECONDS := 0.25
const MAX_FRAMES_PER_TICK := 1024

var enabled: bool = true

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sample_time: float = 0.0
var _muffle: float = 1.0
var _altitude_boost: float = 0.0
var _current_gust: float = 0.4
var _indoors: bool = true

var _lp1_l: float = 0.0
var _lp2_l: float = 0.0
var _lp1_r: float = 0.0
var _lp2_r: float = 0.0
var _howl_low: float = 0.0
var _howl_band: float = 0.0


func _ready() -> void:
	_rng.seed = 19831109
	_player = AudioStreamPlayer.new()
	_player.name = "WindStream"
	_player.volume_db = -13.0
	add_child(_player)

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_SECONDS
	_player.stream = generator

	if enabled:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func set_enabled(value: bool) -> void:
	enabled = value
	if _player == null:
		return
	if enabled:
		if not _player.playing:
			_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	else:
		_player.stop()
		_playback = null


func is_playing() -> bool:
	return enabled and _player != null and _player.playing


func current_muffle() -> float:
	return _muffle


func current_gust() -> float:
	return _current_gust


func is_camera_indoors() -> bool:
	return _indoors


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var target_muffle := 0.0
	var target_altitude := 0.0
	if cam != null:
		var pos := cam.global_position
		_indoors = BaseLayout.is_indoors(pos)
		if _indoors:
			target_muffle = 1.0 if pos.y < -0.5 else 0.78
		else:
			target_altitude = clampf(pos.y / 55.0, 0.0, 0.32)
	_muffle = lerpf(_muffle, target_muffle, clampf(delta * 3.5, 0.0, 1.0))
	_altitude_boost = lerpf(_altitude_boost, target_altitude, clampf(delta * 2.5, 0.0, 1.0))

	if not enabled or _playback == null:
		return
	var frames := mini(_playback.get_frames_available(), MAX_FRAMES_PER_TICK)
	if frames <= 0:
		return

	var dt := 1.0 / MIX_RATE
	for i in frames:
		_sample_time += dt
		var gust := 0.44 + 0.28 * sin(_sample_time * 0.21) \
			+ 0.17 * sin(_sample_time * 0.53 + 1.3) \
			+ 0.11 * sin(_sample_time * 1.17 + 2.7)
		_current_gust = clampf(gust, 0.12, 1.0)

		var cutoff_hz := lerpf(150.0 + _current_gust * 290.0, 95.0 + _current_gust * 55.0, _muffle)
		var alpha := clampf(TAU * cutoff_hz * dt / (1.0 + TAU * cutoff_hz * dt), 0.005, 0.45)

		var n_l := _rng.randf_range(-1.0, 1.0)
		var n_r := _rng.randf_range(-1.0, 1.0)
		_lp1_l += alpha * (n_l - _lp1_l)
		_lp2_l += alpha * (_lp1_l - _lp2_l)
		_lp1_r += alpha * (n_r - _lp1_r)
		_lp2_r += alpha * (_lp1_r - _lp2_r)

		# Silbido agudo sutil al cruzar las ráfagas por crestas y ventanales.
		var howl_hz := 270.0 + _current_gust * 190.0 + 35.0 * sin(_sample_time * 0.37)
		var f := clampf(2.0 * sin(PI * howl_hz * dt), 0.02, 0.22)
		var q := 0.18
		var mono_noise := (n_l + n_r) * 0.5
		var high := mono_noise - _howl_low - q * _howl_band
		_howl_band += f * high
		_howl_low += f * _howl_band

		var gain := lerpf(0.36 + _altitude_boost * 0.22, 0.085, _muffle) * (0.45 + 0.75 * _current_gust)
		var howl_mix := lerpf(0.055, 0.010, _muffle) * maxf(0.0, _current_gust - 0.35)
		var out_l := clampf(_lp2_l * gain + _howl_band * howl_mix, -0.45, 0.45)
		var out_r := clampf(_lp2_r * gain + _howl_band * howl_mix * 0.92, -0.45, 0.45)
		_playback.push_frame(Vector2(out_l, out_r))
