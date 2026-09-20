# game/experiments/physics_lab.gd
# A Jolt physics rig. Half the sectors get bodies in orbit under a real inverse
# square law integrated by hand, the other half a pinned pendulum chain.
#
# Bodies go on their own collision layer and only mask the world, so bodies inside
# one rig pass through each other. That keeps the orbits clean and stops the
# pendulum links from jittering against one another.
extends Experiment

const ORBIT_BODY_MIN: int = 5
const ORBIT_BODY_MAX: int = 9
## Standard gravitational parameter. Bigger means faster, tighter orbits.
const ORBIT_MU: float = 45.0
const MIN_ORBIT_RADIUS: float = 2.0
const MIN_DISTANCE_SQ: float = 0.36

const PENDULUM_SEGMENTS: int = 10
const BODY_RADIUS: float = 0.13

const BODY_LAYER: int = 2
const WORLD_MASK: int = 1

var _bodies: Array[RigidBody3D] = []
var _pivot: Vector3 = Vector3.ZERO
var _orbiting: bool = false


func _construct() -> void:
	if rng.randf() < 0.5:
		_build_orbit()
	else:
		_build_pendulum()


func _physics_process(_delta: float) -> void:
	if not _orbiting:
		return

	for body in _bodies:
		if not is_instance_valid(body):
			continue
		var offset := _pivot - body.position
		var distance_sq := maxf(offset.length_squared(), MIN_DISTANCE_SQ)
		var acceleration := offset.normalized() * (ORBIT_MU / distance_sq)
		# apply_central_force takes a force, so scaling by mass is what produces
		# the acceleration the inverse square law asks for.
		body.apply_central_force(acceleration * body.mass)


# ---------------------------------------------------------------------------
# Orbits
# ---------------------------------------------------------------------------

func _build_orbit() -> void:
	_orbiting = true
	_pivot = centre()

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.35
	core_mesh.height = 0.7
	core.mesh = core_mesh
	core.material_override = emissive_material(Color(1.0, 0.85, 0.4), 3.0)
	core.position = _pivot
	add_child(core)

	var count := rng.randi_range(ORBIT_BODY_MIN, ORBIT_BODY_MAX)
	var max_radius := minf(bounds.x, bounds.z) * 0.42

	for i in count:
		var radius := rng.randf_range(MIN_ORBIT_RADIUS, max_radius)
		var angle := rng.randf_range(0.0, TAU)
		var inclination := rng.randf_range(-0.6, 0.6)

		var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		offset = offset.rotated(Vector3.RIGHT, inclination)

		var body := _make_body(_pivot + offset, BODY_RADIUS, palette_color(float(i) / float(count)))
		_bodies.append(body)

		# Circular orbit speed: v = sqrt(mu / r), along the tangent.
		var speed := sqrt(ORBIT_MU / maxf(offset.length(), MIN_ORBIT_RADIUS))
		var tangent := offset.cross(Vector3.UP)
		if tangent.length_squared() < 0.0001:
			tangent = offset.cross(Vector3.RIGHT)
		body.linear_velocity = tangent.normalized() * speed


# ---------------------------------------------------------------------------
# Pendulum
# ---------------------------------------------------------------------------

func _build_pendulum() -> void:
	var anchor := Vector3(bounds.x * 0.5, bounds.y * 0.88, bounds.z * 0.5)
	_pivot = anchor
	var segment := minf(bounds.y * 0.72 / float(PENDULUM_SEGMENTS), 0.42)

	# A chain hanging dead straight sits at equilibrium and would never move, so
	# give the whole thing a sideways shove to start it swinging.
	var push := Vector3(rng.randf_range(1.5, 3.0), 0.0, rng.randf_range(-0.6, 0.6))

	var anchor_body := StaticBody3D.new()
	anchor_body.name = "Anchor"
	anchor_body.position = anchor
	add_child(anchor_body)

	# Typed as the shared base so the rigid links can be assigned to it later.
	var previous: PhysicsBody3D = anchor_body
	for i in PENDULUM_SEGMENTS:
		var body := _make_body(
			anchor + Vector3(0.0, -segment * float(i + 1), 0.0),
			segment * 0.5,
			palette_color(float(i) / float(PENDULUM_SEGMENTS))
		)
		body.name = "Link%d" % i
		body.linear_damp = 0.05
		body.linear_velocity = push
		_bodies.append(body)

		# The pin sits where the two links touch, which is the midpoint of their
		# centres: the anchor is included so the chain actually hangs from it.
		var joint := PinJoint3D.new()
		add_child(joint)
		joint.position = (previous.position + body.position) * 0.5
		joint.node_a = joint.get_path_to(previous)
		joint.node_b = joint.get_path_to(body)

		previous = body


# ---------------------------------------------------------------------------
# Shared
# ---------------------------------------------------------------------------

## Creates a sphere body on the rig's own collision layer.
func _make_body(position: Vector3, radius: float, colour: Color) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = position
	body.mass = 1.0
	body.gravity_scale = 0.0
	body.linear_damp = 0.0
	body.collision_layer = BODY_LAYER
	body.collision_mask = WORLD_MASK

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = emissive_material(colour, 2.0)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)

	add_child(body)
	return body
