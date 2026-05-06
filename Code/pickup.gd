@tool
extends Area2D

# Terrain snapping setup
@export_node_path("Node2D") var terrain_path: NodePath
@export var auto_find_terrain: bool = true
@export var snap_y_offset: float = -40.0
@export var snap_align_to_slope: bool = false
@export var snap_in_editor: bool = true
@export var snap_in_game: bool = false

# Pickup behavior (energy only)
@export var pickup_id: String = "generic"
@export var message: String = "Picked up something!"
@export var play_sound_on_pick: AudioStream = null
@export var auto_free_on_pick: bool = true
@export var collector_groups: PackedStringArray = ["player", "radler"]
@export var award_energy_kj: int = 0

# Visuals/collision
@export var pickup_animation_name: StringName = &"pickup"
@export_node_path("CollisionShape2D") var collision_shape_path: NodePath
@export var disable_collision_on_pick: bool = true
@export var disappear_scale: float = 0.6
@export var disappear_time: float = 0.15

func _ready() -> void:
	if not Engine.is_editor_hint():
		monitoring = true
		set_deferred("monitorable", true)
		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)

func _process(_dt: float) -> void:
	if auto_find_terrain and terrain_path.is_empty():
		var t: Node2D = _find_terrain_in_tree()
		if t != null:
			terrain_path = get_path_to(t)

	var do_snap: bool = (Engine.is_editor_hint() and snap_in_editor) or (not Engine.is_editor_hint() and snap_in_game)
	if do_snap:
		_snap_to_ground()

func _on_area_entered(a: Area2D) -> void:
	if a != null and _is_allowed_collector(a):
		_collect()

func _on_body_entered(b: PhysicsBody2D) -> void:
	if b != null and _is_allowed_collector(b):
		_collect()

# Applies energy, plays VFX/SFX, and removes the pickup
func _collect() -> void:
	if not is_inside_tree():
		return
	set_process(false)
	set_physics_process(false)

	if disable_collision_on_pick:
		var shape: CollisionShape2D = _get_collision_shape()
		if shape != null:
			shape.set_deferred("disabled", true)

	var level: Node = _find_level()
	if award_energy_kj > 0 and level != null and level.has_method("add_energy"):
		level.call_deferred("add_energy", award_energy_kj)

	if level != null and level.has_method("show_popup_message"):
		level.call_deferred("show_popup_message", message, pickup_id)

	if play_sound_on_pick != null:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = play_sound_on_pick
		add_child(p)
		p.finished.connect(func() -> void:
			if is_instance_valid(p):
				p.queue_free()
		)
		p.play()

	var anim: AnimationPlayer = _get_animation_player()
	if anim != null and anim.has_animation(pickup_animation_name):
		anim.animation_finished.connect(func(_n: StringName) -> void:
			if auto_free_on_pick and is_inside_tree():
				queue_free()
		, Object.CONNECT_ONE_SHOT)
		anim.play(pickup_animation_name)
	else:
		if disappear_time > 0.0:
			var tw: Tween = create_tween()
			tw.tween_property(self, "scale", Vector2(disappear_scale, disappear_scale), disappear_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.finished.connect(func() -> void:
				if auto_free_on_pick and is_inside_tree():
					queue_free()
			)
		else:
			if auto_free_on_pick and is_inside_tree():
				queue_free()

# --- Helpers ---

# Accept only nodes in allowed groups
func _is_allowed_collector(n: Node) -> bool:
	if collector_groups.is_empty():
		return true
	for g in collector_groups:
		if g != "" and n.is_in_group(g):
			return true
	return false

# Find the nearest level node that implements add_energy
func _find_level() -> Node:
	var n: Node = self
	while n != null and not n.has_method("add_energy"):
		n = n.get_parent()
	if n != null:
		return n
	return get_tree().current_scene

# Snap vertically to the terrain, storing position parent-local so items move with Path2D
func _snap_to_ground() -> void:
	var terrain: Node2D = _resolve_node(terrain_path) as Node2D
	if terrain == null or not terrain.has_method("get_surface_y"):
		return

	var world_x: float = global_position.x
	var x_in_terrain: Vector2 = terrain.to_local(Vector2(world_x, 0.0))
	var y: float = float(terrain.call("get_surface_y", x_in_terrain.x))
	var desired_world: Vector2 = terrain.to_global(Vector2(x_in_terrain.x, y + snap_y_offset))

	var parent_nd: Node2D = get_parent() as Node2D
	if parent_nd != null:
		position = parent_nd.to_local(desired_world)
	else:
		global_position = desired_world

	if snap_align_to_slope:
		var y_l: float = float(terrain.call("get_surface_y", x_in_terrain.x - 2.0))
		var y_r: float = float(terrain.call("get_surface_y", x_in_terrain.x + 2.0))
		global_rotation = atan2(y_r - y_l, 4.0)

# Get AnimationPlayer on this node or first child
func _get_animation_player() -> AnimationPlayer:
	var ap: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		return ap
	for c in get_children():
		if c is AnimationPlayer:
			return c as AnimationPlayer
	return null

# Get explicit CollisionShape2D or first child shape
func _get_collision_shape() -> CollisionShape2D:
	if not collision_shape_path.is_empty():
		var s: CollisionShape2D = _resolve_node(collision_shape_path) as CollisionShape2D
		if s != null:
			return s
	for c in get_children():
		if c is CollisionShape2D:
			return c as CollisionShape2D
	return null

# Resolve a NodePath relative to this node
func _resolve_node(p: NodePath) -> Node:
	if p.is_empty() or not is_inside_tree():
		return null
	if p.is_absolute():
		return get_tree().root.get_node_or_null(p)
	return get_node_or_null(p)

# Find a terrain node by scanning the current scene
func _find_terrain_in_tree() -> Node2D:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Node2D and n.has_method("get_surface_y"):
			return n as Node2D
		for c in n.get_children():
			stack.append(c)
	return null
