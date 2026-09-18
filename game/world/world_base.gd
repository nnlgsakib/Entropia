# game/world/world_base.gd
class_name WorldBase
extends Node3D

@export var world_seed: int = 0
@export var world_name: String = "Untitled"

func _ready() -> void:
    _initialize_world()

func _initialize_world() -> void:
    pass
