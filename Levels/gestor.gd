extends Node

var pid_proceso = -1 

func _ready():
	var sistema = OS.get_name()
	var ruta_python = ProjectSettings.globalize_path("res://puente.py")
	#change here the route if it do not work in linux 
	
	if sistema == "Linux" or sistema == "macOS":
		# VERSIÓN RASPBERRY PI (Limpia y directa)
		print("Iniciando en Raspberry Pi/Linux...")
		pid_proceso = OS.create_process("python3", [ruta_python])
	else:
		# VERSIÓN WINDOWS (Te avisamos de que lo abras a mano por ahora)
		print("Estás en Windows. Por favor, abre 'arrancar.bat' manualmente para conectar el rodillo.")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if pid_proceso != -1:
			OS.kill(pid_proceso)
