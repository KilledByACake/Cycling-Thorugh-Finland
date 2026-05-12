@tool # This allows the script to run inside the Godot Editor
extends Label

func _process(_delta: float) -> void:
	# 1. Define or fetch your variables
	# Note: If GlobalWahoo is an Autoload, it might not work in-editor.
	# You can set temporary values for testing in the editor.
	var p: float = 250.0 
	var v: float = 5.0
	
	# Try to get live data if the game is actually running
	if not Engine.is_editor_hint():
		# Replace these with your actual node paths or Autoloads
		# p = GlobalWahoo.power
		# v = GlobalWahoo.wind_speed
		pass

	# 2. Translation of the formula from grafik_3.png
	var diameter: float = 0.0
	if v > 0:
		# Formula: sqrt( (8 * P) / (1.35 * V^3) )
		diameter = sqrt((8.0 * p) / (1.35 * pow(v, 3)))
	
	# 3. Update the text
	# Formatting to lower case as requested
	var raw_text = "you are producing power equals to %.2f m wind turbine diameter" % diameter
	text = raw_text
