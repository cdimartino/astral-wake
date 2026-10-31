# Playing Astral Wake

[All guides](README.md) · [Ships and their systems](ships.md)

Choose a living ship, build its deck, and defeat the guardians of three regions. Each expedition visits three different areas drawn from six possibilities. Hull, salvage, cards and powerups carry between encounters; your combat resources reset for each new fight.

All three ships are available immediately. **New expedition** opens ship selection; **Details** shows a ship's systems and starting deck. See the [ship guide](ships.md) for their different organ networks, Trace and Resonance mechanics.

The combat header's **Last command** box shows the previous card, its kind, and its resolved damage, repair, and disruption. Hover for its base payload, or click/focus and press Enter to inspect the card. Rewrite uses half the upgraded base damage, repair, and disruption, rounded down—not the results after organs, resources, or powerups. This memory persists across turns and saves; older saves may retain the payload without the card's identity.

## Your first encounter

Card faces show their effective upgraded numbers, including Vent, Draw, and vessel-resource gains. Effect badges wrap rather than disappearing beneath long descriptions. Upgrades do not increase Draw: pure utility upgrades instead spare the first routed organ's strain.

While routing, Trace and Resonance show **current → projected** values without spending anything. Selected organs are labeled **Active**, **Fallback**, **Inactive**, or **Wasted** (resource spent without benefit), with matching colors. Hover an organ for its resource changes and the route preview for the complete card-to-organ flow. Undoing or canceling restores the corresponding forecast; the current combat state changes only on confirmation.

The **Draw** and **Discard** piles flank your hand. Cards travel into and out of them when played or when a turn ends; reshuffles and pile counts follow the same sequence. Click a pile to inspect its composition (draw order stays hidden). Escape skips the presentation without changing the committed result. Reduced motion shows the same card and count changes without travel animations.

The route preview's **Damage** is damage to the selected enemy. **Split** lists damage to other living enemies, separately; unequal values reflect each recipient's defenses and remaining hull. Hover the preview or Confirm for the full named-target breakdown.

1. Choose a lit destination on the map. Clicking a reachable node travels immediately; you can also use **Travel here** in its details.
2. Select a command from your hand. Its gold badge is its command point cost.
3. Choose one to three connected organs, in order.
4. Select a living enemy, even for a repair or utility command.
5. Read the preview, then press **Confirm** or **Space**. You can change the route or target before committing.
6. Play another affordable command, or **End turn** to let the enemies act and prepare your next hand.

Hover or focus a card to raise and enlarge it. Tooltips contain its full effects, including evolution bonuses. Cards you cannot afford remain inspectable.

For an unmodified Cartographer, **Needle of Dawn → Lens [Q] → Fork [W] → Echo [E]** costs 1 command point and produces 18 damage to the target, plus 9 to each other enemy. This assumes enough enemy hull and no enemy protection or powerup bonuses. Each of those three organs gains 1 strain. Lens and Echo do not connect directly.

## Command points, hands and turns

Every turn starts with **3 command points**. Cards cost **1 or 2**, paid once per command regardless of route length. Unspent points do not carry over: End turn refills the meter to 3. Command points and salvage are separate resources.

A fight starts with your shuffled expedition deck and a five-card hand. Second Eyelid adds one card to the opening hand only. Played cards enter the discard pile; draw effects can supply more cards during your turn. Whenever the draw pile runs out, the discard pile is shuffled into it. Your hand holds at most ten cards.

End turn does the following:

1. Discards every card still in your hand and clears the previous enemy phase's severed links.
2. Resolves living enemies' intentions in order. Killing an enemy before its turn prevents its action.
3. Removes temporary disruption, redirection and remaining ward, then cools every organ by 1 strain, plus any Winter Gland bonus.
4. Refills command points, reveals the next intentions and draws five cards if combat continues.

You may end a turn with points remaining. Defeating every enemy ends the fight immediately; you do not need to survive an extra enemy phase. Reaching zero hull ends the expedition unless Buried Dawn's once-per-combat rescue triggers.

## Routing and strain

A legal route uses **one to three different organs**. Each consecutive pair must have an open connection; connections work in either direction. Organs apply their effects in the order you select them, so changing the order can change the result.

Every routed organ normally gains **1 strain**. All ships begin with capacity **3** per organ. An organ at capacity cannot be used until it cools. Wide Lung raises capacity by 1. Strain is separate from command points: an affordable command can still have an illegal route.

**Vent** reduces strain on all six organs before the command adds route strain. Route validation happens first, however: a Vent card cannot route through an already saturated organ. Route it through available organs to cool the saturated ones for a later command.

**Link** commands restore all severed connections and, with a route of at least two organs, connect its first and last organs for the rest of that combat. The repair happens after route validation, so the repairing command must itself use an open route. Enemy cuts last for your next turn; the old cuts clear at the start of the following enemy phase, when enemies may sever links again.

Use **Undo** to remove the last step, or **Cancel** to clear the selection. Selecting an organ already in the route removes that organ and every later step, allowing you to backtrack.

Trace and Resonance also last across turns within a fight, then reset for the next fight. Their effects depend on the selected ship; see [Ships](ships.md).

## Reading the preview

Selecting a card, route and target simulates the same rules used to play it. Previewing does not spend points, add strain, change your hand or advance the random sequence. An invalid route disables Confirm and explains the problem.

The compact strip shows:

- **Damage:** actual damage across all affected enemies, including split hits and enemy protection. It is capped by the hull those enemies have left.
- **Hull:** your net hull change, which can include repair and a repeated-route penalty.
- **Disrupt:** disruption produced by the command. This is not necessarily the amount the next attack loses: defenses have a shared cap, and a slain target cannot retain disruption.
- **Command points:** the current and remaining totals.

The organ buttons show forecast strain. Hover the preview or Confirm for the detailed outcome, including individual hits and resource changes. A brief effect sequence displays committed results; Escape skips the presentation to the resulting state without undoing the action.

## Enemy intentions and defenses

Each enemy displays its next intention, current hull and maximum hull. All living enemies remain visible and can be selected directly.

Attacks grow by **1 damage every four combat turns**, starting on turn 5; the displayed intention includes this increase. Long repair loops become increasingly dangerous. Save defensive commands for attacking turns, use quieter turns to cool or repair, and weigh a kill against preventing incoming damage. Later regions increase enemy strength further.

| Intention | What happens in the enemy phase |
| --- | --- |
| Attack | Deals the displayed damage after disruption and redirection; ward can absorb what remains. |
| Strain | Adds up to 2 strain to the indicated number of most-strained organs, capped at capacity. Ties use organ index order. Normal end-of-turn cooling follows. |
| Sever | Cuts the last command's route connections first, in route order, then other open connections in circuit order. Cuts last for your next turn. |
| Incubate | Creates an Ember Cocoon if fewer than five enemies are present. A cocoon hatches after two subsequent enemy phases; the hatchling does not attack during its hatching phase. |
| Rebuild / repair | Repairs every living enemy, up to its maximum hull. |
| Mark | Sets a hull penalty for repeating the immediately previous command's exact ordered route. The mark persists for the combat and compares routes across turns too. |

**Disruption** reduces a surviving target's next attack. **Redirection** moves some of that attack into another living enemy. Together they can prevent at most **half the raw attack, rounded down**. Disruption uses this allowance first; redirection uses the remainder. Redirection is capped at 3 per attacking enemy and requires another living enemy. Repeated Prism uses do not raise that cap. Both defenses expire after the enemy phase, including when their target did not attack.

For example, a raw attack of 10 with 3 disruption and 3 available redirection loses 3 to disruption and redirects only 2. The remaining 5 reaches ward or hull. If there is no other living enemy, redirection does nothing.

**Ward** absorbs normal attack damage after those reductions and is consumed across attacks. Leftover ward expires at the end of the enemy phase. The enemy's displayed attack forecast is **before ward**, so it can exceed the hull you will actually lose. Ward does not absorb the mark's repeated-route penalty or damage paid in events.

Some guardians have additional rules. Each hit on the Salvage Parliament loses 2 damage for every other living enemy protecting it. Removing those enemies changes later previews. Read the guardian's intentions and compare the preview when choosing a target.

### Learn an enemy's counter

Hover or keyboard-focus an enemy's **intent badge** to read its repeating cycle, current stance, and counter. The action order repeats even when you interrupt a turn. Attack damage still escalates in long fights.

- **Armor** subtracts damage from every hit; use fewer, larger hits or wait for a different stance. **Exposed** adds damage to every positive hit, rewarding several attacks during that window.
- **Route weaknesses** grant extra damage from a one-organ route, a three-organ route, or a secondary split hit, as specified by that enemy. A primary hit does not count as split damage. Bonuses apply before armor.
- **Interruptible utility actions** show a disruption threshold. Meet it during that turn to cancel the action entirely. Below the threshold it still happens. Disruption expires afterward; the enemy advances to its next step. Already-applied marks remain until combat ends.
- **Drain** repairs only the hull damage that attack actually deals. Ward, disruption and redirection deny some or all of that repair.
- **Overload** adds damage for each saturated organ when the attack lands, before cooling. Vent beforehand, and account for other enemies applying strain earlier in the phase. Attack forecasts include that earlier strain.

For example, Lantern Eel's Arc has armor, while its following Afterglow is exposed. Ash Cantor's hymn can be interrupted before its overload-enhanced Cough. Ribbon Leech rewards short routes, cuts the last-used conduits, then feeds on unprevented damage. See the [enemy field guide](enemies.md) for all 36 enemies.

## The voyage and its map

An expedition chooses three distinct regions from these six:

- Cradle of Embers
- The Choir of Wrecks
- The Glass Beyond
- The Verdant Engine
- The Tidal Archive
- The Crown of Storms

Each region has twelve map layers. Ordinary layers offer two to four nodes, with branching and merging connections; the final layer contains its guardian. You choose one connected destination per layer. You cannot return to an earlier stop or jump to an unconnected branch. Enemy strength scales with the region's position in your expedition.

Scroll vertically to inspect the chart. The map returns to your progress and focuses a reachable next choice. Hovering, focusing or clicking an unreachable node reveals its details without traveling.

| Destination | What to expect |
| --- | --- |
| Battle | Combat, automatic salvage and a choice of card rewards. |
| Elite | A harder fight, 15 extra salvage and two powerup alternatives in the reward selection. |
| Boss | The region's guardian, 30 extra salvage and two powerup alternatives. Resolve the reward to continue or finish the voyage. |
| Event | A choice that can affect hull, salvage, deck or powerups. Read its terms before choosing; you may also leave. |
| Shop | Spend salvage on commands, a powerup or deck work. |
| Recovery | Repair 30 hull or evolve one command for free. You may leave without choosing. |

Base combat salvage is **18 / 25 / 32** in the first, second and third regions. Elite/boss bonuses and Brass Tithe add to it. Between the first two regions, continuing repairs **25 hull**, capped at your maximum. Defeat the third guardian and resolve its reward to win.

## Rewards and deck building

Salvage is awarded automatically after victory. Then choose **one** offered discovery or skip. Normal rewards offer three card choices. Elites and bosses offer two cards and up to two distinct, unowned powerups. Many Pockets adds another card choice. You still take just one discovery: choose the card or powerup that addresses your deck's current weakness.

Cards come from the chosen ship's discovery pool, fixed when the expedition starts. New ordinary voyages use your current discovery tier; a seed replay restores the pool encoded in that code regardless of the current profile. Duplicate cards are allowed, and each copy can evolve independently. Powerups are shared between ships, last for the expedition and cannot be acquired twice in the same voyage. They do not become starting equipment for future runs.

Shops normally offer two commands priced at 35 and 43 salvage, two distinct unowned powerups for 75 each, removal for 30, and evolution for 35. Old Favour discounts these prices by 20%. Each listed exchange can be completed once. Removal or evolution opens a card chooser; payment happens only when you confirm a particular card. Cancelling does not charge you. Removal must leave at least five cards.

A command can evolve once. Evolution adds every applicable printed-stat bonus: **+3 damage, +2 repair, +1 Vent and +1 disruption**, where that base stat is already positive. If none of those four base stats is positive, the first routed organ instead gains no strain. Evolution does not change the card's command point cost. The card's expanded text lists its actual bonuses.

Hull, maximum-hull changes, salvage, deck changes and powerups persist through the voyage. Starting a new fight resets strain, temporary links/cuts, defenses, marks and ship-specific combat meters.

## Discoveries, history and saves

Every concluded **ordinary** expedition—victory, defeat or abandonment—advances the profile's discovery tier by one, up to tier 3. **Entered-seed practice never advances durable progression or grants unlocks.** Each tier adds two optional Cartographer cards and one shared powerup to the available reward/shop pools:

| Tier | Cards | Powerup |
| --- | --- | --- |
| 1 | Ember Abacus, Kindly Static | Many Pockets |
| 2 | Afterimage, Deep Winter | Old Favour |
| 3 | Whole Horizon, Unbroken Song | Buried Dawn |

Discoveries broaden future options; they do not increase starting hull, capacity or command points. All ships are available without unlocking them. **Discoveries** shows the tiers; **Run history** lists the last thirty concluded voyages. Abandoning records a defeat. Simply replacing an active expedition with a new one does not conclude it or award a discovery tier.

### Seeded practice

On **Select your ship**, enter a six-character seed (letters A–Z and digits 0–9), or leave it blank for an ordinary voyage. Both final screens show your code. **Retry seed** restarts the same vessel and code in practice mode. Practice saves and resumes normally, permits temporary deck upgrades and powerups, and records a marked history entry, but cannot grant durable progression. Reuse the same vessel, game version and actions to reproduce tactics exactly. See [seeds](seeds.md) for details and legacy-save limitations.

The game has one active expedition and saves locally after committed actions and choices. **Save and return to title**, then **Continue expedition**, resumes that state, including the selected ship, itinerary, deck order, combat meters and pending rewards. An unconfirmed route selection is not a committed action. Settings save immediately.

On macOS the default folder is:

```text
~/Library/Application Support/Godot/app_userdata/Astral Wake/
```

`save.json` holds the current save; `save.backup.json` preserves a previous valid generation. If the primary cannot be read or validated, the game attempts the backup and displays a recovery message. A save warning means recent in-memory progress may not be on disk; check it before closing the app. Starting a replacement requires confirmation before active progress is overwritten.

Older saves retain the Cartographer and their original three-area itinerary. In a legacy combat save from before command costs, a turn where a card had already been played resumes with zero points; End turn restores the normal three.

## Controls

| Input | Action |
| --- | --- |
| Mouse | Select cards, route organs, choose targets and activate buttons. Hover a card to enlarge it. |
| 1–5 | Select the first five cards in your hand. Use mouse or keyboard focus for other cards. |
| Q W E R T Y | Add the corresponding labeled organ while a card is selected. |
| Space | Confirm a legal selected command and route. |
| E | End turn when no card is selected. With a card selected, E selects the third organ. |
| Shift+E | End turn while routing as well. |
| Left / Right | Cycle living enemy targets while a card is selected. |
| Escape | Skip a resolving effect sequence; close an overlay, leave ship selection, cancel a selected command or open the pause menu, depending on context. |
| Tab / Shift+Tab | Move focus forward/backward. Focusing cards enlarges them; focusing map nodes scrolls them into view. |
| Enter | Activate the focused control. |
| Any key or click during the opening film | Skip the film. |

Use the on-screen **Undo** and **Cancel** buttons to edit a route. **Deck** inspects your commands and installed powerups; **?** opens help. Settings include fullscreen, reduced motion, and four audio sliders: **Master**, **Music & cinematic**, **Combat effects**, and **Interface**. Category sliders change independently; zero mutes that category, while Master zero mutes everything. Changes apply and save immediately. Reduced motion stops ship/star drift and animated combat feedback, retains result information, and skips the opening film on launch.

## Glossary

| Term | Meaning |
| --- | --- |
| Command | A card played through an organ route. Its kind is attack, repair or utility. |
| Command points | The three-point turn budget used to pay card costs. |
| Hull | Current health; repair cannot exceed maximum hull. |
| Organ | A ship system that changes a command as the route reaches it. |
| Route | The ordered sequence of one to three distinct, connected organs. |
| Strain / capacity | An organ's accumulated load and the threshold that prevents further use. |
| Vent / cooling | Strain removed by a command / at the end of a turn. |
| Link / sever | Restore or add connections / temporarily cut them. |
| Disruption | Temporary reduction to one enemy's next attack, subject to the shared defense cap. |
| Redirection | Damage diverted from an attack into another enemy, also subject to that cap. |
| Ward | A temporary pool that absorbs normal attack damage. |
| Split damage | Damage to secondary enemies, normally half the final command damage, rounded down; Forked Rib adds to each secondary hit. |
| Trace | The Palimpsest's combat resource, capped at 6; its systems can spend it and reuse part of a previous command's base payload. |
| Resonance | The Hollow Choir's combat resource, capped at 3. Changing command kinds builds it; repeating a kind resets it before card/organ gains. |
| Salvage | Expedition currency spent at shops and some events. |
| Evolution | A once-per-copy command upgrade that lasts for the voyage. |
| Powerup | An installed expedition-wide passive effect. |
| Discovery tier | Persistent profile progression that adds optional cards and powerups to future pools. |

The rules above follow the current [game implementation](../scripts/game.gd), [catalog](../data/catalog.json) and [controls](../scripts/main.gd).
