import os
import json
from PyQt6.QtCore import QObject, pyqtSlot, pyqtProperty, pyqtSignal


class ConfigBackend(QObject):
    """
    Lightweight configuration manager for persistent settings.
    - Loads [KEY]:value pairs from CONFIG.txt
    - Exposes config as a QML-accessible dict (QVariantMap)
    - Automatically writes updates to disk when changed
    - Ensures same key structure when updating from frontend
    """

    configChanged = pyqtSignal(dict)  # emitted when any change occurs

    def __init__(self, config_path=None):
        super().__init__()
        # Folder containing ConfigBackend.py
        here = os.path.dirname(os.path.abspath(__file__))

        if config_path is None:
            raise ValueError("ConfigBackend requires a config_path argument.")

        # Normalize to an absolute path
        self.config_path = os.path.abspath(config_path)
        self.config_data = {}
        print(f"[ConfigBackend] Using config at: {self.config_path}")
        self._load_config()

    # ----------------------------------------------------------------------
    # FILE I/O
    # ----------------------------------------------------------------------

    def _load_config(self):
        """Reads key-value pairs from the .txt file into memory."""
        if not os.path.exists(self.config_path):
            print(f"[ConfigBackend] Config file not found, creating default at {self.config_path}")
            self._write_default_config()
            return

        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or not line.startswith("["):
                        continue
                    try:
                        key = line.split("]:")[0].strip("[]")
                        value = line.split("]:", 1)[1].strip()
                        self.config_data[key] = value
                    except Exception as e:
                        print(f"[ConfigBackend] Parse error on line '{line}': {e}")
        except Exception as e:
            print(f"[ConfigBackend] Error loading config: {e}")

        print(f"[ConfigBackend] Loaded config: {self.config_data}")

    def _write_config(self):
        """Writes current config to disk."""
        try:
            os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
            with open(self.config_path, "w", encoding="utf-8") as f:
                for key, value in self.config_data.items():
                    f.write(f"[{key}]:{value}\n")
            print(f"[ConfigBackend] Saved config to {self.config_path}")
        except Exception as e:
            print(f"[ConfigBackend] Error writing config: {e}")

    def _write_default_config(self):
        """Creates a default configuration file if missing."""
        self.config_data = {
            "CAR_CONN": "OBD",
            "MUSIC_FLDR": "C:/Users/james/Music",
            "SPEED_DESIGN": "Circular",
            "RPM_DESIGN": "Circular",
            "FUEL_DESIGN": "Circular",
        }
        self._write_config()

    # ----------------------------------------------------------------------
    # PUBLIC / QML INTERFACE
    # ----------------------------------------------------------------------

    @pyqtSlot(str, result=str)
    def get(self, key):
        """Retrieve value for a given key."""
        return self.config_data.get(key, "")

    @pyqtSlot(str, str)
    def set(self, key, value):
        """Set a new value for a key and save file."""
        if key in self.config_data:
            old_val = self.config_data[key]
            self.config_data[key] = value
            print(f"[ConfigBackend] Updated '{key}' from '{old_val}' to '{value}'")
            self._write_config()
            self.configChanged.emit(self.config_data)
        else:
            print(f"[ConfigBackend] Ignored set() for unknown key '{key}'")

    @pyqtSlot(result=str)
    def to_json(self):
        """Return config as a formatted JSON string."""
        return json.dumps(self.config_data, indent=4)

    @pyqtSlot(str)
    def from_json(self, json_string):
        """
        Replace config from JSON string (e.g., frontend update).
        Only applies changes if keys match the current config.
        """
        try:
            data = json.loads(json_string)
            if not isinstance(data, dict):
                print("[ConfigBackend] JSON is not a valid object — ignoring")
                return

            # validate same keys
            if set(data.keys()) != set(self.config_data.keys()):
                print("[ConfigBackend] Key mismatch — refusing to overwrite config")
                return

            # apply and save
            self.config_data = data
            self._write_config()
            self.configChanged.emit(self.config_data)
            print(f"[ConfigBackend] Config updated from frontend: {data}")

        except Exception as e:
            print(f"[ConfigBackend] Failed to load from JSON: {e}")

    @pyqtProperty("QVariantMap", notify=configChanged)
    def config(self):
        """Expose config dictionary to QML."""
        return self.config_data

# ---------------------------
# config_backend = ConfigBackend()
# print("📁 Config file absolute path:", os.path.abspath(config_backend.config_path))
# print(config_backend.get("CAR_CONN"))
# config_backend.set("RPM_DESIGN", "Circular")
# print(config_backend.to_json())

