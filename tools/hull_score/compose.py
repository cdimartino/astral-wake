"""Engraving sources. Run only to reset the editable masters in midi/."""
from materials import HERE, patch_book
from midi import write

# Beat offsets, lengths, MIDI note and velocity. Spans of rests are written into
# the MIDI end marker; a DAW should not trim the loop to its last note-off.
def part(name, patch, notes): return name, patch, notes


REGIONS = [
    # name, center, tempo, beats per loop, entrance material, answer material
    ("Cradle of Embers", 48, 62, 57, "grain_bow", "wood_ember"),
    ("Choir of Wrecks", 43, 54, 59, "wreck_body", "shell_mallet"),
    ("The Glass Beyond", 51, 60, 63, "reed_mist", "glass_fall"),
    ("Verdant Engine", 50, 66, 62, "reed_wood", "shell_mallet"),
    ("Tidal Archive", 39, 49, 54, "tide_body", "glass_fog"),
    ("Crown of Storms", 45, 58, 70, "bow_thread", "pressure"),
]
REGIONAL_PARTS = [
    [
        part("bowed hull", "grain_bow", [(1,5.8,48,82),(16.75,3.1,51,66),(30,5.7,43,88),(46.5,3.8,48,68)]),
        part("ember", "wood_ember", [(8.25,.42,55,52),(20.6,.31,51,39),(34.85,.47,55,46),(36.22,.32,51,33)]),
        part("vessel motif", "reed_wood", [(24.2,2.4,55,56),(28.1,2.8,58,50)]),
        part("tension", "bow_thread", [(13.1,2.6,55,50),(41.9,2.9,51,54)]),
    ], [
        part("near wreck", "wreck_body", [(.8,4.2,43,86),(22,4.1,46,67),(40.5,4.4,43,71)]),
        part("far wreck", "shell_mallet", [(7.2,2.3,53,58),(17,2.4,50,46),(31.3,2.7,53,62),(49,2.6,46,49)]),
        part("vessel motif", "glass_fall", [(11.3,2.2,50,57),(15.1,2.1,53,50)]),
        part("tension", "pressure", [(25.5,4.2,38,54),(54,2.5,41,47)]),
    ], [
        part("breath", "reed_mist", [(.15,5.4,47,82),(19.2,4.8,52,70),(35.3,3.8,50,61),(50.7,4.9,47,75)]),
        part("rim", "glass_fog", [(3.82,5.2,57,66),(27.4,3.9,54,57),(44.9,4.4,57,58)]),
        part("vessel motif", "glass_fall", [(8.45,2,57,45),(13,2.15,60,40),(39.1,2,57,41)]),
        part("tension", "bow_thread", [(14.12,2.3,54,57),(32.2,3.6,51,48),(54.4,2.1,54,49)]),
    ], [
        part("wood air", "reed_wood", [(.7,4.1,50,79),(11.3,3.7,55,62),(24.1,4.6,50,70),(46.8,3.6,53,74)]),
        part("second breath", "seam_air", [(3.6,4.8,45,60),(18.2,4.1,48,58),(27.3,4.3,45,64),(52.5,3.8,48,53)]),
        part("vessel motif", "shell_mallet", [(34.8,1.7,50,55),(37.35,2.2,53,48)]),
        part("tension", "grain_bow", [(8.5,3.2,45,44),(42.2,3.3,50,48)]),
    ], [
        part("undertow", "tide_body", [(.9,6.2,39,85),(18.1,6.8,34,73),(38.8,5.5,39,65)]),
        part("afterimage", "wreck_body", [(9.3,3.9,39,46),(27.1,3.4,34,42),(45.4,2.8,39,34)]),
        part("vessel motif", "glass_fog", [(13.2,2.9,51,45),(17.05,2.1,54,38)]),
        part("tension", "grain_bow", [(33.3,2.8,42,56),(48.75,2.4,46,47)]),
    ], [
        part("bowed hull", "bow_thread", [(.3,5.3,52,81),(19.4,3.5,53,65),(37.2,4.2,45,81),(44.6,2.5,48,62)]),
        part("pressure swell", "pressure", [(5.2,6.9,40,74),(25.7,5.8,42,71),(48.7,5.6,40,57)]),
        part("vessel motif", "reed_mist", [(12.1,2.6,52,60),(16.4,2.2,55,49)]),
        part("tension", "grain_bow", [(30.6,3.2,46,61),(42.1,2.3,46,53)]),
    ]
]


def score(ident, tempo, length, parts, markers, book):
    write(HERE/"midi"/(ident+".mid"), tempo, length, markers, parts, book)


def engrave():
    book, _ = patch_book()
    for i, (_, center, bpm, length, lead, answer) in enumerate(REGIONS):
        score(f"region_{i}", bpm, length, REGIONAL_PARTS[i],
              [(0,"loop_start"), (length*.25,"phrase"), (length*.62,"phrase"), (length,"loop_end")], book)
        # Ship interval = minor third. Reveals rise but do not return to tonic;
        # clears descend to rest. Each region keeps its own tempo and material.
        for clear in (False, True):
            name = "clear" if clear else "guardian"
            ending = 5.2 if clear else 4.9
            parts = [
                part("hull contact", "shell_knock" if clear else "keel_tap", [(0,.48,60,75 if clear else 81)]),
                part("vessel motif", lead, [(.055,2.1,center+(3 if clear else 0),69)]),
                part("answer", answer, [(1.25,2.85,center+(0 if clear else 3),61)]),
            ]
            if i == 2 and not clear:
                # Preserve the selected listening sketch: C4 psaltery down
                # nine semitones, D#4 rubbed glass down six, 1.23 s apart.
                parts[1] = part("vessel motif","bow_thread",[(.06,2.7,51,69)])
                parts[2] = part("answer","glass_fog",[(1.23,3.5,57,61)])
            answer_beat = parts[2][2][0][0]
            score(f"{name}_{i}", bpm, ending, parts, [(0,name),(answer_beat,"answer"),(ending,"end")],book)
    score("opening", 60, 9, [
        part("keel", "keel_tap", [(.09,.57,56,72)]),
        part("breath", "seam_air", [(.46,4.6,45,81)]),
        part("vessel motif", "grain_bow", [(4.7,2.4,48,64),(7.05,1.85,51,53)])
    ], [(0,"film_start"),(4.7,"phrase"),(8.8,"handoff"),(9,"end")],book)
    score("title", 60, 43, [
        part("vessel motif", "grain_bow", [(.11,3.8,51,57),(16.45,2.6,48,60),(21.6,2.4,51,54)]),
        part("interior", "seam_air", [(5.1,5.1,45,74),(30.7,4.4,45,65)]),
        part("loose shell", "shell_mallet", [(11.9,1.5,48,37),(27.4,1.9,51,33)])
    ],[(0,"loop_start"),(16.45,"phrase"),(43,"loop_end")],book)
    for won in (True, False):
        name = "victory" if won else "defeat"
        parts = [
            part("hull contact","keel_tap", [(0,.55,57,77)]),
            part("vessel motif","grain_bow", [(.1,2.6,48,75),(3.33,2.7,51,71),(6.48,3.9,55 if won else 46,65)]),
            part("afterimage","glass_fall" if won else "seam_air", [(1.5,2.1,55 if won else 43,48),
                 (7.22,3.8,60 if won else 43,56)]),
        ]
        score(name,60 if won else 55,12,parts,[(0,name),(3.33,"phrase"),(6.48,"ending"),(12,"end")],book)


if __name__ == "__main__":
    engrave()
