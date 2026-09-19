# game/audio/chaos_audio.gd
# Ported from chaos_shorts_hell.c — chaotic procedural audio
# 5 sound types, 3 drones, distortion, bitcrush, filters, scream
extends Node

@export var master_volume: float = 0.35
@export var world_seed: int = 0
## Use the seed chosen by GameManager instead of the inspector value.
@export var use_game_seed: bool = true

const SR: int = 22050
const MIX_RATE: int = 22050
const BUFFER_LEN: float = 2.0
## Frames generated per tick — caps the per-frame cost of the sample generator.
const MAX_FRAMES_PER_TICK: int = 4096
## Scream oscillator ramp rate (kept from the original C port).
const SCREAM_RATE: float = 1600.0
## Glitches are rolled once every N samples instead of on every sample.
const GLITCH_CHECK_MASK: int = 63

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng: EntroRNG = EntroRNG.new()
var _sample_pos: int = 0

# Audio state (ported from C)
var _drone_phase1: int = 0
var _drone_phase2: int = 0
var _drone_phase3: int = 0
var _lp_state: float = 0.0
var _hp_state: float = 0.0
var _scream_phase: float = 0.0
var _scream_env: float = 0.0
var _bitcrush_hold: float = 0.0
var _bitcrush_count: int = 0
var _step_num: int = -1

# Params (randomized per scene)
var _bpm: float = 80.0
var _samples_per_step: int = 0
var _distortion: float = 0.5
var _bitcrush: float = 0.3
var _highpass: float = 0.1
var _lowpass: float = 0.3
var _noise_mix: float = 0.4
var _drone_mix: float = 0.6
var _scream_mix: float = 0.2
var _drone_freq1: float = 44.0
var _drone_freq2: float = 66.0
var _drone_freq3: float = 33.0
var _audio_type: int = 0

func _ready() -> void:
	if use_game_seed and GameManager != null:
		world_seed = GameManager.current_seed
	_rng.initialize(world_seed)
	_randomize_params()
	_setup_player()

func _setup_player() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "ChaosDrone"

	var stream = AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LEN

	_player.stream = stream
	_player.volume_db = linear_to_db(master_volume)
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func _randomize_params() -> void:
	_audio_type = _rng.randi_range(0, 4)
	_bpm = 20.0 + _rng.randf_range(0.0, 1.0) * 250.0
	_samples_per_step = int((SR * 60.0) / _bpm)
	_samples_per_step = clampi(_samples_per_step, 32, 8192)

	_distortion = _rng.randf_range(0.0, 1.5)
	_bitcrush = _rng.randf_range(0.0, 1.0)
	_highpass = _rng.randf_range(0.0, 0.3)
	_lowpass = _rng.randf_range(0.0, 0.8)
	_noise_mix = _rng.randf_range(0.0, 1.0)
	_drone_mix = _rng.randf_range(0.0, 1.0)
	_scream_mix = _rng.randf_range(0.0, 1.0)

	var base_freq: float = 10.0 + _rng.randf_range(0.0, 1.0) * 200.0
	_drone_freq1 = base_freq * (0.1 + _rng.randf_range(0.0, 1.0) * 3.0)
	_drone_freq2 = base_freq * (0.1 + _rng.randf_range(0.0, 1.0) * 4.0)
	_drone_freq3 = base_freq * (0.1 + _rng.randf_range(0.0, 1.0) * 2.5)

	_drone_phase1 = _rng.randi_range(0, 2147483647)
	_drone_phase2 = _rng.randi_range(0, 2147483647)
	_drone_phase3 = _rng.randi_range(0, 2147483647)

func _process(_delta: float) -> void:
	if _playback == null:
		return

	var frames: int = mini(_playback.get_frames_available(), MAX_FRAMES_PER_TICK)
	if frames <= 0:
		return

	var batch = PackedVector2Array()
	batch.resize(frames)

	for i in range(frames):
		var sample = _generate_sample()
		batch[i] = Vector2(sample, sample)

	_playback.push_buffer(batch)

func _generate_sample() -> float:
	# Step tracking (for scream triggers)
	var cur_step: int = int(float(_sample_pos) / float(_samples_per_step))
	if cur_step != _step_num:
		_step_num = cur_step
		if _rng.randf_range(0.0, 1.0) < 0.2:
			_scream_env = 0.5 + _rng.randf_range(0.0, 1.0) * 0.8
			_scream_phase = float(_rng.randi_range(0, 1000))

	# White noise
	var ns: int = world_seed ^ (_sample_pos * 7)
	var wn: float = float(((ns * 2654435761) >> 8) & 16777215) / 16777216.0 * 2.0 - 1.0

	# Lowpass / Highpass filters
	_lp_state += _lowpass * (wn * 0.5 - _lp_state)
	_hp_state += _highpass * (wn - _hp_state)

	# 3 drone oscillators (saw, tri, square)
	_drone_phase1 = (_drone_phase1 + _hz_to_inc(_drone_freq1)) & 2147483647
	_drone_phase2 = (_drone_phase2 + _hz_to_inc(_drone_freq2)) & 2147483647
	_drone_phase3 = (_drone_phase3 + _hz_to_inc(_drone_freq3)) & 2147483647

	var d1: float = _saw_phase(_drone_phase1)
	var d2: float = _tri_phase(_drone_phase2)
	var d3: float = _square_phase(_drone_phase3) * 0.5

	var drone: float = d1 + d2 + d3

	# Distortion
	var dist: float = drone * (1.0 + _distortion * 4.0 * (0.5 + 0.5 * sin(float(_sample_pos) * 0.0001)))
	dist = dist / (1.0 + absf(dist) * _distortion)

	# Scream
	_scream_phase += SCREAM_RATE
	var scream: float = sin(_scream_phase * 0.003) * _scream_env
	_scream_env *= 0.97
	if _scream_env < 0.001:
		_scream_env = 0.0

	# Mix
	var s: float = _noise_mix * wn + _drone_mix * dist + _scream_mix * scream
	s += _noise_mix * 0.3 * _hp_state
	s += _noise_mix * 0.2 * _lp_state

	# Bitcrush
	if _bitcrush > 0.1:
		var shift: int = int(_bitcrush * 14.0)
		var hold: int = 1 + int(_bitcrush * 50.0)
		if _bitcrush_count <= 0:
			_bitcrush_hold = s
			_bitcrush_count = hold
		else:
			s = _bitcrush_hold
			_bitcrush_count -= 1
		var q: int = int(s * 32767.0)
		q = (q >> shift) << shift
		s = float(q) / 32767.0

	# Chaotic modulation
	var chaos_mod: float = sin(float(_sample_pos) * 0.01) * 0.3 + 1.0
	s *= chaos_mod

	# Soft clip
	s = s / (1.0 + absf(s) * 0.8)
	s *= 0.6
	s = clampf(s, -1.0, 1.0)

	# Random glitch
	if (_sample_pos & GLITCH_CHECK_MASK) == 0 and _rng.randf() < 0.02:
		s = (_rng.randf_range(-1.0, 1.0) * 0.5 + s * 0.5) * 2.0

	_sample_pos += 1
	return clampf(s, -1.0, 1.0)

func _exit_tree() -> void:
	# Drop the generator reference explicitly so shutdown stays leak-free.
	if _player != null and _player.playing:
		_player.stop()
	_playback = null


func _hz_to_inc(hz: float) -> int:
	var inc: float = hz * (4294967296.0 / float(SR))
	return int(clampf(inc, 0.0, 4294967295.0))

func _saw_phase(ph: int) -> float:
	return float(ph) / 2147483648.0 * 2.0 - 1.0

func _tri_phase(ph: int) -> float:
	var t: float = float(ph if ph < 2147483648 else ~ph)
	return t / 2147483648.0 * 2.0 - 1.0

func _square_phase(ph: int) -> float:
	return 1.0 if ph < 2147483648 else -1.0

func change_scene() -> void:
	_randomize_params()
	_sample_pos = 0
	_step_num = -1
	_lp_state = 0.0
	_hp_state = 0.0
	_scream_env = 0.0
	_bitcrush_count = 0
