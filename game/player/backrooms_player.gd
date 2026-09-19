# game/player/backrooms_player.gd
# First-person player — WASD + mouse look. Feel comes from the global Settings.
extends CharacterBody3D

@export var move_speed: float = 3.5
@export var gravity: float = 9.8
@export var pitch_min: float = -89.0
@export var pitch_max: float = 89.0

@onready var _camera: Camera3D = $Head/Camera3D


func _ready() -> void:
	add_to_group("player")
	_apply_settings()
	Settings.changed.connect(_apply_settings)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)


func _apply_settings() -> void:
	_camera.fov = Settings.fov


func _unhandled_input(event: InputEvent) -> void:
	# Only steer while the mouse is actually captured, so menus stay usable.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)


func _look(relative: Vector2) -> void:
	var sensitivity := Settings.mouse_sensitivity
	rotation.y -= relative.x * sensitivity
	var pitch_delta := relative.y * sensitivity
	if Settings.invert_y:
		pitch_delta = -pitch_delta
	_camera.rotation.x = clampf(_camera.rotation.x - pitch_delta, deg_to_rad(pitch_min), deg_to_rad(pitch_max))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		var deceleration := move_speed * 8.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, deceleration)
		velocity.z = move_toward(velocity.z, 0.0, deceleration)

	move_and_slide()
