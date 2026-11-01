# Palimpsest production evolutions — #15 candidate

This slice adds exactly two named evolutions to each of Palimpsest's 18 cards.
Every base field and non-card catalog group, and all 36 Cartographer pairs, are
unchanged from `cf175c7`. Choir's 18 remain unbranched. Existing level-one copies
remain `legacy` with their exact old arithmetic; level-zero copies choose by UID.
The 432 frozen legacy outcomes are not regenerated. No resolver, enemy, starter,
reward, resource cap, spend rule or effect primitive changes.

These are **starting hypotheses**, not proof of balance or completed #15.
Scalar non-dominance does not establish equally useful choices in full runs.
Independent review and the lead's fresh frozen-candidate manual expedition remain
necessary. Greedy simulation defeat must not be presented as ship unviability.

## Complete authoring table

Entries below are **absolute overrides**, not increments. Every omitted field is
inherited, including kind, Rewrite, link, and cost. All costs remain 1 or 2 CP;
only Loose Leaf changes cost. Names and complete printed effect descriptions live
in `data/catalog.json`; keyword explanations are appended by the existing UI.
Retain holds this unplayed card, not another card, and never grants free replay.

| Card ID | A: stable branch ID / overrides | B: stable branch ID / overrides | Concrete reason to prefer either |
| --- | --- | --- | --- |
| `margin_knife` | `keen_margin`: damage 11 | `inscribed_margin`: damage 7, trace 2 | More primary damage versus reaching Splice's two-Trace split threshold from empty. |
| `pale_patch` | `layered_patch`: heal 8 | `annotated_patch`: heal 5, trace 2 | Survive missing hull versus sacrifice three repair for another Trace; overflow removes that benefit. |
| `carbon_breath` | `cool_carbon`: vent 2 | `carbon_imprint`: draw 0, trace 3 | Global cooling plus finding a playable command versus surrendering cycling and cooling for a later Recall. |
| `first_draft` | `decisive_draft`: damage 9 | `working_draft`: damage 6, trace 3 | Three more immediate damage versus one more banked Trace; cap overflow favors A. |
| `ghost_line` | `etched_line`: trace 2, draw 1 | `waiting_line`: retain true | More inscription now versus more cycling and a link-restoration answer held for severing. |
| `revision_spike` | `piercing_revision`: damage 15 | `pending_revision`: damage 12, retain true | Kill threshold now versus access to a later exposed phase or stocked Recall. |
| `vellum_shield` | `layered_vellum`: heal 6 | `sealed_vellum`: heal 3, disrupt 3 | Repair past damage versus interrupt three-point setup; neither generates ward. |
| `cut_sentence` | `sharp_sentence`: damage 10 | `silencing_sentence`: damage 6, disrupt 4 | Primary kill pressure versus interrupt a four-point action; extra suppression is wasted at attack-defense cap. |
| `borrowed_dawn` | `searing_dawn`: damage 11 | `kindled_dawn`: heal 6 | Same two-CP Rewrite spend, biased toward killing or repairing. |
| `ink_well` | `cold_ink`: vent 3 | `dense_ink`: vent 1, trace 3 | Saturated-ship recovery versus another Trace with substantially weaker cooling. |
| `overwrite` | `forceful_overwrite`: damage 9 | `deferred_overwrite`: damage 6, retain true | Stronger immediate/copyable damage versus holding Rewrite for later setup. Retain does not reserve the previous payload. |
| `scar_note` | `restorative_note`: heal 10 | `cooling_note`: heal 7, vent 2 | More hull versus more global thermal headroom. |
| `lost_paragraph` | `struck_paragraph`: disrupt 8, draw 0 | `reserved_paragraph`: disrupt 5, retain true | Eight-point suppression without cycling versus a held cycling interrupt; five-point B already stops many special actions. |
| `double_exposure` | `burned_exposure`: damage 12, draw 0 | `latent_exposure`: damage 9, retain true | Sacrifice replacement draw for damage versus bank the existing cycling Rewrite. |
| `final_revision` | `definitive_revision`: damage 15 | `reserved_revision`: damage 12, retain true | Two-CP burst versus holding a finisher for a better window. |
| `memory_lattice` | `woven_memory`: heal 8 | `inscribed_memory`: heal 5, trace 3 | Link restoration with better repair versus stronger inscription at lower hull efficiency. |
| `blank_page` | `clean_slate`: vent 3 | `loose_leaf`: cost 1, vent 1, trace 1 | Stronger two-CP cooling/refill versus another affordable action; the discount explicitly loses two vent and one Trace relative to A. |
| `second_history` | `restored_history`: heal 12 | `unwritten_history`: heal 9, retain true | Larger repair/copyable heal versus keeping a repair-kind Rewrite until hull/setup warrants it. |

## Timing and balance risks

- Printed Trace is added **before organs**, capped at six. First Draft at one Trace
  becomes three/four before routing, five/six after Scribe. At five stored Trace,
  either branch gains only one actual point. Recall converts each spent point to
  two damage; Splice switches from +2 primary damage to split at two Trace.
- Rewrite spends all Trace before organs and copies half the previous **printed**
  damage, healing and disruption, rounded down, only on positive spend. Runtime
  Recall/Rewrite additions, Trace, cost, vent, draw and flags never enter that copy.
  Retained Overwrite may follow an intervening utility and copy zeros instead of
  the attack that preceded retention. Scribe after Rewrite refills for organs,
  not retroactively for the card's already-evaluated spend.
- Disruption caps ordinary attack prevention at half damage. Interruptible setup
  uses its own explicit threshold. Repair can be wasted at full hull; suppression
  can be wasted at a filled defense cap. Neither becomes ward.
- Vent affects all organs before new route strain but **after route validation**.
  A saturated entry cannot be legalized by the card's own cooling. Blank Page's
  economy scenario starts with one legal entry and five saturated organs.
- Highest-risk improvements are extra Trace (especially early Splice/Recall),
  retained Rewrite timing, global vent 3, and Loose Leaf's extra action economy.
  Seven Retain branches are deliberately not declared equal to +3 damage/heal:
  they occupy hand space and require future CP, but may be stronger in practice.
  Lost Paragraph B and Double Exposure B combine existing cycling with retention;
  test whether their sacrificed immediate payload is sufficient.
- Existing expensive comparisons are not hidden by huge buffs. Borrowed Dawn
  still pays an extra CP over Overwrite for a modest hybrid payload; Final Revision
  pays for concentrated damage. Blank Page's extra CP over Ink Well buys cycling.
  Test whether these remain unattractive acquisitions, independently of siblings.
- Recovery still offers 30 hull instead of evolving. At critical hull, neither a
  small repair increment nor held future burst substitutes for that immediate heal.

## Policy boundary — `palimpsest-branches-v1`

Only Palimpsest branch scoring gains Trace valuation: **0.6 per point / CP** in
balanced, aggressive and tactical goals. In combat it counts available headroom,
not overflowing printed gain; outside combat it assumes empty Trace because the
upgrade location has no upcoming combat resource state to predict. This modest
term cannot overwhelm First Draft's three-damage gap. Other printed-stat weights,
intrinsic base-card upgrade/removal ranking, and all Cartographer decisions remain
unchanged. Cartographer still reports `cartographer-branches-v1`; Palimpsest reports
`palimpsest-branches-v1`. Choices are explicit UID → branch ID with lexical tie
breaking, never the first branch in an array.

This is a greedy heuristic: it does **not** value future Retain access, copy setup,
future Exhaust loss, exact interrupt/split thresholds, or deep deck sequencing.
It commonly selects frontloaded damage. Tests verify resource headroom, opposing
aggressive/tactical Cut Sentence choices and array-order independence; they do not
claim optimal play. Historical `docs/baselines/` matrices remain untouched and are
not pooled with this catalog/policy version. Any new matrix needs separate source
fingerprints, policy labels and interpretation.

## Tests and native recovery counterfactual

`tests/production_evolutions_test.py` pins the entire `cf175c7` canonical catalog
after removing only Palimpsest evolutions; it also retains the original stripped
base checksum, all Cartographer flag mutation tests, scalar non-dominance, and the
Choir-unbranched gate. The exact 18 override pairs are independently enumerated.

`tests/palimpsest_evolutions_test.gd` exercises all 36 alternatives: strict schema,
inherited fields, UID selection, pure preview/actual agreement, CP, resource order,
plain payloads, actual save/reload and corrupted last-command identity rejection.
Paired counterfactual groups demonstrate both tactical advantages, not full wins:

1. First Draft damage now versus banked Recall payoff, caps/overflow; Margin split.
2. Carbon cooling/cycling with CP available versus Trace-backed later Recall.
3. Overwrite immediate burst versus next-turn access, including intervening utility.
4. Borrowed Dawn/Final Revision burst versus healing/retention; positive-spend
   floor-half copy chains exclude runtime additions.
5. Vellum/Cut repair/damage versus actual setup interruption, including full-hull
   repair waste and already-capped ordinary defense.
6. Blank Page thermal/Trace advantage versus an actual affordable next Recall.

An additional Ghost Line pair checks generation versus cycling/retention. Existing
fixture infrastructure and all 432 frozen compatibility outcomes remain separate.
Native node assertions cover production starter names/full text, cancellation,
chosen hover/deck identity and a paid nonstarter Blank Page CP comparison. Process
replay covers explicit Palimpsest identity, invalid choices, reload, fresh replay,
and source-fingerprint rejection with the existing stable-UID driver.

For a **native production-starter recovery counterfactual**, never player data:

```sh
GODOT=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
DEMO=$(mktemp -d "$TMPDIR/astral-palimpsest-workshop.XXXXXX")
ASTRAL_SAVE_DIR="$DEMO" "$GODOT" --path . --script tests/evolution_demo.gd -- --ship=palimpsest
```

The demo calls `new_run("0093CG", "palimpsest")`, uses the untouched starter deck,
and labels itself a recovery counterfactual. Choose upgrade, inspect the actual
branches and cancel/confirm deliberately. It is **not** a primary expedition.
The existing `tests/production_evolution_driver.gd` also accepts `--ship=palimpsest`
for guarded counterfactual/replay commands. The lead launches the separate fresh
manual expedition only against the frozen review candidate; this implementation
session does not start or automate it.

## Candidate validation — 2026-11-01

- Final `GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
  ASTRAL_AUDIO_DRIVER=Dummy bash tools/check.sh` completed with **exit 0** using
  isolated saves. This includes core rules (11,543), effective definitions (2,087,
  including all 432 frozen outcomes), infrastructure (102), unchanged Cartographer
  production gate (825), Palimpsest mechanics/policy (1,092), both chooser suites,
  all replay gates, remaining suites, both intro modes and audio smoke. The final
  Cartographer tactical legacy-seed smoke won and still reported
  `cartographer-branches-v1`; this is not Palimpsest balance evidence or a new
  win-rate population. Final log: `pal-full-adapter-fixed.log`.
- Targeted Palimpsest mechanics/policy gate: **1,092 checks, zero failures**.
  Native chooser node assertions: **34 checks, zero failures**. Palimpsest's
  separate-process explicit-choice/reload/replay/source-rejection gate: **10
  process checks passed**. Direct comparison with `git show cf175c7:data/catalog.json`
  confirmed exactly 18 Palimpsest evolution additions and no other catalog change.
  Historical baseline tooling's nine Python unit tests and Python syntax checks
  also passed; no historical captures were recomputed or edited.
- Native graphical demo was smoke-launched with fresh scratch data and
  `--quit-after 180 -- --ship=palimpsest`, exiting zero on Apple M1 Max/OpenGL.
  This establishes native startup, not human readability inspection or a played
  expedition. No primary manual expedition was started by this session.
- Initial targeted failures were test-setup mistakes: an enemy's next exposed
  phase added damage after an end-turn, and cancellation cleared pending service
  metadata before a second confirmation setup. Both fixtures were corrected;
  production rules were not changed to satisfy assertions.
- The first two full runs stopped at the existing noncombat manual-adapter test:
  first its obsolete implicit Palimpsest upgrade, then its reset of successful
  entries without resetting newly recorded rejected attempts. The test now checks
  explicit-choice rejection/confirmation and starts its labelled new fixture
  chain by clearing both collections. The targeted adapter passes **48 checks**;
  journal validation and production adapter code remain unchanged.
- UI shutdowns emitted ObjectDB/resource-in-use diagnostics despite zero assertion
  failures and successful exit codes. They are recorded, not suppressed or called
  graphical evidence. Logs are under the approved temporary directory
  `/private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/`:
  `pal-target-initial.log`, `pal-target-second.log`, `pal-target-fixed.log`,
  `pal-ui-initial.log`, `pal-native-demo.log`, `pal-full-initial.log`,
  `pal-full-final.log` and `pal-full-adapter-fixed.log`.
