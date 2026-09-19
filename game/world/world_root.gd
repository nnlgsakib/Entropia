# game/world/world_root.gd
# Bridges a running world to the global systems (settings + game state).
extends Node3D

@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	GameManager.notify_game_ready()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)


func _apply_settings() -> void:
	var env := _world_environment.environment
	if env == null:
		return
	env.glow_enabled = Settings.effects_enabled
	env.ssao_enabled = Settings.effects_enabled
