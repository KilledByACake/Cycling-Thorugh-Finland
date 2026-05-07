extends CharacterBody2D

signal pedal_tapped

# Player controller: taps add power, which decays to control horizontal speed via PathFollow2D.

# Tap-to-speed tuning
@export var power_per_tap: float = 1.0       # Tap adds this much power
@export var power_decay: float = 2.5         # Power lost per second
@export var speed_per_power: float = 2000.0  # Horizontal speed per 1.0 tap power
@export var max_speed: float = 2000.0        # Max horizontal speed

# Score
@export var energy_per_tap: int = 5

# Runtime state
var tap_power: float = 0.0                   # Accumulates on tap; decays over time
var speed_x: float = 0.0                     # Current rightward speed (pixels/sec)
var energy_points: int = 0
var input_locked: bool = false               # GameController can disable input
var frozen: bool = false                     # Level/scene can freeze the player

# Child nodes
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

# Called when added to the scene; initializes groups and state.
func _ready() -> void:
	add_to_group("player")
	add_to_group("radler")
	add_to_group("input_receivers")
	add_to_group("freezable")

	# Ensure CharacterBody2D starts at rest.
	velocity = Vector2.ZERO

	_update_energy_ui()

# Physics tick; reads input, updates power/speed, and animates.
func _physics_process(delta: float) -> void:
	# Tap-to-accelerate (polling avoids UI Controls consuming the key event).
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	# Convert tap power → horizontal speed (with decay and clamp).
	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)

	# Position/rotation are handled by PathFollow2D; do not move this node here.
	# global_position += Vector2(speed_x * delta, 0.0)  # intentionally disabled

	_update_animation()

# Handles a pedal tap; increases power/energy and notifies listeners.
func on_pedal_tap() -> void:
	if input_locked or frozen:
		return
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()
	emit_signal("pedal_tapped")

# Updates the pedaling animation based on horizontal speed.
func _update_animation() -> void:
	if sprite == null:
		return
	var s: float = speed_x
	if s > 1.0:
		sprite.play("rollen")
		sprite.speed_scale = clamp(s / 120.0, 0.2, 8.0)
	else:
		sprite.stop()

# Sends the current energy to a parent UI (if it implements update_energy_UI).
func _update_energy_ui() -> void:
	var p: Node = get_parent()
	if p and p.has_method("update_energy_UI"):
		p.call("update_energy_UI", energy_points)

# External API: lock/unlock input handling.
func lock_input(v: bool) -> void:
	input_locked = v

# External API: freeze movement and clear velocity/power.
func freeze() -> void:
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
	velocity = Vector2.ZERO
