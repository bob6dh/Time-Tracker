.pragma library
// Pure helpers for TimeEditView's per-project session blocks. All times are
// minutes since midnight; a session is {start, end, task}. Kept free of QML
// types so tests can evaluate this file in a plain QJSEngine.

// Sort, drop zero/negative-length sessions, and merge sessions that overlap
// (touching end-to-start is NOT an overlap — adjacent blocks stay separate,
// they often belong to different tasks). When merging, the earlier block's
// task tag wins, falling back to the later one's.
function normalize(sessions) {
    var list = []
    for (var i = 0; i < sessions.length; i++) {
        var s = sessions[i]
        if (s.end > s.start)
            list.push({ start: s.start, end: s.end, task: s.task || "" })
    }
    list.sort(function(a, b) { return a.start - b.start || a.end - b.end })
    var out = []
    for (var j = 0; j < list.length; j++) {
        var cur = list[j]
        var last = out.length ? out[out.length - 1] : null
        if (last && cur.start < last.end) {
            last.end = Math.max(last.end, cur.end)
            if (!last.task) last.task = cur.task
        } else {
            out.push(cur)
        }
    }
    return out
}

// The empty stretch of the column around `minute`: {lo, hi}, bounded by the
// neighbouring sessions and the day. Returns null when `minute` falls inside
// an existing session (so a press there must not start a new block).
function freeGap(sessions, minute, dayStart, dayEnd) {
    var lo = dayStart, hi = dayEnd
    for (var i = 0; i < sessions.length; i++) {
        var s = sessions[i]
        if (minute >= s.start && minute < s.end) return null
        if (s.end <= minute && s.end > lo) lo = s.end
        if (s.start > minute && s.start < hi) hi = s.start
    }
    return { lo: lo, hi: hi }
}

// How far a block [start, end) may be resized without running into the
// other sessions of the same project: {lo, hi}. Never tighter than the block
// itself, so pre-existing overlaps can't make a block un-resizable.
function resizeBounds(others, start, end, dayStart, dayEnd) {
    var lo = dayStart, hi = dayEnd
    for (var i = 0; i < others.length; i++) {
        var o = others[i]
        if (o.start < start && o.end > lo) lo = o.end
        if (o.start >= start && o.start < hi) hi = o.start
    }
    return { lo: Math.min(lo, start), hi: Math.max(hi, end) }
}
