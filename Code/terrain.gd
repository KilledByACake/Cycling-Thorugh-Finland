@tool
extends Node2D

# --- Settings ---
@export var hill_seed: int = 42
@export var width: int = 6000
@export var base_y: int = 400
@export var amplitude: float = 80.0
@export var frequency: float = 0.005

# Regenerate in editor when any export var changes
@export var regenerate: bool = false:
	set(v):
		regenerate = false
		_setup_gradient()
		_generate(hill_seed)

@onready var polygon = $Polygon2D

func _ready():
	_setup_gradient()
	_generate(hill_seed)

# -------------------------------------------------------
# GRADIENT SETUP
# -------------------------------------------------------
func _setup_gradient():
	var polygon_node = get_node_or_null("Polygon2D")
	if polygon_node == null:
		return

	var gradient = Gradient.new()
	# Remove default points first
	gradient.remove_point(1)
	gradient.remove_point(0)
	gradient.add_point(0.00, Color("#927548"))
	gradient.add_point(0.12, Color("#4F7941"))
	gradient.add_point(0.24, Color("#365C58"))
	gradient.add_point(0.39, Color("#3B455C"))
	gradient.add_point(0.52, Color("#6A5A36"))
	gradient.add_point(0.66, Color("#7C3931"))
	gradient.add_point(0.82, Color("#5B3B5C"))
	gradient.add_point(0.98, Color("#283246"))

	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to   = Vector2(0.5, 1.0)
	grad_tex.width  = 2
	grad_tex.height = 256

	polygon_node.texture = grad_tex
	polygon_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# -------------------------------------------------------
# HILL GENERATION
# -------------------------------------------------------
func _generate(s: int):
	var polygon_node = get_node_or_null("Polygon2D")
	if polygon_node == null:
		push_warning("Hill: No Polygon2D child found!")
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = s

	var offset1 = rng.randf_range(0, 1000)
	var offset2 = rng.randf_range(0, 1000)
	var offset3 = rng.randf_range(0, 1000)

	var top_points = PackedVector2Array()
	var bottom_y = base_y + amplitude + 200

	for x in range(width + 1):
		var y = sin(x * frequency         + offset1) * amplitude
		y     += sin(x * frequency * 2.3  + offset2) * (amplitude * 0.4)
		y     += sin(x * frequency * 5.1  + offset3) * (amplitude * 0.15)
		top_points.append(Vector2(x, base_y + y))

	var poly = PackedVector2Array(top_points)
	poly.append(Vector2(width, bottom_y))
	poly.append(Vector2(0,     bottom_y))
	polygon_node.polygon = poly

	# UVs
	var uvs = PackedVector2Array()
	var y_min = base_y - amplitude
	var y_range = bottom_y - y_min

	for p in top_points:
		var u = p.x / float(width)
		var v = (p.y - y_min) / y_range
		uvs.append(Vector2(u, v))

	uvs.append(Vector2(1.0, 1.0))
	uvs.append(Vector2(0.0, 1.0))
	polygon_node.uv = uvs
