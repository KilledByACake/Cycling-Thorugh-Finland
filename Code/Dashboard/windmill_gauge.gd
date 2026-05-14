@tool
extends Control

@export var min_value: float = 0.0
@export var max_value: float = 500.0
@export var value: float = 0.0 : set = set_value

@export var arc_color: Color = Color8(181, 143, 25, 255)
@export var thickness_px: float = 24.0
@export var margin_px: float = 0.0
@export var side_inset_px: float = 0.0

@export var needle_color: Color = Color(0.18, 0.18, 0.18, 0.95)
@export var needle_width_px: float = 8.0
@export var needle_inner_ratio: float = 0.15

@export var source_label_path: NodePath

var _label_ref: Label
var _last_text: String = ""

# Sets the gauge value within bounds and schedules a redraw.
func set_value(v: float) -> void:
	var clamped := clampf(v, min_value, max_value)
	if is_equal_approx(clamped, value):
		return
	value = clamped
	print("Dashboard: wind =", value)
	queue_redraw()

# Prepares redraw hooks, enables polling, and binds the label source.
func _ready() -> void:
	resized.connect(func(): queue_redraw())
	set_process(true)
	_bind_label()
	queue_redraw()

# Draws the arc and the needle for the current value.
func _draw() -> void:
	var s: Vector2 = size
	if s.x <= 1.0 or s.y <= 1.0:
		return

	var half_t := thickness_px * 0.5
	var inset := maxf(side_inset_px, half_t)
	var usable_w: float = maxf(1.0, s.x - 2.0 * inset)

	var radius: float = minf(usable_w * 0.5, s.y - margin_px) - half_t
	radius = maxf(radius, 1.0)
	var center: Vector2 = Vector2(s.x * 0.5, s.y - margin_px)

	var a_start: float = PI
	var a_end: float = TAU
	var segs: int = 96

	draw_arc(center, radius, a_start, a_end, segs, arc_color, thickness_px, true)
	var cap_r: float = half_t
	draw_circle(center + Vector2(cos(a_start), sin(a_start)) * radius, cap_r, arc_color)
	draw_circle(center + Vector2(cos(a_end), sin(a_end)) * radius, cap_r, arc_color)

	var t: float = (value - min_value) / maxf(0.00001, max_value - min_value)
	var ang: float = lerpf(a_start, a_end, t)
	var dir: Vector2 = Vector2(cos(ang), sin(ang))

	var tip: Vector2 = center + dir * radius
	var base: Vector2 = center + dir * (radius * needle_inner_ratio)

	var half_w: float = maxf(needle_width_px * 0.5, 1.0)
	var perp: Vector2 = Vector2(-dir.y, dir.x) * half_w
	var poly: PackedVector2Array = PackedVector2Array([base + perp, base - perp, tip])
	draw_colored_polygon(poly, needle_color)
	draw_circle(base, half_w, needle_color)

# Polls the label, parses the first number, and updates the gauge when text changes.
func _process(_delta: float) -> void:
	if _label_ref == null:
		_bind_label()
		return
	var t := _label_ref.text
	if t == _last_text:
		return
	_last_text = t
	var watts := _extract_first_float(t)
	set_value(watts)

# Resolves the label from the exported path or common fallback names.
func _bind_label() -> void:
	if source_label_path != NodePath():
		var n := get_node_or_null(source_label_path)
		if n and n is Label:
			_set_label(n)
			return
	var candidate := find_child("powerWind", true, false)
	if candidate and candidate is Label:
		_set_label(candidate)
		return
	var alt := find_child("HighUnitLabel", true, false)
	if alt and alt is Label:
		_set_label(alt)

# Stores the label reference and triggers an immediate value update.
func _set_label(l: Label) -> void:
	_label_ref = l
	_last_text = ""
	if _label_ref:
		var watts := _extract_first_float(_label_ref.text)
		set_value(watts)

# Extracts the first floating-point number from a string.
func _extract_first_float(s: String) -> float:
	var re := RegEx.new()
	re.compile(r"[-+]?\d+(?:[.,]\d+)?")
	var m := re.search(s)
	if m:
		var t := m.get_string().replace(",", ".")
		return float(t)
	return 0.0
