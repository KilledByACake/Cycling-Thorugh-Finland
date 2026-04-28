@tool
extends Node2D

@export var rng_seed: int = 42
@export var length: int = 8000
@export var base_y: float = 420.0
@export var amplitude: float = 80.0
@export var noise_frequency: float = 0.0018
@export_range(0.0, 1.0, 0.01) var difficulty: float = 0.4
@export var sample_step: int = 4
@export var max_slope_deg: float = 18.0

@onready var polygon: Polygon2D = get_node_or_null("Polygon2D")

var _top_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_generate()

func _generate() -> void:
	if polygon == null:
		return

	_top_points.clear()
	_top_points.resize(0)

	var rng := RandomNumberGenerator.new()
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

	# Close polygon downwards
	var bottom_y: float = base_y + amplitude + 200.0
	var poly := PackedVector2Array(_top_points)
	poly.append(Vector2(length, bottom_y))
	poly.append(Vector2(0, bottom_y))
	polygon.polygon = poly

	# Simple UVs for gradient (optional)
	var uvs := PackedVector2Array()
	var y_min: float = base_y - amplitude
	var y_range: float = (bottom_y - y_min)
	for p in _top_points:
		var u: float = p.x / float(length)
		var v: float = (p.y - y_min) / y_range
		uvs.append(Vector2(u, v))
	uvs.append(Vector2(1.0, 1.0))
	uvs.append(Vector2(0.0, 1.0))
	polygon.uv = uvs

func get_top_points() -> PackedVector2Array:
	return _top_points.duplicate()
