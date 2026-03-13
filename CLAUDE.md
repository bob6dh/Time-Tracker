# CLAUDE.md

## Project Overview

Time-Tracker is a Python desktop application for tracking time spent on projects. It uses PySide6 (Qt 6.5+) for the UI with a QML frontend and Python backend.

## Architecture

- **`main.py`** — Entry point; initializes the QGuiApplication and QML engine
- **`backend.py`** — Core business logic: data models, timer management, signal/slot connections
- **`qml/`** — Qt Quick/QML UI components (views for timer, history, reports, settings)
- **`tracker_data.json`** — Auto-generated runtime data file (projects and daily logs)

The app follows a Model-View architecture: Python backend emits Qt signals, QML views bind to data via `QAbstractListModel` subclasses.

## Setup

```bash
pip install PySide6>=6.5
```

## Running

```bash
python main.py
```

## Tech Stack

- **Python 3.x** + **PySide6 (Qt 6.5+)**
- **Qt Quick / QML** for the UI
- **JSON** for local data persistence

## Data Format

Data is stored in `tracker_data.json`:

```json
{
  "projects": ["Project Name"],
  "checkInInterval": 30,
  "dailyLogs": {
    "YYYY-MM-DD": {
      "Project Name": {
        "seconds": 3600,
        "description": "What was done"
      }
    }
  }
}
```

## Known Issues

- Active timer is not auto-saved when the application exits
- Report view visualizations need improvement
- Unnecessary scrollbars appear when content fits the view

## Testing

No automated test suite exists. Testing is manual via running the application.
