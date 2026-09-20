# game/experiments/math_structure.gd
# A mathematics sculpture: a Lorenz attractor swept into a glowing ribbon, plus an
# optional interference-wave surface beneath it.
#
# The attractor is integrated directly from the ODE, and the ribbon is coloured by
# the ported chaos palettes, so the maths and the art come from the same place.
extends Experiment

const WAVE_SHADER: Shader = preload("res://rendering/wave_grid.gdshader")

const RIBBON_STEPS: int = 2600
const RIBBON_WIDTH: float = 0.05
const WAVE_SUBDIVISIONS: int = 48
## Fraction of the sector the ribbon is allowed to occupy.
const RIBBON_FILL: float = 0.7


func _construct() -> void:
	_build_lorenz_ribbon()
	if rng.randf() < 0.6:
		_build_wave_surface()


# ---------------------------------------------------------------------------
# Lorenz attractor
# ---------------------------------------------------------------------------

func _build_lorenz_ribbon() -> void:
	var raw := _integrate_lorenz()
	if raw.size() < 2:
		return

	var points := _fit_to_bounds(raw)
	var colours := PackedColorArray()
	for i in points.size():
		colours.append(palette_color(float(i) / float(points.size())))

	var instance := MeshInstance3D.new()
	instance.mesh = ribbon_mesh(points, colours, RIBBON_WIDTH)
	instance.material_override = vertex_colour_material()
	add_child(instance)


## Integrates the Lorenz system with the classic RK-free Euler step. Sigma, rho and
## beta are randomised per installation, so no two attractors have the same shape.
func _integrate_lorenz() -> PackedVector3Array:
	var sigma := rng.randf_range(8.0, 12.0)
	var rho := rng.randf_range(24.0, 32.0)
	var beta := rng.randf_range(2.2, 3.0)
	var dt := 0.004

	var x := rng.randf_range(0.1, 2.0)
	var y := 0.0
	var z := 0.0

	var points := PackedVector3Array()
	for i in RIBBON_STEPS:
		var dx := sigma * (y - x)
		var dy := x * (rho - z) - y
		var dz := x * y - beta * z
		x += dx * dt
		y += dy * dt
		z += dz * dt
		# Z is up in Lorenz; swap axes so the sculpture stands upright in the room.
		points.append(Vector3(x, z, y))
	return points


## Centres the curve inside the sector and uniformly scales it to fit.
func _fit_to_bounds(raw: PackedVector3Array) -> PackedVector3Array:
	var box := AABB(raw[0], Vector3.ZERO)
	for p in raw:
		box = box.expand(p)

	var target := bounds * RIBBON_FILL
	var size := box.size
	var scale := minf(
		target.x / maxf(size.x, 0.001),
		minf(target.y / maxf(size.y, 0.001), target.z / maxf(size.z, 0.001))
	)
	# Centre of the sector, so the sculpture hangs in the middle of the room.
	var centre := Vector3(bounds.x * 0.5, bounds.y * 0.5, bounds.z * 0.5)
	var origin := box.get_center()

	var fitted := PackedVector3Array()
	for p in raw:
		fitted.append((p - origin) * scale + centre)
	return fitted


# ---------------------------------------------------------------------------
# Interference wave surface
# ---------------------------------------------------------------------------

func _build_wave_surface() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(bounds.x * 0.92, bounds.z * 0.92)
	plane.subdivide_width = WAVE_SUBDIVISIONS
	plane.subdivide_depth = WAVE_SUBDIVISIONS

	var material := ShaderMaterial.new()
	material.shader = WAVE_SHADER
	material.set_shader_parameter("amplitude", rng.randf_range(0.15, 0.5))
	material.set_shader_parameter("frequency", rng.randf_range(0.4, 1.6))
	material.set_shader_parameter("speed", rng.randf_range(0.3, 1.4))
	material.set_shader_parameter("drift", rng.randf_range(0.0, 60.0))
	material.set_shader_parameter("grid_density", rng.randf_range(4.0, 14.0))
	material.set_shader_parameter("color_low", Color(0.01, 0.02, 0.06, 1.0))
	material.set_shader_parameter("color_high", palette_color(rng.randf()))

	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = material
	instance.position = Vector3(bounds.x * 0.5, 0.06, bounds.z * 0.5)
	add_child(instance)
