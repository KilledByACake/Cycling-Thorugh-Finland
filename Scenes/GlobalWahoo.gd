extends Node

# Variables globales donde guardaremos los datos
var power: int = 0
var speed: float = 0.0

# Herramientas para la conexión
var udp := PacketPeerUDP.new()
var puerto_escucha = 4242

func _ready():
	print("--- Iniciando GlobalTraining ---")
	
	# 1. Arrancar el .bat
	#var ruta_bat = ProjectSettings.globalize_path("res://arrancar.bat")
	#var ruta_segura = "file:///" + ruta_bat
	#var error_bat = OS.shell_open(ruta_segura)
	
	if error_bat == OK:
		print("✅ Archivo .bat ejecutado correctamente.")
	else:
		print("❌ Error al ejecutar el .bat: ", error_bat)
	
	# 2. Abrir el puerto UDP
	var error_udp = udp.bind(puerto_escucha)
	if error_udp == OK:
		print("✅ Escuchando datos en el puerto UDP: ", puerto_escucha)
	else:
		print("❌ Error al abrir el puerto UDP: ", error_udp)

func _process(_delta):
	# 3. Leer los datos si llegan
	while udp.get_available_packet_count() > 0:
		var paquete = udp.get_packet().get_string_from_utf8()
		var datos = JSON.parse_string(paquete)
		
		# Si los datos son válidos, los guardamos y los imprimimos
		if datos:
			power = datos.get("power", 0)
			speed = datos.get("speed", 0.0)
			
			# ¡AQUÍ ESTÁ LA MAGIA PARA COMPROBARLO!
			print("🚴 Datos en vivo -> Potencia: ", power, " W | Velocidad: ", speed, " km/h")
