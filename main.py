import sys
import os


def _app_dir():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from backend import TimeTrackerBackend


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Time Tracker")

    engine = QQmlApplicationEngine()

    backend = TimeTrackerBackend()
    engine.rootContext().setContextProperty("backend", backend)
    app.aboutToQuit.connect(backend.saveAndStop)

    qml_dir = os.path.join(_app_dir(), "qml")
    engine.addImportPath(qml_dir)
    engine.load(os.path.join(qml_dir, "Main.qml"))

    if not engine.rootObjects():
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
