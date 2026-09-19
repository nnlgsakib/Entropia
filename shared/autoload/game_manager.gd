# shared/autoload/game_manager.gd
# Game flow owner: menu <-> run transitions, pause, quit, mouse capture.
extends Node

signal state_changed(state: State)
signal run_started(seed_value: int)

enum State { BOOT, MENU, LOADING, PLAYING, PAUSED }

const MAIN_MENU_SCENE: String = "res://ui/menus/main_menu.tscn"
const GAME_SCENE: String = "res://game/world/backrooms_main.tscn"
const FADE_TIME: float = 0.25

var current_state: State = State.BOOT
var current_seed: int = 42

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _changing_scene: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_layer()


func _notification(what: int) -> void:
	# Re-capture the mouse if the player alt-tabs back into a running game.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and current_state == State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------

func start_new_run(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	current_seed = seed_value
	run_started.emit(seed_value)
	_change_scene(GAME_SCENE)


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func quit_game() -> void:
	save_all()
	get_tree().quit()


func save_all() -> void:
	Settings.save_settings()


## Called by the game world once it is fully in the tree.
func notify_game_ready() -> void:
	_set_state(State.PLAYING)
	_apply_mouse_mode()


## Called by the main menu when it becomes the active scene.
func notify_menu_ready() -> void:
	get_tree().paused = false
	_set_state(State.MENU)
	_apply_mouse_mode()


# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

func pause_game() -> void:
	if current_state != State.PLAYING:
		return
	get_tree().paused = true
	_set_state(State.PAUSED)
	_apply_mouse_mode()


func resume_game() -> void:
	if current_state != State.PAUSED:
		return
	get_tree().paused = false
	_set_state(State.PLAYING)
	_apply_mouse_mode()


func toggle_pause() -> void:
	if current_state == State.PLAYING:
		pause_game()
	elif current_state == State.PAUSED:
		resume_game()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _change_scene(path: String) -> void:
	if _changing_scene:
		return
	_changing_scene = true

	await _fade_to(1.0)
	get_tree().paused = false
	_set_state(State.LOADING)
	_apply_mouse_mode()

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("GameManager: cannot load scene %s (error %d)" % [path, err])

	# change_scene_to_file() is deferred — wait for the swap before fading in.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_changing_scene = false


func _set_state(state: State) -> void:
	if current_state == state:
		return
	current_state = state
	state_changed.emit(state)


func _apply_mouse_mode() -> void:
	match current_state:
		State.PLAYING:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "ScreenFade"
	_fade_layer.layer = 128
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(0.01, 0.01, 0.02, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color.a = 0.0
	_fade_layer.add_child(_fade_rect)


func _fade_to(alpha: float) -> void:
	if _fade_rect == null:
		return
	_fade_layer.visible = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, FADE_TIME)
	await tween.finished
	_fade_layer.visible = alpha > 0.01
