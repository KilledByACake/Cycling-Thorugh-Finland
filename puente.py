import time
import json
import socket
import logging
import threading
from openant.easy.node import Node
from openant.devices import ANTPLUS_NETWORK_KEY
from openant.devices.fitness_equipment import FitnessEquipment

# Silenciamos los timeout molestos
logging.getLogger("openant").setLevel(logging.CRITICAL)

ID_RODILLO = 51551 

# Variables globales para la telemetría
vatios_actuales = 0
velocidad_actual = 0.0
ant_device = None 

# --- CONFIGURACIÓN DE RED (EL PUENTE UDP) ---
sock_enviar = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
DIRECCION_GODOT = ("127.0.0.1", 4242)

sock_recibir = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock_recibir.bind(("127.0.0.1", 4243))
sock_recibir.setblocking(False)

# --- TAREA ANTENA (EXACTAMENTE COMO EN TU TKINTER) ---
def tarea_antena():
    global vatios_actuales, velocidad_actual, ant_device
    
    def al_recibir_datos(page, page_name, data):
        global vatios_actuales, velocidad_actual
        if hasattr(data, 'instantaneous_power') and data.instantaneous_power is not None:
            vatios_actuales = data.instantaneous_power
        if hasattr(data, 'speed') and data.speed is not None:
            velocidad_actual = round(data.speed * 3.6, 1)
                
    node = None
    try:
        print("Iniciando nodo ANT+ en segundo plano...")
        node = Node()
        node.set_network_key(0x00, ANTPLUS_NETWORK_KEY)
        
        print(f"Buscando rodillo Wahoo con ID {ID_RODILLO}...")
        device = FitnessEquipment(node, device_id=ID_RODILLO)
        device.on_device_data = al_recibir_datos
        
        ant_device = device 
        
        print("¡Conexión ANT+ establecida! Listo para escuchar al rodillo.")
        node.start() # Esto bloquea este hilo, igual que lo hacía con Tkinter
        
    except Exception as e:
        print(f"Error fatal en la antena: {e}")
    finally:
        if node:
            node.stop()

# --- FUNCIÓN PARA ENVIAR RESISTENCIA ---
def enviar_resistencia_ant(porcentaje):
    if ant_device is None:
        print("Error: El rodillo aún no está conectado.")
        return
        
    print(f"Godot solicita resistencia: {porcentaje}%")
    res_val = int((porcentaje / 100.0) * 200)#cambiar esto por q creo que no cubre la resistencia completa
    payload = [0x30, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, res_val]
    
    try:
        if hasattr(ant_device, 'send_acknowledged_data'):
            ant_device.send_acknowledged_data(payload)
        elif hasattr(ant_device, 'channel'):
            ant_device.channel.send_acknowledged_data(payload)
        print("¡Comando inyectado al Wahoo!")
    except Exception as e:
        print(f"Error al enviar el comando ANT+: {e}")

# --- EL BUCLE PRINCIPAL (SUSTITUYE AL ROOT.MAINLOOP DE TKINTER) ---
def iniciar_puente():
    # 1. Arrancamos el hilo del ANT+ (Igual que en tu código original)
    threading.Thread(target=tarea_antena, daemon=True).start()
    
    print("Iniciando traductor de red UDP...")
    
    # 2. Nos quedamos en este bucle solo atendiendo a Godot
    try:
        while True:
            # Enviar datos a Godot
            datos = {"power": vatios_actuales, "speed": velocidad_actual}
            sock_enviar.sendto(json.dumps(datos).encode('utf-8'), DIRECCION_GODOT)
            
            # Leer comandos desde Godot
            try:
                paquete, _ = sock_recibir.recvfrom(1024)
                comando = json.loads(paquete.decode('utf-8'))
                if "resistencia" in comando:
                    enviar_resistencia_ant(comando["resistencia"])
            except BlockingIOError:
                pass # No hay comandos nuevos
            except Exception as e:
                print(f"Error leyendo red: {e}")
                
            time.sleep(0.1) # Pausa de red (10 veces por segundo)
            
    except KeyboardInterrupt:
        print("\nCerrando puente...")

if __name__ == "__main__":
    iniciar_puente()