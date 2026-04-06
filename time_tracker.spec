# -*- mode: python ; coding: utf-8 -*-
#
# PyInstaller spec for Time Tracker.
# Build with:   pyinstaller time_tracker.spec
#
# This produces a one-folder distribution under dist/TimeTracker/.
# To produce a single .exe instead, set onefile=True in the EXE/COLLECT
# section (see comment below).

from PyInstaller.utils.hooks import collect_data_files, collect_submodules

block_cipher = None

# Collect PySide6 QML plugin data so QtQuick / QtQuick.Controls work.
pyside6_qml_data = collect_data_files("PySide6", includes=["*.qml", "qmldir"])

a = Analysis(
    ["main.py"],
    pathex=[],
    binaries=[],
    datas=[
        # Bundle the app's own QML files.
        ("qml", "qml"),
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
        "PySide6.QtNetwork",
        *collect_submodules("openpyxl"),
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
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
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
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
    strip=False,
    upx=True,
    upx_exclude=[],
    name="TimeTracker",
)
