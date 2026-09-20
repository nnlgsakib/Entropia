# ui/hud/ingame_hud.gd
# Minimal in-game overlay: crosshair, zone name, controls hint and an FPS counter.
extends CanvasLayer

@onready var _crosshair: Control = %Crosshair
@onready var _fps_label: Label = %FpsLabel
@onready var _zone_label: Label = %ZoneLabel

## Found lazily: the generator is a world node and may not exist in this scene.
var _generator = null


func _ready() -> void:
	add_to_group("hud")
	_zone_label.text = ""
	Settings.changed.connect(_apply_settings)
	GameManager.state_changed.connect(_on_state_changed)
	_apply_settings()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)
	if _generator != null and _generator.zone_changed.is_connected(_on_zone_changed):
		_generator.zone_changed.disconnect(_on_zone_changed)


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if _generator == null:
		_connect_generator()


func _connect_generator() -> void:
	_generator = get_tree().get_first_node_in_group("experiment_generator")
	if _generator == null:
		return
	_generator.zone_changed.connect(_on_zone_changed)
	_on_zone_changed(_generator.current_zone_name())


func _on_zone_changed(zone_name: String) -> void:
	_zone_label.text = zone_name
	_zone_label.visible = not zone_name.is_empty()


func _apply_settings() -> void:
	_fps_label.visible = Settings.show_fps


func _on_state_changed(state: int) -> void:
	_crosshair.visible = state == GameManager.State.PLAYING
