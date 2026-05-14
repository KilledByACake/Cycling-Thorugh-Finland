extends Node

signal data_updated(power: int, speed: float)

@export var listen_port: int = 4242

var power: int = 0
var speed: float = 0.0
var udp: PacketPeerUDP = PacketPeerUDP.new()

# Binds the UDP socket and enables processing.
func _ready() -> void:
	set_process(true)
	var err: int = udp.bind(listen_port, "127.0.0.1")
	if err != OK:
		push_error("UDP bind failed: %s" % err)
	else:
		print("Listening on UDP port:", listen_port)

# Reads incoming UDP packets and updates power/speed.
func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var pkt: PackedByteArray = udp.get_packet()
		var txt: String = pkt.get_string_from_utf8()
		var data: Variant = JSON.parse_string(txt)
		if typeof(data) == TYPE_DICTIONARY:
			var d: Dictionary = data
			power = int(d.get("power", power))
			speed = float(d.get("speed", speed))
			emit_signal("data_updated", power, speed)
