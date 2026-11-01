# Hollow Choir production evolutions — #15 candidate

Exactly two named evolutions are now authored for each of Choir's 18 cards: all
72 production cards have pairs. This candidate adds only Choir evolution data to
the `f66fe8e` catalog. All base fields, Cartographer/Palimpsest branches and non-card
groups are pinned unchanged. No resolver, migration, enemy, reward, starter,
resource cap, kind rule or effect primitive changes. Old level-one copies remain
`legacy`; new level-zero copies choose explicitly by stable UID.

This completes **authoring coverage**, not #15 acceptance or a balance proof.
Review, native inspection and the lead's frozen-candidate manual expedition are
still separate gates. The earlier Palimpsest manual defeat is neither a Choir
comparison nor evidence that greedy loss establishes ship unviability.

## All 18 pairs

Entries are absolute overrides, not increments. Omitted fields inherit unchanged,
including kind, cost, resource gain, link and Concert. Only Light Shell changes
cost. Names and complete effect descriptions are in `data/catalog.json`; existing
UI keyword text explains Retain/first-free without repeating it in descriptions.

| Card ID | A: stable branch ID / overrides | B: stable branch ID / overrides | Tactical tradeoff |
| --- | --- | --- | --- |
| `choral_bolt` | `piercing_chorus`: damage 11 | `gathering_chorus`: damage 7, resonance 1 | Immediate kill threshold versus rebuilding after a repeated attack or reaching Chorus split sooner. |
| `warm_refrain` | `full_refrain`: heal 8 | `waiting_refrain`: heal 6, retain true | More emergency repair versus retaining a repair-kind bridge for later sequencing. |
| `silent_measure` | `cool_measure`: vent 2 | `gathered_measure`: draw 0, resonance 2 | Global cooling and replacement draw versus surrendering cycling/cooling for resource generation. |
| `call_and_response` | `strong_call`: damage 9, draw 0 | `waiting_response`: damage 6, retain true | Frontloaded damage versus holding the existing cycling/resource attack for a useful kind transition. |
| `tuning_fork` | `clear_tuning`: disrupt 5 | `gathered_tuning`: disrupt 3, resonance 2 | Five-point interruption versus more generation when prevention is already capped. |
| `bright_canon` | `blazing_canon`: damage 15 | `held_canon`: damage 12, retain true | Larger Concert burst versus keeping the finisher for the right phase/sequence. No refund. |
| `breath_between` | `deep_rest`: heal 6 | `cool_rest`: heal 3, vent 2 | Repair missing hull versus more thermal headroom; inherited resource gain is identical. |
| `dissonant_edge` | `cutting_dissonance`: damage 10 | `silencing_dissonance`: damage 6, disrupt 4 | Kill pressure versus interrupt thresholds; extra suppression can be wasted at the ordinary attack cap. |
| `shared_pulse` | `driving_pulse`: damage 9 | `sustaining_pulse`: damage 5, heal 5 | Offensive hybrid versus sacrificing four damage for two repair; both keep attack kind and existing generation. |
| `counterpoint` | `light_counterpoint`: draw 2, first_free true | `gathered_counterpoint`: draw 1, resonance 2 | More cycling and less entry strain versus one more resource at the expense of a draw. |
| `crescendo` | `rising_crescendo`: damage 13 | `restorative_crescendo`: damage 10, heal 3 | Burst versus guaranteed healing, potentially amplified by a later Crescendo organ after resource refill. |
| `hushed_chord` | `muted_chord`: disrupt 8, vent 0 | `cool_chord`: disrupt 5, vent 2 | Strong suppression without cooling versus thermal control and lower suppression. |
| `orbital_round` | `striking_round`: damage 12, draw 0 | `waiting_round`: damage 9, retain true | Sacrifice cycling for damage versus keeping a cycling attack for a future kind/exposure window. |
| `harmonic_bridge` | `strong_harmony`: heal 7 | `gathered_harmony`: heal 4, resonance 2 | Repair/link restoration versus more generation with weaker hull recovery. |
| `grand_concert` | `triumphant_concert`: damage 15 | `restorative_concert`: heal 7 | Offensive versus restorative Concert; both inherit the hybrid payload and two-CP cost. |
| `resonant_shell` | `full_shell`: heal 10 | `light_shell`: cost 1, heal 5, resonance 1 | Concentrated repair/refill versus an extra CP for sequencing, explicitly losing repair and resource gain. |
| `rest_note` | `deep_silence`: vent 3, draw 0 | `held_silence`: vent 2, retain true | Deeper cooling without cycling versus holding existing cooling/draw for later saturation. |
| `unison` | `striking_unison`: damage 13 | `sustaining_unison`: damage 9, heal 3 | Attack/link burst versus weaker damage with guaranteed healing and possible organ amplification. |

## Exact mechanics and high-risk improvements

- Automatic kind logic occurs **before printed gain**: a different previous kind
  gains one, a repeated kind resets to zero, and a first command has no automatic
  kind gain. Printing is then added with the three-point cap. Conductor separately
  gains one on first/different kind only; it does not override a repetition.
- Repeating Choral Bolt with three stored Resonance gives A zero/B one before
  organs; Dissonance adds one/two disruption. Following a nonattack from zero gives
  A one/B two: Chorus makes A 12 primary damage, B seven primary plus three to each
  secondary target. Preview result `damage` totals actual damage across targets;
  route steps preserve primary payload and UI lists the split separately.
- Concert spends **before organs**. Bright Canon after a nonattack at two gains
  the third point, spends it for A 21/B 18 damage and three repair, then has zero
  resource entering organs. Conductor can rebuild one; Chorus then falls back,
  not split using the already-spent three. More damage never refunds CP.
- Retain keeps an unplayed card, not its resource state or previous kind. Held
  Warm Refrain after repair still resets three to its printed one, and a held
  Concert after another attack loses the banked resource before spending. The
  five Retain choices consume hand space and future CP; they are not free replay.
- Counterpoint A inherits one Resonance, draws two and spares **only the first**
  organ's strain. B prints two and draws one. Neither refunds CP or legalizes an
  initially saturated entry. After repeated utility, neutral routing leaves one
  versus two; Rest can add one to either. Extra draw at zero CP is not an action.
- Full/Light Shell after a repair reset produce two/one printing; Rest yields
  eleven repair/three Resonance versus six/two, leaving one/two CP. Light Shell
  can then afford a two-CP Concert. After a different kind at two stored points,
  automatic gain already fills the cap and both printed gains overflow.
- Crescendo/Unison B add positive **printed healing**, but remain attacks. At zero
  Concert spend, Conductor can gain one before Crescendo organ: the organ adds two
  healing only to a positive channel, so B repairs five while A repairs zero.
  Rest grants neither its healing nor resource bonus to these attack cards. At
  positive Concert spend, Concert itself already creates healing on A as well.
- **High risks:** cheap Shell action economy, resource thresholds after repetition,
  retained Concert timing, global vent 3, and new printed healing on Concert
  attacks. Test resource caps, full hull, interrupt thresholds and enemy exposure,
  not just printed numbers. Ordinary attack prevention remains capped at half
  damage; a setup action uses its separate interrupt threshold.
- **Existing bad comparison preserved:** base Crescendo costs two CP and has the
  same kind/Concert as Bright Canon but only ten versus twelve damage. This slice
  does not rebalance that base dominance or hide it with a huge branch buff.
  Full Shell's two-CP acquisition value versus cheap existing repair/generation
  also remains an open deck-level question.

## Policy — `choir-branches-v1`

Only Choir gains a new scoring term: **0.8 per printed Resonance point / CP** in
balanced, aggressive and tactical goals, matching the existing combat-forecast
resource weight. In combat, available headroom is computed **after** the automatic
kind transition/reset, before printing; overflow scores zero. Outside combat,
there is no future combat sequence to predict, so branch selection assumes empty
Resonance. The four-damage Choral gap outweighs one resource. Tests verify this
across goals, cap overflow, opposing Dissonant Edge choices, array-order
independence, and actual explicit UID confirmation of the selected identity.

Cartographer and Palimpsest scoring/versions remain `cartographer-branches-v1`
and `palimpsest-branches-v1`. Intrinsic base-card upgrade/removal ranking and all
other policy decisions remain unchanged. This greedy heuristic does **not** model
future sequence, Retain timing, future Exhaust loss, exact split/interrupt
thresholds, or Concert planning. It may favor immediate damage and is not an
optimal playability oracle. Historical matrices remain untouched; new populations
must carry separate catalog/policy fingerprints and must not be pooled with them.

## Gates and evidence boundaries

- Python gates pin every base/non-card field and all prior branches against the
  canonical `f66fe8e` catalog with only Choir evolutions removed. The original
  stripped-base and Cartographer pins remain. All 72 pairs pass strict schema,
  exact authored override tables for the new ships, typed flags/resources and
  scalar non-dominance. This is necessary validation, not a balance proof.
- `tests/choir_evolutions_test.gd` checks all 36 alternatives: inherited fields,
  explicit UID selection, pure preview/actual agreement, printed cost/payload,
  resource order/caps, actual save/reload and corrupt recorded identity rejection.
  Six paired groups demonstrate both advantages: Choral kill/resource-split,
  Warm repair/future-kind access, Tuning setup interrupt/capped-defense generation,
  Bright burst/retained access, Counterpoint cycling/entry strain versus generation,
  Shell repair/refill versus affordable next Concert. Additional Crescendo/Unison
  tests isolate positive printed-healing amplification and unchanged attack kind.
- All 432 frozen legacy outcomes, Cartographer's 825 checks and Palimpsest's 1,092
  remain separate unchanged gates. The unbranched one-argument API compatibility
  test now uses an explicitly local unbranched fixture: no production card is
  unbranched anymore. Resolver/migration behavior is not modified.
- Native node assertions inspect real starter names, full prose, CP, Retain and
  cancel/confirm; labelled nonstarter fixtures inspect Counterpoint first-free and
  paid Shell discount choices. Separate-process replay covers Choir explicit
  identity, rejected choices, reload, fresh replay and stale source rejection.
- **Remaining #15 criteria:** independent review/native inspection and the lead's
  fresh manual expedition/exact replay of this frozen candidate; broader seeded
  sibling comparisons (including when recovery healing is better than evolving),
  sufficient deck/encounter coverage and calibration. These limited
  counterfactuals do not show every pair balanced, every branch played, or the
  demanding difficulty preserved across the full pool. Unsupported original issue
  examples (refunds, printed ward, capped spending, conditional route effects) are
  still future primitives, not secretly implemented here. Do not close #15 solely
  because all 72 cards now have data.

## Safe native recovery counterfactual

```sh
GODOT=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
DEMO=$(mktemp -d "$TMPDIR/astral-choir-workshop.XXXXXX")
ASTRAL_SAVE_DIR="$DEMO" "$GODOT" --path . --script tests/evolution_demo.gd -- --ship=hollow_choir
```

This calls `new_run("0093CG", "hollow_choir")` with the untouched production starter
deck and a visible recovery-counterfactual label. Choose upgrade, inspect both
full definitions, then cancel/confirm deliberately. It is not a played expedition
and refuses nonempty scratch data. The stable-UID production driver also supports
`--ship=hollow_choir` for labelled counterfactuals. The lead starts the separate
primary manual expedition only after the commit is frozen; this implementation
session does not launch or automate it.

## Validation attempts — 2026-11-01

- The **first full** `GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
  ASTRAL_AUDIO_DRIVER=Dummy bash tools/check.sh` completed with **exit 0**, using
  isolated saves. It includes core rules (11,543 checks), effective definitions
  (2,087 including all 432 frozen outcomes), infrastructure (102), Cartographer
  (825), Palimpsest (1,092), Choir (1,083), all three chooser suites and replay
  gates, remaining tests, both intro modes and audio smoke. UI geometry reported
  14,457 button-bound checks with zero failures. The Cartographer tactical smoke
  still reported `cartographer-branches-v1` and won; this is not Choir balance
  evidence or a new population. Full log: `choir-full-initial.log`.
- Initial targeted mechanics run reported **74 failed assertions** and a dictionary
  access script error because the test assumed Choir writes
  Palimpsest's `last_payload` buffer, and compared total split damage with primary
  printing. Tests now check `last_command.base`, an untouched Palimpsest buffer,
  and explicit seven-primary/three-secondary damage. No production code changed.
  The corrected targeted gate passes **1,083 checks**. Native chooser node checks
  pass **35 checks**; separate-process Choir replay passes **10 process checks**.
- Direct `git show f66fe8e:data/catalog.json` comparison confirms exactly 18 Choir
  evolution additions and no other catalog difference. Historical baseline
  tooling's nine Python unit tests pass, without regenerating any captures.
- Graphical native demo smoke-started on Apple M1 Max/OpenGL with fresh scratch
  data and `--quit-after 180 -- --ship=hollow_choir`, exiting zero. This is startup
  evidence, not human readability/scroll inspection or a manual expedition.
- UI shutdown emitted ObjectDB/resource-in-use diagnostics despite zero assertion
  failures and successful exits. These are recorded, not suppressed.
- Logs are under the approved temporary directory
  `/private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/`:
  `choir-import.log`, `choir-target-initial.log`, `choir-target-fixed.log`,
  `choir-ui-initial.log`, `choir-native-demo.log`, `choir-full-initial.log`.
