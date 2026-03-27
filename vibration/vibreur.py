import time
import board
import busio
import adafruit_drv2605
from gpiozero import DigitalOutputDevice

# 1. On "réveille" la carte en activant la broche EN
enable_pin = DigitalOutputDevice(17)
enable_pin.on() 
time.sleep(0.1) # Attente de l'initialisation

# 2. Configuration de la communication
i2c = busio.I2C(board.SCL, board.SDA)
drv = adafruit_drv2605.DRV2605(i2c)

print("Vibreur prêt !")

def tester_vibrations():
    # Le DRV2605 a une bibliothèque d'effets (1 à 123)
    # Effet 1 : Clic fort / Effet 14 : Alerte / Effet 52 : Buzz long
    effets = [1, 14, 52]
    
    for e in effets:
        print(f"Lancement de l'effet n°{e}")
        drv.sequence[0] = adafruit_drv2605.Effect(e)
        drv.play()
        time.sleep(2) # Pause entre les tests

try:
    tester_vibrations()
    # Au lieu d'utiliser une séquence pré-enregistrée, on utilise le mode direct
    drv.real_time_data = 127  # Intensité maximale (0 à 127)
    drv.mode = adafruit_drv2605.MODE_REALTIME # Active le mode temps réel

    # Pour faire vibrer pendant 1 seconde à pleine puissance
    import time
    drv.play() # Commence à vibrer
    time.sleep(1.0)
    drv.real_time_data = 0 # Arrête la vibration
except KeyboardInterrupt:
    print("Arrêt du programme")
finally:
    enable_pin.off() # On éteint la carte