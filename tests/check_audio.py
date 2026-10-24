"""Check the rendered soundtracks at their circular playback boundary."""
import math
import struct
import wave
from pathlib import Path


def rms(samples):
    return math.sqrt(sum(value * value for value in samples) / len(samples))


tracks = sorted((Path(__file__).resolve().parents[1] / 'audio').glob('region_*.wav'))
assert len(tracks) == 6, 'all six regional soundtracks must exist'
for path in tracks:
    with wave.open(str(path)) as track:
        assert (track.getnchannels(), track.getsampwidth(), track.getframerate()) == (2, 2, 22050)
        count = track.getnframes()
        assert count == 48 * 22050, (path.name, 'unexpected loop duration')
        values = struct.unpack(f'<{count * 2}h', track.readframes(count))
    for channel in range(2):
        samples = values[channel::2]
        middle = rms(samples)
        # Both sides must retain the pad, rather than hide a discontinuity with silence.
        edges = [rms(samples[:2205]), rms(samples[-2205:])]
        assert min(edges) > middle * .35, (path.name, channel, 'loop fades to silence', edges, middle)
        seam = abs(samples[0] - samples[-1])
        assert seam < middle * .025, (path.name, channel, 'discontinuous waveform', seam, middle)
        nearby_steps = [abs(samples[i] - samples[i - 1]) for i in range(1, 2205)]
        nearby_steps += [abs(samples[i] - samples[i - 1]) for i in range(count - 2205, count)]
        assert seam < max(nearby_steps) * 1.2 + 2, (path.name, channel, 'boundary click', seam)
        assert max(map(abs, samples)) < 32767, (path.name, channel, 'clipping')
        print(f'{path.name} channel {channel}: RMS {middle:.1f}, seam RMS {edges[0]:.1f}/{edges[1]:.1f}, boundary step {seam}')
