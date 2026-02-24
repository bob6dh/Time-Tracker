import tkinter as tk
from tkinter import messagebox
import json
import os
import time
from datetime import datetime, date

DATA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tracker_data.json")

# ── Colors ──────────────────────────────────────────────────────
BG = "#f5f5f5"
CARD_BG = "#ffffff"
CARD_ACTIVE = "#eef4ff"
TEXT = "#1f2937"
TEXT_LIGHT = "#6b7280"
TEXT_FAINT = "#adb5bd"
ACCENT = "#2563eb"
BTN_BG = "#1f2937"
BTN_FG = "#ffffff"
BTN_HOVER = "#374151"
DANGER = "#ef4444"
BORDER = "#e5e7eb"
BORDER_ACTIVE = "#93c5fd"

def load_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r") as f:
                return json.load(f)
        except:
            pass
    return {"projects": [], "checkInInterval": 30, "dailyLogs": {}}

def save_data(data):
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)

def fmt_time(seconds):
    h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
    if h > 0: return f"{h}h {m}m"
    if m > 0: return f"{m}m {s}s"
    return f"{s}s"

def fmt_date(d):
    try:
        return datetime.strptime(d, "%Y-%m-%d").strftime("%a, %b %d, %Y")
    except:
        return d


class App:
    def __init__(self, root):
        self.root = root
        self.root.title("Time Tracker")
        self.root.geometry("480x680")
        self.root.minsize(420, 550)
        self.root.configure(bg=BG)

        self.data = load_data()
        self.active_project = None
        self.session_start = None
        self.elapsed = 0
        self.last_checkin = None
        self.eod_dismissed = False
        self.view = "timer"
        self.selected_day = None

        # ── Header ──
        header = tk.Frame(root, bg=BG)
        header.pack(fill="x", padx=20, pady=(18, 0))
        tk.Label(header, text="Time Tracker", font=("Segoe UI", 20, "bold"),
                 bg=BG, fg=TEXT).pack(anchor="w")

        # ── Nav ──
        nav = tk.Frame(root, bg=BG)
        nav.pack(fill="x", padx=20, pady=(10, 6))
        self.nav_btns = {}
        for v in ("timer", "history", "settings"):
            b = tk.Label(nav, text=v.capitalize(), font=("Segoe UI", 11),
                         padx=14, pady=5, cursor="hand2")
            b.pack(side="left", padx=(0, 6))
            b.bind("<Button-1>", lambda e, x=v: self.switch_view(x))
            self.nav_btns[v] = b

        # ── Scrollable content ──
        container = tk.Frame(root, bg=BG)
        container.pack(fill="both", expand=True, padx=20, pady=(4, 18))

        self.canvas = tk.Canvas(container, bg=BG, highlightthickness=0)
        self.scrollbar = tk.Scrollbar(container, orient="vertical", command=self.canvas.yview)
        self.content = tk.Frame(self.canvas, bg=BG)

        self.content.bind("<Configure>", lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))
        self.canvas_window = self.canvas.create_window((0, 0), window=self.content, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.bind("<Configure>", lambda e: self.canvas.itemconfig(self.canvas_window, width=e.width))

        self.canvas.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")

        # Mouse wheel scroll
        self.canvas.bind_all("<MouseWheel>", lambda e: self.canvas.yview_scroll(-1 * (e.delta // 120), "units"))

        self.switch_view("timer")
        self.tick()

    # ── Helpers ─────────────────────────────────────────────────

    def switch_view(self, v):
        self.view = v
        self.selected_day = None
        for name, btn in self.nav_btns.items():
            if name == v:
                btn.configure(bg=BTN_BG, fg=BTN_FG)
            else:
                btn.configure(bg=CARD_BG, fg=TEXT_LIGHT)
        self.render()

    def clear(self):
        for w in self.content.winfo_children():
            w.destroy()

    def make_card(self, parent, active=False):
        f = tk.Frame(parent, bg=CARD_ACTIVE if active else CARD_BG,
                     highlightbackground=BORDER_ACTIVE if active else BORDER,
                     highlightthickness=1, padx=14, pady=12)
        f.pack(fill="x", pady=(0, 6))
        return f

    def make_btn(self, parent, text, command, bg=BTN_BG, fg=BTN_FG, width=None, danger=False):
        if danger:
            bg, fg = "#fff0f0", DANGER
        b = tk.Label(parent, text=text, font=("Segoe UI", 11), bg=bg, fg=fg,
                     padx=14, pady=6, cursor="hand2")
        if width:
            b.configure(width=width)
        b.bind("<Button-1>", lambda e: command())
        b.bind("<Enter>", lambda e: b.configure(bg=BTN_HOVER if not danger else "#fee2e2"))
        b.bind("<Leave>", lambda e: b.configure(bg=bg))
        return b

    # ── Render ──────────────────────────────────────────────────

    def render(self):
        self.clear()
        if self.view == "timer":
            self.render_timer()
        elif self.view == "history":
            if self.selected_day:
                self.render_day_detail()
            else:
                self.render_history()
        elif self.view == "settings":
            self.render_settings()

    # ── Timer View ──────────────────────────────────────────────

    def render_timer(self):
        p = self.content

        # Active timer
        if self.active_project:
            card = self.make_card(p, active=True)
            tk.Label(card, text="Currently tracking", font=("Segoe UI", 10),
                     bg=CARD_ACTIVE, fg=TEXT_LIGHT).pack(anchor="w")
            tk.Label(card, text=self.active_project, font=("Segoe UI", 16, "bold"),
                     bg=CARD_ACTIVE, fg=TEXT).pack(anchor="w", pady=(2, 0))
            self.timer_label = tk.Label(card, text=fmt_time(self.elapsed),
                                        font=("Consolas", 32), bg=CARD_ACTIVE, fg=TEXT)
            self.timer_label.pack(anchor="w", pady=(4, 10))
            stop_btn = self.make_btn(card, "Stop", self.stop_timer, bg=DANGER, fg="white")
            stop_btn.pack(fill="x")
            stop_btn.bind("<Enter>", lambda e: stop_btn.configure(bg="#dc2626"))
            stop_btn.bind("<Leave>", lambda e: stop_btn.configure(bg=DANGER))

        # Add project row
        add_frame = tk.Frame(p, bg=BG)
        add_frame.pack(fill="x", pady=(4, 10))
        self.entry = tk.Entry(add_frame, font=("Segoe UI", 12), relief="solid", bd=1,
                              bg=CARD_BG, fg=TEXT, insertbackground=TEXT)
        self.entry.pack(side="left", fill="x", expand=True, ipady=6, padx=(0, 8))
        self.entry.bind("<Return>", lambda e: self.add_project())
        self.make_btn(add_frame, "Add", self.add_project).pack(side="right")

        # Project list
        if not self.data["projects"]:
            tk.Label(p, text="Add a project to get started", font=("Segoe UI", 12),
                     bg=BG, fg=TEXT_FAINT).pack(pady=30)

        for proj in self.data["projects"]:
            is_active = self.active_project == proj
            card = self.make_card(p, active=is_active)
            bg = CARD_ACTIVE if is_active else CARD_BG

            left = tk.Frame(card, bg=bg)
            left.pack(side="left", fill="x", expand=True)
            tk.Label(left, text=proj, font=("Segoe UI", 13, "bold"),
                     bg=bg, fg=ACCENT if is_active else TEXT).pack(anchor="w")
            tk.Label(left, text=f"Today: {fmt_time(self.get_today_total(proj))}",
                     font=("Segoe UI", 10), bg=bg, fg=TEXT_LIGHT).pack(anchor="w")

            right = tk.Frame(card, bg=bg)
            right.pack(side="right")
            if is_active:
                tk.Label(right, text="Active", font=("Segoe UI", 10, "bold"),
                         bg="#dbeafe", fg=ACCENT, padx=8, pady=2).pack(side="left", padx=(0, 6))
            else:
                self.make_btn(right, "Start",
                              lambda x=proj: self.start_project(x)).pack(side="left", padx=(0, 6))

            x_btn = tk.Label(right, text="✕", font=("Segoe UI", 14), bg=bg, fg=TEXT_FAINT,
                             cursor="hand2", padx=4)
            x_btn.pack(side="left")
            x_btn.bind("<Button-1>", lambda e, x=proj: self.remove_project(x))
            x_btn.bind("<Enter>", lambda e, b=x_btn: b.configure(fg=DANGER))
            x_btn.bind("<Leave>", lambda e, b=x_btn, c=bg: b.configure(fg=TEXT_FAINT))

        # Daily summary button
        today = date.today().isoformat()
        if today in self.data["dailyLogs"] and self.data["dailyLogs"][today]:
            self.make_btn(p, "Write daily summary", self.open_eod,
                          bg=CARD_BG, fg=TEXT_LIGHT).pack(fill="x", pady=(8, 0))

    # ── History View ────────────────────────────────────────────

    def render_history(self):
        days = sorted(self.data["dailyLogs"].keys(), reverse=True)
        if not days:
            tk.Label(self.content, text="No history yet", font=("Segoe UI", 12),
                     bg=BG, fg=TEXT_FAINT).pack(pady=30)
            return
        for day in days:
            log = self.data["dailyLogs"][day]
            total = sum(v["seconds"] for v in log.values())
            count = len(log)
            card = self.make_card(self.content)
            card.configure(cursor="hand2")

            left = tk.Frame(card, bg=CARD_BG)
            left.pack(side="left")
            tk.Label(left, text=fmt_date(day), font=("Segoe UI", 13, "bold"),
                     bg=CARD_BG, fg=TEXT).pack(anchor="w")
            tk.Label(left, text=f"{count} project{'s' if count != 1 else ''}",
                     font=("Segoe UI", 10), bg=CARD_BG, fg=TEXT_LIGHT).pack(anchor="w")
            tk.Label(card, text=fmt_time(total), font=("Consolas", 12),
                     bg=CARD_BG, fg=TEXT_LIGHT).pack(side="right")

            for widget in [card] + card.winfo_children():
                widget.bind("<Button-1>", lambda e, d=day: self.open_day(d))
                for child in widget.winfo_children():
                    child.bind("<Button-1>", lambda e, d=day: self.open_day(d))

    def open_day(self, day):
        self.selected_day = day
        self.render()

    def render_day_detail(self):
        log = self.data["dailyLogs"].get(self.selected_day, {})
        back = tk.Label(self.content, text="← Back", font=("Segoe UI", 11),
                        bg=BG, fg=TEXT_LIGHT, cursor="hand2")
        back.pack(anchor="w", pady=(0, 8))
        back.bind("<Button-1>", lambda e: self.switch_view("history"))

        tk.Label(self.content, text=fmt_date(self.selected_day),
                 font=("Segoe UI", 16, "bold"), bg=BG, fg=TEXT).pack(anchor="w", pady=(0, 10))

        for proj, info in log.items():
            card = self.make_card(self.content)
            top = tk.Frame(card, bg=CARD_BG)
            top.pack(fill="x")
            tk.Label(top, text=proj, font=("Segoe UI", 13, "bold"),
                     bg=CARD_BG, fg=TEXT).pack(side="left")
            tk.Label(top, text=fmt_time(info["seconds"]), font=("Consolas", 12),
                     bg=CARD_BG, fg=TEXT_LIGHT).pack(side="right")
            if info.get("description"):
                tk.Label(card, text=info["description"], font=("Segoe UI", 11),
                         bg=CARD_BG, fg=TEXT_LIGHT, wraplength=360, justify="left").pack(anchor="w", pady=(6, 0))
            else:
                tk.Label(card, text="No summary", font=("Segoe UI", 10),
                         bg=CARD_BG, fg=TEXT_FAINT).pack(anchor="w", pady=(4, 0))

    # ── Settings View ───────────────────────────────────────────

    def render_settings(self):
        p = self.content
        tk.Label(p, text="Check-in Interval", font=("Segoe UI", 16, "bold"),
                 bg=BG, fg=TEXT).pack(anchor="w", pady=(0, 4))
        tk.Label(p, text="How often should we check if you're\nstill on the same project?",
                 font=("Segoe UI", 11), bg=BG, fg=TEXT_LIGHT, justify="left").pack(anchor="w", pady=(0, 12))

        row = tk.Frame(p, bg=BG)
        row.pack(fill="x", pady=(0, 24))
        for m in (15, 30, 60):
            label = "1 hour" if m == 60 else f"{m} min"
            is_sel = self.data["checkInInterval"] == m
            b = tk.Label(row, text=label, font=("Segoe UI", 12),
                         bg=BTN_BG if is_sel else CARD_BG,
                         fg=BTN_FG if is_sel else TEXT_LIGHT,
                         padx=10, pady=8, cursor="hand2", width=8)
            b.pack(side="left", padx=(0, 8))
            b.bind("<Button-1>", lambda e, x=m: self.set_interval(x))

        tk.Label(p, text="Data", font=("Segoe UI", 16, "bold"),
                 bg=BG, fg=TEXT).pack(anchor="w", pady=(0, 8))
        self.make_btn(p, "Clear all history", self.clear_history, danger=True).pack(anchor="w")

    def set_interval(self, m):
        self.data["checkInInterval"] = m
        save_data(self.data)
        self.render()

    def clear_history(self):
        if messagebox.askyesno("Clear History", "Clear all history? This cannot be undone."):
            self.data["dailyLogs"] = {}
            save_data(self.data)
            self.render()

    # ── Project Actions ─────────────────────────────────────────

    def add_project(self):
        name = self.entry.get().strip()
        if not name or name in self.data["projects"]:
            return
        self.data["projects"].append(name)
        save_data(self.data)
        self.render()

    def remove_project(self, name):
        if self.active_project == name:
            self.stop_timer()
        self.data["projects"] = [p for p in self.data["projects"] if p != name]
        save_data(self.data)
        self.render()

    def start_project(self, name):
        if self.active_project and self.session_start:
            self.log_time(int(time.time() - self.session_start))
        self.active_project = name
        self.session_start = time.time()
        self.last_checkin = time.time()
        self.elapsed = 0
        self.render()

    def stop_timer(self):
        if self.active_project and self.session_start:
            self.log_time(int(time.time() - self.session_start))
        self.active_project = None
        self.session_start = None
        self.elapsed = 0
        self.last_checkin = None
        self.render()

    def log_time(self, secs):
        if not self.active_project or secs <= 0:
            return
        today = date.today().isoformat()
        if today not in self.data["dailyLogs"]:
            self.data["dailyLogs"][today] = {}
        if self.active_project not in self.data["dailyLogs"][today]:
            self.data["dailyLogs"][today][self.active_project] = {"seconds": 0, "description": ""}
        self.data["dailyLogs"][today][self.active_project]["seconds"] += secs
        save_data(self.data)

    def get_today_total(self, proj):
        today = date.today().isoformat()
        base = self.data.get("dailyLogs", {}).get(today, {}).get(proj, {}).get("seconds", 0)
        if self.active_project == proj and self.session_start:
            base += int(time.time() - self.session_start)
        return base

    # ── Check-in Dialog ─────────────────────────────────────────

    def show_checkin(self):
        d = tk.Toplevel(self.root)
        d.title("Check In")
        d.geometry("340x160")
        d.resizable(False, False)
        d.grab_set()
        d.attributes("-topmost", True)
        d.configure(bg=CARD_BG)
        d.after(100, d.focus_force)

        f = tk.Frame(d, bg=CARD_BG, padx=24, pady=18)
        f.pack(fill="both", expand=True)
        tk.Label(f, text="Still working on", font=("Segoe UI", 14, "bold"),
                 bg=CARD_BG, fg=TEXT).pack(anchor="w")
        tk.Label(f, text=f"{self.active_project}?", font=("Segoe UI", 18, "bold"),
                 bg=CARD_BG, fg=ACCENT).pack(anchor="w", pady=(4, 14))

        btns = tk.Frame(f, bg=CARD_BG)
        btns.pack(fill="x")

        def yes():
            self.last_checkin = time.time()
            d.destroy()
        def no():
            d.destroy()
            self.stop_timer()

        self.make_btn(btns, "Yes, continue", yes).pack(side="left", fill="x", expand=True, padx=(0, 4))
        self.make_btn(btns, "No, stop", no, bg=CARD_BG, fg=TEXT_LIGHT).pack(side="right", fill="x", expand=True, padx=(4, 0))

    # ── EOD Summary Dialog ──────────────────────────────────────

    def open_eod(self):
        today = date.today().isoformat()
        log = self.data["dailyLogs"].get(today, {})
        if not log:
            return

        d = tk.Toplevel(self.root)
        d.title("End of Day Summary")
        d.geometry("400x" + str(min(180 + len(log) * 85, 520)))
        d.resizable(False, True)
        d.grab_set()
        d.attributes("-topmost", True)
        d.configure(bg=CARD_BG)
        d.after(100, d.focus_force)

        f = tk.Frame(d, bg=CARD_BG, padx=20, pady=16)
        f.pack(fill="both", expand=True)
        tk.Label(f, text="End of Day Summary", font=("Segoe UI", 14, "bold"),
                 bg=CARD_BG, fg=TEXT).pack(anchor="w")
        tk.Label(f, text="What did you work on today?", font=("Segoe UI", 11),
                 bg=CARD_BG, fg=TEXT_LIGHT).pack(anchor="w", pady=(2, 10))

        entries = {}
        for proj, info in log.items():
            tk.Label(f, text=proj, font=("Segoe UI", 11, "bold"),
                     bg=CARD_BG, fg=TEXT).pack(anchor="w", pady=(4, 2))
            tb = tk.Text(f, height=2, font=("Segoe UI", 11), relief="solid", bd=1,
                         bg=BG, fg=TEXT, wrap="word", insertbackground=TEXT)
            tb.pack(fill="x", pady=(0, 6))
            if info.get("description"):
                tb.insert("1.0", info["description"])
            entries[proj] = tb

        btns = tk.Frame(f, bg=CARD_BG)
        btns.pack(fill="x", pady=(8, 0))

        def save():
            for proj, tb in entries.items():
                desc = tb.get("1.0", "end-1c").strip()
                if today in self.data["dailyLogs"] and proj in self.data["dailyLogs"][today]:
                    self.data["dailyLogs"][today][proj]["description"] = desc
            save_data(self.data)
            self.eod_dismissed = True
            d.destroy()

        def later():
            self.eod_dismissed = True
            d.destroy()

        self.make_btn(btns, "Save", save).pack(side="left", fill="x", expand=True, padx=(0, 4))
        self.make_btn(btns, "Later", later, bg=CARD_BG, fg=TEXT_LIGHT).pack(side="right", fill="x", expand=True, padx=(4, 0))

    # ── Tick Loop ───────────────────────────────────────────────

    def tick(self):
        if self.active_project and self.session_start:
            self.elapsed = int(time.time() - self.session_start)
            if hasattr(self, "timer_label") and self.timer_label.winfo_exists():
                self.timer_label.configure(text=fmt_time(self.elapsed))

        if self.active_project and self.last_checkin:
            if time.time() - self.last_checkin >= self.data["checkInInterval"] * 60:
                self.last_checkin = time.time()
                self.show_checkin()

        if not self.eod_dismissed:
            now = datetime.now()
            today = date.today().isoformat()
            log = self.data.get("dailyLogs", {}).get(today, {})
            if now.hour >= 18 and log:
                has_time = any(v["seconds"] > 0 for v in log.values())
                all_descs = all(v.get("description") for v in log.values())
                if has_time and not all_descs:
                    self.eod_dismissed = True
                    self.open_eod()

        self.root.after(1000, self.tick)


if __name__ == "__main__":
    root = tk.Tk()
    app = App(root)
    root.mainloop()
