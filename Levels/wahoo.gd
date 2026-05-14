extends Node

# --- PASO 1: Asegúrate de que estas rutas coincidan con tu árbol de nodos ---
@onready var gestor = $GestorWahoo
@onready var label_power = $LabelPower
@onready var label_speed = $LabelSpeed

func _ready():
	# --- TU CÓDIGO DEL .BAT (Esto está bien) ---
	#var ruta_bat = ProjectSettings.globalize_path("res://arrancar.bat")
	#var ruta_segura = "file:///" + ruta_bat
	#OS.shell_open(ruta_segura)
	
	# --- PASO 2: Conectar las señales del controlador ---
	# Usamos 'gestor' (el nodo), NO 'WahooController' (la clase)
	gestor.power_updated.connect(_on_power_updated)
	gestor.speed_updated.connect(_on_speed_updated)

# --- PASO 3: Funciones para actualizar las etiquetas ---
func _on_power_updated(watts: int):
	# Aquí es donde usas el nuevo nombre de tu etiqueta
	label_power.text = str(watts) + " W"

func _on_speed_updated(kmh: float):
	# Formateamos a un decimal para que no baile mucho el texto
	label_speed.text = "%.1f km/h" % kmh
