import json
import os
import time
import calendar
from datetime import datetime, date, timedelta

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

from PySide6.QtCore import (
    QObject, Property, Signal, Slot, QTimer, QAbstractListModel,
    Qt, QModelIndex, QByteArray,
)

DATA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tracker_data.json")


def _proj_name(p):
    """Return the name string from either a legacy string project or a dict project."""
    return p["name"] if isinstance(p, dict) else p


def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                data = json.load(f)
            # Migrate legacy string-format projects to dict format
            data["projects"] = [
                p if isinstance(p, dict)
                else {"name": p, "billingCode": "", "billable": True}
                for p in data.get("projects", [])
            ]
            return data
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
    BillingCodeRole = Qt.UserRole + 4
    BillableRole = Qt.UserRole + 5

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend

    def roleNames(self):
        return {
            self.NameRole: QByteArray(b"name"),
            self.TodayTimeRole: QByteArray(b"todayTime"),
            self.IsActiveRole: QByteArray(b"isActive"),
            self.BillingCodeRole: QByteArray(b"billingCode"),
            self.BillableRole: QByteArray(b"billable"),
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._backend._data["projects"])

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        proj = self._backend._data["projects"][index.row()]
        name = _proj_name(proj)
        if role == self.NameRole:
            return name
        if role == self.TodayTimeRole:
            return fmt_time(self._backend._get_today_total(name))
        if role == self.IsActiveRole:
            return self._backend._active_project == name
        if role == self.BillingCodeRole:
            return proj.get("billingCode", "") if isinstance(proj, dict) else ""
        if role == self.BillableRole:
            return proj.get("billable", True) if isinstance(proj, dict) else True
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
        days = set(self._backend._data["dailyLogs"].keys())
        # Include today if there's an active session even before first stop
        if self._backend._active_project and self._backend._session_start:
            days.add(date.today().isoformat())
        return sorted(days, reverse=True)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid():
            return None
        day = self._sorted_days()[index.row()]
        log = self._backend._data["dailyLogs"].get(day, {})
        if role == self.DateKeyRole:
            return day
        if role == self.DateLabelRole:
            return fmt_date(day)
        if role == self.ProjectCountRole:
            projects = set(log.keys())
            today_str = date.today().isoformat()
            if day == today_str and self._backend._active_project:
                projects.add(self._backend._active_project)
            n = len(projects)
            return f"{n} project{'s' if n != 1 else ''}"
        if role == self.TotalTimeRole:
            total = sum(v["seconds"] for v in log.values())
            today_str = date.today().isoformat()
            if day == today_str and self._backend._active_project and self._backend._session_start:
                total += int(time.time() - self._backend._session_start)
            return fmt_time(total)
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

    @Slot()
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


# ── Report model ───────────────────────────────────────────────


class ReportModel(QAbstractListModel):
    ProjectRole = Qt.UserRole + 1
    TimeRole = Qt.UserRole + 2
    SecondsRole = Qt.UserRole + 3

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend
        self._items = []

    def roleNames(self):
        return {
            self.ProjectRole: QByteArray(b"project"),
            self.TimeRole: QByteArray(b"time"),
            self.SecondsRole: QByteArray(b"seconds"),
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
            return fmt_time(item["seconds"])
        if role == self.SecondsRole:
            return item["seconds"]
        return None

    def load(self, date_keys):
        totals = {}
        for dk in date_keys:
            log = self._backend._data["dailyLogs"].get(dk, {})
            for proj, info in log.items():
                totals[proj] = totals.get(proj, 0) + info["seconds"]
        # Include active session time if today is in the range
        today = date.today().isoformat()
        if today in date_keys and self._backend._active_project and self._backend._session_start:
            proj = self._backend._active_project
            totals[proj] = totals.get(proj, 0) + int(time.time() - self._backend._session_start)
        self.beginResetModel()
        self._items = sorted(
            [{"project": p, "seconds": s} for p, s in totals.items()],
            key=lambda x: x["seconds"], reverse=True,
        )
        self.endResetModel()

    @property
    def total_seconds(self):
        return sum(i["seconds"] for i in self._items)


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
    reportPeriodChanged = Signal()
    reportLabelChanged = Signal()
    reportTotalChanged = Signal()
    reportTotalSecondsChanged = Signal()
    exportDone = Signal(str, bool)  # (message, success)
    summaryChanged = Signal()
    jsonTransferDone = Signal(str, bool)  # (message, success)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._data = load_data()
        self._active_project = None
        self._session_start = None
        self._elapsed = 0
        self._last_checkin = None
        self._checkin_shown_at = None
        self._eod_dismissed = False

        self.INACTIVITY_TIMEOUT = 30 * 60  # seconds before auto-stopping if no check-in response

        self._project_model = ProjectListModel(self)
        self._history_model = HistoryListModel(self)
        self._day_detail_model = DayDetailModel(self)
        self._eod_model = EodModel(self)
        self._report_model = ReportModel(self)
        self._report_period = "day"
        self._report_offset = 0

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

    @Property(QObject, constant=True)
    def reportModel(self):
        return self._report_model

    @Property(str, notify=reportPeriodChanged)
    def reportPeriod(self):
        return self._report_period

    @Property(str, notify=reportLabelChanged)
    def reportLabel(self):
        return self._get_report_label()

    @Property(str, notify=reportTotalChanged)
    def reportTotal(self):
        return fmt_time(self._report_model.total_seconds)

    @Property(int, notify=reportTotalSecondsChanged)
    def reportTotalSeconds(self):
        return self._report_model.total_seconds

    @Property(int, constant=True)
    def inactivityTimeoutSecs(self):
        return self.INACTIVITY_TIMEOUT

    @Property(str, notify=summaryChanged)
    def todayTotal(self):
        today = date.today().isoformat()
        secs = sum(v["seconds"] for v in self._data["dailyLogs"].get(today, {}).values())
        if self._active_project and self._session_start:
            secs += int(time.time() - self._session_start)
        return fmt_time(secs) if secs > 0 else "0m"

    @Property(str, notify=summaryChanged)
    def weekTotal(self):
        today = date.today()
        monday = today - timedelta(days=today.weekday())
        secs = 0
        for i in range(7):
            dk = (monday + timedelta(days=i)).isoformat()
            secs += sum(v["seconds"] for v in self._data["dailyLogs"].get(dk, {}).values())
        if self._active_project and self._session_start:
            secs += int(time.time() - self._session_start)
        return fmt_time(secs) if secs > 0 else "0m"

    @Property(str, notify=summaryChanged)
    def monthTotal(self):
        today = date.today()
        days_in_month = calendar.monthrange(today.year, today.month)[1]
        secs = 0
        for d in range(1, days_in_month + 1):
            dk = date(today.year, today.month, d).isoformat()
            secs += sum(v["seconds"] for v in self._data["dailyLogs"].get(dk, {}).values())
        if self._active_project and self._session_start:
            secs += int(time.time() - self._session_start)
        return fmt_time(secs) if secs > 0 else "0m"

    # ── Slots ──

    @Slot(str, str, bool)
    def addProject(self, name: str, billing_code: str, billable: bool):
        name = name.strip()
        if not name:
            return
        existing = [_proj_name(p) for p in self._data["projects"]]
        if name in existing:
            return
        self._data["projects"].append({
            "name": name,
            "billingCode": billing_code.strip(),
            "billable": billable,
        })
        save_data(self._data)
        self._project_model.refresh()

    @Slot(str)
    def removeProject(self, name):
        if self._active_project == name:
            self.stopTimer()
        self._data["projects"] = [
            p for p in self._data["projects"] if _proj_name(p) != name
        ]
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
        self._history_model.refresh()

    @Slot()
    def stopTimer(self):
        if self._active_project and self._session_start:
            self._log_time(int(time.time() - self._session_start))
        self._active_project = None
        self._session_start = None
        self._elapsed = 0
        self._last_checkin = None
        self._checkin_shown_at = None
        self.activeProjectChanged.emit()
        self.elapsedChanged.emit()
        self.elapsedTextChanged.emit()
        self.summaryChanged.emit()
        self._project_model.refresh()
        self._history_model.refresh()
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
        self._checkin_shown_at = None

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

    @Slot(str, result="QVariantList")
    def getDayData(self, day_key: str):
        log = self._data["dailyLogs"].get(day_key, {})
        return [
            {
                "project": proj,
                "seconds": info["seconds"],
                "sessions": info.get("sessions", []),
                "description": info.get("description", ""),
            }
            for proj, info in log.items()
        ]

    @Slot(str, str, str)
    def saveDaySessions(self, day_key: str, project: str, sessions_json: str):
        import json as _json
        sessions = _json.loads(sessions_json)
        logs = self._data["dailyLogs"]
        if day_key not in logs or project not in logs[day_key]:
            return
        logs[day_key][project]["sessions"] = sessions
        logs[day_key][project]["seconds"] = sum(
            (s["end"] - s["start"]) * 60 for s in sessions
        )
        save_data(self._data)
        self._history_model.refresh()
        self._day_detail_model.load_day(day_key)
        if day_key == date.today().isoformat():
            self._project_model.refresh()
            self.hasTodayLogsChanged.emit()

    @Slot(str, str, str)
    def saveProjectDescription(self, day_key: str, project: str, description: str):
        logs = self._data["dailyLogs"]
        if day_key not in logs or project not in logs[day_key]:
            return
        logs[day_key][project]["description"] = description
        save_data(self._data)
        self._day_detail_model.load_day(day_key)

    @Slot()
    def refreshModels(self):
        self._project_model.refresh()
        self._history_model.refresh()
        self.hasTodayLogsChanged.emit()

    @Slot(str)
    def setReportPeriod(self, period):
        self._report_period = period
        self._report_offset = 0
        self._load_report()
        self.reportPeriodChanged.emit()

    @Slot()
    def reportPrev(self):
        self._report_offset -= 1
        self._load_report()

    @Slot()
    def reportNext(self):
        if self._report_offset < 0:
            self._report_offset += 1
            self._load_report()

    @Slot()
    def refreshReport(self):
        self._load_report()

    @Slot(str, str)
    def exportMonthlyReport(self, year_month, file_path):
        """Export a monthly report to an Excel file.

        Args:
            year_month: "YYYY-MM" string
            file_path:  Absolute path (may start with "file://")
        """
        try:
            # Normalise file:// URI from QML FileDialog
            if file_path.startswith("file://"):
                file_path = file_path[7:]
            if not file_path.endswith(".xlsx"):
                file_path += ".xlsx"

            year, month = int(year_month[:4]), int(year_month[5:7])
            month_name = datetime(year, month, 1).strftime("%B %Y")
            days_in_month = calendar.monthrange(year, month)[1]

            # Collect (date, project, hours, description) rows
            rows = []
            total_hours = 0.0
            for d in range(1, days_in_month + 1):
                day_key = f"{year}-{month:02d}-{d:02d}"
                log = self._data["dailyLogs"].get(day_key, {})
                for proj, info in sorted(log.items()):
                    secs = info.get("seconds", 0)
                    # Round to nearest 10 minutes, express as decimal hours
                    hours = round(secs / 600) * 10 / 60
                    desc = info.get("description", "")
                    date_label = datetime(year, month, d).strftime("%a, %b %d")
                    rows.append((date_label, proj, hours, desc))
                    total_hours += hours

            wb = openpyxl.Workbook()
            ws = wb.active
            ws.title = "Report"

            # ── Styles ───────────────────────────────────────────────
            dark = "1F2937"
            blue = "2563EB"
            header_fill = PatternFill("solid", fgColor=dark)
            alt_fill    = PatternFill("solid", fgColor="F9FAFB")
            total_fill  = PatternFill("solid", fgColor="EEF4FF")

            header_font = Font(bold=True, color="FFFFFF", size=11)
            title_font  = Font(bold=True, color=dark, size=14)
            total_font  = Font(bold=True, color=dark, size=11)
            total_lbl_font = Font(bold=True, color=blue, size=11)

            thin = Side(style="thin", color="E5E7EB")
            cell_border = Border(left=thin, right=thin, top=thin, bottom=thin)

            center = Alignment(horizontal="center", vertical="center")
            left   = Alignment(horizontal="left",   vertical="center", wrap_text=True)
            right  = Alignment(horizontal="right",  vertical="center")

            # ── Title row ────────────────────────────────────────────
            ws.merge_cells("A1:D1")
            title_cell = ws["A1"]
            title_cell.value = f"Monthly Report — {month_name}"
            title_cell.font = title_font
            title_cell.alignment = left
            ws.row_dimensions[1].height = 28

            ws.append([])  # blank row 2

            # ── Header row ───────────────────────────────────────────
            headers = ["Date", "Project", "Hours", "Description"]
            ws.append(headers)
            for col, _ in enumerate(headers, start=1):
                cell = ws.cell(row=3, column=col)
                cell.font = header_font
                cell.fill = header_fill
                cell.alignment = center
                cell.border = cell_border
            ws.row_dimensions[3].height = 22

            # ── Data rows ────────────────────────────────────────────
            for i, (date_lbl, proj, hrs, desc) in enumerate(rows):
                row_num = i + 4
                fill = alt_fill if i % 2 == 1 else None
                values = [date_lbl, proj, hrs, desc]
                aligns = [center, left, right, left]
                ws.append(values)
                for col, (val, aln) in enumerate(zip(values, aligns), start=1):
                    cell = ws.cell(row=row_num, column=col)
                    cell.alignment = aln
                    cell.border = cell_border
                    if fill:
                        cell.fill = fill
                    if col == 3:  # Hours column — format as number
                        cell.number_format = "0.00"
                ws.row_dimensions[row_num].height = 18

            # ── Total row ────────────────────────────────────────────
            if rows:
                ws.append([])
                total_row = len(rows) + 5
                ws.cell(total_row, 1).value = "Total"
                ws.cell(total_row, 1).font = total_lbl_font
                ws.cell(total_row, 1).fill = total_fill
                ws.cell(total_row, 1).alignment = center
                ws.cell(total_row, 1).border = cell_border
                ws.cell(total_row, 2).fill = total_fill
                ws.cell(total_row, 2).border = cell_border
                ws.cell(total_row, 3).value = total_hours
                ws.cell(total_row, 3).font = total_font
                ws.cell(total_row, 3).fill = total_fill
                ws.cell(total_row, 3).alignment = right
                ws.cell(total_row, 3).border = cell_border
                ws.cell(total_row, 3).number_format = "0.00"
                ws.cell(total_row, 4).fill = total_fill
                ws.cell(total_row, 4).border = cell_border
                ws.row_dimensions[total_row].height = 22

            # ── Column widths ─────────────────────────────────────────
            ws.column_dimensions["A"].width = 16
            ws.column_dimensions["B"].width = 28
            ws.column_dimensions["C"].width = 10
            ws.column_dimensions["D"].width = 52

            # Freeze panes below header
            ws.freeze_panes = "A4"

            wb.save(file_path)
            self.exportDone.emit(f"Exported to {os.path.basename(file_path)}", True)

        except Exception as e:
            self.exportDone.emit(f"Export failed: {e}", False)

    @Slot(str)
    def exportJson(self, file_path: str):
        try:
            if file_path.startswith("file:///"):
                file_path = file_path[8:]  # Windows: strip file:/// → C:/...
            elif file_path.startswith("file://"):
                file_path = file_path[7:]  # Unix: strip file:// → /home/...
            if not file_path.endswith(".json"):
                file_path += ".json"
            with open(file_path, "w") as f:
                json.dump(self._data, f, indent=2)
            self.jsonTransferDone.emit(f"Exported to {os.path.basename(file_path)}", True)
        except Exception as e:
            self.jsonTransferDone.emit(f"Export failed: {e}", False)

    @Slot(str)
    def importJson(self, file_path: str):
        try:
            if file_path.startswith("file:///"):
                file_path = file_path[8:]
            elif file_path.startswith("file://"):
                file_path = file_path[7:]
            with open(file_path, "r") as f:
                new_data = json.load(f)
            if "dailyLogs" not in new_data:
                self.jsonTransferDone.emit("Import failed: not a valid tracker data file", False)
                return
            # Migrate legacy string-format projects
            new_data["projects"] = [
                p if isinstance(p, dict)
                else {"name": p, "billingCode": "", "billable": True}
                for p in new_data.get("projects", [])
            ]
            self._data = new_data
            save_data(self._data)
            self._project_model.refresh()
            self._history_model.refresh()
            self.hasTodayLogsChanged.emit()
            self.summaryChanged.emit()
            self.jsonTransferDone.emit(f"Imported {os.path.basename(file_path)}", True)
        except Exception as e:
            self.jsonTransferDone.emit(f"Import failed: {e}", False)

    # ── Internal ──

    def _log_time(self, secs):
        if not self._active_project or secs <= 0:
            return
        session_start_ts = self._session_start if self._session_start else (time.time() - secs)
        start_dt = datetime.fromtimestamp(session_start_ts)
        end_dt = datetime.fromtimestamp(session_start_ts + secs)

        start_min = start_dt.hour * 60 + start_dt.minute
        # Clamp to same calendar day
        if end_dt.date() != start_dt.date():
            end_min = 23 * 60 + 59
        else:
            end_min = end_dt.hour * 60 + end_dt.minute

        day_key = start_dt.date().isoformat()
        if day_key not in self._data["dailyLogs"]:
            self._data["dailyLogs"][day_key] = {}
        if self._active_project not in self._data["dailyLogs"][day_key]:
            self._data["dailyLogs"][day_key][self._active_project] = {
                "seconds": 0,
                "sessions": [],
                "description": "",
            }
        entry = self._data["dailyLogs"][day_key][self._active_project]
        if "sessions" not in entry:
            entry["sessions"] = []
        entry["sessions"].append({"start": start_min, "end": end_min})
        entry["seconds"] = sum((s["end"] - s["start"]) * 60 for s in entry["sessions"])
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
            self.summaryChanged.emit()
            # Refresh models to update "today" times for active project
            self._project_model.refresh()
            self._history_model.refresh()

        # Check-in
        if self._active_project and self._last_checkin:
            # Auto-stop if the check-in dialog has been unanswered for too long
            if self._checkin_shown_at and time.time() - self._checkin_shown_at >= self.INACTIVITY_TIMEOUT:
                self.stopTimer()
                return
            if time.time() - self._last_checkin >= self._data["checkInInterval"] * 60:
                self._last_checkin = time.time()
                self._checkin_shown_at = time.time()
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

    def _get_report_date_keys(self):
        today = date.today()
        if self._report_period == "day":
            target = today + timedelta(days=self._report_offset)
            return [target.isoformat()]
        elif self._report_period == "week":
            start = today - timedelta(days=today.weekday()) + timedelta(weeks=self._report_offset)
            return [(start + timedelta(days=i)).isoformat() for i in range(7)]
        elif self._report_period == "month":
            month = today.month + self._report_offset
            year = today.year
            while month <= 0:
                month += 12
                year -= 1
            while month > 12:
                month -= 12
                year += 1
            days_in_month = calendar.monthrange(year, month)[1]
            return [date(year, month, d + 1).isoformat() for d in range(days_in_month)]
        return []

    def _get_report_label(self):
        today = date.today()
        if self._report_period == "day":
            target = today + timedelta(days=self._report_offset)
            if self._report_offset == 0:
                return "Today"
            elif self._report_offset == -1:
                return "Yesterday"
            return target.strftime("%a, %b %d, %Y")
        elif self._report_period == "week":
            start = today - timedelta(days=today.weekday()) + timedelta(weeks=self._report_offset)
            end = start + timedelta(days=6)
            if self._report_offset == 0:
                return f"This Week ({start.strftime('%b %d')} \u2013 {end.strftime('%b %d')})"
            return f"{start.strftime('%b %d')} \u2013 {end.strftime('%b %d, %Y')}"
        elif self._report_period == "month":
            month = today.month + self._report_offset
            year = today.year
            while month <= 0:
                month += 12
                year -= 1
            while month > 12:
                month -= 12
                year += 1
            target = date(year, month, 1)
            if self._report_offset == 0:
                return f"This Month ({target.strftime('%B %Y')})"
            return target.strftime("%B %Y")
        return ""

    def _load_report(self):
        keys = self._get_report_date_keys()
        self._report_model.load(keys)
        self.reportLabelChanged.emit()
        self.reportTotalChanged.emit()
        self.reportTotalSecondsChanged.emit()
