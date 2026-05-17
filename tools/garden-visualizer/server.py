#!/usr/bin/env python3
"""Garden Visualizer — lightweight web dashboard for garden activity.

Serves four views (dashboard, timeline, state, bulletin) plus SSE for
live updates. Python stdlib only — no pip install required.

Usage:
  python3 server.py --garden-root /path/to/garden [--port 2804] [--host 0.0.0.0]
"""

import argparse
import html
import http.server
import json
import os
import queue
import re
import subprocess
import threading
import time
from datetime import datetime, timezone

# ── Constants ──────────────────────────────────────────────────────────

DEFAULT_PORT = 2804
DEFAULT_HOST = "0.0.0.0"
POLL_JOURNAL_SECS = 10
POLL_FILESYSTEM_SECS = 5
POLL_GITHUB_SECS = 60
MAX_ENTRIES = 500

# ── Markdown Renderer ──────────────────────────────────────────────────


class MarkdownRenderer:
    """Stdlib-only Markdown→HTML renderer for garden journal prose.

    Handles the subset actually used in journal entries: headings (##–####),
    unordered/ordered lists, fenced code blocks, inline code, links, bold,
    horizontal rules.  Strips YAML frontmatter.  HTML-escapes everything
    before inserting tags, so it is safe by construction.
    """

    _FRONTMATTER_RE = re.compile(r"^---\n.*?\n---\n", re.DOTALL | re.MULTILINE)
    _HEADING_RE = re.compile(r"^(#{2,4})\s+(.+)$")
    _UL_RE = re.compile(r"^(\s*)[-*]\s+(.+)$")
    _OL_RE = re.compile(r"^(\s*)\d+\.\s+(.+)$")
    _HR_RE = re.compile(r"^-{3,}$")
    _BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
    _CODE_RE = re.compile(r"`(.+?)`")
    _LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
    _CODE_FENCE_RE = re.compile(r"^```")

    def render(self, text):
        text = self._FRONTMATTER_RE.sub("", text)
        lines = text.split("\n")
        out = []
        in_code = False
        in_list = False
        list_tag = "ul"

        for line in lines:
            # Code-block fence
            if self._CODE_FENCE_RE.match(line.strip()):
                if in_code:
                    out.append("</code></pre>")
                    in_code = False
                else:
                    out.append("<pre><code>")
                    in_code = True
                continue

            if in_code:
                out.append(html.escape(line))
                continue

            stripped = line.strip()

            if not stripped:
                if in_list:
                    out.append(f"</{list_tag}>")
                    in_list = False
                continue

            # Horizontal rule
            if self._HR_RE.match(stripped):
                self._close_list(out, in_list, list_tag)
                in_list = False
                out.append("<hr>")
                continue

            # Heading
            m = self._HEADING_RE.match(line)
            if m:
                self._close_list(out, in_list, list_tag)
                in_list = False
                level = len(m.group(1))
                content = self._inline(html.escape(m.group(2)))
                out.append(f"<h{level}>{content}</h{level}>")
                continue

            # Unordered list
            m = self._UL_RE.match(line)
            if m:
                if not in_list:
                    out.append("<ul>")
                    in_list = True
                    list_tag = "ul"
                content = self._inline(html.escape(m.group(2)))
                out.append(f"<li>{content}</li>")
                continue

            # Ordered list
            m = self._OL_RE.match(line)
            if m:
                if not in_list:
                    out.append("<ol>")
                    in_list = True
                    list_tag = "ol"
                content = self._inline(html.escape(m.group(2)))
                out.append(f"<li>{content}</li>")
                continue

            # Paragraph
            if in_list:
                out.append(f"</{list_tag}>")
                in_list = False
            out.append(f"<p>{self._inline(html.escape(line))}</p>")

        if in_code:
            out.append("</code></pre>")
        if in_list:
            out.append(f"</{list_tag}>")
        return "\n".join(out)

    @staticmethod
    def _close_list(out, in_list, list_tag):
        if in_list:
            out.append(f"</{list_tag}>")

    @staticmethod
    def _inline(text):
        text = MarkdownRenderer._BOLD_RE.sub(r"<strong>\1</strong>", text)
        text = MarkdownRenderer._CODE_RE.sub(r"<code>\1</code>", text)
        text = MarkdownRenderer._LINK_RE.sub(r'<a href="\2">\1</a>', text)
        return text


# ── PubSub (for SSE) ───────────────────────────────────────────────────


class PubSub:
    """In-process publish / subscribe used to push live updates to SSE."""

    def __init__(self):
        self._lock = threading.Lock()
        self._subscribers = []

    def subscribe(self):
        q = queue.Queue(maxsize=1000)
        with self._lock:
            self._subscribers.append(q)
        return q

    def unsubscribe(self, q):
        with self._lock:
            if q in self._subscribers:
                self._subscribers.remove(q)

    def publish(self, event_type, data):
        msg = json.dumps({"type": event_type, "data": data})
        with self._lock:
            dead = []
            for q in self._subscribers:
                try:
                    q.put_nowait(msg)
                except queue.Full:
                    dead.append(q)
            for q in dead:
                self._subscribers.remove(q)


# ── Data Store ─────────────────────────────────────────────────────────


class GardenData:
    """Thread-safe store of all garden state the visualizer tracks."""

    def __init__(self):
        self._lock = threading.Lock()
        self.entries = []
        self.dispatch_roots = []
        self.monitors = []
        self.worktrees = []
        self.schedule = []
        self.bulletin = ""
        self.last_journal_ref = None

    # ── updaters ───────────────────────────────────────────────────────

    def update_entries(self, entries):
        with self._lock:
            self.entries = sorted(entries, key=lambda e: e["ts"], reverse=True)[:MAX_ENTRIES]

    def update_dispatch_roots(self, roots):
        with self._lock:
            self.dispatch_roots = roots

    def update_monitors(self, monitors):
        with self._lock:
            self.monitors = monitors

    def update_worktrees(self, worktrees):
        with self._lock:
            self.worktrees = worktrees

    def update_schedule(self, events):
        with self._lock:
            self.schedule = sorted(events, key=lambda e: e["trigger"])[:20]

    def update_bulletin(self, md):
        with self._lock:
            self.bulletin = md

    # ── snapshot ───────────────────────────────────────────────────────

    def get_snapshot(self):
        with self._lock:
            return {
                "entries": list(self.entries),
                "dispatch_roots": list(self.dispatch_roots),
                "monitors": list(self.monitors),
                "worktrees": list(self.worktrees),
                "schedule": list(self.schedule),
                "bulletin": self.bulletin,
            }


# ── Parsing helpers ────────────────────────────────────────────────────


def _parse_entry(filepath, content):
    """Parse a journal entry file into a dict."""
    lines = content.split("\n")
    frontmatter = {}
    in_fm = False
    in_body = False
    body_lines = []

    for line in lines:
        if line.strip() == "---" and not in_fm:
            in_fm = True
            continue
        if line.strip() == "---" and in_fm and not in_body:
            in_fm = False
            in_body = True
            continue
        if in_fm and ":" in line:
            key, _, val = line.partition(":")
            frontmatter[key.strip()] = val.strip()
        elif in_body:
            body_lines.append(line)

    preview = ""
    for line in body_lines:
        if line.strip() and not line.strip().startswith("#"):
            preview = line.strip()[:200]
            break

    stem = os.path.splitext(os.path.basename(filepath))[0]
    short_id = stem.split("-")[-1] if "-" in stem else stem

    return {
        "ts": frontmatter.get("ts", ""),
        "kind": frontmatter.get("kind", ""),
        "role": frontmatter.get("role", ""),
        "short_id": short_id,
        "body_preview": preview,
        "path": filepath,
    }


def _parse_worktree_file(filepath, content):
    """Parse a worktree index file from journal/worktrees/<host>/<name>.md."""
    data = {}
    for line in content.split("\n"):
        if ":" in line:
            k, _, v = line.partition(":")
            data[k.strip()] = v.strip()
    parts = filepath.split("/")
    host = parts[1] if len(parts) >= 3 else "?"
    name = os.path.splitext(parts[2])[0] if len(parts) >= 3 else filepath
    return {
        "host": host,
        "name": name,
        "role": data.get("role", "?"),
        "status": data.get("status", "?"),
        "heartbeat": data.get("heartbeat", ""),
        "repo": data.get("repo", ""),
    }


def _parse_schedule_event(filepath, content):
    """Parse a schedule event file."""
    frontmatter = {}
    in_fm = False
    for line in content.split("\n"):
        if line.strip() == "---" and not in_fm:
            in_fm = True
            continue
        if line.strip() == "---" and in_fm:
            break
        if in_fm and ":" in line:
            k, _, v = line.partition(":")
            frontmatter[k.strip()] = v.strip()

    dispatch_val = frontmatter.get("dispatch", "?")
    role = dispatch_val.strip('"').split()[0] if " " in dispatch_val else dispatch_val

    stem = os.path.splitext(os.path.basename(filepath))[0]
    parts = stem.split("--", 1)

    return {
        "trigger": frontmatter.get("trigger", parts[0] if parts else ""),
        "role": role,
        "purpose": frontmatter.get("purpose", "?"),
        "recurrence": frontmatter.get("recurrence", "one-shot"),
    }


# ── Formatting helpers ─────────────────────────────────────────────────


def _fmt_age(seconds):
    if seconds < 60:
        return f"{int(seconds)}s ago"
    minutes = seconds // 60
    if minutes < 60:
        return f"{int(minutes)}m ago"
    return f"{int(minutes // 60)}h ago"


def _fmt_size(bytes_):
    if bytes_ < 1024:
        return f"{bytes_} B"
    return f"{bytes_ / 1024:.1f} KB"


_TS_RE = re.compile(r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z")


def _ts_to_epoch(ts_str):
    m = _TS_RE.match(ts_str)
    if not m:
        return 0
    try:
        return datetime(
            int(m.group(1)), int(m.group(2)), int(m.group(3)),
            int(m.group(4)), int(m.group(5)), int(m.group(6)),
            tzinfo=timezone.utc,
        ).timestamp()
    except (ValueError, OSError):
        return 0


# ── Poll Loops ─────────────────────────────────────────────────────────


def poll_journal(garden_root, data, pubsub, stop_event):
    """Background thread: git fetch journal branch, parse new entries."""
    git_dir = os.path.join(garden_root, ".git")

    def git(args):
        return subprocess.run(
            ["git", f"--git-dir={git_dir}"] + args,
            capture_output=True, text=True, timeout=30,
        )

    while not stop_event.is_set():
        try:
            r = git(["fetch", "origin", "journal"])
            if r.returncode != 0:
                stop_event.wait(POLL_JOURNAL_SECS)
                continue

            r = git(["rev-parse", "origin/journal"])
            if r.returncode != 0:
                stop_event.wait(POLL_JOURNAL_SECS)
                continue
            current_ref = r.stdout.strip()

            if current_ref and current_ref != data.last_journal_ref:
                # ── Journal entries ────────────────────────────────────
                r = git(["ls-tree", "-r", "--name-only", "origin/journal", "entries/"])
                if r.returncode == 0:
                    entry_files = sorted(
                        f for f in r.stdout.strip().split("\n")
                        if f.startswith("entries/") and f.endswith(".md")
                    )
                    entries = []
                    for ef in entry_files[-MAX_ENTRIES:]:
                        r2 = git(["show", f"origin/journal:{ef}"])
                        if r2.returncode != 0:
                            continue
                        entry = _parse_entry(ef, r2.stdout)
                        if entry and entry["ts"]:
                            entries.append(entry)
                    if entries:
                        data.update_entries(entries)
                        pubsub.publish("entries", {"count": len(entries)})

                # ── Bulletin ───────────────────────────────────────────
                r = git(["show", "origin/journal:README.md"])
                if r.returncode == 0:
                    data.update_bulletin(r.stdout)

                # ── Worktrees ──────────────────────────────────────────
                r = git(["ls-tree", "-r", "--name-only", "origin/journal", "worktrees/"])
                if r.returncode == 0:
                    wt_files = [
                        f for f in r.stdout.strip().split("\n")
                        if f.startswith("worktrees/") and f.endswith(".md")
                        and f != "worktrees/README.md"
                    ]
                    worktrees = []
                    for wtf in wt_files:
                        r2 = git(["show", f"origin/journal:{wtf}"])
                        if r2.returncode != 0:
                            continue
                        wt = _parse_worktree_file(wtf, r2.stdout)
                        if wt:
                            worktrees.append(wt)
                    data.update_worktrees(worktrees)

                # ── Schedule ───────────────────────────────────────────
                r = git(["ls-tree", "-r", "--name-only", "origin/journal", "schedule/"])
                if r.returncode == 0:
                    sched_files = [
                        f for f in r.stdout.strip().split("\n")
                        if f.startswith("schedule/") and f.endswith(".md")
                        and "/_fired/" not in f
                    ]
                    events = []
                    for sf in sched_files:
                        r2 = git(["show", f"origin/journal:{sf}"])
                        if r2.returncode != 0:
                            continue
                        ev = _parse_schedule_event(sf, r2.stdout)
                        if ev:
                            events.append(ev)
                    data.update_schedule(events)

                data.last_journal_ref = current_ref
                pubsub.publish("journal-fetch", {"ref": current_ref[:8]})

        except Exception:
            pass  # retry on next tick

        stop_event.wait(POLL_JOURNAL_SECS)


def poll_filesystem(garden_root, data, pubsub, stop_event):
    """Background thread: poll dispatch roots and /tmp monitor logs."""
    dispatches_dir = os.path.join(garden_root, "dispatches")
    tmp_dir = "/tmp"

    while not stop_event.is_set():
        try:
            # ── Dispatch roots ─────────────────────────────────────────
            roots = []
            if os.path.isdir(dispatches_dir):
                for d in os.listdir(dispatches_dir):
                    dpath = os.path.join(dispatches_dir, d)
                    if not os.path.isdir(dpath):
                        continue
                    age = time.time() - os.path.getmtime(dpath)
                    parts = d.split("--", 1)
                    roots.append({
                        "role": parts[0] if parts else "?",
                        "short_id": parts[1] if len(parts) > 1 else d,
                        "age_seconds": int(age),
                    })
            data.update_dispatch_roots(roots)

            # ── Monitor logs ───────────────────────────────────────────
            monitors = []
            for entry in sorted(os.listdir(tmp_dir)):
                if not entry.startswith("garden-monitor-") or not entry.endswith(".log"):
                    continue
                slug = entry[len("garden-monitor-"):-len(".log")]
                fpath = os.path.join(tmp_dir, entry)
                pidpath = fpath.replace(".log", ".pid")
                try:
                    st = os.stat(fpath)
                except OSError:
                    continue
                age = time.time() - st.st_mtime
                pid = None
                alive = False
                if os.path.isfile(pidpath):
                    try:
                        pid = int(open(pidpath).read().strip())
                        alive = os.path.isdir(f"/proc/{pid}")
                    except (ValueError, OSError):
                        pass
                last_line = ""
                try:
                    with open(fpath) as lf:
                        for line in lf:
                            pass
                        last_line = line.strip() if line else ""
                except OSError:
                    pass
                monitors.append({
                    "slug": slug,
                    "pid": pid,
                    "alive": alive,
                    "last_event_ago": int(age),
                    "log_size": st.st_size,
                    "last_line": last_line[:200],
                })

            # review-queue log
            rq_log = os.path.join(tmp_dir, "garden-review-queue.log")
            if os.path.isfile(rq_log):
                try:
                    st = os.stat(rq_log)
                    age = time.time() - st.st_mtime
                    last_line = ""
                    with open(rq_log) as lf:
                        for line in lf:
                            pass
                        last_line = line.strip() if line else ""
                    monitors.append({
                        "slug": "review-queue",
                        "pid": None,
                        "alive": age < 300,
                        "last_event_ago": int(age),
                        "log_size": st.st_size,
                        "last_line": last_line[:200],
                    })
                except OSError:
                    pass

            data.update_monitors(monitors)
            pubsub.publish("filesystem", {"roots": len(roots), "monitors": len(monitors)})

        except Exception:
            pass

        stop_event.wait(POLL_FILESYSTEM_SECS)


def poll_github(data, stop_event):
    """Background thread: optionally poll gh for PR state enrichment."""
    while not stop_event.is_set():
        try:
            r = subprocess.run(["which", "gh"], capture_output=True, text=True)
            if r.returncode != 0:
                stop_event.wait(POLL_GITHUB_SECS)
                continue

            # Gather PR numbers from recent entry previews
            snapshot = data.get_snapshot()
            prs = set()
            for entry in snapshot.get("entries", []):
                for match in re.finditer(r"#(\d{3,6})", entry.get("body_preview", "")):
                    prs.add(match.group(1))

            for pr_num in list(prs)[:10]:
                if stop_event.is_set():
                    break
                r = subprocess.run(
                    ["gh", "pr", "view", pr_num,
                     "--json", "state,isDraft,mergeable,title,url,headRefName,baseRefName"],
                    capture_output=True, text=True, timeout=15,
                )
                if r.returncode == 0:
                    pass  # data available for future enrichment
        except Exception:
            pass

        stop_event.wait(POLL_GITHUB_SECS)


# ── HTML Templates ─────────────────────────────────────────────────────


def _page_head(title, hostname, active_nav):
    nav_items = [
        ("/", "Dashboard"),
        ("/timeline", "Timeline"),
        ("/state", "State"),
        ("/bulletin", "Bulletin"),
    ]
    nav_html = ""
    for href, label in nav_items:
        active_attr = ' class="active"' if href == active_nav else ""
        nav_html += f'<a href="{href}"{active_attr}>{label}</a>\n'
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} — Garden Visualizer</title>
<style>
  * {{ box-sizing: border-box; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
         margin: 0; background: #0d1117; color: #c9d1d9; }}
  nav {{ display: flex; gap: 4px; padding: 8px 20px; background: #0d1117;
        border-bottom: 1px solid #21262d; }}
  nav a {{ padding: 4px 12px; border-radius: 4px; font-size: 13px; color: #8b949e;
          text-decoration: none; }}
  nav a:hover {{ background: #1c2128; color: #c9d1d9; }}
  nav a.active {{ background: #1f6feb33; color: #58a6ff; }}
  .header {{ background: #161b22; border-bottom: 1px solid #30363d;
            padding: 12px 20px; display: flex; justify-content: space-between; align-items: center; }}
  .header h1 {{ margin: 0; font-size: 18px; color: #58a6ff; }}
  .header .meta {{ font-size: 13px; color: #8b949e; }}
  .panel {{ margin: 12px 20px; background: #161b22; border: 1px solid #30363d;
           border-radius: 6px; overflow: hidden; }}
  .panel h2 {{ margin: 0; padding: 10px 16px; font-size: 14px; background: #1c2128;
              border-bottom: 1px solid #30363d; color: #8b949e;
              text-transform: uppercase; letter-spacing: 0.5px; }}
  .panel-body {{ padding: 8px 0; }}
  .row {{ padding: 6px 16px; font-size: 13px; border-bottom: 1px solid #21262d;
         display: flex; align-items: center; gap: 8px; }}
  .row:last-child {{ border-bottom: none; }}
  .badge {{ display: inline-block; padding: 1px 6px; border-radius: 3px;
           font-size: 11px; font-weight: 600; }}
  .badge-dispatch {{ background: #1f6feb33; color: #58a6ff; }}
  .badge-result {{ background: #23863633; color: #3fb950; }}
  .badge-monitor {{ background: #d2992233; color: #d29922; }}
  .status-dot {{ display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 4px; }}
  .dot-alive {{ background: #3fb950; }}
  .dot-stale {{ background: #d29922; }}
  .dot-dead {{ background: #f85149; }}
  .age {{ color: #8b949e; font-size: 11px; margin-left: auto; white-space: nowrap; }}
  .mono {{ font-family: 'SFMono-Regular', Consolas, monospace; font-size: 11px; color: #8b949e; }}
  a {{ color: #58a6ff; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
  th {{ text-align: left; padding: 8px 16px; background: #1c2128; color: #8b949e;
       font-weight: 600; border-bottom: 1px solid #30363d; }}
  td {{ padding: 6px 16px; border-bottom: 1px solid #21262d; }}
  tr:hover {{ background: #1c2128; }}
  .content {{ padding: 20px; }}
  .content h1, .content h2, .content h3, .content h4 {{ color: #58a6ff; }}
  .content h1 {{ border-bottom: 1px solid #30363d; padding-bottom: 8px; }}
  .content pre {{ background: #1c2128; padding: 12px; border-radius: 6px; overflow-x: auto; }}
  .content code {{ background: #1c2128; padding: 2px 6px; border-radius: 3px; font-size: 13px; }}
  .content pre code {{ padding: 0; }}
  .content ul, .content ol {{ padding-left: 20px; }}
  .content li {{ margin: 4px 0; }}
  .content hr {{ border: none; border-top: 1px solid #30363d; }}
  .range {{ display: flex; gap: 4px; padding: 8px 20px; }}
  .range a {{ padding: 4px 12px; border-radius: 4px; font-size: 13px; color: #8b949e;
            text-decoration: none; border: 1px solid #30363d; }}
  .range a:hover {{ background: #1c2128; }}
  .range a.active {{ background: #1f6feb33; color: #58a6ff; border-color: #1f6feb; }}
</style>
</head>
<body>
<nav>{nav_html}</nav>
<div class="header">
  <h1>{html.escape(title)}</h1>
  <span class="meta" id="meta">{html.escape(hostname)} · <span id="stale">starting…</span></span>
</div>
"""


def _page_end(extra_js=""):
    return f"""
<script>
const es = new EventSource('/events');
es.onmessage = function(e) {{ document.getElementById('stale').textContent =
  'updated ' + new Date().toLocaleTimeString(); }};
es.onerror = function() {{ document.getElementById('stale').textContent = 'disconnected'; }};
{extra_js}
</script>
</body>
</html>"""


def render_dashboard(data, hostname):
    s = data.get_snapshot()
    entries = s["entries"][:10]
    monitors = s["monitors"]
    roots = s["dispatch_roots"]

    html_ = _page_head("Dashboard", hostname, "/")

    # Active dispatches
    html_ += '<div class="panel"><h2>Active Dispatches</h2><div class="panel-body" id="dispatches">'
    if roots:
        for r in roots:
            html_ += (
                f'<div class="row">'
                f'<span class="badge badge-dispatch">{html.escape(r["role"])}</span> '
                f'<code>{html.escape(r["short_id"])}</code>'
                f'<span class="age">{_fmt_age(r["age_seconds"])}</span></div>'
            )
    else:
        html_ += '<div class="row" style="color:#8b949e">No active dispatches.</div>'
    html_ += "</div></div>"

    # Recent results
    html_ += '<div class="panel"><h2>Recent Results</h2><div class="panel-body" id="results">'
    if entries:
        for e in entries:
            kind_class = "badge-result" if e["kind"] == "result" else "badge-dispatch"
            html_ += (
                f'<div class="row">'
                f'<span class="badge {kind_class}">{html.escape(e["kind"])}</span>'
                f'{html.escape(e["role"])} <code>{html.escape(e["short_id"])}</code>'
                f'<span style="color:#8b949e;font-size:11px;margin-left:8px;overflow:hidden;text-overflow:ellipsis;max-width:400px;white-space:nowrap">'
                f'{html.escape(e["body_preview"][:100])}</span>'
                f'<span class="age">{_fmt_age(_ts_to_epoch(e["ts"]))}</span></div>'
            )
    else:
        html_ += '<div class="row" style="color:#8b949e">No entries yet.</div>'
    html_ += "</div></div>"

    # Running monitors
    html_ += '<div class="panel"><h2>Running Monitors</h2><div class="panel-body" id="monitors">'
    if monitors:
        for m in monitors:
            dot = "dot-alive" if m["alive"] and m["last_event_ago"] < 120 else (
                "dot-stale" if m["alive"] else "dot-dead"
            )
            html_ += (
                f'<div class="row">'
                f'<span class="status-dot {dot}"></span>'
                f'<span class="badge badge-monitor">{html.escape(m["slug"])}</span>'
                f'<span style="color:#8b949e;font-size:11px">'
                f'{"PID " + str(m["pid"]) if m["pid"] else ""}</span>'
                f'<span class="age">{_fmt_age(m["last_event_ago"])}</span></div>'
            )
            if m["last_line"]:
                html_ += (
                    f'<div class="row mono" style="padding-left:38px;padding-top:2px;padding-bottom:2px">'
                    f'{html.escape(m["last_line"][:150])}</div>'
                )
    else:
        html_ += '<div class="row" style="color:#8b949e">No monitors found.</div>'
    html_ += "</div></div>"

    html_ += _page_end()
    return html_


def render_timeline(data, since_seconds=3600):
    s = data.get_snapshot()
    cutoff = time.time() - since_seconds
    entries = [e for e in s["entries"] if _ts_to_epoch(e.get("ts", "")) >= cutoff]

    ranges = [(3600, "1h"), (14400, "4h"), (86400, "24h"), (604800, "7d")]
    html_ = _page_head("Timeline", "", "/timeline")

    html_ += '<div class="range">'
    for sec, label in ranges:
        active = ' active' if sec == since_seconds else ''
        html_ += f'<a href="/timeline?since={sec}" class="{active}">{label}</a>'
    html_ += '</div>'

    html_ += '<div id="entries">'
    if entries:
        for e in entries:
            kind_class = {
                "result": "badge-result", "dispatch": "badge-dispatch",
                "message": "badge-monitor", "tick": "badge-monitor",
            }.get(e["kind"], "")
            html_ += (
                f'<div class="row" style="flex-direction:column;align-items:stretch">'
                f'<div><span class="badge {kind_class}">{html.escape(e["kind"])}</span> '
                f'{html.escape(e["role"])} <code>{html.escape(e["short_id"])}</code>'
                f'<span class="age">{html.escape(e["ts"])}</span></div>'
                f'<div style="color:#c9d1d9;font-size:12px;padding-left:4px">'
                f'{html.escape(e["body_preview"][:200])}</div></div>'
            )
    else:
        html_ += '<div class="row" style="color:#8b949e">No entries in this window.</div>'
    html_ += '</div>'

    html_ += _page_end()
    return html_


def render_state(data, hostname):
    s = data.get_snapshot()
    worktrees = s["worktrees"]
    monitors = s["monitors"]
    schedule = s["schedule"]

    html_ = _page_head("Garden State", hostname, "/state")

    # Worktrees
    html_ += '<div class="panel"><h2>Worktrees</h2><table>'
    html_ += "<tr><th>Host</th><th>Name</th><th>Role</th><th>Status</th><th>Heartbeat</th></tr>"
    if worktrees:
        for w in sorted(worktrees, key=lambda x: (x["host"], x["name"])):
            html_ += (
                f"<tr><td>{html.escape(w['host'])}</td>"
                f"<td>{html.escape(w['name'])}</td>"
                f"<td>{html.escape(w['role'])}</td>"
                f"<td>{html.escape(w['status'])}</td>"
                f"<td style='font-size:11px'>{html.escape(w['heartbeat'])}</td></tr>"
            )
    else:
        html_ += '<tr><td colspan="5" style="color:#8b949e;text-align:center">No worktrees found.</td></tr>'
    html_ += "</table></div>"

    # Daemon health
    html_ += '<div class="panel"><h2>Daemon Health</h2><table>'
    html_ += "<tr><th>Monitor</th><th>Status</th><th>PID</th><th>Last Event</th><th>Log Size</th></tr>"
    if monitors:
        for m in sorted(monitors, key=lambda x: x["slug"]):
            status = "RUNNING" if m["alive"] else "STOPPED"
            html_ += (
                f"<tr><td>{html.escape(m['slug'])}</td>"
                f"<td>{status}</td>"
                f"<td>{m['pid'] if m['pid'] else '—'}</td>"
                f"<td>{_fmt_age(m['last_event_ago'])} ago</td>"
                f"<td>{_fmt_size(m['log_size'])}</td></tr>"
            )
    else:
        html_ += '<tr><td colspan="5" style="color:#8b949e;text-align:center">No monitors found.</td></tr>'
    html_ += "</table></div>"

    # Schedule
    html_ += '<div class="panel"><h2>Schedule</h2><table>'
    html_ += "<tr><th>Trigger</th><th>Role</th><th>Purpose</th><th>Recurrence</th></tr>"
    if schedule:
        for e in schedule:
            html_ += (
                f"<tr><td style='font-size:11px'>{html.escape(e['trigger'])}</td>"
                f"<td>{html.escape(e['role'])}</td>"
                f"<td>{html.escape(e['purpose'])}</td>"
                f"<td>{html.escape(e['recurrence'])}</td></tr>"
            )
    else:
        html_ += '<tr><td colspan="4" style="color:#8b949e;text-align:center">No scheduled events.</td></tr>'
    html_ += "</table></div>"

    html_ += _page_end()
    return html_


def render_bulletin(data, md_renderer):
    s = data.get_snapshot()
    raw = s.get("bulletin", "")
    html_ = _page_head("Bulletin", "", "/bulletin")

    if not raw:
        html_ += '<div class="row" style="color:#8b949e">Waiting for first journal fetch…</div>'
    else:
        html_ += f'<div class="content">{md_renderer.render(raw)}</div>'

    html_ += _page_end()
    return html_


# ── HTTP Handler ───────────────────────────────────────────────────────


class VisualizerHandler(http.server.BaseHTTPRequestHandler):
    """HTTP handler.  Shared state lives on the class object."""

    data = None
    md_renderer = None
    hostname = ""
    pubsub = None

    def do_GET(self):
        path = self.path.split("?")[0]
        params = {}
        if "?" in self.path:
            for part in self.path.split("?", 1)[1].split("&"):
                if "=" in part:
                    k, v = part.split("=", 1)
                    params[k] = v

        try:
            if path == "/":
                self._html(render_dashboard(self.data, self.hostname))
            elif path == "/timeline":
                since = int(params.get("since", "3600"))
                self._html(render_timeline(self.data, since))
            elif path == "/state":
                self._html(render_state(self.data, self.hostname))
            elif path == "/bulletin":
                self._html(render_bulletin(self.data, self.md_renderer))
            elif path == "/events":
                self._sse()
            elif path == "/api/snapshot":
                self._json(self.data.get_snapshot())
            else:
                self.send_response(404)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"Not found")
        except BrokenPipeError:
            pass
        except Exception as e:
            try:
                self.send_response(500)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(f"Error: {e}".encode())
            except BrokenPipeError:
                pass

    def _html(self, content):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(content.encode("utf-8"))

    def _json(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(json.dumps(data, default=str).encode("utf-8"))

    def _sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        q = self.pubsub.subscribe()
        try:
            while True:
                try:
                    msg = q.get(timeout=30)
                    self.wfile.write(f"data: {msg}\n\n".encode("utf-8"))
                    self.wfile.flush()
                except queue.Empty:
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            self.pubsub.unsubscribe(q)

    def log_message(self, fmt, *args):
        pass  # quiet


# ── Main ───────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="Garden Visualizer")
    parser.add_argument("--port", type=int,
                        default=int(os.environ.get("GARDEN_VISUALIZER_PORT", DEFAULT_PORT)))
    parser.add_argument("--host",
                        default=os.environ.get("GARDEN_VISUALIZER_HOST", DEFAULT_HOST))
    parser.add_argument("--garden-root",
                        default=os.environ.get("GARDEN_ROOT", os.getcwd()))
    args = parser.parse_args()

    garden_root = os.path.abspath(args.garden_root)

    data = GardenData()
    md_renderer = MarkdownRenderer()
    pubsub = PubSub()
    stop_event = threading.Event()

    VisualizerHandler.data = data
    VisualizerHandler.md_renderer = md_renderer
    VisualizerHandler.hostname = os.uname().nodename
    VisualizerHandler.pubsub = pubsub

    threads = [
        threading.Thread(target=poll_journal,
                         args=(garden_root, data, pubsub, stop_event),
                         daemon=True, name="journal"),
        threading.Thread(target=poll_filesystem,
                         args=(garden_root, data, pubsub, stop_event),
                         daemon=True, name="fs"),
        threading.Thread(target=poll_github,
                         args=(data, stop_event),
                         daemon=True, name="gh"),
    ]
    for t in threads:
        t.start()

    server = http.server.ThreadingHTTPServer((args.host, args.port), VisualizerHandler)

    print(f"Garden Visualizer  http://{args.host}:{args.port}", flush=True)
    print(f"  garden root: {garden_root}", flush=True)
    print(f"  pid: {os.getpid()}", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nshutting down…")
        stop_event.set()
        server.shutdown()


if __name__ == "__main__":
    main()
