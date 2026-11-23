"""Backend logic tests. Run with:  python -m pytest tests -q

All tests use a temp data dir (see conftest.py) — real data is never touched.
"""
import json
import time
from datetime import date, datetime, timedelta

import backend as backend_mod
from backend import TimeTrackerBackend


def _today_entry(b, project):
    return b._data["dailyLogs"].get(date.today().isoformat(), {}).get(project)


def _backdate(b, seconds):
    """Pretend the running session started `seconds` ago."""
    b._session_start -= seconds


# ── Projects ──────────────────────────────────────────────────────────

def test_add_archive_reinstate_project(be):
    be.addProject("Alpha", "A1", True)
    be.addProject("Alpha", "dup", False)  # duplicate ignored
    assert be.getProjectNames() == ["Alpha"]
    be.archiveProject("Alpha")
    assert be.getProjectNames() == []
    assert [p["name"] for p in be.getArchivedProjects()] == ["Alpha"]
    be.reinstateProject("Alpha")
    assert be.getProjectNames() == ["Alpha"]


# ── Timer ─────────────────────────────────────────────────────────────

def test_start_stop_logs_session(be):
    be.addProject("Alpha", "", True)
    be.startProject("Alpha")
    assert be.activeProject == "Alpha"
    _backdate(be, 30 * 60)
    be.stopTimer()
    assert be.activeProject == ""
    entry = _today_entry(be, "Alpha")
    assert entry is not None
    assert 29 * 60 <= entry["seconds"] <= 31 * 60
    assert "activeSession" not in be._data


def test_switching_projects_logs_previous(be):
    be.addProject("Alpha", "", True)
    be.addProject("Beta", "", True)
    be.startProject("Alpha")
    _backdate(be, 20 * 60)
    be.startProject("Beta")
    assert be.activeProject == "Beta"
    assert _today_entry(be, "Alpha")["seconds"] >= 19 * 60


def test_task_time_and_description_autofill(be):
    be.addProject("Alpha", "", True)
    be.addTask("Write proposal", "Alpha", "", 60)
    task_id = be._data["tasks"][0]["id"]
    be.startTask(task_id)
    assert be.activeTaskTitle == "Write proposal"
    _backdate(be, 15 * 60)
    be.stopTimer()
    entry = _today_entry(be, "Alpha")
    assert entry["sessions"][-1]["task"] == task_id
    assert "Write proposal" in entry["description"]
    assert be._task_seconds(task_id) >= 14 * 60


def test_idle_auto_stop_trims_idle_time(be, monkeypatch):
    be.addProject("Alpha", "", True)
    be.startProject("Alpha")
    _backdate(be, 40 * 60)
    monkeypatch.setattr(backend_mod, "_idle_seconds", lambda: 20 * 60)  # > 10 min default
    be._tick()
    assert be.activeProject == ""
    secs = _today_entry(be, "Alpha")["seconds"]
    assert 19 * 60 <= secs <= 21 * 60, secs


def test_check_in_unanswered_auto_stops(be):
    be.addProject("Alpha", "", True)
    shown = []
    be.showCheckIn.connect(lambda: shown.append(1))
    be.startProject("Alpha")
    be._last_checkin -= be._data["checkInInterval"] * 60 + 1
    be._tick()
    assert shown == [1]
    be._checkin_shown_at -= be.INACTIVITY_TIMEOUT + 1
    be._tick()
    assert be.activeProject == ""


def test_save_and_restore_session_no_double_count(be, data_dir):
    be.addProject("Alpha", "", True)
    be.startProject("Alpha")
    _backdate(be, 10 * 60)
    be.saveAndStop()
    logged = _today_entry(be, "Alpha")["seconds"]
    b2 = TimeTrackerBackend()
    b2._timer.stop()
    assert b2.activeProject == "Alpha"
    assert b2._elapsed < 60  # resumed from the save point, not from the original start
    assert _today_entry(b2, "Alpha")["seconds"] == logged


def test_restore_skips_archived_project(be):
    be.addProject("Alpha", "", True)
    be.startProject("Alpha")
    be.saveAndStop()
    be._data["projects"][0]["archived"] = True
    backend_mod.save_data(be._data)
    b2 = TimeTrackerBackend()
    b2._timer.stop()
    assert b2.activeProject == ""


# ── Day rollover (app lives in the tray, so it runs across midnight) ──

def test_session_across_midnight_is_split(be):
    be.addProject("Alpha", "", True)
    be.startProject("Alpha")
    today = date.today()
    midnight = datetime.combine(today, datetime.min.time()).timestamp()
    yesterday = (today - timedelta(days=1)).isoformat()
    be._session_start = midnight - 30 * 60  # started 23:30 yesterday
    be._current_day = yesterday
    be._tick()
    y_entry = be._data["dailyLogs"][yesterday]["Alpha"]
    assert y_entry["sessions"][-1] == {"start": 23 * 60 + 30, "end": 24 * 60, "task": None}
    assert y_entry["seconds"] == 30 * 60
    assert be._session_start == midnight
    assert be.activeProject == "Alpha"


def test_eod_prompt_rearms_on_new_day(be):
    be._eod_dismissed = True
    be._current_day = (date.today() - timedelta(days=1)).isoformat()
    be._tick()
    assert be._current_day == date.today().isoformat()
    # It may have re-fired immediately if it's after 6pm with undescribed time;
    # either way it must no longer be stuck on yesterday's dismissal.
    assert be._eod_dismissed is False or be._data["dailyLogs"].get(date.today().isoformat())


# ── Activity prompt ───────────────────────────────────────────────────

def _prompt_count(b):
    hits = []
    b.showActivityPrompt.connect(lambda: hits.append(1))
    return hits


def test_activity_prompt_fires_on_activity_when_idle_timer(be):
    be.addProject("Alpha", "", True)
    hits = _prompt_count(be)
    be._tick()
    be._tick()  # stays shown; not re-fired every second
    assert hits == [1]


def test_activity_prompt_not_shown_while_timer_running(be):
    be.addProject("Alpha", "", True)
    hits = _prompt_count(be)
    be.startProject("Alpha")
    be._tick()
    assert hits == []


def test_activity_prompt_waits_for_input(be, monkeypatch):
    be.addProject("Alpha", "", True)
    hits = _prompt_count(be)
    monkeypatch.setattr(backend_mod, "_idle_seconds", lambda: 120)
    be._tick()
    assert hits == []
    monkeypatch.setattr(backend_mod, "_idle_seconds", lambda: 0.5)
    be._tick()
    assert hits == [1]


def test_activity_prompt_needs_projects(be):
    hits = _prompt_count(be)
    be._tick()
    assert hits == []


def test_activity_prompt_dismiss_snoozes(be):
    be.addProject("Alpha", "", True)
    hits = _prompt_count(be)
    be._tick()
    be.dismissActivityPrompt()
    be._tick()
    assert hits == [1]
    be._prompt_snooze_until = time.time() - 1  # snooze elapsed
    be._tick()
    assert hits == [1, 1]


def test_manual_stop_snoozes_but_idle_stop_does_not(be, monkeypatch):
    be.addProject("Alpha", "", True)
    hits = _prompt_count(be)
    be.startProject("Alpha")
    be.stopTimer()
    be._tick()
    assert hits == []  # deliberate stop → quiet

    be._prompt_snooze_until = 0
    be.startProject("Alpha")
    _backdate(be, 30 * 60)
    monkeypatch.setattr(backend_mod, "_idle_seconds", lambda: 15 * 60)
    be._tick()  # idle auto-stop
    assert be.activeProject == ""
    monkeypatch.setattr(backend_mod, "_idle_seconds", lambda: 0)
    be._tick()  # user comes back → asked what they're working on
    assert hits == [1]


def test_activity_prompt_can_be_disabled(be):
    be.addProject("Alpha", "", True)
    hits = _prompt_count(be)
    be.setActivityPromptEnabled(False)
    be._tick()
    assert hits == []
    assert be.activityPromptEnabled is False


def test_activity_prompt_options(be):
    be.addProject("Old", "", True)
    be.addProject("Recent", "", False)
    be.addTask("Today task", "Old", "", 0)
    be._data["dailyLogs"]["2020-01-01"] = {"Old": {"seconds": 60, "sessions": [], "description": ""}}
    be._data["dailyLogs"][date.today().isoformat()] = {"Recent": {"seconds": 60, "sessions": [], "description": ""}}
    opts = be.getActivityPromptOptions()
    assert [p["name"] for p in opts["projects"]] == ["Recent", "Old"]
    assert opts["projects"][0]["billable"] is False
    assert [t["title"] for t in opts["tasks"]] == ["Today task"]


def test_picking_from_prompt_starts_timer(be):
    be.addProject("Alpha", "", True)
    be._tick()
    assert be._prompt_visible
    be.startProject("Alpha")
    assert be.activeProject == "Alpha"
    assert be._prompt_visible is False


# ── Persistence ───────────────────────────────────────────────────────

def test_corrupt_main_file_recovers_from_bak(be, data_dir):
    be.addProject("Alpha", "", True)
    be.addProject("Beta", "", True)  # second save → .bak holds Alpha
    (data_dir / "tracker_data.json").write_text("{not json", encoding="utf-8")
    data = backend_mod.load_data()
    assert [p["name"] for p in data["projects"]] == ["Alpha"]


def test_old_data_file_migrates(data_dir):
    (data_dir / "tracker_data.json").write_text(json.dumps({
        "projects": ["Legacy"], "checkInInterval": 30, "dailyLogs": {},
    }), encoding="utf-8")
    data = backend_mod.load_data()
    assert data["projects"][0] == {"name": "Legacy", "billingCode": "", "billable": True}
    assert data["tasks"] == []
    assert data["activityPrompt"] is True
    assert data["activityPromptSnooze"] == 15


def test_export_import_roundtrip(be, data_dir):
    be.addProject("Alpha", "", True)
    out = data_dir / "export.json"
    be.exportJson(str(out))
    be.addProject("Beta", "", True)
    be.importJson(str(out))
    assert be.getProjectNames() == ["Alpha"]


def test_excel_and_csv_export(be, data_dir):
    be.addProject("Alpha", "", True)
    be.startProject("Alpha")
    _backdate(be, 60 * 60)
    be.stopTimer()
    ym = date.today().strftime("%Y-%m")
    xlsx, csvf = data_dir / "r.xlsx", data_dir / "r.csv"
    be.exportMonthlyReport(ym, str(xlsx))
    be.exportMonthlyReportCsv(ym, str(csvf))
    assert xlsx.stat().st_size > 0
    assert "Alpha" in csvf.read_text(encoding="utf-8-sig")


def test_utilization(be):
    be.addProject("Bill", "", True)
    be.addProject("Admin", "", False)
    d = "2026-11-02"  # a Monday
    be._data["dailyLogs"][d] = {
        "Bill": {"seconds": 6 * 3600, "sessions": [], "description": ""},
        "Admin": {"seconds": 2 * 3600, "sessions": [], "description": ""},
    }
    r = be.calculateUtilization(d, d, 0.0, 0.0)
    assert r["rate1"] == 75.0 and r["rate2"] == 75.0
    assert "error" in be.calculateUtilization("2026-11-03", d, 0.0, 0.0)
