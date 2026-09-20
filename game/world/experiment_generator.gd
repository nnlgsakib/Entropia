# game/world/experiment_generator.gd
# Streams procedural installations into the endless world.
#
# Which sector holds which experiment is a pure function of the world seed, so
# nothing is ever written to disk: walk away and it is freed, walk back and it is
# rebuilt identically. The world is the same for every player on the same seed.
extends Node3D

signal zone_changed(zone_name: String)

@export var room_size: float = 10.0
@export var room_height: float = 3.5
## Chunks per side of one sector. 2 means an installation spans a 2x2 block of rooms.
@export var chunks_per_sector: int = 2
## How many sectors around the player stay built.
@export var sector_render_distance: int = 1
@export var world_seed: int = 42
## Use the seed chosen by GameManager instead of the inspector value.
@export var use_game_seed: bool = true
@export var enabled: bool = true

## Installations built per frame — installations are heavy, so this stays at one.
const MAX_BUILDS_PER_UPDATE: int = 1
const CHECK_INTERVAL: float = 0.25

## Vector2i -> Experiment. A null value marks a sector that is deliberately quiet,
## recorded so the generator does not try to rebuild it every check.
var _experiments: Dictionary = {}
var _build_queue: Array[Vector2i] = []
var _player_sector: Vector2i = Vector2i(99999, 99999)
var _check_timer: float = 0.0
var _zone_name: String = ""


func _ready() -> void:
	add_to_group("experiment_generator")
	if use_game_seed and GameManager != null:
		world_seed = GameManager.current_seed
	_player_sector = _current_player_sector()
	_update_sectors(_player_sector)
	_update_zone()


func _process(delta: float) -> void:
	_process_build_queue()

	_check_timer += delta
	if _check_timer < CHECK_INTERVAL:
		return
	_check_timer = 0.0

	var sector := _current_player_sector()
	if sector == _player_sector:
		return
	_player_sector = sector
	_update_sectors(sector)
	_update_zone()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Name of the installation the player is standing in, or "" for a quiet sector.
func current_zone_name() -> String:
	return _zone_name


func sector_size() -> float:
	return room_size * float(chunks_per_sector)


func sector_of_position(position: Vector3) -> Vector2i:
	var size := sector_size()
	return Vector2i(floori(position.x / size), floori(position.z / size))


# ---------------------------------------------------------------------------
# Streaming
# ---------------------------------------------------------------------------

func _current_player_sector() -> Vector2i:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return Vector2i.ZERO
	return sector_of_position((players[0] as Node3D).global_position)


func _update_sectors(center: Vector2i) -> void:
	_build_queue.clear()
	if not enabled:
		return

	var needed: Dictionary = {}
	for dx in range(-sector_render_distance, sector_render_distance + 1):
		for dz in range(-sector_render_distance, sector_render_distance + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			needed[key] = true
			if not _experiments.has(key):
				_build_queue.append(key)

	# Nearest first, so the installation you are walking toward appears first.
	_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared()
	)

	for key in _experiments.keys():
		if needed.has(key):
			continue
		var experiment: Experiment = _experiments[key]
		if experiment != null:
			experiment.queue_free()
		_experiments.erase(key)


func _process_build_queue() -> void:
	var budget := MAX_BUILDS_PER_UPDATE
	while budget > 0 and not _build_queue.is_empty():
		_build_sector(_build_queue.pop_front())
		budget -= 1


func _build_sector(sector: Vector2i) -> void:
	var kind := ExperimentCatalog.kind_for(sector, world_seed)
	if kind == &"":
		_experiments[sector] = null
		return

	var experiment := ExperimentCatalog.create(kind)
	if experiment == null:
		_experiments[sector] = null
		return

	var size := sector_size()
	experiment.name = "Experiment_%d_%d" % [sector.x, sector.y]
	experiment.position = Vector3(sector.x * size, 0.0, sector.y * size)
	add_child(experiment)
	experiment.build(
		ExperimentCatalog.seed_for(sector, world_seed),
		Vector3(size, room_height, size)
	)
	_experiments[sector] = experiment


func _update_zone() -> void:
	var kind := ExperimentCatalog.kind_for(_player_sector, world_seed)
	var label := ExperimentCatalog.label_for(kind)
	if label == _zone_name:
		return
	_zone_name = label
	zone_changed.emit(label)
