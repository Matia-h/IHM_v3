import sys
from PySide6.QtCore import QObject, Slot, Property, Signal, QTimer, QTime
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from enum import Enum
import RPi.GPIO as GPIO
import time

class AppState(Enum):
    LOCKED    = "locked"
    UNLOCKED  = "unlocked"
    DIFF_MODE = "diff_mode"


class Backend(QObject):
    # ── Signaux propriété batterie ────────────────────────────────────────────
    batteryLevelChanged = Signal()

    # ── Signaux vers le QML ───────────────────────────────────────────────────
    pinFailed       = Signal()
    unlocked        = Signal()
    locked          = Signal()
    diffModeChanged = Signal(bool)
    showBattery     = Signal()
    chargeStarted   = Signal()
    chargeStopped   = Signal()

    # ── Signaux mode différé ──────────────────────────────────────────────────
    timeChanged     = Signal()
    editChanged     = Signal()   # cursorPos / editHour / editMinute / editBattery

    def __init__(self):
        super().__init__()
        self._batteryLevel  = 0.25
        self.state          = AppState.LOCKED
        self.pin_buffer     = []
        self.trappe_open    = False
        self._charge_timer  = None
        self._charging      = False
        self._charge_active = False
        self.PIN_CODE       = ["e1", "e3", "e2", "e4"]

        # GPIO.setmode(GPIO.BCM)
        self.INA = 27
        self.INB = 22
        self.PWM_PIN = 13
        self.EN = 23

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.INA, GPIO.OUT)
        GPIO.setup(self.INB, GPIO.OUT)
        GPIO.setup(self.PWM_PIN, GPIO.OUT)
        GPIO.setup(self.EN, GPIO.OUT)
        self.pwm = GPIO.PWM(self.PWM_PIN, 1000)



        # Horloge
        self._time = QTime.currentTime()
        self._clock_timer = QTimer()
        self._clock_timer.timeout.connect(self._update_clock)
        self._clock_timer.start(1000)

        # Valeurs éditées en mode différé
        self._editHour    = self._time.hour()
        self._editMinute  = self._time.minute()
        self._editBattery = int(self._batteryLevel * 100)
        self._cursorPos   = 0   # 0=Hd 1=Hu 2=Md 3=Mu 4=Bd 5=Bu

        QTimer.singleShot(0, self._emit_initial_values)

    def _emit_initial_values(self):
        self.batteryLevelChanged.emit()
        self.timeChanged.emit()
        self.editChanged.emit()

    def open_trappe(self, vitesse=60, duree=2.8):
        self.pwm.stop()
        GPIO.output(self.INA, GPIO.HIGH)
        GPIO.output(self.INB, GPIO.LOW)
        self.pwm.ChangeDutyCycle(vitesse)
        time.sleep(duree)
        self.pwm.stop()
    def close_trappe(self, vitesse=60, duree=2.8):
        self.pwm.stop()
        GPIO.output(self.INA, GPIO.LOW)
        GPIO.output(self.INB, GPIO.HIGH)
        self.pwm.ChangeDutyCycle(vitesse)
        time.sleep(duree)
        self.pwm.stop()
    # ── Horloge ──────────────────────────────────────────────────────────────
    def _update_clock(self):
        # Mise à jour uniquement hors mode différé (heure figée en mode program)
        if self.state != AppState.DIFF_MODE:
            self._time = QTime.currentTime()
            self.timeChanged.emit()

    def getTime(self):
        if self.state == AppState.DIFF_MODE:
            return f"{self._editHour:02d}:{self._editMinute:02d}"
        return self._time.toString("HH:mm")

    time = Property(str, getTime, notify=timeChanged)



    # ── Propriétés éditées exposées au QML ───────────────────────────────────
    def getEditHour(self):    return self._editHour
    def getEditMinute(self):  return self._editMinute
    def getEditBattery(self): return self._editBattery
    def getCursorPos(self):   return self._cursorPos

    editHour    = Property(int, getEditHour,    notify=editChanged)
    editMinute  = Property(int, getEditMinute,  notify=editChanged)
    editBattery = Property(int, getEditBattery, notify=editChanged)
    cursorPos   = Property(int, getCursorPos,   notify=editChanged)

    # ── Propriété batteryLevel ────────────────────────────────────────────────
    def getBatteryLevel(self):
        return self._batteryLevel

    def setBatteryLevel(self, value):
        value = max(0.0, min(1.0, float(value)))
        if self._batteryLevel != value:
            self._batteryLevel = value
            self.batteryLevelChanged.emit()

    batteryLevel = Property(float, getBatteryLevel, setBatteryLevel, notify=batteryLevelChanged)

    def getBatteryPercent(self):
        return int(self._batteryLevel * 100)

    batteryPercent = Property(int, getBatteryPercent, notify=batteryLevelChanged)

    # ── Slot principal ────────────────────────────────────────────────────────
    @Slot(object)
    def handleUserAction(self, payload):
        payload     = payload.toVariant()
        action_type = payload.get("type")

        if self.state == AppState.LOCKED:
            self._handle_locked(action_type, payload)
        elif self.state == AppState.UNLOCKED:
            self._handle_unlocked(action_type, payload)
        elif self.state == AppState.DIFF_MODE:
            self._handle_diff_mode(action_type, payload)

    # ── État VERROUILLÉ ───────────────────────────────────────────────────────
    def _handle_locked(self, action_type, payload):
        if action_type != "click":
            return
        segment = payload["segment"]
        self.pin_buffer.append(segment)
        if len(self.pin_buffer) < len(self.PIN_CODE):
            return
        if self.pin_buffer == self.PIN_CODE:
            print("🔓 DÉVERROUILLÉ")
            self.state = AppState.UNLOCKED
            self.unlocked.emit()
        else:
            print(f"❌ PIN ERRONÉ — reçu: {self.pin_buffer}")
            self.pinFailed.emit()
        self.pin_buffer.clear()

    # ── État DÉVERROUILLÉ ─────────────────────────────────────────────────────
    def _handle_unlocked(self, action_type, payload):
        if action_type == "click":
            seg = payload["segment"]
            if seg == "e1":
                print("🔒 VERROUILLAGE")
                self._stop_charge()
                self.state = AppState.LOCKED
                self.locked.emit()
            elif seg == "e2":
                # Entrée mode différé — figer heure et batterie
                self._editHour    = self._time.hour()
                self._editMinute  = self._time.minute()
                self._editBattery = int(self._batteryLevel * 100)
                self._cursorPos   = 0
                print("⏱ MODE DIFFÉRÉ ACTIVÉ")
                self.state = AppState.DIFF_MODE
                self.diffModeChanged.emit(True)
                self.editChanged.emit()
                self.timeChanged.emit()
            elif seg == "e3":
                if self.trappe_open : 
                    self.open_trappe()
                    self.trappe_open = not self.trappe_open
                    print("🚪 Trappe:", "OUVERTE" if self.trappe_open else "FERMÉE")
                else : 
                    self.close_trappe()
                    self.trappe_open = not self.trappe_open
                    print("🚪 Trappe:", "OUVERTE" if self.trappe_open else "FERMÉE")
            elif seg in ("e4", "e5"):
                print(f"Segment {seg} cliqué (déverrouillé)")
        elif action_type == "drag":
            self._handle_drag(payload["segments"])
        elif action_type == "long_press":
            if payload.get("segment") == "e5":
                self._stop_charge()
        elif action_type == "double_click_outer":
            print("👁 Affichage batterie :", round(self._batteryLevel * 100), "%")
            self.showBattery.emit()

    # ── État MODE DIFFÉRÉ ─────────────────────────────────────────────────────
    def _handle_diff_mode(self, action_type, payload):
        if action_type == "click":
            seg = payload["segment"]
            if seg == "e3":      # B3 — avance curseur
                self._cursorPos = (self._cursorPos + 1) % 6
                print(f"Curseur → pos {self._cursorPos}")
                self.editChanged.emit()
            elif seg == "e4":    # B4 — recule curseur
                self._cursorPos = (self._cursorPos - 1) % 6
                print(f"Curseur ← pos {self._cursorPos}")
                self.editChanged.emit()
            elif seg == "e1":    # B1 — décrémente chiffre courant
                self._adjust_cursor(-1)
            elif seg == "e2":    # B2 — incrémente chiffre courant
                self._adjust_cursor(+1)
            elif seg == "e5":    # V — valider et programmer la charge
                print(f"✅ VALIDATION : charge à {self._editBattery}% à {self._editHour:02d}:{self._editMinute:02d}")
                self._schedule_charge()
                self.state = AppState.UNLOCKED
                self.diffModeChanged.emit(False)
                self.timeChanged.emit()
        elif action_type == "drag":
            self._handle_drag(payload["segments"])
        elif action_type == "long_press":
            if payload.get("segment") == "e5":
                self._stop_charge()
        elif action_type == "double_click_outer":
            self.showBattery.emit()

    # ── Navigation curseur + édition chiffres ────────────────────────────────
    def _adjust_cursor(self, delta):
        """Modifie le chiffre à la position curseur avec contraintes."""
        p = self._cursorPos

        if p == 0:   # dizaine heures (0–2)
            diz  = (self._editHour // 10 + delta) % 3
            unit = self._editHour % 10
            if diz == 2 and unit > 3:
                unit = 3
            self._editHour = diz * 10 + unit

        elif p == 1: # unité heures
            diz      = self._editHour // 10
            max_unit = 3 if diz == 2 else 9
            unit     = (self._editHour % 10 + delta) % (max_unit + 1)
            self._editHour = diz * 10 + unit

        elif p == 2: # dizaine minutes (0–5)
            diz  = (self._editMinute // 10 + delta) % 6
            unit = self._editMinute % 10
            self._editMinute = diz * 10 + unit

        elif p == 3: # unité minutes (0–9)
            diz  = self._editMinute // 10
            unit = (self._editMinute % 10 + delta) % 10
            self._editMinute = diz * 10 + unit

        elif p == 4: # dizaine batterie (0–10 pour atteindre 100%)
            diz  = self._editBattery // 10
            unit = self._editBattery % 10
            diz  = (diz + delta) % 11   # 0 à 10
            if diz == 10:
                unit = 0               # 100% → unité forcée à 0
            self._editBattery = min(100, diz * 10 + unit)

        elif p == 5: # unité batterie (0–9, bloquée si dizaine=10)
            diz = self._editBattery // 10
            if diz < 10:
                unit = (self._editBattery % 10 + delta) % 10
                self._editBattery = diz * 10 + unit

        print(f"  edit → {self._editHour:02d}:{self._editMinute:02d}  bat={self._editBattery}%")
        self.editChanged.emit()
        self.timeChanged.emit()

    # ── Programmation de la charge différée ──────────────────────────────────
    def _schedule_charge(self):
        now    = QTime.currentTime()
        target = QTime(self._editHour, self._editMinute)
        wait_ms = now.msecsTo(target)
        if wait_ms <= 0:
            wait_ms += 24 * 3600 * 1000
        target_pct = self._editBattery
        print(f"⏰ Charge programmée dans {wait_ms/1000:.0f}s → objectif {target_pct}%")
        QTimer.singleShot(wait_ms, lambda: self._start_charge_to(target_pct))

    def _start_charge_to(self, target_pct):
        print(f"🔌 Démarrage charge → {target_pct}%")
        self._stop_charge()
        self._charge_active = True
        self.chargeStarted.emit()

        def update():
            current = int(self._batteryLevel * 100)
            if current < target_pct:
                self.setBatteryLevel(self._batteryLevel + 0.01)
            else:
                self._stop_charge()
                print(f"✅ Objectif {target_pct}% atteint")

        self._charge_timer = QTimer()
        self._charge_timer.timeout.connect(update)
        self._charge_timer.start(500)

    # ── Gestion drag (charge/décharge immédiate) ──────────────────────────────
    def _handle_drag(self, segments):
        charge_seq    = ["e5", "e1", "e2", "e3", "e4"]
        discharge_seq = ["e4", "e3", "e2", "e1", "e5"]
        if segments == charge_seq:
            if not self._charge_active:
                print(f"⚡ CHARGE démarrée depuis {round(self._batteryLevel*100)}%")
                self._start_charge(charging=True)
        elif segments == discharge_seq:
            if not self._charge_active:
                print(f"🔋 DÉCHARGE démarrée depuis {round(self._batteryLevel*100)}%")
                self._start_charge(charging=False)
        else:
            print("Glissement non reconnu:", segments)

    # ── Charge / décharge continue ────────────────────────────────────────────
    def _start_charge(self, charging: bool):
        self._stop_charge()
        self._charging      = charging
        self._charge_active = True
        self.chargeStarted.emit()

        def update():
            if charging:
                if self._batteryLevel >= 1.0:
                    self.setBatteryLevel(1.0)
                    self._stop_charge()
                    print("✅ Batterie PLEINE")
                    return
                self.setBatteryLevel(self._batteryLevel + 0.002)
            else:
                if self._batteryLevel <= 0.0:
                    self.setBatteryLevel(0.0)
                    self._stop_charge()
                    print("⚠️  Batterie VIDE")
                    return
                self.setBatteryLevel(self._batteryLevel - 0.002)

        self._charge_timer = QTimer()
        self._charge_timer.timeout.connect(update)
        self._charge_timer.start(100)

    def _stop_charge(self):
        if self._charge_timer is not None:
            self._charge_timer.stop()
            self._charge_timer = None
        if self._charge_active:
            self._charge_active = False
            print(f"⏹ Arrêt charge/décharge à {round(self._batteryLevel*100)}%")
            self.chargeStopped.emit()


# ── POINT D'ENTRÉE ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    app    = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    engine.load("test.qml")

    if not engine.rootObjects():
        sys.exit(-1)

    root = engine.rootObjects()[0]
    root.userAction.connect(backend.handleUserAction)

    sys.exit(app.exec())