@tool
extends PanelContainer
class_name PedalGauge

const BAR_SHADER_PATH := "res://Style/bar.gdshader"

@export var min_value: float = 0.0
@export var max_value: float = 500.0
@export var value: float = 0.0 : set = set_value

@export var needle_width: float = 12.0
@export var bar_corner_px: float = 24.0
@export var bar_col_left: Color  = Color(0.30, 0.75, 0.20, 1.0)
@export var bar_col_mid: Color   = Color(0.90, 0.85, 0.40, 1.0)
@export var bar_col_right: Color = Color(0.90, 0.25, 0.15, 1.0)

@onready var _bar: Control = $Control/Bar
@onready var _needle: ColorRect = $Control/Needle

# Sets up signals and defers initialization until layout is ready.
func _ready() -> void:
	resized.connect(_on_resized)
	call_deferred("_init_visuals")

# Ensures material, applies colors, and refreshes shader + needle.
func _init_visuals() -> void:
	_ensure_bar_material()
	_refresh_all()

# Updates visuals on resize.
func _on_resized() -> void:
	_refresh_all()

# Applies clamped value and updates needle.
func set_value(v: float) -> void:
	value = clampf(v, min_value, max_value)
	_update_needle()

# Ensures Bar has the gradient ShaderMaterial and makes it local to scene.
func _ensure_bar_material() -> void:
	if not _bar:
		return
	if _bar.material == null or not (_bar.material is ShaderMaterial):
		var sh: Shader = load(BAR_SHADER_PATH)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.resource_local_to_scene = true
		_bar.material = mat
	_apply_bar_colors()

# Applies gradient colors to the shader.
func _apply_bar_colors() -> void:
	if _bar.material is ShaderMaterial:
		var m: ShaderMaterial = _bar.material as ShaderMaterial
		m.set_shader_parameter("col_left",  bar_col_left)
		m.set_shader_parameter("col_mid",   bar_col_mid)
		m.set_shader_parameter("col_right", bar_col_right)

# Refreshes shader uniforms and needle together.
func _refresh_all() -> void:
	_update_bar_shader()
	_update_needle()

# Updates shader uniforms using on-screen pixel size.
func _update_bar_shader() -> void:
	if _bar and _bar.material is ShaderMaterial:
		var m: ShaderMaterial = _bar.material as ShaderMaterial
		var scale: Vector2 = _bar.get_global_transform().get_scale().abs()
		var px_size: Vector2 = _bar.size * scale
		m.set_shader_parameter("rect_size", px_size)
		m.set_shader_parameter("corner_px", bar_corner_px * max(scale.x, scale.y))

# Positions the needle and clamps it inside the bar.
func _update_needle() -> void:
	if not (is_instance_valid(_bar) and is_instance_valid(_needle)):
		return

	_needle.size = Vector2(needle_width, _bar.size.y)

	var denom: float = maxf(0.00001, max_value - min_value)
	var t: float = clampf((value - min_value) / denom, 0.0, 1.0)

	var x0: float = _bar.position.x
	var w: float = _bar.size.x

	var target_x: float = x0 + t * w - _needle.size.x * 0.5
	target_x = clampf(target_x, x0, x0 + w - _needle.size.x)

	_needle.position = Vector2(target_x, _bar.position.y)
	_needle.z_index = 100
