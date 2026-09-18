# game/audio/chaos_audio.gd
# Generates procedural ambient drones — emission-only audio like the visuals
extends Node3D

@export var master_volume: float = 0.3
@export var world_seed: int = 0

var _generators: Array[AudioStreamGeneratorPlayback] = []
var _streams: Array[AudioStreamGenerator] = []
var _phase: Array[float] = []
var _freqs: Array[float] = []
var _rng: EntroRNG = EntroRNG.new()
var _time: float = 0.0

const BASE_FREQS: Array[float] = [55.0, 82.5, 110.0, 165.0, 220.0]
const DRONE_COUNT: int = 5
const MIX_RATE: int = 22050

func _ready() -> void:
	_rng.initialize(world_seed)
	_create_drones()

func _create_drones() -> void:
	for i in range(DRONE_COUNT):
		var player = AudioStreamPlayer.new()
		player.name = "Drone_%d" % i

		var stream = AudioStreamGenerator.new()
		stream.mix_rate = MIX_RATE
		stream.buffer_length = 2.0

		player.stream = stream
		player.volume_db = linear_to_db(master_volume * _rng.randf_range(0.3, 0.8))
		add_child(player)
		player.play()

		_streams.append(stream)
		_generators.append(player.get_stream_playback() as AudioStreamGeneratorPlayback)
		_phase.append(0.0)
		_freqs.append(BASE_FREQS[i % BASE_FREQS.size()])

func _process(delta: float) -> void:
	_time += delta

	for i in range(_generators.size()):
		var playback = _generators[i]
		if playback == null:
			continue

		var frames_available = playback.get_frames_available()
		if frames_available <= 0:
			continue

		var freq = _freqs[i]
		var batch = PackedVector2Array()
		batch.resize(frames_available)

		for f in range(frames_available):
			var t = _time + float(f) / float(MIX_RATE)

			var val = 0.0
			val += sin(TAU * freq * t) * 0.35
			val += sin(TAU * freq * 2.01 * t) * 0.15
			val += sin(TAU * freq * 0.498 * t) * 0.12

			val *= 0.7 + 0.3 * sin(TAU * 0.08 * t + float(i) * 1.3)

			var crushed = floorf(val * 12.0) / 12.0
			val = lerp(val, crushed, 0.15)

			val = clampf(val, -1.0, 1.0)
			batch[f] = Vector2(val, val)

		playback.push_buffer(batch)

func get_drone_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for i in range(DRONE_COUNT):
		var angle = float(i) / float(DRONE_COUNT) * TAU
		var dist = 8.0 + float(i) * 3.0
		positions.append(Vector3(cos(angle) * dist, 0.0, sin(angle) * dist))
	return positions
