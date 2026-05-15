extends PathFollow2D

# --- Tuning knobs ---

# Max path speed clamp (pixels/sec)
@export var max_speed: float = 8000.0

# Map sensor speed (km/h) → path speed (pixels/sec). Tune to match scene scale
@export var speed_kmh_to_path_speed: float = 60.0

# Extra multiplier to move faster along the path without changing HUD km/h
@export_range(0.1, 5.0, 0.05) var path_speed_multiplier: float = 1.5

# Asymmetric responsiveness (pixels/sec^2):
# ramp-up is usually slower, slowdown faster (coasting feel)
@export var accel_up_units: float = 4000.0
@export var decel_units: float = 9000.0

# Treat tiny sensor noise as stopped (km/h)
@export var stop_threshold_kmh: float = 0.3

# Loop and end behavior
@export var loop_path: bool = false
@export var lock_when_reached_end: bool = true

# Markers and path
@export_node_path("Node2D") var start_marker_path: NodePath
@export_node_path("Node2D") var end_marker_path: NodePath
@export var search_samples: int = 600
@export var wait_frames_for_curve: int = 5

# --- State ---

# Current path speed (pixels/sec)
var speed_x: float = 0.0
var input_locked: bool = false
var frozen: bool = false
var start_offset: float = 0.0
var end_offset: float = 0.0
var prev_progress: float = 0.0

# Reference to child (player/rider)
@onready var rider: Node2D = get_node_or_null("Player") as Node2D

func _ready() -> void:
	# Ensure PathFollow2D looping matches our exported flag
	loop = loop_path

	# Keep rider at the PathFollow2D origin
	if rider:
		rider.position = Vector2.ZERO

	await _wait_for_curve_ready()
	_compute_start_end_offsets()

	progress = start_offset
	prev_progress = progress

func _physics_process(delta: float) -> void:
	if frozen or input_locked:
		return

	# Read live bike speed (km/h) from autoload
	var speed_kmh: float = float(GlobalWahoo.speed)

	# Compute target path speed in pixels/sec
	var target_speed: float = speed_kmh * speed_kmh_to_path_speed
	if speed_kmh < stop_threshold_kmh:
		target_speed = 0.0

	# Apply extra path multiplier (single knob to move faster on the path)
	target_speed *= path_speed_multiplier

	# Smooth toward target speed (asymmetric)
	var rate: float = accel_up_units if target_speed > speed_x else decel_units
	speed_x = move_toward(speed_x, target_speed, rate * delta)
	speed_x = clamp(speed_x, 0.0, max_speed)

	# Move along the path
	if speed_x > 0.0:
		progress += speed_x * delta

		# Respect end offset if not looping
		if not loop_path and progress > end_offset:
			progress = end_offset

		var reached_end_now: bool = (not loop_path) and (prev_progress < end_offset - 0.1) and (progress >= end_offset - 0.1)
		prev_progress = progress

		if reached_end_now and lock_when_reached_end:
			input_locked = true
			speed_x = 0.0

# --- Helpers ---

func _wait_for_curve_ready() -> void:
	for i in range(wait_frames_for_curve):
		var p2d := get_parent()
		if p2d is Path2D and (p2d as Path2D).curve and (p2d as Path2D).curve.get_baked_length() > 10.0:
			break
		await get_tree().process_frame

func _compute_start_end_offsets() -> void:
	var p2d := get_parent()
	if not (p2d is Path2D):
		return
	var path := p2d as Path2D
	if path.curve == null:
		return

	var length: float = path.curve.get_baked_length()

	# Resolve start
	if not start_marker_path.is_empty():
		var start_nd := get_node_or_null(start_marker_path) as Node2D
		if start_nd:
			start_offset = path.curve.get_closest_offset(path.to_local(start_nd.global_position))
	else:
		start_offset = 0.0

	# Resolve end
	if not end_marker_path.is_empty():
		var end_nd := get_node_or_null(end_marker_path) as Node2D
		if end_nd:
			end_offset = path.curve.get_closest_offset(path.to_local(end_nd.global_position))
	else:
		end_offset = length
