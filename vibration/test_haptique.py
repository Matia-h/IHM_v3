import tkinter as tk
import board
import busio
import adafruit_drv2605
from gpiozero import DigitalOutputDevice
import time

# --- Configuration Matérielle ---
# Activation de la broche EN (GPIO 17 / Pin 11)
enable_pin = DigitalOutputDevice(17)
enable_pin.on()
time.sleep(0.2)

# Initialisation I2C
try:
    i2c = busio.I2C(board.SCL, board.SDA)
    drv = adafruit_drv2605.DRV2605(i2c)
    current_effect = 1 # On commence à l'effet 1
except Exception as e:
    print(f"Erreur : {e}")

# --- Fonctions ---
def jouer_effet():
    """Joue l'effet actuellement sélectionné"""
    global current_effect
    print(f"Lecture de l'effet n°{current_effect}")
    drv.sequence[0] = adafruit_drv2605.Effect(current_effect)
    drv.play()

def effet_suivant():
    """Passe à l'effet suivant (max 123)"""
    global current_effect
    if current_effect < 123:
        current_effect += 1
    else:
        current_effect = 1 # Retour au début
    label_num.config(text=f"Effet actuel : {current_effect}")
    jouer_effet() # Joue automatiquement le nouvel effet

def effet_precedent():
    """Retourne à l'effet précédent"""
    global current_effect
    if current_effect > 1:
        current_effect -= 1
    else:
        current_effect = 123
    label_num.config(text=f"Effet actuel : {current_effect}")
    jouer_effet()

# --- Interface Graphique (Tkinter) ---
root = tk.Tk()
root.title("Testeur Séquentiel Haptique")
root.geometry("400x350")

# Affichage du numéro
label_num = tk.Label(root, text=f"Effet actuel : {current_effect}", font=("Arial", 16, "bold"))
label_num.pack(pady=20)

# Bouton Principal (Jouer)
btn_play = tk.Button(root, text="REJOUER L'EFFET", command=jouer_effet,
                     bg="#4CAF50", fg="white", font=("Arial", 12, "bold"), height=2, width=20)
btn_play.pack(pady=10)

# Boutons de Navigation
frame_nav = tk.Frame(root)
frame_nav.pack(pady=20)

btn_prev = tk.Button(frame_nav, text="<<< Précédent", command=effet_precedent, width=12)
btn_prev.pack(side="left", padx=10)

btn_next = tk.Button(frame_nav, text="Suivant >>>", command=effet_suivant, width=12)
btn_next.pack(side="left", padx=10)

# Note informative
info = tk.Label(root, text="Testez les 123 effets du DRV2605\n(Click, Buzz, Hum, etc.)", font=("Arial", 9, "italic"))
info.pack(pady=10)

try:
    root.mainloop()
finally:
    enable_pin.off() # Sécurité pour éteindre le driver en quittant