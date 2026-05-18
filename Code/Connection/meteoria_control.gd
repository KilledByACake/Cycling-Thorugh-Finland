extends Control

signal solar2_changed(value: float)

var MQTT_SCRIPT = load("res://mqtt.gd")
var mqtt_client
var solar_power_value: float = 0.0

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
	if topic == "open/meteoria/energy/systemJson":
		var json_data = JSON.parse_string(message)
		if json_data != null and json_data.has("Solar2"):
			var total_w: float = float(json_data["Solar2"].get("Power", 0.0))
			var per_panel: float = total_w / 12.0
			solar_power_value = per_panel
			emit_signal("solar2_changed", solar_power_value)
			lbl_solar.text = "Solar Power: " + "%.8f" % per_panel + " W"

	elif topic == "open/meteoria/windSpeed":
		var v: float = float(message)
		var area: float = 1.0
		var p_eolica: float = 0.5 * 1.225 * area * pow(v, 3)
		lbl_wind.text = "wind power " + "%.4f" % p_eolica + " W"
