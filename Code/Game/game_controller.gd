extends Node2D

signal round_over(won: bool)

@export_node_path("Path2D") var rail_path: NodePath
@export var trigger_path_rebuild: bool = true
@export var randomize_seed_on_play: bool = true

# Win when the player reaches PathRight (configure these to match your scene).
@export_node_path("Area2D") var goal_area_path: NodePath = NodePath("Path2D/PathRight")  # If PathRight is an Area2D
@export_node_path("Node2D") var goal_node_path: NodePath = NodePath("Path2D/PathRight")  # Fallback if PathRight is Node2D

const ROUND_TIME_SEC: int = 100
const TARGET_ENERGY: int = 200
const BANNER_DURATION_SEC: float = 2.0

const GAME_OVER_SCENE: PackedScene = preload("res://Screen/GameOver.tscn")
const YOU_WON_SCENE: PackedScene = preload("res://Screen/Victory.tscn")
const RESULT_SCREEN_SCENE: PackedScene = preload("res://Screen/Result.tscn")

var energy_points: int = 0
var round_finished: bool = false
var game_timer: Timer

# Timer blinking (UI)
@export var timer_blink_threshold_sec: int = 5
@export var timer_blink_interval_sec: float = 0.3
@export var timer_blink_color: Color = Color(1, 0.2, 0.2)
@export var timer_normal_color: Color = Color(1, 1, 1)

var _timer_blink_active: bool = false
var _timer_blink_accum: float = 0.0
var _timer_blink_state: bool = false

# UI references (resolved at runtime)
var ui_root: CanvasLayer
var player_name_label: Label
var timer_label: Label
var energy_label: Label

@export var hill_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var terrain_difficulty: float = 0.4
@export var terrain_length: int = 8000
@export var terrain_base_y: float = 420.0
@export var terrain_amplitude: float = 80.0
@export var terrain_noise_frequency: float = 0.0018
@export var terrain_max_slope_deg: float = 18.0
@export var terrain_sample_step: int = 4

# Inactivity → Game Over (10s total), with warning blink for last 5s of inactivity
@export var inactivity_timeout_sec: float = 10.0
@export var inactivity_warning_threshold_sec: float = 5.0
var inactivity_timer: Timer
var inactivity_warning_timer: Timer
var _blink_due_to_inactivity: bool = false

# Overlay
var overlay_layer: CanvasLayer

# Called when the node enters the scene tree; sets up terrain, UI, timers, and goal trigger.
func _ready() -> void:
	_ensure_overlay_layer()
	_scan_and_fix_nodepaths(self, true)
	# Only spawn terrain if a scene is provided to avoid warnings.
	if hill_scene != null:
		_spawn_terrain()
	await get_tree().process_frame
	_resolve_ui_refs()
	_refresh_energy_ui()
	_update_player_name_from_tree()
	_start_round_timer()
	_setup_inactivity_detection()
	_connect_goal_area()  # Connect PathRight (Area2D) if available

# Spawns terrain instance and configures its exported properties.
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
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		if _has_property(hill, "rng_seed"):
			hill.set("rng_seed", rng.randi())
		elif _has_property(hill, "seed"):
			hill.set("seed", rng.randi())
	add_child(hill)
	await get_tree().process_frame
	_scan_and_fix_nodepaths(self, true)
	if trigger_path_rebuild:
		var p2d: Path2D = _resolve_node_safe(rail_path) as Path2D
		if p2d != null and p2d.has_method("rebuild_auto"):
			p2d.call("rebuild_auto")
		elif p2d != null and p2d.has_method("_rebuild_from_terrain"):
			p2d.call("_rebuild_from_terrain")

# Per-frame update; updates timer UI and checks goal (fallback for Node2D goal).
func _process(delta: float) -> void:
	if round_finished:
		return
	if GlobalWahoo.power > 1: # Si hay más de 1W, el jugador está activo
		_on_player_pedaled()
	if game_timer and timer_label:
		var t: int = max(0, int(ceil(game_timer.time_left)))
		timer_label.text = _format_time(t)
		# Blink if round timer is low or inactivity warning is active.
		var should_blink: bool = (t <= timer_blink_threshold_sec) or _blink_due_to_inactivity
		_enable_timer_blink(should_blink)
		_update_timer_blink(delta)

	# Fallback win: if PathRight is a Node2D, finish when the player crosses its X.
	var goal_node: Node2D = _resolve_node_safe(goal_node_path) as Node2D
	if not round_finished and goal_node != null:
		var player_nd: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player_nd == null:
			player_nd = get_tree().get_first_node_in_group("radler") as Node2D
		if player_nd != null and player_nd.global_position.x >= goal_node.global_position.x:
			_finish_as_victory()

# Increases energy by amount and refreshes UI.
func add_energy(amount: int) -> void:
	if round_finished:
		return
	energy_points += amount
	_refresh_energy_ui()

# Sets energy to a specific value and refreshes UI.
func update_energy_UI(value: int) -> void:
	if round_finished:
		return
	energy_points = value
	_refresh_energy_ui()

# Updates the energy UI (via UI script method or fallback label).
func _refresh_energy_ui() -> void:
	if ui_root and ui_root.has_method("set_energy"):
		ui_root.call("set_energy", energy_points)
		return
	if ui_root:
		if energy_label == null:
			var node: Node = ui_root.get_node_or_null("Energy/Label")
			if node == null:
				var energy_node: Node = ui_root.get_node_or_null("Energy")
				if energy_node:
					energy_label = energy_node.find_child("Label", true, false) as Label
			else:
				energy_label = node as Label
		if energy_label:
			energy_label.text = str(energy_points)

# Pulls the player name from the tree metadata into the label.
func _update_player_name_from_tree() -> void:
	if not player_name_label:
		return
	var n: String = ""
	if get_tree().root.has_meta("player_name"):
		n = str(get_tree().root.get_meta("player_name"))
	if n != "":
		player_name_label.text = n

# Starts the round timer and initializes UI for the countdown.
func _start_round_timer() -> void:
	game_timer = Timer.new()
	game_timer.one_shot = true
	game_timer.wait_time = ROUND_TIME_SEC
	add_child(game_timer)
	game_timer.timeout.connect(_finish_round)
	game_timer.start()
	if timer_label:
		timer_label.text = _format_time(ROUND_TIME_SEC)
		_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)

# Called when the round timer finishes; freezes world and shows results (win by energy).
func _finish_round() -> void:
	if round_finished:
		return
	round_finished = true
	if timer_label:
		timer_label.text = "00:00"
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)
	_blink_due_to_inactivity = false
	var won: bool = energy_points >= TARGET_ENERGY
	_freeze_world()
	emit_signal("round_over", won)
	await _show_banner_overlay(won)
	_show_result_screen_overlay(won, energy_points, TARGET_ENERGY)

# Sets up inactivity timers and connects to pedaling signal.
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

	# Start both timers; pedaling will keep resetting them.
	inactivity_warning_timer.start()
	inactivity_timer.start()

	#var radler: Node = get_tree().get_first_node_in_group("radler")
	#if radler and radler.has_signal("pedal_tapped"):
	#	radler.connect("pedal_tapped", Callable(self, "_on_player_pedaled"))

# Handles player pedaling; resets inactivity timers and updates blink state.
func _on_player_pedaled() -> void:
	if round_finished:
		return
	if inactivity_warning_timer:
		inactivity_warning_timer.start()
	if inactivity_timer:
		inactivity_timer.start()
	_blink_due_to_inactivity = false
	if game_timer and timer_label:
		var t: int = max(0, int(ceil(game_timer.time_left)))
		_enable_timer_blink((t <= timer_blink_threshold_sec) or _blink_due_to_inactivity)

# Called when inactivity warning threshold elapses; enables blink.
func _on_inactivity_warning_timeout() -> void:
	if round_finished:
		return
	_blink_due_to_inactivity = true

# Called when inactivity timeout elapses; ends the round as a loss.
func _on_inactivity_timeout() -> void:
	if round_finished:
		return
	_game_over_due_to_inactivity()

# Ends the round due to inactivity and shows overlays.
func _game_over_due_to_inactivity() -> void:
	round_finished = true
	if game_timer:
		game_timer.stop()
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)
	_blink_due_to_inactivity = false
	_freeze_world()
	emit_signal("round_over", false)
	await _show_banner_overlay(false)
	_show_result_screen_overlay(false, energy_points, TARGET_ENERGY)

# Connects to PathRight (Area2D) once; safe if PathRight is not an Area2D.
func _connect_goal_area() -> void:
	var area: Area2D = _resolve_node_safe(goal_area_path) as Area2D
	if area != null and not area.body_entered.is_connected(_on_goal_area_body_entered):
		area.body_entered.connect(_on_goal_area_body_entered)

# Called when the player enters PathRight (Area2D); finishes as victory.
func _on_goal_area_body_entered(body: Node) -> void:
	if round_finished:
		return
	if body != null and (body.is_in_group("player") or body.is_in_group("radler")):
		_finish_as_victory()

# Ends the round immediately as a win and shows Victory.
func _finish_as_victory() -> void:
	if round_finished:
		return
	round_finished = true
	# Stop timers/blink and reset colors.
	if game_timer:
		game_timer.stop()
	if inactivity_warning_timer:
		inactivity_warning_timer.stop()
	if inactivity_timer:
		inactivity_timer.stop()
	_set_timer_label_color(timer_normal_color)
	_enable_timer_blink(false)
	_blink_due_to_inactivity = false

	# ADD: trigger celebrate and wait until it finishes (plays once)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("start_celebrate"):
		p.call("start_celebrate")
		var spr := p.get("sprite") as AnimatedSprite2D
		if spr and spr.is_playing():
			await spr.animation_finished

	# Freeze world and show overlays.
	_freeze_world()
	emit_signal("round_over", true)
	await _show_banner_overlay(true)
	_show_result_screen_overlay(true, energy_points, TARGET_ENERGY)

# Enables or disables timer blinking and resets blink state.
func _enable_timer_blink(v: bool) -> void:
	if _timer_blink_active == v:
		return
	_timer_blink_active = v
	_timer_blink_accum = 0.0
	_timer_blink_state = false
	_set_timer_label_color(timer_normal_color)

# Updates blink timer and toggles label color.
func _update_timer_blink(delta: float) -> void:
	if not _timer_blink_active or timer_label == null:
		return
	_timer_blink_accum += delta
	if _timer_blink_accum >= timer_blink_interval_sec:
		_timer_blink_accum = 0.0
		_timer_blink_state = not _timer_blink_state
		_set_timer_label_color(timer_blink_color if _timer_blink_state else timer_normal_color)

# Sets the timer label color (with theme override and tint).
func _set_timer_label_color(col: Color) -> void:
	if timer_label == null:
		return
	timer_label.add_theme_color_override("font_color", col)
	timer_label.modulate = col

# Freezes the entire world except UI layers.
func _freeze_world() -> void:
	get_tree().call_group("freezable", "freeze")
	_freeze_recursive(self)

# Recursively freezes nodes, skipping UI layers.
func _freeze_recursive(n: Node) -> void:
	if n == null:
		return
	if (n is CanvasLayer) and (n.name == "UI" or n.name == "OverlayLayer"):
		return
	_freeze_node(n)
	for c in n.get_children():
		_freeze_recursive(c)

# Applies freeze behavior to a single node.
func _freeze_node(n: Node) -> void:
	if n is CharacterBody2D:
		var cb: CharacterBody2D = n as CharacterBody2D
		cb.velocity = Vector2.ZERO
		cb.set_physics_process(false)
	elif n is RigidBody2D:
		var rb: RigidBody2D = n as RigidBody2D
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

# Shows a brief banner overlay (win/lose) then hides it.
func _show_banner_overlay(won: bool) -> void:
	_ensure_overlay_layer()
	var scene: PackedScene = YOU_WON_SCENE if won else GAME_OVER_SCENE
	var banner: Control = scene.instantiate() as Control
	overlay_layer.add_child(banner)
	await get_tree().create_timer(BANNER_DURATION_SEC).timeout
	if is_instance_valid(banner):
		banner.queue_free()

# Shows the result screen overlay and passes result data.
func _show_result_screen_overlay(won: bool, energy: int, target: int) -> void:
	_ensure_overlay_layer()
	var rs: Control = RESULT_SCREEN_SCENE.instantiate() as Control
	overlay_layer.add_child(rs)
	var player_name_text: String = ""
	if get_tree().root.has_meta("player_name"):
		player_name_text = str(get_tree().root.get_meta("player_name"))
	rs.call_deferred("set_result", won, energy, target, player_name_text)

# Shows a temporary popup message near the right side of the screen.
func show_popup_message(text: String, _id: String = "") -> void:
	_ensure_overlay_layer()
	var panel_size: Vector2 = Vector2(720, 140)
	var right_offset_px: float = 200.0
	var font_size_px: int = 36
	var padding_px: int = 20
	var panel: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.9) # BG Color
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
	var lbl: RichTextLabel = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.scroll_active = false
	lbl.fit_content = true  # box expands in height so text fits
	lbl.add_theme_font_size_override("normal_font_size", font_size_px)
	lbl.add_theme_color_override("default_color", Color("#314219"))  # Font Color
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
	
	#auto height calculation
	await get_tree().process_frame
	var actual_height: float = lbl.get_content_height() + padding_px * 2
	panel.offset_top = -actual_height * 0.5
	panel.offset_bottom = actual_height * 0.5
	panel.offset_right = right_offset_px + 720.0
	
	var tw: Tween = create_tween()
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.18)
	tw.tween_interval(1.6)
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.finished.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)

# Finds and stores UI nodes (labels) for later updates.
func _resolve_ui_refs() -> void:
	ui_root = get_node_or_null("UI") as CanvasLayer
	if ui_root:
		timer_label = ui_root.get_node_or_null("TimerLabel") as Label
		if timer_label == null:
			timer_label = ui_root.find_child("TimerLabel", true, false) as Label
		player_name_label = ui_root.get_node_or_null("PlayerNameLabel") as Label
		if player_name_label == null:
			player_name_label = ui_root.find_child("PlayerNameLabel", true, false) as Label

# Ensures there is a layer to host transient overlays.
func _ensure_overlay_layer() -> void:
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		overlay_layer.layer = 10
		add_child(overlay_layer)

# Formats seconds as MM:SS.
func _format_time(t: int) -> String:
	var m: int = int(t / 60.0)
	var s: int = t % 60
	return "%02d:%02d" % [m, s]

# Safely resolves a NodePath to a node (handles absolute/relative).
func _resolve_node_safe(path: NodePath) -> Node:
	if path.is_empty():
		return null
	if not is_inside_tree():
		return null
	if path.is_absolute():
		return get_tree().root.get_node_or_null(path)
	return get_node_or_null(path)

# Checks if an object has a property by name.
func _has_property(obj: Object, prop: StringName) -> bool:
	for d in obj.get_property_list():
		if typeof(d) == TYPE_DICTIONARY and d.has("name") and StringName(d["name"]) == prop:
			return true
	return false

# Sets a property if it exists on the object.
func _set_if_has_property(obj: Object, prop: StringName, value) -> void:
	if _has_property(obj, prop):
		obj.set(prop, value)

# Scans tree for absolute NodePaths and converts them to relative.
func _scan_and_fix_nodepaths(root: Node, auto_fix: bool = true) -> void:
	_scan_np_recursive(root, auto_fix)

# Recursive helper: rewrite absolute NodePaths on a node (and its children) to relative paths.
func _scan_np_recursive(n: Node, auto_fix: bool) -> void:
	# Check all properties; if a property is a NodePath and absolute, try to make it relative.
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
	# Recurse into children.
	for c in n.get_children():
		if c is Node:
			_scan_np_recursive(c, auto_fix)
