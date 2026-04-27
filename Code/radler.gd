extends RigidBody2D

# Tap → speed
@export var power_per_tap: float = 1.0
@export var power_decay: float = 2.5
@export var speed_per_power: float = 200.0
@export var max_speed: float = 2000.0

# Slope follow
@export var ray_length: float = 80.0      # how far down we search for ground
@export var ride_height: float = 18.0     # distance to keep above hit point
@export var align_speed: float = 12.0     # how fast we rotate to match slope

# Score
@export var energy_per_tap: int = 5

var tap_power: float = 0.0
var speed_x: float = 0.0
var energy_points: int = 0
var input_locked: bool = false
var frozen: bool = false

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var ground_ray: RayCast2D = get_node_or_null("GroundRay") as RayCast2D

func _ready() -> void:
	add_to_group("player")
	add_to_group("input_receivers")
	add_to_group("freezable")
	if ground_ray:
		ground_ray.target_position = Vector2(0.0, ray_length)
		ground_ray.enabled = true
	_update_energy_ui()

func _physics_process(delta: float) -> void:
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	# Manual movement only
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = false

	# Speed from tap power
	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)
	global_position.x += speed_x * delta

	# Stick to ground and align to slope
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
		# No ray: relax rotation toward flat
		rotation = lerp_angle(rotation, 0.0, align_speed * delta)
		return

	# Ensure the ray is long enough each frame (in case you tweak in inspector)
	ground_ray.target_position = Vector2(0.0, ray_length)
	ground_ray.force_raycast_update()

	if ground_ray.is_colliding():
		var hit_pos: Vector2 = ground_ray.get_collision_point()
		var n: Vector2 = ground_ray.get_collision_normal()

		# Keep a fixed height above ground
		global_position.y = hit_pos.y - ride_height

		# Rotate to face "right" along the surface (tangent pointing to the right)
		var tangent_right: Vector2 = Vector2(-n.y, n.x)
		if tangent_right.x < 0.0:
			tangent_right = -tangent_right
		var target_angle: float = tangent_right.angle()
		rotation = lerp_angle(rotation, target_angle, align_speed * delta)
	else:
		# If not hitting ground, relax toward flat
		rotation = lerp_angle(rotation, 0.0, align_speed * delta)

func _update_animation() -> void:
	if sprite == null:
		return
	var s: float = speed_x
	if s > 1.0:
		sprite.play("rollen")
		sprite.speed_scale = clamp(s / 120.0, 0.2, 8.0)
	else:
		sprite.stop()

func _update_energy_ui() -> void:
	var p := get_parent()
	if p and p.has_method("update_energy_UI"):
		p.update_energy_UI(energy_points)

func lock_input(v: bool) -> void:
	input_locked = v

func freeze() -> void:
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sleeping = true
