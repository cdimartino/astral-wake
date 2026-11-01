# Expansion Attempt A — labelled recovery continuation

Limited manual evidence for #16, not an uninterrupted primary audit, graphical
expedition, optimal-play demonstration, distribution estimate or proof of balance.

## Provenance and outcome

- Frozen source `79bed51aa887291c47ea614700b342b9fee46978`; seed `0093CG`,
  Cartographer, discovery0/content1/reward1. Do not relabel as `197949d`.
- Victory: 22 wins, 284 card plays, 74 end turns; final hull50/100, salvage115.
  Global minimum committed hull18; final-guardian minimum43 (correcting48 in
  the original narrative).
- Lineage: 295 original successes, one reconstructed sequence295 `end_turn`,
  and158 subsequent manual successes; one unchanged-state post-terminal rejection.
- Lead exact replay verified454 successes and that rejection. Guard455 state:
  `e77a5d5c74501f4d36b52011163497cbeff74749771a2613a304aad196433684`.
- Recovery trace SHA256:
  `dd6cfa4b5e1a4922d08151cf1e0b99c9a07a8cc01ac924bd3a08071c58d0abd1`.

[Final narration](https://github.com/cdimartino/astral-wake/pull/46#issuecomment-6559912436)
and [evidence bundle](https://gist.github.com/cdimartino/490432dc4bd875249a1f521104a7b97d)
preserve the original evidence and recovery lineage.

## Interrupted transaction and authorized recovery

An interruption persisted an end turn without its journal receipt. The guard
correctly refused resume. Read-only investigation identified separate save/journal
commits, not an atomic transaction. The original attempt was blocked, not defeated.

With explicit user authorization, isolated replay verified all295 original entries
against the preserved backup. One intended end turn then reproduced the complete
preserved primary rules state, including RNG, piles, enemies and counters. Only
the adapter's existing `id`, `started_at`, and `elapsed_seconds` exclusions applied.
The user separately authorized continuation from a copied recovery session.

All31 original files and forensic-annex files remain unchanged. The missing original
receipt remains missing: deterministic reconstruction and later exact replay do
not make it contemporaneously journaled. Non-atomic journaling remains a separate
engineering defect; longer timeouts alone do not repair transaction atomicity.

## Actual coverage and limits

Independent analysis checked all284 plays for printed identity/payload, CP,
conditions, ordered routes, ward and pre-organ powerup/Atlas arithmetic.

- Tempered Lance28 plays: entry-strain2 bonuses and cooling.
- Sheltering Sink10: flat ward and cooling, without Echo amplification.
- Refracted Fang5: group eligibility grants4 ward; the condition fails alone.
- Survey Spike5: late novel-route bonuses.
- Living Atlas installed once for2CP; only later attacks earned stacks, reaching
  and respecting cap6. Repeated routes did not earn stacks.
- Eight upgrades: five recovery and three paid35. At actual hull52 and50 recovery
  checkpoints, the player instead chose30 repair each time.

Survey appeared after win19 and Atlas after win21. Phase Radiator was never
offered. Loom was offered once and declined at23 hull for Soft Copper; that is
not played Loom coverage. Pity6→0 accompanied Atlas's offer, but no explicit
forcing metadata was exposed, so independent RNG-causation proof is not claimed.

Strong powerups and prior player experience confound attribution. Manual selection
is reported; a journal cannot independently prove the full decision process.
Independent assessment passed this limited Attempt A evidence only, not PR46 merge
approval. Attempt B and its assessment remain separate. Shared illustrations do
not fulfill nine-new-artwork acceptance, and #16 is not complete.
