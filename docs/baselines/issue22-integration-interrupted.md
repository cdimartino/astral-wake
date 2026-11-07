# INTERRUPTED integration baseline — issue #22

Server restart cancelled the experiment. This is a separate historical capture; it does not replace earlier evidence. Raw JSONL is preserved byte-for-byte.

Capture SHA-256: `e2129b83c1fc8a8fe856330e6c50da6f46eb5f546d7edfa153a23d7441bd83a1`.

Revision: `1cd5596a653c7dfe66c3d976f96f88c6c2d61fa1`; engine: `4.7.2.stable.official.ed1daf0bf`

Recorded 354/720 cases; missing 366.
Statuses: {'defeat': 257, 'timeout': 35, 'victory': 62}
INTERRUPTED / INCOMPLETE: no final summary; missing cases have no recorded outcome, not timeouts or defeats.

| Ship | Tier | Policy | Wins | Defeats | Errors | Unfinished | Timeout | Missing |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cartographer | 0 | aggressive | 0 | 13 | 0 | 0 | 2 | 15 |
| cartographer | 0 | balanced | 4 | 9 | 0 | 0 | 2 | 15 |
| cartographer | 0 | no-bonuses | 0 | 13 | 0 | 0 | 2 | 15 |
| cartographer | 0 | tactical | 8 | 5 | 0 | 0 | 2 | 15 |
| cartographer | 3 | aggressive | 0 | 13 | 0 | 0 | 2 | 15 |
| cartographer | 3 | balanced | 6 | 7 | 0 | 0 | 2 | 15 |
| cartographer | 3 | no-bonuses | 0 | 14 | 0 | 0 | 1 | 15 |
| cartographer | 3 | tactical | 12 | 2 | 0 | 0 | 1 | 15 |
| hollow_choir | 0 | aggressive | 0 | 15 | 0 | 0 | 0 | 15 |
| hollow_choir | 0 | balanced | 3 | 10 | 0 | 0 | 2 | 15 |
| hollow_choir | 0 | no-bonuses | 0 | 13 | 0 | 0 | 1 | 16 |
| hollow_choir | 0 | tactical | 10 | 3 | 0 | 0 | 1 | 16 |
| hollow_choir | 3 | aggressive | 0 | 14 | 0 | 0 | 0 | 16 |
| hollow_choir | 3 | balanced | 6 | 7 | 0 | 0 | 1 | 16 |
| hollow_choir | 3 | no-bonuses | 0 | 12 | 0 | 0 | 2 | 16 |
| hollow_choir | 3 | tactical | 7 | 4 | 0 | 0 | 3 | 16 |
| palimpsest | 0 | aggressive | 0 | 15 | 0 | 0 | 0 | 15 |
| palimpsest | 0 | balanced | 0 | 14 | 0 | 0 | 1 | 15 |
| palimpsest | 0 | no-bonuses | 0 | 13 | 0 | 0 | 2 | 15 |
| palimpsest | 0 | tactical | 4 | 9 | 0 | 0 | 2 | 15 |
| palimpsest | 3 | aggressive | 0 | 15 | 0 | 0 | 0 | 15 |
| palimpsest | 3 | balanced | 0 | 13 | 0 | 0 | 2 | 15 |
| palimpsest | 3 | no-bonuses | 0 | 13 | 0 | 0 | 2 | 15 |
| palimpsest | 3 | tactical | 2 | 11 | 0 | 0 | 2 | 15 |

No final wall time was recorded. Recorded timeouts are the 35 explicit timeout rows; the 366 missing cases include unknown/unrecorded cancellation progress and must not be relabelled as timeouts or defeats. Four workers and a 180-second per-case timeout were configured. This automated headless measurement is not manual play or a human win-rate estimate.
