import sys
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import (QObject, pyqtSignal, pyqtSlot as Slot,
                          QtMsgType, qInstallMessageHandler, QTimer, QCoreApplication, Qt)

import os


from NAS.QML_LOGGER_FOR_PYTHON import qml_logger
from NasLogin.LoginBackend import LoginManager






if __name__ == "__main__":
    #windows config
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"
    # 1. Install the logger BEFORE the app starts
    qInstallMessageHandler(qml_logger)


    #+++++++++++++++++++CONFIG FOR OLDER COMPUTERS:++++++++++++++++++++++++
    #MY CREATURES MAY BE FUN BUT ARE SLOW ON OLDER COMPUTERS, TRY RUNNING WITH THESE FLAGS
    #BUT HONESTLY I JSUT EXPECT YOU TO REMOVE THEM SO NO ISSUE HERE (JUST SET TO 0 the animation mode in login-ui-choices
    #and destroy the setting sbutotn that changes them, so they cna never appear but stay in github as a fun thing
    # os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    # os.environ["QSG_RENDER_LOOP"] = "basic"
    # # Optional: Use "software" for maximum compatibility on very old PCs
    # os.environ["QT_QUICK_BACKEND"] = "software"
    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()

    login_manager = LoginManager()
    # 2. Expose the manager to QML
    engine.rootContext().setContextProperty("loginManager", login_manager)

    #mini test before fll wardrobe integration
    from NAS.NasCreateFurnitures.WardrobeModel import WardrobeManager
    wardrobe_backend = WardrobeManager()
    engine.rootContext().setContextProperty('wardrobeManager', wardrobe_backend)
    engine.load("NasCreateFurnitures/WardrobeEditor.qml")
    # engine.load("NasLogin/login.qml")

    if not engine.rootObjects():
        print("[PY] Error: Could not load QML file.")
        sys.exit(-1)

    sys.exit(app.exec())
    #ITS SUPPOSED TO RETURN CONNECTION AND WORK WELL WITH A SCREEN MANAGER