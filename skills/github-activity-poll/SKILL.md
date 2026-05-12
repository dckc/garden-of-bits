---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Skill: github-activity-poll

Poll a GitHub repository's public events feed efficiently using conditional HTTP requests. When nothing has changed, the response is 304 Not Modified and does **not** count against the primary REST rate limit, so 1/minute polling is sustainable indefinitely.

## Inputs

- `repo`: `owner/name` (e.g. `anthropics/claude-code`).
- `state_dir`: directory to read/write polling state. Default: `<worktree>/.garden-monitor/<owner>-<repo>/`.
- `auth_token` (optional): a GitHub token. Read from `$GITHUB_TOKEN` if not passed. Required for private repos; raises rate limit from 60/hr to 5000/hr otherwise.

## State files

Inside `state_dir`:

- `etag.txt`: value of the previous response's `ETag` header.
- `last_modified.txt`: value of the previous response's `Last-Modified` header.
- `last_event_id.txt`: id of the highest event seen so far. Used to dedupe within a single 200 response.

All three are written atomically (write to `*.tmp`, then `mv`) so a crash mid-write cannot corrupt state.

## Procedure

1. `mkdir -p <state_dir>`.
2. Read `etag.txt` and `last_modified.txt` if present.
3. Issue:

   ```
   GET https://api.github.com/repos/<repo>/events
   Accept: application/vnd.github+json
   X-GitHub-Api-Version: 2022-11-28
   If-None-Match: <etag>            # if known
   If-Modified-Since: <last_modified> # if known
   Authorization: Bearer <token>    # if a token is configured
   ```

4. Branch on status:

   - **304 Not Modified**: no new events. Touch nothing on disk. Output: `unchanged repo=<repo> last_modified=<ts>`.
   - **200 OK**: parse the JSON array (newest first). Drop events with `id <= last_event_id`. For each remaining event capture: `id`, `type`, `actor.login`, `created_at`, and a payload-specific link (PR number, issue number, push ref, comment URL). Then atomically update `etag.txt`, `last_modified.txt`, and `last_event_id.txt` (set to the max id seen).
   - **403 / 429**, or `X-RateLimit-Remaining: 0`: stop. Report the limit and `X-RateLimit-Reset` (epoch seconds).
   - **404**: repo is missing, private, or the token lacks access. Stop and report.
   - **Anything else**: stop and report status + body excerpt.

## Output shape

Unchanged:

```
unchanged repo=<repo> last_modified=<ts>
```

Changed:

```
changed repo=<repo> new_events=<n>
  <created_at> <type> by <actor> -> <link>
  ...
```

If `n > 10`, group by `(type, actor)` and emit one line per group with a count instead of one line per event.

## Notes

- The `/events` endpoint is server-cached by GitHub for ~60 seconds. Polling faster than 1/min wastes calls and may return stale data.
- The events feed only surfaces public activity. For private repos, or for activity not on the events feed (discussions, security advisories), use the equivalent typed endpoint (`/issues`, `/pulls`, `/discussions`) with the same conditional-request pattern.
- `ETag` is the more reliable validator; `If-Modified-Since` is a fallback. Always send both when both are known. GitHub will honor whichever matches.

## Notes from the field

- _2026-05-12_: `check_run` and `check_suite` activity does **not** appear on this endpoint. To watch CI on a specific PR, use [pr-ci-watch](../pr-ci-watch/SKILL.md), which polls the PR's status check rollup directly. This skill is still useful alongside it for repo-wide situational awareness (new pushes to base, branch creations, etc.).
