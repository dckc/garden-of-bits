#!/bin/bash
# next-trigger.sh — compute the next UTC trigger timestamp for a recurrence rule.
#
# Usage:
#   next-trigger.sh <recurrence-rule> [<reference-iso-8601>]
#
# Recurrence-rule shapes (see skills/scheduling/SKILL.md § Recurrence rule shape):
#   one-shot                                            (no next trigger; exits non-zero)
#   daily-at-<HH:MM>-<timezone>                         (e.g. daily-at-00:00-America/Los_Angeles)
#   weekly-on-<weekday>-at-<HH:MM>-<timezone>           (weekday is lowercase English)
#   hourly-at-<MM>-<timezone>                           (e.g. hourly-at-00-UTC)
#
# Reference time is UTC ISO-8601 (e.g. 2026-05-13T05:38:22Z). Defaults to now (UTC).
# The script emits the first occurrence strictly after the reference time.
#
# Output:
#   stdout line 1: UTC ISO-8601 (e.g. 2026-05-13T07:00:00Z)
#   stdout line 2: compact form (e.g. 20260513T070000Z)
# Exit codes:
#   0 success
#   1 parse failure or one-shot (no next trigger)
#   2 usage error

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <recurrence-rule> [<reference-iso-8601>]" >&2
  exit 2
fi

RULE=$1
REFERENCE=${2:-}

exec python3 - "$RULE" "$REFERENCE" <<'PY'
import sys
import re
from datetime import datetime, timedelta, time
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

rule = sys.argv[1]
reference_arg = sys.argv[2] if len(sys.argv) > 2 else ""

UTC = ZoneInfo("UTC")

# Reference time (UTC). Accepts trailing Z or +00:00.
if reference_arg:
    s = reference_arg.replace("Z", "+00:00")
    try:
        reference = datetime.fromisoformat(s)
    except ValueError:
        print(f"next-trigger: cannot parse reference time: {reference_arg}", file=sys.stderr)
        sys.exit(1)
    if reference.tzinfo is None:
        reference = reference.replace(tzinfo=UTC)
    reference = reference.astimezone(UTC)
else:
    reference = datetime.now(UTC)


def emit(dt_utc):
    iso = dt_utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    compact = dt_utc.strftime("%Y%m%dT%H%M%SZ")
    print(iso)
    print(compact)


WEEKDAYS = {
    "monday": 0,
    "tuesday": 1,
    "wednesday": 2,
    "thursday": 3,
    "friday": 4,
    "saturday": 5,
    "sunday": 6,
}


def parse_hhmm(s):
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", s)
    if not m:
        return None
    hh, mm = int(m.group(1)), int(m.group(2))
    if not (0 <= hh <= 23 and 0 <= mm <= 59):
        return None
    return hh, mm


def parse_mm(s):
    m = re.fullmatch(r"(\d{1,2})", s)
    if not m:
        return None
    mm = int(m.group(1))
    if not (0 <= mm <= 59):
        return None
    return mm


def load_tz(name):
    try:
        return ZoneInfo(name)
    except ZoneInfoNotFoundError:
        return None


def next_daily(hhmm, tzname):
    tz = load_tz(tzname)
    if tz is None:
        print(f"next-trigger: unknown timezone: {tzname}", file=sys.stderr)
        sys.exit(1)
    hh, mm = hhmm
    ref_local = reference.astimezone(tz)
    candidate = ref_local.replace(hour=hh, minute=mm, second=0, microsecond=0)
    if candidate <= ref_local:
        candidate = candidate + timedelta(days=1)
    # Resolve the local wall time onto UTC. zoneinfo on a non-existent or
    # ambiguous local time picks a side automatically; for daily-at-HH:MM
    # rules that side is the standard fold semantics.
    return candidate.astimezone(UTC)


def next_weekly(weekday_name, hhmm, tzname):
    tz = load_tz(tzname)
    if tz is None:
        print(f"next-trigger: unknown timezone: {tzname}", file=sys.stderr)
        sys.exit(1)
    if weekday_name not in WEEKDAYS:
        print(f"next-trigger: unknown weekday: {weekday_name}", file=sys.stderr)
        sys.exit(1)
    target = WEEKDAYS[weekday_name]
    hh, mm = hhmm
    ref_local = reference.astimezone(tz)
    candidate = ref_local.replace(hour=hh, minute=mm, second=0, microsecond=0)
    days_ahead = (target - candidate.weekday()) % 7
    candidate = candidate + timedelta(days=days_ahead)
    if candidate <= ref_local:
        candidate = candidate + timedelta(days=7)
    return candidate.astimezone(UTC)


def next_hourly(mm, tzname):
    tz = load_tz(tzname)
    if tz is None:
        print(f"next-trigger: unknown timezone: {tzname}", file=sys.stderr)
        sys.exit(1)
    ref_local = reference.astimezone(tz)
    candidate = ref_local.replace(minute=mm, second=0, microsecond=0)
    if candidate <= ref_local:
        candidate = candidate + timedelta(hours=1)
    return candidate.astimezone(UTC)


# Dispatch on rule shape.
if rule == "one-shot":
    print("next-trigger: one-shot has no next trigger", file=sys.stderr)
    sys.exit(1)

m = re.fullmatch(r"daily-at-(\d{1,2}:\d{2})-(.+)", rule)
if m:
    hhmm = parse_hhmm(m.group(1))
    tzname = m.group(2)
    if hhmm is None:
        print(f"next-trigger: cannot parse time-of-day in: {rule}", file=sys.stderr)
        sys.exit(1)
    emit(next_daily(hhmm, tzname))
    sys.exit(0)

m = re.fullmatch(r"weekly-on-([a-z]+)-at-(\d{1,2}:\d{2})-(.+)", rule)
if m:
    weekday_name = m.group(1)
    hhmm = parse_hhmm(m.group(2))
    tzname = m.group(3)
    if hhmm is None:
        print(f"next-trigger: cannot parse time-of-day in: {rule}", file=sys.stderr)
        sys.exit(1)
    emit(next_weekly(weekday_name, hhmm, tzname))
    sys.exit(0)

m = re.fullmatch(r"hourly-at-(\d{1,2})-(.+)", rule)
if m:
    mm = parse_mm(m.group(1))
    tzname = m.group(2)
    if mm is None:
        print(f"next-trigger: cannot parse minute in: {rule}", file=sys.stderr)
        sys.exit(1)
    emit(next_hourly(mm, tzname))
    sys.exit(0)

print(f"next-trigger: unknown recurrence-rule shape: {rule}", file=sys.stderr)
sys.exit(1)
PY
