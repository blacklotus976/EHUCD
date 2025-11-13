import obd
import threading

class OBDConnection:
    def __init__(self, port_str=None, baudrate=None, fast=False):
        """
        Initialize OBD-II connection and start async data streaming.
        """
        self.connection = obd.OBD(port_str, baudrate=baudrate, fast=fast)
        self.data = {}
        self.lock = threading.Lock()

        # Supported PID cache
        self.supported_cmds = set(self.connection.supported_commands)

        # Start async streaming
        self._start_streaming()

    def _start_streaming(self):
        """
        Watches every supported OBD command to update self.data live.
        """
        def callback(response):
            if response.is_null():
                return
            with self.lock:
                self.data[response.command.name] = response.value

        for cmd in self.supported_cmds:
            try:
                self.connection.watch(cmd, callback)
            except Exception as e:
                print(f"Cannot watch {cmd}: {e}")

        self.connection.start()

    # --------------------------------------------------------------
    #   LIVE DATA ACCESS
    # --------------------------------------------------------------

    def get_value(self, command_name):
        """Return latest live PID value (or None)."""
        with self.lock:
            return self.data.get(command_name)

    def get_all_live_data(self):
        """Return dict of all currently available live data."""
        with self.lock:
            # Return safe printable values
            output = {}
            for k, v in self.data.items():
                try:
                    output[k] = str(v)
                except:
                    output[k] = None
            return output

    # --------------------------------------------------------------
    #   ERROR CODES (DTCs)
    # --------------------------------------------------------------

    def get_all_codes(self):
        """
        Returns all stored, pending, and permanent trouble codes.
        """

        stored = self.connection.query(obd.commands.GET_DTC)
        pending = self.connection.query(obd.commands.PENDING_DTC)
        permanent = self.connection.query(obd.commands.PERMANENT_DTC)

        def parse(result):
            return result.value if result and not result.is_null() else []

        return {
            "stored": parse(stored),
            "pending": parse(pending),
            "permanent": parse(permanent),
        }

    def clear_all_codes(self):
        """
        Clear all stored / pending DTCs.
        (Permanent DTCs cannot be cleared manually — they clear after successful drive cycles.)
        """

        res = self.connection.query(obd.commands.CLEAR_DTC)
        return not res.is_null()

    # --------------------------------------------------------------
    #   STOP CONNECTION
    # --------------------------------------------------------------

    def stop(self):
        self.connection.stop()
        self.connection.close()
