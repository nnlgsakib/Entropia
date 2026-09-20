# game/experiments/experiment.gd
# Base class for one generated installation.
#
# An experiment must be fully rebuildable from (seed, bounds) alone: the generator
# frees and re-creates these freely as the player walks, so nothing may depend on
# state captured at build time or on anything outside its own sector.
class_name Experiment
extends Node3D

var world_seed: int = 0
## Local space the installation must fit inside.
var bounds: Vector3 = Vector3(20.0, 3.5, 20.0)
var rng: EntroRNG = EntroRNG.new()


func build(p_seed: int, p_bounds: Vector3) -> void:
	world_seed = p_seed
	bounds = p_bounds
	rng.initialize(p_seed)
	_construct()


## Subclasses build their content here.
func _construct() -> void:
	pass


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

func random_point(margin: float = 0.0) -> Vector3:
	return Vector3(
		rng.randf_range(margin, maxf(margin, bounds.x - margin)),
		rng.randf_range(margin, maxf(margin, bounds.y - margin)),
		rng.randf_range(margin, maxf(margin, bounds.z - margin))
	)


func centre() -> Vector3:
	return Vector3(bounds.x * 0.5, bounds.y * 0.5, bounds.z * 0.5)


## Detail multiplier driven by the player's effects setting.
func detail_scale() -> float:
	if Settings != null and not Settings.effects_enabled:
		return 0.35
	return 1.0


## A colour from the ported chaos palettes, so every installation shares the
## world's mood instead of looking like a separate art style.
func palette_color(t: float) -> Color:
	return ChaosMath.palette_pick(t, world_seed, rng.randi_range(0, 99))


func fade_gradient(from: Color, to: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## Unshaded material that takes its colour from mesh vertex colours.
func vertex_colour_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func emissive_material(colour: Color, energy: float = 2.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour.darkened(0.6)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	material.roughness = 0.4
	return material


## Sweeps a constant-width ribbon along a curve. Each sample emits two vertices
## offset either side, which a triangle strip turns into a continuous surface.
func ribbon_mesh(points: PackedVector3Array, colours: PackedColorArray, width: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var vertex_colours := PackedColorArray()
	var last := points.size() - 1

	for i in points.size():
		var direction: Vector3
		if i == 0:
			direction = points[1] - points[0]
		elif i == last:
			direction = points[i] - points[i - 1]
		else:
			direction = points[i + 1] - points[i - 1]

		if direction.length_squared() < 0.0000001:
			direction = Vector3.UP
		direction = direction.normalized()

		var side := direction.cross(Vector3.UP)
		if side.length_squared() < 0.0000001:
			side = direction.cross(Vector3.RIGHT)
		side = side.normalized() * width

		vertices.append(points[i] - side)
		vertices.append(points[i] + side)
		vertex_colours.append(colours[i])
		vertex_colours.append(colours[i])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = vertex_colours

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh
