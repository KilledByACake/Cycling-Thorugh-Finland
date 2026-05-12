extends CharacterBody2D

signal pedal_tapped

# Player controller: taps add power, which decays and drives horizontal speed (used by a PathFollow2D setup).

# Tap-to-speed tuning
@export var power_per_tap: float = 1.0       # Power added per tap
@export var power_decay: float = 2.5         # Power lost per second
@export var speed_per_power: float = 2000.0  # Horizontal speed per unit of power
@export var max_speed: float = 2000.0        # Maximum horizontal speed

# Score
@export var energy_per_tap: int = 5          # Energy points awarded per tap

# Animation
@export var pedal_anim_name: String = "rollen"  # Name of the pedaling animation present in every skin

# Runtime state
var tap_power: float = 0.0                   # Accumulated input power
var speed_x: float = 0.0                     # Current horizontal speed (pixels/sec)
var energy_points: int = 0                   # Score counter
var input_locked: bool = false               # If true, input is ignored
var frozen: bool = false                     # If true, motion/animation are stopped

# The currently selected AnimatedSprite2D skin (picked at startup)
var sprite: AnimatedSprite2D

# All AnimatedSprite2D children treated as skins (e.g., Felix, Magdalena, Hilla, Mikko)
var _skins: Array[AnimatedSprite2D] = []

# Random generator used to pick a skin
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Organize player into groups used elsewhere in the game
	add_to_group("player")
	add_to_group("radler")
	add_to_group("input_receivers")
	add_to_group("freezable")

	# Ensure the physics body starts at rest
	velocity = Vector2.ZERO

	# Gather all AnimatedSprite2D children and randomly select one to use
	_collect_skins()
	_choose_random_skin()

	# Initialize UI with current energy
	_update_energy_ui()


func _physics_process(delta: float) -> void:
	# Read tap input (Polling avoids UI controls consuming the event)
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	# Power decays over time; map power to capped horizontal speed
	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)

	# Drive animation speed based on movement speed
	_update_animation()


func on_pedal_tap() -> void:
	# Ignore taps when input is locked or the player is frozen
	if input_locked or frozen:
		return

	# Apply power and award energy
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()

	# Notify listeners that a pedal tap occurred
	emit_signal("pedal_tapped")


func _update_animation() -> void:
	# Safeguard: no animation when no skin is selected
	if sprite == null:
		return
		
	# If moving, play the pedal animation on the chosen skin and scale playback speed
	var s: float = speed_x
	if s > 1.0:
		# Play target animation only if needed to avoid restarting it constantly
		if sprite.animation != pedal_anim_name or not sprite.playing:
			# Play only if the animation exists on this skin; otherwise do nothing
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(pedal_anim_name):
				sprite.play(pedal_anim_name)
		# Speed-scale maps movement speed to animation speed within a safe range
		sprite.speed_scale = clamp(s / 120.0, 0.2, 8.0)
	else:
		# Stop when nearly stationary
		sprite.stop()
		
		
func _update_energy_ui() -> void:
	# If the parent provides a UI hook, push the current energy value to it
	var p: Node = get_parent()
	if p and p.has_method("update_energy_UI"):
		p.call("update_energy_UI", energy_points)


func lock_input(v: bool) -> void:
	# External API to disable/enable input handling
	input_locked = v


func freeze() -> void:
	# External API to freeze the player and clear motion/power
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
	velocity = Vector2.ZERO


# -------- Skin management --------

func _collect_skins() -> void:
	# Collect all immediate AnimatedSprite2D children (each is a visual skin)
	_skins.clear()
	for c in get_children():
		if c is AnimatedSprite2D:
			_skins.append(c)


func _choose_random_skin() -> void:
	# Select one skin at random and hide the others
	if _skins.is_empty():
		sprite = null
		return

	_rng.randomize()
	var idx := _rng.randi_range(0, _skins.size() - 1)
	var chosen := _skins[idx]

	for s in _skins:
		s.stop()
		s.visible = (s == chosen)

	sprite = chosen


func reshuffle_skin() -> void:
	# Public method to pick a new random skin (e.g., on respawn/new round)
	_choose_random_skin()
