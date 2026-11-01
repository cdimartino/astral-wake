# Cartographer production evolutions — #15 partial candidate

All 36 Cartographer commands now offer exactly two permanent, mutually exclusive
evolutions per owned UID. All 72 base definitions (including rarity, unlocks, art,
cost and text) are unchanged. Palimpsest's 18 and Choir's 18 remain **unbranched**
with their generic upgrades. Existing level-1 `legacy` copies keep their exact
generic stats forever, including Cartographer copies; unupgraded copies can choose.
No new cards, enemies, reward rules, conditional routes, ward, refunds or spend
controls. Recovery still trades a 30-hull repair for one evolution; shop service
still costs 35 salvage before existing discounts, charged only on confirmation.

This is a balance-changing **candidate**, not a completed #15 or proof of balance.
Independent review, graphical chooser inspection and a fresh manual expedition
are required before merge. Scalar non-dominance and paired mechanical advantages
cannot establish that all 36 pairs are balanced in real decks or against scaling.

## Complete authored table

IDs in backticks are stable save/replay identities. Names and complete effect prose
are in `data/catalog.json` and the native chooser. Here D = damage, H = hull repair,
V = cooling **every** organ before routing, I = disruption, Draw = cards drawn.
Each entry gives **all nonzero printed payloads**; 1 CP unless explicitly 2 CP.
Link restoration/endpoint connection is inherited by **both** siblings on Graft
Wire, Thread Cannon, Scar Bridge, Long Hem, Star Chart, Whole Horizon and Unbroken
Song. Retain holds an *unplayed* command across turns, not free replay. Exhaust
removes a played command from circulation for that combat. First-free spares only
the first routed organ's strain, not CP. Unmarked branches have none of these flags.

| Base command | Branch A | Branch B | Why choose either? |
| --- | --- | --- | --- |
| Needle | `sunpoint`: 12 D | `held_dawn`: 9 D, Retain | Kill a 12-hull target now, or hold damage for a later safe route/target window. |
| Hull Stitch | `deep_stitch`: 9 H | `coolant_stitch`: 5 H, 1 V | Repair a deep wound, or sacrifice repair to reopen hot organs. |
| Cold Breath | `deep_breath`: 2 V, Draw 1 | `last_breath`: 1 V, Draw 2, Exhaust | Repeatable thermal control versus finite hand burst; draws cannot exceed remaining CP. |
| Quiet Pulse | `hard_pulse`: 10 D, 1 I | `still_pulse`: 6 D, 3 I | Kill threshold versus stronger interruption; extra disruption can be wasted at the defense cap. |
| Graft Wire | `live_wire`: Draw 2 | `reserve_wire`: Draw 1, first-free | Find more commands now versus preserve route capacity; both can self-redraw. |
| Sun Splinter | `sunburst`: 15 D | `banked_sun`: 12 D, Retain | Frontload damage versus keep an attack through a bad turn. |
| Mercy Circuit | `sharp_mercy`: 11 D, 3 H | `gentle_mercy`: 7 D, 6 H | Finish a threat versus repair without giving up all offense. |
| Black Suture | `closed_wound`: 13 H | `ready_suture`: 10 H, Retain | More healing now versus reserve healing until hull is actually missing. |
| Spare Heartbeat | `strong_beat`: 8 H, Draw 1 | `racing_beat`: 3 H, Draw 2 | Wounded survival versus hand access, at a five-hull price. |
| Frost Seam | `warm_seam`: 9 H, 1 V | `ice_seam`: 4 H, 2 V | Deep repair versus wider thermal reopening. |
| Red Interval | `red_peak`: 14 D, 1 V | `blue_interval`: 9 D, 2 V | Kill pressure versus preserving next routes under strain. |
| Wake Lance | `breaking_wake`: 18 D | `waiting_lance`: 14 D, Retain | Immediate heavy hit versus bank a heavy attack for a route window. |
| Glass Murmur | `glass_cry`: 12 D, Draw 1 | `glass_echo`: 7 D, Draw 2 | Five more damage versus one more command found, not one more action granted. |
| Thread Cannon | `heavy_thread`: 12 D | `spooled_thread`: 8 D, Retain | Damage now versus hold link restoration until severing matters. |
| Mute Bell | `dead_bell`: 9 I, Draw 1 | `ringing_bell`: 4 I, Draw 2 | Large interrupt thresholds versus hand access when disruption would overcap. |
| Cold Psalm | `winter_psalm`: 3 V | `remembered_psalm`: 2 V, Retain | Emergency thermal reset versus on-demand cooling on a future turn. |
| Salvage Hymn | `mending_hymn`: 11 H, 1 I | `silencing_hymn`: 6 H, 4 I | Recover past damage versus prevent/interrupt an incoming threat. |
| Votive Shard | `piercing_votive`: 15 D, 1 I | `quiet_votive`: 10 D, 4 I | Kill now versus buy a less damaging enemy phase. |
| Mirror Cut | `cruel_reflection`: 14 D, 2 H | `kind_reflection`: 9 D, 6 H | Offensive threshold versus repair while attacking. |
| Open Channel | `flood_channel`: Draw 3, Exhaust | `patient_channel`: Draw 2, Retain | One-shot burst versus repeatable draw held for useful CP/hand space. |
| Scar Bridge | `broad_bridge`: 9 H | `reserve_bridge`: 6 H, Retain | More repair now versus retain a repair/link answer for later. |
| Winter Needle | `winter_fang`: 12 D, 2 V | `winter_shelter`: 6 D, 3 V | Attack payload versus another unit of global cooling. |
| Hollow Chorus | `loud_chorus`: 13 D, 2 I | `hushed_chorus`: 8 D, 5 I | Damage threshold versus stronger interruption. |
| Seam of Light | `radiant_seam`: 2 CP, 17 H, 2 V | `narrow_seam`: 8 H, 1 V | Two-CP concentrated recovery versus an extra action slot; discount loses nine heal and one vent. |
| Pilgrim Signal | `shelter_signal`: 2 V, Draw 1, 1 I | `warning_signal`: 1 V, Draw 1, 4 I | Thermal safety versus targeted enemy control, not blanket extra draw. |
| Long Hem | `cutting_hem`: 17 D | `folded_hem`: 13 D, Retain | Frontload offense versus retain an attack/link answer. |
| Blue Refrain | `deep_refrain`: 2 CP, 7 H, 3 V, Draw 1 | `brief_refrain`: 2 H, 1 V, Draw 1 | Big thermal repair versus cheap cycling; discount loses five heal and two vent. |
| Last Match | `bright_match`: 18 D, 1 I | `banked_match`: 14 D, 1 I, Retain | Immediate damage versus keep a useful attack across a poor turn. |
| White Noise | `deafening_noise`: 1 V, 11 I | `cooling_noise`: 2 V, 6 I | Large interruption versus thermal reset when disruption is capped. |
| Star Chart | `flaring_chart`: Draw 3, Exhaust | `folded_chart`: Draw 2, Retain | Finite burst/link repair versus a repeatable, timed link/draw answer. |
| Ember Abacus | `burning_sum`: 2 CP, 18 D, 2 V, Draw 1 | `small_sum`: 9 D, 1 V | Burst plus cooling/draw versus one-CP access; discount loses nine damage, vent and all draw. |
| Kindly Static | `deep_static`: 2 CP, 14 H, 4 I | `brief_static`: 6 H, 2 I | Concentrated repair/control versus a cheap supporting action; discount loses eight heal and two disruption. |
| Afterimage | `vivid_image`: 2 CP, 17 D, Draw 2 | `faint_image`: 7 D, Draw 1 | Large damage and hand burst versus an affordable one-CP attack; discount loses ten damage and one draw. |
| Deep Winter | `winter_storm`: 2 CP, 4 V, Draw 2 | `winter_flurry`: 2 V | Deep reset/hand refill versus cheap cooling; discount loses two vent and all draw. |
| Whole Horizon | `wide_horizon`: 2 CP, 21 D, 6 H, Exhaust | `near_horizon`: 9 D, 2 H | Short-fight burst versus cheap repeatable attack/link repair; discount loses twelve damage and four heal, but avoids exhaustion. |
| Unbroken Song | `full_song`: 2 CP, 17 H, 3 V, Draw 1 | `short_song`: 7 H, 1 V | Large combined reset versus a supporting action; discount loses ten heal, two vent and all draw. |

## Strategic opportunities and difficulty

1. **Frontload or bank attacks.** Lens/Echo/Fork routing makes immediate damage
   thresholds valuable. Retained attacks give control over *when* to route, at the
   cost of lower printed damage and occupied hand space. They do not increase CP.
2. **Thermal repair hybrid.** Stitch, Frost Seam, Winter Needle and Refrain trade
   output for cooling. Vent can reopen multiple organs, but is wasted on a cool
   ship; pure repair can be wasted at full hull. Those valuations change during a run.
3. **Kill, interrupt or repair.** Pulse, Hymn, Static and Noise can support defense
   instead of racing damage. Attacks keep their half-damage defense cap; special
   actions with interrupt thresholds can be stopped at the printed threshold.
   These are distinct rules: more disruption does not cancel a whole attack.
4. **Two-CP concentration versus one-CP sequencing.** Discount branches surrender
   real payloads. Large branches can win short fights; cheap branches leave room
   for other commands. Exhaust creates future loss, not an automatic upside.

Enemy scaling is unchanged. These choices are intended to make demanding fights
more deliberate, not guarantee wins or flatten difficulty. Retain, cooling and
draw require actual timing decisions; drawing at zero CP is not a new action.
Ordinary cards enter discard **before** drawing and may self-redraw. Exhausting
draw branches cannot self-redraw, and extra draw can be wasted by a thin pile or
the hand limit. All these are existing resolver semantics.

## Simulation boundary

The named evolution policy version is `cartographer-branches-v1`, emitted with
playthrough results. `plan_modify_branches()` scores each effective branch and
returns explicit stable UID → ID choices. Printed damage + repair (2.1 below 60
hull, otherwise 1.1) + vent×5 + disruption×1.6 + draw×2 is normalized by CP.
Aggressive uses damage/CP only; tactical additionally weights repair/disruption.
Ties use lexical branch ID, never array order. The existing intrinsic base-card
ranking for upgrade/removal and **all unbranched behavior** remain unchanged.
Only branch selection is new; it does not pretend to model Retain timing, future
Exhaust loss, draw saturation or exact enemy interrupt thresholds optimally.
Tests show aggressive/tactical Pulse choices and healthy/wounded Stitch choices
can oppose one another, and branch array reordering cannot change the score winner.

Catalog and policy source fingerprints intentionally change. Historical matrices
in `docs/baselines/` are **not recomputed, pooled, replaced or current balance
evidence**. Their old source/policy fingerprints remain historical and do not match
this candidate. Any new population must be separately labelled/fingerprinted;
there is no new win-rate claim or requirement that an automated policy win.

## Native review and manual expedition

Use the main checkout's absolute engine; always isolate scratch saves:

```sh
GODOT=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
DEMO=$(mktemp -d "$TMPDIR/astral-production-chooser.XXXXXX")
ASTRAL_SAVE_DIR="$DEMO" "$GODOT" --path . --script tests/evolution_demo.gd
```

This demo is a **labelled recovery counterfactual** for Cartographer `0093CG`, pool
0. It uses actual production starter cards, no fake overrides or route automation.
Inspect Needle, Stitch, Breath, Pulse and Wire before/after text, both branches,
CP, service price, Retain/Exhaust/first-free, cancel and confirm. It is not a played
expedition and must not replace the primary manual run. To drive this same
counterfactual with guarded commands, use `tests/production_evolution_driver.gd`
instead of `tools/manual_replay.gd` below; its session source is fingerprinted.

**Primary fresh manual expedition** (lead/reviewer chooses every decision):

```sh
SESSION="$TMPDIR/astral-cartographer-primary-$(uuidgen)"
"$GODOT" --headless --path . --script tools/manual_replay.gd -- \
  --session="$SESSION" --start=0093CG --ship=cartographer --unlocks=0
```

Use [manual replay commands](manual-replay.md) to inspect, travel, preview routes,
play and end turns. At a real recovery, choose repair or upgrade deliberately.
For a selected copy, take UID, branch and the latest guard from inspection:

```json
{"op":"modify","uid":1,"branch":"held_dawn","expect":{"step":0,"state":"COPY_LATEST_HASH"}}
```

Pass via `--resume=true --command='JSON'`; do not reuse stale guards. Replay the
trace into a fresh session. Separate paired recovery arms must be labelled
counterfactuals, not substituted for the primary expedition. `0093CJ` pool 3 is a
**different experiment**, not a repeat of `0093CG` pool 0. No manual decision
automation is introduced. Native/demo smoke tests do not replace human review.

## Gates and remaining work

- Python gate compares the entire catalog with a pinned canonical SHA-256 from
  infrastructure commit `63fbd24` (so shallow checkouts also work)
  after removing authored evolutions: every base field and non-card group matches.
  It checks 36 pairs, no branches on the later ships, strict flag types and scalar
  non-dominance (necessary but deliberately not called a balance proof).
- Godot production tests evolve all 72 alternatives by UID, check exact replacement
  stats, actual payload/CP against preview and existing flag semantics. Six paired
  scenarios demonstrate both advantages: Needle kill/retention, Stitch repair/vent,
  Breath cooling/draw with and without spare CP, Wire draw/first strain including
  self-redraw, Pulse kill/interrupt including filled defense cap, Horizon burst/cheap
  repeatability and exhausted future loss.
- The 432 frozen legacy outcomes remain untouched. Fixture infrastructure tests
  remain separate. Native chooser tests additionally cover actual production
  text, price, cancellation and paid confirmation; production separate-process
  tests cover explicit identity, reload, replay and stale source rejection.
- **#15 remains partially complete:** Palimpsest/Choir authoring is deferred, and
  independent balance review plus native/manual expedition evidence is outstanding.

### Candidate validation — 2026-10-31

- `GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
  ASTRAL_AUDIO_DRIVER=Dummy bash tools/check.sh` completed with **exit 0**. It
  includes core rules (11,543 checks), effective definitions (2,087, including all
  432 frozen outcomes), evolution infrastructure (102), production branches (822
  at full-run time), chooser (13), all remaining suites, both intro modes, audio
  smoke and the tactical legacy-seed smoke. That single automated victory is not
  a balance population, human expedition or new win-rate claim.
- Final targeted production run passed **825 checks**, adding the special-action
  interrupt scenario; the final pinned-base Python gate and Python syntax checks
  passed too. Production and fixture replay each passed 10 separate-process checks.
  The new adapter also fingerprints its own session/driver source.
- Failures were retained, not retried away: an initial full run stopped after
  combat presentation with shell exit 127 because `tools/check.sh` was edited
  during execution; the next full run stopped at a new adapter's static-method
  signature error (surfacing as a process timeout). After that adapter correction,
  the full run above passed. A subsequent added test initially assumed an attack
  could be completely interrupted; that incorrect assertion failed, was replaced
  with an actual interruptible **strain** action plus the separate attack cap, and
  the final 825-check run passed. No resolver behavior was changed to satisfy it.
- Logs remain under the approved temporary directory
  `/private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/` as
  `issue15-full-initial.log`, `issue15-full-final.log` (the adapter failure) and
  `issue15-full-adapter-fixed.log` (exit 0). No historical captures were edited.
- Native demo was **smoke-started headlessly only** with fresh scratch saves.
  Full-suite/native shutdowns emitted ObjectDB/resource-leak diagnostics despite
  successful process exits. Graphical readability and the required independent
  manual expedition have **not** been validated by this implementation session.
