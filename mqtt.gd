extends Node

@export var client_id = ""
var socket : StreamPeerTCP = null
var brokerconnectmode = 0 
var receivedbuffer : PackedByteArray = PackedByteArray()
var pingticksnext0 = 0
var user = "reader"
var password = "reader"

signal received_message(topic, message)
signal broker_connected()

func _ready():
	if client_id == "":
		client_id = "Godot_User_" + str(randi() % 1000)

func connect_to_broker(host):
	socket = StreamPeerTCP.new()
	var err = socket.connect_to_host(host, 1883)
	if err == OK:
		brokerconnectmode = 1
		return true
	return false

func _process(_delta):
	if socket == null: return
	socket.poll()
	var status = socket.get_status()
	
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if brokerconnectmode == 1:
			_send_connect_packet()
			brokerconnectmode = 2
		
		var available = socket.get_available_bytes()
		if available > 0:
			# DEBUG: This will show in the console if ANY data is received
			print("Receiving ", available, " bytes from server...")
			var data = socket.get_data(available)
			receivedbuffer.append_array(data[1])
			_parse_buffer()
			
		if Time.get_ticks_msec() > pingticksnext0:
			_send_ping()
			pingticksnext0 = Time.get_ticks_msec() + 30000

func _send_connect_packet():
	var pkt = PackedByteArray([0x10])
	var id_b = client_id.to_ascii_buffer()
	var u_b = user.to_ascii_buffer()
	var p_b = password.to_ascii_buffer()
	var rem_len = 10 + (2 + id_b.size()) + (2 + u_b.size()) + (2 + p_b.size())
	pkt.append(rem_len)
	pkt.append_array(PackedByteArray([0, 4]))
	pkt.append_array("MQTT".to_ascii_buffer())
	pkt.append(4) 
	pkt.append(0xC2) 
	pkt.append_array(PackedByteArray([0, 60]))
	_append_str_to_pkt(pkt, id_b)
	_append_str_to_pkt(pkt, u_b)
	_append_str_to_pkt(pkt, p_b)
	socket.put_data(pkt)

func _append_str_to_pkt(pkt, bytes):
	pkt.append(bytes.size() >> 8)
	pkt.append(bytes.size() & 0xFF)
	pkt.append_array(bytes)

func _send_ping(): socket.put_data(PackedByteArray([0xc0, 0x00]))

func subscribe(topic):
	var t_b = topic.to_ascii_buffer()
	var pkt = PackedByteArray([0x82])
	var rem_len = 2 + 2 + t_b.size() + 1
	pkt.append(rem_len)
	pkt.append_array(PackedByteArray([0, 1])) 
	_append_str_to_pkt(pkt, t_b)
	pkt.append(0) 
	socket.put_data(pkt)

func _parse_buffer():
	while receivedbuffer.size() >= 2:
		var type = receivedbuffer[0]
		
		# --- Variable Length Header Reader (MQTT Standard) ---
		var multiplier = 1
		var length = 0
		var pos = 1
		while true:
			if pos >= receivedbuffer.size(): return # Wait for more data
			var digit = receivedbuffer[pos]
			length += (digit & 127) * multiplier
			multiplier *= 128
			pos += 1
			if (digit & 128) == 0: break
		# ----------------------------------------------------
		
		if receivedbuffer.size() < pos + length: return # Incomplete packet
		
		var payload = receivedbuffer.slice(pos, pos + length)
		
		if type == 0x20: # CONNACK
			broker_connected.emit()
		elif type & 0xf0 == 0x30: # PUBLISH
			var t_len = (payload[0] << 8) + payload[1]
			var topic = payload.slice(2, 2 + t_len).get_string_from_ascii()
			var message = payload.slice(2 + t_len).get_string_from_ascii()
			received_message.emit(topic, message)
		
		receivedbuffer = receivedbuffer.slice(pos + length)
