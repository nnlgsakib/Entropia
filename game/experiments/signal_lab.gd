# game/experiments/signal_lab.gd
# Audio-reactive installation: a ring of spectrum bars and a morphing Lissajous
# ribbon, both driven by the live procedural drone from chaos_audio.gd.
#
# A spectrum analyser is attached to the Master bus the first time one of these is
# built and is deliberately left there for the rest of the session — it is a tiny
# 512-sample FFT and re-adding it per installation would restart the analysis.
extends Experiment

const BAR_COUNT: int = 16
const BAR_LENGTH: float = 2.2
const BAR_WIDTH: float = 0.16
const RING_RADIUS_FRACTION: float = 0.28

const MIN_FREQ: float = 40.0
const MAX_FREQ: float = 8000.0
## A gentle floor so the rig never looks dead when the drone is quiet.
const IDLE_LEVEL: float = 0.07
## Per-band peak decay per second. Normalising against the running peak means the
## bars look right whatever the drone's absolute level happens to be.
const PEAK_DECAY: float = 0.4

const LISSAJOUS_POINTS: int = 320
const LISSAJOUS_REBUILD_INTERVAL: float = 0.2
const LISSAJOUS_WIDTH: float = 0.035

var _bars: Array[MeshInstance3D] = []
var _bar_materials: Array[StandardMaterial3D] = []
var _raw := PackedFloat32Array()
var _energies := PackedFloat32Array()
var _peaks := PackedFloat32Array()

var _bus: int = -1
var _effect_index: int = -1
var _analyzer: AudioEffectSpectrumAnalyzerInstance = null

var _lissajous: MeshInstance3D
var _lissajous_phase: float = 0.0
var _lissajous_timer: float = 0.0
var _liss_freq := Vector3(3.0, 2.0, 4.0)

var _elapsed: float = 0.0
var _total_energy: float = 0.0


func _construct() -> void:
	_raw.resize(BAR_COUNT)
	_energies.resize(BAR_COUNT)
	_peaks.resize(BAR_COUNT)

	_liss_freq = Vector3(
		float(rng.randi_range(2, 5)),
		float(rng.randi_range(1, 4)),
		float(rng.randi_range(2, 6))
	)

	_build_bars()
	_build_lissajous()
	_acquire_analyzer()


func _process(delta: float) -> void:
	_elapsed += delta
	_sample_bands(delta)
	_drive_bars()
	_drive_lissajous(delta)


# ---------------------------------------------------------------------------
# Spectrum
# ---------------------------------------------------------------------------

func _acquire_analyzer() -> void:
	if _analyzer != null:
		return

	_bus = AudioServer.get_bus_index("Master")
	if _bus < 0:
		return

	# Reuse an existing analyser so several signal labs never stack up FFT effects.
	for i in AudioServer.get_bus_effect_count(_bus):
		if AudioServer.get_bus_effect(_bus, i) is AudioEffectSpectrumAnalyzer:
			_effect_index = i
			_analyzer = AudioServer.get_bus_effect_instance(_bus, i) as AudioEffectSpectrumAnalyzerInstance
			return

	var effect := AudioEffectSpectrumAnalyzer.new()
	effect.buffer_length = 0.1
	effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512
	AudioServer.add_bus_effect(_bus, effect)

	_effect_index = AudioServer.get_bus_effect_count(_bus) - 1
	_analyzer = AudioServer.get_bus_effect_instance(_bus, _effect_index) as AudioEffectSpectrumAnalyzerInstance


func _sample_bands(delta: float) -> void:
	if _analyzer == null:
		_acquire_analyzer()
		for i in BAR_COUNT:
			_raw[i] = 0.0
			_energies[i] = 0.0
		return

	var decay := exp(-PEAK_DECAY * delta)

	# Auto-gain against the loudest band, so the display is readable at any level.
	var loudest := 0.0
	for i in BAR_COUNT:
		_raw[i] = _band_magnitude(i)
		_peaks[i] = maxf(_peaks[i] * decay, _raw[i])
		loudest = maxf(loudest, _peaks[i])

	var gain := 1.0 / maxf(loudest, 0.00001)
	var total := 0.0
	for i in BAR_COUNT:
		var level := clampf(_raw[i] * gain, 0.0, 1.0)
		_energies[i] = level
		total += level
	_total_energy = total / float(BAR_COUNT)


func _band_magnitude(index: int) -> float:
	if _analyzer == null:
		return 0.0

	# Logarithmically spaced bands, which matches how hearing and the drone's
	# content actually distribute across the spectrum.
	var ratio := MAX_FREQ / MIN_FREQ
	var from_hz := MIN_FREQ * pow(ratio, float(index) / float(BAR_COUNT))
	var to_hz := MIN_FREQ * pow(ratio, float(index + 1) / float(BAR_COUNT))

	var magnitude := _analyzer.get_magnitude_for_frequency_range(
		from_hz, to_hz, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
	)
	return maxf(magnitude.x, magnitude.y)


# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

func _build_bars() -> void:
	var radius := minf(bounds.x, bounds.z) * RING_RADIUS_FRACTION
	var middle := centre()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE

	for i in BAR_COUNT:
		var angle := TAU * float(i) / float(BAR_COUNT)
		var material := emissive_material(palette_color(float(i) / float(BAR_COUNT)), 1.0)

		var bar := MeshInstance3D.new()
		bar.mesh = mesh
		bar.material_override = material
		bar.scale = Vector3(BAR_WIDTH, BAR_LENGTH, BAR_WIDTH)
		bar.position = middle + Vector3(cos(angle) * radius, BAR_LENGTH * 0.5, sin(angle) * radius)

		add_child(bar)
		_bars.append(bar)
		_bar_materials.append(material)


func _drive_bars() -> void:
	for i in BAR_COUNT:
		var idle := IDLE_LEVEL + 0.03 * sin(_elapsed * 1.4 + float(i) * 0.8)
		var energy := _energies[i]
		var height := maxf(0.06, maxf(energy, idle) * BAR_LENGTH)

		var bar := _bars[i]
		bar.scale = Vector3(BAR_WIDTH, height, BAR_WIDTH)
		# Bars grow from the floor: the mesh is centred, so recentre it as it grows.
		bar.position.y = height * 0.5
		_bar_materials[i].emission_energy_multiplier = 0.4 + energy * 6.0


func _build_lissajous() -> void:
	var material := vertex_colour_material()
	_lissajous = MeshInstance3D.new()
	_lissajous.mesh = _lissajous_mesh()
	_lissajous.material_override = material
	_lissajous.position = centre() + Vector3(0.0, bounds.y * 0.55, 0.0)
	add_child(_lissajous)


## A 3D Lissajous figure: three sine oscillators at different frequencies, which is
## the same idea as an oscilloscope's XY mode, extended into three axes.
func _lissajous_mesh() -> ArrayMesh:
	var scale := minf(bounds.x, bounds.z) * 0.3
	var points := PackedVector3Array()

	for i in LISSAJOUS_POINTS:
		var t := TAU * float(i) / float(LISSAJOUS_POINTS - 1)
		points.append(
			Vector3(
				sin(_liss_freq.x * t + _lissajous_phase),
				sin(_liss_freq.y * t) * 0.6,
				sin(_liss_freq.z * t + _lissajous_phase * 0.7)
			) * scale
		)

	var colours := PackedColorArray()
	for i in points.size():
		colours.append(palette_color(float(i) / float(points.size())))

	return ribbon_mesh(points, colours, LISSAJOUS_WIDTH)


func _drive_lissajous(delta: float) -> void:
	# The figure morphs faster the louder the drone is.
	_lissajous_phase += delta * (0.25 + _total_energy * 1.5)
	_lissajous.rotation.y += delta * 0.2
	_lissajous.scale = Vector3.ONE * (0.85 + _total_energy * 0.5)

	_lissajous_timer += delta
	if _lissajous_timer < LISSAJOUS_REBUILD_INTERVAL:
		return
	_lissajous_timer = 0.0
	_lissajous.mesh = _lissajous_mesh()
