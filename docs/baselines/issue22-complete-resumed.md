# Fully recorded frozen baseline — issue #22

All 720 planned cases have records; 35 are unresolved timeouts, not defeats or resolved expedition outcomes. This cumulative capture preserves the 354 interrupted integration rows and adds only the 366 previously absent cases. Earlier captures are unchanged and must not be added to these counts.

Capture SHA-256: `50a1666218ed4c3d564f7c01a287af5efb58f8e30af796dcccdedce9b355bdc8`. Raw JSONL size: 1,297,531 bytes.

Revision: `5a616c60e9380e83d9d8895bfaf6bb361c383d05`; engine: `4.7.2.stable.official.ed1daf0bf`

Recorded 720/720 cases; missing 0.
Statuses: {'defeat': 544, 'timeout': 35, 'victory': 141}
Wall time (this invocation only): 937.623 seconds.
Resume: 354 retained rows; revision relationship: explicit-compatible-fingerprints.

| Ship | Tier | Policy | Wins | Defeats | Errors | Unfinished | Timeout | Missing |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cartographer | 0 | aggressive | 0 | 28 | 0 | 0 | 2 | 0 |
| cartographer | 0 | balanced | 12 | 16 | 0 | 0 | 2 | 0 |
| cartographer | 0 | no-bonuses | 0 | 28 | 0 | 0 | 2 | 0 |
| cartographer | 0 | tactical | 19 | 9 | 0 | 0 | 2 | 0 |
| cartographer | 3 | aggressive | 0 | 28 | 0 | 0 | 2 | 0 |
| cartographer | 3 | balanced | 12 | 16 | 0 | 0 | 2 | 0 |
| cartographer | 3 | no-bonuses | 0 | 29 | 0 | 0 | 1 | 0 |
| cartographer | 3 | tactical | 23 | 6 | 0 | 0 | 1 | 0 |
| hollow_choir | 0 | aggressive | 0 | 30 | 0 | 0 | 0 | 0 |
| hollow_choir | 0 | balanced | 8 | 20 | 0 | 0 | 2 | 0 |
| hollow_choir | 0 | no-bonuses | 0 | 29 | 0 | 0 | 1 | 0 |
| hollow_choir | 0 | tactical | 22 | 7 | 0 | 0 | 1 | 0 |
| hollow_choir | 3 | aggressive | 0 | 30 | 0 | 0 | 0 | 0 |
| hollow_choir | 3 | balanced | 11 | 18 | 0 | 0 | 1 | 0 |
| hollow_choir | 3 | no-bonuses | 0 | 28 | 0 | 0 | 2 | 0 |
| hollow_choir | 3 | tactical | 18 | 9 | 0 | 0 | 3 | 0 |
| palimpsest | 0 | aggressive | 0 | 30 | 0 | 0 | 0 | 0 |
| palimpsest | 0 | balanced | 0 | 29 | 0 | 0 | 1 | 0 |
| palimpsest | 0 | no-bonuses | 0 | 28 | 0 | 0 | 2 | 0 |
| palimpsest | 0 | tactical | 7 | 21 | 0 | 0 | 2 | 0 |
| palimpsest | 3 | aggressive | 0 | 30 | 0 | 0 | 0 | 0 |
| palimpsest | 3 | balanced | 0 | 28 | 0 | 0 | 2 | 0 |
| palimpsest | 3 | no-bonuses | 0 | 28 | 0 | 0 | 2 | 0 |
| palimpsest | 3 | tactical | 9 | 19 | 0 | 0 | 2 | 0 |

The 937.623-second wall time covers only the resumed invocation, not the interrupted segment or the entire experiment. The 35 timeouts were inherited unchanged; no recorded timeout or other result was retried. No errors or action-limit unfinished results were recorded.

## Provenance and interpretation

- Clean resumed measurement revision: `5a616c60e9380e83d9d8895bfaf6bb361c383d05`, using the frozen historical gameplay sources, not latest-main gameplay. Parent revision: `1cd5596a653c7dfe66c3d976f96f88c6c2d61fa1`.
- Parent capture SHA-256: `e2129b83c1fc8a8fe856330e6c50da6f46eb5f546d7edfa153a23d7441bd83a1`. All 354 inherited result dictionaries and original metadata match the preserved interrupted capture exactly; the 354 inherited JSONL row byte strings are also identical.
- Engine, generation version, full ordered seed/case plan, all four recorded source hashes, and 180-second timeout match the parent. Git object contents at both historical revisions independently match those source hashes. Resume explicitly labels the revision difference as compatible fingerprints. Four workers were used. The original fingerprint scope is the rules, RNG, catalog, and playthrough driver; it is not a fingerprint of every repository file.
- Tactical victories: Cartographer **42/60**, Hollow Choir **40/60**, Palimpsest **16/60** scheduled cases, each across both tiers. These are observed policy counts, not human win rates or proof of optimal ship viability; timeouts are included in the scheduled denominator and are unresolved, not losses.
- Tier 0 and tier 3 use different encoded seeds/RNG initializations. Their comparison is not a discoveries-only ablation. No-bonuses also changes several between-battle choices, not only upgrades.
- Automated headless rules expeditions only; no graphical/manual UX evidence. The original seed-777 loss is unchanged.

## Future comparisons

Freeze these same 720 ship/tier/policy/seed cases for before/after comparisons. Report changed source revision/fingerprints, per-case paired outcomes, resolved wins/defeats, and timeouts separately; do not silently retry or replace inherited timeouts. Any timeout follow-up needs a separate labelled runtime experiment. Tactical outperformed the simpler policies in recorded victories on this set, including Palimpsest where balanced recorded none, motivating decision-sensitive checks and improved planning rather than an enemy nerf or guaranteed win-rate target. Do not attribute the gap to one mechanic without controlled ablations. Expansion ablations, audited action replay evidence, and graphical human expeditions remain separate requirements: issue #22 remains open.
