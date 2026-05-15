extends Control

var MQTT_SCRIPT = load("res://mqtt.gd")
var mqtt_client

@onready var lbl_solar = $powerSolar
@onready var lbl_wind = $powerWind

func _ready():
	mqtt_client = MQTT_SCRIPT.new()
	add_child(mqtt_client)
	
	mqtt_client.broker_connected.connect(_al_conectar)
	mqtt_client.received_message.connect(_al_recibir_mensaje)
	
	mqtt_client.connect_to_broker("iot.novia.fi")

func _al_conectar():
	mqtt_client.subscribe("open/meteoria/#")

func _al_recibir_mensaje(topic, message):
	# 1. LÓGICA PARA EL LABEL SOLAR (Desde el JSON)
	if topic == "open/meteoria/energy/systemJson":
		var json_data = JSON.parse_string(message)
		if json_data != null and json_data.has("Solar2"):
			var total_w = float(json_data["Solar2"].get("Power", 0.0))
			var por_panel = total_w / 12.0
			
			#lbl_solar.text = "SOLAR TOTAL: " + str(total_w) + " W\n"
			#change here if you not want the text 
			lbl_solar.text = "Solar Power: " + "%.8f" % por_panel + " W"

	# 2. LÓGICA PARA EL LABEL WIND (Desde el Topic directo + Fórmula)
	elif topic == "open/meteoria/windSpeed":
		var v = float(message)
		var area = 1.0
		# P = 0.5 * 1.225 (Rho) * 1.0 (Area) * v^3
		#var p_eolica = 0.5 * 1.225 * area * pow(v, 3)
		var p_eolica = 0.5 * 1.225 * area * pow(v, 3)
		#lbl_wind.text = "VELOCIDAD: " + str(v) + " m/s\n"
		lbl_wind.text = "wind power " + "%.4f" % p_eolica + " W"
