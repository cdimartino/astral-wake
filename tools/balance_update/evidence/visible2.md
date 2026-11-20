# visible2: 16 of 16 rows

Headless paired policy tests. Counts in each cell are control → single-rule trial.

| Seed stratum | Ship | Policy | Pairs | Victories | Area 3 reached | Median fight turns: all | Matched median (n; change) | Area 3 matched | Win-run median minimum hull |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| fresh | hollow_choir | tactical | 1 | 1→1 | 1→1 | 5.5→5.5 | 5.5→5.5 (20; 0%) | 6→6 (6) | 40→40 |
| fresh | palimpsest | tactical | 1 | 0→0 | 1→1 | 4→3.5 | 4→4 (17; 0%) | 6.5→4.5 (4) | —→— |
| full | hollow_choir | tactical | 1 | 1→1 | 1→1 | 8→8 | 8→8 (23; 0%) | 8→8 (7) | 36→36 |
| full | palimpsest | tactical | 1 | 0→1 | 1→1 | 6→6 | 6→5 (20; -16.67%) | 9.5→7.5 (4) | —→0 |
| legacy | hollow_choir | tactical | 2 | 1→2 | 2→2 | 8→8 | 8→8 (32; 0%) | 8→8 (7) | 65→40.5 |
| legacy | palimpsest | tactical | 2 | 1→1 | 2→2 | 5→5 | 4→5 (29; 25%) | 17→14 (2) | 16→14 |

## Mechanism/exposure

Threshold = damaging six-Trace Recall (A) or three-Resonance **card** Crescendo (B). Effective = at least one more actual damage after defenses and HP clipping, versus old rule on the exact selected move. Final-kill count is a marginal selected-target kill, not a saved encounter.

| Stratum | Ship / policy | Reward offers → picks (C/T) | Crescendo draw / play (C/T) | Threshold plays C→T | Effective trial plays | Added actual damage | Marginal target kills |
|---|---|---:|---:|---:|---:|---:|---:|
| fresh | hollow_choir / tactical | 3→1 / 3→1 | 29/4 · 29/4 | 1→1 | 1 | 4 | 0 |
| fresh | palimpsest / tactical | — | — | 2→14 | 14 | 41 | 1 |
| full | hollow_choir / tactical | 5→1 / 5→1 | 62/1 · 62/2 | 0→1 | 1 | 4 | 0 |
| full | palimpsest / tactical | — | — | 11→19 | 16 | 47 | 2 |
| legacy | hollow_choir / tactical | 5→2 / 4→2 | 102/6 · 116/5 | 2→5 | 5 | 19 | 2 |
| legacy | palimpsest / tactical | — | — | 10→24 | 23 | 66 | 3 |

## Terminal flips

| Ship, cohort, policy | Seed | Result | Original losing encounter in normal trial | Different route branch? |
|---|---|---|---|---|
| palimpsest, full, tactical | 03ZRV7 | defeat→victory | original node cleared with different history | yes |
| hollow_choir, legacy, tactical | 777 | defeat→victory | original loss not revisited | yes |

Exact-entry replays, when run, are reported separately. A changed victory is not by itself a rescue of the old losing encounter.
