# game/player/backrooms_player.gd
# First-person player for backrooms — walking only, no sprint
extends CharacterBody3D

@export var move_speed: float = 3.5
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 9.8

@onready var _camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensitivity
		_camera.rotation.x -= event.relative.y * mouse_sensitivity
		_camera.rotation.x = clampf(_camera.rotation.x, -PI / 2, PI / 2)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input.x, 0, input.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 0.15)
		velocity.z = move_toward(velocity.z, 0, move_speed * 0.15)

	move_and_slide()
