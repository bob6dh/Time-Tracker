"""History day editor (TimeEditView.qml): session-block helpers, backend
cleanup, and real mouse interaction against the rendered editor.

Regressions covered: the × on short blocks was covered by the resize handles
(couldn't delete), clicks inside a block created a new block on top of it,
and dragging/resizing could create overlapping blocks of the same project.
"""
import json
import os

import pytest
from PySide6.QtCore import QPoint, QPointF, QUrl, Qt, qInstallMessageHandler
from PySide6.QtGui import QWindow
from PySide6.QtQml import QJSEngine, QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest

import backend as backend_mod

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DAY = "2026-11-02"


def _find(item, name):
    """Visual-tree search: Repeater delegates are childItems, not QObject children."""
    out = []
    for child in item.childItems():
        if child.objectName() == name:
            out.append(child)
        out.extend(_find(child, name))
    return out


# ── SessionUtils.js (pure helpers) ────────────────────────────────────

@pytest.fixture(scope="module")
def su(qapp):
    src = open(os.path.join(ROOT, "qml", "SessionUtils.js"), encoding="utf-8").read()
    src = src.replace(".pragma library", "", 1)
    js = QJSEngine()
    js.evaluate(src)

    def call(fn, *args):
        val = js.evaluate(f"JSON.stringify({fn}(...{json.dumps(list(args))}))")
        assert not val.isError(), val.toString()
        return json.loads(val.toString())

    call.engine = js  # keep alive
    return call


def test_normalize_merges_overlaps_keeps_adjacent(su):
    out = su("normalize", [
        {"start": 600, "end": 660, "task": ""},
        {"start": 540, "end": 615, "task": "t1"},   # overlaps the first
        {"start": 660, "end": 690, "task": "t2"},   # adjacent: stays separate
        {"start": 700, "end": 700, "task": ""},     # zero-length: dropped
    ])
    assert out == [
        {"start": 540, "end": 660, "task": "t1"},
        {"start": 660, "end": 690, "task": "t2"},
    ]


def test_free_gap(su):
    sessions = [{"start": 60, "end": 120}, {"start": 180, "end": 240}]
    assert su("freeGap", sessions, 150, 0, 1440) == {"lo": 120, "hi": 180}
    assert su("freeGap", sessions, 10, 0, 1440) == {"lo": 0, "hi": 60}
    assert su("freeGap", sessions, 300, 0, 1440) == {"lo": 240, "hi": 1440}
    assert su("freeGap", sessions, 90, 0, 1440) is None      # inside a block
    assert su("freeGap", sessions, 60, 0, 1440) is None      # on a block's start


def test_resize_bounds(su):
    others = [{"start": 60, "end": 120}, {"start": 300, "end": 360}]
    assert su("resizeBounds", others, 180, 240, 0, 1440) == {"lo": 120, "hi": 300}
    # Never tighter than the block itself, even if data already overlaps.
    b = su("resizeBounds", [{"start": 100, "end": 200}], 150, 180, 0, 1440)
    assert b["lo"] <= 150 and b["hi"] >= 180


# ── Backend ───────────────────────────────────────────────────────────

def test_save_day_sessions_merges_overlaps(be):
    be.addProject("Alpha", "", True)
    be.addProjectToDay(DAY, "Alpha")
    be.saveDaySessions(DAY, "Alpha", json.dumps([
        {"start": 60, "end": 120, "task": None},
        {"start": 90, "end": 150, "task": None},
    ]))
    entry = be._data["dailyLogs"][DAY]["Alpha"]
    assert entry["sessions"] == [{"start": 60, "end": 150, "task": None}]
    assert entry["seconds"] == 90 * 60  # not double-counted


def test_sub_minute_session_not_logged_as_zero_length_block(be):
    be.addProject("Alpha", "", True)
    be.addProject("Beta", "", True)
    be.startProject("Alpha")
    be.startProject("Beta")  # switch within the same minute
    be.stopTimer()
    for log in be._data["dailyLogs"].values():
        for info in log.values():
            assert all(s["end"] > s["start"] for s in info["sessions"])


# ── Real mouse interaction against the editor ─────────────────────────

@pytest.fixture
def editor(qapp, be):
    be.addProject("Alpha", "", True)
    be.addProjectToDay(DAY, "Alpha")
    # 1:00–1:15 (short, the old can't-delete case) and 2:00–3:00, near the
    # top of the grid so they're on screen without scrolling.
    be._data["dailyLogs"][DAY]["Alpha"]["sessions"] = [
        {"start": 60, "end": 75, "task": None},
        {"start": 120, "end": 180, "task": None},
    ]
    be._data["dailyLogs"][DAY]["Alpha"]["seconds"] = 75 * 60
    be._data["lastAppOpenDate"] = None

    messages = []
    old = qInstallMessageHandler(lambda m, c, s: messages.append(s))
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", be)
    engine.load(QUrl.fromLocalFile(os.path.join(ROOT, "qml", "Main.qml")))
    root = engine.rootObjects()[0]
    root.setProperty("height", 900)
    root.showWindow()
    root.setProperty("currentView", "history")
    root.setProperty("selectedDay", DAY)
    for _ in range(10):
        qapp.processEvents()

    class Ctx:
        pass
    ctx = Ctx()
    ctx.qapp, ctx.be, ctx.root, ctx.messages = qapp, be, root, messages
    ctx.view = _find(root.contentItem(), "timeEditView")[0]

    def blocks():
        items = [b for b in _find(ctx.view, "sessionBlock") if b.isVisible()]
        return sorted(((b.property("start"), b.property("end"), b) for b in items), key=lambda t: t[0])
    ctx.blocks = lambda: [(s, e) for s, e, _ in blocks()]
    ctx.block_item = lambda start: next(b for s, e, b in blocks() if s == start)

    def pos(item, x, y):
        p = item.mapToScene(QPointF(x, y))
        return QPoint(round(p.x()), round(p.y()))
    ctx.pos = pos

    def column():
        return next(c for c in _find(ctx.view, "sessionColumn") if c.isVisible())
    ctx.column = column

    def minute_y(minute):
        return minute * 44 / 60.0  # hourHeight 44, grid starts at midnight
    ctx.minute_y = minute_y

    def settle():
        for _ in range(5):
            qapp.processEvents()
    ctx.settle = settle

    def drag(p1, p2, steps=8):
        QTest.mousePress(root, Qt.LeftButton, Qt.NoModifier, p1)
        for i in range(1, steps + 1):
            QTest.mouseMove(root, QPoint(p1.x() + (p2.x() - p1.x()) * i // steps,
                                         p1.y() + (p2.y() - p1.y()) * i // steps))
            settle()
        QTest.mouseRelease(root, Qt.LeftButton, Qt.NoModifier, p2)
        settle()
    ctx.drag = drag

    yield ctx
    qInstallMessageHandler(old)
    root.hide()
    engine.deleteLater()


def test_editor_loaded(editor):
    assert editor.blocks() == [(60, 75), (120, 180)]


def test_delete_short_block(editor):
    blk = editor.block_item(60)
    delete = _find(blk, "sessionDelete")[0]
    # Click the centre of the × (the old bug: a resize handle sat on top of it).
    p = editor.pos(delete, delete.width() / 2 - 3, delete.height() / 2 - 3)
    QTest.mouseMove(editor.root, p)
    editor.settle()
    QTest.mouseClick(editor.root, Qt.LeftButton, Qt.NoModifier, p)
    editor.settle()
    assert editor.blocks() == [(120, 180)]


def test_click_inside_block_does_not_create_block(editor):
    blk = editor.block_item(120)
    p = editor.pos(blk, blk.width() / 3, blk.height() / 2)
    QTest.mouseClick(editor.root, Qt.LeftButton, Qt.NoModifier, p)
    editor.settle()
    editor.drag(p, QPoint(p.x(), p.y() + 30))  # dragging from inside a block too
    assert editor.blocks() == [(60, 75), (120, 180)]


def test_plain_click_in_empty_column_does_not_create_block(editor):
    col = editor.column()
    p = editor.pos(col, col.width() / 2, editor.minute_y(300))
    QTest.mouseClick(editor.root, Qt.LeftButton, Qt.NoModifier, p)
    editor.settle()
    assert editor.blocks() == [(60, 75), (120, 180)]


def test_drag_across_block_stops_at_it(editor):
    col = editor.column()
    # From 1:30 down past the 2:00–3:00 block to ~4:00.
    p1 = editor.pos(col, col.width() / 2, editor.minute_y(90))
    p2 = editor.pos(col, col.width() / 2, editor.minute_y(240))
    editor.drag(p1, p2)
    assert editor.blocks() == [(60, 75), (90, 120), (120, 180)]


def test_drag_in_empty_space_creates_block(editor):
    col = editor.column()
    p1 = editor.pos(col, col.width() / 2, editor.minute_y(300))
    p2 = editor.pos(col, col.width() / 2, editor.minute_y(360))
    editor.drag(p1, p2)
    assert (300, 360) in editor.blocks()


def test_resize_cannot_overlap_neighbour(editor):
    blk = editor.block_item(120)
    top = _find(blk, "sessionTopHandle")[0]
    p1 = editor.pos(top, top.width() / 2, top.height() / 2)
    p2 = QPoint(p1.x(), p1.y() - round(editor.minute_y(90)))  # try to pull start up to 0:30
    editor.drag(p1, p2)
    blocks = editor.blocks()
    assert blocks == [(60, 75), (75, 180)], blocks  # stops at the previous block's end


def test_save_persists_edits(editor):
    col = editor.column()
    editor.drag(editor.pos(col, col.width() / 2, editor.minute_y(300)),
                editor.pos(col, col.width() / 2, editor.minute_y(360)))
    editor.view.metaObject().invokeMethod(editor.view, "saveAll")
    editor.settle()
    sessions = editor.be._data["dailyLogs"][DAY]["Alpha"]["sessions"]
    assert [(s["start"], s["end"]) for s in sessions] == [(60, 75), (120, 180), (300, 360)]
    relevant = [m for m in editor.messages if "qml" in m.lower() and "propagateSizeHints" not in m]
    assert relevant == [], relevant
