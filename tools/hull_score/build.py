"""Compile edited MIDI masters to runtime bank; optionally build the DAW pack."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from zipfile import ZipFile, ZIP_DEFLATED

from materials import CODE, HERE, REVISION, SOURCES, edit, patch_book, read_sources, write_wav
from midi import compile_score
from soundfont import display_name, soundfont

ROOT = HERE.parents[1]
BANK = ROOT/"audio/hull" if CODE == HERE else HERE/"rebuilt"/"bank"
DIST = ROOT/"dist" if CODE == HERE else HERE/"rebuilt"
PACK_NAME = "Astral-Wake-Living-Hull"


def json_write(path, data):
    path.write_text(json.dumps(data, indent=2)+"\n")


def compile_bank(folder, samples=True):
    book,cues = patch_book()
    folder.mkdir(parents=True, exist_ok=True)
    if samples:
        sources = read_sources()
        for ident,(_,_,_,cuts) in book.items():
            write_wav(folder/"samples"/f"{ident}.wav",edit(sources, cuts))
    expected = {"opening","title","victory","defeat"} | {
        f"{prefix}_{n}" for n in range(6) for prefix in ["region","guardian","clear"]}
    scores = {p.stem:compile_score(p, book) for p in sorted((HERE/"midi").glob("*.mid"))}
    if set(scores) != expected: raise ValueError("missing or unexpected MIDI master")
    bank = dict(version=1,patches={k:dict(file=f"samples/{k}.wav",root=v[2],bank=v[0],program=v[1])
                for k,v in book.items()},cues=cues,scores=scores)
    json_write(folder/"bank.json",bank)
    print(f"Compiled {len(scores)} editable MIDI masters, {len(book)} patches, {len(cues)} cues → {folder}")
    return bank


def portable(pack, bank, folder):
    from references import renders
    book, _ = patch_book()
    pack.mkdir(parents=True,exist_ok=True)
    # The expanded pack may sit under an open Godot project. Its references and
    # untouched sources are not game resources and must not acquire sidecars.
    (pack/".gdignore").touch()
    (pack/"AstralWake.sf2").write_bytes(soundfont(book,folder/"samples"))
    sfz = pack/"instruments"
    sfz.mkdir(exist_ok=True)
    for name,(_,_,root,_) in book.items():
        (sfz/(name+".sfz")).write_text(f"// Astral Wake | {name}\n<region> sample=../samples/{name}.wav "
              f"lokey=0 hikey=127 pitch_keycenter={root} loop_mode=no_loop ampeg_release=0.079\n")
    for k in book: shutil.copy2(folder/"samples"/f"{k}.wav", _parent(pack/"samples"/f"{k}.wav"))
    shutil.copytree(HERE/"midi",pack/"midi",dirs_exist_ok=True)
    shutil.copytree(HERE/"source",pack/"source",dirs_exist_ok=True,ignore=shutil.ignore_patterns("*.import"))
    for p in CODE.glob("*.py"): shutil.copy2(p, _parent(pack/"authoring"/p.name))
    for p in HERE.glob("*.md"): shutil.copy2(p,pack/p.name)
    json_write(pack/"bank.json",bank)
    mapping = ["# Living hull · patch and track map\n",
        "Numbers below are zero-based SF2 bank/preset and MIDI key numbers. DAWs displaying programs 1–128 add one to the program column. Each patch plays chromatically around its listed root. Bank 0 contains the score; bank 1 the close contacts; bank 2 the alternate recorded takes. These are melodic programs, not a GM drum kit. Each MIDI track selects its instrument explicitly. Load one instance of the SF2 in multitimbral mode, or one SFZ on each indicated MIDI channel.\n",
        "| Bank | Program | SF2 display | Patch / SFZ name | Root | Recorded sources |","|---:|---:|---|---|---:|---|"]
    for k,(b,p,r,c) in book.items(): mapping.append(f"| {b} | {p} | `{display_name(k)}` | `{k}` | {r} | {', '.join(dict.fromkeys(x.source for x in c))} |")
    mapping += ["\n## Parts by piece\n","| MIDI | Channel (1–16) | Part | Patch(es) |","|---|---:|---|---|"]
    for k,s in bank["scores"].items():
        for track,t in s["tracks"].items():
            names = list(dict.fromkeys(e["cue"][6:] for e in s["events"] if e["track"] == track))
            mapping.append(f"| {k} | {t['channel']} | {track} | {', '.join(names)} |")
    (pack/"PATCH-MAP.md").write_text("\n".join(mapping)+"\n")
    provenance = dict(repository="https://github.com/sgossner/VCSL",revision=REVISION,license="CC0-1.0",
                      sources={k:dict(file=f"source/{k}-source.wav", upstream=v[0], sha256=v[1]) for k,v in SOURCES.items()})
    json_write(pack/"SOURCES.json",provenance)
    for alternate in (False,True):
        name = "alternate" if alternate else "factory"
        controls = {id:dict(patch=c["variants"][1]) for id,c in bank["cues"].items()} if alternate else {}
        json_write(_parent(pack/"presets"/(name+".json")),dict(version=1,overrides=controls,muted={},solo="",stingers_enabled=True))
    # Files stay usable after unpacking; do not depend on the repository layout.
    for name in ("README.md","SPOTTING.md"):
        if not (pack/name).is_file(): raise ValueError(f"missing {name}")
    renders(pack/"references",bank,folder)
    files = {"AstralWake.sf2","PATCH-MAP.md","README.md","SPOTTING.md","bank.json","SOURCES.json",
             "presets/factory.json","presets/alternate.json","source/LICENSE-VCSL.txt","references/LISTENING.json",
             "references/glass-guardian-on.wav","references/glass-guardian-off.wav","references/glass-contact-stem.wav"}
    files.update("source/"+k+"-source.wav" for k in SOURCES)
    files.update("authoring/"+p.name for p in CODE.glob("*.py"))
    files.update("midi/"+s+".mid" for s in bank["scores"])
    files.update("references/"+s+".wav" for s in bank["scores"])
    files.update("instruments/"+k+".sfz" for k in book)
    files.update(v["file"] for v in bank["patches"].values())
    manifest = {s:hashlib.sha256((pack/s).read_bytes()).hexdigest() for s in sorted(files)}
    json_write(pack/"SHA256.json", manifest)
    archive = pack.with_suffix(".zip")
    with ZipFile(archive,"w",ZIP_DEFLATED,compresslevel=8) as z:
        for rel in sorted(files | {"SHA256.json"}):
            z.write(pack/rel, pack.name+"/"+rel)
    print(f"{archive} · {archive.stat().st_size:,} bytes · {len(manifest)} files")


def _parent(path):
    path.parent.mkdir(parents=True,exist_ok=True)
    return path


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--pack", action="store_true",help="build standalone SF2/SFZ + MIDI + reference archive")
    cli.add_argument("--bank", type=Path,default=BANK,help="runtime bank output")
    cli.add_argument("--dist",type=Path,default=DIST,help="directory for the expanded and zipped score pack")
    cli.add_argument("--midi-only",action="store_true",help="leave PCM alone, recompile edited note/tempo/marker data")
    a = cli.parse_args()
    compiled = compile_bank(a.bank, not a.midi_only)
    if a.pack: portable(a.dist/PACK_NAME,compiled,a.bank)
