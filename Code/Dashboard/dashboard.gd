extends Control

const MAIN_SCENE_PATH: String = "res://Levels/Main.tscn"

@export var gauge_path: NodePath
@export var solar_data_path: NodePath

@onready var label_speed = %LabelSpeed
@onready var label_power = %LabelPower

var gauge: Control

# Resolves nodes and connects the solar data signal.
func _ready() -> void:
	gauge = get_node_or_null(gauge_path) as Control
	var data_node := get_node_or_null(solar_data_path)

	if data_node and data_node.has_signal("solar2_changed"):
		if not data_node.is_connected("solar2_changed", Callable(self, "_on_solar2_changed")):
			data_node.connect("solar2_changed", Callable(self, "_on_solar2_changed"))
	else:
		push_error("SolarData not found or missing 'solar2_changed' signal. Set 'solar_data_path'.")

	if gauge == null:
		push_error("SolarGauge not found. Set 'gauge_path'.")

# Updates labels each frame.
func _process(_delta: float) -> void:
	if label_speed:
		label_speed.text = "%.1f" % GlobalWahoo.speed
	if label_power:
		label_power.text = str(GlobalWahoo.power) + " W"

# Receives new solar value and updates the gauge.
func _on_solar2_changed(v: float) -> void:
	print("Dashboard: solar2 =", v)
	if gauge:
		gauge.set("value", v)


func _on_back_pressed() -> void:
	# Go straight to main menu from here (no parent needed).
	if ResourceLoader.exists(MAIN_SCENE_PATH):
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		# Optional: keep the signal if any parent also listens.
	else:
		push_error("Main scene not found: " + MAIN_SCENE_PATH)
