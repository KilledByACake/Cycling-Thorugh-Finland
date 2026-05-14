@tool
extends Label

@export var test_power: float = 100.0           # Editor-only preview power (W)
@export var battery_wh: float = 20.0            # Smartphone battery capacity (Wh)
@export var charge_efficiency: float = 0.65     # Charging efficiency (0–1)

# Enables per-frame updates.
func _ready() -> void:
	set_process(true)

# Updates the label text each frame based on power and charging model.
func _process(_delta: float) -> void:
	var p: float
	if Engine.is_editor_hint():
		p = test_power
	else:
		p = float(GlobalWahoo.power)

	var time_minutes: float = 0.0
	var denom: float = charge_efficiency * p
	if denom > 0.0:
		time_minutes = (60.0 * battery_wh) / denom

	text = "Funfact!\nYou need to cycle %.1f more minutes to charge a phone." % time_minutes
