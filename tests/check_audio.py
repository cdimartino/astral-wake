"""Verify released PCM, Type 1 master/compiled score parity and optional DAW pack."""
import argparse
from array import array
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import wave
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/hull_score"))
from materials import HERE, RATE, SOURCES, patch_book
from midi import compile_score

BANK = ROOT/"audio/hull"
REGIONS = {f"{s}_{i}" for s in ("region","guardian","clear") for i in range(6)}
SCORES = REGIONS | {"opening","title","victory","defeat"}
WEAPONS = {f"combat_{family}_{kind}" for family in ("kinetic","plasma","fracture","sonic","memory","beam")
           for kind in ("launch","hit")}
ACTIONS = WEAPONS | {f"combat_{cue}" for cue in "draw discard shield repair disrupt vent sever link phase ready".split()} | set(
    "click play reward transition impact card_select organ_cartographer organ_palimpsest organ_choir choir_phrase shop_buy recovery map_travel ship_select".split())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def waveform(data,channels):
    with wave.open(BytesIO(data)) as w:
        assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getcomptype()) == (channels,2,RATE,"NONE")
        pcm = w.readframes(w.getnframes())
        assert len(pcm) == w.getnframes()*channels*2
    vals = array("h",pcm)
    if sys.byteorder != "little": vals.byteswap()
    return pcm, vals


def beam_band_peak(vals, db):
    """Sliding Hann-windowed sinusoid amplitude across the reported 1.18 kHz ring."""
    n = round(.03*RATE)
    hann = [.5-.5*math.cos(2*math.pi*i/(n-1)) for i in range(n)]
    coefficients = [2*math.cos(2*math.pi*f/RATE) for f in range(1100,1261,20)]
    peak = 0.
    for start in range(0,len(vals)-n+1,round(.005*RATE)):
        window = [a*b for a,b in zip(vals[start:start+n],hann)]
        for c in coefficients:
            q1 = q2 = 0.
            for x in window:
                q1,q2 = x+c*q1-q2,q1
            peak = max(peak,math.sqrt(max(0,q1*q1+q2*q2-c*q1*q2)))
    return db+20*math.log10(max(1,2*peak/sum(hann))/32767)


def check_bank():
    bank = json.loads((BANK/"bank.json").read_bytes())
    book,_ = patch_book()
    assert bank["version"] == 1 and bank["scores"].keys() == SCORES
    assert ACTIONS == {c for c in bank["cues"] if not c.startswith("score_")}
    assert set(bank["patches"]) == set(book)
    assert len({c["group"] for c in bank["cues"].values()}) == 9
    files, clips, mapped = set(), set(), set()
    for k,p in bank["patches"].items():
        file = BANK/p["file"]
        assert file == BANK/"samples"/(k+".wav") and file not in files
        files.add(file)
        pcm,vals = waveform(file.read_bytes(),1)
        sig = digest(pcm)
        assert sig not in clips, f"duplicate patch recording: {k}"
        clips.add(sig)
        peak = max(map(abs,vals))
        assert peak < 32000 and peak > 1800 and not (vals[0] or vals[-1]), (k,"clipping/silent/discontinuous")
        assert 0 <= p["root"] <= 127
    assert set((BANK/"samples").glob("*.wav")) == files
    for k,c in bank["cues"].items():
        variants = c["variants"]
        assert len(set(variants)) == len(variants) >= 2 and set(variants) <= book.keys(), k
        assert c["bus"] == ("Music" if k.startswith("score_") else "Combat" if k.startswith(("combat_","organ_")) or k=="choir_phrase" else "Interface"), k
        assert -32 < c["gain_db"] < 0
        mapped.update(variants)
    assert mapped == set(book), "unreachable patch"
    for k in ("combat_draw","combat_discard","card_select","organ_cartographer","combat_shield","combat_kinetic_hit"):
        c = bank["cues"][k]
        assert len(set(c["round_robin"])) >= 2 and c["variants"][1] not in c["round_robin"], k
    for k in ("combat_beam_launch","combat_beam_hit"):
        cue = bank["cues"][k]
        for name in cue["variants"]:
            _,vals = waveform((BANK/bank["patches"][name]["file"]).read_bytes(),1)
            assert len(vals)/RATE < .2,(name,"tail overlaps the 220 ms beam echo")
            assert beam_band_peak(vals,cue["gain_db"]) < -48,(name,"1.18 kHz ring has returned")
    for name,(_,sha) in SOURCES.items():
        assert digest((HERE/"source"/f"{name}-source.wav").read_bytes()) == sha, name
    layouts = set()
    for name,s in bank["scores"].items():
        assert s == compile_score(HERE/"midi"/(name+".mid"),book), f"recompile after editing {name}.mid"
        markers = {m["name"]:m["time"] for m in s["markers"]}
        assert s["length"] > 0 and len(s["tracks"]) >= 2 and len(s["events"]) >= 2
        for e in s["events"]:
            assert 0 <= e["time"] < e["time"]+e["duration"] <= s["length"]+.000001, (name,e)
            assert e["cue"] in bank["cues"] and e["track"] in s["tracks"]
        if name.startswith("region_") or name == "title":
            assert markers["loop_start"] == 0 and markers["loop_end"] == s["length"]
            assert 0 < markers["phrase"] < s["length"]
        if name.startswith("region_"):
            assert "tension" in s["tracks"]
            gaps = [b["time"]-a["time"] for a,b in zip(s["events"],s["events"][1:])]
            assert max(gaps) > 3 and len(set(round(g,1) for g in gaps)) > 5
            layout = tuple((e["track"],e["cue"],e["time"]) for e in s["events"])
            assert layout not in layouts, "duplicate regional material"
            layouts.add(layout)
        if name.startswith(("guardian_","clear_")):
            assert s["events"][0]["time"] == 0
            answer = next(e for e in s["events"] if e["track"] == "answer")
            assert markers["answer"] == answer["time"] and .9 < answer["time"] < 2
            lead = next(e for e in s["events"] if e["track"] == "vessel motif")
            if name == "guardian_2":
                assert (lead["cue"],lead["note"],lead["time"]) == ("score_bow_thread",51,.060417)
                assert (answer["cue"],answer["note"],answer["time"]) == ("score_glass_fog",57,1.229167)
            else:
                assert answer["note"]-lead["note"] == (3 if name.startswith("guardian") else -3)
    # A DAW adding an unsupported automation lane must not lose it silently.
    pilot = (HERE/"midi/region_2.mid").read_bytes()
    old = b"\xb0\x20\x00"
    assert old in pilot
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp)/"pedal.mid"
        path.write_bytes(pilot.replace(old,b"\xb0\x40\x7f",1))
        try:
            compile_score(path,book)
        except ValueError as error:
            assert "unsupported" in str(error),error
        else: raise AssertionError("unsupported sustain CC was silently discarded")
    print(f"PASS: {len(files)} distinct PCM patches, all {len(ACTIONS)} action cues, 6 sparse regional arrangements and 16 other MIDI scores")
    return bank


def chunks(data):
    """Read RIFF word-aligned subchunks independently from the SF2 writer."""
    at = 0
    while at < len(data):
        tag,size = struct.unpack_from("<4sI",data,at)
        stop = at+8+size
        assert stop <= len(data), (tag,"truncation")
        yield tag,data[at+8:stop]
        at = stop + size%2
    assert at == len(data)


def check_sf2(data,bank,load):
    [(tag,body)] = list(chunks(data))
    assert tag == b"RIFF" and body[:4] == b"sfbk"
    lists = {v[:4]:dict(chunks(v[4:])) for k,v in chunks(body[4:]) if k == b"LIST"}
    assert struct.unpack("<HH",lists[b"INFO"][b"ifil"]) == (2,1)
    pd,pcm = lists[b"pdta"],lists[b"sdta"][b"smpl"]
    def rows(tag,fmt): return list(struct.iter_unpack("<"+fmt,pd[tag]))
    pr, bag, pgen = rows(b"phdr","20sHHHIII"), rows(b"pbag","HH"), rows(b"pgen","HH")
    inst, ibag, igen = rows(b"inst","20sH"),rows(b"ibag","HH"),rows(b"igen","HH")
    shdr = rows(b"shdr","20sIIIIIBbHH")
    assert pr[-1][0].startswith(b"EOP") and inst[-1][0].startswith(b"EOI") and shdr[-1][0].startswith(b"EOS")
    table = {(b,p):(n,zone) for n,p,b,zone,*_ in pr[:-1]}
    assert len(table) == len(shdr)-1 == len(inst)-1 == len(bank["patches"])
    assert len({name for name,_ in table.values()}) == len(table), "ambiguous SF2 display labels"
    for id,p in bank["patches"].items():
        preset_name,zone = table[p["bank"],p["program"]]
        (op,instrument), = pgen[bag[zone][0]:bag[zone+1][0]]
        assert op == 41
        zone = inst[instrument][1]
        op,sample = igen[ibag[zone+1][0]-1]
        assert op == 53
        name,start,end,ls,le,rate,root,_,_,kind = shdr[sample]
        assert preset_name == name and kind == 1 and start <= ls < le <= end
        assert (rate,root) == (RATE,p["root"])
        wav,_ = waveform(load(p["file"]),1)
        assert pcm[2*start:2*end] == wav and pcm[2*end:2*(end+46)] == bytes(92),id


def check_pack(path,bank):
    with ZipFile(path) as archive:
        bad = archive.testzip()
        assert bad is None, bad
        prefix = archive.namelist()[0].split("/")[0]+"/"
        def load(p): return archive.read(prefix+p)
        manifest = json.loads(load("SHA256.json"))
        assert set(archive.namelist()) == {prefix+m for m in manifest}|{prefix+"SHA256.json"}
        for p,sha in manifest.items(): assert digest(load(p)) == sha, p
        assert json.loads(load("bank.json")) == bank
        check_sf2(load("AstralWake.sf2"),bank,load)
        for p,v in bank["patches"].items():
            text = load(f"instruments/{p}.sfz").decode()
            assert "<region> " in text and "sample=../"+v["file"]+" " in text and f"pitch_keycenter={v['root']} " in text
        assert json.loads(load("presets/alternate.json"))["overrides"].keys() == bank["cues"].keys()
        assert json.loads(load("presets/factory.json"))["stingers_enabled"]
        assert "CC0 1.0" in load("source/LICENSE-VCSL.txt").decode()
        for k,s in bank["scores"].items():
            assert load(f"midi/{k}.mid") == (HERE/"midi"/(k+".mid")).read_bytes()
            _,vals = waveform(load(f"references/{k}.wav"),2)
            assert abs(len(vals)/2/RATE-s["length"]) < 1/RATE
            assert 20 < max(map(abs,vals)) < 32000
            if k.startswith("region_"):
                assert max(map(abs,vals[:RATE//10]+vals[-RATE//10:])) == 0, f"{k}: non-silent loop boundary"
        collection = []
        for suffix in ("off","on"):
            _,vals = waveform(load(f"references/glass-guardian-{suffix}.wav"),2)
            assert len(vals) == 33*RATE*2 and max(map(abs,vals)) < 32000
            collection.append(vals)
        energies = [sum(x*x for x in vals) for vals in collection]
        assert abs(10*math.log10(energies[0]/energies[1])) < .01,"A/B level mismatch"
        off,on = collection
        reveal = int(25.6*RATE)*2
        assert sum(abs(x) for x in on[reveal:]) > sum(abs(x) for x in off[reveal:]),"no audible stinger"
    print(f"PASS: SF2 zones/programs match every PCM/key, SFZs resolve, 22 stereo mixes, level-matched guardian A/B, archive digests · {path.name}")


if __name__ == "__main__":
    options = argparse.ArgumentParser(description=__doc__)
    options.add_argument("--pack",type=Path,help="validate a built standalone .zip")
    args = options.parse_args()
    bank = check_bank()
    if args.pack: check_pack(args.pack,bank)
