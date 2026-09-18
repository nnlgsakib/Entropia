# game/player/camera_controller.gd
extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0
@export var smoothing: float = 0.0

var _pitch: float = 0.0
var _yaw: float = 0.0
var _target_pitch: float = 0.0
var _target_yaw: float = 0.0

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _target_yaw -= event.relative.x * mouse_sensitivity
        _target_pitch -= event.relative.y * mouse_sensitivity
        _target_pitch = clamp(_target_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))

func _process(delta: float) -> void:
    if smoothing > 0.0:
        _pitch = lerp(_pitch, _target_pitch, smoothing * delta * 10.0)
        _yaw = lerp(_yaw, _target_yaw, smoothing * delta * 10.0)
    else:
        _pitch = _target_pitch
        _yaw = _target_yaw

    rotation.x = _pitch

func get_yaw() -> float:
    return _yaw

func apply_yaw_to_parent() -> void:
    if get_parent():
        get_parent().rotation.y = _yaw
