extends Control

# --- PASO 1: Referencia a las etiquetas ---
@onready var label_speed = %LabelSpeed
@onready var label_power = %LabelPower  # Cambiado para que coincida con tu árbol de nodos

const MAIN_MENU := "res://Levels/Main.tscn"

# --- PASO 2: Actualización constante ---
func _process(_delta: float) -> void:
	# Actualizar Velocidad
	if label_speed:
		label_speed.text = "%.1f" % GlobalWahoo.speed
	
	# Actualizar Potencia (He quitado el # para que el código funcione)
	if label_power:
		label_power.text = str(GlobalWahoo.power) + " W"

# --- PASO 3: Tu lógica existente de navegación ---
func _on_back_pressed() -> void:
	if get_tree().paused:
		get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
