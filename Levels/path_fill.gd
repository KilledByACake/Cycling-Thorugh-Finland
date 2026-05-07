@tool
extends Polygon2D

@export var path: Path2D

func _ready():
	if path:
		polygon = path.curve.get_baked_points()
