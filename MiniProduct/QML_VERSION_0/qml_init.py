import functools
import os
import sys

import PyQt6
from PyQt6.QtCore import QTimer, QtMsgType, qInstallMessageHandler, QUrl
from PyQt6.QtQml import QQmlApplicationEngine, QQmlComponent
from PyQt6.QtWidgets import QApplication

from MiniProduct.QML_VERSION_0.BACKENDS.PyVer.CongifBackend import ConfigBackend
from MiniProduct.QML_VERSION_0.BACKENDS.PyVer.music_backend import MusicBackend
from MiniProduct.QML_VERSION_0.BACKENDS.PyVer.CarMetrics import CarMetrics


# ---------------------------
# QML CONSOLE LOGGER
# ---------------------------
def qml_logger(msg_type, context, message, log_somewhere_else_func=None):
    """Global handler for QML / Qt debug and error messages."""
    prefix = {
        QtMsgType.QtDebugMsg: "[QML DEBUG]",
        QtMsgType.QtWarningMsg: "[QML WARNING]",
        QtMsgType.QtCriticalMsg: "[QML CRITICAL]",
        QtMsgType.QtFatalMsg: "[QML FATAL]",
        QtMsgType.QtInfoMsg: "[QML INFO]",
    }.get(msg_type, "[QML LOG]")

    mssg = f"{prefix} {message}"
    print(mssg)
    if context.file:
        mssg1 = f"    at {context.file}:{context.line}"
        print(mssg1)
    else:
        mssg1 = ""
    if log_somewhere_else_func is not None:
        try:
            log_somewhere_else_func(f"{mssg}  {mssg1}")
        except Exception as e:
            print(f"[QML LOGGER ERROR] Could not forward log: {e}")


# ---------------------------
# MAIN ENTRY POINT
# ---------------------------
if __name__ == "__main__":
    # ✅ 1. Create the QApplication first (Qt internals ready)
    app = QApplication(sys.argv)

    qml_dir_pyqt = os.path.join(os.path.dirname(PyQt6.__file__), "Qt6", "qml")
    qml_dir_qt = r"C:\Qt\6.9.3\qml"  # <-- adjust this path to your actual Qt version

    # Combine both paths
    os.environ["QML2_IMPORT_PATH"] = os.pathsep.join([qml_dir_pyqt, qml_dir_qt])
    print("✅ QML import paths set:", os.environ["QML2_IMPORT_PATH"])
    print("QML2_IMPORT_PATH =", os.environ["QML2_IMPORT_PATH"])

    engine = QQmlApplicationEngine()


    # ✅ 2. Create CarMetrics backend — it's ready to log
    metrics = CarMetrics()

    # ✅ 3. Install QML logger, safely linked to metrics.log
    qml_logger_with_metrics = functools.partial(qml_logger, log_somewhere_else_func=metrics.log)
    qInstallMessageHandler(qml_logger_with_metrics)

    # ✅ 4. Expose Python backends BEFORE loading QML
    engine.rootContext().setContextProperty("carMetrics", metrics)
    engine.rootContext().setContextProperty("colorOptions", metrics.colors)

    # ✅ Create Config backend (loads or creates CONFIG.txt)
    config_backend = ConfigBackend(config_path='BACKENDS/CONFIG.txt')
    # ✅ Expose it globally to all QML components
    engine.rootContext().setContextProperty("configBackend", config_backend)

    music_backend = MusicBackend(config_backend.get("MUSIC_FLDR"))
    engine.rootContext().setContextProperty("musicBackend", music_backend)


    # ✅ 3. Link: when config changes, update the music folder live
    def on_config_changed(cfg):
        new_music_path = cfg.get("MUSIC_FLDR", "")
        if new_music_path and new_music_path != music_backend.music_root:
            music_backend.musicRoot = new_music_path
            print(f"[Link] Music folder updated dynamically: {new_music_path}")


    config_backend.configChanged.connect(on_config_changed)

    # ✅ 5. Load QML files
    base_path = os.path.dirname(__file__)
    musiccore_path = os.path.join(base_path, "core", "MusicEngine.qml")

    component = QQmlComponent(engine)
    component.loadUrl(QUrl.fromLocalFile(musiccore_path))

    if not component.isReady():
        print("❌ MusicCore load error:")
        for err in component.errors():
            print("   >", err.toString())
        sys.exit(-1)

    # ✅ Create MusicCore and expose it
    music_core = component.create(engine.rootContext())
    music_core.setParent(engine)
    engine.music_core = music_core
    engine.rootContext().setContextProperty("MusicCore", music_core)

    # ✅ Now load the main screen
    engine.load(QUrl.fromLocalFile(os.path.join(base_path, "screen_manager.qml")))

    if not engine.rootObjects():
        print("[ERROR] QML failed to load — exiting with code -1.")
        sys.exit(-1)

    root_obj = engine.rootObjects()[0]
    root_obj.setProperty("carMetrics", metrics)
    root_obj.setProperty("musicBackend", music_backend)

    # ✅ Optional: keep metrics updating or start fallback mode
    # QTimer.singleShot(1000, metrics.start_random_metrics)

    sys.exit(app.exec())
