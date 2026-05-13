@tool
extends Path2D

# Builds a rail Path2D from a Terrain node's top surface.

# Assign your Terrain node (Node2D with terrain.gd). Can be left empty if auto_find_terrain is true.
@export_node_path("Node2D") var terrain_path: NodePath
@export var auto_find_terrain: bool = true    # Auto-detect Terrain if terrain_path is empty.

# Rail shape settings
@export var y_offset: float = -8.0            # Lift the rail above the ground.
@export var stride: int = 8                   # Take every Nth terrain point (fewer points -> faster).
@export var bake_interval: float = 8.0        # Curve2D bake interval.

# Editor helpers
@export var auto_rebuild_in_editor: bool = true
@export var rebuild_now: bool = false:
	set(v):
		rebuild_now = false
		_rebuild_from_terrain()

# Runtime build (when you press Play)
@export var build_on_ready: bool = true

# Optional debug logging
@export var log_debug: bool = false

# Called on enter tree; defers a build during gameplay.
func _ready() -> void:
	# Build once at runtime. In the editor, _process handles preview.
	if not Engine.is_editor_hint() and build_on_ready:
		call_deferred("_rebuild_after_ready")

# Deferred builder; waits one frame so dependencies are in the tree.
func _rebuild_after_ready() -> void:
	await get_tree().process_frame
	_rebuild_from_terrain()

# Editor tick; rebuilds continuously for live preview if enabled.
#func _process(_dt: float) -> void:
	#if Engine.is_editor_hint() and auto_rebuild_in_editor:
		#_rebuild_from_terrain()
# En path_2d.gd
func _process(_dt: float) -> void:
	# NEW: Only rebuild in the editor. 
	# NEVER rebuild during gameplay as it breaks PathFollow2D.
	if Engine.is_editor_hint() and auto_rebuild_in_editor:
		_rebuild_from_terrain()

# Builds the Path2D curve from the terrain's top surface points.
func _rebuild_from_terrain() -> void:
	if not is_inside_tree():
		return

	var terrain: Node2D = _get_terrain()
	if terrain == null:
		if log_debug:
			print("[path_2d] Terrain not found; set terrain_path or enable auto_find_terrain.")
		return

	if not terrain.has_method("get_top_points"):
		if log_debug:
			print("[path_2d] Terrain has no get_top_points().")
		return

	# Strict type check of the returned data to avoid Variant warnings.
	var pts_any: Variant = terrain.call("get_top_points")
	if typeof(pts_any) != TYPE_PACKED_VECTOR2_ARRAY:
		if log_debug:
			print("[path_2d] get_top_points did not return PackedVector2Array.")
		return
	var pts: PackedVector2Array = pts_any as PackedVector2Array
	if pts.size() < 2:
		if log_debug:
			print("[path_2d] Not enough points: ", pts.size())
		return

	var c: Curve2D = Curve2D.new()
	c.bake_interval = bake_interval
	var step: int = max(1, stride)

	for i in range(0, pts.size(), step):
		var p_global: Vector2 = terrain.to_global(pts[i])
		var p_local: Vector2 = to_local(p_global)
		c.add_point(p_local + Vector2(0.0, y_offset))

	# Ensure the last point is included.
	var last_global: Vector2 = terrain.to_global(pts[pts.size() - 1])
	var last_local: Vector2 = to_local(last_global)
	if c.point_count == 0 or c.get_point_position(c.point_count - 1).distance_to(last_local) > 0.5:
		c.add_point(last_local + Vector2(0.0, y_offset))

	curve = c

	if log_debug:
		var L: float = curve.get_baked_length()
		print("[path_2d] Curve rebuilt. Points:", c.point_count, "  Baked length:", L)

# Finds the Terrain node: explicit path first, otherwise scans the current scene.
func _get_terrain() -> Node2D:
	# 1) Use explicit NodePath if set.
	if not terrain_path.is_empty():
		var n: Node = _resolve_node(terrain_path)
		return n as Node2D

	# 2) Auto-find by scanning the current scene for a Node2D with get_top_points (Terrain API).
	if auto_find_terrain:
		var root: Node = get_tree().current_scene
		if root != null:
			var stack: Array = [root]
			while stack.size() > 0:
				var node: Node = stack.pop_back()
				if node is Node2D and node.has_method("get_top_points"):
					terrain_path = get_path_to(node) # Cache for next time.
					return node as Node2D
				for c in node.get_children():
					stack.append(c)

	return null

# Resolves a NodePath safely, handling absolute and relative paths.
func _resolve_node(p: NodePath) -> Node:
	if p.is_empty():
		return null
	if not is_inside_tree():
		return null
	if p.is_absolute():
		return get_tree().root.get_node_or_null(p)
	return get_node_or_null(p)
