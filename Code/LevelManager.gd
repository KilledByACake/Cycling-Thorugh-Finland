extends Node2D

var coins_collected: int = 0
var energy_points: int = 0

@onready var coin_label: Label = get_node_or_null("UI/Coin/Label")
@onready var energy_label: Label = get_node_or_null("UI/Energy/Label")
@onready var fuel_bar: ProgressBar = get_node_or_null("UI/TextureRect/ProgressBar")  # old fuel

func _ready() -> void:
	# Hide the old fuel bar (we don't use fuel anymore)
	if fuel_bar:
		fuel_bar.visible = false
	_refresh_coin_ui()
	_refresh_energy_ui()

# Coins (unchanged)
func add_coins(amount: int) -> void:
	coins_collected += amount
	_refresh_coin_ui()

# Energy (called from Player.gd)
func update_energy_UI(value: int) -> void:
	energy_points = value
	_refresh_energy_ui()

# Backward compatibility: if something still calls this, do nothing
func update_fuel_UI(_value: float) -> void:
	if fuel_bar:
		fuel_bar.visible = false

func _refresh_coin_ui() -> void:
	if coin_label:
		coin_label.text = str(coins_collected)

func _refresh_energy_ui() -> void:
	if energy_label:
		energy_label.text = str(energy_points)
