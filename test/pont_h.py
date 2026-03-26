import RPi.GPIO as GPIO
import time

# Définition des pins (numérotation BCM)
INA = 27
INB = 22
PWM_PIN = 13
EN = 23

# Setup
GPIO.setmode(GPIO.BCM)
GPIO.setup(INA, GPIO.OUT)
GPIO.setup(INB, GPIO.OUT)
GPIO.setup(PWM_PIN, GPIO.OUT)
GPIO.setup(EN, GPIO.OUT)

# Activation du driver
GPIO.output(EN, GPIO.HIGH)

# PWM (fréquence 1000 Hz)
pwm = GPIO.PWM(PWM_PIN, 1000)
pwm.start(0)

try:
    while True:

        # 🔄 Sens 1
        GPIO.output(INA, GPIO.HIGH)
        GPIO.output(INB, GPIO.LOW)
        pwm.ChangeDutyCycle(60)  # équivalent ~150/255
        time.sleep(2.8)

        # ⛔ Stop
        pwm.ChangeDutyCycle(0)
        time.sleep(1)

        # 🔁 Sens inverse
        GPIO.output(INA, GPIO.LOW)
        GPIO.output(INB, GPIO.HIGH)
        pwm.ChangeDutyCycle(60)
        time.sleep(2.8)

        # ⛔ Stop
        pwm.ChangeDutyCycle(0)
        time.sleep(1)

except KeyboardInterrupt:
    pass

finally:
    pwm.stop()
    GPIO.cleanup()