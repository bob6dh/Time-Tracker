# CLAUDE.md

## Project Overview

Time-Tracker is a Windows desktop app for tracking time spent on projects, with periodic check-ins, daily/weekly/monthly reports, a billable-utilization calculator, and Excel/JSON export. It uses PySide6 (Qt 6.5+) for the UI: a QML frontend backed by a single Python `QObject` that owns all state and persistence. It is packaged into a standalone `.exe` via PyInstaller (see `time_tracker.spec`).

## Architecture

- **`main.py`** — Entry point. Creates the `QGuiApplication`/`QQmlApplicationEngine`, instantiates `TimeTrackerBackend`, exposes it to QML as the `backend` context property, loads `qml/Main.qml`, and wires `app.aboutToQuit` to `backend.saveAndStop` so an in-progress session is flushed to disk on exit. Also resolves the app/resource directory correctly whether running from source or frozen by PyInstaller (one-folder or one-file).
- **`backend.py`** — All business logic and state, in one file:
  - `TimeTrackerBackend(QObject)` — the central backend: active timer, check-in/EOD scheduling (`QTimer` ticking every second), project CRUD (add/archive/reinstate — projects are never hard-deleted), a task todo list tied to projects (add/complete/reopen/delete, `startTask`), report period navigation (day/week/month with offsets), Excel export (`exportMonthlyReport`, via `openpyxl`), JSON export/import (`exportJson`/`importJson`), and billable-utilization math (`calculateUtilization`).
  - Six `QAbstractListModel` subclasses exposed as properties to QML: `ProjectListModel`, `TaskListModel`, `HistoryListModel`, `DayDetailModel`, `EodModel`, `ReportModel`. Each defines Qt roles and a `refresh()`/`load()` method the backend calls after mutating `_data`.
  - Module-level helpers: `load_data()`/`save_data()` (JSON I/O, with legacy migration of string-only project entries to dict form, atomic writes, and automatic backup/recovery — see Data Format below), `fmt_time()`, `fmt_date()`.
  - Session persistence: on `startProject`/`startTask` (both funnel through the internal `_start()`), the active session is written to `_data["activeSession"]` (including the active task id, if any); on normal `stopTimer()` it's cleared; on app exit `saveAndStop()` logs elapsed time without clearing session state (so a crash/kill doesn't lose time); on next launch `_restore_active_session()` resumes it if the project still exists and isn't archived (and the task, if any, still exists and isn't done).
  - Time is stored as discrete `sessions` (`{start, end, task}` in minutes-of-day, `task` optional) per project per day, not just a running total — this is what powers manual time editing (`saveDaySessions`) in `TimeEditView.qml` and per-task time totals (`_task_seconds`, scanned on demand rather than cached).
  - Starting a task (`startTask`) auto-appends the task's title as a new line in that day/project's `description` the first time time is logged against it (`_autofill_description`) — additive only, never overwrites text already there (including manual EOD-dialog edits).
- **`qml/`** — Qt Quick/QML UI, all under one `ApplicationWindow` (`Main.qml`) with a 5-tab nav bar (Timer / Tasks / History / Reports / Settings) driven by a `StackLayout`:
  - `TimerView.qml` — project list, start/stop, live elapsed time; the active-session card also shows the active task's title (`backend.activeTaskTitle`) when the running timer was started from a task.
  - `TaskListView.qml` → `TaskDialog.qml` / `ConfirmDeleteTaskDialog.qml` — the todo list: pending tasks (each assigned a project, startable directly from its row) and a "Completed" sub-page to reopen finished tasks, mirroring the archived-projects sub-page pattern in `SettingsView.qml`.
  - `CheckInWindow.qml` / `CheckInDialog.qml` — periodic "are you still working on X?" prompt (interval configurable in Settings); auto-stops the timer after `INACTIVITY_TIMEOUT` (30 min) of no response.
  - `EodDialog.qml` — end-of-day prompt (fires after 6pm if today has logged time with missing descriptions) to fill in per-project descriptions.
  - `HistoryView.qml` → `TimeEditView.qml` — browse past days and manually add/remove/edit per-project time sessions and descriptions (sessions added/edited here are not task-tagged). `DayDetailView.qml` is a lighter read-only day view.
  - `ReportView.qml` — day/week/month totals per project, Excel export dialog, and embeds `UtilizationView.qml` (billable-rate calculator against 8h/weekday standard, with PTO/holiday adjustment) as a sub-section, not a separate nav tab.
  - `SettingsView.qml` → `ProjectDialog.qml` / `ConfirmRemoveDialog.qml` — manage projects (name, billing code, billable flag), archive/reinstate, check-in interval, JSON export/import, clear history.
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
      "done": false, "createdDate": "2026-08-31", "completedDate": null }
  ],
  "checkInInterval": 30,
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

- `projects` entries may still be plain strings on old data files; `load_data()`/`importJson()` migrate them to the dict form (`billingCode: ""`, `billable: true`) on load.
- `tasks` is defaulted to `[]` by `load_data()` for older data files that predate it. A task's `project` is a name, not a reference — nothing currently guards against that project later being archived. Deleting a task only removes the task record; any time already logged against its project stays in `dailyLogs`.
- `sessions` entries are `{start, end}` in minutes-since-midnight, plus an optional `task` (task id) when that block of time was logged while a task was active; ad-hoc project-only sessions omit it. `seconds` is derived from `sessions` and kept in sync by `_log_time`/`saveDaySessions`.
- `activeSession` is only present while a timer is running (or was running at last exit); consumed by `_restore_active_session()` on startup, including which task (if any) was active.

### Backups & crash safety

`save_data()` writes atomically (temp file + `os.replace`) so a crash or kill mid-write can't leave `tracker_data.json` truncated. It also maintains backups, all git-ignored:

- `tracker_data.json.bak` — a copy of the file as it was just before the most recent save (updated every save).
- `backups/tracker_data_YYYY-MM-DD.json` — one snapshot per calendar day, pruned after `BACKUP_RETENTION_DAYS` (30).
- `backups/tracker_data_pre-import_YYYY-MM-DD_HHMMSS.json` — written by `snapshot_pre_import_backup()` right before `importJson()` replaces all in-memory data, so a bad import can be undone.

`load_data()` never silently resets to an empty dataset on a corrupt/missing main file — it tries `tracker_data.json`, then `.bak`, then the newest daily snapshot, and only falls back to empty if all three fail (`_is_valid_data()` gate). To manually recover, close the app and copy a file from `backups/` (or `tracker_data.json.bak`) over `tracker_data.json` — there's no in-app restore UI.

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

Produces a one-folder build at `dist/TimeTracker/`. The spec explicitly excludes unused PySide6 modules (WebEngine, Multimedia, 3D, Charts, etc.) and stdlib modules to keep the output small — when adding new imports (especially new PySide6 submodules), check whether they need adding to `hiddenimports` or removing from `excludes`.

## Tech Stack

- **Python 3.x** + **PySide6 (Qt 6.5+)** for the app/QML bridge
- **Qt Quick / QML** for the UI (no QML Charts/visualization modules currently used)
- **openpyxl** for `.xlsx` report export
- **JSON** for local data persistence
- **PyInstaller** for packaging (see `time_tracker.spec`)

## Known Issues

- Report view visualizations are still numeric/tabular (day/week/month totals + a utilization percentage) — no charts/graphs yet.
- Default `Flickable`/`ScrollView` scrollbars can appear even when content fits the view (no explicit `ScrollBar.policy` overrides in the QML views).
- No automated test suite — all verification is manual.

Resolved since the original notes (kept here so they aren't rediscovered as new bugs): active-timer autosave on exit and restore on relaunch (`saveAndStop`/`_restore_active_session`), and Excel export of monthly reports.

## Testing

No automated test suite exists. Testing is manual via running the application (`python main.py`).
