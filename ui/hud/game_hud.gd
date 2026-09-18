# ui/hud/game_hud.gd
# HUD — collect count, interact prompt
extends CanvasLayer

@onready var _collect_label: Label = $CollectLabel
@onready var _interact_prompt: Label = $InteractPrompt

var _collect_count: int = 0

func _ready() -> void:
	add_to_group("hud")
	_interact_prompt.visible = false

func add_collect() -> void:
	_collect_count += 1
	_collect_label.text = "CHAOS: %d" % _collect_count

func show_interact_prompt(val: bool) -> void:
	_interact_prompt.visible = val
