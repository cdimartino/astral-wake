# official: 224 of 224 rows

Headless paired policy tests. Counts in each cell are control → single-rule trial.

| Seed stratum | Ship | Policy | Pairs | Victories | Area 3 reached | Median fight turns: all | Matched median (n; change) | Area 3 matched | Win-run median minimum hull |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| fresh | hollow_choir | balanced | 8 | 1→1 | 5→5 | 6→6 | 6→6 (114; 0%) | 7→7 (15) | 28→3 |
| fresh | hollow_choir | tactical | 8 | 7→7 | 8→8 | 7→7 | 7→7 (164; 0%) | 8→8 (54) | 25→25 |
| fresh | palimpsest | balanced | 8 | 0→0 | 3→3 | 4→4 | 4→4 (96; 0%) | 5→5 (5) | —→— |
| fresh | palimpsest | tactical | 8 | 3→4 | 7→7 | 4→4 | 4→4 (140; 0%) | 5.5→5.5 (34) | 10→9 |
| full | hollow_choir | balanced | 8 | 3→3 | 8→8 | 8→8 | 8→8 (152; 0%) | 9→9 (34) | 23→23 |
| full | hollow_choir | tactical | 8 | 6→7 | 8→8 | 8→8 | 8→8 (167; 0%) | 9→9 (49) | 28→15 |
| full | palimpsest | balanced | 8 | 1→0 | 5→5 | 5→4 | 4→4 (116; 0%) | 6→5 (15) | 0→— |
| full | palimpsest | tactical | 8 | 2→2 | 7→7 | 5→5 | 5→5 (141; 0%) | 6→6 (24) | 16.5→17 |
| legacy | hollow_choir | aggressive | 6 | 0→0 | 0→0 | 4→4 | 4→4 (18; 0%) | —→— (0) | —→— |
| legacy | hollow_choir | balanced | 6 | 2→2 | 6→6 | 8→8 | 7→7 (95; 0%) | 7→7 (15) | 10→5 |
| legacy | hollow_choir | starter_only | 6 | 0→0 | 5→5 | 9→9 | 9→9 (99; 0%) | 16→16 (17) | —→— |
| legacy | hollow_choir | tactical | 6 | 4→4 | 6→6 | 8→8 | 8→8 (113; 0%) | 9→9 (29) | 56→56 |
| legacy | palimpsest | aggressive | 6 | 0→0 | 0→0 | 3→3 | 3→3 (27; 0%) | —→— (0) | —→— |
| legacy | palimpsest | balanced | 6 | 0→0 | 5→6 | 4→4 | 4→4 (79; 0%) | 4→4 (6) | —→— |
| legacy | palimpsest | starter_only | 6 | 0→0 | 3→3 | 6→5 | 6→6 (72; 0%) | —→— (0) | —→— |
| legacy | palimpsest | tactical | 6 | 1→1 | 6→6 | 4.5→4.5 | 4.5→4.5 (112; 0%) | 5→5 (25) | 37→37 |

## Mechanism/exposure

Threshold = damaging six-Trace Recall (A) or three-Resonance **card** Crescendo (B). Effective = at least one more actual damage after defenses and HP clipping, versus old rule on the exact selected move. Final-kill count is a marginal selected-target kill, not a saved encounter.

| Stratum | Ship / policy | Reward offers → picks (C/T) | Crescendo draw / play (C/T) | Threshold plays C→T | Effective trial plays | Added actual damage | Marginal target kills |
|---|---|---:|---:|---:|---:|---:|---:|
| fresh | hollow_choir / balanced | 16→6 / 16→6 | 214/113 · 214/118 | 2→4 | 4 | 16 | 0 |
| fresh | hollow_choir / tactical | 24→7 / 24→7 | 383/15 · 379/18 | 0→1 | 1 | 4 | 0 |
| fresh | palimpsest / balanced | — | — | 0→3 | 3 | 9 | 1 |
| fresh | palimpsest / tactical | — | — | 15→31 | 30 | 90 | 0 |
| full | hollow_choir / balanced | 23→7 / 23→7 | 312/187 · 315/186 | 2→4 | 4 | 16 | 0 |
| full | hollow_choir / tactical | 21→7 / 23→7 | 365/24 · 381/28 | 4→10 | 10 | 39 | 1 |
| full | palimpsest / balanced | — | — | 3→6 | 6 | 18 | 0 |
| full | palimpsest / tactical | — | — | 5→16 | 15 | 41 | 5 |
| legacy | hollow_choir / aggressive | 1→1 / 1→1 | 6/4 · 6/4 | 0→0 | 0 | 0 | 0 |
| legacy | hollow_choir / balanced | 15→5 / 15→5 | 327/183 · 348/204 | 2→6 | 6 | 24 | 0 |
| legacy | hollow_choir / starter_only | 16→0 / 16→0 | 0/0 · 0/0 | 0→0 | 0 | 0 | 0 |
| legacy | hollow_choir / tactical | 16→5 / 14→5 | 334/5 · 326/9 | 1→4 | 4 | 16 | 0 |
| legacy | palimpsest / aggressive | — | — | 0→1 | 1 | 3 | 0 |
| legacy | palimpsest / balanced | — | — | 2→7 | 7 | 21 | 0 |
| legacy | palimpsest / starter_only | — | — | 2→7 | 7 | 21 | 0 |
| legacy | palimpsest / tactical | — | — | 2→8 | 7 | 21 | 0 |

## Terminal flips

| Ship, cohort, policy | Seed | Result | Original losing encounter in normal trial | Different route branch? |
|---|---|---|---|---|
| palimpsest, fresh, tactical | 02VDB4 | defeat→victory | original node cleared with different history | yes |
| hollow_choir, full, tactical | 04FHIZ | defeat→victory | original node cleared with different history | no |
| palimpsest, full, balanced | 0449HF | victory→defeat | no original loss | no |

Exact-entry replays, when run, are reported separately. A changed victory is not by itself a rescue of the old losing encounter.
