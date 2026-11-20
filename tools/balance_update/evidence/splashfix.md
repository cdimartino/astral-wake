# splashfix: 32 of 32 rows

Headless paired policy tests. Counts in each cell are control → single-rule trial.

| Seed stratum | Ship | Policy | Pairs | Victories | Area 3 reached | Median fight turns: all | Matched median (n; change) | Area 3 matched | Win-run median minimum hull |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| fresh | hollow_choir | tactical | 1 | 1→1 | 1→1 | 5.5→5.5 | 5.5→5.5 (20; 0%) | 6.5→6.5 (6) | 38→38 |
| fresh | palimpsest | tactical | 1 | 0→0 | 1→1 | 4→4 | 4→4 (16; 0%) | 4.5→4.5 (2) | —→— |
| full | hollow_choir | tactical | 1 | 1→1 | 1→1 | 8→8 | 8→8 (23; 0%) | 10→10 (7) | 43→43 |
| full | palimpsest | tactical | 1 | 1→1 | 1→1 | 6→6 | 6→6 (23; 0%) | 7→6 (7) | 31→34 |
| legacy | hollow_choir | tactical | 6 | 5→5 | 6→6 | 8→8 | 8→8 (115; 0%) | 9→9 (29) | 45→45 |
| legacy | palimpsest | tactical | 6 | 2→2 | 5→6 | 5→5 | 5→5 (103; 0%) | 6→6 (21) | 15.5→15.5 |

## Mechanism/exposure

Threshold = damaging six-Trace Recall (A) or three-Resonance **card** Crescendo (B). Effective = at least one more actual damage after defenses and HP clipping, versus old rule on the exact selected move. Final-kill count is a marginal selected-target kill, not a saved encounter.

| Stratum | Ship / policy | Reward offers → picks (C/T) | Crescendo draw / play (C/T) | Threshold plays C→T | Effective trial plays | Added actual damage | Marginal target kills |
|---|---|---:|---:|---:|---:|---:|---:|
| fresh | hollow_choir / tactical | 3→1 / 3→1 | 29/2 · 29/2 | 0→0 | 0 | 0 | 0 |
| fresh | palimpsest / tactical | — | — | 2→2 | 2 | 6 | 0 |
| full | hollow_choir / tactical | 5→1 / 5→1 | 65/2 · 66/3 | 0→1 | 1 | 4 | 0 |
| full | palimpsest / tactical | — | — | 0→3 | 3 | 7 | 1 |
| legacy | hollow_choir / tactical | 22→6 / 21→6 | 340/15 · 333/22 | 1→8 | 8 | 32 | 0 |
| legacy | palimpsest / tactical | — | — | 5→11 | 10 | 30 | 1 |

## Terminal flips

| Ship, cohort, policy | Seed | Result | Original losing encounter in normal trial | Different route branch? |
|---|---|---|---|---|

Exact-entry replays, when run, are reported separately. A changed victory is not by itself a rescue of the old losing encounter.
