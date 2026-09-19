# ui/menus/pause_menu.gd
# In-game pause overlay. Owns the ESC handling for a running game.
extends CanvasLayer

@onready var _panel: Control = %PausePanel
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %PauseSettingsButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _quit_button: Button = %PauseQuitButton
@onready var _settings_overlay: Control = %SettingsOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.hide()

	_resume_button.pressed.connect(GameManager.resume_game)
	_settings_button.pressed.connect(_settings_overlay.open)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_quit_button.pressed.connect(GameManager.quit_game)
	_settings_overlay.closed.connect(_on_settings_closed)
	GameManager.state_changed.connect(_on_state_changed)

	_on_state_changed(GameManager.current_state)


func _exit_tree() -> void:
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if _settings_overlay.visible:
		_settings_overlay.close()
	elif GameManager.current_state == GameManager.State.PAUSED:
		GameManager.resume_game()
	elif GameManager.current_state == GameManager.State.PLAYING:
		GameManager.pause_game()
	else:
		return

	get_viewport().set_input_as_handled()


func _on_state_changed(state: int) -> void:
	var paused := state == GameManager.State.PAUSED
	_panel.visible = paused

	if paused:
		_resume_button.grab_focus()
	elif _settings_overlay.visible:
		_settings_overlay.close()


func _on_settings_closed() -> void:
	if _panel.visible:
		_resume_button.grab_focus()


func _on_main_menu_pressed() -> void:
	GameManager.go_to_main_menu()
