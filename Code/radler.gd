extends CharacterBody2D

signal pedal_tapped

# Tap = speed (tuning)
@export var power_per_tap: float = 4.0      # 1.0 tap power added per Space press
@export var power_decay: float = 2.5        # tap power lost per second
@export var speed_per_power: float = 200.0  # horizontal speed per 1.0 tap power
@export var max_speed: float = 20000.0       #2000.0 speed clamp

# Ground follow (tuning)
# (PathFollow2D now handles ground following; these are no longer used.)
# @export var ray_length: float = 80.0        # GroundRay length downward (pixels)
# @export var ride_height: float = 18.0       # distance above ground along its normal (≈ wheel radius)
# @export var align_speed: float = 12.0       # rotation smoothing toward slope (higher = snappier)
# @export var follow_pos_lerp: float = 12.0   # vertical smoothing toward ground (higher = snappier)

# Score
@export var energy_per_tap: int = 5

# Runtime state
var tap_power: float = 0.0                  # accumulates on tap; decays over time
var speed_x: float = 0.0                    # current rightward speed (pixels/sec)
var energy_points: int = 0
var input_locked: bool = false              # Game_Controller can disable input
var frozen: bool = false                    # Level_Controller can freeze the player

# Child nodes
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
# @onready var ground_ray: RayCast2D = get_node_or_null("GroundRay") as RayCast2D  # removed

func _ready() -> void:
	# Grouping lets other systems (e.g., LevelController) address the player.
	add_to_group("player")
	add_to_group("radler") 
	add_to_group("input_receivers")
	add_to_group("freezable")

	# CharacterBody2D uses `velocity`; make sure we start at rest.
	velocity = Vector2.ZERO

	_update_energy_ui()

func _physics_process(delta: float) -> void:
	# Tap-to-accelerate (polling avoids UI Controls consuming the key event).
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	# Convert tap power → horizontal speed (with decay and clamp).
	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)

	# We used to move/align with a GroundRay here.
	# PathFollow2D now controls position/rotation, so do NOT move this node manually.
	# global_position += Vector2(speed_x * delta, 0.0)  # disabled

	_update_animation()

func on_pedal_tap() -> void:
	if input_locked or frozen:
		return
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()
	emit_signal("pedal_tapped")

func _update_animation() -> void:
	# Speed drives animation rate.
	if sprite == null:
		return
	var s: float = speed_x
	if s > 1.0:
		sprite.play("rollen")
		sprite.speed_scale = clamp(s / 120.0, 0.2, 8.0)
	else:
		sprite.stop()

func _update_energy_ui() -> void:
	# Parent nodes can implement update_energy_UI(int).
	var p := get_parent()
	if p and p.has_method("update_energy_UI"):
		p.update_energy_UI(energy_points)

# Called by GameController
func lock_input(v: bool) -> void:
	input_locked = v

func freeze() -> void:
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
	# CharacterBody2D: clear velocity if you use it elsewhere later.
	velocity = Vector2.ZERO
