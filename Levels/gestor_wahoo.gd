extends Node

signal power_updated(watts: int)
signal speed_updated(kmh: float)

# ... resto del código ...
func _ready():
	# 1. Obtenemos la ruta normal
	var ruta_bat = ProjectSettings.globalize_path("res://arrancar.bat")
	
	# 2. Le ponemos el escudo "file:///" por delante
	var ruta_segura = "file:///" + ruta_bat
	
	print("Intentando abrir de forma segura: ", ruta_segura)
	
	# 3. Disparamos
	var error = OS.shell_open(ruta_segura)
	
	if error == OK:
		print("¡Windows lo ha aceptado!")
	else:
		print("Fallo masivo. Error número: ", error)
