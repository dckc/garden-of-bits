# I'm Just a PR
*(A Garden Schoolhouse Rock Song)*

---

## Part I: The Journey

### Verse 1 — "Here I Sit"

*(A small pull request sits alone on a fork.
A single spotlight. The PR hums to itself.)*

Here I sit, on a bot's fork branch,
Waiting for my journey to begin.
I'm just a PR, with a draft tag on,
And a long, long road I haven't been in.

Oh, when I'm fully reviewed and merged at last,
I'll be code on upstream — I'll be real at last!
But until that day, I'm a draft, you see,
And there's quite a lot of work ahead of me.

### Verse 2 — "It Starts With You"

*(The MAINTAINER appears at a desk. The LIAISON stands nearby.)*

It starts with you — a wish, a need,
A feature that you'd like to see.
You tell the liaison what you want,
The liaison confirms and sets me free.

The liaison doesn't write the code — oh no!
The liaison dispatches roles that know.
A builder gets the word to start my life,
And suddenly I'm more than just a pipe.

### Verse 3 — "The Builder Builds"

*(The BUILDER arrives with tools. Code appears around the PR.)*

The builder reads the spec, the design,
And writes the code that makes me real.
Tests too — the builder writes the tests,
Because a PR without tests is no deal.

Then the builder opens me, a draft PR,
On the bot fork, where I belong.
But I'm not done — oh no, not yet!
The chain is long, and I'm still young.

### Verse 4 — "The Cleaner Cleans"

*(The CLEANER enters with a magnifying glass and a coverage report.)*

Now the cleaner comes to check my coverage,
Hunting dead code, hunting gaps.
"Is every path that you can take
Covered by a test?" the cleaner asks.

The cleaner pushes commits, tidy and neat,
Making sure I'm thorough and complete.
Then the cleaner steps aside and says:
"The coverage's good. Now meet the judge, I guess."

### Verse 5 — "The Judge and the Jury"

*(The JUDGE bangs a gavel. Twelve JURORS take their seats in a panel.)*

The judge convenes the twelve-seat jury —
Assessor, typist, stylist too,
Packager, archivist, prover, curator,
Migrator, locksmith, warden, saboteur,
And breaker — all the twelve are here,
Each reading me with a practiced eye.

They check my logic, check my types,
My naming, my commits, my security too.
Each writes a verdict — must-fix, should-fix,
Or "looks fine to me" — and the judge reviews.

### Verse 6 — "The Fixer Loop"

*(The FIXER appears, rolling up sleeves. A loop spins.)*

If the jury finds something that must be fixed,
The fixer gets to work right away.
Addresses every comment, every thread,
Pushes the fixes, saves the day.

Then the judge sends the jury back again —
"Read it fresh, tell me what you see."
Round and round the loop goes,
Until there's nothing left to fix in me.

### Verse 7 — "I'm Ready!"

*(The PR stands tall. The JUDGE raises a stamp: READY.)*

When every must-fix has been addressed,
The judge submits the panel's review.
Then the judge un-drafts me with a flourish —
Now I'm ready for the maintainer's queue!

I'm no longer just a draft, you see,
I'm a real PR, awaiting review.
The maintainer will read what I have done,
And decide if I'm the thing they want to do.

---

## Part II: While You Were Sleeping

### Verse 8 — "The Night Watchman"

*(Night falls. The STEWARD enters with a lantern and a clipboard.)*

But what happens when you go to sleep?
Does the garden stop? Does the PR just sit?
Oh no — the steward wakes on schedule,
And the garden keeps on turning, bit by bit.

The steward runs on cron, every thirty minutes,
Or sooner if the watcher daemon calls.
A bash daemon polling every fifteen seconds,
Watching logs for `NEW` lines on the walls.

### Verse 9 — "The Monitors"

*(Small MONITOR daemons sit at desks, each watching a different repo.
They write on notepads. A `NEW` line appears.)*

The monitors are polling all the repos,
Conditional GETs with an ETag in hand.
Three-oh-four means nothing has changed —
But a two-hundred means something's in the land.

They write a `NEW` line in the daemon log,
And the watcher daemon sees it right away.
Sixty seconds later, the steward wakes —
And dispatches what the per-project skills say.

### Verse 10 — "The Journal"

*(A grand bulletin board. Envelopes fly between agents.
The JOURNAL is the town square.)*

The journal is the garden's message bus,
Where every agent writes what they have done.
Dispatch entries, results, and messages —
A transcript of the garden, everyone's.

A `message: liaison → steward` says "run the gamut,"
A `message: steward → *` says "treat this check as pass."
A `message: steward → understudy` says "take this investigation,"
And the journal carries every word that passes.

### Verse 11 — "The PR-creation-flow Scan"

*(The STEWARD walks down a row of sleeping draft PRs,
tapping each one on the shoulder.)*

Each cycle, the steward scans the draft PRs,
Checking which stage each one is owed.
"Is there a conflict?" — dispatch the weaver.
"Did the builder finish?" — send the cleaner down the road.

"Did the cleaner push?" — dispatch the judge.
"Did the jury find must-fix?" — call the fixer in.
"Did the fixer push?" — send the judge again.
Round and round, until the PR can win.

One stage per PR per cycle — that's the rule.
One cleaner across the estate at a time.
The steward doesn't rush, the steward doesn't skip —
The steward just keeps everything in line.

### Verse 12 — "The Understudy"

*(The UNDERSTUDY appears, standing next to the STEWARD.)*

When an understudy's present and awake,
The steward shunts some work their way.
Investigations, journalist dispatches,
Major-general fanout — things that need a human's say.

The steward checks the presence file —
Is the heartbeat fresh? Is the status "present"?
If so, a shunt message goes across the journal,
And the understudy handles it, efficient.

### Verse 13 — "Self-Improvement"

*(A small seed sprouts from a journal entry. It grows into a role file.)*

Every engagement ends the same way —
With a lesson learned, or "nothing this time."
A `message` to the liaison with a proposal:
"The role should know this. The skill needs a rewrite."

The liaison reads the lesson, considers,
And edits the role files on `main`.
The garden gets a little bit smarter,
And the cycle starts all over again.

---

## Finale — "I'm Just a PR (Reprise)"

*(The PR is now upstream. The whole cast gathers.)*

I was just a PR, on a bot's fork branch,
Waiting for my journey to begin.
Now I'm merged upstream, the tests all pass,
And the garden's turning on its own again.

From the liaison's dispatch to the steward's scan,
From the builder's code to the judge's gavel bang,
From the monitor's poll to the journal's bus —
That's the garden's workflow, and that's my song.

Oh, when you're fully reviewed and merged at last,
You'll be code on upstream — you'll be real at last!
And until that day, you're a draft, you see,
But the garden's got a workflow that will set you free!

*(Finale. Curtain.)*
