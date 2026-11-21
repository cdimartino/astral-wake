# Astral Wake 0.3.0 — Ascension 11 and Living Hull

## Go to 11

Win an ordinary expedition to unlock the next Ascension for that ship, up to
**A11**. Higher ranks add attack pressure in Areas 2 and 3 without raising
enemy hull. The ship picker shows the new rule at the selected rank and the
full set of active modifiers. A0 keeps its difficulty, and existing saves
can continue under their original rules. Seeded practice never advances rank.

## Make better-informed choices

- Cadence forecasts the ward you'll actually gain, including when you hit the
  cap. The Ember Cocoon shows how many enemy phases remain before it hatches.
- For new Hollow Choir expeditions, the **Crescendo card** adds 4 damage when
  its Concert spends all 3 Resonance. Bright Canon is still stronger without
  that setup. The Crescendo organ is unchanged.
- The live MCP distinguishes travel from inspection and identifies shop
  purchases by name, price, and slot. The updated game projects player-visible
  state without revealing future draws or RNG internals.

## Listen and make it your own

Living Hull has six original regional scores, distinct combat cues, and
separate music, combat, interface, and master controls. The local Sound Desk
lets you audition, swap, and tune sounds in an isolated workshop. The optional
composer pack includes editable multitrack MIDI, SF2/SFZ, and cue references.
The later audio trial did not justify changing the shipped mix.

## What we verified

All 462 scheduled balance runs resolved: every ship had a held-out tactical
win at every rank, while all 216 damage-first runs lost. The separate A0
comparison matched all 24 historical cases. These are automated rules results,
not human win rates. The one blind A11 Hollow Choir voyage lost in Area 1.
See the [playtest report](ascension-playtest.md) for the balance, live, and
audio evidence and its limits.

The macOS app is universal (Apple Silicon and Intel), ad-hoc signed, and
not notarized. Install from the release ZIP or use the Homebrew cask. For live
control, download the updated standalone `astral_mcp.py` host and follow the
[MCP setup guide](mcp.md).
