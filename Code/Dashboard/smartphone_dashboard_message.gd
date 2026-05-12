@tool
extends Label

func _process(_delta: float) -> void:
	# 1. Get Power (P) from your Wahoo node
	var p: float = 100.0 # Default value for the editor view
	
	if not Engine.is_editor_hint():
		# This runs when the game is actually playing
		p = GlobalWahoo.power
	
	# 2. Translate the formula from grafik_4.png
	var time_minutes: float = 0.0
	
	# Prevent division by zero if the player isn't pedaling
	if p > 0:
		time_minutes = 1200.0 / (0.65 * p)
	
	# 3. Update the label text in lowercase
	# %.1f rounds the minutes to one decimal place (e.g., 18.5)
	text = "Your smart phone could be fully charged in %.1f minutes." % time_minutes
