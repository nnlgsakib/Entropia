extends Node

enum State { MENU, LOADING, PLAYING, PAUSED }

var current_state: State = State.MENU
var current_seed: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func load_world(scene_path: String, seed_value: int = 0) -> void:
    current_seed = seed_value
    current_state = State.LOADING
    get_tree().change_scene_to_file(scene_path)
    current_state = State.PLAYING

func pause_game() -> void:
    get_tree().paused = true
    current_state = State.PAUSED

func resume_game() -> void:
    get_tree().paused = false
    current_state = State.PLAYING
