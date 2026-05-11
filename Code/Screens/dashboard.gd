extends Control

# Dashboard HUD: shows current speed and power from GlobalWahoo and returns to Main after inactivity.

# Node references (labels must have unique names in the scene)
@onready var label_speed = %LabelSpeed       # Displays current speed (e.g., km/h)
@onready var label_power = %LabelPower       # Displays current power in watts

# Paths and inactivity settings
const MAIN_MENU := "res://Levels/Main.tscn"  # Scene to load when timing out
@export var inactivity_timeout_sec: float = 10.0        # Seconds without pedaling before returning to main
@export var inactivity_power_threshold: float = 1.0     # Considered "not cycling" when power <= this

# Internal state
var _inactive_elapsed: float = 0.0                       # Accumulated idle time (seconds)

func _process(delta: float) -> void:
	# Update the speed label every frame (one decimal place)
	if label_speed:
		label_speed.text = "%.1f" % GlobalWahoo.speed

	# Update the power label every frame (in watts)
	if label_power:
		label_power.text = str(GlobalWahoo.power) + " W"

	# Inactivity check: accumulate time when power is at or below the threshold
	var power_now: float = float(GlobalWahoo.power)
	if power_now <= inactivity_power_threshold:
		_inactive_elapsed += delta
		if _inactive_elapsed >= inactivity_timeout_sec:
			if get_tree().paused:
				get_tree().paused = false
			get_tree().change_scene_to_file(MAIN_MENU)
	else:
		# Reset the timer as soon as the player starts pedaling again
		_inactive_elapsed = 0.0

func _on_back_pressed() -> void:
	# Back button: unpause (if needed) and return to main menu immediately
	if get_tree().paused:
		get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
