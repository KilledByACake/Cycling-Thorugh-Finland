extends Node2D

const ROUND_TIME_SEC := 10
const TARGET_ENERGY := 200
const RESULT_SCREEN_SCENE := preload("res://Levels/ResultScreen.tscn") # update path if needed

var coins_collected: int = 0
var energy_points: int = 0

@onready var coin_label: Label = get_node_or_null("UI/Coin/Label")
@onready var energy_label: Label = get_node_or_null("UI/Energy/Label")
@onready var fuel_bar: ProgressBar = get_node_or_null("UI/TextureRect/ProgressBar")
@onready var player_name_label: Label = get_node_or_null("UI/PlayerNameLabel")
@onready var timer_label: Label = get_node_or_null("UI/TimerLabel")
@onready var overlay_layer: CanvasLayer = get_node_or_null("OverlayLayer")

var game_timer: Timer

func _ready() -> void:
	if fuel_bar:
		fuel_bar.visible = false
	_refresh_coin_ui()
	_refresh_energy_ui()
	_update_player_name_from_tree()
	_start_round_timer()

func _process(_delta: float) -> void:
	if game_timer and timer_label:
		var t := int(ceil(game_timer.time_left))
		timer_label.text = _format_time(t)

func add_coins(amount: int) -> void:
	coins_collected += amount
	_refresh_coin_ui()

func update_energy_UI(value: int) -> void:
	energy_points = value
	_refresh_energy_ui()

func update_fuel_UI(_value: float) -> void:
	if fuel_bar:
		fuel_bar.visible = false

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
	var won := energy_points >= TARGET_ENERGY
	_show_result_screen(won, energy_points, TARGET_ENERGY)

func _show_result_screen(won: bool, energy: int, target: int) -> void:
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		overlay_layer.layer = 10
		add_child(overlay_layer)

	var rs := RESULT_SCREEN_SCENE.instantiate()
	var player_name := ""
	if get_tree().has_meta("player_name"):
		player_name = str(get_tree().get_meta("player_name"))

	if rs.has_method("set_result"):
		rs.set_result(won, energy, target, player_name)

	overlay_layer.add_child(rs)

func _format_time(t: int) -> String:
	var m := t / 60
	var s := t % 60
	return "%02d:%02d" % [m, s]
