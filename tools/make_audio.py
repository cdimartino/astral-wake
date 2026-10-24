"""Original stereo space music and interface cues; deterministic stdlib synthesis."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'audio'
RATE = 22050
TAU = math.tau

def write(name, frames):
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)

def music(region):
    duration = 48
    bases = [[55, 65.406, 49, 73.416], [43.654, 55, 41.203, 49], [65.406, 49, 58.27, 43.654],
             [73.416, 87.307, 65.406, 97.999], [32.703, 38.891, 29.135, 36.708], [49, 58.27, 46.249, 65.406]][region]
    ratios = [1, 1.5, 2, 2.378414, 2.996614]
    notes = [0, 2, 4, 3, 2, 1, 4, 2, 0, 3, 4, 1]
    if region == 3:
        ratios = [1, 1.25, 1.5, 2, 2.5]
        notes = [0, 1, 2, 4, 3, 2, 1, 3, 4, 2, 1, 0]
    elif region == 4:
        ratios = [1, 1.498307, 1.887749, 2, 2.828427]
        notes = [0, 0, 2, 1, 0, 3, 1, 0, 4, 2, 0, 1]
    elif region == 5:
        ratios = [1, 1.189207, 1.5, 2.244924, 3]
        notes = [4, 0, 3, 1, 4, 2, 0, 4, 1, 3, 2, 4]
    # Whole-cycle oscillators and a wrapped chord crossfade make the 48s buffer circular.
    frequencies = [[round(base * ratio * duration) / duration for ratio in ratios] for base in bases]
    frames = bytearray()
    for i in range(duration * RATE):
        t = i / RATE
        segment = int(t // 12)
        local = t % 12
        blend = .5 - .5 * math.cos(math.pi * min(1.0, local / 3))
        base = bases[segment]
        pad = 0.0
        side = 0.0
        for chord, weight in [((segment - 1) % 4, 1 - blend), (segment, blend)]:
            if weight == 0:
                continue
            for voice, frequency in enumerate(frequencies[chord]):
                motion = .7 + .3 * math.sin(TAU * round((.09 + voice * .017) * duration) * t / duration)
                phase = voice * .7 + .3 * math.sin(TAU * 6 * t / duration)
                pad += math.sin(TAU * frequency * t + phase) * motion * weight / (voice + 2)
                side_frequency = round((frequency + .22) * duration) / duration
                side += math.sin(TAU * side_frequency * t + phase + .4) * motion * weight / (voice + 2)
        beat = t % .75
        note = base * ratios[notes[int(t / .75) % len(notes)]] * 4
        bell = (math.sin(TAU * note * beat) + .22 * math.sin(TAU * note * 2.01 * beat)) * math.exp(-beat * 7) * math.sin(math.pi * beat / .75) ** 2
        pulse_time = t % 3
        pulse = math.sin(TAU * (base / 2) * pulse_time) * math.exp(-pulse_time * 4) * math.sin(math.pi * pulse_time / 3) ** 2
        left = pad * .33 + bell * .045 + pulse * .075
        right = side * .33 + bell * .04 + pulse * .075
        frames.extend(struct.pack('<hh', int(max(-.95, min(.95, left)) * 32767), int(max(-.95, min(.95, right)) * 32767)))
    write(f'region_{region}', frames)

def opening():
    frames = bytearray()
    for i in range(9 * RATE):
        t = i / RATE
        envelope = min(1.0, t / 2) * min(1.0, (9 - t) / 1.5)
        swell = .12 + .08 * math.sin(math.pi * t / 9)
        left = sum(math.sin(TAU * f * t + j * .4) / (j + 2)
                   for j, f in enumerate([43.654, 65.406, 87.307, 130.813]))
        right = sum(math.sin(TAU * (f + .17) * t + j * .4) / (j + 2)
                    for j, f in enumerate([43.654, 65.406, 87.307, 130.813]))
        frames.extend(struct.pack('<hh', int(left * swell * envelope * 32767),
                                  int(right * swell * envelope * 32767)))
    write('opening', frames)

def cue(name, duration, kind):
    rng = random.Random(41)
    frames = bytearray()
    for i in range(int(RATE * duration)):
        t = i / RATE
        env = math.sin(math.pi * t / duration) ** .7
        if kind == 'play':
            value = .42 * math.sin(TAU * (150 * t + 900 * t * t)) * env + .06 * rng.uniform(-1, 1) * env
        elif kind == 'impact':
            value = (.42 * math.sin(TAU * (90 * t - 45 * t * t)) + .2 * rng.uniform(-1, 1)) * math.exp(-t * 9) * min(1, t * 300)
        elif kind in ('reward', 'transition'):
            chord = [261.63, 329.63, 392, 523.25]
            value = sum(math.sin(TAU * f * max(0, t - j * .08)) * math.exp(-max(0, t - j * .08) * 1.4) for j, f in enumerate(chord) if t >= j * .08) * .13 * env
        else:
            value = .23 * math.sin(TAU * 750 * t) * env
        frames.extend(struct.pack('<hh', int(value * 30000), int(value * 30000)))
    write(name, frames)

if __name__ == '__main__':
    ROOT.mkdir(exist_ok=True)
    for region in range(6): music(region)
    opening()
    for name, length in [('play', .35), ('impact', .4), ('reward', 1.2), ('transition', 2.2), ('click', .06)]: cue(name, length, name)
    print('Rendered six original 48-second soundtracks and five effect cues.')
