# core/math/chaos_math.gd
# Ported from chaos_shorts_hell.c — procedural noise and palette math
class_name ChaosMath
extends RefCounted

static func fractf(x: float) -> float:
	return x - floorf(x)

static func custom_smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

static func lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t

static func clampf(x: float, a: float, b: float) -> float:
	return clampf(x, a, b)

# xorshift128 RNG
static func rng_next_u32(s: Array) -> int:
	var result: int = (((s[1] * 5) << 7) | ((s[1] * 5) >> 25)) * 9
	var t: int = s[1] << 9
	s[2] = s[2] ^ s[0]
	s[3] = s[3] ^ s[1]
	s[1] = s[1] ^ s[2]
	s[0] = s[0] ^ s[3]
	s[2] = s[2] ^ t
	s[3] = (s[3] << 11) | (s[3] >> 21)
	return result & 0xFFFFFFFF

static func rng_f01(s: Array) -> float:
	return float(rng_next_u32(s) >> 8) / 16777216.0

static func splitmix32(x: int) -> int:
	x = (x + 0x9E3779B9) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	return (x ^ (x >> 16)) & 0xFFFFFFFF

static func rng_seed(s: Array, seed_val: int) -> void:
	var x: int = seed_val
	for i in range(4):
		x = splitmix32(x)
		s[i] = x
	if (s[0] | s[1] | s[2] | s[3]) == 0:
		s[0] = 1

# Hash functions from C code
static func hash2(x: int, y: int, s: int) -> int:
	var h: int = (x * 0x1E35A7BD ^ y * 0x94D049BB ^ s * 0x369DEA0F) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 0x7FEB352D) & 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 0x846CA68B) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return h

static func hash2f(x: int, y: int, s: int) -> float:
	return float(hash2(x, y, s) >> 8) / 16777216.0

# Value noise
static func value_noise(x: float, y: float, seed_val: int) -> float:
	var xi: int = int(floorf(x))
	var yi: int = int(floorf(y))
	var tx: float = x - float(xi)
	var ty: float = y - float(yi)
	var sx: float = custom_smoothstep(clampf(tx, 0.0, 1.0))
	var sy: float = custom_smoothstep(clampf(ty, 0.0, 1.0))
	var v00: float = hash2f(xi, yi, seed_val)
	var v10: float = hash2f(xi + 1, yi, seed_val)
	var v01: float = hash2f(xi, yi + 1, seed_val)
	var v11: float = hash2f(xi + 1, yi + 1, seed_val)
	var a: float = lerp(v00, v10, sx)
	var b: float = lerp(v01, v11, sx)
	return lerp(a, b, sy)

# Fractal noise (octaves)
static func fractal_noise(x: float, y: float, seed_val: int, octaves: int) -> float:
	var sum: float = 0.0
	var amp: float = 1.0
	var freq: float = 1.0
	var maxval: float = 0.0
	for i in range(octaves):
		sum += amp * (value_noise(x * freq, y * freq, seed_val + i * 997) * 2.0 - 1.0)
		maxval += amp
		amp *= 0.5
		freq *= 2.0
	return sum / maxval if maxval > 0.0 else 0.0

# Color palette functions (ported from C)
static func palette_hell(t: float, seed_val: int) -> Color:
	t = clampf(t, 0.0, 1.0)
	var h: int = splitmix32(int(t * 99999.0) ^ seed_val)
	var r: float = clampf(0.5 + 1.5 * t + float(h & 0x3FF) / 1023.0 * 0.5, 0.0, 1.0)
	var g: float = clampf(0.1 + 2.0 * float((h >> 10) & 0x3FF) / 1023.0, 0.0, 1.0)
	var b: float = clampf(0.0 + 3.0 * (1.0 - t) * float((h >> 20) & 0x3FF) / 1023.0, 0.0, 1.0)
	return Color(r, g, b)

static func palette_blood(t: float, seed_val: int) -> Color:
	t = clampf(t, 0.0, 1.0)
	var h: int = splitmix32(int(t * 88888.0) ^ seed_val)
	var r: float = clampf(0.3 + 1.4 * t + float((h >> 8) & 0xFF) / 255.0 * 0.4, 0.0, 1.0)
	var g: float = clampf(float((h >> 16) & 0xFF) / 255.0 * 0.3 * t, 0.0, 1.0)
	var b: float = clampf(float(h & 0xFF) / 255.0 * 0.2, 0.0, 1.0)
	return Color(r, g, b)

static func palette_void(t: float, seed_val: int) -> Color:
	t = clampf(t, 0.0, 1.0)
	var h: int = splitmix32(int(t * 77777.0) ^ seed_val)
	var r: float = clampf(float(h & 0x3FF) / 1023.0 * 1.2 * (1.0 - t), 0.0, 1.0)
	var g: float = clampf(float((h >> 10) & 0x3FF) / 1023.0 * 0.8, 0.0, 1.0)
	var b: float = clampf(0.5 + 1.2 * t + float((h >> 20) & 0x3FF) / 1023.0 * 0.6, 0.0, 1.0)
	return Color(r, g, b)

static func palette_electric(t: float, seed_val: int) -> Color:
	t = clampf(t, 0.0, 1.0)
	var h: int = splitmix32(int(t * 66666.0) ^ seed_val)
	var r: float = clampf(0.8 * float((h >> 8) & 0x3FF) / 1023.0, 0.0, 1.0)
	var g: float = clampf(0.4 + 1.2 * t * float((h >> 16) & 0x3FF) / 1023.0, 0.0, 1.0)
	var b: float = clampf(1.0 * float(h & 0x3FF) / 1023.0 + 0.5 * t, 0.0, 1.0)
	return Color(r, g, b)

static func palette_pick(t: float, seed_val: int, id: int) -> Color:
	var s: Array = [0, 0, 0, 0]
	rng_seed(s, seed_val ^ id * 0xDEADBEEF)
	var palette_type: int = rng_next_u32(s) % 6
	match palette_type:
		0: return palette_hell(t, seed_val ^ rng_next_u32(s))
		1: return palette_blood(t, seed_val ^ rng_next_u32(s))
		2: return palette_void(t, seed_val ^ rng_next_u32(s))
		3: return palette_electric(t, seed_val ^ rng_next_u32(s))
		_: return palette_hell(t * (0.5 + rng_f01(s)), seed_val ^ rng_next_u32(s))
