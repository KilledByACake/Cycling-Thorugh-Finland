extends Node

# Global variables to store incoming data
var power: int = 0
var speed: float = 0.0

# Networking tools for the connection
var udp := PacketPeerUDP.new()
var puerto_escucha = 4242

func _ready():
	print("--- Starting GlobalTraining ---")
	
	# 1 Open the UDP port
	var error_udp = udp.bind(puerto_escucha)
	if error_udp == OK:
		print("Listening for data on UDP port: ", puerto_escucha)
	else:
		print("Error opening UDP port: ", error_udp)

func _process(_delta):
	# 2. Read packets if available
	while udp.get_available_packet_count() > 0:
		var paquete = udp.get_packet().get_string_from_utf8()
		var datos = JSON.parse_string(paquete)
		
		# If the JSON is valid, store and print values
		if datos:
			power = datos.get("power", 0)
			speed = datos.get("speed", 0.0)
			
			# Live data log
			print("Live data -> Power: ", power, " W | Speed: ", speed, " km/h")
