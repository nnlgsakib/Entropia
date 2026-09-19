# ui/menus/settings_menu.gd
# Settings panel — instanced by both the main menu and the pause menu.
# Every control applies its value live; the config file is written on close.
extends Control

signal closed

@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _fov_slider: HSlider = %FovSlider
@onready var _fov_value: Label = %FovValue
@onready var _invert_check: CheckButton = %InvertCheck
@onready var _display_option: OptionButton = %DisplayModeOption
@onready var _distance_slider: HSlider = %RenderDistanceSlider
@onready var _distance_value: Label = %RenderDistanceValue
@onready var _effects_check: CheckButton = %EffectsCheck
@onready var _vsync_check: CheckButton = %VsyncCheck
@onready var _fps_check: CheckButton = %ShowFpsCheck
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton

var _syncing: bool = false


func _ready() -> void:
	hide()
	_connect_controls()
	_sync_from_settings()


func _connect_controls() -> void:
	_volume_slider.value_changed.connect(func(v: float) -> void: Settings.set_master_volume(v))
	_sensitivity_slider.value_changed.connect(func(v: float) -> void: Settings.set_mouse_sensitivity(v))
	_fov_slider.value_changed.connect(func(v: float) -> void: Settings.set_fov(v))
	_invert_check.toggled.connect(func(v: bool) -> void: Settings.set_invert_y(v))
	_display_option.item_selected.connect(func(index: int) -> void: Settings.set_display_mode(index))
	_distance_slider.value_changed.connect(func(v: float) -> void: Settings.set_render_distance(int(v)))
	_effects_check.toggled.connect(func(v: bool) -> void: Settings.set_effects_enabled(v))
	_vsync_check.toggled.connect(func(v: bool) -> void: Settings.set_vsync(v))
	_fps_check.toggled.connect(func(v: bool) -> void: Settings.set_show_fps(v))
	_reset_button.pressed.connect(_on_reset_pressed)
	_back_button.pressed.connect(close)
	Settings.changed.connect(_sync_from_settings)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_sync_from_settings):
		Settings.changed.disconnect(_sync_from_settings)


func open() -> void:
	_sync_from_settings()
	show()
	_back_button.grab_focus()


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _sync_from_settings() -> void:
	if _syncing:
		return
	_syncing = true
	_volume_slider.value = Settings.master_volume
	_sensitivity_slider.value = Settings.mouse_sensitivity
	_fov_slider.value = Settings.fov
	_invert_check.button_pressed = Settings.invert_y
	_display_option.selected = Settings.display_mode
	_distance_slider.value = Settings.render_distance
	_effects_check.button_pressed = Settings.effects_enabled
	_vsync_check.button_pressed = Settings.vsync
	_fps_check.button_pressed = Settings.show_fps
	_syncing = false
	_update_value_labels()


func _update_value_labels() -> void:
	_volume_value.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_sensitivity_value.text = "%.1f" % (Settings.mouse_sensitivity * 1000.0)
	_fov_value.text = "%d" % roundi(Settings.fov)
	_distance_value.text = "%d" % Settings.render_distance


func _on_reset_pressed() -> void:
	Settings.reset_to_defaults()
	Settings.save_settings()
	_sync_from_settings()
