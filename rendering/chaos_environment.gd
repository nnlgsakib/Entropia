# rendering/chaos_environment.gd
# Spawns procedural chaos objects in the world
extends Node3D

@export var spawn_radius: float = 30.0
@export var object_count: int = 20
@export var world_seed: int = 42

var _rng: EntroRNG = EntroRNG.new()

func _ready() -> void:
	_rng.initialize(world_seed)
	_spawn_chaos_objects()
	_spawn_chaos_floor()
	_spawn_chaos_pillars()

func _spawn_chaos_floor() -> void:
	var floor_mesh: MeshInstance3D = get_node_or_null("Floor/MeshInstance3D")
	if floor_mesh:
		var mat: ShaderMaterial = ShaderMaterial.new()
		var shader: Shader = load("res://rendering/chaos_shader.gdshader")
		mat.shader = shader
		mat.set_shader_parameter("seed_val", world_seed)
		mat.set_shader_parameter("pattern_type", 0)
		mat.set_shader_parameter("brightness", 0.6)
		mat.set_shader_parameter("time_scale", 0.15)
		floor_mesh.set_surface_override_material(0, mat)

func _spawn_chaos_objects() -> void:
	var chaos_scene: PackedScene = load("res://rendering/chaos_object.tscn")
	if not chaos_scene:
		return

	for i in range(object_count):
		var obj: Node3D = chaos_scene.instantiate()
		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(5.0, spawn_radius)
		var height: float = _rng.randf_range(0.5, 8.0)
		obj.position = Vector3(cos(angle) * dist, height, sin(angle) * dist)

		var mesh_inst: MeshInstance3D = obj.get_node("MeshInstance3D")
		if mesh_inst:
			var mat: ShaderMaterial = ShaderMaterial.new()
			var shader: Shader = load("res://rendering/chaos_vortex.gdshader")
			mat.shader = shader
			mat.set_shader_parameter("seed_val", _rng.randi_range(0, 99999))
			mat.set_shader_parameter("brightness", _rng.randf_range(0.8, 2.0))
			mat.set_shader_parameter("warp_strength", _rng.randf_range(0.5, 3.0))
			mat.set_shader_parameter("rotation_speed", _rng.randf_range(0.1, 2.0))
			mesh_inst.set_surface_override_material(0, mat)

			var scale_val: float = _rng.randf_range(0.3, 2.5)
			obj.scale = Vector3(scale_val, scale_val, scale_val)

		add_child(obj)

func _spawn_chaos_pillars() -> void:
	for i in range(8):
		var pillar: StaticBody3D = StaticBody3D.new()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var col: CollisionShape3D = CollisionShape3D.new()

		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.5, _rng.randf_range(2.0, 10.0), 0.5)
		mesh.mesh = box

		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = box.size
		col.shape = box_shape

		var mat: ShaderMaterial = ShaderMaterial.new()
		var shader: Shader = load("res://rendering/chaos_shader.gdshader")
		mat.shader = shader
		mat.set_shader_parameter("seed_val", _rng.randi_range(0, 99999))
		mat.set_shader_parameter("brightness", _rng.randf_range(1.0, 2.5))
		mat.set_shader_parameter("warp_strength", _rng.randf_range(1.0, 4.0))
		mesh.set_surface_override_material(0, mat)

		pillar.add_child(mesh)
		pillar.add_child(col)

		var angle: float = _rng.randf_range(0.0, TAU)
		var dist: float = _rng.randf_range(8.0, 25.0)
		pillar.position = Vector3(cos(angle) * dist, box.size.y * 0.5, sin(angle) * dist)

		add_child(pillar)
