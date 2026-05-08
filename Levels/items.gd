# Items.gd
extends Node2D

# Camera-based spawning and cleanup
@export var use_camera_trigger: bool = true
@export var camera_pre_spawn_margin_px: float = 160.0     # spawn just before right edge
@export var cleanup_margin_px: float = 256.0              # despawn after left edge + margin
@export var forward_only: bool = true                     # skip items already left of the left edge (camera mode)

# Time window and visual warning
@export var item_lifetime_sec: float = 3.0                # seconds to collect before auto-despawn
@export var warn_duration_sec: float = 1.0                # last seconds to pulse before despawn
@export var warn_scale_multiplier: float = 1.18           # peak scale during pulse

# Spawn throttling and fallback
@export var max_spawns_per_frame: int = 4
@export var trigger_distance_px: float = 600.0            # fallback if no camera found

# References
@export var player_groups: PackedStringArray = ["player", "radler"]
@export_node_path("Node") var spawn_parent_path: NodePath

# Internal state
var _defs: Array[Dictionary] = []      # { "scene": PackedScene, "pos": Vector2, "rot": float, "scale": Vector2, "name": StringName, "spawned": bool }
var _player: Node2D = null
var _cam: Camera2D = null
var _next_index: int = 0
var _active: Array[Node2D] = []

func _ready() -> void:
	_player = _find_player()
	_cam = get_viewport().get_camera_2d()

	# Capture editor-placed items, then remove them
	for c in get_children():
		if c is Node2D:
			var nd: Node2D = c as Node2D
			var ps: PackedScene = null
			var scene_path: String = nd.get_scene_file_path()
			if scene_path != "":
				ps = load(scene_path) as PackedScene
			else:
				ps = PackedScene.new()
				var err: int = ps.pack(nd)
				if err != OK:
					continue

			_defs.append({
				"scene": ps,
				"pos": nd.global_position,
				"rot": nd.global_rotation,
				"scale": nd.global_scale,
				"name": nd.name,
				"spawned": false
			})
			nd.queue_free()

	# Sort by X for efficient forward scan
	_defs.sort_custom(Callable(self, "_cmp_by_x"))
	set_process(true)

func _cmp_by_x(a: Dictionary, b: Dictionary) -> bool:
	return a["pos"].x < b["pos"].x

func _process(_dt: float) -> void:
	# Refresh references
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_2d()
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()

	var spawned_this_frame: int = 0
	var have_cam: bool = use_camera_trigger and _cam != null and is_instance_valid(_cam)

	var left_x: float = -INF
	var right_x: float = INF

	if have_cam:
		var vp_size: Vector2i = get_viewport().get_visible_rect().size
		var half_w: float = float(vp_size.x) * 0.5 * _cam.zoom.x
		left_x = _cam.global_position.x - half_w
		right_x = _cam.global_position.x + half_w

	# Forward scan/spawn
	while _next_index < _defs.size():
		var sd: Dictionary = _defs[_next_index]
		if sd["spawned"]:
			_next_index += 1
			continue

		if have_cam:
			# Skip if already off to the left (forward-only)
			if forward_only and float(sd["pos"].x) < left_x:
				_next_index += 1
				continue

			# Spawn when entering near the right edge (plus margin)
			if float(sd["pos"].x) <= right_x + camera_pre_spawn_margin_px:
				_spawn_one(sd)
				sd["spawned"] = true
				_next_index += 1
				spawned_this_frame += 1
				if spawned_this_frame >= max_spawns_per_frame:
					break
			else:
				# Not at the right edge yet; stop early (sorted by X)
				break
		else:
			# Fallback: distance-to-player trigger
			if _player == null:
				break
			var px: Vector2 = _player.global_position
			if forward_only and float(sd["pos"].x) < px.x:
				_next_index += 1
				continue
			if px.distance_to(sd["pos"]) <= trigger_distance_px:
				_spawn_one(sd)
				sd["spawned"] = true
				_next_index += 1
				spawned_this_frame += 1
				if spawned_this_frame >= max_spawns_per_frame:
					break
			else:
				break

	# Cleanup: remove active items far beyond the left edge (camera mode)
	if have_cam and _active.size() > 0 and cleanup_margin_px > 0.0:
		for i in range(_active.size() - 1, -1, -1):
			var inst: Node2D = _active[i]
			if not is_instance_valid(inst):
				_active.remove_at(i)
				continue
			if inst.global_position.x < left_x - cleanup_margin_px:
				inst.queue_free()
				_active.remove_at(i)

func _spawn_one(sd: Dictionary) -> void:
	var ps: PackedScene = sd["scene"]
	if ps == null:
		return

	var spawned: Node = ps.instantiate()

	# Choose parent
	var parent: Node = self
	if not spawn_parent_path.is_empty():
		var p: Node = get_node_or_null(spawn_parent_path)
		if p != null:
			parent = p

	# Apply transform from editor placement
	if spawned is Node2D:
		var nd: Node2D = spawned as Node2D
		nd.global_position = sd["pos"]
		nd.global_rotation = sd["rot"]
		nd.global_scale = sd["scale"]
		nd.name = sd["name"]
		_active.append(nd)

	parent.add_child(spawned)

	# Schedule heartbeat pulse for the last warn_duration_sec before despawn
	if item_lifetime_sec > 0.0 and warn_duration_sec > 0.0:
		var delay: float = max(0.0, item_lifetime_sec - warn_duration_sec)
		var warn_timer := Timer.new()
		warn_timer.one_shot = true
		warn_timer.wait_time = delay
		spawned.add_child(warn_timer)
		warn_timer.timeout.connect(Callable(self, "_start_heartbeat_pulse").bind(spawned))
		warn_timer.start()

	# Auto-despawn window
	if item_lifetime_sec > 0.0:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = item_lifetime_sec
		spawned.add_child(t)
		t.timeout.connect(func() -> void:
			if is_instance_valid(spawned):
				spawned.queue_free()
		)
		t.start()

	# Remove from _active when the spawned node leaves the tree
	spawned.tree_exited.connect(func() -> void:
		for i in range(_active.size() - 1, -1, -1):
			if _active[i] == spawned:
				_active.remove_at(i)
				break
	)

# Start a smooth, “heartbeat-like” pulse and keep looping until node is freed.
func _start_heartbeat_pulse(n: Node) -> void:
	if not (n is Node2D):
		return
	var nd: Node2D = n as Node2D
	if not is_instance_valid(nd):
		return

	var base_scale: Vector2 = nd.scale
	var up_scale: Vector2 = base_scale * warn_scale_multiplier
	var up2_scale: Vector2 = base_scale.lerp(up_scale, 0.6)  # slightly smaller second beat

	_play_heartbeat_cycle(nd, base_scale, up_scale, up2_scale)

func _play_heartbeat_cycle(nd: Node2D, base_scale: Vector2, up_scale: Vector2, up2_scale: Vector2) -> void:
	if not is_instance_valid(nd):
		return
	var tw := nd.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Beat 1 (strong)
	tw.tween_property(nd, "scale", up_scale, 0.08)
	tw.tween_property(nd, "scale", base_scale, 0.12)

	# Beat 2 (weaker)
	tw.tween_property(nd, "scale", up2_scale, 0.06)
	tw.tween_property(nd, "scale", base_scale, 0.14)

	# Rest between heartbeats
	tw.tween_interval(0.22)

	# Loop by reconnecting to a class method (no standalone lambda)
	tw.finished.connect(Callable(self, "_on_heartbeat_cycle_finished").bind(nd, base_scale, up_scale, up2_scale))

func _on_heartbeat_cycle_finished(nd: Node2D, base_scale: Vector2, up_scale: Vector2, up2_scale: Vector2) -> void:
	if is_instance_valid(nd):
		_play_heartbeat_cycle(nd, base_scale, up_scale, up2_scale)

func _find_player() -> Node2D:
	for g in player_groups:
		var n: Node = get_tree().get_first_node_in_group(g)
		if n is Node2D:
			return n as Node2D
	return null

func reset_manager() -> void:
	# Remove active items
	for i in range(_active.size() - 1, -1, -1):
		var inst: Node2D = _active[i]
		if is_instance_valid(inst):
			inst.queue_free()
	_active.clear()

	# Reset definitions
	for sd in _defs:
		sd["spawned"] = false
	_next_index = 0
