extends Node2D

signal round_over(won: bool)

# Round config
const ROUND_TIME_SEC: int = 6               # adjust as you want
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

@export var hill_scene: PackedScene  

var game_timer: Timer

func _ready():
	_ensure_overlay_layer()
	var hill = hill_scene.instantiate()
	hill.hill_seed = 42
	hill.position = Vector2(-3000, 0)
	add_child(hill)

	
	
	_refresh_coin_ui()
	_refresh_energy_ui()
	_update_player_name_from_tree()
	_start_round_timer()

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
	# 1) Ask all "freezable" nodes to stop themselves (PathFollow2D, Radler, etc.)
	get_tree().call_group("freezable", "freeze")
	# 2) Hard-disable processing on the whole level (except UI layers) to catch stragglers
	_freeze_recursive(self)

func _freeze_recursive(n: Node) -> void:
	if n == null:
		return
	# Skip UI layers so result screen still works
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
	# Stop common animations/emitters
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
	# Defer so the result UI is ready
	rs.call_deferred("set_result", won, energy, target, player_name_text)

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
