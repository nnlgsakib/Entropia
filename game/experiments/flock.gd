# game/experiments/flock.gd
# Artificial life: a boid flock that steers by separation, alignment and cohesion.
#
# Every pair of boids is visited once and the forces are added to both, so a flock
# of 80 costs 3160 distance tests per step rather than 6400. Scratch arrays are
# allocated once and reused, because this runs every physics frame.
extends Experiment

const BOID_COUNT: int = 80
const NEIGHBOUR_RADIUS: float = 3.0
const SEPARATION_RADIUS: float = 0.9

const SEPARATION_WEIGHT: float = 2.6
const ALIGNMENT_WEIGHT: float = 1.1
const COHESION_WEIGHT: float = 0.9
const BOUNDS_WEIGHT: float = 12.0

const MAX_SPEED: float = 3.4
const MIN_SPEED: float = 1.3
## Steering is stepped at a fixed rate so the motion is stable regardless of fps.
const STEP_INTERVAL: float = 1.0 / 30.0
const MESH_SIZE: Vector3 = Vector3(0.05, 0.05, 0.2)

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _separation := PackedVector3Array()
var _alignment := PackedVector3Array()
var _cohesion := PackedVector3Array()
var _counts := PackedInt32Array()

var _multimesh: MultiMesh
var _step_timer: float = 0.0


func _construct() -> void:
	_positions.resize(BOID_COUNT)
	_velocities.resize(BOID_COUNT)
	_separation.resize(BOID_COUNT)
	_alignment.resize(BOID_COUNT)
	_cohesion.resize(BOID_COUNT)
	_counts.resize(BOID_COUNT)

	for i in BOID_COUNT:
		_positions[i] = random_point(1.0)
		_velocities[i] = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.4, 0.4),
			rng.randf_range(-1.0, 1.0)
		).normalized() * MAX_SPEED

	_build_multimesh()
	_refresh_instances()


func _physics_process(delta: float) -> void:
	_step_timer += delta
	if _step_timer < STEP_INTERVAL:
		return
	var step := _step_timer
	_step_timer = 0.0
	_step(step)
	_refresh_instances()


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _step(dt: float) -> void:
	for i in BOID_COUNT:
		_separation[i] = Vector3.ZERO
		_alignment[i] = Vector3.ZERO
		_cohesion[i] = Vector3.ZERO
		_counts[i] = 0

	var radius_sq := NEIGHBOUR_RADIUS * NEIGHBOUR_RADIUS

	for i in BOID_COUNT:
		for j in range(i + 1, BOID_COUNT):
			var offset := _positions[j] - _positions[i]
			var distance_sq := offset.length_squared()
			if distance_sq > radius_sq or distance_sq < 0.000001:
				continue

			# One distance test, two boids updated.
			_alignment[i] += _velocities[j]
			_alignment[j] += _velocities[i]
			_cohesion[i] += _positions[j]
			_cohesion[j] += _positions[i]
			_counts[i] += 1
			_counts[j] += 1

			var distance := sqrt(distance_sq)
			if distance < SEPARATION_RADIUS:
				var push := offset / distance * (1.0 - distance / SEPARATION_RADIUS)
				_separation[i] -= push
				_separation[j] += push

	for i in BOID_COUNT:
		var acceleration := _bounds_force(_positions[i])
		var count := _counts[i]
		if count > 0:
			var inverse := 1.0 / float(count)
			acceleration += (_alignment[i] * inverse - _velocities[i]) * ALIGNMENT_WEIGHT
			acceleration += (_cohesion[i] * inverse - _positions[i]) * COHESION_WEIGHT
			acceleration += _separation[i] * SEPARATION_WEIGHT

		var velocity := _velocities[i] + acceleration * dt
		var speed := velocity.length()
		if speed > MAX_SPEED:
			velocity = velocity * (MAX_SPEED / speed)
		elif speed < MIN_SPEED and speed > 0.000001:
			velocity = velocity * (MIN_SPEED / speed)

		_velocities[i] = velocity
		_positions[i] = _clamp_to_interior(_positions[i] + velocity * dt)


## Pushes boids back inside an inset box so the flock stays in its room.
func _bounds_force(position: Vector3) -> Vector3:
	var middle := centre()
	var half := _interior_half()
	var offset := position - middle
	var force := Vector3.ZERO

	if absf(offset.x) > half.x:
		force.x = -signf(offset.x) * (absf(offset.x) - half.x) * BOUNDS_WEIGHT
	if absf(offset.y) > half.y:
		force.y = -signf(offset.y) * (absf(offset.y) - half.y) * BOUNDS_WEIGHT
	if absf(offset.z) > half.z:
		force.z = -signf(offset.z) * (absf(offset.z) - half.z) * BOUNDS_WEIGHT

	return force


func _interior_half() -> Vector3:
	return Vector3(bounds.x * 0.4, bounds.y * 0.34, bounds.z * 0.4)


## The steering force is a soft spring, so a fast boid can overshoot it. This is a
## hard backstop that guarantees the flock never pokes through a wall or floor.
func _clamp_to_interior(position: Vector3) -> Vector3:
	var middle := centre()
	var half := _interior_half()
	return Vector3(
		clampf(position.x, middle.x - half.x, middle.x + half.x),
		clampf(position.y, middle.y - half.y, middle.y + half.y),
		clampf(position.z, middle.z - half.z, middle.z + half.z)
	)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _build_multimesh() -> void:
	var mesh := BoxMesh.new()
	mesh.size = MESH_SIZE

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = mesh
	_multimesh.instance_count = BOID_COUNT

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.material_override = vertex_colour_material()
	add_child(instance)


func _refresh_instances() -> void:
	for i in BOID_COUNT:
		_multimesh.set_instance_transform(i, Transform3D(_basis_for(_velocities[i]), _positions[i]))
		_multimesh.set_instance_color(i, palette_color(float(i) / float(BOID_COUNT)))


## Orthonormal basis whose +Z points along the boid's heading, which lines the
## elongated mesh up with its own velocity.
func _basis_for(velocity: Vector3) -> Basis:
	var forward := velocity.normalized()
	if forward.length_squared() < 0.5:
		return Basis()

	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT

	var right := up.cross(forward).normalized()
	var real_up := forward.cross(right).normalized()
	return Basis(right, real_up, forward)
