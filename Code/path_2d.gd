@tool
extends Path2D
class_name PathAutoBuilder

# Helper segment type
class Segment:
	var a: Vector2
	var b: Vector2
	func _init(_a: Vector2, _b: Vector2) -> void:
		a = _a
		b = _b

# Ground polygon source (drag your Ground/CollisionPolygon2D here)
@export_node_path("CollisionPolygon2D") var ground_collision_path: NodePath

# Alternative visual ground (if you have no CollisionPolygon2D)
@export_node_path("Polygon2D") var ground_polygon2d_path: NodePath

# Alternative: your procedural Terrain node that exposes get_top_points()
@export_node_path("Node") var terrain_node_path: NodePath

# Optional markers to define the horizontal sampling range (recommended).
# Place two Node2D/Position2D as children anywhere you like, move them over the ground,
# then assign them here. Only their X is used.
@export_node_path("Node2D") var left_marker_path: NodePath
@export_node_path("Node2D") var right_marker_path: NodePath

# If markers are not set, we’ll sample across the polygon bounds, trimmed by this margin (pixels).
@export var x_margin: float = 8.0

# Path vertical lift. Keep 0.0 if you already use PathFollow2D's V Offset to lift the rider.
@export var ride_height: float = 0.0

# Sampling density across X (pixels) for CollisionPolygon2D-based build. Smaller = more points.
@export var sample_step: float = 16.0

# When building from top-point arrays (Terrain/Polygon2D), take every Nth point.
@export var points_stride: int = 8

# Smoothing strength for the rebuilt curve (0 = straight segments, 1 = strong smoothing)
@export_range(0.0, 1.0, 0.05) var tangent_smoothness: float = 0.5

# Editor buttons
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if Engine.is_editor_hint():
			rebuild_auto()

@export var snap_points_to_ground: bool = false:
	set(value):
		snap_points_to_ground = false
		if Engine.is_editor_hint():
			_snap_curve_to_ground()

# Auto-build at runtime
@export var build_on_ready: bool = true

func _ready() -> void:
	if build_on_ready and not Engine.is_editor_hint():
		rebuild_auto()

# ------------------------------------------------------------
# Public entry: try Terrain -> Polygon2D -> CollisionPolygon2D
# ------------------------------------------------------------
func rebuild_auto() -> void:
	# Prefer Terrain.get_top_points() for perfect match and performance.
	var terrain: Node = _resolve_node_safe(terrain_node_path)
	if (terrain as Object) != null and terrain.has_method("get_top_points"):
		var top_points: PackedVector2Array = terrain.call("get_top_points")
		var src2d := terrain as Node2D
		if src2d != null and top_points.size() >= 2:
			_build_from_top_points(top_points, src2d)
			return

	# Next, try Polygon2D (assumes top chain first and last two are the bottom closer)
	var poly2d: Polygon2D = _resolve_node_safe(ground_polygon2d_path) as Polygon2D
	if poly2d != null and poly2d.polygon.size() >= 3:
		var poly: PackedVector2Array = poly2d.polygon
		var top_chain: PackedVector2Array = poly.slice(0, max(0, poly.size() - 2))
		if top_chain.size() >= 2:
			_build_from_top_points(top_chain, poly2d)
			return

	# Finally, fall back to sampling over CollisionPolygon2D
	var col: CollisionPolygon2D = _resolve_node_safe(ground_collision_path) as CollisionPolygon2D
	if col != null and col.polygon.size() >= 3:
		rebuild_from_collision(col)
		return

	push_warning("PathAutoBuilder: No valid source found. Assign terrain_node_path, ground_polygon2d_path, or ground_collision_path.")

# ------------------------------------------------------------
# Build from a top-points polyline (Terrain/Polygon2D)
# ------------------------------------------------------------
func _build_from_top_points(points_local_to_src: PackedVector2Array, src: Node2D) -> void:
	if points_local_to_src.size() < 2:
		push_warning("PathAutoBuilder: not enough points to build curve.")
		return

	# Transform from source local -> path local
	var to_path_local: Transform2D = global_transform.affine_inverse() * src.global_transform

	var curve_new: Curve2D = Curve2D.new()
	var stride: int = max(1, points_stride)
	for i in range(0, points_local_to_src.size(), stride):
		var p_src: Vector2 = points_local_to_src[i]
		var p_local: Vector2 = to_path_local * p_src
		curve_new.add_point(p_local + Vector2(0.0, -ride_height))

	# Ensure last point is present
	if curve_new.point_count == 0 or points_local_to_src.size() > 0:
		var p_end: Vector2 = to_path_local * points_local_to_src[points_local_to_src.size() - 1]
		if curve_new.point_count == 0 or curve_new.get_point_position(curve_new.point_count - 1).distance_to(p_end) > 0.5:
			curve_new.add_point(p_end + Vector2(0.0, -ride_height))

	_apply_smoothing(curve_new, tangent_smoothness)
	curve = curve_new
	queue_redraw()

# ------------------------------------------------------------
# Build segments from Ground polygon in Path2D local space
# (CollisionPolygon2D-based workflow)
# ------------------------------------------------------------
func _get_polygon_segments_local(col: CollisionPolygon2D) -> Array[Segment]:
	var pts: PackedVector2Array = col.polygon
	var arr: Array[Segment] = []
	if pts.size() < 2:
		return arr
	var to_local_xf: Transform2D = global_transform.affine_inverse() * col.global_transform
	for i in range(pts.size()):
		var a_g: Vector2 = to_local_xf * pts[i]
		var b_g: Vector2 = to_local_xf * pts[(i + 1) % pts.size()]
		arr.append(Segment.new(a_g, b_g))
	return arr

# Top-most Y at x (smallest screen Y). Returns NaN if no intersection with non-vertical segments.
func _top_y_for_x(x_val: float, segs: Array[Segment]) -> float:
	var found: bool = false
	var best_y: float = 0.0
	for seg in segs:
		var a: Vector2 = seg.a
		var b: Vector2 = seg.b
		var dx: float = b.x - a.x
		if absf(dx) < 0.0001:
			continue  # skip vertical segments (side walls)
		if x_val >= minf(a.x, b.x) - 0.0001 and x_val <= maxf(a.x, b.x) + 0.0001:
			var t: float = (x_val - a.x) / dx
			if t >= -0.0001 and t <= 1.0001:
				var y: float = lerp(a.y, b.y, t)
				if not found or y < best_y:
					found = true
					best_y = y
	if found:
		return best_y
	return NAN

# Figure out the X range to sample (using markers if provided)
func _compute_sample_bounds_local(col: CollisionPolygon2D) -> Vector2:
	var to_local_xf: Transform2D = global_transform.affine_inverse() * col.global_transform
	var pts: PackedVector2Array = col.polygon
	var min_x: float = INF
	var max_x: float = -INF
	for i in range(pts.size()):
		var p_local: Vector2 = to_local_xf * pts[i]
		min_x = minf(min_x, p_local.x)
		max_x = maxf(max_x, p_local.x)

	# If both markers are set and valid, use them (ignores x_margin)
	var lm: Node2D = _resolve_node_safe(left_marker_path) as Node2D
	var rm: Node2D = _resolve_node_safe(right_marker_path) as Node2D
	if lm != null and rm != null:
		# Convert marker positions to Path2D local space
		var lm_local: Vector2 = global_transform.affine_inverse() * lm.global_position
		var rm_local: Vector2 = global_transform.affine_inverse() * rm.global_position
		var a: float = lm_local.x
		var b: float = rm_local.x
		var lo: float = minf(a, b)
		var hi: float = maxf(a, b)
		return Vector2(lo, hi)

	# No markers: shrink bounds by margin to avoid sampling the closing side walls
	min_x += x_margin
	max_x -= x_margin
	if min_x > max_x:
		var mid: float = (min_x + max_x) * 0.5
		min_x = mid
		max_x = mid
	return Vector2(min_x, max_x)

# Rebuild the entire Path2D curve from Ground polygon (CollisionPolygon2D)
func rebuild_from_collision(col: CollisionPolygon2D = null) -> void:
	var ground: CollisionPolygon2D = col
	if ground == null:
		if ground_collision_path.is_empty():
			push_warning("PathAutoBuilder: ground_collision_path is empty.")
			return
		ground = _resolve_node_safe(ground_collision_path) as CollisionPolygon2D
	if ground == null or ground.polygon.size() < 3:
		push_warning("PathAutoBuilder: Ground CollisionPolygon2D missing or invalid.")
		return

	var segs: Array[Segment] = _get_polygon_segments_local(ground)
	if segs.is_empty():
		push_warning("PathAutoBuilder: no segments.")
		return

	var bounds: Vector2 = _compute_sample_bounds_local(ground)
	var x_lo: float = bounds.x
	var x_hi: float = bounds.y
	var step: float = maxf(1.0, sample_step)

	var new_curve: Curve2D = Curve2D.new()
	var x: float = x_lo
	while x <= x_hi + 0.001:
		var gy: float = _top_y_for_x(x, segs)
		if not is_nan(gy):
			new_curve.add_point(Vector2(x, gy - ride_height))
		x += step

	# If nothing was added, warn and exit
	if new_curve.point_count < 2:
		push_warning("PathAutoBuilder: no valid samples found. Check markers/bounds and CollisionPolygon2D.")
		return

	_apply_smoothing(new_curve, tangent_smoothness)
	curve = new_curve
	queue_redraw()

# Snap existing Path2D points to the ground at their current X (works best with CollisionPolygon2D source)
func _snap_curve_to_ground() -> void:
	var col: CollisionPolygon2D = _resolve_node_safe(ground_collision_path) as CollisionPolygon2D
	if col == null or col.polygon.size() < 3:
		push_warning("Assign a valid ground_collision_path to use snap.")
		return
	if curve == null or curve.point_count == 0:
		push_warning("Path2D has no points. Use 'rebuild_now' instead.")
		return

	var segs: Array[Segment] = _get_polygon_segments_local(col)
	if segs.is_empty():
		push_warning("No polygon segments found.")
		return

	for i in range(curve.point_count):
		var p: Vector2 = curve.get_point_position(i)
		var gy: float = _top_y_for_x(p.x, segs)
		if not is_nan(gy):
			p.y = gy - ride_height
			curve.set_point_position(i, p)

	# Reset tangents after snapping
	for i in range(curve.point_count):
		curve.set_point_in(i, Vector2.ZERO)
		curve.set_point_out(i, Vector2.ZERO)

	queue_redraw()

# Simple tangent smoothing (endpoints stay sharp)
func _apply_smoothing(c: Curve2D, strength: float) -> void:
	if c.point_count < 3 or strength <= 0.0:
		for i in range(c.point_count):
			c.set_point_in(i, Vector2.ZERO)
			c.set_point_out(i, Vector2.ZERO)
		return

	for i in range(c.point_count):
		var p: Vector2 = c.get_point_position(i)
		if i == 0 or i == c.point_count - 1:
			c.set_point_in(i, Vector2.ZERO)
			c.set_point_out(i, Vector2.ZERO)
			continue
		var prev_p: Vector2 = c.get_point_position(i - 1)
		var next_p: Vector2 = c.get_point_position(i + 1)

		var dir: Vector2 = (next_p - prev_p).normalized()
		var len_prev: float = (p - prev_p).length()
		var len_next: float = (next_p - p).length()
		var handle_len: float = 0.5 * (len_prev + len_next) * strength

		c.set_point_in(i, -dir * handle_len)
		c.set_point_out(i, dir * handle_len)

# ------------------------------------------------------------
# Safe node resolving that avoids absolute-path errors
# ------------------------------------------------------------
func _resolve_node_safe(path: NodePath) -> Node:
	if path.is_empty():
		return null
	# Avoid calling get_node with an absolute path when not in the tree
	if path.is_absolute():
		if not is_inside_tree():
			# In editor, this node might not be in the active scene tree yet.
			push_warning("PathAutoBuilder: absolute NodePath cannot be resolved when not inside the scene tree. Use a relative path.")
			return null
		return get_tree().root.get_node_or_null(path)
	else:
		if not is_inside_tree():
			return null
		return get_node_or_null(path)
