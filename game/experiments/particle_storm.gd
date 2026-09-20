# game/experiments/particle_storm.gd
# Emitters suspended inside invisible force fields.
#
# The fields are Godot's GPU particle attractors, so the forces are evaluated on
# the GPU and tens of thousands of particles cost the CPU almost nothing. Sphere
# attractors are given a negative strength to repel, which is what makes the
# fields read as real forces rather than decorations.
extends Experiment

const EMITTER_MIN: int = 2
const EMITTER_MAX: int = 4
const FIELD_MIN: int = 2
const FIELD_MAX: int = 5
## Particles generated per installation, split between its emitters.
const PARTICLE_BUDGET: int = 14000
const FIELD_RADIUS_MIN: float = 2.5
const FIELD_RADIUS_MAX: float = 6.5


func _construct() -> void:
	var emitter_count := rng.randi_range(EMITTER_MIN, EMITTER_MAX)
	var field_count := rng.randi_range(FIELD_MIN, FIELD_MAX)

	for i in range(field_count):
		_add_force_field()
	for i in range(emitter_count):
		_add_emitter(i, emitter_count)


# ---------------------------------------------------------------------------
# Force fields
# ---------------------------------------------------------------------------

func _add_force_field() -> void:
	var position := random_point(2.0)
	position.y = rng.randf_range(1.0, maxf(1.5, bounds.y * 0.75))

	# Roughly a third of fields are directional wind instead of a point force.
	if rng.randf() < 0.35:
		_add_vector_field(position)
		return

	var attractor := GPUParticlesAttractorSphere3D.new()
	attractor.position = position
	attractor.radius = rng.randf_range(FIELD_RADIUS_MIN, FIELD_RADIUS_MAX)
	# A negative strength pulls inward instead of pushing outward.
	attractor.strength = rng.randf_range(1.5, 6.0) * (-1.0 if rng.randf() < 0.6 else 1.0)
	attractor.attenuation = rng.randf_range(0.1, 0.9)
	attractor.directionality = rng.randf_range(0.0, 1.0)
	add_child(attractor)

	_add_field_visual(position, attractor.radius, attractor.strength < 0.0)


## A vector field driven by a 3D noise texture — swirling, curl-like wind.
func _add_vector_field(position: Vector3) -> void:
	var field := GPUParticlesAttractorVectorField3D.new()
	field.position = position

	var extent := rng.randf_range(8.0, 16.0)
	field.size = Vector3(extent, maxf(2.0, bounds.y), extent)
	field.strength = rng.randf_range(1.0, 4.0)

	var noise := FastNoiseLite.new()
	noise.seed = world_seed ^ rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = rng.randf_range(0.008, 0.03)

	var texture := NoiseTexture3D.new()
	texture.noise = noise
	texture.width = 32
	texture.height = 32
	texture.depth = 32
	field.texture = texture

	add_child(field)


## A faint additive bubble so the invisible force is still readable.
func _add_field_visual(position: Vector3, radius: float, attracts: bool) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = (
		Color(0.25, 0.75, 1.0, 0.05) if attracts else Color(1.0, 0.3, 0.35, 0.05)
	)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	add_child(instance)


# ---------------------------------------------------------------------------
# Emitters
# ---------------------------------------------------------------------------

func _add_emitter(index: int, emitter_count: int) -> void:
	var colour := palette_color(float(index) / maxf(1.0, float(emitter_count)))
	var position := random_point(3.0)
	position.y = rng.randf_range(0.8, maxf(1.2, bounds.y * 0.6))

	var particles := GPUParticles3D.new()
	particles.position = position
	particles.amount = maxi(1500, int(float(PARTICLE_BUDGET) * detail_scale() / float(emitter_count)))
	particles.lifetime = rng.randf_range(4.0, 9.0)
	# Prewarm so the storm is already full the moment you walk in.
	particles.preprocess = particles.lifetime
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	particles.fixed_fps = 30
	particles.local_coords = false
	# Attractors in the same tree act on particles automatically — there is no
	# opt-in flag in Godot 4.7.
	# GPU particles are culled by this box, so it must cover the whole field.
	particles.visibility_aabb = AABB(-bounds, bounds * 2.0)
	particles.process_material = _make_process_material(colour)
	particles.draw_pass_1 = _make_draw_mesh()
	add_child(particles)


func _make_process_material(colour: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = rng.randf_range(0.3, 1.2)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = rng.randf_range(0.0, 2.0)
	material.initial_velocity_max = rng.randf_range(2.0, 7.0)
	# No gravity: the force fields are the only thing acting on the particles.
	material.gravity = Vector3.ZERO
	material.scale_min = rng.randf_range(0.04, 0.12)
	material.scale_max = rng.randf_range(0.15, 0.40)
	material.lifetime_randomness = 0.4
	material.damping_min = 0.2
	material.damping_max = 0.8
	material.turbulence_enabled = true
	material.turbulence_noise_strength = rng.randf_range(0.4, 2.5)
	material.turbulence_noise_speed_random = 0.4
	material.turbulence_noise_speed = Vector3(
		rng.randf_range(0.1, 0.6),
		rng.randf_range(0.1, 0.6),
		rng.randf_range(0.1, 0.6)
	)
	material.color = colour
	material.color_ramp = fade_gradient(colour, Color(colour.r, colour.g, colour.b, 0.0))
	return material


## Camera-facing additive quad. Vertex colour carries the particle colour, so the
## albedo stays white and is not multiplied twice.
func _make_draw_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.0, 1.0)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	return mesh
