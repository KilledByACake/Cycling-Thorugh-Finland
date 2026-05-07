@tool
extends Polygon2D

@export var path: Path2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if path:
		#var points = path.curve.get_baked_points()
		#polygon = points
		polygon = path.curve.tessellate()
