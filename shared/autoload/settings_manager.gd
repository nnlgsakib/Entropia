# shared/autoload/settings_manager.gd
# Global user settings. Persisted to user://settings.cfg and applied immediately.
# Consumers read the properties directly and listen to the `changed` signal.
extends Node

signal changed

enum DisplayMode { WINDOWED, FULLSCREEN, EXCLUSIVE }

const CONFIG_PATH: String = "user://settings.cfg"
const MIN_SENSITIVITY: float = 0.0005
const MAX_SENSITIVITY: float = 0.01
const MIN_FOV: float = 60.0
const MAX_FOV: float = 110.0
const MIN_RENDER_DISTANCE: int = 1
const MAX_RENDER_DISTANCE: int = 6
const DEFAULT_WINDOW_SIZE: Vector2i = Vector2i(1600, 900)
## First launch starts windowed; flip this to DisplayMode.FULLSCREEN to ship fullscreen.
const DEFAULT_DISPLAY_MODE: int = DisplayMode.WINDOWED

# --- Audio ---
var master_volume: float = 0.8

# --- Input ---
var mouse_sensitivity: float = 0.0025
var invert_y: bool = false

# --- Video ---
var display_mode: int = DEFAULT_DISPLAY_MODE
var vsync: bool = true
var fov: float = 78.0
var window_size: Vector2i = DEFAULT_WINDOW_SIZE
var effects_enabled: bool = true

# --- Gameplay ---
var render_distance: int = 3
var show_fps: bool = false

var _loading: bool = false


func _ready() -> void:
	# Keep working while the game is paused (F11, audio preview).
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		cycle_display_mode()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		save_settings()
		return

	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)), MIN_SENSITIVITY, MAX_SENSITIVITY)
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	display_mode = clampi(int(cfg.get_value("video", "display_mode", display_mode)), DisplayMode.WINDOWED, DisplayMode.EXCLUSIVE)
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	fov = clampf(float(cfg.get_value("video", "fov", fov)), MIN_FOV, MAX_FOV)
	effects_enabled = bool(cfg.get_value("video", "effects", effects_enabled))
	window_size = cfg.get_value("video", "window_size", window_size) as Vector2i
	render_distance = clampi(int(cfg.get_value("gameplay", "render_distance", render_distance)), MIN_RENDER_DISTANCE, MAX_RENDER_DISTANCE)
	show_fps = bool(cfg.get_value("gameplay", "show_fps", show_fps))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("video", "display_mode", display_mode)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "effects", effects_enabled)
	cfg.set_value("video", "window_size", window_size)
	cfg.set_value("gameplay", "render_distance", render_distance)
	cfg.set_value("gameplay", "show_fps", show_fps)

	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("Settings: could not write %s (error %d)" % [CONFIG_PATH, err])


# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_video()
	changed.emit()


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


func apply_video() -> void:
	match display_mode:
		DisplayMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(window_size)
			_center_window()
		DisplayMode.EXCLUSIVE:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_pos + (screen_size - window_size) / 2)


func reset_to_defaults() -> void:
	master_volume = 0.8
	mouse_sensitivity = 0.0025
	invert_y = false
	display_mode = DEFAULT_DISPLAY_MODE
	vsync = true
	fov = 78.0
	effects_enabled = true
	window_size = DEFAULT_WINDOW_SIZE
	render_distance = 3
	show_fps = false
	apply_all()


# ---------------------------------------------------------------------------
# Setters — each applies immediately and notifies listeners
# ---------------------------------------------------------------------------

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	changed.emit()


func set_invert_y(value: bool) -> void:
	invert_y = value
	changed.emit()


func set_fov(value: float) -> void:
	fov = clampf(value, MIN_FOV, MAX_FOV)
	changed.emit()


func set_display_mode(value: int) -> void:
	if display_mode == DisplayMode.WINDOWED and value != DisplayMode.WINDOWED:
		window_size = DisplayServer.window_get_size()
	display_mode = clampi(value, DisplayMode.WINDOWED, DisplayMode.EXCLUSIVE)
	apply_video()
	changed.emit()


func cycle_display_mode() -> void:
	set_display_mode((display_mode + 1) % DisplayMode.size())


func set_vsync(value: bool) -> void:
	vsync = value
	apply_video()
	changed.emit()


func set_effects_enabled(value: bool) -> void:
	effects_enabled = value
	changed.emit()


func set_render_distance(value: int) -> void:
	render_distance = clampi(value, MIN_RENDER_DISTANCE, MAX_RENDER_DISTANCE)
	changed.emit()


func set_show_fps(value: bool) -> void:
	show_fps = value
	changed.emit()
