@tool
extends Label

@export var test_power: float = 250.0
@export var test_wind_speed: float = 5.0
@export var coeff: float = 1.35

# Updates the label text each frame using power and wind speed.
func _process(_delta: float) -> void:
	var p: float
	var v: float

	if Engine.is_editor_hint():
		p = test_power
		v = test_wind_speed
	else:
		p = float(GlobalWahoo.power)
		v = float(GlobalWahoo.speed)

	var diameter: float = 0.0
	if v > 0.0 and p > 0.0:
		diameter = sqrt((8.0 * p) / (coeff * pow(v, 3.0)))

	text = "Whooooooosh!\nYou are about a %.2f m of a wind turbine." % diameter
