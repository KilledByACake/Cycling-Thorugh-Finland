@tool
extends Node2D

# ---- Terrain settings ----
@export var rng_seed: int = 42
@export var length: int = 125500
@export var base_y: float = 420.0
@export var amplitude: float = 1000.0
@export var noise_frequency: float = 0.0018
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.4
@export var sample_step: int = 4
@export var max_slope_deg: float = 100.0

# How far down the polygon is closed below the surface
@export var ground_thickness: float = 400.0

# Editor button to regenerate the terrain without running the game
@export var regenerate: bool = false:
	set(value):
		regenerate = false
		_generate()

@onready var polygon: Polygon2D = get_node_or_null("Polygon2D")

# Stores the top surface points of the terrain
var _top_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_generate()

func _generate() -> void:
	if polygon == null:
		return
	_top_points.clear()

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Use system entropy so the seed is different each run
	rng.randomize()
	# Optional: store the actual seed used (handy for debugging/repro later)
	rng_seed = int(rng.seed)

	var off1: float = rng.randf_range(0.0, 1000.0)
	var off2: float = rng.randf_range(0.0, 1000.0)
	var off3: float = rng.randf_range(0.0, 1000.0)
	# var off4: float = rng.randf_range(0.0, 1000.0) # more randomness - fast small bumps

	var x: int = 0
	var prev_y: float = base_y
	var slope_limit: float = tan(deg_to_rad(max_slope_deg))

	# Generate surface points using layered sine waves
	while x <= length:
		var y: float = sin((x * noise_frequency) + off1) * amplitude
		y += sin((x * noise_frequency) * 2.1 + off2) * (amplitude * 0.35 * (0.7 + difficulty * 0.6))
		y += sin((x * noise_frequency) * 0.47 + off3) * (amplitude * 0.6)   # more randomness - slow large waves
		# y += sin((x * noise_frequency) * 5.3 + off4) * (amplitude * 0.15)
		var target_y: float = base_y + y

		# Limit steep slopes between consecutive points
		if _top_points.size() > 0:
			var dy: float = target_y - prev_y
			var dx: float = float(sample_step)
			var s: float = dy / dx
			if abs(s) > slope_limit:
				target_y = prev_y + clamp(s, -slope_limit, slope_limit) * dx

		_top_points.append(Vector2(x, target_y))
		prev_y = target_y
		x += sample_step

	# Close the polygon at the bottom to form a solid shape
	var bottom_y: float = base_y + abs(amplitude) + ground_thickness
	var poly: PackedVector2Array = PackedVector2Array(_top_points)
	poly.append(Vector2(length, bottom_y))
	poly.append(Vector2(0.0, bottom_y))
	polygon.polygon = poly

	# Pass the terrain width to the shader so the gradient stretches correctly
	if polygon.material:
		polygon.material.set_shader_parameter("terrain_start", 0.0)
		polygon.material.set_shader_parameter("terrain_end", float(length))

# Returns a copy of the top surface points for other nodes to use
func get_top_points() -> PackedVector2Array:
	return _top_points.duplicate()

# Returns the surface Y position at a given X in local space
func get_surface_y(x_pos: float) -> float:
	if _top_points.is_empty():
		return base_y
	x_pos = clamp(x_pos, 0.0, float(length))
	var step := float(max(1, sample_step))
	var idx: int = int(floor(x_pos / step))
	idx = clamp(idx, 0, _top_points.size() - 2)
	var p0: Vector2 = _top_points[idx]
	var p1: Vector2 = _top_points[idx + 1]
	var t: float = 0.0
	if p1.x != p0.x:
		t = (x_pos - p0.x) / (p1.x - p0.x)
	return lerp(p0.y, p1.y, t)
