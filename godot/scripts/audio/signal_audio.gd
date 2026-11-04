class_name SignalAudio
extends Node
## Reproducción sintetizada de una señal. Sin archivos de audio.

const MIX_RATE := 22050.0
const DEFAULT_DURATION := 4.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _playing := false
var _tone := 220.0
var _elapsed := 0.0
var _duration := DEFAULT_DURATION


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Stream"
	_player.volume_db = -14.0
	add_child(_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25
	_player.stream = generator


func play(tone: float, duration: float = DEFAULT_DURATION) -> void:
	if _player == null:
		return
	_tone = tone
	_elapsed = 0.0
	_duration = duration
	_playing = true
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func stop() -> void:
	_playing = false
	_elapsed = 0.0
	_playback = null
	if _player != null:
		_player.stop()


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		stop()
		return
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for i in frames:
		var t := _elapsed + float(i) / MIX_RATE
		var sample := sin(TAU * _tone * t) * 0.22
		sample += sin(TAU * _tone * 2.01 * t) * 0.08
		sample += sin(TAU * 7.0 * t) * 0.02
		_playback.push_frame(Vector2(sample, sample))
