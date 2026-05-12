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

# Clamps and sets the value, then schedules a redraw.
func set_value(v: float) -> void:
	value = clampf(v, min_value, max_value)
	queue_redraw()

# Hooks resize to redraw and triggers the first draw.
func _ready() -> void:
	resized.connect(func(): queue_redraw())
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
