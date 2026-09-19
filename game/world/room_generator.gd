# game/world/room_generator.gd
# Infinite rooms with doorways + chaotic mixed patterns.
#
# Streaming model: rooms are built in a square window around the player chunk and
# freed when they leave it. Each room is a SINGLE StaticBody3D holding all of its
# collision shapes, and meshes/shapes/materials are shared between rooms, which
# keeps the node, resource and draw state count low enough to stay smooth.
extends Node3D

@export var room_size: float = 10.0
@export var room_height: float = 3.5
@export var render_distance: int = 3
@export var world_seed: int = 42
## Use the seed chosen by GameManager instead of the inspector value.
@export var use_game_seed: bool = true
## Follow the render distance from the global Settings autoload.
@export var use_settings: bool = true

const WALL_THICKNESS: float = 0.15
const DOOR_WIDTH: float = 3.0
const DOOR_HEIGHT: float = 2.8
const FLOOR_THICKNESS: float = 0.1
const PATTERN_COUNT: int = 11
## Materials are shared between rooms that land in the same (pattern, seed) bucket.
const MATERIAL_BUCKETS: int = 8
## Rooms built per frame while streaming — keeps the frame time flat.
const MAX_BUILDS_PER_UPDATE: int = 2
## How often the player's chunk is re-checked.
const CHUNK_CHECK_INTERVAL: float = 0.2

const WALL_SHADER: Shader = preload("res://rendering/backrooms_wall.gdshader")

var _rng: EntroRNG = EntroRNG.new()
var _rooms: Dictionary = {}
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _shapes: Dictionary = {}
var _build_queue: Array[Vector2i] = []
var _player_chunk: Vector2i = Vector2i(99999, 99999)
var _check_timer: float = CHUNK_CHECK_INTERVAL
var _active_render_distance: int = -1


func _ready() -> void:
	if use_game_seed and GameManager != null:
		world_seed = GameManager.current_seed
	if use_settings and Settings != null:
		render_distance = Settings.render_distance
		Settings.changed.connect(_on_settings_changed)

	_active_render_distance = render_distance
	_rng.initialize(world_seed)
	_player_chunk = _get_player_chunk()
	_update_chunks(_player_chunk)


func _exit_tree() -> void:
	if Settings != null and Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _process(delta: float) -> void:
	_process_build_queue()

	_check_timer += delta
	if _check_timer < CHUNK_CHECK_INTERVAL:
		return
	_check_timer = 0.0

	var chunk := _get_player_chunk()
	if chunk != _player_chunk:
		_player_chunk = chunk
		_update_chunks(chunk)


# ---------------------------------------------------------------------------
# Streaming
# ---------------------------------------------------------------------------

func _get_player_chunk() -> Vector2i:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return Vector2i.ZERO
	var pos: Vector3 = players[0].global_position
	return Vector2i(floori(pos.x / room_size), floori(pos.z / room_size))


func _on_settings_changed() -> void:
	if not use_settings:
		return
	var distance := Settings.render_distance
	if distance == _active_render_distance:
		return
	_active_render_distance = distance
	render_distance = distance
	_clear_rooms()
	_player_chunk = _get_player_chunk()
	_update_chunks(_player_chunk)


func _update_chunks(center: Vector2i) -> void:
	var needed: Dictionary = {}
	_build_queue.clear()

	for dx in range(-render_distance, render_distance + 1):
		for dz in range(-render_distance, render_distance + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			needed[key] = true
			if not _rooms.has(key):
				_build_queue.append(key)

	# Nearest first, so the room the player is looking at appears before the edges.
	_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared()
	)

	for key in _rooms.keys():
		if not needed.has(key):
			_rooms[key].queue_free()
			_rooms.erase(key)


func _process_build_queue() -> void:
	var budget := MAX_BUILDS_PER_UPDATE
	while budget > 0 and not _build_queue.is_empty():
		var key: Vector2i = _build_queue.pop_front()
		if not _rooms.has(key):
			_build_room(key)
		budget -= 1


func _clear_rooms() -> void:
	_build_queue.clear()
	for room in _rooms.values():
		room.queue_free()
	_rooms.clear()


# ---------------------------------------------------------------------------
# Room construction
# ---------------------------------------------------------------------------

func _build_room(pos: Vector2i) -> void:
	var h := _hash_pos(pos)

	var room := StaticBody3D.new()
	room.name = "Room_%d_%d" % [pos.x, pos.y]
	room.position = Vector3(pos.x * room_size, 0.0, pos.y * room_size)

	# Every surface picks its own pattern — deliberately chaotic.
	_add_floor(room, h, h % PATTERN_COUNT)
	_add_ceiling(room, h + 500, (h >> 3) % PATTERN_COUNT)
	_add_wall(room, Vector3(0.0, 0.0, -room_size * 0.5), h + 100, (h >> 6) % PATTERN_COUNT, true)
	_add_wall(room, Vector3(0.0, 0.0, room_size * 0.5), h + 200, (h >> 9) % PATTERN_COUNT, true)
	_add_wall(room, Vector3(-room_size * 0.5, 0.0, 0.0), h + 300, (h >> 12) % PATTERN_COUNT, false)
	_add_wall(room, Vector3(room_size * 0.5, 0.0, 0.0), h + 400, (h >> 15) % PATTERN_COUNT, false)

	add_child(room)
	_rooms[pos] = room


func _add_floor(parent: StaticBody3D, seed_val: int, pattern: int) -> void:
	var size := Vector3(room_size, FLOOR_THICKNESS, room_size)
	_add_box(parent, Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0), size, _get_material(seed_val, pattern))


func _add_ceiling(parent: StaticBody3D, seed_val: int, pattern: int) -> void:
	var size := Vector3(room_size, FLOOR_THICKNESS, room_size)
	_add_box(parent, Vector3(0.0, room_height + FLOOR_THICKNESS * 0.5, 0.0), size, _get_material(seed_val, pattern))


## Builds one wall with a centred doorway. `horizontal` means the wall runs along X.
func _add_wall(parent: StaticBody3D, wall_offset: Vector3, seed_val: int, pattern: int, horizontal: bool) -> void:
	var mat := _get_material(seed_val, pattern)
	var side_width := maxf(0.2, (room_size - DOOR_WIDTH) * 0.5)
	var side_offset := DOOR_WIDTH * 0.5 + side_width * 0.5
	var centre_y := room_height * 0.5
	var lintel_height := room_height - DOOR_HEIGHT

	if horizontal:
		var segment := Vector3(side_width, room_height, WALL_THICKNESS)
		_add_box(parent, wall_offset + Vector3(-side_offset, centre_y, 0.0), segment, mat)
		_add_box(parent, wall_offset + Vector3(side_offset, centre_y, 0.0), segment, mat)
		if lintel_height > 0.01:
			_add_box(parent, wall_offset + Vector3(0.0, DOOR_HEIGHT + lintel_height * 0.5, 0.0),
				Vector3(DOOR_WIDTH, lintel_height, WALL_THICKNESS), mat)
	else:
		var segment := Vector3(WALL_THICKNESS, room_height, side_width)
		_add_box(parent, wall_offset + Vector3(0.0, centre_y, -side_offset), segment, mat)
		_add_box(parent, wall_offset + Vector3(0.0, centre_y, side_offset), segment, mat)
		if lintel_height > 0.01:
			_add_box(parent, wall_offset + Vector3(0.0, DOOR_HEIGHT + lintel_height * 0.5, 0.0),
				Vector3(WALL_THICKNESS, lintel_height, DOOR_WIDTH), mat)


func _add_box(parent: StaticBody3D, pos: Vector3, size: Vector3, mat: ShaderMaterial) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _get_mesh(size)
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = _get_shape(size)
	collision.position = pos
	parent.add_child(collision)


# ---------------------------------------------------------------------------
# Shared resources
# ---------------------------------------------------------------------------

func _get_mesh(size: Vector3) -> BoxMesh:
	var cached: BoxMesh = _meshes.get(size)
	if cached != null:
		return cached
	var mesh := BoxMesh.new()
	mesh.size = size
	_meshes[size] = mesh
	return mesh


func _get_shape(size: Vector3) -> BoxShape3D:
	var cached: BoxShape3D = _shapes.get(size)
	if cached != null:
		return cached
	var shape := BoxShape3D.new()
	shape.size = size
	_shapes[size] = shape
	return shape


func _get_material(seed_val: int, pattern: int) -> ShaderMaterial:
	var key := (pattern % PATTERN_COUNT) * MATERIAL_BUCKETS + absi(seed_val) % MATERIAL_BUCKETS
	var cached: ShaderMaterial = _materials.get(key)
	if cached != null:
		return cached

	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	mat.set_shader_parameter("seed_val", seed_val)
	mat.set_shader_parameter("pattern_type", pattern)
	mat.set_shader_parameter("emission_strength", 0.8)
	mat.set_shader_parameter("time_speed", 0.5)
	mat.set_shader_parameter("color_intensity", 1.2)
	_materials[key] = mat
	return mat


func _hash_pos(pos: Vector2i) -> int:
	var h := pos.x * 374761393 + pos.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h)
