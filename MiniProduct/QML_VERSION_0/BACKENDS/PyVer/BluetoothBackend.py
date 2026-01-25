# BluetoothBackend.py
import sys
import asyncio
import threading
from typing import List, Dict, Optional
from PyQt6.QtCore import QObject, pyqtSlot, pyqtProperty, pyqtSignal, QTimer

# --- Windows-only helpers (wrapped in try/except so file also imports on Linux) ---
_win = sys.platform.startswith("win")
if _win:
    try:
        # Windows Runtime projections
        from winsdk.windows.devices.enumeration import (
            DeviceInformation, DeviceClass, DeviceInformationKind, DeviceWatcherStatus
        )
        from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as GSMTCManager
        from winsdk.windows.foundation import TypedEventHandler
    except Exception as e:
        _win = False
        print("[BluetoothBackend] winsdk import failed:", e)

# Media key emulation (works on Windows; harmless no-op elsewhere)
def _send_media_key(vk_code: int):
    if not _win:
        return
    import ctypes
    user32 = ctypes.WinDLL('user32', use_last_error=True)

    KEYEVENTF_EXTENDEDKEY = 0x0001
    KEYEVENTF_KEYUP       = 0x0002

    # MapVirtualKey is not required; keybd_event is enough for media keys
    user32.keybd_event(vk_code, 0, KEYEVENTF_EXTENDEDKEY, 0)
    user32.keybd_event(vk_code, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0)

VK_MEDIA_NEXT_TRACK      = 0xB0
VK_MEDIA_PREV_TRACK      = 0xB1
VK_MEDIA_PLAY_PAUSE      = 0xB3
VK_MEDIA_STOP            = 0xB2

class BluetoothBackend(QObject):
    # --- pyqtSignals the QML can bind to ---
    devicesUpdated = pyqtSignal(list)             # list of dicts: [{name, id, kind, paired, address?}, ...]
    connectedChanged = pyqtSignal(bool, dict)     # (isConnected, deviceInfo)
    error = pyqtSignal(str)

    # Remote music control / metadata
    remoteMusicActivated = pyqtSignal(bool)       # tell the UI/MusicCore to switch to remote mode
    trackInfo = pyqtSignal(dict)                  # {"title":..., "artist":..., "album":...}
    playbackStateChanged = pyqtSignal(str)        # "playing" | "paused" | "stopped" | "unknown"

    # (Future Linux) telephony
    callStateChanged = pyqtSignal(str)            # "idle" | "dialing" | "ringing" | "active" | "ended"

    def __init__(self):
        super().__init__()
        self._devices: List[Dict] = []
        self._connected: bool = False
        self._current_device: Optional[Dict] = None

        # Run a small asyncio loop in a thread for Windows RT calls
        self._loop = None
        self._loop_thread = None
        if _win:
            self._ensure_loop()

        # Poll GSMTC metadata periodically (simple + robust)
        self._gstmc_timer = QTimer(self)
        self._gstmc_timer.setInterval(1000)  # 1s
        self._gstmc_timer.timeout.connect(self._poll_gsmtc)
        if _win:
            self._gstmc_timer.start()

    # ------------- Async loop management (Windows) -------------
    def _ensure_loop(self):
        if self._loop is None:
            self._loop = asyncio.new_event_loop()
            self._loop_thread = threading.Thread(target=self._loop.run_forever, daemon=True)
            self._loop_thread.start()

    def _call_soon_threadsafe(self, coro):
        if not _win or self._loop is None:
            return
        asyncio.run_coroutine_threadsafe(coro, self._loop)

    # ------------- Public properties -------------
    @pyqtProperty("QVariantList", notify=devicesUpdated)
    def devices(self):
        return self._devices

    @pyqtProperty(bool, notify=connectedChanged)
    def connected(self):
        return self._connected

    # ------------- Device discovery -------------
    @pyqtSlot()
    def scan(self):
        """Discover Bluetooth devices (Classic + BLE on Windows)."""
        if not _win:
            # Minimal stub for non-Windows dev
            self._devices = []
            self.devicesUpdated.emit(self._devices)
            self.error.emit("Bluetooth scanning is only implemented on Windows in this build.")
            return

        async def _scan_async():
            try:
                # Use DeviceInformation to enumerate Bluetooth devices
                # Audio endpoints and phones are most relevant for our use case
                kinds = [
                    DeviceClass.AUDIO_VIDEO,
                    DeviceClass.PHONE,
                    DeviceClass.AUDIO_RENDER,  # endpoints
                    DeviceClass.UNCATEGORIZED
                ]
                found = []
                for klass in kinds:
                    coll = await DeviceInformation.find_all_async_device_class(klass)
                    for di in coll:
                        # di.properties may contain "System.Devices.Aep.DeviceAddress" on some builds,
                        # but it’s not guaranteed. We'll keep a generic structure.
                        info = {
                            "name": di.name,
                            "id": di.id,
                            "kind": str(di.kind),
                            "paired": getattr(di, "pairing", None).is_paired if getattr(di, "pairing", None) else None
                        }
                        # Avoid dupes by id
                        if not any(x["id"] == info["id"] for x in found):
                            found.append(info)

                self._devices = found
                self.devicesUpdated.emit(self._devices)
            except Exception as e:
                self.error.emit(f"Scan failed: {e}")

        self._call_soon_threadsafe(_scan_async())

    # ------------- Connection management -------------
    @pyqtSlot(str)
    def connectTo(self, device_id: str):
        """
        On Windows, pairing/connecting is handled by the OS.
        Here we "select" the device for our session & try to ensure it’s the active playback target.
        """
        if not _win:
            self.error.emit("Connect only implemented on Windows in this build.")
            return

        # Find device in cache
        dev = next((d for d in self._devices if d["id"] == device_id), None)
        if not dev:
            self.error.emit("Device id not in discovered list.")
            return

        # Mark as "connected" for our session (OS pairing is external)
        self._current_device = dev
        self._connected = True
        self.connectedChanged.emit(True, dev)

        # Activate remote music mode in UI
        self.remoteMusicActivated.emit(True)

    @pyqtSlot()
    def disconnect(self):
        self._current_device = None
        if self._connected:
            self._connected = False
            self.connectedChanged.emit(False, {})
        self.remoteMusicActivated.emit(False)

    # ------------- Media controls (Windows → AVRCP via media keys) -------------
    @pyqtSlot()
    def playPause(self):
        _send_media_key(VK_MEDIA_PLAY_PAUSE)

    @pyqtSlot()
    def next(self):
        _send_media_key(VK_MEDIA_NEXT_TRACK)

    @pyqtSlot()
    def previous(self):
        _send_media_key(VK_MEDIA_PREV_TRACK)

    @pyqtSlot()
    def stop(self):
        _send_media_key(VK_MEDIA_STOP)

    # ------------- Track info via GSMTC (Windows) -------------
    def _poll_gsmtc(self):
        if not _win:
            return
        try:
            mgr = GSMTCManager.request_async().get()
            session = mgr.get_current_session()
            if not session:
                self.playbackStateChanged.emit("unknown")
                return

            info = session.try_get_media_properties_async().get()
            # info contains title, artist, album_artist, album_title, etc.
            title = info.title or ""
            artist = ", ".join(info.artist.split(";")) if info.artist else ""
            album = info.album_title or ""

            self.trackInfo.emit({"title": title, "artist": artist, "album": album})

            # State
            state = session.get_playback_info().playback_status
            state_str = {
                0: "closed",
                1: "opened",
                2: "changing",
                3: "stopped",
                4: "playing",
                5: "paused"
            }.get(int(state), "unknown")

            if state_str == "playing":
                self.playbackStateChanged.emit("playing")
            elif state_str == "paused":
                self.playbackStateChanged.emit("paused")
            elif state_str == "stopped":
                self.playbackStateChanged.emit("stopped")
            else:
                self.playbackStateChanged.emit("unknown")

        except Exception as e:
            # Don’t spam; just report once in a while if needed
            pass

    # ------------- Remote music mode toggle (for QML) -------------
    @pyqtSlot(bool)
    def setRemoteMusicMode(self, enabled: bool):
        self.remoteMusicActivated.emit(enabled)

    # ------------- Telephony stubs (to be implemented on Linux with BlueZ/oFono) -------------
    @pyqtSlot(str)
    def dial(self, number: str):
        self.error.emit("Dial not supported on Windows backend. Implemented on Linux via oFono.")

    @pyqtSlot()
    def hangup(self):
        self.error.emit("Hangup not supported on Windows backend. Implemented on Linux via oFono.")
