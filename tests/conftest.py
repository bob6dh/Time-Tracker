"""Shared test fixtures.

Every test runs against a throwaway data directory: backend's module-level
DATA_FILE/BAK_FILE/BACKUP_DIR are redirected to tmp_path before a backend is
constructed, so the real tracker_data.json next to the app is never touched.
"""
import os
import sys

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQuickControls2 import QQuickStyle  # noqa: E402

import backend as backend_mod  # noqa: E402


@pytest.fixture(scope="session")
def qapp():
    QQuickStyle.setStyle("Basic")  # same as main.py
    app = QGuiApplication.instance() or QGuiApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    return app


@pytest.fixture
def data_dir(tmp_path, monkeypatch):
    monkeypatch.setattr(backend_mod, "DATA_FILE", str(tmp_path / "tracker_data.json"))
    monkeypatch.setattr(backend_mod, "BAK_FILE", str(tmp_path / "tracker_data.json.bak"))
    monkeypatch.setattr(backend_mod, "BACKUP_DIR", str(tmp_path / "backups"))
    # Never let real system idle time leak into tests.
    monkeypatch.setattr(backend_mod, "_idle_seconds", lambda: 0)
    return tmp_path


@pytest.fixture
def be(qapp, data_dir):
    b = backend_mod.TimeTrackerBackend()
    b._timer.stop()  # tests drive _tick() by hand
    yield b
