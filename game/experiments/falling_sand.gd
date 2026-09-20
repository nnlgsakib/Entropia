# game/experiments/falling_sand.gd
# A voxel cellular automaton hung in the room.
#
# Sand pours from the top of a tall panel, piles up on two shelves with gaps in
# them, and drains away along the bottom, so the pattern keeps circulating instead
# of filling up and stopping. The whole grid is drawn with one MultiMesh, so a few
# hundred cells cost a single draw call.
extends Experiment

const EMPTY: int = 0
const SAND: int = 1
const WALL: int = 2

const WIDTH: int = 28
const HEIGHT: int = 22
## Simulation rate. Slower than the frame rate, which is what makes grains read as
## falling rather than teleporting.
const TICK_INTERVAL: float = 0.085
const SPAWN_PER_TICK: int = 2
const INITIAL_SAND: int = 60
const SHELF_GAP_HALF_WIDTH: int = 3

var _grid := PackedByteArray()
var _palette_colours := PackedColorArray()
var _multimesh: MultiMesh
var _panel_origin: Vector3 = Vector3.ZERO
var _cell: float = 0.1
var _tick_timer: float = 0.0


func _construct() -> void:
	_grid.resize(WIDTH * HEIGHT)
	_grid.fill(EMPTY)

	_cell = bounds.y * 0.8 / float(HEIGHT)
	_panel_origin = Vector3(bounds.x * 0.5, bounds.y * 0.12, bounds.z * 0.5)

	for i in 8:
		_palette_colours.append(palette_color(float(i) / 7.0))

	_place_shelves()
	_build_multimesh()
	_seed_initial_sand()
	_refresh_instances()


func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer < TICK_INTERVAL:
		return
	_tick_timer = 0.0
	_simulate()
	_refresh_instances()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Two shelves with a gap, so falling sand has to find its way through.
func _place_shelves() -> void:
	var upper := int(float(HEIGHT) * 0.62)
	var lower := int(float(HEIGHT) * 0.38)

	_set_shelf(upper, rng.randi_range(SHELF_GAP_HALF_WIDTH, WIDTH - 1 - SHELF_GAP_HALF_WIDTH))
	_set_shelf(lower, rng.randi_range(SHELF_GAP_HALF_WIDTH, WIDTH - 1 - SHELF_GAP_HALF_WIDTH))


func _set_shelf(row: int, gap_x: int) -> void:
	for x in WIDTH:
		if absi(x - gap_x) > SHELF_GAP_HALF_WIDTH:
			_set_cell(x, row, WALL)


func _seed_initial_sand() -> void:
	for i in INITIAL_SAND:
		_set_cell(
			rng.randi_range(0, WIDTH - 1),
			rng.randi_range(0, HEIGHT / 3),
			SAND
		)


func _build_multimesh() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_cell * 0.92, _cell * 0.92, _cell * 0.92)

	_multimesh = MultiMesh.new()
	# Format flags must be set before the instance count.
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = mesh
	_multimesh.instance_count = WIDTH * HEIGHT

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.material_override = vertex_colour_material()
	add_child(instance)


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------

func _simulate() -> void:
	for i in SPAWN_PER_TICK:
		_set_cell(rng.randi_range(0, WIDTH - 1), 0, SAND)

	# Walk bottom-up so a grain can only move once per tick: anything that moves
	# lands in a row that has already been processed.
	for y in range(HEIGHT - 1, -1, -1):
		for x in WIDTH:
			if _grid[y * WIDTH + x] != SAND:
				continue

			if y == HEIGHT - 1:
				# Drains away, which is what keeps the panel from filling up.
				_set_cell(x, y, EMPTY)
				continue

			if _try_move(x, y, x, y + 1):
				continue

			var drift := -1 if rng.randf() < 0.5 else 1
			if not _try_move(x, y, x + drift, y + 1):
				_try_move(x, y, x - drift, y + 1)


func _try_move(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	if to_x < 0 or to_x >= WIDTH or to_y < 0 or to_y >= HEIGHT:
		return false
	if _grid[to_y * WIDTH + to_x] != EMPTY:
		return false
	_set_cell(to_x, to_y, SAND)
	_set_cell(from_x, from_y, EMPTY)
	return true


func _set_cell(x: int, y: int, state: int) -> void:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT:
		return
	_grid[y * WIDTH + x] = state


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _refresh_instances() -> void:
	# A zero-scale basis collapses the instance to nothing, which is cheaper than
	# tracking and compacting a visible instance count every tick.
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	var index := 0

	for y in HEIGHT:
		for x in WIDTH:
			var state := _grid[index]
			if state == EMPTY:
				_multimesh.set_instance_transform(index, hidden)
			else:
				_multimesh.set_instance_transform(index, Transform3D(Basis(), _cell_position(x, y)))
				_multimesh.set_instance_color(index, _colour_for(state, y))
			index += 1


func _cell_position(x: int, y: int) -> Vector3:
	return Vector3(
		_panel_origin.x,
		_panel_origin.y + float(HEIGHT - 1 - y) * _cell,
		_panel_origin.z + (float(x) - float(WIDTH) * 0.5) * _cell
	)


## Sand is tinted by how far it has fallen, which reads as depth in the pile.
func _colour_for(state: int, y: int) -> Color:
	if state == WALL:
		return Color(0.09, 0.10, 0.14)
	var t := 1.0 - float(y) / float(HEIGHT)
	var scaled := t * float(_palette_colours.size() - 1)
	var lower := clampi(int(scaled), 0, _palette_colours.size() - 1)
	var upper := clampi(lower + 1, 0, _palette_colours.size() - 1)
	return _palette_colours[lower].lerp(_palette_colours[upper], scaled - float(lower))
