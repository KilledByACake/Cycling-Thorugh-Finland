extends Control

# Emitted when a new solar power value (per panel, in watts) is available.
signal solar2_changed(value: float)

# Loads the MQTT helper script and will hold the client instance.
var MQTT_SCRIPT = load("res://mqtt.gd")
var mqtt_client
# Latest solar power value per panel (W).
var solar_power_value: float = 0.0

# UI labels for displaying live values.
@onready var lbl_solar = $powerSolar
@onready var lbl_wind = $powerWind

# Initializes MQTT, connects signals, and starts the broker connection.
func _ready():
	mqtt_client = MQTT_SCRIPT.new()
	add_child(mqtt_client)
	mqtt_client.broker_connected.connect(_al_conectar)
	mqtt_client.received_message.connect(_al_recibir_mensaje)
	mqtt_client.connect_to_broker("iot.novia.fi")

# Subscribes to all Meteoria topics once connected.
func _al_conectar():
	mqtt_client.subscribe("open/meteoria/#")

# Handles incoming MQTT messages: parses solar JSON and wind speed.
func _al_recibir_mensaje(topic, message):
	# Solar from JSON: extract Solar2.Power, compute per-panel watts, emit signal, update label.
	if topic == "open/meteoria/energy/systemJson":
		var json_data = JSON.parse_string(message)
		if json_data != null and json_data.has("Solar2"):
			var total_w: float = float(json_data["Solar2"].get("Power", 0.0))
			var per_panel: float = total_w / 12.0
			solar_power_value = per_panel
			emit_signal("solar2_changed", solar_power_value)
			lbl_solar.text = "Solar Power: " + "%.8f" % per_panel + " W"

	# Wind from raw topic: estimate power from wind speed and update label.
	elif topic == "open/meteoria/windSpeed":
		var v: float = float(message)
		var area: float = 1.0
		var p_eolica: float = 0.5 * 1.225 * area * pow(v, 3)
		lbl_wind.text = "wind power " + "%.4f" % p_eolica + " W"
