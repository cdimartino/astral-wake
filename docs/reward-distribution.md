# Reward distribution — #19 first coherent slice

**Candidate, not issue closure or balance approval.** [Finite generation report](reward-distribution-report.md).
All 72 base cards and all 144 evolution branches are unchanged except two additive
draft fields. No new cards, enemies, powerup stats, starters or resolver effects.
The lead's full manual drafting expedition must start **after the candidate is
frozen**; this implementation does not claim that expedition was played.

## One authoritative policy owner

`scripts/reward_distribution.gd` owns generation 1, bounded integer draw weights,
role validation, finite selection, prices and policy prose. `game.gd` owns run/save
validation and calls it only when generating a new reward/shop. No deck, hull,
archetype score, prior take/skip, or exact-card synergy preference is consulted.
The simulator's drafting/evolution scores and policy decisions are unchanged.

The configuration constants are versioned code, not mutable player-save knobs:
ordinary `[65,28,7]`, elite `[35,45,20]`, pity limit 6 and nominal prices
`[30,40,55]`. Weight schema requires exactly three finite integral numbers in
0..100 totaling 100; bools/fractions are rejected before conversion. Changing
released rules will require another generation, not silently retuning saved v1.

### Rarity, distinct IDs and diversity

- Draw a rarity among **nonempty remaining** rarity buckets, renormalizing the
  configured weights; then draw an ID uniformly from that bucket. Remove its ID
  for this offer only. Existing copies in the deck are still eligible.
- If only zero-weight buckets remain, draw uniformly from remaining IDs. Empty
  pools return no card; short pools return all available slots without retrying.
- Ordinary offers have 3 cards (+1 Many Pockets). If all previous primary roles
  match, the final slot restricts candidates to a different primary role when
  possible. That single finite restriction guarantees at least two primaries;
  secondary tags alone do not satisfy it. No defense/engine/exact card is promised.
- Elite/boss slots remain 2 cards (+1 Pockets) plus up to 2 distinct unowned
  powerups. Boss card slots temporarily use elite weights; coordinated boss
  structure remains **#20**, not a new boss reward system in this slice.
- These are **draw weights**, not final-offer probabilities. Without replacement,
  exhausted rarities, final-slot diversity and pity bias the final population.
  The report publishes raw draws, constrained normal, elite, Pockets and sparse
  observations separately, with fixed seeds and fingerprints.

### Inspectable pity

`rare_offer_misses` is run/ship-local. **Only ordinary battle reward generation**
counts: any rare in that card offer resets it to zero immediately, otherwise it
increments, capped at six. Taking, skipping, rejecting, hovering, inspecting,
reloading, elites, bosses and shops never advance/reset it. After six ordinary
misses, the next ordinary offer with an eligible rare reserves its **first** slot
for a rarity-weighted draw from eligible rares. This is not an exact-card guarantee.
If no rare is eligible, leave the counter at six and terminate normally. The next
eligible ordinary offer still owes the rare. Deck inspection and rewards show
`6/6`, the next-eligible guarantee, and the full offer-not-take policy.

### Shops

Enumerate feasible ordered pairs of **distinct IDs**, where the first has any of
attack/group/prevention/repair and the second has enabler/scaling (primary **or
secondary** tags qualify). Uniformly choose a pair; overlap never consumes the
only possible partner by mistake. If no pair exists, prefer one immediate-use
candidate, otherwise an engine candidate, then fill uniformly from remaining IDs.
An empty pool or singleton terminates with fewer cards. The UI discloses fallback;
no deck/hull adaptation or rare guarantee is used in shops.

New card base prices: common **30**, uncommon **40**, rare **55** salvage. One
explicit exception: **Bright Canon is 40**, matching Crescendo while their known
base dominance is awaiting separate design work. This avoids making the strict
base upgrade cheaper as well. It is not a hidden rarity or offer-weight change.
[Separate required Choir follow-up](choir-base-dominance-followup.md).
Powerups remain 75, removal 30, evolution 35. Old Favour is applied exactly once
at stock creation. Pending displayed prices, sold flags and service cancellation
are not recomputed on load. Services still charge only on explicit confirmation.

## Role honesty and inspection

Every production card explicitly authors `roles` and one member `primary_role`.
Both validators require exactly the roles justified by printed **base** mechanics:
damage→attack, disruption→prevention, healing→repair, cooling/link/Trace/Resonance
generation→enabler, draw/known-card access→selection, Rewrite/Concert/actual engine
payoff→scaling. Selection does **not** mean guaranteed targeted search. Cooling
enables routing but is not labeled direct attack prevention. Split routing is
not printed group damage. There are currently no printed group cards and no
production Install engines: Cartographer's printed scaling exposure is honestly
zero. Runtime organs can still create situational payoffs.

Primary describes the card's main draft purpose, not an exclusive kind: for
example Quiet Pulse prevention, Thread Cannon link enabler, and a Concert attack
scaling. Tags do not prescribe a best pick or guarantee a complete archetype.
Reward/shop faces show rarity, primary and all base roles. Deck headings and
reward/shop controls expose full prose plus both named evolution options and CP
costs. Evolved cards show their actual effective definition; draft roles remain
explicitly **base roles**, not claims that an evolution preserves every channel.
Draft fields are deliberately excluded from combat definitions/pending payloads;
the 72-card legacy outcome fingerprints remain pinned unchanged.

Fresh profiles already have basic damage, prevention, repair, cooling and printed
Trace/Resonance generation at common rarity. Palimpsest's uncommon Rewrite and
Choir's common Concert are not discovery locked. Six Cartographer unlocks remain
sidegrades. No rare or experienced account is required to access core primitives.

## Save / seed compatibility

- Save envelope remains version 1; run schema is explicitly **6**. Fresh runs use
  `reward_generation=1, rare_offer_misses=0` with existing seed encoding/RNG version.
- Valid old active runs migrate additively to schema 6 with **generation 0** and
  zero pity. They permanently retain uniform reward shuffles, uniform shop stock,
  old slot-based 35/43 prices and exact legacy RNG consumption. No active run is
  silently upgraded to v1. Existing pending offers/shops/prices remain untouched.
- Old pending-selection guards are verified **before** migration; only verified
  guards are rebound after adding schema fields. Current-schema missing fields,
  bools, fractions, out-of-range versions/counters and v0 nonzero pity are corrupt,
  not repaired/truncated. A valid backup can still recover them.
- The oracle in `tests/reward_legacy_oracle.json` was generated against
  **7382d3d**, all three ships, modern `A1B2C3` and legacy numeric `424242`.
  Tests compare pending state, discounted shop stock, next elite reward and every
  subsequent RNG state. `tests/reward_legacy_fixture.gd` is an oracle generator,
  not a standalone test to run on the candidate.
- Modern six-character runs keep independent world/cards/enemies/rewards/shop
  streams. Reward/shop changes do not alter maps or combat RNG. The numeric API
  remains a legacy fixture compatibility API with its original **shared** RNG;
  modern stream-independence claims do not apply to that historic API.
- History and manual inspection expose active generation. Manual replay and
  simulator metadata fingerprint the new authoritative module. A real dirty
  copied module at the same HEAD is rejected by replay, without editing the
  working tree. Old traces/matrices must not be relabeled or pooled with v1.

## Native demo (not expedition evidence)

Use an empty scratch save directory each launch. No production cheat entry point:

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
ASTRAL_SAVE_DIR="$(mktemp -d "$TMPDIR/astral-reward-demo.XXXXXX")" \
  "$GODOT_BIN" --path . --script tests/reward_demo.gd -- --view=reward --ship=cartographer
```

Views: `reward` generates the real normal offer; `shop` generates actual new stock;
`pity` sets a **labelled counterfactual** six-miss counter and opens deck inspection;
`guarantee` starts at that counter then calls real generation, showing a rare and
the reset counter. Fixed seed `0093CG`; ship may also be `palimpsest` or
`hollow_choir`. `--capture=/absolute/path.png` captures the native rendered viewport
then quits. Combat is **not** played; the conspicuous counterfactual notice must
remain in screenshots. Native inspection is separate from headless node tests.
Add `--pockets` for an explicitly labelled Many Pockets four-card counterfactual.

Native Godot 4.7.2 / Apple M1 Max viewport captures at 1440×900 (label retained):
[actual new reward](screenshots/distribution-reward-counterfactual.png),
[actual new stock and prices](screenshots/distribution-shop-counterfactual.png),
[6/6 deck readout](screenshots/distribution-pity-counterfactual.png).
These were inspected for visible role/counter/price text and header overlap, not
used as played-run or decision-rate evidence. Native Pockets/guarantee views were
also inspected on Palimpsest and Choir. Some rapid UI/demo shutdowns emit Godot
AudioStreamWAV/playback resource-in-use/leak warnings; no audio behavior was changed
in this slice. Such warnings are not a clean-log claim or gameplay assertion pass.

## Acceptance still open

Candidate verification (Godot **4.7.2.stable.official.ed1daf0bf**, macOS):

- `GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot ./tools/check.sh`
  completed with exit 0 using isolated scratch saves. No `SCRIPT ERROR` occurred.
  UI subprocesses did emit the audio teardown ObjectDB/resource-in-use diagnostics
  noted above, so this is **not** a warning-free log.
- Distribution: **489,032 checks / 0 failures**; native UI node assertions:
  **15 / 0**; content equals `7382d3d` after stripping exactly the two validated
  draft fields; all 72-card legacy full-outcome hashes remain unchanged.
- Save/oracle, raw corruption, old pending guard, modern stream isolation, exact
  v0 continuation, service cancellation and same-HEAD dirty-module replay gates
  pass. Two complete generation reports were byte-identical; stored source
  fingerprints match this candidate.
- Numeric compatibility smoke `424242`, tactical, unchanged
  `cartographer-branches-v1` policy: **victory, 58 turns, 21 battles, 68 hull**,
  explicitly `reward_generation=1`. This is a new single seeded automated smoke,
  not the prior 79-turn result, a human win rate, or a comparable old-matrix row.

The automated first-seven-offer report is a generation scenario, **not actual
area-1 boss reach**. It compares policies on the same pool, not a future expansion.
No win rate, human skip rate, optimal drafting claim or completed manual expedition
is asserted. Lead review/frozen-candidate manual drafting remains required; actual
missing-rares/cold-start/skipped-card review remains **#22**. The separate base
dominance follow-up must precede future Choir card additions. Thus **#19 remains
open** for those audit/experience gates and future pool-expansion comparison.
