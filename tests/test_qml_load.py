"""Load the full QML UI offscreen and fail on any QML error/warning.

Catches binding errors, missing properties, bad imports and typos in every
view, since all views are instantiated eagerly by Main.qml's StackLayout.
"""
import os

from PySide6.QtCore import QUrl, qInstallMessageHandler, QtMsgType
from PySide6.QtQml import QQmlApplicationEngine

import backend as backend_mod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(qapp, b):
    messages = []

    def handler(mode, ctx, msg):
        if mode != QtMsgType.QtDebugMsg:
            messages.append(msg)

    old = qInstallMessageHandler(handler)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", b)
    engine.addImportPath(os.path.join(ROOT, "qml"))
    engine.load(QUrl.fromLocalFile(os.path.join(ROOT, "qml", "Main.qml")))
    for _ in range(5):
        qapp.processEvents()
    return engine, messages, old


def _relevant(messages):
    # Platform-plugin noise from the offscreen QPA isn't an app bug.
    return [m for m in messages if "qml" in m.lower() or "TypeError" in m or "ReferenceError" in m]


def test_main_qml_loads_without_warnings(qapp, be):
    be.addProject("Alpha", "A-1", True)
    be.addTask("Write report", "Alpha", "", 30)
    engine, messages, old = _load(qapp, be)
    try:
        assert engine.rootObjects(), "Main.qml failed to load"
        assert _relevant(messages) == [], "\n".join(messages)
    finally:
        qInstallMessageHandler(old)
        engine.deleteLater()


def test_ui_survives_start_stop_and_prompts(qapp, be):
    be.addProject("Alpha", "", True)
    engine, messages, old = _load(qapp, be)
    try:
        root = engine.rootObjects()[0]
        for view in ["timer", "tasks", "history", "reports", "settings"]:
            root.setProperty("currentView", view)
            qapp.processEvents()
        be.startProject("Alpha")
        qapp.processEvents()
        be.showCheckIn.emit()
        qapp.processEvents()
        be.stopTimer()
        qapp.processEvents()
        if hasattr(be, "showActivityPrompt"):
            be.showActivityPrompt.emit()
            qapp.processEvents()
        be.openEodDialog()
        qapp.processEvents()
        assert _relevant(messages) == [], "\n".join(messages)
    finally:
        qInstallMessageHandler(old)
        engine.deleteLater()


def _window(root, name):
    from PySide6.QtGui import QWindow
    return root.findChild(QWindow, name)


def test_popups_appear_while_main_window_hidden_in_tray(qapp, be):
    """Regression: popups declared inside Main's window became transient
    children and silently refused to show while the app sat in the tray."""
    be.addProject("Alpha", "", True)
    be._data["lastAppOpenDate"] = None
    engine, messages, old = _load(qapp, be)
    try:
        root = engine.rootObjects()[0]
        root.hide()
        qapp.processEvents()
        be._tick()  # activity with no timer → prompt
        qapp.processEvents()
        prompt = _window(root, "activityPrompt")
        assert prompt is not None and prompt.isVisible()

        be.startProject("Alpha")  # starting anything closes the prompt
        qapp.processEvents()
        assert not prompt.isVisible()

        be.showCheckIn.emit()
        qapp.processEvents()
        checkin = _window(root, "checkInWindow")
        assert checkin is not None and checkin.isVisible()
        be.checkInNo()
        qapp.processEvents()
        assert not checkin.isVisible()
        assert _relevant(messages) == [], "\n".join(messages)
    finally:
        qInstallMessageHandler(old)
        engine.deleteLater()


def test_main_window_has_no_taskbar_button(qapp, be):
    from PySide6.QtCore import Qt
    engine, messages, old = _load(qapp, be)
    try:
        root = engine.rootObjects()[0]
        assert root.flags() & Qt.WindowType.Tool  # Tool windows get no taskbar entry on Windows
    finally:
        qInstallMessageHandler(old)
        engine.deleteLater()


def test_tray_quit_uses_exit_not_quit():
    """Regression: QGuiApplication.quit() asks every window to close first and
    is cancelled if one refuses. Main.qml's onClosing always refuses (✕ hides
    to tray), so Qt.quit() made tray → Quit a no-op while the window was open."""
    src = open(os.path.join(ROOT, "qml", "Main.qml"), encoding="utf-8").read()
    code = "\n".join(l.split("//")[0] for l in src.splitlines())
    assert "Qt.quit()" not in code
    assert "Qt.exit(0)" in code
    main_src = open(os.path.join(ROOT, "main.py"), encoding="utf-8").read()
    assert "engine.exit.connect(app.exit)" in main_src
    assert "app.quit()" not in main_src


def test_tray_icon_source_resolves_to_real_file(qapp, be):
    """Regression: a bare relative icon.source ("../time_img.ico") isn't
    resolved by Qt.labs.platform, the icon is empty, and Windows never adds the
    tray icon — the app runs hidden with no way to open it."""
    from PySide6.QtCore import QUrl
    from PySide6.QtQml import QQmlEngine, QQmlExpression
    engine, messages, old = _load(qapp, be)
    try:
        root = engine.rootObjects()[0]
        expr = QQmlExpression(QQmlEngine.contextForObject(root), root, "String(trayIcon.icon.source)")
        src, _err = expr.evaluate()
        url = QUrl(src)
        assert url.isLocalFile(), f"tray icon source is not an absolute file URL: {src!r}"
        assert os.path.isfile(url.toLocalFile()), url.toLocalFile()
    finally:
        qInstallMessageHandler(old)
        engine.deleteLater()
