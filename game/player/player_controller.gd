extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_multiplier: float = 1.5
@export var jump_force: float = 7.0
@export var crouch_speed: float = 2.5
@export var crouch_height: float = 0.5
@export var gravity: float = 20.0
@export var deceleration_factor: float = 10.0

@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _default_height: float = 0.0
var _current_height: float = 0.0
var _is_crouching: bool = false

func _ready() -> void:
	_default_height = _collision.shape.height
	_current_height = _default_height

func _physics_process(delta: float) -> void:
	_handle_crouch()
	_handle_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_camera_pivot.apply_yaw_to_parent()
	move_and_slide()

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	input_dir = input_dir.normalized()

	var speed := walk_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier
	if _is_crouching:
		speed = crouch_speed

	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	direction = direction.rotated(Vector3.UP, _camera_pivot.get_yaw())

	if direction.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * deceleration_factor)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * deceleration_factor)

func _handle_crouch() -> void:
	var wants_crouch := Input.is_action_pressed("crouch")
	if wants_crouch and not _is_crouching:
		_is_crouching = true
		_current_height = _default_height * crouch_height
		_collision.shape.height = _current_height
		_camera_pivot.position.y = _current_height * 0.5
	elif not wants_crouch and _is_crouching:
		_is_crouching = false
		_current_height = _default_height
		_collision.shape.height = _current_height
		_camera_pivot.position.y = _current_height * 0.5
