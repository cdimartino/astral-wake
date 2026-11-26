"""Recorded edits in the living hull bank. Times are seconds, pitches semitones."""
from array import array
from dataclasses import dataclass, replace
import hashlib
import math
from pathlib import Path
import sys
import wave

CODE = Path(__file__).resolve().parent
HERE = CODE.parent if CODE.name == "authoring" and (CODE.parent/"midi").is_dir() else CODE
RATE = 24000
REVISION = "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
# Seven untouched takes from the listening sketch, plus three alternate strikes.
SOURCES = {
    "glass": ("Idiophones/Friction Idiophones/Wine Glasses/Sustains/Fast/glass1_D#4_Fast_1_main.wav", "689b0794c3ea57825e51ddac092ccfa087814c142f88ec20764681b5997a1ba3"),
    "release": ("Idiophones/Friction Idiophones/Wine Glasses/Releases/Fast/glass1_D#4_Fast_1_Decay.wav", "bab9b423a5c9177d07d899f10f281f1cd6085704859a7f25b3cc80cefb9c0083"),
    "breath": ("Aerophones/Edge-blown Aerophones/Baroque Bass Recorder/SusVib/BassRecorder_SusVib_D3_rr1_Main.wav", "80d0724f1c73ee1979b09aaba64a83656f0fed182170930dc0e1b846cbe4acea"),
    "bow": ("Chordophones/Zithers/Psaltery, Bowed and Plucked/LongBow/BowedPsaltery_C4_Main_LongBow_rr1.wav", "57f455c9412f2d642e8d423207aa7a12f48dde77293283d058636b08cd8fdfb0"),
    "card": ("Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerLowFaster_Down_rr1.wav", "4f8c887b138696c2dc47003d6b35a2be29da33e548afc4e43e07a4a60723ef65"),
    "wood": ("Idiophones/Struck Idiophones/Slit Drum/LogDrumLo_MedM_v1_rr1_Sum.wav", "cb77b9a6e7fc560d03b45102632ee0be5d08158cb03f59d63dd6fd2c4443ba4f"),
    "felt": ("Membranophones/Struck Membranophones/Frame Drum/HDrumL_HitMuted_v2_rr1_Sum.wav", "fb08d2a29537fb6da0852ad8318709b8cbc312633237ca969e6e8f95ab5ca075"),
    "card2": ("Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerLowFaster_Down_rr2.wav", "c448de8d6f3bfe410d3ea3ef672a9065dbf40b4d042e0f73e9eecce1e64b7116"),
    "wood2": ("Idiophones/Struck Idiophones/Slit Drum/LogDrumLo_MedM_v2_rr1_Sum.wav", "609a9ae5441a007371e0dc3120d7e6d4ad5d23073f5f4fb3f16d0dc08823dfc4"),
    "felt2": ("Membranophones/Struck Membranophones/Frame Drum/HDrumL_HitMuted_v2_rr2_Sum.wav", "f9ed09653a870811a2f2843e0fa7fa860293a206629d47414bb7ae7039d3bcef"),
    "harp": ("Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_C3_v2_RR1.wav", "bfc5a2cae93793ac46bfe50c1b71d1e64e29eba34e71164c47c29e67488abd96"),
    "hammer": ("Chordophones/Zithers/Grand Piano, Steinway B/NoSus/JHPiano_NoSus_Close_C3_vl2_rr1.wav", "53c2cf94051119d240c8ccd4b9a91f07aa07333d845515c1ea1276daa775549e"),
}


def read_sources():
    sources = {}
    for key, (_, sha) in SOURCES.items():
        file = HERE / "source" / f"{key}-source.wav"
        if hashlib.sha256(file.read_bytes()).hexdigest() != sha:
            raise ValueError(f"source revision mismatch: {file}")
        with wave.open(str(file)) as w:
            channels, width, rate, count = w.getparams()[:4]
            data = w.readframes(count)
        frames = array("f")
        for pos in range(0, len(data), channels * width):
            frames.append(sum(int.from_bytes(data[i:i+width], "little", signed=True)
                              for i in range(pos, pos + channels*width, width)) /
                          (channels * 2 ** (8*width-1)))
        peak = max(map(abs, frames))
        onset = next(i for i, v in enumerate(frames) if abs(v) > .012 * peak)
        sources[key] = rate, frames[max(0, onset - round(rate*.004)):]
    return sources


@dataclass(frozen=True)
class Cut:
    source: str
    length: float
    pitch: float = 0
    offset: float = 0
    attack: float = .008
    tail: float = .08
    hz: float = 4800
    at: float = 0
    weight: float = 1
    reverse: bool = False


def edit(sources, cuts):
    mix = array("f", [0]) * (1 + round(RATE * max(c.at+c.length for c in cuts)))
    for c in cuts:
        rate, data = sources[c.source]
        step = rate / RATE * 2 ** (c.pitch / 12)
        start = int(rate*c.offset)
        n = min(round(c.length*RATE), int((len(data)-start-2)/step))
        if n < 20:
            raise ValueError(f"empty cut: {c}")
        filtered = 0.
        damp = 1 - math.exp(-2*math.pi*c.hz/RATE)
        for i in range(n):
            pos = start + (n-1-i if c.reverse else i)*step
            j = int(pos)
            filtered += damp*(data[j] + (pos-j)*(data[j+1]-data[j]) - filtered)
            env = min(1., i/(c.attack*RATE), (n-1-i)/(c.tail*RATE))
            mix[round(c.at*RATE)+i] += filtered*c.weight*env*env
    # Keep source dynamics inside the take; matched absolute peak across alternates.
    gain = .66*32767 / max(map(abs, mix))
    return array("h", (round(v*gain) for v in mix))


def write_wav(path, pcm, channels=1):
    path.parent.mkdir(parents=True, exist_ok=True)
    if sys.byteorder != "little":
        pcm = pcm[:]
        pcm.byteswap()
    with wave.open(str(path), "wb") as w:
        w.setparams((channels, 2, RATE, 0, "NONE", "not compressed"))
        w.writeframes(pcm.tobytes())


# For sustained parts the attacks are preparatory noise; allow them room.
def long(source, length, pitch, offset, swell, tail, hz):
    return Cut(source, length, pitch, offset, swell, tail, hz)


# program, id, MIDI root note, contrasting partner, mixer group, edits
MUSIC = [
    ("reed_mist", 50, "reed_wood", "score instruments", [long("breath", 5.8, 0, .05, .72, 1.45, 1650)]),
    ("reed_wood", 50, "reed_mist", "score instruments", [long("breath", 4.3, 0, .74, .28, .84, 2900), Cut("wood", .28, -7, at=.04, weight=.06)]),
    # Legacy patch and program IDs are bound in Sound Desk presets and DAWs.
    # Use the ringing wood of a finger-plucked harp, no oscillating bow hair.
    # VCSL's folk harp C3 has a measured 261 Hz fundamental (MIDI 60),
    # unlike the piano C3 at 131 Hz; correct it to the established root 48.
    ("grain_bow", 48, "pressure", "score instruments", [long("harp", 5.6, -12, 0, .027, 1.05, 1950)]),
    ("bow_thread", 60, "grain_bow", "score instruments", [long("bow", 4.8, 0, 1.65, .37, 1.2, 2350)]),
    ("glass_fog", 57, "glass_fall", "regional atmospheres", [long("glass", 6.3, -6, 1.3, 1.23, 1.65, 1550)]),
    ("glass_fall", 57, "glass_fog", "regional atmospheres", [long("release", 3.95, -6, .02, .28, 1.1, 2100)]),
    ("shell_mallet", 51, "wood_ember", "score instruments", [Cut("wood", .31, -8, hz=1450), long("release", 2.4, -12, .17, .14, .7, 1100)]),
    ("wood_ember", 51, "shell_mallet", "score instruments", [Cut("wood", .67, -4, hz=2000), Cut("card", .11, -6, at=.025, weight=.08)]),
    ("tide_body", 39, "wreck_body", "regional atmospheres", [long("glass", 8.4, -24, 4.1, 1.7, 2.6, 700)]),
    ("wreck_body", 43, "tide_body", "regional atmospheres", [long("release", 5.7, -20, .035, .22, 1.85, 1000), Cut("felt", .44, -5, weight=.12)]),
    ("seam_air", 45, "pressure", "regional atmospheres", [long("breath", 6.7, -5, .2, 1.4, 2.15, 890)]),
    ("pressure", 42, "seam_air", "regional atmospheres", [long("hammer", 7.5, -6, 0, .034, 1.64, 1120)]),
    ("keel_tap", 60, "shell_knock", "outcomes/cinematics", [Cut("felt", .62, -2, hz=2200), Cut("wood", .26, -5, at=.018, weight=.35)]),
    ("shell_knock", 60, "keel_tap", "outcomes/cinematics", [Cut("wood", .54, -7, hz=1650), Cut("felt", .36, at=.035, weight=.22)]),
]


# Close contacts have no room reverb baked in. Offset, reverse and damping
# define each gesture; e.g. a catch stops a skin while a vent lets air through.
def brush(length=.19, pitch=-4, **kw): return Cut("card", length, pitch, **kw)
def tap(length=.32, pitch=-3, **kw): return Cut("wood", length, pitch, **kw)
def skin(length=.46, pitch=-2, **kw): return Cut("felt", length, pitch, **kw)
def air(length=.52, pitch=-4, **kw): return Cut("breath", length, pitch, **kw)
def soft_contact(length=.45, pitch=-4, **kw): return Cut("wood", length, pitch, **kw)
def rim(length=.58, pitch=-4, **kw): return Cut("release", length, pitch, **kw)


# cue, group, bus gain, factory articulation, alternate articulation. The
# paired edits differ in material or gesture, not just volume/random pitch.
FOLEY = {}
def gesture(name, group, db, a, b):
    FOLEY[name] = (group, db, a, b)


UI, SHIP, PLACE, LAUNCH, HIT, SUPPORT = (
    "cards/interface", "ship/organ voices", "travel/locations",
    "weapon launches", "impacts", "support/status")
gesture("click", UI, -12, [tap(.09, 4, tail=.04)], [skin(.11, 7, tail=.05)])
gesture("card_select", UI, -12, [brush(.09, -5), tap(.08, 2, weight=.25)], [brush(.12, 2, reverse=True), skin(.1, 5, weight=.15)])
gesture("play", UI, -8, [brush(.13), skin(.29, at=.07)], [tap(.25, -7), brush(.15, 1, weight=.3)])
gesture("impact", HIT, -6, [skin(.54, -4), tap(.22, -2, weight=.3)], [tap(.36, -8), skin(.36, 3, at=.03)])
gesture("reward", PLACE, -10, [tap(.24, -3), rim(1.1, -9, attack=.08, at=.03)], [skin(.2, 2), rim(.95, -5, attack=.13, at=.08)])
gesture("transition", PLACE, -13, [brush(.42, -17, attack=.09, tail=.2)], [air(.58, -11, attack=.14, tail=.26)])
gesture("ship_select", SHIP, -11, [skin(.34, -5), soft_contact(.62, -12, attack=.12, weight=.24)], [tap(.36, -9), air(.47, -9, attack=.1, weight=.18)])
gesture("organ_cartographer", SHIP, -10, [tap(.25, 0), brush(.07, 2, weight=.17)], [tap(.21, 3, offset=.012), skin(.16, 9, weight=.2)])
gesture("organ_palimpsest", SHIP, -10, [tap(.23, -3), tap(.19, -6, at=.14, weight=.24)], [skin(.22, 2), brush(.21, -7, reverse=True, at=.09, weight=.29)])
gesture("organ_choir", SHIP, -11, [skin(.22, 4), air(.32, 0, attack=.065, weight=.17)], [tap(.2, -1), air(.27, 2, reverse=True, weight=.25)])
gesture("choir_phrase", SHIP, -10, [air(.85, 3, attack=.14, tail=.39), rim(.47, -2, weight=.18)], [air(.69, 0, attack=.1, tail=.31), soft_contact(.55, 5, weight=.1)])
gesture("shop_buy", PLACE, -9, [tap(.17, 3), skin(.23, -2, at=.092)], [skin(.13, 5), tap(.22, -4, at=.07)])
gesture("recovery", PLACE, -11, [air(.85, -5, attack=.14, tail=.41), rim(.87, -10, at=.19, weight=.26)], [soft_contact(1.05, -12, attack=.23, tail=.43), brush(.18, -9, weight=.24)])
gesture("map_travel", PLACE, -12, [brush(.38, -14, reverse=True, attack=.07), air(.8, -9, at=.15, attack=.11, tail=.41)], [soft_contact(.88, -15, attack=.22, tail=.41), brush(.34, -11, at=.42, weight=.42)])
gesture("combat_kinetic_launch", LAUNCH, -7, [brush(.12, -4), skin(.27, -1, at=.039)], [tap(.22, -6), brush(.21, -5, weight=.36)])
gesture("combat_kinetic_hit", HIT, -4, [skin(.5, -6), tap(.29, -4, at=.009, weight=.5)], [skin(.39, 1), tap(.24, -9, at=.027)])
gesture("combat_plasma_launch", LAUNCH, -8, [brush(.36, -11, reverse=True), air(.36, -9, attack=.08, weight=.5)], [air(.43, -5, attack=.06), soft_contact(.22, 3, reverse=True, weight=.18)])
gesture("combat_plasma_hit", HIT, -6, [skin(.41, 0), brush(.3, -9, at=.044), air(.44, -7, weight=.46)], [tap(.29, -5), air(.46, -12, at=.03), brush(.2, -6, weight=.6)])
gesture("combat_fracture_launch", LAUNCH, -8, [tap(.16, 9), rim(.31, 5, at=.052, tail=.12)], [brush(.12, 8), rim(.37, 2, reverse=True)])
gesture("combat_fracture_hit", HIT, -7, [rim(.34, 6), tap(.13, 9, at=.024), rim(.19, 12, at=.092), brush(.17, 4, at=.145)], [tap(.16, 6), rim(.24, 9, at=.038), brush(.14, 7, at=.097), tap(.13, 13, at=.16)])
gesture("combat_sonic_launch", LAUNCH, -8, [rim(.49, -13, attack=.09), skin(.18, 0, weight=.23)], [soft_contact(.44, -14, attack=.07), tap(.24, -5, weight=.4)])
gesture("combat_sonic_hit", HIT, -6, [skin(.36, -1), rim(.78, -16, at=.016)], [tap(.42, -6), soft_contact(.67, -17, at=.026, tail=.27)])
gesture("combat_memory_launch", LAUNCH, -9, [rim(.43, -8, reverse=True, tail=.035), brush(.11, -1, at=.38)], [air(.39, -5, reverse=True, tail=.027), tap(.14, -1, at=.35)])
gesture("combat_memory_hit", HIT, -7, [skin(.27, -3), rim(.48, -9, reverse=True, at=.08)], [tap(.25, -4), soft_contact(.52, -8, reverse=True, at=.053)])
# Split beams used to stack .5 s of bowed pitch around 1.18 kHz. Instead a
# low brush glides toward a damped, tangential contact. No rim or bowed tail.
gesture("combat_beam_launch", LAUNCH, -18, [
    brush(.165, -10, attack=.025, tail=.072, hz=1150),
    air(.165, -16, attack=.04, tail=.08, hz=560, at=.012, weight=.16),
], [
    brush(.143, -8, offset=.014, attack=.017, tail=.063, hz=900),
    tap(.105, -10, offset=.022, attack=.018, tail=.045, hz=720, weight=.13),
])
gesture("combat_beam_hit", HIT, -16, [
    brush(.097, -11, attack=.014, tail=.044, hz=1060),
    skin(.131, -4, offset=.017, attack=.018, tail=.072, hz=830, at=.034, weight=.40),
], [
    tap(.117, -9, offset=.016, attack=.021, tail=.06, hz=770, weight=.47),
    brush(.129, -12, offset=.008, attack=.013, tail=.065, hz=920, at=.023),
])
gesture("combat_repair", SUPPORT, -8, [brush(.24, -9, reverse=True), tap(.31, -2, at=.18)], [air(.29, -6, reverse=True), skin(.27, 2, at=.23)])
gesture("combat_shield", SUPPORT, -6, [skin(.35, -1), rim(.69, -7, attack=.026, at=.025, weight=.56)], [tap(.34, -8), skin(.3, 3, at=.017), rim(.35, -13, weight=.22)])
gesture("combat_disrupt", SUPPORT, -9, [soft_contact(.28, -1, reverse=True), tap(.093, 5, at=.18)], [rim(.22, -2, tail=.028), brush(.15, 2, at=.09)])
gesture("combat_vent", SUPPORT, -10, [brush(.4, -13), air(.7, -11, attack=.11, tail=.3, weight=.32)], [air(.57, -7, reverse=True, tail=.17), brush(.22, -6, at=.32)])
gesture("combat_sever", SUPPORT, -8, [brush(.15, 5, reverse=True, tail=.009), tap(.1, 6, at=.097, tail=.012)], [soft_contact(.19, 5, tail=.012), skin(.1, 9, at=.13, tail=.015)])
gesture("combat_link", SUPPORT, -10, [tap(.17, -3), tap(.23, 1, at=.075, weight=.66)], [skin(.14, 4), tap(.18, -1, at=.09)])
gesture("combat_phase", SUPPORT, -7, [tap(.24, -1), skin(.31, 4, at=.21), tap(.19, 1, at=.21, weight=.5)], [skin(.2, 5), tap(.32, -3, at=.2)])
gesture("combat_ready", SUPPORT, -10, [skin(.22, 2), tap(.23, 2, at=.045, weight=.45)], [tap(.2, -2), rim(.31, -2, weight=.25)])
gesture("combat_draw", UI, -12, [brush(.22, -6, attack=.012)], [brush(.18, 0, offset=.022), brush(.11, -5, at=.057, weight=.27)])
gesture("combat_discard", UI, -12, [brush(.14, 1, reverse=True, tail=.036)], [brush(.12, 3, offset=.019), skin(.09, 9, at=.078, weight=.11)])


def patch_book():
    """Stable program numbers within each bank; IDs and cuts used by all outputs."""
    book, cues = {}, {}
    for program, (name, root, alt, group, cuts) in enumerate(MUSIC):
        book[name] = (0, program, root, cuts)
        cues["score_"+name] = dict(group=group, bus="Music", variants=[name, alt], gain_db=-12)
    for index, (cue, (group, db, a, b)) in enumerate(FOLEY.items()):
        ids = [cue+"_near", cue+"_hollow"]
        for j, cuts in enumerate([a, b]):
            book[ids[j]] = (1, 2*index+j, 60, cuts)
        bus = "Combat" if cue.startswith(("combat_", "organ_")) or cue == "choir_phrase" else "Interface"
        cues[cue] = dict(group=group, bus=bus, variants=ids, gain_db=db)
        if group in (UI, SHIP, HIT, LAUNCH) or cue == "combat_shield":
            rr = [replace(c,source=c.source+"2") if c.source in ("card","wood","felt") else c for c in a]
            if rr != a:
                take = cue+"_take2"
                book[take] = (2, index, 60, rr)
                ids.append(take)
                cues[cue]["round_robin"] = [ids[0],take]
    return book, cues
