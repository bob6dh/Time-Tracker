import sys
import os

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

    qml_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "qml")
    engine.addImportPath(qml_dir)
    engine.load(os.path.join(qml_dir, "Main.qml"))

    if not engine.rootObjects():
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
