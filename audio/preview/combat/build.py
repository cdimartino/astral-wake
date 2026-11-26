"""Extract the reviewed isolated events, never the complete mixed sampler.

No new synthesis/normalization. Attack/ward windows were entirely replaced by
the retained authored mock generator. Kill/clear are actual native source-bus
stems, before Combat/Music/Master, from round 2.
"""
from array import array
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import wave

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]


def read(path):
    with wave.open(str(path)) as w:
        assert w.getframerate()==48000 and w.getnchannels()==2 and w.getsampwidth()==2
        return array("h",w.readframes(w.getnframes()))


def main():
    mock=ROOT/"dist/audio-review-round-1/attacks/02-enemy-phase-and-defenses--AFTER.wav"
    native=ROOT/"dist/audio-review-round-2/combat/qa"
    definitions=[
        ("ward",mock,Fraction(11,6),Fraction(73,100),6.020599913279624),
        ("enemy_kinetic_launch",mock,Fraction(10,3),Fraction(3,10),6.020599913279624),
        ("enemy_kinetic_hit",mock,Fraction(109,30),Fraction(76,100),6.020599913279624),
        ("enemy_sonic_launch",mock,Fraction(76,15),Fraction(3,10),6.020599913279624),
        ("enemy_sonic_hit",mock,Fraction(161,30),Fraction(91,100),6.020599913279624)]
    for key,source,length,window in [
        ("kill",native/"AuditionKill-diagnostic.wav",.38,(4,6)),
        ("clear",native/"AuditionClear-diagnostic.wav",1.70,(12,15))]:
        samples=read(source)
        first=next(i for i in range(int(window[0]*96000),int(window[1]*96000)) if samples[i])
        definitions.append((key,source,Fraction(first//2,48000),Fraction(str(length)),0.0))
    manifest={}
    for key,source,start,length,compensation in definitions:
        samples=read(source)
        start_frame=round(start*48000)
        frames=round(length*48000)
        selected=samples[start_frame*2:(start_frame+frames)*2]
        assert len(selected)==frames*2 and 0<max(map(abs,selected))<32767
        destination=HERE/(key+".wav")
        with wave.open(str(destination),"wb") as w:
            w.setparams((2,2,48000,0,"NONE","not compressed"))
            w.writeframes(selected.tobytes())
        manifest[key]=dict(source=str(source.relative_to(ROOT)),
            source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            source_start_frame=start_frame,frames=frames,seconds=frames/48000,
            compensation_db=compensation,sha256=hashlib.sha256(destination.read_bytes()).hexdigest())
    (HERE/"provenance.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("PASS seven isolated per-event WAVs; no mixed sampler playback")


if __name__=="__main__":main()
