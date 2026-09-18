# core/random/entro_rng.gd
class_name EntroRNG
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0

func initialize(seed_value: int) -> void:
    _seed = seed_value
    _rng.seed = seed_value

func get_seed() -> int:
    return _seed

func randf() -> float:
    return _rng.randf()

func randf_range(min_val: float, max_val: float) -> float:
    return _rng.randf_range(min_val, max_val)

func randi() -> int:
    return _rng.randi()

func randi_range(min_val: int, max_val: int) -> int:
    return _rng.randi_range(min_val, max_val)

func randf_range_vec3(min_val: float, max_val: float) -> Vector3:
    return EntroMath.random_range_vec3(_rng, min_val, max_val)
