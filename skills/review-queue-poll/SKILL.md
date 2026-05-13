---
created: 2026-05-12
updated: 2026-05-12
author: liaison
---

# Skill: review-queue-poll

Poll the GitHub search API for the set of open pull requests on which `kriskowal` is a requested reviewer, persist the canonical set atomically, and emit one log line per add/remove since the previous tick.

This skill is the operational contract the daemon at `skills/review-queue-poll/review-queue-poll.sh` (sibling to this `SKILL.md`) implements. The LLM-side `review-queue` role reads the daemon's outputs; it does not call the search itself.

## Inputs

- `state_dir`: the daemon's state directory. Default: `/tmp/garden-review-queue/`.
- `cadence_seconds`: seconds between polls. Default: 120. The `gh search prs` endpoint costs against the authenticated user's search rate limit (30/min), so cadences faster than 30s are wasteful; 120s gives ample headroom for the daemon plus any concurrent search the steward might run.

## State files

Inside `state_dir`, atomic via `*.tmp` + `mv`:

- `current.json`: canonical snapshot of the queue. One object per pending PR with at least `repo`, `number`, `title`, `url`, `isDraft`, `updatedAt`, `author`, `requestedAt` (best-effort).
- `prev.json`: the previous tick's snapshot, used to compute the diff. Rolled forward atomically before `current.json` is replaced.
- `etag.txt`: present only if the daemon switches to a conditional-fetch transport later; not used by the search API today.

## Procedure (daemon)

1. `gh search prs --review-requested=kriskowal --state=open --limit=1000 --json number,repository,title,url,author,isDraft,updatedAt`. The `gh search` command paginates transparently up to `--limit`; 1000 is the CLI's hard cap. The full GitHub search API caps at 1000 results regardless, so a queue larger than that is undetectable from this skill; if the count ever hits 1000, that itself is the signal to raise a `message` to liaison about refining the filter.
2. Normalize each row into the canonical-set shape:

   ```json
   {
     "repo": "<owner>/<name>",
     "number": 123,
     "title": "...",
     "url": "https://github.com/.../pull/123",
     "isDraft": false,
     "updatedAt": "2026-05-12T20:00:00Z",
     "author": "<login>",
     "requestedAt": null
   }
   ```

   `requestedAt` is left `null` until the per-PR timeline query is added; see *Notes from the field*.

3. Atomically write `current.json.tmp` and rename to `current.json`. Before the rename, copy the previous `current.json` to `prev.json` (also atomic).

4. Diff `prev.json` vs `current.json` by `(repo, number)`. Emit:

   - `[HH:MM:SS] ADD <repo>#<n> draft=<bool> updated=<iso> '<title>'` for each new key.
   - `[HH:MM:SS] REMOVE <repo>#<n>` for each missing key.
   - If neither, `[HH:MM:SS] unchanged n=<count>`.

   The `unchanged` line is the steady state and is what the steward filters out when deciding whether to dispatch.

5. On 401 / 403 / 5xx from `gh search`, write `[HH:MM:SS] HTTP <code> search rate-limited or error` to stderr and back off:

   - 401: exit. Token is gone; the steward will respawn after the maintainer fixes auth.
   - 403 / 429: read `X-RateLimit-Reset` if present (the gh CLI exposes this via the `--include` flag on `gh api`; for `gh search` the daemon falls back to a fixed 5-minute back-off).
   - 5xx: 60-second back-off, then retry.

6. Sleep `cadence_seconds` and loop.

## Procedure (LLM-side, on dispatch)

1. `tail -200 /tmp/garden-review-queue.log` and find lines newer than the prior cycle's close. Note the ADD/REMOVE set as the cycle's delta (for the `tick` journal entry).
2. Read `/tmp/garden-review-queue/current.json` (the source of truth for what is currently pending).
3. Sort the set per the priority rule in `roles/review-queue/AGENT.md` § Priority and ordering. With today's data, every item is tier (3) (fresh request); draft items group at the bottom.
4. Rewrite the *Pending kriskowal reviews* section of `journal/README.md` between the section's delimiters. Each item is one line:

   ```
   - [<repo>#<n>](<url>) <title> — <author>, requested <relative-time>[, draft]
   ```

   Trim title to ~60 chars if needed; the URL is the canonical link.

5. Commit the journal change via `skills/journal-sync/SKILL.md`. Write a `tick` journal entry under `entries/...` summarizing the deltas (one paragraph). Both commits go on the `journal` branch.

## Notes from the field

- _2026-05-12_: `gh search prs --review-requested=USERNAME` returns PRs across all visible repos in one call. Cost is one search-rate-limit point per call (30/min budget). 120s cadence ≈ 30/hr, comfortable.
- _2026-05-12_: `gh search`'s `--limit` is the *hard* page-walk ceiling, not the per-call cap (gh handles pagination internally). The GitHub search API itself stops responding past the 1000-result mark, so 1000 is both the CLI's documented max and the API's practical max; a queue larger than 1000 is invisible to this skill.
- _2026-05-12_: the search endpoint does not include `requestedAt` or the per-PR review history. To populate tiers (1) (`CHANGES_REQUESTED` then pushed) and (2) (explicit re-request), the daemon needs a follow-up `gh api repos/<repo>/pulls/<n>/timeline` per PR in the result set. Cost: one REST call per PR per tick (the 5000/hr REST budget absorbs this for the queue sizes we expect, but it does mean the daemon stops being purely cheap). Land this as a follow-up; until then, every item is tier (3).
- _2026-05-12_: `gh search prs --json updatedAt` returns the *PR's* last-update timestamp, not the last *review-request* timestamp. For tier (3) sort ("newest request first"), `updatedAt` is a usable proxy when the PR was just opened, but not when an old PR re-requests review. The timeline query (above) is the right fix.
