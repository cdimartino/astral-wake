# Typed defense Install engines (#14/#16 prerequisite only)

Historical prerequisite record. The [production expansion candidate](cartographer-expansion.md)
now registers these engines on production cards in content pool 1 / schema 7.
The fixture-only scope and validation record below describe df3e6c5, not closure.

**Fixture-only; neither issue is complete.** Phase Radiator and Interception Loom
are real prototype names, utility Install, cost 2, registered only by
`tests/defense_engine_fixtures.gd`. No production card, 72-base/144-branch content,
role assignment, reward policy/pool, art or expedition balance changes.

## Closed definition contract

`install_engines.gd` and the raw Python catalog validator accept exactly:

* `{type: "cooling_ward", threshold: 1..12, ward: 1..99}` (Radiator: 2 / 5).
* `{type: "redirect_retaliation", damage: 1..99}` (Loom: 6).

All numbers must be finite integral numbers, never booleans; unknown/missing fields
and type-inappropriate fields fail. Existing `novel_route`/`other_exhaust` contracts
are unchanged; untyped installs remain dormant. No generic event interpreter.

## Actual cooling and source timing

Entry-active Radiators pay flat additive ward on the first **later committed
command** of a player turn whose actual removals meet the threshold. Actual vent
removal plus actual post-route removal is summed, not attempted removal or net
strain change. Vent can remove strain, route can add it back, and post-route cooling
can legitimately remove it again. First-free zero-strain postcool counts zero.
Own installation, invalid routes, chooser staging/cancellation and automatic
end-turn cooling cannot trigger. Existing legal-route checks precede cooling.

No Echo/organ amplification, damage stacks, copying or plain D/H/I payload additions.
Living final kills can pay before combat transition; lethal route penalties cannot
pay or resurrect. Preview and confirmation share the copied-state resolver.

## Resolved redirect event and enemy identity

Enemy-phase entry snapshots the existing Loom source records. Each consumes its
once latch on the first **positive resolved redirected amount**, even if armor
absorbs all HP loss or the redirect kills the recipient. Attempted redirects with
zero budget, interrupted/non-attacks and lone foes do not consume it.

The existing order is retained: compute capped attack → redirected hit → player
hull/ward hit and existing emergency survival → drain from actual hull loss only →
actor disruption/redirect cleanup → lethal break → retaliation if alive. A lethal
unrecovered player hit therefore still deals its ordinary redirect first, but never
pays the passive afterwards. There is no invented resurrection. Ward absorption
does not heal drain.

The extra 6 is a separate ordinary enemy hit: armor/exposed apply independently;
no route weakness, split, organ, powerup, copy, Echo or recursive passive damage.
Attack 12 / disruption 2 / redirect 3 produces 7 incoming before ward. Ward 5
means hull loss/drain 2. Recipient armor 2 takes redirect 1 plus retaliation 4.
A recipient killed by redirect receives no extra hit and **never retargets**.

No enemy compaction is introduced inside the initial-count loop. Actor and recipient
indices bind to the attack snapshot, not enemy type IDs or the compacted surviving
array. Dead recipients skip later actions. Appended eggs do not act this phase.
Presentation carries the actual source UID and snapshot actor/recipient indices;
invalid retaliation indices are skipped, never clamped to another foe. Extra-hit
cues are after the attack, visibly source-labelled, and never Echo-amplified.

## Persistence and inspection

Run schema **6**, store envelope **1**: no new fields or revision needed. Existing
five-field `{source_uid,type,stacks,used,turn}` records are validated raw before
integer restoration, in exact installed-source order with matching type/UID.
Both new types require `stacks == 0` and never contribute to attack bonus. Cooling
may be used with zero stacks; old used/positive-stack/route invariants remain
type-specific. Counter turn must equal battle turn. Unknown/fractional/boolean
numeric values, missing current records/fields, wrong sources/types/turns and
nonzero new-type stacks fail with verified backup fallback.

Enemy resolution is atomic: retaliation `used` cannot persist true in a saved
player state. At the single completed-phase/new-player boundary both latches clear,
counter turns advance, and the existing global route ledger resets. No preview,
reload, chooser, cancellation or per-foe reset. Old typed counters survive revision
5 migration; old pending guards validate before migration then rebind; forged guards
are never blessed. The existing 432 frozen legacy comparisons need no rebaseline.

Installed inspection states actual-cooling threshold/flat ward and used/available
**player-turn** status, versus same-recipient extra damage and availability **next
enemy phase**. No dormant or once-per-route wording for these active types.

Existing authoritative `game.gd` / `install_engines.gd` fingerprints cover these
rules; no new production rules module exists. `defense_engine_replay_test.py` uses
a 12-entry counter-bearing fixture journal across separate processes, exact
state/RNG/result replay, a saved chooser, cancellation/confirmation, and same-HEAD
dirty-byte resume/replay rejection for game/engine/selection/route modules.

## Exact test / native commands

Use a fresh isolated scratch save, never a player save:

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
export TMPDIR="$(mktemp -d /private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/defense-review.XXXXXX)/"
python3 tests/validate_content.py data/catalog.json --self-test
"$GODOT_BIN" --headless --path . --script tests/defense_engines_test.gd
"$GODOT_BIN" --headless --path . --script tests/defense_engines_ui_test.gd
python3 tests/defense_engine_replay_test.py "$GODOT_BIN"
GODOT_BIN="$GODOT_BIN" bash tools/check.sh
export ASTRAL_SAVE_DIR="$TMPDIR/native"
"$GODOT_BIN" --path . --script tests/defense_engine_demo.gd -- --capture
# Fresh directory for 1100x720 capture (default is 1440x900):
export ASTRAL_SAVE_DIR="$TMPDIR/native-small"
"$GODOT_BIN" --path . --script tests/defense_engine_demo.gd -- --capture --small
```

Without `--capture`, the labelled fixture opens for manual commands. Initial UID 1
= Radiator, 2 = Loom, 3 = Cooling Command, 4 = Chosen Cooling, 5 = Post-route Cooling.
Install Radiator via Q,W (0,1), then UID 3 via T (4): actual cooling 2, flat ward 5.
End turn; install retained Loom via R (3). End turn again: Cinder turn 2 uses strain,
not attack. On turn 3, UID 4 via Y/Prism (5), choose retained UID 5 to exhaust, confirm,
then end turn: ordinary redirect 3 and Loom extra 6 to recipient index 1. Default
fixture enemy HP is 100, normal CP 3, capacity 3; no production cheat hook. Supporting
fixture commands have visible intrinsic Retain; Loom starts with a visible ordinary
one-boundary temporary-retain mark. Neither engine prototype has intrinsic Retain.

Capture mode executes those legal commands, prints result/source-counter JSON,
and saves battle and Installed inspection PNGs for cooling and retaliation, then
exits. Capture geometry logs the actual window and viewport image dimensions;
the default aspect-fit viewport can omit window letterboxing (for example a
1100×720 window yields a 1100×687 viewport PNG). Headless UI assertions at both
sizes are not human-playtest/balance evidence.
Fixture saves cannot resume through the production entry point.

### Candidate validation record

On Godot 4.7.2 with the absolute main-worktree binary above: full `tools/check.sh`
exited 0, including the 2,087-check effective-card suite (unchanged 432 legacy
cases), 189 existing-engine checks, 158 new defense-engine checks, both-size UI
nodes, 34-process/12-entry defense replay, native CoreAudio smoke and tactical
playthrough victory. The final fixture-only retention refinement was also checked
again with the defense, UI and replay suites.

The full run still emitted exit-time ObjectDB/resource diagnostics from existing
Palimpsest evolution UI (7 objects/3 resources), Choir evolution UI (16/3), and
reward distribution UI (4/2). These are not claimed fixed or warning-free. The
new defense suites/native captures emitted none. The first full attempt stopped
at an incorrect test assumption that Cinder turn 2 attacked; corrected to route
Prism on turn 3. An outer zsh reporting wrapper also initially used its read-only
`status` name; the successful rerun uses `rc`.

Native automated fixture captures succeeded with actual window sizes 1440×900
and 1100×720: ward 5/used UID 1, redirect 3 + separate 6 to recipient 1 from UID 2,
and reset counters afterwards. Four PNGs per window include both Installed
inspections. A pixel-dimension audit initially mistook the small aspect-fit
1100×687 viewport capture for a wrong window size; explicit native geometry logs
verify the actual 1100×720 window. No screenshot padding or fabricated gate
evidence. This is automated fixture inspection, not human playtesting or balance.
