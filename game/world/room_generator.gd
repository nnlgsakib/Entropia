# game/world/room_generator.gd
# Infinite rooms with doorways + chaotic mixed patterns
extends Node3D

@export var room_size: float = 10.0
@export var room_height: float = 3.5
@export var render_distance: int = 3
@export var world_seed: int = 42

var _rng: EntroRNG = EntroRNG.new()
var _rooms: Dictionary = {}
var _player_chunk: Vector2i = Vector2i(99999, 99999)
var _shader: Shader

const WALL_THICKNESS: float = 0.15
const DOOR_WIDTH: float = 3.0
const DOOR_HEIGHT: float = 2.8

func _ready() -> void:
	_rng.initialize(world_seed)
	_shader = load("res://rendering/backrooms_wall.gdshader")
	_update_chunks(Vector2i.ZERO)

func _process(_delta: float) -> void:
	var chunk = _get_player_chunk()
	if chunk != _player_chunk:
		_player_chunk = chunk
		_update_chunks(chunk)

func _get_player_chunk() -> Vector2i:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return Vector2i.ZERO
	var pos = players[0].global_position
	return Vector2i(floori(pos.x / room_size), floori(pos.z / room_size))

func _update_chunks(center: Vector2i) -> void:
	var needed: Dictionary = {}
	for dx in range(-render_distance, render_distance + 1):
		for dz in range(-render_distance, render_distance + 1):
			var key = Vector2i(center.x + dx, center.y + dz)
			needed[key] = true
			if not _rooms.has(key):
				_build_room(key)

	for key in _rooms.keys():
		if not needed.has(key):
			_rooms[key].queue_free()
			_rooms.erase(key)

func _build_room(pos: Vector2i) -> void:
	var room = Node3D.new()
	room.position = Vector3(pos.x * room_size, 0, pos.y * room_size)

	var h = _hash_pos(pos)

	# Each surface gets its OWN random pattern — chaotic
	var floor_pat = h % 11
	var ceil_pat = (h >> 3) % 11
	var wall_n_pat = (h >> 6) % 11
	var wall_s_pat = (h >> 9) % 11
	var wall_e_pat = (h >> 12) % 11
	var wall_w_pat = (h >> 15) % 11

	# Floor
	_add_floor(room, h, floor_pat)

	# Ceiling
	_add_ceiling(room, h + 500, ceil_pat)

	# Walls with doorways (always open to adjacent rooms)
	_add_wall_with_door(room, Vector3(0, 0, -room_size * 0.5), Vector3(room_size, room_height, WALL_THICKNESS), h + 100, wall_n_pat, true)
	_add_wall_with_door(room, Vector3(0, 0, room_size * 0.5), Vector3(room_size, room_height, WALL_THICKNESS), h + 200, wall_s_pat, true)
	_add_wall_with_door(room, Vector3(-room_size * 0.5, 0, 0), Vector3(WALL_THICKNESS, room_height, room_size), h + 300, wall_e_pat, false)
	_add_wall_with_door(room, Vector3(room_size * 0.5, 0, 0), Vector3(WALL_THICKNESS, room_height, room_size), h + 400, wall_w_pat, false)

	add_child(room)
	_rooms[pos] = room

func _add_floor(parent: Node3D, seed_val: int, pattern: int) -> void:
	var body = StaticBody3D.new()
	body.position = Vector3(0, 0, 0)
	body.name = "Floor"

	var mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(room_size, room_size)
	mesh.mesh = plane
	mesh.material_override = _make_mat(seed_val, pattern)
	body.add_child(mesh)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(room_size, 0.1, room_size)
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)

func _add_ceiling(parent: Node3D, seed_val: int, pattern: int) -> void:
	var body = StaticBody3D.new()
	body.position = Vector3(0, room_height, 0)
	body.name = "Ceiling"

	var mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(room_size, room_size)
	mesh.mesh = plane
	mesh.rotation.x = PI
	mesh.material_override = _make_mat(seed_val, pattern)
	body.add_child(mesh)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(room_size, 0.1, room_size)
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)

func _add_wall_with_door(parent: Node3D, pos: Vector3, _size: Vector3, seed_val: int, pattern: int, horizontal: bool) -> void:
	var wall_group = Node3D.new()
	wall_group.position = pos

	var mat = _make_mat(seed_val, pattern)

	if horizontal:
		# Wall along X axis, door in center
		var side_width = (room_size - DOOR_WIDTH) * 0.5

		# Left segment
		if side_width > 0.1:
			_add_box(wall_group, Vector3(-room_size * 0.25 - side_width * 0.25, room_height * 0.5, 0),
				Vector3(side_width, room_height, WALL_THICKNESS), mat)

		# Right segment
		if side_width > 0.1:
			_add_box(wall_group, Vector3(room_size * 0.25 + side_width * 0.25, room_height * 0.5, 0),
				Vector3(side_width, room_height, WALL_THICKNESS), mat)

		# Top segment (above door)
		_add_box(wall_group, Vector3(0, DOOR_HEIGHT + (room_height - DOOR_HEIGHT) * 0.5, 0),
			Vector3(DOOR_WIDTH, room_height - DOOR_HEIGHT, WALL_THICKNESS), mat)
	else:
		# Wall along Z axis, door in center
		var side_width = (room_size - DOOR_WIDTH) * 0.5

		# Front segment
		if side_width > 0.1:
			_add_box(wall_group, Vector3(0, room_height * 0.5, -room_size * 0.25 - side_width * 0.25),
				Vector3(WALL_THICKNESS, room_height, side_width), mat)

		# Back segment
		if side_width > 0.1:
			_add_box(wall_group, Vector3(0, room_height * 0.5, room_size * 0.25 + side_width * 0.25),
				Vector3(WALL_THICKNESS, room_height, side_width), mat)

		# Top segment (above door)
		_add_box(wall_group, Vector3(0, DOOR_HEIGHT + (room_height - DOOR_HEIGHT) * 0.5, 0),
			Vector3(WALL_THICKNESS, room_height - DOOR_HEIGHT, DOOR_WIDTH), mat)

	parent.add_child(wall_group)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: ShaderMaterial) -> void:
	var body = StaticBody3D.new()
	body.position = pos

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)

	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	parent.add_child(body)

func _make_mat(seed_val: int, pattern: int) -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("seed_val", seed_val)
	mat.set_shader_parameter("pattern_type", pattern)
	mat.set_shader_parameter("emission_strength", 0.8)
	mat.set_shader_parameter("time_speed", 0.5)
	mat.set_shader_parameter("color_intensity", 1.2)
	return mat

func _hash_pos(pos: Vector2i) -> int:
	var h = pos.x * 374761393 + pos.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h)
