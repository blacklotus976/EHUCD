import os
import sys
import random
from PyQt6.QtCore import QObject, pyqtSignal, QTimer, QtMsgType, qInstallMessageHandler, pyqtSlot, QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication
from Colours import ALL_AVAILABLE_COLORS, find_colours_by_tag
from music_backend import MusicBackend

# ---------------------------
# QML CONSOLE LOGGER
# ---------------------------
def qml_logger(msg_type, context, message):
    """Global handler for QML / Qt debug and error messages."""
    prefix = {
        QtMsgType.QtDebugMsg: "[QML DEBUG]",
        QtMsgType.QtWarningMsg: "[QML WARNING]",
        QtMsgType.QtCriticalMsg: "[QML CRITICAL]",
        QtMsgType.QtFatalMsg: "[QML FATAL]",
        QtMsgType.QtInfoMsg: "[QML INFO]",
    }.get(msg_type, "[QML LOG]")

    print(f"{prefix} {message}")
    if context.file:
        print(f"    at {context.file}:{context.line}")

# Install QML message handler before engine is created
qInstallMessageHandler(qml_logger)


# ---------------------------
# BACKEND CLASS
# ---------------------------
class CarMetrics(QObject):
    speedChanged = pyqtSignal(int)
    rpmChanged = pyqtSignal(int)
    fuelChanged = pyqtSignal(int)
    throttleChanged = pyqtSignal(int)
    brakesChanged = pyqtSignal(int)
    oilTempChanged = pyqtSignal(int)
    batteryChanged = pyqtSignal(float)
    coolantChanged = pyqtSignal(int)
    fuelLevelChanged = pyqtSignal(int)
    engineLoadChanged = pyqtSignal(int)

    def __init__(self, colours_filename="COLOURS_CONFIG.txt"):
        super().__init__()
        self.starting = True
        self.phase_one_reached = False
        self.speed_range_max = 200
        self.rpm_range_max = 8000
        self.speed_current_start = 0
        self.rpm_current_start = 0
        self.colours_filename = colours_filename

        self.colors = self.get_colours()  # Get the colors once at startup
        engine.rootContext().setContextProperty("colorOptions", self.colors)

    def update_metrics(self):
        if self.starting:
            if not self.phase_one_reached:
                if self.speed_current_start <= self.speed_range_max:
                    self.speedChanged.emit(self.speed_current_start)
                    self.speed_current_start += 20
                else:
                    self.phase_one_reached = True
            else:
                if self.speed_current_start >=0:
                    self.speedChanged.emit(self.speed_current_start)
                    self.speed_current_start -= 20
                else:
                    self.starting = False
            if not self.phase_one_reached:
                if self.rpm_current_start <= self.rpm_range_max:
                    self.rpmChanged.emit(self.rpm_current_start)
                    self.rpm_current_start += 800
                else:
                    self.phase_one_reached = True
            else:
                if self.rpm_current_start >=0:
                    self.rpmChanged.emit(self.rpm_current_start)
                    self.rpm_current_start -= 800
                else:
                    self.starting = False
        else:
            self.speedChanged.emit(random.randint(0, 200))
            self.rpmChanged.emit(random.randint(0, 8000))
        self.fuelChanged.emit(random.randint(0, 100))
        self.throttleChanged.emit(random.randint(0, 100))
        self.brakesChanged.emit(random.randint(0, 100))
        self.oilTempChanged.emit(random.randint(80, 120))
        self.batteryChanged.emit(round(random.uniform(12.0, 14.5), 1))
        self.coolantChanged.emit(random.randint(70, 110))
        self.fuelLevelChanged.emit(random.randint(0, 100))
        self.engineLoadChanged.emit(random.randint(0, 100))



    @pyqtSlot(str, str, str, str, str, str, str, str)  # Adjust according to your needs
    def set_color_settings(self, speedNeedleColor, speedBgColor, speedTickColor,
                           rpmNeedleColor, rpmBgColor, rpmTickColor,
                           barBgColor, metricBoxColor):
        # Store the colors in the backend
        self.speedNeedleColor = speedNeedleColor
        self.speedBgColor = speedBgColor
        self.speedTickColor = speedTickColor
        self.rpmNeedleColor = rpmNeedleColor
        self.rpmBgColor = rpmBgColor
        self.rpmTickColor = rpmTickColor
        self.barBgColor = barBgColor
        self.metricBoxColor = metricBoxColor



    def get_colours(self):
        colors = ALL_AVAILABLE_COLORS
        # Convert to a list of dictionaries for QML
        return [{"name": name, "value": value} for name, value in colors.items()]

    @pyqtSlot(result=list)  # Ensures it’s callable from QML and returns a list
    def get_dynamic_colors(self):
        return self.get_colours()

    @pyqtSlot(result=list)  # Expose this to QML as a callable method
    def read_color_settings(self):
        color_list = []
        try:
            with open(self.colours_filename, 'r') as file:
                color_list = [line.strip() for line in file.readlines() if line.strip()]
        except Exception as e:
            print(f"Error reading file {self.colours_filename}: {e}")
        return color_list



    @pyqtSlot(list)
    def write_color_settings(self, colors):
        if len(colors) != 9:
            print("Error: Expected a list of 9 color strings.")
            return

        try:
            # Open the file in write mode to clear previous contents
            with open(self.colours_filename, 'w') as file:
                # Write each color string to the file
                for color in colors:
                    # Convert QColor to a string in hexadecimal format
                    file.write(f"{find_colours_by_tag(color.name())[0]}\n")

            print(f"Color settings written to {self.colours_filename}")
        except Exception as e:
            print(f"Error writing to file {self.colours_filename}: {e}")

    @pyqtSlot(result=list)
    def read_design_settings(self):
        #speed, rpm, fuel, throttle, brakes
        return ["submarine", "circular", "circular", "bar", "bar"]
            # speed, rpm, fuel, bars default

    @pyqtSlot(list)
    def write_design_settings(self, arr):
        return

# ---------------------------
# MAIN ENTRY POINT
# ---------------------------
if __name__ == "__main__":
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    metrics = CarMetrics()
    music_backend = MusicBackend("C:/Users/james/OneDrive/Υπολογιστής/Music")

    base_path = os.path.dirname(__file__)
    musiccore_path = os.path.join(base_path, "core", "MusicEngine.qml")

    component = QQmlComponent(engine)
    component.loadUrl(QUrl.fromLocalFile(musiccore_path))

    if not component.isReady():
        print("❌ MusicCore load error:")
        for err in component.errors():
            print("   >", err.toString())
        sys.exit(-1)

    music_core = component.create(engine.rootContext())  # ✅ create with a context
    music_core.setParent(engine)  # ✅ give it QML ownership
    engine.music_core = music_core  # ✅ keep Python reference
    engine.rootContext().setContextProperty("MusicCore", music_core)
    engine.rootContext().setContextProperty("carMetrics", metrics)
    engine.rootContext().setContextProperty("musicBackend", music_backend)
    engine.rootContext().setContextProperty("colorOptions", metrics.colors)

    # ✅ Load main UI
    engine.load(QUrl.fromLocalFile(os.path.join(base_path, "screen_manager.qml")))

    if not engine.rootObjects():
        print("[ERROR] QML failed to load — exiting with code -1.")
        sys.exit(-1)

    root_obj = engine.rootObjects()[0]
    root_obj.setProperty("carMetrics", metrics)
    root_obj.setProperty("musicBackend", music_backend)

    # ✅ Keep metrics updating
    timer = QTimer()
    timer.timeout.connect(metrics.update_metrics)
    timer.start(100)

    sys.exit(app.exec())
