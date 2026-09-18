# game/entities/chaos_entity.gd
# Dark entity that follows player — appears in random rooms
extends CharacterBody3D

@export var move_speed: float = 2.5
@export var detection_range: float = 20.0
@export var entity_seed: int = 0

var _target: Node3D = null
var _rng: EntroRNG = EntroRNG.new()
var _time: float = 0.0
var _active: bool = false

func _ready() -> void:
	_rng.initialize(entity_seed)
	add_to_group("entity")

func _physics_process(delta: float) -> void:
	if _target == null:
		_find_player()
		return

	var dist = global_position.distance_to(_target.global_position)

	if dist < detection_range:
		_active = true
	else:
		_active = false

	if not _active:
		return

	# Move toward player
	var dir = (_target.global_position - global_position).normalized()
	dir.y = 0

	velocity = dir * move_speed
	move_and_slide()

	# Bob up and down
	_time += delta
	position.y = 1.0 + sin(_time * 2.0) * 0.2

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_target = players[0]
