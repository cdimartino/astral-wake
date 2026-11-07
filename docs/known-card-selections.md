# Atomic known-card selections (#14, third scoped slice)

The subsequent [bounded Install slice](bounded-install-engines.md) adds typed
passive consequences to committed exhausts, never to speculative enumeration.
Its revision 4 supersedes the historical revision 3 save contract below.

Dormant primitives only: all 72 production definitions remain unchanged. Scrape
Clean, a Cold Breath branch, Binding Thread and Reprise remain future authoring
work. #14 is **not complete**. No passive payouts, balancing or engine triggers.

## Authored contract

`effective_card(instance).selections` optionally contains one to three ordered
descriptors, validated by runtime and content schema. Supported fields only:

- `kind`: `exhaust_hand`, `retain_hand`, or `return_discard`.
- `optional`: boolean, defaults false; only true permits an explicit `null` choice.
- `kind_filter`: optional `attack` or `repair`, only for `return_discard`, checked
  against the candidate's effective definition, never caller filter authority.

Each operation chooses one distinct UID. Source, draw, exhausted and installed
cards are ineligible. Choices use only known pre-draw cards. Retrieval chooses
discard only. Duplicate choices are rejected. Eligibility excludes choices that
make a later required operation impossible. Required empty sets fail before opening
a chooser; optional empty sets expose `null`, never an implicit skip/random pick.

## Atomic API and ordering

`begin_selection(source_uid, ordered_route, target_index, target_guard)` takes an
exact enemy dictionary as guard. Source, affordability, route, target and feasibility
are checked on a copy. `selection_view()` exposes the next operation/eligible UIDs;
`select_uid(uid)` appends a choice. `preview_selection()` is pure, including Trace,
Resonance and RNG. Complete preview agrees with `confirm_selection()` on visible
outcomes; simulated hidden draw identities are redacted from preview presentation.

Pending context contains source UID, ordered route, target snapshot/index, authored
definition snapshot, state fingerprint and explicit choice prefix: descriptors,
**not cached applied effects** or a sixth ownership zone. The fingerprint is internal
integrity bookkeeping, not hidden-deck inspection. Confirmation revalidates everything
and simulates on a copy before one commit. Failure preserves pending context.
`cancel_selection()` clears even stale context: no CP, draws, RNG calls or effects.
Reopening cannot reveal hidden draws. Game APIs block ordinary play, end turn,
direct retain, replacement new run and abandonment while pending. Inspection,
pure previews, saves and non-gameplay settings remain available.

Operations resolve in descriptor order before source draw. Exhaust clears temporary
retain. Temporary Retain lasts through the next discard unless played first.
Retrieval takes priority over draw and reserves the slot freed by source use: a
ten-card hand can retrieve one card, suppressing source draw at cap. Multiple
retrievals must fit; overflow rejects preflight, never silently loses a card.
Source always enters its proper zone before normal draw, preserving self-redraw/RNG.
Retrieval emits distinct `retrieve_card`/RETRIEVE presentation, not a draw event;
dedicated moves still emit `zone_card`. Plain payload, route-before-vent validation
and lethal-route death precedence remain unchanged.

Existing `play_card` and `preview_card` calls work unchanged for no-choice cards.
Their optional fourth `choices` array allows complete atomic known-UID calls.
Incomplete choices return `selection_required` without gameplay/RNG mutation.

The chooser restricts mouse input, keyboard focus and unrelated shortcuts. It shows
full source text, route, target, choices and explicit CP commitment. Tab/Enter operate
native buttons; Escape cancels. Resuming restores the exact pending chooser.

## Saves and regression gates

Envelope version remains 1; run schema is 3 with mandatory `pending_selection`
(empty dictionary when idle). Explicit revision-2 migration adds only that field.
Truly unversioned legacy saves retain zones/CP/expansion migration. Unversioned files
carrying new pending bookkeeping are rejected, as are malformed current fields and
unknown revisions; validated backup recovery remains available.

Full normal combat validation and five-zone conservation still apply. Raw pending
UIDs/route indices/choices, authored numeric metadata, types, extra fields, guards,
source/route/target changes and eligibility are validated **before** integer restore.
Legacy numeric and modern split-stream RNG survive migration/resume unchanged.

`tests/known_selections_test.gd` covers both RNG formats, pending save/resume,
cancellation, malformed raw metadata, stale contexts, source-slot/cap retrieval,
death precedence, manual replay including errors, and chooser nodes/focus at
1440×900 and 1100×720. All 432 frozen compatibility hashes remain unchanged;
only asserted-empty `pending_selection` is newly omitted. Headless assertions are
not evidence of native graphical legibility or human playtesting.

## Native fixture demo

From this worktree, using isolated approved temporary saves:

```sh
export GODOT_BIN=/Users/chris/Source/astral-wake/.tools/Godot.app/Contents/MacOS/Godot
export TMPDIR="$(mktemp -d /private/var/folders/tj/54g2g21d0pd98kcp8btp0s_r0000gn/T/opencode/selections-review.XXXXXX)/"
export ASTRAL_SAVE_DIR="$TMPDIR/title-save"
export ASTRAL_SKIP_INTRO=1
"$GODOT_BIN" --headless --path . --script tests/known_selections_test.gd
"$GODOT_BIN" --path . --script tests/known_selections_test.gd -- --demo
```

The demo runs assertions then displays **Fixture Ordered Choices**, UID 1. Choose
it, organ Q (index 0), then Space / Choose cards. Choose UID 2 to exhaust, UID 3
to retain through next discard, and discard UID 10 to retrieve. Before confirmation
CP remains 3 and piles unchanged. Escape cancels at any stage. Reopen and confirm:
spend 1 CP, exhaust UID 2, mark UID 3, retrieve UID 10, then draw 2 subject to cap.
Inspect Exhausted and `[R1]` duration. Capture at 1440×900 and 1100×720; close to exit.
Only tests register these definitions; no production catalog/reward/demo hook exists.

## Stable-UID JSON fixture driver

The test-only `tests/selection_driver.gd` uses the real manual adapter, guards and
journal, starting the same fixture:

```sh
"$GODOT_BIN" --headless --path . --script tests/selection_driver.gd -- \
  --session="$TMPDIR/manual" --start=A1B2C3
```

Resume one command at a time with the same session path and
`--resume=true --command='<JSON>'`. Every command must copy the **latest** response's
`view.expect` (initial start returns `expect` at top level). Example sequence:

```json
{"op":"begin_selection","uid":1,"route":[0],"target":{"slot":0,"id":"cinder_mite"},"expect":{"step":0,"state":"COPY_LATEST_HASH"}}
{"op":"select_uid","choice_uid":2,"expect":{"step":1,"state":"COPY_LATEST_HASH"}}
{"op":"select_uid","choice_uid":3,"expect":{"step":2,"state":"COPY_LATEST_HASH"}}
{"op":"select_uid","choice_uid":10,"expect":{"step":3,"state":"COPY_LATEST_HASH"}}
{"op":"selection_preview","expect":{"step":4,"state":"COPY_LATEST_HASH"}}
{"op":"confirm_selection","expect":{"step":4,"state":"COPY_LATEST_HASH"}}
```

Use `cancel_selection` at any stage instead, then reopen with the newest guard.
`selection_preview` is a query, not a journal step. Failed commands are explicit
errors and **do** advance the step without gameplay mutation. Optional choices use
`choice_uid:null` only when authored. Production `tools/manual_replay.gd` supports
the same operations without fixtures. Replay into a fresh directory:

```sh
"$GODOT_BIN" --headless --path . --script tests/selection_driver.gd -- \
  --session="$TMPDIR/replay" --replay="$TMPDIR/manual/trace.json"
```

Exact source environment/revision guards still apply to replay/resume. Like the
pre-existing manual driver, the journal/inspection state is a full rules audit
(including raw piles/RNG), not a player-facing hidden-information security boundary.
The chooser and new selection preview never display newly drawn identities.

## Explicit deferrals

- Draw 2 then discard 1, or selecting newly drawn cards: future committed cost/draw
  before reveal with a noncancelable continuation, **not** this cancellable protocol.
- Inspect/reorder hidden top cards. No reveal/cancel free scry exists here.
- Organ choices, Install counters/triggers/passive activation/stacking/payout.
- Production cards/branches or balancing. Known-hand discard is not implemented.
