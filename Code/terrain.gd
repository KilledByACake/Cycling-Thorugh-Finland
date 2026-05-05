@tool
extends Node2D

# ---- Terrain settings ----
@export var rng_seed: int = 42
@export var length: int = 160000
@export var base_y: float = 420.0
@export var amplitude: float = 80.0
@export var noise_frequency: float = 0.0018
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.4
@export var sample_step: int = 4
@export var max_slope_deg: float = 18.0

# How far down to close the ground polygon (pixels). Increase to avoid “air” below the ground.
@export var ground_thickness: float = 800.0

# Editor button to force regeneration
@export var regenerate: bool = false:
	set(value):
		regenerate = false
		_generate()

@onready var polygon: Polygon2D = get_node_or_null("Polygon2D")

var _top_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	#$Polygon2D.uv = $Polygon2D.polygon
	_generate()

func _generate() -> void:
	if polygon == null:
		return

	_top_points.clear()
	_top_points.resize(0)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var off1: float = rng.randf_range(0.0, 1000.0)
	var off2: float = rng.randf_range(0.0, 1000.0)

	var x: int = 0
	var prev_y: float = base_y
	var slope_limit: float = tan(deg_to_rad(max_slope_deg))

	while x <= length:
		# Simple layered sines (cheap and deterministic)
		var y: float = sin((x * noise_frequency) + off1) * amplitude
		y += sin((x * noise_frequency) * 2.1 + off2) * (amplitude * 0.35 * (0.7 + difficulty * 0.6))
		var target_y: float = base_y + y

		# Optional slope limiting
		if _top_points.size() > 0:
			var dy: float = target_y - prev_y
			var dx: float = float(sample_step)
			var s: float = dy / dx
			if abs(s) > slope_limit:
				target_y = prev_y + clamp(s, -slope_limit, slope_limit) * dx

		_top_points.append(Vector2(x, target_y))
		prev_y = target_y
		x += sample_step

	# Close the polygon deeper using ground_thickness (avoid “air” below ground)
	var bottom_y: float = base_y + abs(amplitude) + ground_thickness

	var poly: PackedVector2Array = PackedVector2Array(_top_points)
	poly.append(Vector2(length, bottom_y))
	poly.append(Vector2(0.0, bottom_y))
	polygon.polygon = poly

	# Simple UVs for gradient 
	var uvs: PackedVector2Array = PackedVector2Array()
	#var y_min: float = base_y - amplitude
	#var y_range: float = (bottom_y - y_min)
		
	#actual length of terrain	
	var actual_length: float = _top_points[-1].x
	# Und die UVs anpassen:
	for p in _top_points:
		var u: float = (p.x / float(actual_length) * 255)
		uvs.append(Vector2(u, 0.0))

	uvs.append(Vector2(0.0, 0.0))    # bottom left
	uvs.append(Vector2(255.0, 0.0	))  # bottom right
	print(_top_points[0], _top_points[-1])
	
	polygon.uv = uvs
	
	if polygon.texture is GradientTexture2D:
		polygon.texture.width = 256
		polygon.texture.height = 1	
			
func get_top_points() -> PackedVector2Array:
	return _top_points.duplicate()

# Height on the ground at a given X (local space)
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
