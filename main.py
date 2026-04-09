import sys
import os


def _app_dir():
    """Return the directory containing bundled app resources.

    - Development: directory of this script.
    - PyInstaller one-folder: directory of the executable (qml/ sits next to it).
    - PyInstaller one-file: sys._MEIPASS temp extraction dir (qml/ is there).
    """
    if getattr(sys, "frozen", False):
        return getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl

from backend import TimeTrackerBackend


def main():
    # Needed on some platforms so Qt can find its own plugins when frozen.
    if getattr(sys, "frozen", False):
        os.environ.setdefault(
            "QT_PLUGIN_PATH",
            os.path.join(_app_dir(), "PySide6", "Qt6", "plugins"),
        )

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Time Tracker")
    app.setWindowIcon(QIcon(os.path.join(_app_dir(), "time_img.ico")))

    engine = QQmlApplicationEngine()

    backend = TimeTrackerBackend()
    engine.rootContext().setContextProperty("backend", backend)
    app.aboutToQuit.connect(backend.saveAndStop)

    qml_dir = os.path.join(_app_dir(), "qml")
    # Clear any stale QML cache that may exist from a previous build.
    engine.clearComponentCache()
    engine.addImportPath(qml_dir)
    engine.load(QUrl.fromLocalFile(os.path.join(qml_dir, "Main.qml")))

    if not engine.rootObjects():
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
