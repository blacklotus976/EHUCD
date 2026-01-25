import obd
import threading
import time
import pandas as pd
import os

class OBDBackendCore:
    """
    Core backend for handling OBD-II connections and queries.
    Independent of GUI / frameworks.
    Includes middleware logging when enabled.
    """

    def __init__(self, port="COM5", baudrate=38400, fast=False, timeout=1.0, log_file_path=None):
        self.port = port
        self.baudrate = baudrate
        self.fast = fast
        self.timeout = timeout
        self.lock = threading.Lock()

        # --- Logging setup ---
        self.logging_enabled = False
        self._log_buffer = []
        self._log_df = pd.DataFrame()
        self._log_filename = log_file_path if log_file_path is not None else None #TODO: FIX THIS
        self._log_columns = [
            "timestamp", "SPEED", "RPM", "THROTTLE_POS", "ENGINE_LOAD",
            "COOLANT_TEMP", "VOLTAGE", "MAF",
            "STEERING_ANGLE", "GEAR", "BRAKE_PRESSURE", "ACCELERATOR_PEDAL",
            "WHEEL_FL", "WHEEL_FR", "WHEEL_RL", "WHEEL_RR"
        ]

    # ------------------------------------------------------------------
    # CONNECTION
    # ------------------------------------------------------------------
    def _connect(self):
        mssg = [f"[OBD] Connecting to {self.port} ..."]
        try:
            self.connection = obd.OBD(
                portstr=self.port,
                baudrate=self.baudrate,
                fast=self.fast,
                timeout=self.timeout
            )
            mssg.append(f"[OBD] Status: {self.connection.status()}")
            self.obd_elm327_connection = (
                self.connection.status() != obd.OBDStatus.NOT_CONNECTED
            )
        except Exception as e:
            mssg.append(f"[OBD] Failed to connect: {e}")
            self.connection = None
            self.obd_elm327_connection = False
        return mssg

    def is_connected(self):
        return self.connection and self.connection.status() == obd.OBDStatus.CAR_CONNECTED

    def reconnect(self):
        self._connect()

    def close(self):
        if self.connection:
            self.connection.close()

    # ------------------------------------------------------------------
    # LOGGING CONTROL
    # ------------------------------------------------------------------
    def start_logging(self):
        """Enable logging and create CSV file."""
        os.makedirs("logs", exist_ok=True)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        self._log_filename = f"obd_log_{timestamp}.csv"
        self.logging_enabled = True
        self._log_buffer = []
        self._log_df = pd.DataFrame(columns=self._log_columns)
        print(f"[OBD-LOG] Started logging → {self._log_filename}")

    def stop_logging(self):
        """Flush current logs and disable."""
        if not self.logging_enabled:
            return
        self._flush_to_csv()
        self._log_buffer = []
        self.logging_enabled = False
        print("[OBD-LOG] Stopped logging.")

    def _append_log_entry(self, data_dict: dict):
        """Internal — append a single dict entry to the log buffer."""
        if not self.logging_enabled:
            return
        data_dict["timestamp"] = time.time()
        self._log_buffer.append(data_dict)

        # flush to dataframe every 100
        if len(self._log_buffer) >= 100:
            df = pd.DataFrame(self._log_buffer)
            self._log_buffer.clear()
            self._log_df = pd.concat([self._log_df, df], ignore_index=True)

        # flush to CSV every 500
        if len(self._log_df) >= 500:
            self._flush_to_csv()

    def _flush_to_csv(self):
        """Internal — append current DataFrame to CSV and clear."""
        if not self._log_filename:
            return
        self._log_df.to_csv(
            self._log_filename,
            mode="a",
            index=False,
            header=not os.path.exists(self._log_filename)
        )
        self._log_df = pd.DataFrame(columns=self._log_columns)
        print(f"[OBD-LOG] Data flushed → {self._log_filename}")

    # ------------------------------------------------------------------
    # STATUS DETECTION
    # ------------------------------------------------------------------
    def get_status_flags(self):
        if not self.is_connected():
            return {"connected": False, "ignition_on": False, "engine_running": False, "voltage": None, "rpm": None}

        with self.lock:
            voltage = self._safe_query(obd.commands.CONTROL_MODULE_VOLTAGE)
            rpm = self._safe_query(obd.commands.RPM)
            maf = self._safe_query(obd.commands.MAF)
            speed = self._safe_query(obd.commands.SPEED)

        voltage_v = voltage.magnitude if voltage else None
        rpm_v = rpm.magnitude if rpm else 0
        maf_v = maf.magnitude if maf else 0
        speed_v = speed.magnitude if speed else 0

        ignition_on = voltage_v is not None and voltage_v > 9.0
        engine_running = (rpm_v and rpm_v > 200) or (maf_v and maf_v > 0.5) or (speed_v and speed_v > 0.5)

        data = {
            "connected": True,
            "ignition_on": ignition_on,
            "engine_running": engine_running,
            "voltage": voltage_v,
            "rpm": rpm_v
        }

        self._append_log_entry(data)
        return data

    # ------------------------------------------------------------------
    # DATA SNAPSHOTS
    # ------------------------------------------------------------------
    # ------------------------------------------------------------------
    # FUEL CONSUMPTION CALCULATION
    # ------------------------------------------------------------------
    def _calculate_fuel_consumption(self, maf_gps: float, speed_kph: float, afr: float = 14.7, fuel_density: float = 720.0):
        """
        Estimate instantaneous fuel consumption (L/100 km) from MAF and vehicle speed.
        Returns 0.0 if speed or MAF are zero.
        """
        if speed_kph <= 0 or maf_gps <= 0:
            return 0.0

        # Step 1: fuel flow (liters/hour)
        fuel_flow_lph = (maf_gps * 3600) / (afr * fuel_density)

        # Step 2: normalize per distance
        l_per_100km = (fuel_flow_lph * 100) / speed_kph

        return round(l_per_100km, 2)

    def get_fast_data(self):
        if not self.is_connected():
            return {}

        cmds = {
            "RPM": obd.commands.RPM,
            "SPEED": obd.commands.SPEED,
            "THROTTLE_POS": obd.commands.THROTTLE_POS,
            "ENGINE_LOAD": obd.commands.ENGINE_LOAD,
            "MAF": obd.commands.MAF,
            "COOLANT_TEMP": obd.commands.COOLANT_TEMP,
            "VOLTAGE": obd.commands.CONTROL_MODULE_VOLTAGE,
        }

        results = {}
        with self.lock:
            for name, cmd in cmds.items():
                val = self._safe_query(cmd)
                if val is not None:
                    results[name] = val.magnitude

        # Calculate instantaneous fuel consumption if possible
        maf = results.get("MAF", 0.0)
        speed = results.get("SPEED", 0.0)
        results["FUEL_CONSUMPTION"] = self._calculate_fuel_consumption(maf, speed)

        # also append CAN-style simulated data
        results.update({
            "STEERING_ANGLE": 0.0,
            "GEAR": "N",
            "BRAKE_PRESSURE": 0.0,
            "ACCELERATOR_PEDAL": 0.0,
            "WHEEL_FL": 0.0,
            "WHEEL_FR": 0.0,
            "WHEEL_RL": 0.0,
            "WHEEL_RR": 0.0
        })

        self._append_log_entry(results)
        return results

    def get_full_snapshot(self):
        if not self.is_connected():
            return {}

        snapshot = {}
        with self.lock:
            for cmd in self.connection.supported_commands:
                try:
                    r = self.connection.query(cmd, force=True)
                    if not r.is_null() and r.value is not None:
                        snapshot[cmd.name] = str(r.value)
                except Exception as e:
                    snapshot[cmd.name] = f"ERR: {e}"

        self._append_log_entry(snapshot)
        return snapshot

    # ------------------------------------------------------------------
    # DTC MANAGEMENT
    # ------------------------------------------------------------------
    def get_dtc_codes(self):
        if not self.is_connected():
            return {}

        def parse(res):
            if not res or res.is_null():
                return []
            return [f"{c} - {d}" for c, d in res.value]

        with self.lock:
            stored = self.connection.query(obd.commands.GET_DTC)
            pending = self.connection.query(obd.commands.PENDING_DTC)
            permanent = self.connection.query(obd.commands.PERMANENT_DTC)

        result = {
            "stored": parse(stored),
            "pending": parse(pending),
            "permanent": parse(permanent)
        }

        self._append_log_entry({"DTC": result})
        return result

    def clear_dtc_codes(self):
        if not self.is_connected():
            return False
        with self.lock:
            res = self.connection.query(obd.commands.CLEAR_DTC)
        self._append_log_entry({"CLEAR_DTC": True})
        return not res.is_null()

    # ------------------------------------------------------------------
    # INTERNAL HELPERS
    # ------------------------------------------------------------------
    def _safe_query(self, cmd):
        try:
            res = self.connection.query(cmd, force=True)
            if res and not res.is_null() and res.value is not None:
                return res.value
        except Exception:
            pass
        return None
