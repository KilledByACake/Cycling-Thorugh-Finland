import time
import json
import socket
import logging
import threading
from openant.easy.node import Node
from openant.devices import ANTPLUS_NETWORK_KEY
from openant.devices.fitness_equipment import FitnessEquipment

# Suppress annoying timeout logs
logging.getLogger("openant").setLevel(logging.CRITICAL)

ID_RODILLO = 51551

# Global variables for telemetry
vatios_actuales = 0
velocidad_actual = 0.0
ant_device = None

# --- NETWORK CONFIGURATION (THE UDP BRIDGE) ---
sock_enviar = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
DIRECCION_GODOT = ("127.0.0.1", 4242)
sock_recibir = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock_recibir.bind(("127.0.0.1", 4243))
sock_recibir.setblocking(False)

# --- ANTENNA TASK (EXACTLY AS IN YOUR TKINTER VERSION) ---
def tarea_antena():
    global vatios_actuales, velocidad_actual, ant_device

    def on_data_received(page, page_name, data):
        global vatios_actuales, velocidad_actual
        if hasattr(data, 'instantaneous_power') and data.instantaneous_power is not None:
            vatios_actuales = data.instantaneous_power
        if hasattr(data, 'speed') and data.speed is not None:
            velocidad_actual = round(data.speed * 3.6, 1)

    node = None
    try:
        print("Starting ANT+ node in background...")
        node = Node()
        node.set_network_key(0x00, ANTPLUS_NETWORK_KEY)

        print(f"Searching for Wahoo trainer with ID {ID_RODILLO}...")
        device = FitnessEquipment(node, device_id=ID_RODILLO)
        device.on_device_data = on_data_received

        ant_device = device

        print("ANT+ connection established! Ready to listen to the trainer.")
        node.start()  # This blocks this thread, just like it did with Tkinter

    except Exception as e:
        print(f"Fatal error in antenna: {e}")
    finally:
        if node:
            node.stop()

# --- FUNCTION TO SEND RESISTANCE ---
def enviar_resistencia_ant(percentage):
    if ant_device is None:
        print("Error: Trainer not connected yet.")
        return

    print(f"Godot requests resistance: {percentage}%")
    res_val = int((percentage / 100.0) * 200)  # TODO: check if this covers the full resistance range
    payload = [0x30, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, res_val]

    try:
        if hasattr(ant_device, 'send_acknowledged_data'):
            ant_device.send_acknowledged_data(payload)
        elif hasattr(ant_device, 'channel'):
            ant_device.channel.send_acknowledged_data(payload)
        print("Command sent to Wahoo!")
    except Exception as e:
        print(f"Error sending ANT+ command: {e}")

# --- MAIN LOOP (REPLACES TKINTER'S ROOT.MAINLOOP) ---
def iniciar_puente():
    # 1. Start the ANT+ thread (same as in your original code)
    threading.Thread(target=tarea_antena, daemon=True).start()

    print("Starting UDP network bridge...")

    # 2. Stay in this loop only to handle Godot
    try:
        while True:
            # Send data to Godot
            data = {"power": vatios_actuales, "speed": velocidad_actual}
            sock_enviar.sendto(json.dumps(data).encode('utf-8'), DIRECCION_GODOT)

            # Read commands from Godot
            try:
                packet, _ = sock_recibir.recvfrom(1024)
                command = json.loads(packet.decode('utf-8'))
                if "resistencia" in command:
                    enviar_resistencia_ant(command["resistencia"])
            except BlockingIOError:
                pass  # No new commands
            except Exception as e:
                print(f"Error reading network: {e}")

            time.sleep(0.1)  # Network pause (10 times per second)

    except KeyboardInterrupt:
        print("\nClosing bridge...")

if __name__ == "__main__":
    iniciar_puente()