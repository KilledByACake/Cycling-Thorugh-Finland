extends PathFollow2D

@export var max_speed: float = 2000.0
@export var power_to_speed_multiplier: float = 5.0 
@export var loop_path: bool = false
@export var lock_when_reached_end: bool = true

# Markers y Path
@export_node_path("Node2D") var start_marker_path: NodePath
@export_node_path("Node2D") var end_marker_path: NodePath
@export var search_samples: int = 600
@export var wait_frames_for_curve: int = 5

# Estado
var speed_x: float = 0.0
var input_locked: bool = false
var frozen: bool = false
var start_offset: float = 0.0
var end_offset: float = 0.0
var prev_progress: float = 0.0

# Referencia al hijo (Player)
@onready var rider: Node2D = get_node_or_null("Radler")

func _ready() -> void:
	if rider:
		rider.position = Vector2.ZERO # Reset de posición del hijo
	
	await _wait_for_curve_ready()
	_compute_start_end_offsets()
	
	progress = start_offset
	prev_progress = progress

func _physics_process(delta: float) -> void:
	if frozen or input_locked: return

	# Cálculo de velocidad del sensor
	var target_speed = GlobalWahoo.power * power_to_speed_multiplier
	speed_x = lerp(speed_x, target_speed, 4.0 * delta)
	speed_x = clamp(speed_x, 0.0, max_speed)

	# Movimiento físico por el Path
	if speed_x > 0.1:
		progress += speed_x * delta
		
		if not loop and progress > end_offset:
			progress = end_offset

		var reached_end_now = (not loop) and (prev_progress < end_offset - 0.1) and (progress >= end_offset - 0.1)
		prev_progress = progress

		if reached_end_now and lock_when_reached_end:
			input_locked = true
			speed_x = 0.0

# --- Helper Functions (Iguales para no romper el camino) ---

func _wait_for_curve_ready() -> void:
	for i in range(wait_frames_for_curve):
		var p2d = get_parent()
		if p2d is Path2D and p2d.curve and p2d.curve.get_baked_length() > 10.0:
			break
		await get_tree().process_frame

func _compute_start_end_offsets() -> void:
	var p2d = get_parent()
	if not p2d or not p2d is Path2D or not p2d.curve: return
	var length = p2d.curve.get_baked_length()
	start_offset = p2d.curve.get_closest_offset(p2d.to_local(get_node(start_marker_path).global_position)) if not start_marker_path.is_empty() else 0.0
	end_offset = p2d.curve.get_closest_offset(p2d.to_local(get_node(end_marker_path).global_position)) if not end_marker_path.is_empty() else length
