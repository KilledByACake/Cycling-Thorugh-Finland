extends Node

# Signals to notify other nodes about data updates
signal power_updated(watts: int)
signal speed_updated(kmh: float)

var udp := PacketPeerUDP.new()
var puerto_escucha = 4242

# --- CLASS VARIABLES ---
# These must exist here so other scripts can access them via GestorWahoo.speed
var speed: float = 0.0
var power: int = 0
# -----------------------

func _ready():
	# IMPORTANT: You must bind the port to start receiving UDP packets
	var status = udp.bind(puerto_escucha)
	
	if status == OK:
		print("UDP Server listening on port: ", puerto_escucha)
	else:
		print("Failed to bind UDP port! Error code: ", status)

	## 1. Get the absolute path of the batch file
	#var ruta_bat = ProjectSettings.globalize_path("res://arrancar.bat")
	#
	## 2. Format the path with the "file:///" prefix for Windows compatibility
	#var ruta_segura = "file:///" + ruta_bat
	#
	#print("Attempting to open safely: ", ruta_segura)
	
	## 3. Execute the file
	#var error = OS.shell_open(ruta_segura)
	#
	#if error == OK:
		#print("Windows accepted the shell command!")
	#else:
		#print("Execution failed. Error number: ", error)
		
		
func _process(_delta):
	# Check if there are any incoming packets from Python
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(packet)
		
		if data:
			# Extract values from the JSON sent by the Python script
			# We update the class variables first
			power = data.get("power", 0)
			speed = data.get("speed", 0.0)
			
			# Emit signals so the Player or UI can react to the changes
			power_updated.emit(power)
			speed_updated.emit(speed)
