# core/math/entro_math.gd
class_name EntroMath
extends RefCounted

static func remapf(value: float, from_min: float, from_max: float, to_min: float, to_max: float) -> float:
    return lerpf(to_min, to_max, (value - from_min) / (from_max - from_min))

static func smoothstepf(edge0: float, edge1: float, x: float) -> float:
    var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

static func random_range_vec3(rng: RandomNumberGenerator, min_val: float, max_val: float) -> Vector3:
    return Vector3(
        rng.randf_range(min_val, max_val),
        rng.randf_range(min_val, max_val),
        rng.randf_range(min_val, max_val)
    )
