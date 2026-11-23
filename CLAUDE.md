# CLAUDE.md

## Project Overview

Time-Tracker is a Windows desktop app for tracking time spent on projects, with periodic check-ins, daily/weekly/monthly reports, a billable-utilization calculator, and Excel/JSON export. It uses PySide6 (Qt 6.5+) for the UI: a QML frontend backed by a single Python `QObject` that owns all state and persistence. It is packaged into a standalone `.exe` via PyInstaller (see `time_tracker.spec`).

## Architecture

- **`main.py`** — Entry point. Creates the `QGuiApplication`/`QQmlApplicationEngine`, instantiates `TimeTrackerBackend`, exposes it to QML as the `backend` context property, loads `qml/Main.qml`, and wires `app.aboutToQuit` to `backend.saveAndStop` so an in-progress session is flushed to disk on exit. Also resolves the app/resource directory correctly whether running from source or frozen by PyInstaller (one-folder or one-file). Stays on `QGuiApplication` (no QtWidgets) — the system tray icon is implemented via the QML-native `Qt.labs.platform` module instead of `QSystemTrayIcon`. Sets `setQuitOnLastWindowClosed(False)` (closing/hiding a popup while the main window is hidden in the tray must never quit the app), enforces a single running instance via a Windows named mutex (`_already_running()`); a second launch signals the running instance through a named event (`_signal_running_instance()` → `_ShowRequestListener`, polled every 250 ms) so its window opens, then exits, and sets the app-wide font (Segoe UI Variable).
- **`backend.py`** — All business logic and state, in one file:
  - `TimeTrackerBackend(QObject)` — the central backend: active timer, check-in/EOD/idle scheduling (`QTimer` ticking every second), project CRUD (add/archive/reinstate — projects are never hard-deleted), a task todo list tied to projects with optional due dates (add/edit/complete/reopen/delete, `startTask`), report period navigation (day/week/month with offsets), Excel/CSV export (`exportMonthlyReport`/`exportMonthlyReportCsv`, sharing row-collection via `_collect_monthly_rows`), JSON export/import/restore (`exportJson`/`importJson`/`restoreBackup`), and billable-utilization math (`calculateUtilization`).
  - Six `QAbstractListModel` subclasses exposed as properties to QML: `ProjectListModel`, `TaskListModel`, `HistoryListModel`, `DayDetailModel`, `EodModel`, `ReportModel`. Each defines Qt roles and a `refresh()`/`load()` method the backend calls after mutating `_data`; `TaskListModel` also has `refresh_active_time()`, which updates only the active task's row via `dataChanged` instead of resetting the whole list — used every tick so the Tasks tab doesn't re-scan all rows once a second.
  - Module-level helpers: `load_data()`/`save_data()` (JSON I/O, explicit UTF-8 with `ensure_ascii=False`, legacy migration of string-only project entries to dict form, atomic writes with OneDrive-lock retry, and automatic backup/recovery — see Data Format below), `fmt_time()`, `fmt_date()`, `_idle_seconds()` (Windows `GetLastInputInfo` via ctypes; returns 0 elsewhere).
  - Starting/stopping funnels through two internal methods: `_start(project, task_id)` (used by both `startProject` and `startTask`) and `_stop(trim_seconds=0)` (used by `stopTimer` and by the idle-timeout auto-stop, which passes the idle duration so that trailing idle time is excluded from what gets logged rather than credited to the project/task).
  - Session persistence: the active session is written to `_data["activeSession"]` (including the active task id, if any); on app exit `saveAndStop()` logs elapsed time without clearing session state (so a crash/kill doesn't lose time); on next launch `_restore_active_session()` resumes it if the project still exists and isn't archived (and the task, if any, still exists and isn't done).
  - Time is stored as discrete `sessions` (`{start, end, task}` in minutes-of-day, `task` optional) per project per day, not just a running total — this is what powers manual time editing (`saveDaySessions`) in `TimeEditView.qml` and per-task time totals (`_task_seconds`, scanned on demand rather than cached). `TimeEditView.qml` preserves each session's `task` tag through its edit round-trip rather than dropping it.
  - Starting a task (`startTask`) auto-appends the task's title as a new line in that day/project's `description` the first time time is logged against it (`_autofill_description`) — additive only, never overwrites text already there (including manual EOD-dialog edits).
- **`qml/`** — Qt Quick/QML UI, all under one `ApplicationWindow` (`Main.qml`) with a segmented 5-tab nav (Timer / Tasks / History / Reports / Settings) driven by a `StackLayout`, plus a `Qt.labs.platform.SystemTrayIcon`. The main window is a frameless `Qt.Tool` window (custom title bar: drag to move, bottom-right grip to resize) so it **never gets a taskbar button** — the app lives only in the tray/hidden-icons area. It starts hidden (except on the first launch of the day, which opens to Today's Plan) and `showWindow()` positions it above the tray. Closing/✕ hides it instead of quitting; the backend's `QTimer` keeps running regardless of window visibility. Quit is only reachable from the tray menu, and it (and Ctrl+C in `main.py`) must use `Qt.exit`/`app.exit`, **never `quit()`** — in Qt 6 `quit()` first asks every window to close and is cancelled when `onClosing` refuses, so it silently does nothing while the window is open. A second launch that gets no acknowledgement from the running copy within 3 s shows a "not responding" message instead of exiting silently. `onShowEod` calls `showWindow()` first because `EodDialog` lives inside the main window.
  - **Popup windows (`CheckInWindow`, `ActivityPrompt`) must set `transientParent: null`.** A `Window` declared inside `Main.qml`'s window otherwise becomes its transient child, and Qt refuses to show it while the main window is hidden in the tray (regression-tested in `tests/test_qml_load.py`). Both are frameless, always-on-top, `Qt.WindowDoesNotAcceptFocus` cards in the bottom-right corner (via `backend.primaryAvailableGeometry()`).
  - `ActivityPrompt.qml` — the "What are you working on?" card: today's planned tasks + projects (most-recently-used first) as one-click choices, plus "Not working" (snooze for the configured time), "Snooze 1 hour" and "Open app".
  - `TimerView.qml` — project list, start/stop, live elapsed time; the active-session card also shows the active task's title (`backend.activeTaskTitle`) when the running timer was started from a task.
  - `TaskListView.qml` → `TaskDialog.qml` / `ConfirmDeleteTaskDialog.qml` — the todo list: pending tasks sorted by due date (undated last), each assigned a project and startable/editable/deletable directly from its row, plus a "Completed" sub-page to reopen finished tasks (mirrors the archived-projects sub-page pattern in `SettingsView.qml`). `TaskDialog` doubles as create and edit form (an empty `taskId` means create) and includes a `DatePicker` for the optional due date.
  - `DatePicker.qml` — shared year/month/day spinner widget, extracted from `UtilizationView.qml` (which uses two instances for its date range) and reused a third time by `TaskDialog`. Owns its own year/month/day state; callers read `dateStr()` (or call `setFromString()` to pre-populate it) rather than relying on a live two-way binding.
  - `CheckInWindow.qml` (`CheckInDialog.qml` is an older unused variant) — periodic "are you still working on X?" prompt (interval configurable in Settings); auto-stops the timer after `INACTIVITY_TIMEOUT` (30 min) of no response.
  - `EodDialog.qml` — end-of-day prompt (fires after 6pm if today has logged time with missing descriptions) to fill in per-project descriptions.
  - `HistoryView.qml` → `TimeEditView.qml` — browse past days and manually add/remove/edit per-project time sessions and descriptions. Block geometry rules live in `qml/SessionUtils.js` (`normalize` merges overlaps on load/save, `freeGap` bounds drag-to-create and rejects presses inside a block, `resizeBounds` stops edge-resizes at neighbouring blocks); the backend mirrors `normalize` in `_normalize_sessions()` inside `saveDaySessions`. Each block's × is a direct child with z above the resize handles, and the handles leave the × column free — otherwise short blocks can't be deleted. Creating a block needs a real drag (≥4 px); a plain click does nothing. Mouse-level regression tests: `tests/test_time_edit.py`. `DayDetailView.qml` is a lighter read-only day view.
  - `ReportView.qml` — day/week/month totals per project, an Excel/CSV export dialog (format toggle in the same dialog), and embeds `UtilizationView.qml` (billable-rate calculator against 8h/weekday standard, with PTO/holiday adjustment) as a sub-section, not a separate nav tab.
  - `SettingsView.qml` → `ProjectDialog.qml` / `ConfirmRemoveDialog.qml` / `ConfirmRestoreDialog.qml` — manage projects (name, billing code, billable flag), archive/reinstate, check-in interval, idle timeout, JSON export/import, an in-app "Restore Backup" sub-page (lists every backup on disk via `backend.getAvailableBackups()`, same sub-page pattern as Archived Projects), and clear history.
  - Views communicate with the backend by calling `Slot`s directly and binding to `Property`/`Signal` values and the list models — no other IPC layer.

## Data Format

Runtime data lives in `tracker_data.json` (git-ignored, auto-created next to the script or `.exe`):

```json
{
  "projects": [
    { "name": "Project Name", "billingCode": "", "billable": true, "archived": false }
  ],
  "tasks": [
    { "id": "3f1a...", "title": "Write proposal", "project": "Project Name",
      "done": false, "createdDate": "2026-08-31", "completedDate": null,
      "dueDate": null }
  ],
  "checkInInterval": 30,
  "idleTimeout": 10,
  "dailyLogs": {
    "YYYY-MM-DD": {
      "Project Name": {
        "seconds": 3600,
        "description": "What was done",
        "sessions": [{ "start": 540, "end": 600, "task": "3f1a..." }]
      }
    }
  },
  "activeSession": { "project": "Project Name", "startTime": 1234567890.0, "task": "3f1a..." }
}
```

- `projects` entries may still be plain strings on old data files; `load_data()`/`importJson()`/`restoreBackup()` migrate them to the dict form (`billingCode: ""`, `billable: true`) on load.
- `tasks` is defaulted to `[]` by `load_data()` for older data files that predate it, and each task's `dueDate` is backfilled to `null` if missing. A task's `project` is a name, not a reference — nothing currently guards against that project later being archived. Deleting a task only removes the task record; any time already logged against its project stays in `dailyLogs`. `TaskListModel` sorts pending tasks by `dueDate` (undated last), then `createdDate`.
- `idleTimeout` (minutes, default 10) is defaulted by `load_data()` for older files; see Idle detection below.
- `sessions` entries are `{start, end}` in minutes-since-midnight, plus an optional `task` (task id) when that block of time was logged while a task was active; ad-hoc project-only sessions omit it. `seconds` is derived from `sessions` and kept in sync by `_log_time`/`saveDaySessions`.
- `activityPrompt` (bool, default `true`) and `activityPromptSnooze` (minutes, default 15) control the activity prompt; see below.
- `activeSession` is only present while a timer is running (or was running at last exit); consumed by `_restore_active_session()` on startup, including which task (if any) was active.

### Backups & crash safety

`save_data()` writes atomically (temp file + `os.replace`, with a short retry-then-fallback loop for the transient `PermissionError` a cloud-synced folder like OneDrive can cause) so a crash, kill, or sync-lock mid-write can't leave `tracker_data.json` truncated or unsaved. It also maintains backups, all git-ignored:

- `tracker_data.json.bak` — a copy of the file as it was just before the most recent save (updated every save).
- `backups/tracker_data_YYYY-MM-DD.json` — one snapshot per calendar day, pruned after `BACKUP_RETENTION_DAYS` (30).
- `backups/tracker_data_pre-import_<timestamp>.json` / `backups/tracker_data_pre-restore_<timestamp>.json` — written by `snapshot_before_overwrite(reason)` right before `importJson()` or `restoreBackup()` replaces all in-memory data, so either action can itself be undone.

`load_data()` never silently resets to an empty dataset on a corrupt/missing main file — it tries `tracker_data.json`, then `.bak`, then the newest daily snapshot, and only falls back to empty if all three fail (`_is_valid_data()` gate). Recovery can be done in-app: Settings → Restore Backup lists every backup (via `backend.getAvailableBackups()`, newest-first by file mtime) with a one-click restore (`backend.restoreBackup(path)`), or you can still close the app and manually copy a file from `backups/` (or `tracker_data.json.bak`) over `tracker_data.json`.

### Activity prompt

When no timer is running, the prompt is enabled, at least one project exists and the snooze has elapsed, `_check_activity_prompt()` (every tick) emits `showActivityPrompt` as soon as `_idle_seconds() < 2` (i.e. the user just touched the mouse/keyboard). `_prompt_visible` stops it re-firing every second while shown; starting any timer clears it. A deliberate stop (`stopTimer`, check-in "No") or "Not working" snoozes for `activityPromptSnooze` minutes; an **idle auto-stop does not** snooze, so returning to the computer prompts right away. If the main window is focused, `Main.qml` snoozes 1 minute instead of showing the card.

### Day rollover

The app runs for days in the tray, so `_tick()` calls `_roll_over_day()` when the date changes: a running session is split at midnight (the pre-midnight part logged to the previous day, ending at minute 1440), the EOD prompt is re-armed, and date-dependent models refresh.

### Idle detection

`_idle_seconds()` reads system-wide idle time via the Windows `GetLastInputInfo` API. When a session is active and idle time crosses `idleTimeout` minutes, `_tick()` calls `_stop(trim_seconds=idle)`, which logs only the non-idle portion of the elapsed time (via `_log_time`, anchored at the original `session_start`) rather than crediting the idle tail to the project/task. Inert (returns 0, never triggers) on non-Windows platforms.

## Setup

```bash
pip install -r requirements.txt   # PySide6>=6.5, openpyxl
```

## Running

```bash
python main.py
```

## Building the executable

```bash
pyinstaller time_tracker.spec
```

Produces a one-folder build at `dist/TimeTracker/`. The spec's `excludes` list *intends* to keep unused PySide6 modules (WebEngine, Multimedia, 3D, Charts, etc.) out of the build, and `hiddenimports`/`pyside6_qml_data` explicitly add back QML modules actually used (`QtQuick.Dialogs`, `Qt.labs.platform` for the tray icon) — but see the exe-size caveat in Known Issues before assuming `excludes` is actually trimming anything. When adding a new QML module import, add its data path to `pyside6_qml_data`'s `includes` (match the existing entries' style) so a packaged build can locate it.

Build verification note: if you build in a very deeply-nested path (e.g. a long temp/scratch directory), you can hit a Windows `MAX_PATH` "filename or extension is too long" failure loading a QML plugin DLL — this is a path-length artifact of the build location, not an app bug. Build from a short path (e.g. close to a drive root) if you hit it.

## Tech Stack

- **Python 3.x** + **PySide6 (Qt 6.5+)** for the app/QML bridge
- **Qt Quick / QML** for the UI (no QML Charts/visualization modules currently used); `Qt.labs.platform` for the system tray icon
- **openpyxl** + stdlib **csv** for `.xlsx`/`.csv` report export
- **ctypes** (Windows `GetLastInputInfo`) for idle detection
- **JSON** for local data persistence
- **PyInstaller** for packaging (see `time_tracker.spec`)

## Known Issues

- Report view visualizations are still numeric/tabular (day/week/month totals + a utilization percentage) — no charts/graphs yet.
- Default `Flickable`/`ScrollView` scrollbars can appear even when content fits the view (no explicit `ScrollBar.policy` overrides in the QML views).
- The PyInstaller spec's `excludes` list doesn't appear to actually trim binaries in the currently-installed PyInstaller (6.22.2) / PySide6 (6.11.1) combo — a real packaged build was found to include `Qt6Widgets.dll` and most other "excluded" Qt6 modules (WebEngine, Multimedia, 3D, etc.) regardless. The earlier exe-size-reduction work may need revisiting; worth confirming with `PyInstaller.utils.hooks` / the PySide6 hook version before assuming any module is actually excluded from a build.
- No manual reordering of tasks (sorted by due date, then creation date only), and no guard against a task's project being archived out from under it.

Resolved since the original notes (kept here so they aren't rediscovered as new bugs): active-timer autosave on exit and restore on relaunch (`saveAndStop`/`_restore_active_session`), Excel/CSV export of monthly reports, task tracking with due dates, backup/restore, idle detection, and minimize-to-tray.

## Testing

```bash
pip install pytest
python -m pytest tests -q
```

- `tests/test_backend.py` — backend logic (timer, tasks, idle auto-stop, check-in timeout, midnight split, activity prompt, persistence/recovery, import/export, utilization).
- `tests/test_time_edit.py` — History day editor: `SessionUtils.js` helpers (evaluated in a plain `QJSEngine`) plus real `QTest` mouse clicks/drags against the rendered editor (delete short block, click inside block, drag across block, resize into neighbour, save).
- `tests/test_qml_load.py` — loads the full QML UI offscreen and fails on any QML warning/error; also checks popups show while the main window is hidden and the main window has no taskbar button.
- `tests/conftest.py` redirects `DATA_FILE`/`BAK_FILE`/`BACKUP_DIR` to a temp dir and stubs `_idle_seconds`, so tests never touch the real `tracker_data.json`. It also sets the `Basic` style like `main.py`.
- Note: on Windows, Qt log output goes to the debugger, not the console, when running outside a terminal — install a `qInstallMessageHandler` to see QML warnings (the tests do).

UI/visual behavior (tray, popups, real input) still deserves a manual pass via `python main.py`.
