extends CharacterBody2D

signal pedal_tapped

# --- Tuning Configuration (Original kept) ---
@export_group("Manual Configuration")
@export var power_per_tap: float = 1.0
@export var power_decay: float = 2.5
@export var speed_per_power: float = 2000.0

@export_group("Wahoo Sensor Configuration")
# Multiplicador para ajustar la relación entre Watts y avance en el juego
@export var power_to_speed_multiplier: float = 5.0 
@export var max_speed: float = 2000.0

@export_group("Scoring")
@export var energy_per_tap: int = 5

# --- State Variables ---
var velocidad_sensor: float = 0.0
var potencia_sensor: int = 0
var tap_power: float = 0.0
var speed_x: float = 0.0 # Esta variable ahora la mueve la POTENCIA del GlobalWahoo
var energy_points: int = 0
var input_locked: bool = false
var frozen: bool = false

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _ready() -> void:
	# Mantenemos todos tus grupos originales
	add_to_group("player")
	add_to_group("radler")
	add_to_group("input_receivers")
	add_to_group("freezable")
	velocity = Vector2.ZERO
	_update_energy_ui()

	# --- COMENTADO: Ya no buscamos el nodo localmente porque usamos el Global ---
	# await get_tree().process_frame 
	# var ruta_gestor = "/root/Main/HBoxContainer/Dashboard/Wahoo/GestorWahoo"
	# var gestor = get_node_or_null(ruta_gestor)
	# if gestor:
	# 	gestor.power_updated.connect(_on_power_from_sensor)
	# 	gestor.speed_updated.connect(_on_speed_from_sensor)
	# 	print("Player: Wahoo connection established")

func _physics_process(delta: float) -> void:
	if frozen: return

	# --- SUSTITUCIÓN DEL TAPING POR POTENCIA GLOBAL ---
	# En lugar de usar tap_power (espacio), usamos GlobalWahoo.power
	# Usamos un lerp muy suave para que la potencia no dé tirones al cambiar
	var target_speed = GlobalWahoo.power * power_to_speed_multiplier
	speed_x = lerp(speed_x, target_speed, 2.0 * delta) 
	speed_x = clamp(speed_x, 0.0, max_speed)
	
	# Aplicamos el movimiento a la velocidad física
	velocity.x = speed_x
	#move_and_slide() # Necesario para que el CharacterBody2D se mueva

	# --- Lógica de energía adaptada ---
	if GlobalWahoo.power > 50:
		# Sumamos energía de forma constante mientras haya potencia
		energy_points += 1
		_update_energy_ui()

	# --- COMENTADO: Código anterior de input manual ---
	# if not input_locked and Input.is_action_just_pressed("ui_accept"):
	# 	on_pedal_tap()
	# tap_power = max(0.0, tap_power - power_decay * delta)
	
	_update_animation()

# --- COMENTADO: Ya no usamos estas señales porque leemos directo del GlobalWahoo ---
# func _on_power_from_sensor(watts: int) -> void:
# 	potencia_sensor = watts
# func _on_speed_from_sensor(kmh: float) -> void:
# 	velocidad_sensor = kmh

func on_pedal_tap() -> void:
	if input_locked or frozen: return
	tap_power += power_per_tap
	energy_points += energy_per_tap
	_update_energy_ui()
	emit_signal("pedal_tapped")

func _update_animation() -> void:
	if sprite == null: return
	# Usamos velocity.x (el movimiento real) para la animación
	if abs(velocity.x) > 1.0:
		sprite.play("rollen")
		sprite.speed_scale = clamp(velocity.x / 300.0, 0.2, 8.0)
	else:
		sprite.stop()

func _update_energy_ui() -> void:
	var p: Node = get_parent()
	if p and p.has_method("update_energy_UI"):
		p.call("update_energy_UI", energy_points)

func lock_input(v: bool) -> void:
	input_locked = v

func freeze() -> void:
	frozen = true
	tap_power = 0.0
	speed_x = 0.0
	velocity = Vector2.ZERO
