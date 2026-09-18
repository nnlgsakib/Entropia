# game/objects/chaos_orb.gd
# Collectible chaos orb — floats, glows, rotates
extends Area3D

@export var orb_seed: int = 0
@export var float_speed: float = 2.0
@export var float_amp: float = 0.3
@export var rotate_speed: float = 1.5

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _base_y + sin(_time * float_speed) * float_amp
	rotation.y += rotate_speed * delta

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("player"):
		_collected = true
		# Update HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("add_collect"):
			hud.add_collect()
		queue_free()
