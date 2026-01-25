import ctypes
from PyQt6.QtCore import (QObject, pyqtSignal, pyqtProperty as Property, pyqtSlot as Slot, QTimer, QVariant)
from NAS.NasLogin.LoginInteractiveChoices import LOGIN_INTERACTIVE_CHOICES
class LoginManager(QObject):
    loginSuccess = pyqtSignal()
    loginFailed = pyqtSignal(str)
    internetChanged = pyqtSignal()
    def __init__(self):
        super().__init__()
        self.credentials = {"admin": "1234", "user": "password"}
        self.ui_styling = LOGIN_INTERACTIVE_CHOICES
        self._has_internet = False

        # Trigger the check immediately
        # Use a tiny delay (100ms) to ensure QML is loaded and listening to the signal
        QTimer.singleShot(100, self.refreshInternetStatus)
    @Slot(str, str, str)
    def attempt_login(self, username, password, db_ip):
        print(f"[PY] Attempting login for: {username}")
        # 1. Immediate check for internet
        self._check_windows_internet()

        # 2. Add an artificial delay so the UI shows the 'Parsing' state
        # We pass an error reason if internet is missing
        reason = "SQL ERROR FAILURE" if self._has_internet else "Limited Connectivity"

        # Artificial delay to see our smooth progress bar in action
        QTimer.singleShot(2000, lambda: self._process_login(username, password, db_ip, reason))

    @Property(bool, notify=internetChanged)
    def hasInternet(self):
        return self._has_internet



    def refreshInternetStatus(self):
        """Manual trigger for QML 'Reload' button"""
        self._check_windows_internet()

    def _check_windows_internet(self):
        """Uses wininet.dll to check connection state without COM objects"""
        try:
            # Flags to identify the type of connection (LAN, Modem, etc.)
            flags = ctypes.c_ulong()
            # This returns True if there is a configured connection to internet
            is_connected = ctypes.windll.wininet.InternetGetConnectedState(ctypes.byref(flags), 0)

            if is_connected != self._has_internet:
                self._has_internet = bool(is_connected)
                self.internetChanged.emit()
            return bool(is_connected)
        except Exception as e:
            print(f"Native Internet check error: {e}")
            return False
    @Property(QVariant, constant=True)
    def UI_STYLING(self):
        return self.ui_styling
    def _process_login(self, username, password, db_ip, reason):
        if username in self.credentials and self.credentials[username] == password:
            print("[PY] Login Successful")
            self.loginSuccess.emit()
        else:
            print("[PY] Login Failed")
            self.loginFailed.emit(reason)