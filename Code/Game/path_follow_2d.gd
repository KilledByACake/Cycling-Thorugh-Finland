extends PathFollow2D

@export var max_speed: float = 3000.0           # clamp for path speed (pixels/sec)
@export var loop_path: bool = false
@export var lock_when_reached_end: bool = true

# Map sensor speed (km/h) → path speed (pixels/sec). Tune to match your scene scale.
@export var speed_kmh_to_path_speed: float = 30.0

# Asymmetric responsiveness (units/sec^2): slower ramp-up, faster slowdown (coasting feel)
@export var accel_up_units: float = 2500.0
@export var decel_units: float = 6000.0

# Treat tiny sensor noise as stopped
@export var stop_threshold_kmh: float = 0.3

# Markers and path
@export_node_path("Node2D") var start_marker_path: NodePath
@export_node_path("Node2D") var end_marker_path: NodePath
@export var search_samples: int = 600
@export var wait_frames_for_curve: int = 5

# State
var speed_x: float = 0.0        # current path speed (pixels/sec)
var input_locked: bool = false
var frozen: bool = false
var start_offset: float = 0.0
var end_offset: float = 0.0
var prev_progress: float = 0.0

# Reference to child (Player)
@onready var rider: Node2D = get_node_or_null("Radler")

func _ready() -> void:
	if rider:
		rider.position = Vector2.ZERO  # reset child position
	
	await _wait_for_curve_ready()
	_compute_start_end_offsets()
	
	progress = start_offset
	prev_progress = progress

func _physics_process(delta: float) -> void:
	if frozen or input_locked:
		return

	# Read live bike speed (km/h) from your sensor/autoload (same as Dashboard)
	var speed_kmh: float = 0.0
	var sv: Variant = GlobalWahoo.get("speed")
	if typeof(sv) == TYPE_FLOAT or typeof(sv) == TYPE_INT:
		speed_kmh = float(sv)

	# Target path speed in pixels/sec
	var target_speed: float = speed_kmh * speed_kmh_to_path_speed
	if speed_kmh < stop_threshold_kmh:
		target_speed = 0.0

	# Asymmetric smoothing: ramp up modestly, slow down quickly (coasting)
	var rate: float = accel_up_units if target_speed > speed_x else decel_units
	speed_x = move_toward(speed_x, target_speed, rate * delta)
	speed_x = clamp(speed_x, 0.0, max_speed)

	# Move along path
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

# --- Helpers (unchanged) ---

func _wait_for_curve_ready() -> void:
	for i in range(wait_frames_for_curve):
		var p2d = get_parent()
		if p2d is Path2D and p2d.curve and p2d.curve.get_baked_length() > 10.0:
			break
		await get_tree().process_frame

func _compute_start_end_offsets() -> void:
	var p2d = get_parent()
	if not p2d or not p2d is Path2D or not p2d.curve:
		return
	var length = p2d.curve.get_baked_length()
	start_offset = p2d.curve.get_closest_offset(p2d.to_local(get_node(start_marker_path).global_position)) if not start_marker_path.is_empty() else 0.0
	end_offset = p2d.curve.get_closest_offset(p2d.to_local(get_node(end_marker_path).global_position)) if not end_marker_path.is_empty() else length
