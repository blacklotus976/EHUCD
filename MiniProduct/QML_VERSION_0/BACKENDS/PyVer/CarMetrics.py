import random
import time
from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot, QTimer, pyqtProperty
from MiniProduct.QML_VERSION_0.Colours import ALL_AVAILABLE_COLORS, find_colours_by_tag
from MiniProduct.QML_VERSION_0.BACKENDS.PyVer.OBD_client import OBDBackendCore


class CarMetrics(QObject):
    # === Signals for QML (engine + vehicle) ===
    speedChanged = pyqtSignal(float)
    rpmChanged = pyqtSignal(float)
    throttleChanged = pyqtSignal(float)
    brakesChanged = pyqtSignal(float)
    fuelChanged = pyqtSignal(float)
    oilTempChanged = pyqtSignal(float)
    batteryChanged = pyqtSignal(float)
    coolantChanged = pyqtSignal(float)
    fuelLevelChanged = pyqtSignal(float)
    engineLoadChanged = pyqtSignal(float)
    fuelConsumptionChanged = pyqtSignal(float)

    # === New signals for CAN-level / chassis metrics ===
    steeringAngleChanged = pyqtSignal(float)      # degrees
    gearChanged = pyqtSignal(str)                 # e.g. "P", "R", "N", "D", "1"
    brakePressureChanged = pyqtSignal(float)      # percentage
    acceleratorPedalChanged = pyqtSignal(float)   # percentage
    wheelFLChanged = pyqtSignal(float)            # Front left wheel speed
    wheelFRChanged = pyqtSignal(float)
    wheelRLChanged = pyqtSignal(float)
    wheelRRChanged = pyqtSignal(float)
    dtcCodesChanged = pyqtSignal(list)            # list of strings ["P0138 - O2 Sensor High Voltage", ...]

    miniLoggerChanged = pyqtSignal(list)
    engineWarningChanged = pyqtSignal(bool)
    generalWarningChanged = pyqtSignal(bool)
    loggingStateChanged = pyqtSignal(bool)

    speedSeriesChanged = pyqtSignal(list)
    fuelSeriesChanged = pyqtSignal(list)



    def log(self, message):
        print(message)
        if isinstance(message, list):
            for line in message:
                timestamp = time.strftime("%H:%M:%S", time.localtime())
                self.mini_logger.append(f"[{timestamp}] {line}")
        else:
            timestamp = time.strftime("%H:%M:%S", time.localtime())
            self.mini_logger.append(f"[{timestamp}] {message}")
        if len(self.mini_logger) > 100:
            self.mini_logger.pop(0)

    def __init__(self, colours_filename="COLOURS_CONFIG.txt", log_file_path=None):
        super().__init__()
        self.mini_logger = []
        self.log("CarMetrics backend initialized.")

        self.colours_filename = colours_filename
        self.colors = self.get_colours()

        # === startup animation ===
        self.starting = True
        self.phase_one_reached = False
        self.speed_range_max = 200
        self.rpm_range_max = 8000
        self.speed_current_start = 0
        self.rpm_current_start = 0
        self.fuel_current_start = 0
        self.fuel_range_max = 100

        # === OBD client ===
        try:
            self._obd_client = OBDBackendCore(port="COM5", log_file_path=log_file_path)
            connect_response = self._obd_client._connect()
            self.log(connect_response)
            self.obd_connected = self._obd_client.obd_elm327_connection
            self.log("[OBD] Connected to OBD-II adapter." if self.obd_connected else "[OBD] OBD-II adapter not connected.")
        except Exception as e:
            self.log(f"[OBD] Connection failed: {e}\nSwitching to random view...")
            self._obd_client = None
            self.obd_connected = False

        # === Timers ===
        self.fast_timer = QTimer()
        self.fast_timer.timeout.connect(self.update_fast_metrics)
        self.fast_timer.start(100)  # ~10 Hz

        self.slow_timer = QTimer()
        self.slow_timer.timeout.connect(self.update_slow_metrics)
        self.slow_timer.start(1000)  # 1 Hz

        self.dtc_timer = QTimer()
        self.dtc_timer.timeout.connect(self.update_dtc_codes)
        self.dtc_timer.start(5000)  # Every 5 seconds (diagnostic check)


        self.logger_timer = QTimer()
        self.logger_timer.timeout.connect(self.emit_logger)
        self.logger_timer.start(3000)  # update every 3 seconds

        self.isLogging = False
        self.engine_warning = False
        self.general_warning = True

        self._speed_tick = 0
        self._fuel_tick = 0
        self._avg_speed = 0.0
        self._avg_fuel = 0.0
        self._avg_speed_series = []
        self._avg_fuel_series = []
        self._current_fuel_consumption = 0.0


    # ----------------------------------------------------------------------
    #                       METRIC UPDATES
    # ----------------------------------------------------------------------

    def update_fast_metrics(self):
        """Called ~10Hz → we use it as base clock."""
        if self.starting:
            self._startup_animation_step()
            return

        # --- fetch or simulate data ---
        if self.obd_connected and self._obd_client and self._obd_client.is_connected():
            fast_data = self._obd_client.get_fast_data()
            speed = float(fast_data.get("SPEED", 0))
            rpm = float(fast_data.get("RPM", 0))
            throttle = float(fast_data.get("THROTTLE_POS", 0))
            engine_load = round(float(fast_data.get("ENGINE_LOAD", 0)), 2)

            fuel = float(fast_data.get("FUEL_LEVEL", random.uniform(20, 90)))
            fuel_consumption = float(fast_data.get("FUEL_CONSUMPTION", 0))
        else:
            # --- fallback: random simulation ---
            speed = random.uniform(0, 180)
            rpm = random.uniform(700, 5000)
            throttle = random.uniform(0, 100)
            engine_load = round(random.uniform(0, 100), 2)
            fuel = random.uniform(20, 90)
            fuel_consumption = random.uniform(3, 12)  # random simulated L/100km

        # --- Emit instant readings to QML ---
        self.speedChanged.emit(speed)
        self.rpmChanged.emit(rpm)
        self.throttleChanged.emit(throttle)
        self.engineLoadChanged.emit(engine_load)
        self.fuelChanged.emit(fuel)
        self._current_fuel_consumption = fuel_consumption
        self.fuelConsumptionChanged.emit(fuel_consumption)

        brakes = random.uniform(0, 100)
        self.brakesChanged.emit(brakes)

        # === accumulate speed ===
        self._speed_tick += 1
        self._avg_speed = (self._avg_speed * (self._speed_tick - 1) + speed) / self._speed_tick

        # === accumulate fuel ===
        self._fuel_tick += 1
        self._avg_fuel = (self._avg_fuel * (self._fuel_tick - 1) + fuel_consumption) / self._fuel_tick


        # --- every 10 ticks, record one average point ---
        if self._speed_tick % 10 == 0:
            self._avg_speed_series.append(self._avg_speed)
            self._speed_tick = 0  # reset tick counter for next local average block

        if self._fuel_tick % 10 == 0:
            self._avg_fuel_series.append(self._avg_fuel)
            self._fuel_tick = 0

        # --- if too many points, downsample ---
        if len(self._avg_speed_series) > 100:
            self._avg_speed_series = self._downsample(self._avg_speed_series)
        if len(self._avg_fuel_series) > 100:
            self._avg_fuel_series = self._downsample(self._avg_fuel_series)

        # --- emit rolling average series for graphs ---
        self.speedSeriesChanged.emit(self._avg_speed_series)
        self.fuelSeriesChanged.emit(self._avg_fuel_series)

    # ----------------------------------------------------------
    # Helper: reduce list by averaging each 10-segment block
    # ----------------------------------------------------------
    def _downsample(self, data, factor=10):
        if len(data) < factor:
            return data
        new_data = []
        block_size = len(data) // factor
        for i in range(0, len(data), block_size):
            block = data[i:i + block_size]
            if block:
                new_data.append(sum(block) / len(block))
        return new_data

    def update_slow_metrics(self):
        """Fuel, temp, voltage — slower updates."""
        if self.starting:
            return  # no need during intro

        if self.obd_connected and self._obd_client and self._obd_client.is_connected():
            try:
                fast_data = self._obd_client.get_fast_data()
                battery = round(float(fast_data.get("VOLTAGE", 12.5)), 1)
                coolant = float(fast_data.get("COOLANT_TEMP", 80))
                fuel_level = random.randint(20, 90)
                oil_temp = coolant + random.randint(-5, 5)
                fuel = random.randint(30, 90)

                self.batteryChanged.emit(battery)
                self.coolantChanged.emit(coolant)
                self.oilTempChanged.emit(oil_temp)
                self.fuelLevelChanged.emit(fuel_level)
                self.fuelChanged.emit(fuel)



            except Exception as e:
                self.log(f"[OBD] Slow update error: {e}")
                self.obd_connected = False
        else:
            self.batteryChanged.emit(round(random.uniform(12.0, 14.5), 1))
            self.coolantChanged.emit(random.randint(70, 110))
            self.oilTempChanged.emit(random.randint(80, 120))
            self.fuelLevelChanged.emit(random.randint(0, 100))
            self.fuelChanged.emit(random.randint(0, 100))

        self.engineWarningChanged.emit(bool(self.engine_warning))
        self.generalWarningChanged.emit(bool(self.general_warning))

    def update_dtc_codes(self):
        """Fetch DTC codes periodically (if available)."""
        if not self._obd_client or not self.obd_connected:
            return

        try:
            dtc_data = self._obd_client.get_dtc_codes()
            codes = []
            for category in ("stored", "pending", "permanent"):
                codes.extend(dtc_data.get(category, []))
            self.dtcCodesChanged.emit(codes)
        except Exception as e:
            self.log(f"[OBD] DTC fetch error: {e}")

    def emit_logger(self):
        """Emit mini_logger contents periodically."""
        if hasattr(self, "mini_logger"):
            self.miniLoggerChanged.emit(self.mini_logger[-50:])  # last 50 lines

    # --- logging control ---
    @pyqtSlot()
    def toggleLogging(self):
        if self._obd_client:
            if self.isLogging:
                self._obd_client.stop_logging()
                self.isLogging = False
            else:
                if not self.obd_connected:
                    self.log("[OBD] Cannot start logging: Not connected to OBD-II adapter. The functions will be called, but no data is stored")
                self._obd_client.start_logging()
                self.isLogging = True
            self.loggingStateChanged.emit(self.isLogging)


    @pyqtProperty(bool, notify=loggingStateChanged)
    def isLogging(self):
        return self._isLogging
    @isLogging.setter
    def isLogging(self, val):
        self._isLogging = val


    # ----------------------------------------------------------------------
    #                   STARTUP REV ANIMATION
    # ----------------------------------------------------------------------
    def _startup_animation_step(self):
        """Coordinated startup rev-up/down animation for speed, RPM, and fuel."""
        step_duration_ms = 100  # same tick rate as fast_timer
        total_time_ms = 1000  # total forward time in ms
        steps = total_time_ms // step_duration_ms

        # compute step increments so all finish together
        step_speed = self.speed_range_max / steps
        step_rpm = self.rpm_range_max / steps
        step_fuel = self.fuel_range_max / steps

        if not self.phase_one_reached:
            # going up
            if (self.speed_current_start < self.speed_range_max or
                    self.rpm_current_start < self.rpm_range_max or
                    self.fuel_current_start < self.fuel_range_max):

                self.speedChanged.emit(self.speed_current_start)
                self.rpmChanged.emit(self.rpm_current_start)
                self.fuelLevelChanged.emit(self.fuel_current_start)

                self.speed_current_start = min(self.speed_current_start + step_speed, self.speed_range_max)
                self.rpm_current_start = min(self.rpm_current_start + step_rpm, self.rpm_range_max)
                self.fuel_current_start = min(self.fuel_current_start + step_fuel, self.fuel_range_max)
            else:
                self.phase_one_reached = True
        else:
            # going down
            if (self.speed_current_start > 0 or
                    self.rpm_current_start > 0 or
                    self.fuel_current_start > 0):

                self.speedChanged.emit(self.speed_current_start)
                self.rpmChanged.emit(self.rpm_current_start)
                self.fuelLevelChanged.emit(self.fuel_current_start)

                self.speed_current_start = max(self.speed_current_start - step_speed, 0)
                self.rpm_current_start = max(self.rpm_current_start - step_rpm, 0)
                self.fuel_current_start = max(self.fuel_current_start - step_fuel, 0)
            else:
                self.starting = False  # done animating

    @pyqtProperty(float, notify=fuelConsumptionChanged)
    def fuelConsumption(self):
        return self._current_fuel_consumption

    # ----------------------------------------------------------------------
    #                    COLOR / DESIGN SETTINGS
    # ----------------------------------------------------------------------
    def get_colours(self):
        return [{"name": name, "value": value} for name, value in ALL_AVAILABLE_COLORS.items()]

    @pyqtSlot(result=list)
    def get_dynamic_colors(self):
        return self.get_colours()

    @pyqtSlot(result=list)
    def read_color_settings(self):
        try:
            with open(self.colours_filename, 'r') as file:
                return [line.strip() for line in file if line.strip()]
        except Exception as e:
            print(f"Error reading color settings: {e}")
            return []

    @pyqtSlot(list)
    def write_color_settings(self, colors):
        try:
            with open(self.colours_filename, 'w') as file:
                for color in colors:
                    file.write(f"{find_colours_by_tag(color.name())[0]}\n")
            print(f"Colors saved to {self.colours_filename}")
        except Exception as e:
            print(f"Error writing colors: {e}")

    @pyqtSlot(result=list)
    def read_design_settings(self):
        return ["submarine", "circular", "circular", "bar", "bar"]

    @pyqtSlot(list)
    def write_design_settings(self, arr):
        pass
