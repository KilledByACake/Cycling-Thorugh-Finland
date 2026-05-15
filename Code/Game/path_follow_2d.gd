extends PathFollow2D

@export var max_speed: float = 2000.0
@export var power_to_speed_multiplier: float = 5.0
@export var loop_path: bool = false
@export var lock_when_reached_end: bool = true

# Use speed (km/h) to path speed when power is near zero
@export var speed_kmh_to_path_speed: float = 20.0  # km/h → path units per second

# Markers and path
@export_node_path("Node2D") var start_marker_path: NodePath
@export_node_path("Node2D") var end_marker_path: NodePath
@export var search_samples: int = 600
@export var wait_frames_for_curve: int = 5

# State
var speed_x: float = 0.0
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

	# Compute desired path speed from sensor input.
	# Prefer power; if power is near zero, fall back to speed (km/h).
	var power_w: float = 0.0
	var speed_kmh: float = 0.0

	var pv: Variant = GlobalWahoo.get("power")
	if typeof(pv) == TYPE_FLOAT or typeof(pv) == TYPE_INT:
		power_w = float(pv)

	var sv: Variant = GlobalWahoo.get("speed")
	if typeof(sv) == TYPE_FLOAT or typeof(sv) == TYPE_INT:
		speed_kmh = float(sv)

	var target_speed: float = 0.0
	if power_w > 1.0:
		target_speed = power_w * power_to_speed_multiplier
	else:
		target_speed = speed_kmh * speed_kmh_to_path_speed

	speed_x = lerp(speed_x, target_speed, 4.0 * delta)
	speed_x = clamp(speed_x, 0.0, max_speed)

	# Move along the path
	if speed_x > 0.1:
		progress += speed_x * delta
		
		# Respect end offset if not looping
		if not loop and progress > end_offset:
			progress = end_offset

		var reached_end_now: bool = (not loop) and (prev_progress < end_offset - 0.1) and (progress >= end_offset - 0.1)
		prev_progress = progress

		if reached_end_now and lock_when_reached_end:
			input_locked = true
			speed_x = 0.0

# --- Helpers (unchanged behavior) ---

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
