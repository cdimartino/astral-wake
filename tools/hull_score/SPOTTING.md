# Space heard through a living hull · spotting notebook

The score puts the listening position **inside** the hull. On the map, a sound reaches you after crossing some distance; when you select a card, the contact is under your fingers. Use the difference in distance to make the input legible at low listening volume.

### Three useful comparisons

* [Clark Aboud, *Slay the Spire*](https://clarkaboudmusic.bandcamp.com/album/slay-the-spire-original-soundtrack): the titles mark places and exceptional opponents. Take the distinction between place and event; a track listing doesn't tell us when or how often a game plays it.
* [Ben Prunty on *FTL*](https://www.pcgamer.com/uk/ftl-faster-than-light-soundtrack-ben-prunty/): related exploration and battle materials can preserve a sector's identity across danger. Here the same MIDI arrangement continues and its bowed tension part can enter mid-phrase.
* [Prunty on *Into the Breach*](https://www.pcgamer.com/how-i-made-into-the-breachs-soundtrack/): environmental sound is enough during deployment; the last landing changes what the scene means. Preserve empty planning time, and spend musical gestures on changes of meaning.

| Place | Where to listen | What the silence does |
|---|---|---|
| Cradle of Embers | Grainy low C on bowed psaltery. A very short log-drum/shaker tick interrupts it. | The second tick in a pair is a crumb, not a new beat. |
| Choir of Wrecks | A low G from one body, then a higher, shorter wood/rim answer. | Different decay times make the hulls feel separate. |
| The Glass Beyond | Recorder air at 0.15 s, rubbed glass entering at 3.82 s, free glass release at 8.45 s. | Leave the attack of actual damage to the fracture cue. |
| Verdant Engine | A D-centered breath on wood; the second air column overlaps its end, then separates. | Let the next breath arrive early or late, not like a heartbeat. |
| Tidal Archive | Low E-flat emerges and returns as a quieter body at the same pitch. | Keep the middle register clear for a card or a command. |
| Crown of Storms | Bow tension, pressure, a short unfinished phrase. The last swell falls into the longest wait. | Pressure can recede even at the hardest part of the voyage. |

### What each interruption earns

| Trigger | Material / purpose | When silence wins |
|---|---|---|
| Film → title | The opening plays once. Its tail settles as the picture fades; the title and ship selection stay quiet until the player acts. | The optional title arrangement stays in the composer pack but does not play automatically. A skip releases the active sound instead of triggering another cue. |
| Card draw / select / commit / discard | Shaker downstroke; muted tap; felt behind the brush; very short returning brush. | No ordinary hover; don't score hand contents. |
| Accepted route | Cartographer's precise wood, Palimpsest's delayed trace, Choir's air on a skin. An airy harmonic closes a Choir phrase. | No reward sound for an invalid connection. Let the initial planning turn breathe. |
| Shot / impact | Kinetic skin/thud; plasma air/rush; fracture little rim shards; sonic vibrating shell; memory trace in reverse; beam a low brush gliding into a damped skin or wood contact. | Busy split attacks need individual contacts, not six simultaneous musical accents. |
| Ward / repair / vent / sever | Rim caught by drum; brush pulled into wood; dry exhale; abruptly gated cut. Enemy phase is the uneven two knocks. | No stinger on damage, expiry, draw, discard or enemy turn. |
| Travel / recovery / shop / reward | A passing wash, air releasing, short clasp, one warm overtone. | Don't repeat on every shop or map redraw. |
| Guardian reveal | One low contact on the reveal, lead tone, then an unfinished interval. Most rise a minor third; Glass retains the wider interval of the chosen pilot. | The guardian comment should fire once, not on resume. Independent mute for repeated comparisons. |
| Region clear | Same contact/answer form, turned downward to the regional center. | Skip on the final boss: the voyage outcome supersedes it. |
| Voyage end | The first two notes are shared. Victory rises to an open fifth; defeat falls away to a lower unsettled answer. | Spend the full phrase once. Never delay a decision for a musical tail. |

### What the Glass pilot changed

The starting sketch compared the same reveal with and without pitched music. **The guardian stinger was chosen**; it remains deliberately smaller than the split attack. In Glass, the contact sits on the reveal, low psaltery enters 60 ms later and the thin rubbed-glass answer arrives at 1.23 seconds. Both glass instruments survived as independently selectable patches. Shield A is the resonant rim over a stopped skin; B puts the weight into a wooden shell. Repeated card, hit and organ contacts can use a second recorded strike without switching material. Ordinary rewards retain just their overtone; there is no reward MIDI fanfare.

The playthrough exposed a different sound at 9.7 s: repeated beam launches and impacts stacked a pitched scrape above the quiet bed. The revised launch uses shaker and low recorder air; the impact brushes past a muted skin, or soft wood in the alternate. Neither gesture uses bowed string or glass. Factory gain is 9 dB lower for both, and each individual edit ends before the next launch in the reported 220 ms pair.

For an offline A/B, start `references/glass-guardian-off.wav` and `glass-guardian-on.wav` at zero without adjusting the monitor. Both include 10 s of planning, draw and selection, three contacts, split fracture, a shield catch, repair, reward, then the same unpitched reveal at 25.6 s. The pitched reply is the only arrangement change. Both **complete takes** are matched by stereo RMS with a single trim on the music bus; the contact stem (`glass-contact-stem.wav`) is identical in both. See `references/LISTENING.json` for the trims and peaks. There is no limiting or per-event normalization. Individual score reference WAVs use a common mix gain to preserve inter-piece dynamics.
