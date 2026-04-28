extends RigidBody2D

# Tap = speed (tuning)
@export var power_per_tap: float = 1.0      # tap power added per Space press
@export var power_decay: float = 2.5        # tap power lost per second
@export var speed_per_power: float = 200.0  # horizontal speed per 1.0 tap power
@export var max_speed: float = 2000.0       # speed clamp

# Ground follow (tuning)
@export var ray_length: float = 80.0        # GroundRay length downward (pixels)
@export var ride_height: float = 18.0       # distance above ground along its normal (≈ wheel radius)
@export var align_speed: float = 12.0       # rotation smoothing toward slope (higher = snappier)
@export var follow_pos_lerp: float = 12.0   # vertical smoothing toward ground (higher = snappier)

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
@onready var ground_ray: RayCast2D = get_node_or_null("GroundRay") as RayCast2D

func _ready() -> void:
	# Grouping lets other systems (e.g., LevelController) address the player.
	add_to_group("player")
	add_to_group("input_receivers")
	add_to_group("freezable")

	# Ensure the ground ray is vertical, long enough, and enabled.
	if ground_ray:
		ground_ray.global_rotation = 0.0
		ground_ray.target_position = Vector2(0.0, ray_length)
		ground_ray.enabled = true

	_update_energy_ui()

func _physics_process(delta: float) -> void:
	# Tap-to-accelerate (polling avoids UI Controls consuming the key event).
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	# We move manually; disable body-driven motion.
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = false

	# Convert tap power → horizontal speed (with decay and clamp).
	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)
	global_position.x += speed_x * delta

	# Keep the player aligned to and just above the ground.
	_follow_and_align_to_ground(delta)

	_update_animation()

func on_pedal_tap() -> void:
	if input_locked or frozen:
		return
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()

func _follow_and_align_to_ground(delta: float) -> void:
	if ground_ray == null:
		# No ray available: slowly rotate back to flat.
		rotation = lerp_angle(rotation, 0.0, clamp(align_speed * delta, 0.0, 1.0))
		return

	# Cast straight down each frame (keeps it vertical even if the player rotates).
	ground_ray.global_rotation = 0.0
	ground_ray.target_position = Vector2(0.0, ray_length)
	ground_ray.force_raycast_update()

	if ground_ray.is_colliding():
		var hit_pos: Vector2 = ground_ray.get_collision_point()
		var n: Vector2 = ground_ray.get_collision_normal().normalized()

		# Position: stay ride_height above the surface along its normal (prevents sinking on slopes).
		var target_y: float = (hit_pos - n * ride_height).y
		var pos_lerp: float = clamp(follow_pos_lerp * delta, 0.0, 1.0)
		global_position.y = lerp(global_position.y, target_y, pos_lerp)

	# Rotation: align with the ground tangent, facing right.
		var tangent_right: Vector2 = Vector2(-n.y, n.x)
		if tangent_right.x < 0.0:
			tangent_right = -tangent_right
		var target_angle: float = tangent_right.angle()
		rotation = lerp_angle(rotation, target_angle, clamp(align_speed * delta, 0.0, 1.0))
	else:
		# If we’re airborne or between tiles: gently rotate toward flat.
		rotation = lerp_angle(rotation, 0.0, clamp(align_speed * delta, 0.0, 1.0))

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
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
