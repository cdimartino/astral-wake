# Astral Wake balance update: make the hard choice worth making

**Recommendation:** Keep current enemy scaling and use Cartographer as the reference ship. Fix three places where the game obscures a decision, then test **one Palimpsest change and one Hollow Choir change independently**. The aim is a game that still defeats careless play, lets each ship win through its own mechanics, and doesn’t make a player repeat a fight they have already solved.

## What the evidence changes

| Fresh-profile policy | Cartographer | Palimpsest | Hollow Choir |
|---|---:|---:|---:|
| Damage first | 0/6 | 0/6 | 0/6 |
| Balanced | 3/6 | 0/6 | 2/6 |
| Tactical | 5/6 | 1/6 | 4/6 |
| Tactical, starter only | 0/6 | 0/6 | 0/6 |

- **Palimpsest’s problem is more specific than “late bosses are too hard.”** All six tactical runs reached Area 3. The five losses ended at layers **2, 5, 7, 7 and 7**, before the guardian. The first question is whether saving Trace can remove a dangerous enemy in time, or prevent its next action. Extra starting hull isn’t a good first test.
- **Choir’s problem is more specific than “the slow ship plays more fights.”** On seed 424242, Choir needed **153 turns in 19 fights** versus Cartographer’s **71 in 22**. On the other two shared tactical wins the comparison was **181 vs. 85** and **200 vs. 52**. A separate historical manually selected Choir victory also took 155 turns. Look for turns spent defending *after* the player has built a winning position.
- **There’s already a good model for difficulty.** The live Cartographer reached the final guardian on turn 89 and lost. The Drowned Catalogue offers distinct answers to its mark, drain, rebuild and exposed phase. Preserve that design. The loss also included skipped shops/events; it doesn’t justify weakening the boss.
- **Powerups matter; no single culprit is established.** Cartographer went from 5/6 to 1/6 when direct powerup choices were discouraged. Capacity trades could still award one. Winning runs also get more chances to collect powerups. Measure what each item contributed *after acquisition* before changing it.
- These are **72 runs on six legacy numeric seeds plus six powerup comparisons**, not human win rates. The historical 720-case modern-seed study also ranked tactical Palimpsest lowest (16 recorded wins vs. 42 Cartographer and 40 Choir, out of 60 scheduled per ship); its 35 overall timeouts are not defeats. Keep versions and generators separate.

## The update I would put into playtest

| Priority | Change | What should happen at the table |
|---|---|---|
| First | **01–03: truthful ward, travel and purchase choices.** | A player can see exactly what Cadence buys, travel only to reachable nodes, and buy the item they meant after stock changes. No numeric buffs needed. |
| First | **04: plain-language shop copy.** | Replace “reward generation v1” and “audit floor” with what the offered card or service does, what it costs, and when payment occurs. Keep detailed generation rules in the field guide. |
| Prototype A | **11: reward a full-Trace Recall against the primary target.** | At exactly 6 Trace spent by the **Recall organ** on a damaging command, test **+3 primary damage** before target mitigation. The ordinary +12 remains; the extra 3 is neither split nor remembered by Rewrite. At 0–5 Trace there is no bonus. Banking Trace can secure a kill, but passing up Redact to bank it can still be fatal. |
| Prototype B | **21: distinguish the Crescendo card from Bright Canon.** | Keep both at 2 CP. Test **+4 damage only when the Crescendo card spends all 3 Resonance on Concert**. Before organs or mitigation, at 0 spend Canon wins **12 vs. 10**; at 3 spend Crescendo wins **20 vs. 18**. The bonus isn’t healing, printed base damage, or an organ bonus. Preserve each named evolution’s identity. |
| After evidence | **05: expose the interrupt shortfall; 91: quicker reduced-motion input.** | Prioritize the former if people misread a boss; prioritize the latter if fights are tactically short enough but take too long to operate. Neither should be counted as an improvement in combat turn count. |

**Important limit on Prototype B:** Choir starts with Bright Canon, not the Crescendo card. B can fix a real card comparison even if it does little for overall voyage length. Compare fights with and without the card actually drawn. If slow finishes occur without it, test **22 instead** as the ship-wide alternative; don’t stack both changes to force the result. Likewise, if Palimpsest’s actual losses come from incoming actions rather than missed kills, test **12 instead of 11**.

## 100 changes considered

**Read this as a decision list.** **First** is recommended for the update; **Trial** is the selected mechanical experiment; **Reserve** is an alternative with a reason to try it; **Hold** means the cost or risk outweighs the evidence today. Numbers identify distinct changes, not implementation order.

### 01–10 · Make the combat and navigation choices legible

01. **First — Show actual ward gained.** Give the compact forecast and live API one named total for Cadence, printed ward and installs. If Cadence starts at 2 ward, show **+1**, not its nominal +3; don’t count the install line twice.
02. **First — Separate map inspection from travel.** Only reachable destinations belong in `choose_node`; retain inspect-only access to everything already visible. The review fixture advertised 33 travel choices for two reachable nodes.
03. **First — Name each purchasable shop slot.** Advertise item/service, price and stable visible slot; validate the current option and revision. Buying slot one must not make “buy the powerup” silently refer to a service.
04. **First — Replace shop policy text with decision text.** Explain the actual purchase and service confirmation rather than the generator’s version or pricing exception.
05. **Reserve — Show disruption still needed on the selected intent.** “Restore record: 2 more to interrupt” lets the player decide whether another command is worth spending. Don’t imply that partially meeting the threshold cancels the action.
06. **Reserve — Show ward use in enemy action order.** In a two-enemy attack, identify which hit consumes the ward and which still reaches hull; separate predicted damage from uncertain follow-ons.
07. **Reserve — Put mark self-damage before healing in the compact forecast.** A route that first loses 6 hull and then repairs 6 is not equivalent to a safe zero-delta route at 5 hull.
08. **Reserve — Show the forgone secondary hit when a split route has one target.** Keep the valid primary attack; explain precisely why Fork, Chorus or Splice contributes no splash.
09. **Reserve — Show the projected cut on the conduit itself.** Outline the visible, deterministically targeted link when a cut intent is selected so the player can bait it with a different final route.
10. **Reserve — Show the last point of damage needed for a kill.** Put “survives at 2” on the selected enemy rather than making the player subtract combined primary and splash numbers.

### 11–20 · Palimpsest: give Trace a purpose worth planning for

11. **Trial — Full-Trace Recall gets +3 primary damage.** Reward one deliberate cash-out against the dangerous target, without paying for every secondary enemy too.
12. **Reserve — Give funded Redact one more disruption.** Test **3 → 4** for its one-Trace spend; leave the unfunded value at 1 and preserve the half-attack cap. This is the defensive alternative if late failures are missed interrupts.
13. **Reserve — Let Splice punch through 2 secondary-target armor when funded.** Reward setting up a multi-enemy answer without raising single-target damage.
14. **Reserve — Make Palimend better at emergency recovery.** Below one-third hull, its one-Trace spend heals 4 instead of 2. Watch for a repeated low-hull repair loop before keeping it.
15. **Reserve — Let the Rewrite organ copy slightly more *disruption* than damage.** Round half of prior printed disruption up instead of down; odd-valued setup cards gain a distinct defensive use without recursive copying.
16. **Reserve — Trade damage for a defensive starter.** Replace one of three Margin Knives with Vellum Shield in new Palimpsest voyages. Test an explicit deck trade rather than adding an eleventh free card.
17. **Reserve — Make First Draft a stronger preparation card.** Try 4 damage and 3 Trace instead of 6 and 2. It should lose the immediate-damage comparison and win some two-command comparisons.
18. **Reserve — Give Pale Patch a costly choice at the Trace cap.** If played at cap, offer to spend 2 Trace for 3 ward instead of wasting its generation. Retain the option to bank for Recall; watch interaction overhead.
19. **Reserve — Give Final Revision a distinct two-CP payoff.** On a full printed Rewrite spend, ignore up to 3 primary armor. Check this expensive card against the cheaper Overwrite, including on unarmored targets.
20. **Hold — Carry up to 2 Trace between battles.** It would speed up setup, but largely rewards the prior fight’s ending and changes every opening; the losses point to specific late decisions instead.

### 21–30 · Hollow Choir: let a well-phrased sequence end the fight

21. **Trial — Give the Crescendo card a full-spend damage premium.** +4 only on a three-point Concert; Canon remains better without the completed phrase. Keep the existing shop price floor during the experiment.
22. **Reserve — Give the Crescendo organ a full-spend attack premium instead.** Test +3 primary damage on a damaging attack when the **organ itself** spends 3. If printed Concert already spent it, the organ earns nothing. This reaches every starting deck.
23. **Reserve — Reward Chorus for splitting at maximum Resonance.** Test +2 damage to the first living secondary target only; do not improve lone-guardian damage.
24. **Reserve — Stop Cadence from spending Resonance at its ward ceiling.** This forgives a genuinely empty spend. Test separately from 01: an honest preview is necessary even if the spending rule stays as it is.
25. **Reserve — Make Dissonance turn surplus defense into offense.** At full Resonance, if its disruption actually interrupts a non-attack action, deal 3 damage to that foe once. No reward for ineffective disruption.
26. **Reserve — Give Choral Bolt a phrase-opening role.** +2 damage if the preceding command was a repair; repeated attacks gain nothing. Watch all three starter copies.
27. **Reserve — Make Silent Measure a planning tool.** Give it Retain but remove its draw. Holding it can set up a later phrase at a real hand-cycling cost.
28. **Reserve — Let Grand Concert end an exposed guardian window.** At full spend, trade its normal Concert healing for extra primary damage against an exposed foe; retain its printed repair. Compare a real kill against the lost sustain.
29. **Reserve — Distinguish Full Shell from Light Shell by defense.** Replace part of Full Shell’s extra repair with ward, leaving the cheaper branch as the efficient phrase enabler. Compare at both full and low hull.
30. **Hold — Remove the repeat-kind Resonance reset.** This would shorten fights, but by rewarding repeated attacks. It removes the central reason to play Choir well.

### 31–40 · Cartographer: preserve a benchmark while testing route choices

31. **Reserve — Pay Lens extra damage only on a one-organ route.** Test +1 for committing to precision; inspect its interaction with Hermit Knot before making short routes the routine best answer.
32. **Reserve — Taper Fork on crowded encounters.** Keep the first secondary hit at half strength; test one-third on subsequent enemies. Only useful if large groups consistently become free wins.
33. **Reserve — Cap Echo’s amplification of *powerup-added* repair.** Leave its multiplication of printed repair intact. Test only if sustain data show that layering multipliers, rather than choosing Suture before Echo, is the issue.
34. **Reserve — Let Suture convert a wasted repair into one ward at full hull.** It gives a non-damaging route an opening use, but must compete with attacking rather than add defense for free every turn.
35. **Reserve — Pay Hush for a correct interrupt.** Cool Hush by 1 when its contribution crosses a non-attack interrupt threshold; no cooling for merely routing through it.
36. **Reserve — Make Prism’s second target selectable.** Where two recipients are alive, let the player choose who takes the redirected hit. Keep its current budget and lone-enemy limitation.
37. **Reserve — Give Sun Splinter short-route armor penetration.** Exchange 2 printed damage for up to 3 armor ignored on a one-organ route. A common starter would then have a real armored-target niche.
38. **Reserve — Give Graft Wire a repair incentive.** Replace its unconditional draw with draw two only if it restores an actually severed link. This rewards timing, but could make uncut encounters slower.
39. **Reserve — Offer a defense-first starter exchange.** Swap one Needle for Heat Sink at departure, not in addition to the existing deck. Test whether two distinct builds stay viable on the same route.
40. **Hold — Reduce Cartographer’s starting hull.** Its 5/6 tactical wins are a useful comparison point, and balanced play still lost half. A hull tax would obscure whether Palimpsest or Choir improved.

### 41–50 · Cards and evolutions: make choices depend on the encounter

41. **Reserve — Trade some Mercy Circuit repair for disruption.** Test 7 damage, 1 healing and 2 disruption against the current 7/3 hybrid. It should be better at an interrupt and worse at routine sustain.
42. **Reserve — Let Mute Bell draw only on a successful interrupt, then draw two.** Give timing more value and remove unconditional cycling; retain its disruption against attacks.
43. **Reserve — Give Cold Psalm Retain in exchange for one point of cooling.** Test whether choosing *when* to vent is as valuable as a bigger immediate vent.
44. **Reserve — Let Hull Stitch bank a small part of otherwise wasted repair.** Convert at most 2 overheal to ward, once per turn. Check specifically for free repeated ward at full hull.
45. **Reserve — Make Wake Lance an armor specialist.** Test 12 damage plus up to 3 primary armor ignored in place of flat 14. Require one fixture where each version wins.
46. **Reserve — Tie Thread Cannon’s extra damage to repairing a severed link.** Reward a purposeful attack-and-repair command, not a generic bonus whenever a Link card is drawn.
47. **Reserve — Give Cross Current a different cooling branch.** One evolution cools the *last* organ of a three-organ route instead of the first. The route to take now should depend on which organ the player needs next.
48. **Reserve — Move some Barbed Filament disruption into conditional damage.** Deal damage only when Parry Filament’s offensive evolution actually interrupts; keep Woven Filament the reliable ward choice.
49. **Reserve — Let a costly Blank Page reserve a known card.** Trade its draw for temporary Retain on a selected current hand card. Test whether a future payoff is worth spending 2 CP now.
50. **Reserve — Let Unison repair a phrase as well as a link.** If its Link repairs a cut, restore 1 Resonance *after* the Concert spend. Cap at once per command so it cannot fund itself.

### 51–60 · Powerups: test the source of snowballing

51. **Reserve — Gate Soft Copper on the first effective repair each turn.** Preserve +2 where it matters, remove repeat procs. Measure actual hull restored, excluding overheal.
52. **Reserve — Make Pilgrim Spine require a different three-organ route from the last one.** Preserve its +4 payoff while testing whether repeated routing is currently too automatic.
53. **Reserve — Pay Echo Pearl for a productive amplifier.** Require Echo to increase the attack or Recall/Crescendo to spend resource, rather than awarding damage for touching an idle organ.
54. **Reserve — Convert Velvet Tongue to an interrupt specialist.** Offer +2 on interruptible non-attack intents and zero on ordinary attacks. Check threshold crossings, not merely total disruption printed.
55. **Reserve — Narrow Winter Gland’s extra cooling.** Cool only the two hottest organs by the extra point; show tie order. Test it *with* Wide Lung to see whether saturation becomes relevant again.
56. **Reserve — Make Wide Lung a targeted capacity choice.** At acquisition choose two organs for +2 capacity instead of every organ for +1. Clear build direction at the expense of flexibility.
57. **Reserve — Cap Carrion Grace at two kills per combat.** Use only if spawned or summoned foes enable repeated recovery disproportionate to actual danger.
58. **Reserve — Give Patient Heart a clean-finish condition.** Test 4 recovery if the last enemy phase dealt no hull damage, zero otherwise, versus the current unconditional 2.
59. **Reserve — Make Brass Tithe pay for facing risk.** Concentrate its extra salvage on elites instead of every combat. Audit when it was found; an early economy item has more time to compound.
60. **Hold — Impose a hard powerup inventory cap.** It might suppress a snowball, but would erase build identities without establishing which interactions actually cause it.

### 61–70 · Rewards, shops and recovery: make drafting decisions matter

61. **Reserve — Exchange one elite powerup offer for a prepared evolution offer.** Keep one reward pick. Test whether a coherent deck can compete with taking another passive.
62. **Reserve — Offer a small skip dividend after a guardian.** Test 8 salvage instead of a forced incentive to take an unwanted card; check whether thin decks become strictly better.
63. **Reserve — Sell one shop refresh per visit.** Charge a visible fixed price and use only the shop RNG stream. A missed build piece becomes a spending decision, not a free reroll.
64. **Reserve — Let a player reserve one visible shop item for the next exchange.** Require a nonrefundable deposit. It rewards planning but competes with an immediate purchase.
65. **Reserve — Raise the price of successive powerups within the same shop.** The first keeps its price; the second costs 10 more. Try only if buying both drives the measured gap.
66. **Reserve — Discount the first evolution service in Area 2.** Encourage committing to a card before the final region; compare with an equal amount of unconditional salvage.
67. **Reserve — Offer partial repair plus a minor service at recovery.** Test 15 hull plus a removal against 30 hull alone. A healthy thin-deck strategy should pay a real opportunity cost.
68. **Reserve — Add a one-time paid card exchange.** Trade one unevolved card and salvage for a displayed card of the same rarity; do not secretly fit offers to the player’s deck.
69. **Reserve — Replace one Area 3 ordinary reward slot with a visible role choice.** Let the player select an attack or prevention offer before the card is generated; never promise a specific rare or silently inspect the deck.
70. **Hold — Grant a missing defensive powerup automatically before the last guardian.** It would hide weak drafts instead of making careful early picks more valuable.

### 71–80 · Enemy encounters: reward knowledge rather than adding HP

71. **Reserve — Shift part of Drowned Catalogue’s rebuild into an interrupt reward.** On a successful Restore Record interrupt, let the next primary hit ignore 2 armor. Do not reduce Black Tide or grant damage for ignoring the rebuild.
72. **Reserve — Let a fully prevented Black Tide cost the Catalogue hull.** A small recoil distinguishes a *perfect* defense from simply reducing drain. Use instead of 71, not alongside it.
73. **Reserve — Let a broken Parliament escort expose its guardian briefly.** Give the player one stronger primary hit after removing the last attendant; retain the reason to target attendants first.
74. **Reserve — Give Witness Array an alternative to venting.** A successfully interrupted Sever also reduces its next overload bonus. Test whether the player now has two valid counters rather than one universal answer.
75. **Reserve — Stop a Folio Leviathan from restoring itself on Rebind if its allies are gone.** An alternative if late repair loops prove grindy; keep its armor and its ability to protect allies.
76. **Reserve — Give Undertow Scribe one round of reduced armor after its overload finds no saturated organs.** Reward deliberate cooling with a finishing opportunity.
77. **Reserve — Reward destroying an Ember Cocoon just before hatch.** Deal a small fixed hit to the guardian; compare with killing the egg immediately, so waiting has a real risk.
78. **Reserve — Cap simultaneous group repairs in Area 3 encounter assembly.** Prevent only confirmed unwinnable or excessively long healer pairings. Preserve single-healer and healer-plus-attacker fights.
79. **Reserve — Stagger two opening cut intents in a group.** Offset one enemy’s starting phase on those specific pairings if measured openings remove all meaningful route choices. Show the new phase normally.
80. **Hold — Raise all final-area enemy HP.** This directly worsens the strongest pacing signal, and a longer fight is not necessarily a harder decision.

### 81–90 · Map and events: let the route express a strategy

81. **Reserve — Show the next reachable fork before committing to a node.** Highlight its already-visible successors, making the cost of missing a shop or recovery easier to compare.
82. **Reserve — Show where two routes rejoin.** Mark the first common destination so a risky elite branch can be compared with its actual detour, not the entire rest of the region.
83. **Reserve — Flag a route with no reachable recovery before the guardian.** Derive the marker only from visible map information; make hull conservation an informed bet.
84. **Reserve — Offer an explicit elite bounty.** Before traveling, show a guaranteed salvage premium for that elite. Keep its card/powerup reward exclusive so the risk is legible.
85. **Reserve — Turn the Small Beacon into advance planning.** Offer a choice between immediate salvage and marking a later recovery stop for a larger repair; the player still has to reach it.
86. **Reserve — Let the Thorn Orchard trade maximum hull for a selected evolution.** Display the exact loss and branch first; compare with its existing current-hull-for-salvage choice.
87. **Reserve — Let the Drifting Chapel name its offered powerup before commitment.** Test if informed choices make the card option competitive rather than automatically preferable or irrelevant.
88. **Reserve — Give the Bone Dock a cheaper small repair.** Add a lower-price, lower-repair alternative for a nearly healthy ship. Check that it doesn’t dominate full repair for badly damaged ships.
89. **Reserve — Offer an inter-area commitment.** Forgo part of the 25-hull transition repair to evolve an eligible card. This tests whether confident players will take controlled risk to prepare for Area 3.
90. **Hold — Guarantee a recovery immediately before every guardian.** It would make earlier path planning and hull conservation less consequential.

### 91–100 · Pace, practice and feedback: improve execution without playing for the player

91. **Reserve — In reduced motion, unlock selection after the last consequential impact.** Leave numbers readable in the log; never allow two unresolved commits. Measure seconds per command separately from turns per encounter.
92. **Reserve — Resolve simultaneous secondary-hit labels together.** Keep each enemy’s actual damage and audio readable but avoid making a three-target Fork feel three times slower to operate.
93. **Reserve — Add a one-fight Palimpsest practice puzzle.** From the same visible hand, banking Trace kills one target next command; against a different intent, spending it on Redact is the way to survive. Let the player try both.
94. **Reserve — Add a Choir phrase puzzle with a deliberate trap.** A repeated attack resets the meter; playing a non-attack first sets up a three-point spend. Show the difference after the attempt.
95. **Reserve — Add a post-defeat replay of the last player turn in the sandbox.** Let players try another legal choice without rewriting their expedition or revealing future draws.
96. **Reserve — Add a guardian recap showing missed interrupt and exposed windows.** Distinguish “the window existed” from “you had an affordable legal answer”; never claim an unavoidable loss was the player’s fault.
97. **Reserve — Summarize actual powerup contribution after battle.** Show effective repair, damage and prevented hull loss rather than activation count. Useful for drafting and for checking the stacking hypothesis.
98. **Reserve — Give a successful interrupt its own short, quiet confirmation sound.** Pair it with text so hearing is optional. It should signal an action actually cancelled, not any application of disruption.
99. **Reserve — Soften repeated vent and plasma-launch transients in busy turns.** Compare an untreated take with reducing only overlapping repeats; preserve the first cue and shield catch. The 6:36 capture did not clip but reached −2.1 dBTP.
100. **Hold — Add an automatic “best route” button to standard play.** It would solve the very choice that makes the game difficult. Use authored practice situations and honest forecasts instead.

## Verification and release decision

1. **Freeze the comparison before changing rules.** Preserve the original playtest review and its raw results, six exact seeds `424242, 777, 61579, 11057, 2102, 96327`, policy versions, fresh profiles and content fingerprints. Run the unchanged tactical and simpler policies on both builds. In `tests/playthrough.gd` the kill bonus currently compares *aggregate damage* with the selected enemy’s HP; splash can earn a false kill bonus. Add a separately labelled target-aware diagnostic policy on **both** builds, alongside a two-command, visible-hand Trace/phrase policy. Never silently improve the baseline bot and credit the ship.
2. **Separate the trials.** Measure control, A only and B only before a combined candidate. Capture minimum positive hull, cause and layer of death, enemies actually killed/interrupted, turns per encounter, guardian turns, useful vs. wasted resource spend, whether the changed card was offered/picked/drawn, and effective powerup contributions. Match by seed and encounter where possible; identify diverged paths and incomplete runs. Don’t compare only surviving expeditions.
3. **Prove the arithmetic in the shared rules path.** For A, cover 5 vs. 6 Trace, armor, primary vs. split, organ order, and a case where banking is lethal and Redact survives. For B, check spends 0–3, kind-repeat reset, Concert before organs, both named evolutions and the legacy copy. Include a case in which Bright Canon is the correct pick and another in which Crescendo is. For ward, test 0/2/3 starting ward, mixed printed/install sources and preview=commit. Exercise the actual compact UI and public MCP projection, with no newly exposed hidden data. Relevant owners: `scripts/game.gd` for outcomes, `scripts/main.gd` for display, `scripts/mcp_controller.gd` for advertised actions, `data/catalog.json` for card definitions.
4. **Use explicit playtest gates, not a target human win rate.** On the six calibration seeds, keep damage-first and starter-only difficult: investigate any new win in either. Require at least one documented hard win per ship. For A, seek at least one formerly lost Area 3 case finishing or surviving a previously lethal encounter *because of the full-Trace choice*, plus the same direction on held-out modern seeds. For B, first require the head-to-head damage crossover; only claim a **pacing** improvement if median turns in paired, comparable Choir fights fall by at least **15%**, counting the card’s availability and reporting the all-fights result too. A passing arithmetic test with unchanged voyage length is a card sidegrade, not a solved pacing issue.
5. **Check normal play, compatibility and rollback.** Preselect disjoint modern six-character seed families at fresh and full discovery tiers before tuning; compare old/new *within* tier. Publish counts, limits and timeouts separately, then run the established 720-case plan on the release candidate if the small trials pass. Verify one fresh, isolated, player-visible live MCP expedition per affected ship; review the key decisions at normal speed. Use the existing balance, evolution, route-preview, reward, blind-MCP and save tests, `bash tools/check.sh`, and the protocol-to-scene integration test. Record the rules revision with new expeditions and retain old semantics for in-progress saves and historical replay fixtures; don’t repurpose RNG or reward-generation version numbers. Ship the clarity fixes independently. Drop a failed numerical trial rather than compensating with another buff.

**Deliverable after approval:** a playable balance candidate, paired before/after results and a short change log that says which decisions now pay off, which ships remain hard, and which proposed changes were rejected by playtesting.