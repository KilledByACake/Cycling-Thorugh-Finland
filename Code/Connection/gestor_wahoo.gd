extends Node

signal power_updated(watts: int)
signal speed_updated(kmh: float)

var udp := PacketPeerUDP.new()
var puerto_escucha = 4242

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
		
		
func _process(_delta):
	# 3. Revisar si han llegado datos de Python
	while udp.get_available_packet_count() > 0:
		var paquete = udp.get_packet().get_string_from_utf8()
		var datos = JSON.parse_string(paquete)
		
		if datos:
			# Extraemos los datos del JSON que envía tu Python
			var watts = datos.get("power", 0)
			var kmh = datos.get("speed", 0.0)
			
			# ¡ESTO ES LO QUE ACTIVA AL JUGADOR!
			power_updated.emit(watts)
			speed_updated.emit(kmh)
