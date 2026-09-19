# ui/hud/ingame_hud.gd
# Minimal in-game overlay: crosshair, controls hint and an optional FPS counter.
extends CanvasLayer

@onready var _crosshair: Control = %Crosshair
@onready var _fps_label: Label = %FpsLabel


func _ready() -> void:
	add_to_group("hud")
	Settings.changed.connect(_apply_settings)
	GameManager.state_changed.connect(_on_state_changed)
	_apply_settings()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _apply_settings() -> void:
	_fps_label.visible = Settings.show_fps


func _on_state_changed(state: int) -> void:
	_crosshair.visible = state == GameManager.State.PLAYING
