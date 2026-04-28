# res://Code/pickup.gd
@tool
extends Area2D

# --- Ground snapping (so you can place in editor easily) ---
@export_node_path("Node2D") var terrain_path: NodePath
@export var auto_find_terrain: bool = true
@export var snap_y_offset: float = -40.0        # how high above ground to place the pickup
@export var snap_align_to_slope: bool = false   # rotate to match ground slope
@export var snap_in_editor: bool = true         # keep snapped while editing
@export var snap_in_game: bool = false          # usually false if rider follows a rail

# --- Pickup behavior (generic) ---
@export var pickup_id: String = "generic"
@export var message: String = "Picked up something!"
@export var play_sound_on_pick: AudioStream = null
@export var auto_free_on_pick: bool = true

# Who is allowed to collect (player/collector). Any match in this list will collect.
@export var collector_groups: PackedStringArray = ["player", "radler"]

# Optional: award coins (Level script must implement add_coins(int))
@export var award_coins: int = 0

# Optional: animation on pick (AnimationPlayer child with this animation name)
@export var pickup_animation_name: StringName = &"pickup"

# Optional: disable a specific CollisionShape2D on pick (leave empty to auto-find first CollisionShape2D child)
@export_node_path("CollisionShape2D") var collision_shape_path: NodePath
@export var disable_collision_on_pick: bool = true

# Optional: simple disappear tween (used only if no animation is played)
@export var disappear_scale: float = 0.6
@export var disappear_time: float = 0.15

# --- Runtime wiring ---
func _ready() -> void:
	# Connect overlap signals at runtime
	if not Engine.is_editor_hint():
		monitoring = true
		set_deferred("monitorable", true)
		area_entered.connect(_on_area_entered)
		body_entered.connect(_on_body_entered)

func _process(_dt: float) -> void:
	# Auto-assign terrain if requested
	if auto_find_terrain and terrain_path.is_empty():
		var t: Node2D = _find_terrain_in_tree()
		if t != null:
			terrain_path = get_path_to(t)

	var do_snap: bool = (Engine.is_editor_hint() and snap_in_editor) or (not Engine.is_editor_hint() and snap_in_game)
	if do_snap:
		_snap_to_ground()

# --- Overlap handlers (accept both Area2D and PhysicsBody2D collectors) ---
func _on_area_entered(a: Area2D) -> void:
	if a != null and _is_allowed_collector(a):
		_collect()

func _on_body_entered(b: PhysicsBody2D) -> void:
	if b != null and _is_allowed_collector(b):
		_collect()

# --- Collect core ---
func _collect() -> void:
	# Prevent double-collect
	if not is_inside_tree():
		return
	set_process(false)
	set_physics_process(false)

	# 1) Disable collision (so it can't be picked twice)
	if disable_collision_on_pick:
		var shape: CollisionShape2D = _get_collision_shape()
		if shape != null:
			shape.set_deferred("disabled", true)

	# 2) Notify level (popup)
	var level: Node = get_tree().current_scene
	if level != null and level.has_method("show_popup_message"):
		level.call_deferred("show_popup_message", message, pickup_id)

	# 3) Award coins (if configured)
	if award_coins > 0 and level != null and level.has_method("add_coins"):
		level.call_deferred("add_coins", award_coins)

	# 4) Play sound (optional)
	if play_sound_on_pick != null:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = play_sound_on_pick
		add_child(p)
		p.finished.connect(func() -> void: if is_instance_valid(p): p.queue_free())
		p.play()

	# 5) Animation if available, else tween-disappear
	var anim: AnimationPlayer = _get_animation_player()
	if anim != null and anim.has_animation(pickup_animation_name):
		# Connect once to free (or not) when animation ends
		anim.animation_finished.connect(func(_name: StringName) -> void:
			if auto_free_on_pick and is_inside_tree():
				queue_free()
		, Object.CONNECT_ONE_SHOT)
		anim.play(pickup_animation_name)
	else:
		# Fallback: tiny disappear tween
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

# --- Helpers -------------------------------------------------------------

func _is_allowed_collector(n: Node) -> bool:
	if collector_groups.is_empty():
		return true
	for g in collector_groups:
		if g != "" and n.is_in_group(g):
			return true
	return false

# Ground snap helper (uses Terrain.get_surface_y)
func _snap_to_ground() -> void:
	var terrain: Node2D = _resolve_node(terrain_path) as Node2D
	if terrain == null or not terrain.has_method("get_surface_y"):
		return

	var local: Vector2 = terrain.to_local(global_position)
	var y: float = float(terrain.call("get_surface_y", local.x))
	var snapped_local: Vector2 = Vector2(local.x, y + snap_y_offset)
	global_position = terrain.to_global(snapped_local)

	if snap_align_to_slope:
		var dy_left: float = float(terrain.call("get_surface_y", local.x - 2.0))
		var dy_right: float = float(terrain.call("get_surface_y", local.x + 2.0))
		var angle: float = atan2(dy_right - dy_left, 4.0)
		global_rotation = angle

func _get_animation_player() -> AnimationPlayer:
	# Try direct child named "AnimationPlayer" first
	var ap: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null:
		return ap
	# Fallback: first AnimationPlayer in children
	for c in get_children():
		if c is AnimationPlayer:
			return c as AnimationPlayer
	return null

func _get_collision_shape() -> CollisionShape2D:
	if not collision_shape_path.is_empty():
		var s: CollisionShape2D = _resolve_node(collision_shape_path) as CollisionShape2D
		if s != null:
			return s
	# Fallback: first CollisionShape2D child
	for c in get_children():
		if c is CollisionShape2D:
			return c as CollisionShape2D
	return null

func _resolve_node(p: NodePath) -> Node:
	if p.is_empty() or not is_inside_tree():
		return null
	if p.is_absolute():
		return get_tree().root.get_node_or_null(p)
	return get_node_or_null(p)

func _find_terrain_in_tree() -> Node2D:
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is Node2D and n.has_method("get_surface_y"):
			return n as Node2D
		for c in n.get_children():
			stack.append(c)
	return null
