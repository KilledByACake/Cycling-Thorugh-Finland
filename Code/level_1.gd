extends Node2D

signal round_over(won: bool)

@export_node_path("Path2D") var rail_path: NodePath
@export var trigger_path_rebuild: bool = true   # set false if your Path2D builds itself (@tool path2d.gd)
@export var randomize_seed_on_play: bool = true # set false while designing to match editor/runtime

# Round config
const ROUND_TIME_SEC: int = 150               # adjust as you want
const TARGET_ENERGY: int = 200
const BANNER_DURATION_SEC: float = 2.0

# Result/Banner scenes
const GAME_OVER_SCENE: PackedScene = preload("res://Screen/GameOver.tscn")
const YOU_WON_SCENE: PackedScene = preload("res://Screen/Victory.tscn")
const RESULT_SCREEN_SCENE: PackedScene = preload("res://Screen/Result.tscn")

# Runtime state
var coins_collected: int = 0
var energy_points: int = 0
var round_finished: bool = false
var game_timer: Timer

# UI refs (match your node paths)
@onready var coin_label: Label = get_node_or_null("UI/Coin/Label") as Label
@onready var energy_label: Label = get_node_or_null("UI/Energy/Label") as Label
@onready var player_name_label: Label = get_node_or_null("UI/PlayerNameLabel") as Label
@onready var timer_label: Label = get_node_or_null("UI/TimerLabel") as Label
@onready var overlay_layer: CanvasLayer = get_node_or_null("OverlayLayer") as CanvasLayer

# HILL
@export var hill_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var terrain_difficulty: float = 0.4
@export var terrain_length: int = 8000
@export var terrain_base_y: float = 420.0
@export var terrain_amplitude: float = 80.0
@export var terrain_noise_frequency: float = 0.0018
@export var terrain_max_slope_deg: float = 18.0
@export var terrain_sample_step: int = 4

func _ready():
	_ensure_overlay_layer()
	_scan_and_fix_nodepaths(self, true)
	_spawn_terrain()
	_refresh_coin_ui()
	_refresh_energy_ui()
	_update_player_name_from_tree()
	_start_round_timer()

func _spawn_terrain() -> void:
	if hill_scene == null:
		push_warning("hill_scene is not set.")
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

func _process(_delta: float) -> void:
	if round_finished:
		return
	if game_timer and timer_label:
		var t: int = max(0, int(ceil(game_timer.time_left)))
		timer_label.text = _format_time(t)

# Called by player scripts to update UI/state
func add_coins(amount: int) -> void:
	if round_finished:
		return
	coins_collected += amount
	_refresh_coin_ui()

func update_energy_UI(value: int) -> void:
	if round_finished:
		return
	energy_points = value
	_refresh_energy_ui()

func _refresh_coin_ui() -> void:
	if coin_label:
		coin_label.text = str(coins_collected)

func _refresh_energy_ui() -> void:
	if energy_label:
		energy_label.text = str(energy_points)

func _update_player_name_from_tree() -> void:
	if not player_name_label:
		return
	var n := ""
	if get_tree().has_meta("player_name"):
		n = str(get_tree().get_meta("player_name"))
	if n != "":
		player_name_label.text = n

func _start_round_timer() -> void:
	game_timer = Timer.new()
	game_timer.one_shot = true
	game_timer.wait_time = ROUND_TIME_SEC
	add_child(game_timer)
	game_timer.timeout.connect(_finish_round)
	game_timer.start()
	if timer_label:
		timer_label.text = _format_time(ROUND_TIME_SEC)

func _finish_round() -> void:
	if round_finished:
		return
	round_finished = true
	if timer_label:
		timer_label.text = "00:00"

	var won: bool = energy_points >= TARGET_ENERGY
	_freeze_world()
	emit_signal("round_over", won)

	await _show_banner_overlay(won)
	_show_result_screen_overlay(won, energy_points, TARGET_ENERGY)

func _freeze_world() -> void:
	get_tree().call_group("freezable", "freeze")
	_freeze_recursive(self)

func _freeze_recursive(n: Node) -> void:
	if n == null:
		return
	if (n is CanvasLayer) and (n.name == "UI" or n.name == "OverlayLayer"):
		return
	_freeze_node(n)
	for c in n.get_children():
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
	var player_name_text := ""
	if get_tree().has_meta("player_name"):
		player_name_text = str(get_tree().get_meta("player_name"))
	rs.call_deferred("set_result", won, energy, target, player_name_text)

# Simple popup API (Pickups can call: level.show_popup_message("Picked a blueberry!"))
func show_popup_message(text: String, id: String = "") -> void:
	_ensure_overlay_layer()
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.modulate = Color(1, 1, 1, 0)

	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -250
	label.offset_right = 250
	label.offset_top = 20
	label.offset_bottom = 60

	overlay_layer.add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.finished.connect(func ():
		if is_instance_valid(label):
			label.queue_free()
	)

func _ensure_overlay_layer() -> void:
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		overlay_layer.layer = 10
		add_child(overlay_layer)

func _format_time(t: int) -> String:
	var m: int = int(t / 60.0)
	var s: int = t % 60
	return "%02d:%02d" % [m, s]

# --- Helpers -------------------------------------------------------------

func _resolve_node_safe(path: NodePath) -> Node:
	if path.is_empty():
		return null
	if not is_inside_tree():
		return null
	if path.is_absolute():
		return get_tree().root.get_node_or_null(path)
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
			var np: NodePath = n.get(pname)
			if np is NodePath and not np.is_empty() and np.is_absolute():
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
