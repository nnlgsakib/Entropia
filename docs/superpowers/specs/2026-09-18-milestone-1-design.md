# Entropia — Milestone 1 Design

**Date:** 2026-09-18
**Status:** Approved
**Game:** Entropia
**Engine:** Godot 4.7.2

---

## Goal

Establish the project foundation: folder structure, first-person player controller, and a procedural test environment. Milestone 1 delivers a runnable scene where a player can move through a minimal lab space.

---

## Folder Structure

```
entropia/
├── core/
│   ├── math/
│   │   └── entro_math.gd        # Vector utilities, noise helpers
│   └── random/
│       └── entro_rng.gd          # Deterministic RNG wrapper
├── game/
│   ├── player/
│   │   ├── player.tscn           # CharacterBody3D + camera + collision
│   │   ├── player_controller.gd  # Movement, sprint, jump, crouch
│   │   └── camera_controller.gd  # Pitch/yaw, FOV, smoothing
│   └── world/
│       ├── world_base.gd         # Abstract world interface (future)
│       └── empty_lab.tscn        # Floor + lighting + sky
├── rendering/
│   └── environment_presets.gd    # Visual mode configs (placeholder)
├── ui/
│   ├── hud/
│   │   └── hud.tscn              # Minimal HUD overlay
│   └── menus/
│       └── main_menu.tscn        # Create/Join/Settings (placeholder)
├── shared/
│   └── autoload/
│       ├── game_manager.gd       # State machine, scene transitions
│       └── network_manager.gd    # Placeholder for Milestone 7
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-09-18-milestone-1-design.md
└── project.godot
```

### Structure Rationale

- **core/** — Pure utilities with no engine dependency. Math, random, serialization.
- **game/** — Gameplay logic. Player, world, tools, building.
- **rendering/** — Materials, shaders, procedural geometry, effects.
- **networking/** — Client, server, replication, protocol (added in Milestone 7).
- **ui/** — Menus, HUD, rule editor, server browser.
- **shared/** — Autoloads, global state, configuration.

This matches the layered architecture from the main spec section 34.

---

## Player Controller

### Node Tree

```
player.tscn
└── Player (CharacterBody3D)
    ├── CollisionShape3D (CapsuleShape3D)
    ├── CameraPivot (Node3D)
    │   └── Camera3D
    └── RayCast3D (floor detection)
```

### Movement

| Action | Input | Behavior |
|--------|-------|----------|
| Move forward | W | Relative to camera facing, horizontal plane |
| Move backward | S | Same |
| Move left | A | Same |
| Move right | D | Same |
| Sprint | Shift (hold) | 1.5x movement speed |
| Jump | Space | Impulse upward if `is_on_floor()` |
| Crouch | Ctrl (hold) | Capsule height → 0.5x, speed → 0.5x, smooth transition |
| Mouse look | Mouse movement | Yaw rotates player, pitch rotates camera pivot |

### Parameters

```gdscript
@export var walk_speed: float = 5.0
@export var sprint_multiplier: float = 1.5
@export var jump_force: float = 7.0
@export var crouch_speed: float = 2.5
@export var crouch_height: float = 0.5  # Multiplier on capsule height
@export var mouse_sensitivity: float = 0.002
@export var pitch_min: float = -89.0    # Degrees
@export var pitch_max: float = 89.0     # Degrees
@export var gravity: float = 20.0
```

### Camera Controller

- Attached to CameraPivot (Node3D)
- Pitch: clamped between pitch_min and pitch_max
- Yaw: applied to Player root rotation
- Smooth camera: optional lerp on pitch for feel
- FOV: 70° default (configurable for future sprint effect)

### Crouch Implementation

- Tween capsule height from full to crouched
- Raycast above to prevent crouching under overhangs (if needed later)
- Speed reduction while crouched

---

## Empty Lab

### Scene Tree

```
empty_lab.tscn
└── World (Node3D)
    ├── DirectionalLight3D (sun, slight angle)
    ├── WorldEnvironment
    │   └── Environment
    │       ├── sky: ProceduralSkyMaterial
    │       ├── ambient_light: sky
    │       ├── fog: enabled, dark gray, short distance
    │       └── tonemap: ACES
    ├── Floor (StaticBody3D)
    │   ├── MeshInstance3D (PlaneMesh, 200x200)
    │   └── CollisionShape3D
    ├── SpawnPoint (Marker3D)
    └── Player (instanced from player.tscn)
```

### Visual Style

- Floor: dark gray material with subtle grid lines
- Sky: dark procedural sky, deep blue-black
- Fog: short distance, dark gray, adds depth
- Lighting: single directional light, slight warm tint
- Accent: subtle blue-white point light in center

### Atmosphere

Clean, minimal, scientific. Like an empty physics laboratory. Not bright or cheerful. The environment should feel like a blank canvas waiting for simulation objects.

---

## Scenes

### Main Scene Flow

1. Game starts → `game_manager.gd` autoload runs
2. GameManager loads `main_menu.tscn` (placeholder for now, skip to game)
3. GameManager loads `empty_lab.tscn`
4. Player spawns at SpawnPoint

### Autoloads

```gdscript
# game_manager.gd
extends Node

enum State { MENU, LOADING, PLAYING, PAUSED }

var current_state: State = State.MENU
var current_seed: int = 0

func _ready() -> void:
    pass

func load_world(scene_path: String, seed: int = 0) -> void:
    current_seed = seed
    current_state = State.LOADING
    get_tree().change_scene_to_file(scene_path)
    current_state = State.PLAYING

func pause_game() -> void:
    get_tree().paused = true
    current_state = State.PAUSED

func resume_game() -> void:
    get_tree().paused = false
    current_state = State.PLAYING
```

```gdscript
# network_manager.gd
extends Node
# Placeholder for Milestone 7
```

---

## What Milestone 1 Does NOT Include

- No simulation systems
- No tools
- No building
- No rule graph
- No saving/loading
- No networking
- No multiplayer
- No UI beyond basic HUD
- No procedural geometry
- No particle systems

These are all Milestone 2+.

---

## Verification Criteria

Milestone 1 is complete when:

1. Project opens in Godot 4.7.2 without errors
2. `empty_lab.tscn` loads and displays correctly
3. Player can move with WASD on flat ground
4. Mouse look works (yaw + pitch, clamped)
5. Sprint increases speed
6. Jump works when on floor
7. Crouch reduces height and speed
8. Camera responds smoothly
9. No script errors in output
10. Scene runs at stable 60fps
