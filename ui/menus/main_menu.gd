# ui/menus/main_menu.gd
# Title screen — entry point of the game.
extends Control

@onready var _play_button: Button = %PlayButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_overlay: Control = %SettingsOverlay
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	GameManager.notify_menu_ready()

	_version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

	_play_button.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_overlay.closed.connect(_on_settings_closed)

	_play_button.grab_focus()


func _on_play_pressed() -> void:
	GameManager.start_new_run()


func _on_settings_pressed() -> void:
	_settings_overlay.open()


func _on_settings_closed() -> void:
	_play_button.grab_focus()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
