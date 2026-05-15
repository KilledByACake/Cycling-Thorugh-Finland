extends Node2D

signal round_over(won: bool)

# Scene/Node references
@export_node_path("Node2D") var rail_path: NodePath
@export var trigger_path_rebuild: bool = true
@export var randomize_seed_on_play: bool = true

# Goal: win by reaching PathRight
@export_node_path("Area2D") var goal_area_path: NodePath = NodePath("Path2D/PathRight")
@export_node_path("Node2D") var goal_node_path: NodePath = NodePath("Path2D/PathRight")

# End-flow config
@export var celebrate_max_wait_sec: float = 2.0
const ROUND_TIME_SEC: int = 100
const TARGET_ENERGY: int = 200
const BANNER_DURATION_SEC: float = 2.0

# Screens
const GAME_OVER_SCENE: PackedScene = preload("res://Screen/GameOver.tscn")
const YOU_WON_SCENE: PackedScene = preload("res://Screen/Victory.tscn")
const RESULT_SCREEN_SCENE: PackedScene = preload("res://Screen/Result.tscn")

# State
var energy_points: int = 0              # kept for Result/Highscore; driven by Energy.gd
var round_finished: bool = false
var game_timer: Timer

# Timer blink config
@export var timer_blink_threshold_sec: int = 5
@export var timer_blink_interval_sec: float = 0.3
@export var timer_blink_color: Color = Color(1, 0.2, 0.2)
@export var timer_normal_color: Color = Color(1, 1, 1)
var _timer_blink_active: bool = false
var _timer_blink_accum: float = 0.0
var _timer_blink_state: bool = false

# UI references (fallbacks if UI.gd methods aren’t present)
var ui_root: Node                          # UI CanvasLayer
var player_name_label: Label
var timer_label: Label
var energy_label: Label
var _speed_label: Label

# Terrain export
@export var hill_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var terrain_difficulty: float = 0.4
@export var terrain_length: int = 8000
@export var terrain_base_y: float = 420.0
@export var terrain_amplitude: float = 80.0
@export var terrain_noise_frequency: float = 0.0018
@export var terrain_max_slope_deg: float = 18.0
@export var terrain_sample_step: int = 4

# Inactivity → Game Over (10s), with warning blink at 5s
@export var inactivity_timeout_sec: float = 10.0
@export var inactivity_warning_threshold_sec: float = 5.0
var inactivity_timer: Timer
var inactivity_warning_timer: Timer
var _blink_due_to_inactivity: bool = false

# Overlay layer
var overlay_layer: CanvasLayer

# Entry point
func _ready() -> void:
	_ensure_overlay_layer()
	_scan_and_fix_nodepaths(self, true)

	if hill_scene != null:
		_spawn_terrain()

	await get_tree().process_frame
	_resolve_ui_refs()
	_resolve_speed_label()

	# Hook Energy singleton → keep legacy energy_points + HUD in sync
	if not Energy.changed.is_connected(_on_energy_changed):
		Energy.changed.connect(_on_energy_changed)
	_on_energy_changed(Energy.total_kj, Energy.score_int)

	# Initial speed (via UI if available)
	var v0: float = 0.0
	var vv0: Variant = GlobalWahoo.get("speed")
	if typeof(vv0) == TYPE_FLOAT or typeof(vv0) == TYPE_INT:
		v0 = float(vv0)
	_ui_call("set_speed", [v0])
	if _speed_label and not ui_root or (ui_root and not ui_root.has_method("set_speed")):
		_speed_label.text = "%.1f" % v0

	_update_player_name_from_tree()
	_start_round_timer()
	_setup_inactivity_detection()
	_connect_goal_area()

# Terrain spawn
func _spawn_terrain() -> void:
	if hill_scene == null:
		return
	var hill: Node2D = hill_scene.instantiate() as Node2D
	hill.position = Vector2(0, 0)
	_set_if_has_property(hill, "length", terrain_length)
	_set_if_has_property(hill, "base_y", terrain_base_y)
	_set_if_has_property(hill, "difficulty", terrain_difficulty)
	_set_if_has_property(hill, "amplitude", terrain_amplitude)
	_set_if_has_property(hill, "noise_frequency", terrain_noise_frequency)
	_set_if_has_property(hill, "max_slope_deg", terrain_max_slope_deg)
	_set_if_has_property(hill, "sample_step", terrain_sample_step)
	if randomize_seed_on_play:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if _has_property(hill, "rng_seed"):
			hill.set("rng_seed", rng.randi())
		elif _has_property(hill, "seed"):
			hill.set("seed", rng.randi())
	add_child(hill)
	await get_tree().process_frame
	_scan_and_fix_nodepaths(self, true)

# Per-frame update
func _process(delta: float) -> void:
	if round_finished:
		return

	# Integrate pedaling energy (Energy.gd owns totals and emits when score integer changes)
	var pv: Variant = GlobalWahoo.get("power")
	var power_w: float = (float(pv) if (typeof(pv) == TYPE_FLOAT or typeof(pv) == TYPE_INT) else 0.0)
	Energy.integrate_power(delta, power_w)

	# Activity (resets inactivity timers) by either power or speed
	var sv: Variant = GlobalWahoo.get("speed")
	var speed_kmh: float = (float(sv) if (typeof(sv) == TYPE_FLOAT or typeof(sv) == TYPE_INT) else 0.0)
	if power_w > 1.0 or speed_kmh > 0.5:
		_on_player_pedaled()

	# Speed HUD via UI.gd if present (fallback to label)
	_ui_call("set_speed", [speed_kmh])
	if _speed_label and (ui_root == null or not ui_root.has_method("set_speed")):
		_speed_label.text = "%.1f" % speed_kmh

	# Timer HUD and blink
	if game_timer:
		var t: int = max(0, int(ceil(game_timer.time_left)))
		_ui_call("set_timer_text", [_format_time(t)])
		if timer_label and (ui_root == null or not ui_root.has_method("set_timer_text")):
			timer_label.text = _format_time(t)
		var should_blink: bool = (t <= timer_blink_threshold_sec) or _blink_due_to_inactivity
		_enable_timer_blink(should_blink)
		_update_timer_blink(delta)

	# Victory detection: prefer PathFollow2D end-lock; fallback to X-cross
	var player_nd := get_tree().get_first_node_in_group("player") as Node2D
	if not round_finished and player_nd:
		var reached := false
		var pf := player_nd.get_parent()
		if pf is PathFollow2D and (pf as PathFollow2D).input_locked:
			reached = true
		else:
			var goal_node := _resolve_node_safe(goal_node_path) as Node2D
			if goal_node != null and player_nd.global_position.x >= goal_node.global_position.x:
				reached = true
		if reached:
			_finish_as_victory()

# Energy: forward pickups into Energy.gd (do not handle totals here)
func add_energy(amount: int) -> void:
	if round_finished:
		return
	Energy.add_pickup(amount)
	# Energy.changed will call _on_energy_changed → updates energy_points + HUD

# Energy change handler (from Energy.gd)
func _on_energy_changed(total_kj: float, score_int: int) -> void:
	energy_points = score_int
	_ui_call("set_energy_total_kj", [total_kj])
	if energy_label and (ui_root == null or not ui_root.has_method("set_energy_total_kj")):
		energy_label.text = "%.1f" % total_kj

# Player name to UI
func _update_player_name_from_tree() -> void:
	if ui_root:
		var n := ""
		if get_tree().root.has_meta("player_name"):
			n = str(get_tree().root.get_meta("player_name"))
		if n != "":
			_ui_call("set_player_name", [n])
			if player_name_label and (ui_root == null or not ui_root.has_method("set_player_name")):
				player_name_label.text = n

# Round timer
func _start_round_timer() -> void:
	game_timer = Timer.new()
	game_timer.one_shot = true
	game_timer.wait_time = ROUND_TIME_SEC
	add_child(game_timer)
	game_timer.timeout.connect(_finish_round)
	game_timer.start()
	_ui_call("set_timer_text", [_format_time(ROUND_TIME_SEC)])
	if timer_label and (ui_root == null or not ui_root.has_method("set_timer_text")):
		timer_label.text = _format_time(ROUND_TIME_SEC)
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)

# Round end by time (loss)
func _finish_round() -> void:
	if round_finished:
		return
	round_finished = true
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)
	_blink_due_to_inactivity = false

	_hide_ui()
	_freeze_world()
	emit_signal("round_over", false)
	await _show_banner_overlay(false)
	_show_result_screen_overlay(false, energy_points, TARGET_ENERGY)

# Inactivity detection
func _setup_inactivity_detection() -> void:
	inactivity_warning_timer = Timer.new()
	inactivity_warning_timer.one_shot = true
	inactivity_warning_timer.wait_time = inactivity_warning_threshold_sec
	add_child(inactivity_warning_timer)
	inactivity_warning_timer.timeout.connect(_on_inactivity_warning_timeout)

	inactivity_timer = Timer.new()
	inactivity_timer.one_shot = true
	inactivity_timer.wait_time = inactivity_timeout_sec
	add_child(inactivity_timer)
	inactivity_timer.timeout.connect(_on_inactivity_timeout)

	inactivity_warning_timer.start()
	inactivity_timer.start()

# Pedaling → reset inactivity timers
func _on_player_pedaled() -> void:
	if round_finished:
		return
	if inactivity_warning_timer:
		inactivity_warning_timer.start()
	if inactivity_timer:
		inactivity_timer.start()
	_blink_due_to_inactivity = false
	if game_timer:
		var t: int = max(0, int(ceil(game_timer.time_left)))
		_enable_timer_blink((t <= timer_blink_threshold_sec) or _blink_due_to_inactivity)

# Inactivity warning crosses threshold (start blinking)
func _on_inactivity_warning_timeout() -> void:
	if round_finished:
		return
	_blink_due_to_inactivity = true

# Inactivity timeout → game over
func _on_inactivity_timeout() -> void:
	if round_finished:
		return
	_game_over_due_to_inactivity()

# Game over due to inactivity
func _game_over_due_to_inactivity() -> void:
	round_finished = true
	if game_timer:
		game_timer.stop()
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)
	_blink_due_to_inactivity = false

	_hide_ui()
	_freeze_world()
	emit_signal("round_over", false)
	await _show_banner_overlay(false)
	_show_result_screen_overlay(false, energy_points, TARGET_ENERGY)

# Connect goal Area2D once
func _connect_goal_area() -> void:
	var area: Area2D = _resolve_node_safe(goal_area_path) as Area2D
	if area != null and not area.body_entered.is_connected(_on_goal_area_body_entered):
		area.body_entered.connect(_on_goal_area_body_entered)

func _on_goal_area_body_entered(body: Node) -> void:
	if round_finished:
		return
	if body != null and body.is_in_group("player"):
		_finish_as_victory()

# Victory: stop moving, let Celebrate play, hide UI, freeze world, show overlays
func _finish_as_victory() -> void:
	if round_finished:
		return
	round_finished = true

	if game_timer: game_timer.stop()
	if inactivity_warning_timer: inactivity_warning_timer.stop()
	if inactivity_timer: inactivity_timer.stop()
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)
	_blink_due_to_inactivity = false

	var player := get_tree().get_first_node_in_group("player")
	if player:
		var pf := player.get_parent()
		if pf is PathFollow2D:
			pf.input_locked = true
			pf.speed_x = 0.0
		if not player.is_in_group("unfreezable"):
			player.add_to_group("unfreezable")
		if player.has_method("start_celebrate"):
			player.call("start_celebrate")

	_hide_ui()
	_freeze_world()

	emit_signal("round_over", true)
	await _show_banner_overlay(true)
	_show_result_screen_overlay(true, energy_points, TARGET_ENERGY)

# Blink helpers
func _enable_timer_blink(v: bool) -> void:
	if _timer_blink_active == v:
		return
	_timer_blink_active = v
	_timer_blink_accum = 0.0
	_timer_blink_state = false
	_set_timer_label_color(timer_normal_color)

func _update_timer_blink(delta: float) -> void:
	if not _timer_blink_active or timer_label == null:
		return
	_timer_blink_accum += delta
	if _timer_blink_accum >= timer_blink_interval_sec:
		_timer_blink_accum = 0.0
		_timer_blink_state = not _timer_blink_state
		_set_timer_label_color(timer_blink_color if _timer_blink_state else timer_normal_color)

func _set_timer_label_color(col: Color) -> void:
	if timer_label:
		timer_label.add_theme_color_override("font_color", col)
		timer_label.modulate = col

# Freeze everything except UI/Overlay layers and nodes in "unfreezable"
func _freeze_world() -> void:
	get_tree().call_group("freezable", "freeze")
	_freeze_recursive(self)

func _freeze_recursive(n: Node) -> void:
	if n == null:
		return
	if (n is CanvasLayer and (n.name == "UI" or n.name == "OverlayLayer")) or n.is_in_group("unfreezable"):
		return
	_freeze_node(n)
	for c in n.get_children():
		if c is Node:
			_freeze_recursive(c)

func _freeze_node(n: Node) -> void:
	if n is CharacterBody2D:
		var cb := n as CharacterBody2D
		cb.velocity = Vector2.ZERO
		cb.set_physics_process(false)
	elif n is RigidBody2D:
		var rb := n as RigidBody2D
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
		rb.sleeping = true
	else:
		if n.has_method("set_physics_process"):
			n.call("set_physics_process", false)
		if n.has_method("set_process"):
			n.call("set_process", false)
	if n is AnimationPlayer:
		(n as AnimationPlayer).stop()
	elif n is AnimatedSprite2D:
		(n as AnimatedSprite2D).speed_scale = 0.0
	elif n is GPUParticles2D:
		(n as GPUParticles2D).emitting = false
	elif n is CPUParticles2D:
		(n as CPUParticles2D).emitting = false
	elif n is AudioStreamPlayer:
		(n as AudioStreamPlayer).stop()

# Overlays
func _show_banner_overlay(won: bool) -> void:
	_ensure_overlay_layer()
	var scene: PackedScene = YOU_WON_SCENE if won else GAME_OVER_SCENE
	var banner: Control = scene.instantiate() as Control
	overlay_layer.add_child(banner)
	await get_tree().create_timer(BANNER_DURATION_SEC).timeout
	if is_instance_valid(banner):
		banner.queue_free()

func _show_result_screen_overlay(won: bool, energy: int, target: int) -> void:
	_ensure_overlay_layer()
	var rs: Control = RESULT_SCREEN_SCENE.instantiate() as Control
	overlay_layer.add_child(rs)
	var player_name_text: String = ""
	if get_tree().root.has_meta("player_name"):
		player_name_text = str(get_tree().root.get_meta("player_name"))
	rs.call_deferred("set_result", won, energy, target, player_name_text)

# Popup helper
func show_popup_message(text: String, _id: String = "") -> void:
	_ensure_overlay_layer()
	var panel_size := Vector2(720, 140)
	var right_offset_px: float = 200.0
	var font_size_px: int = 36
	var padding_px: int = 20

	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.9)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.modulate = Color(1, 1, 1, 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = right_offset_px
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = right_offset_px + panel_size.x
	panel.offset_bottom = -panel_size.y * 0.5 + panel_size.y
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.scroll_active = false
	lbl.fit_content = true
	lbl.add_theme_font_size_override("normal_font_size", font_size_px)
	lbl.add_theme_color_override("default_color", Color("#314219"))
	lbl.text = "[left]" + text + "[/left]"
	lbl.anchor_left = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_top = 0.0
	lbl.anchor_bottom = 1.0
	lbl.offset_left = padding_px
	lbl.offset_right = -padding_px
	lbl.offset_top = padding_px
	lbl.offset_bottom = -padding_px
	panel.add_child(lbl)
	overlay_layer.add_child(panel)

	await get_tree().process_frame
	var actual_height: float = lbl.get_content_height() + padding_px * 2
	panel.offset_top = -actual_height * 0.5
	panel.offset_bottom = actual_height * 0.5
	panel.offset_right = right_offset_px + 720.0

	var tw := create_tween()
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.18)
	tw.tween_interval(1.6)
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.finished.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)

# UI helpers
func _set_ui_visible(v: bool) -> void:
	# Preferred: hide/show every node in the “ui” group (your UI CanvasLayer should be in this group)
	get_tree().call_group("ui", "set_visible", v)

	# Fallback: also try a node named “UI” if present (in case the group is missing in some scenes)
	var ui := get_node_or_null("UI") as CanvasItem
	if ui:
		ui.visible = v

func _hide_ui() -> void:
	_set_ui_visible(false)

# Resolve UI nodes (fallbacks if UI.gd is missing)
func _resolve_ui_refs() -> void:
	ui_root = get_node_or_null("UI")
	if ui_root == null:
		ui_root = get_tree().root.find_child("UI", true, false)
	timer_label = _resolve_label(NodePath(), "UI/VBoxContainer/TimerLabel", "TimerLabel")
	player_name_label = _resolve_label(NodePath(), "UI/VBoxContainer/PlayerNameLabel", "PlayerNameLabel")
	if player_name_label == null:
		player_name_label = _resolve_label(NodePath(), "UI/VBoxContainer/PlayerNameLabe", "PlayerNameLabe")
	energy_label = _resolve_label(NodePath(), "UI/VBoxContainer/Energy/EnergyLabel", "EnergyLabel")

func _resolve_speed_label() -> void:
	if _speed_label != null:
		return
	_speed_label = _resolve_label(NodePath(), "UI/VBoxContainer/Speed/SpeedLabel", "SpeedLabel")

func _resolve_label(exported: NodePath, canonical_path: String, name_only: String) -> Label:
	var n: Node = null
	if not exported.is_empty():
		n = _resolve_node_safe(exported)
	if n == null:
		n = get_node_or_null(NodePath(canonical_path))
	if n == null:
		if ui_root:
			n = ui_root.find_child(name_only, true, false)
		else:
			n = get_tree().root.find_child(name_only, true, false)
	return n as Label

# Overlay layer helper
func _ensure_overlay_layer() -> void:
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		overlay_layer.layer = 10
		add_child(overlay_layer)

# Small UI caller that prefers UI.gd methods
func _ui_call(method: StringName, args: Array = []) -> void:
	if ui_root and ui_root.has_method(method):
		ui_root.callv(method, args)

# Formatting/utilities
func _format_time(t: int) -> String:
	var m: int = int(t / 60.0)
	var s: int = t % 60
	return "%02d:%02d" % [m, s]

func _resolve_node_safe(path: NodePath) -> Node:
	if path.is_empty(): return null
	if not is_inside_tree(): return null
	if path.is_absolute(): return get_tree().root.get_node_or_null(path)
	return get_node_or_null(path)

func _has_property(obj: Object, prop: StringName) -> bool:
	for d in obj.get_property_list():
		if typeof(d) == TYPE_DICTIONARY and d.has("name") and StringName(d["name"]) == prop:
			return true
	return false

func _set_if_has_property(obj: Object, prop: StringName, value) -> void:
	if _has_property(obj, prop):
		obj.set(prop, value)

func _scan_and_fix_nodepaths(root: Node, auto_fix: bool = true) -> void:
	_scan_np_recursive(root, auto_fix)

func _scan_np_recursive(n: Node, auto_fix: bool) -> void:
	for d in n.get_property_list():
		if typeof(d) == TYPE_DICTIONARY and d.has("type") and int(d["type"]) == TYPE_NODE_PATH:
			var pname: StringName = StringName(d["name"])
			var np: NodePath = n.get(pname) as NodePath
			if np != null and not np.is_empty() and np.is_absolute():
				var target: Node = get_tree().root.get_node_or_null(np)
				if target != null:
					var rel: NodePath = n.get_path_to(target)
					if auto_fix:
						n.set(pname, rel)
					print("Fixed absolute NodePath: ", n.get_path(), ".", String(pname), " -> ", String(rel))
				else:
					print("Found absolute NodePath but target missing: ", n.get_path(), ".", String(pname), " = ", String(np))
	for c in n.get_children():
		if c is Node:
			_scan_np_recursive(c, auto_fix)
