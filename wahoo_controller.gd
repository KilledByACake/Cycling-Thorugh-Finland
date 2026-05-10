# En wahoo_controller.gd
class_name WahooController
extends Node 

signal power_updated(watts: int)
signal speed_updated(kmh: float)

# --- AÑADE ESTAS DOS LÍNEAS AQUÍ ---
var current_speed: float = 0.0
var current_power: int = 0
# ----------------------------------

var udp_server := UDPServer.new()
var udp_peer : PacketPeerUDP
var udp_client := PacketPeerUDP.new()

func _ready():
	udp_server.listen(4242)
	udp_client.connect_to_host("127.0.0.1", 4243)

func _process(_delta):
	udp_server.poll()
	if udp_server.is_connection_available():
		udp_peer = udp_server.take_connection()
		
	if udp_peer and udp_peer.get_available_packet_count() > 0:
		var paquete = udp_peer.get_packet().get_string_from_utf8()
		procesar_datos_python(paquete)

func procesar_datos_python(json_string: String):
	# --- AÑADE ESTA LÍNEA PARA VER EN LA CONSOLA ---
	print("Datos recibidos: ", json_string)
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var datos = json.data
		if datos.has("power"):
			power_updated.emit(datos["power"])
		if datos.has("speed"):
			speed_updated.emit(datos["speed"])

func set_resistance(percent: int):
	var porcentaje_seguro = clamp(percent, 0, 100)
	var comando = {"resistencia": porcentaje_seguro}
	var json_string = JSON.stringify(comando)
	udp_client.put_packet(json_string.to_utf8_buffer())
