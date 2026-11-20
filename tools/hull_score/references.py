"""Reference mixer using only the compiled MIDI, recorded patch PCM and cue map.

Slight stereo placement for part separation. A listening reference, not game capture.
"""
from array import array
import json
import math
import sys
import wave

from materials import RATE, write_wav


class Renderer:
    def __init__(self, bank, folder):
        self.bank, self.pcm = bank, {}
        for k,p in bank["patches"].items():
            with wave.open(str(folder/p["file"])) as w:
                self.pcm[k] = array("h",w.readframes(w.getnframes()))
                if sys.byteorder != "little": self.pcm[k].byteswap()

    def hit(self,mix,at,cue,note=None,velocity=127,duration=None,pan=0,variant=0):
        c = self.bank["cues"][cue]
        patch = c["variants"][variant]
        root = self.bank["patches"][patch]["root"]
        step = 2**(((root if note is None else note)-root)/12)
        gain = 10**(c["gain_db"]/20) * velocity/127
        source = self.pcm[patch]
        offset = round(at*RATE)
        release = .15
        n = min(len(mix[0])-offset,int((len(source)-1)/step))
        if duration is not None: n = min(n, round((duration+release)*RATE))
        left,right = mix
        l = gain*math.sqrt((1-pan)/2)
        r = gain*math.sqrt((1+pan)/2)
        for i in range(n):
            pos = i*step
            j = int(pos)
            v = source[j]+(pos-j)*(source[j+1]-source[j])
            if duration is not None and i > duration*RATE:
                v *= max(0,1-(i-duration*RATE)/(release*RATE))**2
            left[i+offset] += v*l
            right[i+offset] += v*r

    def notes(self,mix,id,at=0,tension_since=0,include=None,exclude=()):
        score = self.bank["scores"][id]
        for e in score["events"]:
            if (include is not None and e["track"] not in include) or e["track"] in exclude: continue
            if e["track"] == "tension" and e["time"] < tension_since: continue
            index = score["tracks"][e["track"]]["channel"]
            self.hit(mix,at+e["time"],e["cue"],e["note"],e["velocity"],e["duration"],
                     {1:-.14,2:.19,3:.04,4:-.09}.get(index,0))


def stereo(seconds):
    return [array("f",[0])*round(seconds*RATE) for _ in range(2)]


def output(path, mix, gain=1):
    pcm = array("h")
    peak = 0
    for l,r in zip(*mix):
        p = max(abs(l),abs(r))*gain
        if p > 32000: raise ValueError(f"{path} clipping at {p}")
        peak = max(peak,p)
        pcm.extend((round(l*gain),round(r*gain)))
    write_wav(path,pcm,2)
    return round(20*math.log10(peak/32767),2)


def rms(mix):
    return math.sqrt(sum(x*x for channel in mix for x in channel)/(2*len(mix[0])))


def renders(folder, bank, sample_root):
    folder.mkdir(parents=True,exist_ok=True)
    renderer = Renderer(bank,sample_root)
    levels = {}
    for name,s in bank["scores"].items():
        mix = stereo(s["length"])
        renderer.notes(mix,name)
        levels[name] = output(folder/(name+".wav"),mix)

    # Pilot spotting script: the same interactions on both takes. The cue for
    # the reveal exists unpitched in both; the short musical comment is optional.
    cue_sheet = [
        (10.2,"combat_draw",0), (10.8,"card_select",0),
        (11.65,"organ_cartographer",0),(12.43,"organ_cartographer",2),(13.55,"organ_cartographer",0),
        (14.82,"combat_fracture_launch",0),(15.6,"combat_fracture_hit",0),
        (15.81,"combat_fracture_hit",2),(17.35,"combat_phase",0),(18.12,"combat_shield",0),
        (21.3,"combat_repair",0),(23.15,"reward",0)
    ]
    before,contacts = stereo(33),stereo(33)
    renderer.notes(before,"region_2",tension_since=13.55)
    for at,cue,variant in cue_sheet: renderer.hit(contacts,at,cue,variant=variant)
    renderer.notes(contacts,"guardian_2",25.6,include={"hull contact"})
    after = [c[:] for c in before]
    renderer.notes(after,"guardian_2",25.6,exclude={"hull contact"})
    output(folder/"glass-contact-stem.wav",contacts)
    # Trim only the music bus; the printed contact stem remains sample-identical.
    # Match whole-take energy: sum((contact + g * music)^2) = target energy.
    dot = lambda a,b: sum(x*y for aa,bb in zip(a,b) for x,y in zip(aa,bb))
    music_target = dot(before,before) + 2*dot(before,contacts)
    takes = []
    for suffix,mix in (("off",before),("on",after)):
        a,b = dot(mix,mix),dot(mix,contacts)
        gain = (-b+math.sqrt(b*b+a*music_target))/a
        total = [array("f",(v*gain+c for v,c in zip(music,contact))) for music,contact in zip(mix,contacts)]
        peak = output(folder/f"glass-guardian-{suffix}.wav",total)
        takes.append(dict(file=f"glass-guardian-{suffix}.wav",music_bus_trim_db=round(20*math.log10(gain),3),
                          contact_bus_trim_db=0,peak_dbfs=peak,full_take_rms_dbfs=round(20*math.log10(rms(total)/32767),3)))
    (folder/"LISTENING.json").write_text(json.dumps(dict(sample_rate=RATE,reference_peak_dbfs=levels,
        guardian_comparison=takes,guardian_at_seconds=25.6,actions=cue_sheet,
        common_reveal_track="guardian_2/hull contact",source="Offline MIDI/PCM desk reference; not a live gameplay capture."),indent=2)+"\n")
