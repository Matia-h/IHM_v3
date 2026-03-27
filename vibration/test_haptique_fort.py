import time
import board
import busio
import adafruit_drv2605
from gpiozero import DigitalOutputDevice

# 1. Forcer l'activation
en = DigitalOutputDevice(17)
en.on()
time.sleep(0.2)

# 2. Connexion I2C
i2c = busio.I2C(board.SCL, board.SDA)
drv = adafruit_drv2605.DRV2605(i2c)

# 3. Mode de test : Effet pré-programmé n°14 (Buzz très fort)
print("Tentative de vibration forte...")
drv.sequence[0] = adafruit_drv2605.Effect(14)
drv.play()
time.sleep(1)
print("Fin du test.")