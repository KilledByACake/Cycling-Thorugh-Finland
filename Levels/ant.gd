extends Control

@onready var label_potencia = $LabelPotencia
@onready var label_speed = $LabelSpeed

func _ready():
	# USAMOS EL NOMBRE QUE PUSISTE EN LA IMAGEN
	# Fíjate que ahora empieza por MAYÚSCULA
	WahooController.power_updated.connect(_al_recibir_potencia)
	WahooController.speed_updated.connect(_al_recibir_velocidad)

func _al_recibir_potencia(vatios: int):
	label_potencia.text = "Potencia: " + str(vatios) + " W"

func _al_recibir_velocidad(kmh: float):
	label_speed.text = "Speed: " + str(kmh) + " km/h"
