@tool
extends PanelContainer

@export var min_value: float = 0.0
@export var max_value: float = 500.0
@export var value: float = 0.0 : set = set_value

@onready var _bar: Control    = $Control/Bar
@onready var _needle: ColorRect = $Control/Needle  # now a ColorRect

func _ready() -> void:
	resized.connect(func(): _update_needle())
	call_deferred("_update_needle")

func set_value(v: float) -> void:
	value = clampf(v, min_value, max_value)
	call_deferred("_update_needle")
	
func _update_bar_shader() -> void:
	if _bar.material is ShaderMaterial:
		var m := _bar.material as ShaderMaterial
		m.set_shader_parameter("rect_size", _bar.size)
		m.set_shader_parameter("corner_px", 24.0)

func _update_needle() -> void:
	if not (is_instance_valid(_bar) and is_instance_valid(_needle)):
		return
	# make the needle a thin vertical rectangle with bar's height
	_needle.size = Vector2(12.0, _bar.size.y)

	var t: float = (value - min_value) / maxf(0.00001, max_value - min_value)
	var x: float = _bar.position.x + t * _bar.size.x

	# center the needle on x; align to bar on y
	_needle.position = Vector2(
		x - _needle.size.x * 0.5,
		_bar.position.y
	)
	_needle.z_index = 100
