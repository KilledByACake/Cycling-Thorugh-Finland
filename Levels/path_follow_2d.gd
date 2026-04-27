extends PathFollow2D

# Tap = speed (tuning)
@export var power_per_tap: float = 1.0      # tap power added per Space press
@export var power_decay: float = 2.5        # tap power lost per second
@export var speed_per_power: float = 200.0  # horizontal speed per 1.0 tap power
@export var max_speed: float = 2000.0       # speed clamp

# Path follow (tuning)
@export var loop_path: bool = false         # must be false to clamp at PathRight

# Start/end markers on the Path2D (assign PathLeft and PathRight)
@export_node_path("Node2D") var start_marker_path: NodePath
@export_node_path("Node2D") var end_marker_path: NodePath
@export var search_samples: int = 600       # samples to find nearest offsets to markers
@export var lock_when_reached_end: bool = true  # stop input when reaching PathRight

# Score
@export var energy_per_tap: int = 5

# Runtime state
var tap_power: float = 0.0
var speed_x: float = 0.0
var energy_points: int = 0
var input_locked: bool = false
var frozen: bool = false

# Computed offsets (pixels along the curve)
var start_offset: float = 0.0
var end_offset: float = 0.0
var prev_progress: float = 0.0

# Node references
@onready var rider: Node2D = get_node_or_null("Radler") as Node2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("Radler/AnimatedSprite2D") as AnimatedSprite2D

func _ready() -> void:
	# Keep Inspector v_offset; clean transform.
	scale = Vector2.ONE
	rotates = true
	loop = loop_path
	if rider:
		rider.scale = Vector2.ONE
		rider.rotation = 0.0

	# Wait one frame so Path2D (and auto-build) updates the curve.
	await get_tree().process_frame
	_compute_start_end_offsets()

	# Start at PathLeft (or at curve start if no marker).
	progress = start_offset
	prev_progress = progress
	input_locked = false  # ensure not locked at start

	_update_energy_ui()

func _physics_process(delta: float) -> void:
	if not input_locked and not frozen and Input.is_action_just_pressed("ui_accept"):
		on_pedal_tap()

	tap_power = max(0.0, tap_power - power_decay * delta)
	speed_x = clamp(tap_power * speed_per_power, 0.0, max_speed)

	var new_progress: float = progress + speed_x * delta
	if not loop and new_progress > end_offset:
		new_progress = end_offset

	var reached_end_now: bool = (not loop) and (prev_progress < end_offset - 0.001) and (new_progress >= end_offset - 0.001)

	progress = new_progress
	prev_progress = progress

	if reached_end_now and lock_when_reached_end:
		input_locked = true
		tap_power = 0.0
		speed_x = 0.0

	_update_animation()

func on_pedal_tap() -> void:
	if input_locked or frozen:
		return
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()

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
	# Send the energy value to the level root so the UI updates.
	var level := get_tree().current_scene
	if level and level.has_method("update_energy_UI"):
		level.update_energy_UI(energy_points)

# Compute start_offset (near PathLeft) and end_offset (near PathRight)
func _compute_start_end_offsets() -> void:
	var p2d := get_parent() as Path2D
	if p2d == null or p2d.curve == null:
		start_offset = 0.0
		end_offset = 0.0
		return

	var length: float = p2d.curve.get_baked_length()
	if length <= 0.0:
		start_offset = 0.0
		end_offset = 0.0
		return

	start_offset = _offset_from_marker(p2d, start_marker_path, 0.0, length)
	end_offset = _offset_from_marker(p2d, end_marker_path, length, length)

	# Ensure start <= end. If they collapse, fall back to full length so we can move.
	if end_offset < start_offset:
		var tmp := start_offset
		start_offset = end_offset
		end_offset = tmp
	if end_offset <= start_offset + 1.0:
		end_offset = length

# Find the closest curve offset to a given marker; fallback if no marker.
func _offset_from_marker(p2d: Path2D, marker_path: NodePath, fallback: float, length: float) -> float:
	if marker_path.is_empty():
		return fallback
	var marker := get_node_or_null(marker_path) as Node2D
	if marker == null:
		return fallback

	var local_target: Vector2 = p2d.to_local(marker.global_position)
	var samples: int = max(1, search_samples)
	var step: float = length / float(samples)

	var best_offset: float = fallback
	var best_dist: float = INF
	var off: float = 0.0
	while off <= length:
		var pt: Vector2 = p2d.curve.sample_baked(off)
		var d: float = pt.distance_to(local_target)
		if d < best_dist:
			best_dist = d
			best_offset = off
		off += step
	return best_offset

# Hooks (optional)
func lock_input(v: bool) -> void:
	input_locked = v

func freeze() -> void:
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
