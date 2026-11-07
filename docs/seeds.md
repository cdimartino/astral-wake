# Seeds and reproducible expeditions

## Play and retry

- **Ordinary voyage:** leave the optional seed field blank on ship selection. The game generates a six-character code, with letters **A–Z** and digits **0–9**.
- **Practice voyage:** enter a six-character code. Lowercase and surrounding whitespace are normalized. Other characters or lengths are rejected before replacing any active expedition.
- **Retry:** victory and defeat both show the seed and offer **Retry seed**. This selects the same vessel and restarts from the beginning in practice mode. Ordinary new expeditions remain available separately.
- **Restrictions:** practice cannot award durable leveling, discovery tiers or unlocks, whether won, lost or abandoned. This restriction survives save/resume. Temporary card upgrades, salvage and powerups still work within the voyage. History records are retained and explicitly marked as practice; settings still save normally.

Use the **same code, vessel and game version** for the same starting expedition. Follow the same path and action sequence to reproduce card draws/reshuffles, enemy intentions and outcomes, event rewards, shops, and command results. Different choices can change subsequent outcomes; seeds do not make a different tactical decision produce the same result.

## Discovery pools do not drift

Ordinary voyages retain the discovery tier you have earned. Their generated codes encode that tier in the base-36 value's low two bits. Entering the same code reconstructs the same card/powerup pool without consulting the current profile. Thus an ordinary run can be retried after its conclusion unlocks another tier, or on a different profile. A practice pool can include options the local profile has not durably discovered; using them never unlocks them for future ordinary voyages.

This avoids both changing ordinary progression and silently changing reward/shop RNG when a replay is attempted on a more advanced profile.

## Dedicated RNG engine

`scripts/seed_engine.gd` owns all gameplay randomness. New codes use **RNG version 1**, a specified integer Park–Miller generator (`state × 48271 mod 2147483647`) with rejection sampling for bounded results. Fisher–Yates shuffles use those bounded draws. No reliance on Godot's mutable global RNG, built-in shuffle implementation, system clock, audio or animations occurs after the code is chosen.

Six independent named streams are initialized with fixed salts and saved with the expedition:

| Stream | Consumers |
| --- | --- |
| `world` | Region itinerary, map widths/types, encounter enemy rosters, event placement and graph edges |
| `cards` | Battle draw order and discard reshuffles |
| `rewards` | Card and powerup reward order |
| `shop` | Shop inventory/order |
| `events` | Random card and powerup event grants |
| `enemies` | Reserved for any future random enemy decisions; current intentions/counters/targeting are deterministic rules |

Card draws cannot consume map or reward RNG. Previews operate on copied state; invalid actions consume no random draws. Replay flags, timestamps, run IDs, elapsed time and history are bookkeeping and do not affect tactical RNG. Cryptographic entropy is used only to generate a fresh ordinary code.

Save validation requires the supported RNG version, canonical code, matching pool tier, practice flag, and every valid stream state. Incomplete or corrupt RNG data is rejected through the existing validated-backup recovery path rather than silently reseeding the expedition.

## Compatibility boundary

- Existing numeric-seed saves continue with their **original Godot PCG state**, map, pools and progression semantics. They are not reinterpreted as new codes; doing so would change the expedition.
- Numeric seed arguments are retained as a legacy/internal deterministic fixture API. All newly player-created games use six-character codes. Old final screens retain their numeric seed and do not advertise a six-character retry.
- RNG versioning protects the stream algorithm, not future content/balance changes. Exact tactical replay is guaranteed for the **same game version and vessel**, not across different catalogs, rules or unsupported RNG versions. Keep the build with which a seed was created.

## Verification

`tests/seed_tests.gd` covers golden RNG vectors, base-36 codes, tier encoding, independent streams, maps across all regions, all vessels, card/encounter reproduction, preview purity, rewards/shops, profile independence, resumable streams, practice progression restrictions, malformed saves, backup recovery and legacy saves. `tests/seed_ui_test.gd` checks seed entry, active-run replacement confirmation, victory/defeat display and direct retry at both supported window sizes. Both are included in `tools/check.sh`.

The full-run policy also accepts new codes:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script tests/playthrough.gd -- --code=A1B2C3 --policy=tactical --allow-defeat
```

Two independent Cartographer runs with this code reproduced victory after **418 actions, 254 cards played and 73 turns**, with identical itinerary, final deck, powerups, hull and region checkpoints. Wall time and save-directory names are intentionally not deterministic.
