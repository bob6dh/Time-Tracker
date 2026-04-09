# -*- mode: python ; coding: utf-8 -*-
#
# PyInstaller spec for Time Tracker.
# Build with:   pyinstaller time_tracker.spec
#
# This produces a one-folder distribution under dist/TimeTracker/.
# To produce a single .exe instead, set onefile=True in the EXE/COLLECT
# section (see comment below).

import os
import sys
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

block_cipher = None

# strip is a Linux/macOS-only tool; UPX can trigger antivirus on Windows.
_is_windows = sys.platform == "win32"
_strip = not _is_windows
_upx   = not _is_windows

# Collect QML data only for the modules this app actually uses:
#   QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Dialogs, QtQuick.Window
# Avoids pulling in QML files for WebEngine, Multimedia, 3D, etc.
_qml_includes = [
    "*/QtQuick/*",
    "*/QtQuick.Controls/*",
    "*/QtQuick/Controls/*",
    "*/QtQuick/Layouts/*",
    "*/QtQuick/Dialogs/*",
    "*/QtQml/*",
    "qmldir",
    "*.qmltypes",
]
pyside6_qml_data = collect_data_files(
    "PySide6",
    includes=["Qt/qml/QtQuick*/**", "Qt/qml/QtQml*/**", "Qt/qml/QtQuick*", "Qt/qml/QtQml*", "qmldir"],
)

a = Analysis(
    ["main.py"],
    pathex=[],
    binaries=[],
    datas=[
        # Bundle the app's own QML files.
        ("qml", "qml"),
        # App icon — placed in the root of the bundle so _app_dir() can find it.
        ("time_img.ico", "."),
        # PySide6 QML module files (QtQuick, QtQuick.Controls, etc.)
        *pyside6_qml_data,
    ],
    hiddenimports=[
        "backend",
        "openpyxl",
        "openpyxl.styles",
        "openpyxl.utils",
        "PySide6.QtQml",
        "PySide6.QtQuick",
        "PySide6.QtQuickControls2",
        "PySide6.QtQuickDialogs2",     # backs QtQuick.Dialogs used in ReportView/SettingsView
        *collect_submodules("openpyxl"),
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Unused Qt modules — prevents their binaries from being bundled.
        # WebEngine is especially large (50+ MB on its own).
        "PySide6.QtWebEngine",
        "PySide6.QtWebEngineCore",
        "PySide6.QtWebEngineWidgets",
        "PySide6.QtWebEngineQuick",
        "PySide6.QtMultimedia",
        "PySide6.QtMultimediaWidgets",
        "PySide6.QtMultimediaQuick",
        "PySide6.Qt3DCore",
        "PySide6.Qt3DRender",
        "PySide6.Qt3DInput",
        "PySide6.Qt3DLogic",
        "PySide6.Qt3DAnimation",
        "PySide6.Qt3DExtras",
        "PySide6.QtCharts",
        "PySide6.QtDataVisualization",
        "PySide6.QtLocation",
        "PySide6.QtPositioning",
        "PySide6.QtBluetooth",
        "PySide6.QtNfc",
        "PySide6.QtSensors",
        "PySide6.QtWebSockets",
        "PySide6.QtWebChannel",
        "PySide6.QtSerialPort",
        "PySide6.QtSerialBus",
        "PySide6.QtSql",
        "PySide6.QtTest",
        "PySide6.QtPdf",
        "PySide6.QtPdfWidgets",
        "PySide6.QtSvg",
        "PySide6.QtSvgWidgets",
        "PySide6.QtXml",
        "PySide6.QtConcurrent",
        "PySide6.QtHelp",
        "PySide6.QtDesigner",
        "PySide6.QtUiTools",
        "PySide6.QtWidgets",
        "PySide6.QtOpenGLWidgets",
        "PySide6.QtPrintSupport",
        "PySide6.QtScxml",
        "PySide6.QtStateMachine",
        "PySide6.QtRemoteObjects",
        "PySide6.QtQuick3D",
        "PySide6.QtVirtualKeyboard",
        # Unused stdlib modules
        "tkinter",
        "unittest",
        "xmlrpc",
        "ftplib",
        "imaplib",
        "smtplib",
        "telnetlib",
        "turtle",
        "turtledemo",
        "msilib",
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],                    # Keep empty for one-folder mode.
    # a.binaries,          # Uncomment these three lines and remove COLLECT
    # a.zipfiles,          # below to switch to one-file mode.
    # a.datas,
    exclude_binaries=True,  # Set to False for one-file mode.
    name="TimeTracker",
    icon="time_img.ico",
    debug=False,
    bootloader_ignore_signals=False,
    strip=_strip,
    upx=_upx,
    console=False,          # No terminal window.
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

# Remove this block when switching to one-file mode.
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=_strip,
    upx=_upx,
    upx_exclude=[],
    name="TimeTracker",
)
