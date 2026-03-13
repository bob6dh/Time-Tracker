import json
import os
import time
from datetime import datetime, date

from PySide6.QtCore import (
    QObject, Property, Signal, Slot, QTimer, QAbstractListModel,
    Qt, QModelIndex, QByteArray,
)

DATA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tracker_data.json")


def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"projects": [], "checkInInterval": 30, "dailyLogs": {}}


def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)


def fmt_time(seconds):
    seconds = int(seconds)
    h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
    if h > 0:
        return f"{h}h {m}m"
    if m > 0:
        return f"{m}m {s}s"
    return f"{s}s"


def fmt_date(d):
    try:
        return datetime.strptime(d, "%Y-%m-%d").strftime("%a, %b %d, %Y")
    except Exception:
        return d


# ── Project list model ──────────────────────────────────────────


class ProjectListModel(QAbstractListModel):
    NameRole = Qt.UserRole + 1
    TodayTimeRole = Qt.UserRole + 2
    IsActiveRole = Qt.UserRole + 3

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend

    def roleNames(self):
        return {
            self.NameRole: QByteArray(b"name"),
            self.TodayTimeRole: QByteArray(b"todayTime"),
            self.IsActiveRole: QByteArray(b"isActive"),
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._backend._data["projects"])

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        proj = self._backend._data["projects"][index.row()]
        if role == self.NameRole:
            return proj
        if role == self.TodayTimeRole:
            return fmt_time(self._backend._get_today_total(proj))
        if role == self.IsActiveRole:
            return self._backend._active_project == proj
        return None

    def refresh(self):
        self.beginResetModel()
        self.endResetModel()


# ── History list model ──────────────────────────────────────────


class HistoryListModel(QAbstractListModel):
    DateKeyRole = Qt.UserRole + 1
    DateLabelRole = Qt.UserRole + 2
    ProjectCountRole = Qt.UserRole + 3
    TotalTimeRole = Qt.UserRole + 4

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend

    def roleNames(self):
        return {
            self.DateKeyRole: QByteArray(b"dateKey"),
            self.DateLabelRole: QByteArray(b"dateLabel"),
            self.ProjectCountRole: QByteArray(b"projectCount"),
            self.TotalTimeRole: QByteArray(b"totalTime"),
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._sorted_days())

    def _sorted_days(self):
        return sorted(self._backend._data["dailyLogs"].keys(), reverse=True)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        day = self._sorted_days()[index.row()]
        log = self._backend._data["dailyLogs"][day]
        if role == self.DateKeyRole:
            return day
        if role == self.DateLabelRole:
            return fmt_date(day)
        if role == self.ProjectCountRole:
            n = len(log)
            return f"{n} project{'s' if n != 1 else ''}"
        if role == self.TotalTimeRole:
            return fmt_time(sum(v["seconds"] for v in log.values()))
        return None

    def refresh(self):
        self.beginResetModel()
        self.endResetModel()


# ── Day detail list model ───────────────────────────────────────


class DayDetailModel(QAbstractListModel):
    ProjectRole = Qt.UserRole + 1
    TimeRole = Qt.UserRole + 2
    DescriptionRole = Qt.UserRole + 3

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend
        self._items = []

    def roleNames(self):
        return {
            self.ProjectRole: QByteArray(b"project"),
            self.TimeRole: QByteArray(b"time"),
            self.DescriptionRole: QByteArray(b"description"),
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        item = self._items[index.row()]
        if role == self.ProjectRole:
            return item["project"]
        if role == self.TimeRole:
            return item["time"]
        if role == self.DescriptionRole:
            return item["description"]
        return None

    def load_day(self, day_key):
        self.beginResetModel()
        log = self._backend._data["dailyLogs"].get(day_key, {})
        self._items = [
            {
                "project": proj,
                "time": fmt_time(info["seconds"]),
                "description": info.get("description", ""),
            }
            for proj, info in log.items()
        ]
        self.endResetModel()


# ── EOD model ───────────────────────────────────────────────────


class EodModel(QAbstractListModel):
    ProjectRole = Qt.UserRole + 1
    DescriptionRole = Qt.UserRole + 2

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend
        self._items = []

    def roleNames(self):
        return {
            self.ProjectRole: QByteArray(b"project"),
            self.DescriptionRole: QByteArray(b"description"),
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        item = self._items[index.row()]
        if role == self.ProjectRole:
            return item["project"]
        if role == self.DescriptionRole:
            return item["description"]
        return None

    def load(self):
        self.beginResetModel()
        today = date.today().isoformat()
        log = self._backend._data["dailyLogs"].get(today, {})
        self._items = [
            {"project": proj, "description": info.get("description", "")}
            for proj, info in log.items()
        ]
        self.endResetModel()

    @Slot(int, str)
    def setDescription(self, index, desc):
        if 0 <= index < len(self._items):
            self._items[index]["description"] = desc


# ── Main backend ────────────────────────────────────────────────


class TimeTrackerBackend(QObject):
    # Signals
    activeProjectChanged = Signal()
    elapsedChanged = Signal()
    elapsedTextChanged = Signal()
    checkInIntervalChanged = Signal()
    showCheckIn = Signal()
    showEod = Signal()
    hasTodayLogsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._data = load_data()
        self._active_project = None
        self._session_start = None
        self._elapsed = 0
        self._last_checkin = None
        self._eod_dismissed = False

        self._project_model = ProjectListModel(self)
        self._history_model = HistoryListModel(self)
        self._day_detail_model = DayDetailModel(self)
        self._eod_model = EodModel(self)

        self._timer = QTimer(self)
        self._timer.setInterval(1000)
        self._timer.timeout.connect(self._tick)
        self._timer.start()

    # ── Properties ──

    @Property(str, notify=activeProjectChanged)
    def activeProject(self):
        return self._active_project or ""

    @Property(int, notify=elapsedChanged)
    def elapsed(self):
        return self._elapsed

    @Property(str, notify=elapsedTextChanged)
    def elapsedText(self):
        return fmt_time(self._elapsed)

    @Property(int, notify=checkInIntervalChanged)
    def checkInInterval(self):
        return self._data["checkInInterval"]

    @Property(bool, notify=hasTodayLogsChanged)
    def hasTodayLogs(self):
        today = date.today().isoformat()
        return bool(self._data["dailyLogs"].get(today))

    @Property(QObject, constant=True)
    def projectModel(self):
        return self._project_model

    @Property(QObject, constant=True)
    def historyModel(self):
        return self._history_model

    @Property(QObject, constant=True)
    def dayDetailModel(self):
        return self._day_detail_model

    @Property(QObject, constant=True)
    def eodModel(self):
        return self._eod_model

    # ── Slots ──

    @Slot(str)
    def addProject(self, name):
        name = name.strip()
        if not name or name in self._data["projects"]:
            return
        self._data["projects"].append(name)
        save_data(self._data)
        self._project_model.refresh()

    @Slot(str)
    def removeProject(self, name):
        if self._active_project == name:
            self.stopTimer()
        self._data["projects"] = [p for p in self._data["projects"] if p != name]
        save_data(self._data)
        self._project_model.refresh()

    @Slot(str)
    def startProject(self, name):
        if self._active_project and self._session_start:
            self._log_time(int(time.time() - self._session_start))
        self._active_project = name
        self._session_start = time.time()
        self._last_checkin = time.time()
        self._elapsed = 0
        self.activeProjectChanged.emit()
        self.elapsedChanged.emit()
        self.elapsedTextChanged.emit()
        self._project_model.refresh()

    @Slot()
    def stopTimer(self):
        if self._active_project and self._session_start:
            self._log_time(int(time.time() - self._session_start))
        self._active_project = None
        self._session_start = None
        self._elapsed = 0
        self._last_checkin = None
        self.activeProjectChanged.emit()
        self.elapsedChanged.emit()
        self.elapsedTextChanged.emit()
        self._project_model.refresh()
        self.hasTodayLogsChanged.emit()

    @Slot(int)
    def setCheckInInterval(self, minutes):
        self._data["checkInInterval"] = minutes
        save_data(self._data)
        self.checkInIntervalChanged.emit()

    @Slot()
    def clearHistory(self):
        self._data["dailyLogs"] = {}
        save_data(self._data)
        self._history_model.refresh()
        self.hasTodayLogsChanged.emit()

    @Slot(str)
    def openDayDetail(self, day_key):
        self._day_detail_model.load_day(day_key)

    @Slot(str, result=str)
    def dayDetailTitle(self, day_key):
        return fmt_date(day_key)

    @Slot()
    def checkInYes(self):
        self._last_checkin = time.time()

    @Slot()
    def checkInNo(self):
        self.stopTimer()

    @Slot()
    def openEodDialog(self):
        self._eod_model.load()
        self.showEod.emit()

    @Slot()
    def saveEod(self):
        today = date.today().isoformat()
        for item in self._eod_model._items:
            proj = item["project"]
            desc = item["description"]
            if today in self._data["dailyLogs"] and proj in self._data["dailyLogs"][today]:
                self._data["dailyLogs"][today][proj]["description"] = desc
        save_data(self._data)
        self._eod_dismissed = True

    @Slot()
    def dismissEod(self):
        self._eod_dismissed = True

    @Slot()
    def refreshModels(self):
        self._project_model.refresh()
        self._history_model.refresh()
        self.hasTodayLogsChanged.emit()

    # ── Internal ──

    def _log_time(self, secs):
        if not self._active_project or secs <= 0:
            return
        today = date.today().isoformat()
        if today not in self._data["dailyLogs"]:
            self._data["dailyLogs"][today] = {}
        if self._active_project not in self._data["dailyLogs"][today]:
            self._data["dailyLogs"][today][self._active_project] = {
                "seconds": 0,
                "description": "",
            }
        self._data["dailyLogs"][today][self._active_project]["seconds"] += secs
        save_data(self._data)

    def _get_today_total(self, proj):
        today = date.today().isoformat()
        base = (
            self._data.get("dailyLogs", {})
            .get(today, {})
            .get(proj, {})
            .get("seconds", 0)
        )
        if self._active_project == proj and self._session_start:
            base += int(time.time() - self._session_start)
        return base

    def _tick(self):
        if self._active_project and self._session_start:
            self._elapsed = int(time.time() - self._session_start)
            self.elapsedChanged.emit()
            self.elapsedTextChanged.emit()
            # Refresh project model to update "today" times for active project
            self._project_model.refresh()

        # Check-in
        if self._active_project and self._last_checkin:
            if time.time() - self._last_checkin >= self._data["checkInInterval"] * 60:
                self._last_checkin = time.time()
                self.showCheckIn.emit()

        # EOD prompt
        if not self._eod_dismissed:
            now = datetime.now()
            today = date.today().isoformat()
            log = self._data.get("dailyLogs", {}).get(today, {})
            if now.hour >= 18 and log:
                has_time = any(v["seconds"] > 0 for v in log.values())
                all_descs = all(v.get("description") for v in log.values())
                if has_time and not all_descs:
                    self._eod_dismissed = True
                    self.openEodDialog()
