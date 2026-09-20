# core/experiments/experiment_catalog.gd
# Registry of the generated installations.
#
# What lives where is a pure function of ChaosMath.hash2(sector, world_seed), so
# the world is byte-identical on every run and nothing ever needs saving.
class_name ExperimentCatalog
extends RefCounted

const PARTICLE_STORM: GDScript = preload("res://game/experiments/particle_storm.gd")
const MATH_STRUCTURE: GDScript = preload("res://game/experiments/math_structure.gd")
const FALLING_SAND: GDScript = preload("res://game/experiments/falling_sand.gd")
const FLOCK: GDScript = preload("res://game/experiments/flock.gd")
const SIGNAL_LAB: GDScript = preload("res://game/experiments/signal_lab.gd")
const PHYSICS_LAB: GDScript = preload("res://game/experiments/physics_lab.gd")

## Percentage of sectors deliberately left empty, so installations have contrast.
const QUIET_PERCENT: int = 30

static var _types: Array[Dictionary] = []


static func types() -> Array[Dictionary]:
	if _types.is_empty():
		_types = [
			{"id": &"particle_storm", "label": "PARTICLE STORM", "script": PARTICLE_STORM},
			{"id": &"math_structure", "label": "MATH STRUCTURE", "script": MATH_STRUCTURE},
			{"id": &"falling_sand", "label": "FALLING SAND", "script": FALLING_SAND},
			{"id": &"flock", "label": "FLOCK", "script": FLOCK},
			{"id": &"signal_lab", "label": "SIGNAL LAB", "script": SIGNAL_LAB},
			{"id": &"physics_lab", "label": "PHYSICS RIG", "script": PHYSICS_LAB},
		]
	return _types


## The installation kind for a sector. An empty id means a quiet sector.
static func kind_for(sector: Vector2i, world_seed: int) -> StringName:
	var list := types()
	if list.is_empty():
		return &""

	var hash := ChaosMath.hash2(sector.x, sector.y, world_seed)
	if hash % 100 < QUIET_PERCENT:
		return &""
	return list[(hash >> 8) % list.size()]["id"]


## A stable per-sector seed, so an installation rebuilds exactly as it was.
static func seed_for(sector: Vector2i, world_seed: int) -> int:
	return ChaosMath.splitmix32(ChaosMath.hash2(sector.x, sector.y, world_seed + 7919))


static func label_for(id: StringName) -> String:
	var index := _index_of(id)
	return "" if index < 0 else String(types()[index]["label"])


static func create(id: StringName) -> Experiment:
	var index := _index_of(id)
	if index < 0:
		return null
	var script: GDScript = types()[index]["script"]
	return script.new() as Experiment


static func _index_of(id: StringName) -> int:
	var list := types()
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1
