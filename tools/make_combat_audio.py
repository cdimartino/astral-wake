"""Original layered combat Foley: deterministic synthesis, no external samples.

Run independently to rebuild combat sounds without regenerating the music.
"""
import math
import random
import struct

from make_audio import RATE, ROOT, TAU, write

FAMILIES = ("kinetic", "plasma", "fracture", "sonic", "memory", "beam")
SUPPORT = ("repair", "shield", "disrupt", "vent", "sever", "link", "phase", "ready", "draw")


def render(name, duration):
    rng = random.Random(name)
    dry = []
    low_noise = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low_noise += .09 * (noise - low_noise)
        high_noise = noise - low_noise
        attack = min(1, t / .004)
        tail = min(1, (duration - t) / .07)
        impact = name.endswith("_hit")
        family = name.removesuffix("_hit").removesuffix("_launch")
        # Fast mechanical transient and a deeper, longer resonating hull body.
        body = math.sin(TAU * (72 * t + 3.5 * (1 - math.exp(-t * 22)))) * math.exp(-t * 9)
        if family == "kinetic":
            if impact:
                value = .7 * body + .8 * low_noise * math.exp(-t * 7) + .28 * high_noise * math.exp(-t * 65)
                value += .16 * math.sin(TAU * 431 * t) * math.exp(-t * 16)
            else:
                value = .6 * math.sin(TAU * (210 * t + 16 * (1 - math.exp(-t * 38)))) * math.exp(-t * 22)
                value += .35 * high_noise * math.exp(-t * 42) + .25 * low_noise * math.exp(-t * 12)
        elif family == "plasma":
            value = .45 * math.sin(TAU * (95 * t + 18 * (1 - math.exp(-t * 12))) + 2 * math.sin(TAU * 37 * t)) * math.exp(-t * (6 if impact else 12))
            value += low_noise * (1.1 if impact else .7) * math.exp(-t * 6)
            if impact: value += .45 * body
        elif family == "fracture":
            value = .0
            for j, frequency in enumerate([827, 1379, 2267, 3181, 4013]):
                local = t - j * (.023 if impact else .012)
                if local >= 0:
                    value += .24 * math.sin(TAU * frequency * local) * math.exp(-local * (9 + j * 3)) * min(1, local * 600)
            value += (.3 * body if impact else .1 * high_noise * math.exp(-t * 30))
        elif family == "sonic":
            sweep = 135 * t + (12 if impact else 38) * t * t
            value = sum(math.sin(TAU * sweep * ratio) / (j + 2) for j, ratio in enumerate([1, 1.5, 2.01, 3]))
            value *= (.65 + .35 * math.sin(TAU * 18 * t)) * math.exp(-t * 5) * .6
            if impact: value += .4 * body
        elif family == "memory":
            value = 0.0
            for j in range(4):
                local = t - j * .055
                if local >= 0:
                    grain = math.sin(TAU * (380 * local - 150 * local * local) + 3 * math.sin(TAU * 93 * local))
                    value += grain * .3 * math.exp(-local * 18) / (1 + j * .5) * min(1, local * 400)
            if impact: value += .32 * body
        elif family == "beam":
            value = .4 * math.sin(TAU * (950 * t - 620 * t * t) + 2 * math.sin(TAU * 121 * t)) * math.exp(-t * 12)
            value += .12 * high_noise * math.exp(-t * 16)
            if impact: value += .55 * body
        elif name in ("repair", "link", "ready", "draw"):
            notes = {"repair": [330, 440, 554, 660], "link": [220, 330, 440], "ready": [392, 523, 784], "draw": [620, 830]}[name]
            value = 0.0
            for j, frequency in enumerate(notes):
                local = t - j * .075
                if local >= 0:
                    value += (math.sin(TAU * frequency * local) + .2 * math.sin(TAU * frequency * 2.003 * local)) * .22 * math.exp(-local * 7) * min(1, local * 90)
            if name == "repair": value += .3 * low_noise * math.sin(math.pi * t / duration) ** 2
        elif name == "shield":
            value = .5 * math.sin(TAU * 164 * t + 1.5 * math.sin(TAU * 241 * t)) * math.exp(-t * 7)
            value += .3 * body + .15 * high_noise * math.exp(-t * 40)
        elif name in ("disrupt", "sever"):
            gate = .35 + .65 * max(0, math.sin(TAU * (27 * t + 30 * t * t)))
            value = (.35 * high_noise + .35 * math.sin(TAU * (780 * t - 600 * t * t))) * gate * math.exp(-t * 6)
            if name == "sever": value += .4 * body
        elif name == "vent":
            value = (low_noise * 1.6 + high_noise * .14) * math.sin(math.pi * t / duration) ** 1.5
        else:  # Enemy-phase warning: paired low sonar pulses.
            value = 0.0
            for delay in [0, .17]:
                local = t - delay
                if local >= 0: value += .45 * math.sin(TAU * (130 * local - 30 * local * local)) * math.exp(-local * 12) * min(1, local * 150)
        dry.append(math.tanh(value * 1.25) * attack * tail)
    # Short asymmetric reflections give width without losing the centered transient.
    frames = bytearray()
    for i, value in enumerate(dry):
        fade = min(1, (len(dry) - 1 - i) / (RATE * .045))
        left = value + (dry[i - int(RATE * .037)] * .18 if i >= int(RATE * .037) else 0)
        right = value + (dry[i - int(RATE * .053)] * .2 if i >= int(RATE * .053) else 0)
        frames.extend(struct.pack("<hh", round(left * fade * 23500), round(right * fade * 23500)))
    write("combat_" + name, frames)


if __name__ == "__main__":
    ROOT.mkdir(exist_ok=True)
    for family in FAMILIES:
        render(family + "_launch", .38)
        render(family + "_hit", .65)
    for name in SUPPORT:
        render(name, .8 if name in ("repair", "link", "ready") else .55)
    print("Rendered 21 original stereo combat cues.")
