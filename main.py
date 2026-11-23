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


from PySide6.QtGui import QGuiApplication, QIcon, QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtCore import QUrl, QMetaObject

from backend import TimeTrackerBackend


_instance_mutex = None  # kept referenced for the life of the process
_MUTEX_NAME = "Local\\TimeTracker.SingleInstance"
_SHOW_EVENT_NAME = "Local\\TimeTracker.ShowWindow"
_ACK_EVENT_NAME = "Local\\TimeTracker.ShowWindowAck"


def _already_running():
    """True if another Time Tracker is already running (Windows named mutex).

    The app now lives in the system tray, so a second launch would otherwise
    create a second tray icon and two backends racing to write the same data
    file. Returns False on non-Windows platforms."""
    global _instance_mutex
    if sys.platform != "win32":
        return False
    import ctypes
    ERROR_ALREADY_EXISTS = 183
    kernel32 = ctypes.windll.kernel32
    kernel32.CreateMutexW.restype = ctypes.c_void_p
    _instance_mutex = kernel32.CreateMutexW(None, False, _MUTEX_NAME)
    return kernel32.GetLastError() == ERROR_ALREADY_EXISTS


def _signal_running_instance():
    """Ask the already-running instance to show its window (second launch).

    Returns True if it acknowledged within a few seconds. False means another
    copy holds the single-instance lock but isn't responding (stuck, or an
    older build without the listener) — the caller tells the user rather than
    exiting silently, which otherwise looks like "nothing happens"."""
    if sys.platform != "win32":
        return True
    import ctypes
    EVENT_MODIFY_STATE = 0x0002
    WAIT_OBJECT_0 = 0
    kernel32 = ctypes.windll.kernel32
    kernel32.OpenEventW.restype = ctypes.c_void_p
    kernel32.CreateEventW.restype = ctypes.c_void_p
    # Create the ack event first so the reply can't be missed.
    ack = kernel32.CreateEventW(None, False, False, _ACK_EVENT_NAME)
    handle = kernel32.OpenEventW(EVENT_MODIFY_STATE, False, _SHOW_EVENT_NAME)
    acknowledged = False
    if handle:
        kernel32.SetEvent(ctypes.c_void_p(handle))
        kernel32.CloseHandle(ctypes.c_void_p(handle))
        if ack:
            acknowledged = kernel32.WaitForSingleObject(ctypes.c_void_p(ack), 3000) == WAIT_OBJECT_0
    if ack:
        kernel32.CloseHandle(ctypes.c_void_p(ack))
    return acknowledged


def _warn_unresponsive_instance():
    msg = ("Time Tracker is already running but isn't responding.\n\n"
           "Open Task Manager, end the Time Tracker / python process running "
           "main.py, then start Time Tracker again.")
    print(msg, file=sys.stderr)
    if sys.platform == "win32":
        import ctypes
        MB_ICONWARNING = 0x30
        ctypes.windll.user32.MessageBoxW(None, msg, "Time Tracker", MB_ICONWARNING)


class _ShowRequestListener:
    """First instance: owns a named auto-reset event and polls it, so a
    second launch (which just sets the event and exits) brings this
    instance's window to the front instead of silently doing nothing.
    Polling with a zero timeout every 250 ms is negligible cost and keeps
    everything on the GUI thread."""

    def __init__(self, on_request):
        self._handle = None
        if sys.platform != "win32":
            return
        import ctypes
        from PySide6.QtCore import QTimer
        self._k32 = ctypes.windll.kernel32
        self._k32.CreateEventW.restype = ctypes.c_void_p
        # auto-reset (bManualReset=False), initially non-signaled
        self._handle = self._k32.CreateEventW(None, False, False, _SHOW_EVENT_NAME)
        if not self._handle:
            return
        self._on_request = on_request
        self._timer = QTimer()
        self._timer.setInterval(250)
        self._timer.timeout.connect(self._poll)
        self._timer.start()

    def _poll(self):
        import ctypes
        WAIT_OBJECT_0 = 0
        if self._k32.WaitForSingleObject(ctypes.c_void_p(self._handle), 0) == WAIT_OBJECT_0:
            self._on_request()
            # Tell the second launch we handled it (see _signal_running_instance).
            self._k32.OpenEventW.restype = ctypes.c_void_p
            ack = self._k32.OpenEventW(0x0002, False, _ACK_EVENT_NAME)  # EVENT_MODIFY_STATE
            if ack:
                self._k32.SetEvent(ctypes.c_void_p(ack))
                self._k32.CloseHandle(ctypes.c_void_p(ack))


def main():
    if _already_running():
        if not _signal_running_instance():
            _warn_unresponsive_instance()
        sys.exit(0)

    # Needed on some platforms so Qt can find its own plugins when frozen.
    if getattr(sys, "frozen", False):
        os.environ.setdefault(
            "QT_PLUGIN_PATH",
            os.path.join(_app_dir(), "PySide6", "Qt6", "plugins"),
        )

    # The native platform style (the default on Windows) doesn't allow
    # customizing a Control's background/contentItem/indicator, which the
    # QML views rely on for the app's flat look — Basic is a non-native
    # style that supports it. Must be set before the QML engine loads.
    QQuickStyle.setStyle("Basic")

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Time Tracker")
    # Tray app: hiding/closing windows (main window, check-in, activity
    # prompt) must never quit — Quit is only reachable from the tray menu.
    app.setQuitOnLastWindowClosed(False)
    font = QFont("Segoe UI Variable Text")
    font.setFamilies(["Segoe UI Variable Text", "Segoe UI", "Arial"])
    font.setPixelSize(14)
    app.setFont(font)
    app.setWindowIcon(QIcon(os.path.join(_app_dir(), "time_img.ico")))

    engine = QQmlApplicationEngine()
    # Qt.exit() from QML (tray → Quit) must end the event loop.
    engine.exit.connect(app.exit)

    backend = TimeTrackerBackend()
    engine.rootContext().setContextProperty("backend", backend)
    app.aboutToQuit.connect(backend.saveAndStop)

    # Ctrl+C in the terminal (or an IDE "stop") would otherwise surface as a
    # KeyboardInterrupt inside the next Qt slot (the 1s _tick), which Qt just
    # prints and swallows — leaving a hidden tray app still running. Quit
    # cleanly instead so aboutToQuit → saveAndStop flushes the active session.
    # (Python only runs this handler between bytecodes; the backend's 1s tick
    # guarantees that happens promptly.)
    import signal
    # exit(), not quit(): quit() is cancelled while the main window is open
    # (its onClosing always refuses so ✕ hides to tray). aboutToQuit still fires.
    signal.signal(signal.SIGINT, lambda *_: app.exit(0))

    qml_dir = os.path.join(_app_dir(), "qml")
    # Clear any stale QML cache that may exist from a previous build.
    engine.clearComponentCache()
    engine.addImportPath(qml_dir)
    engine.load(QUrl.fromLocalFile(os.path.join(qml_dir, "Main.qml")))

    if not engine.rootObjects():
        sys.exit(1)

    root = engine.rootObjects()[0]
    # Second launch → show this instance's window (Main.qml's showWindow()).
    # (PySide's type stubs say `member` is bytes, but at runtime it requires str.)
    _listener = _ShowRequestListener(  # noqa: F841 — must stay referenced for the app's lifetime
        lambda: QMetaObject.invokeMethod(root, "showWindow")  # type: ignore[arg-type]
    )

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
