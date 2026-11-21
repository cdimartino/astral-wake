"""Explicit subset of SMF for the game. Pure Python; fail on uncompiled events."""
from bisect import bisect_right
from io import BytesIO
import struct

PPQ = 480


def vlq(n):
    if not 0 <= n <= 0x0fffffff:
        raise ValueError(f"invalid delta {n}")
    b = [n & 127]
    while (n := n >> 7):
        b.append(128 | n & 127)
    return bytes(reversed(b))


def meta(kind, payload):
    return bytes([255, kind]) + vlq(len(payload)) + payload


def midi_track(events, length):
    events.append((length, meta(47, b"")))
    pos, body = 0, bytearray()
    for tick, payload in sorted(events, key=lambda e: e[0]):
        body.extend(vlq(tick-pos) + payload)
        pos = tick
    return b"MTrk" + struct.pack(">I", len(body)) + body


def write(path, bpm, beats, markers, parts, book):
    end = round(PPQ*beats)
    conductor = [
        (0, meta(3, b"conductor")), (0, meta(81, round(60_000_000/bpm).to_bytes(3, "big"))),
        (0, meta(88, bytes([4, 2, 24, 8]))),
    ]
    conductor.extend((round(t*PPQ), meta(6, name.encode())) for t, name in markers)
    chunks = [midi_track(conductor, end)]
    for channel, (name, patch, notes) in enumerate(parts):
        bank, pgm, _, _ = book[patch]
        events = [(0, meta(3, name.encode())), (0, bytes([176+channel, 0, bank])),
                  (0, bytes([176+channel, 32, 0])), (0, bytes([192+channel, pgm]))]
        for beat, duration, key, velocity in notes:
            events.extend([(round(beat*PPQ), bytes([144+channel, key, velocity])),
                           (round((beat+duration)*PPQ), bytes([128+channel, key, 0]))])
        chunks.append(midi_track(events, end))
    path.write_bytes(b"MThd"+struct.pack(">IHHH", 6, 1, len(chunks), PPQ)+b"".join(chunks))


def exact(stream, n):
    data = stream.read(n)
    if len(data) != n:
        raise ValueError("truncated MIDI chunk")
    return data


def uint(stream):
    n = 0
    for _ in range(4):
        b = exact(stream, 1)[0]
        n = (n << 7) | (b & 127)
        if b < 128:
            return n
    raise ValueError("bad MIDI variable length")


def chunk(stream, tag):
    if exact(stream, 4) != tag:
        raise ValueError(f"expected {tag}")
    return BytesIO(exact(stream, int.from_bytes(exact(stream, 4), "big")))


def compile_score(path, book):
    """Decode DAW edits including running status and global tempo changes.

    Refuse silent mistranslations (pedal, bends, sysex, percussion, unsupported
    CC etc). Note-on captures current patch. DAW text/copyright are metadata.
    """
    def fail(message):
        raise ValueError(f"{path.name}: {message}")

    patches = {(b, pgm): name for name, (b, pgm, _, _) in book.items()}
    file = BytesIO(path.read_bytes())
    fmt, count, ppq = struct.unpack(">HHH", chunk(file, b"MThd").read())
    if fmt != 1 or count < 3 or not 0 < ppq < 32768:
        fail("requires a conductor and ≥2 musical tracks in PPQ Type 1 MIDI")
    tempo, marks, meter, notes, tracks = [], [], [], [], {}
    names, channels = set(), set()
    end_tick = 0
    for idx in range(count):
        body = chunk(file, b"MTrk")
        t, name, running, channel = 0, None, None, None
        bank_msb = bank_lsb = patch = None
        pending = {}
        has_note = ended = False
        while body.tell() < len(body.getbuffer()):
            t += uint(body)
            op = exact(body, 1)[0]
            if op < 128:
                if running is None:
                    fail(f"invalid running status at tick {t}")
                body.seek(-1, 1)
                op = running
            running = op if op < 240 else None
            if op == 255:
                kind = exact(body, 1)[0]
                data = exact(body, uint(body))
                if kind == 3:
                    if name is not None: fail("repeated track name")
                    name = data.decode()
                elif kind == 47:
                    if data or body.read(1): fail("bad end-of-track")
                    ended = True
                elif kind in (81, 88, 6):
                    if idx: fail("global metadata must live on conductor")
                    if kind == 81:
                        if len(data) != 3 or not any(data): fail("bad tempo")
                        tempo.append((t, int.from_bytes(data, "big")))
                    if kind == 88:
                        if len(data) != 4: fail("bad time signature")
                        meter.append((t, data[0], 2**data[1]))
                    if kind == 6: marks.append((t, data.decode()))
                elif kind not in (1, 2, 4):
                    fail(f"unsupported meta event {kind:#x} at tick {t}")
                continue
            if op >= 240: fail(f"unsupported system event {op:#x}")
            chan = op % 16
            if not idx or chan == 9 or channel not in (None, chan):
                fail("parts must use one independent melodic channel per track")
            channel = chan
            code = op >> 4
            a = exact(body, 1)[0]
            b = None if code in (12, 13) else exact(body, 1)[0]
            if a > 127 or (b is not None and b > 127): fail("invalid MIDI data byte")
            if code == 11 and a in (0, 32):
                if a == 0: bank_msb = b
                else: bank_lsb = b
            elif code == 12:
                if bank_lsb != 0 or (bank_msb, a) not in patches:
                    fail(f"unmapped bank/program {bank_msb}:{bank_lsb}/{a}")
                patch = patches[bank_msb, a]
                if book[patch][0] != 0:
                    fail(f"{patch} is not mapped to a score cue")
            elif code == 9 and b:
                if not name or not patch or a in pending: fail("unnamed/unmapped/overlapping note")
                pending[a] = (t, b, patch)
                has_note = True
            elif code in (8, 9):
                if a not in pending: fail(f"orphan note-off {a}")
                start, vel, selected = pending.pop(a)
                if start == t: fail("zero length note")
                notes.append((start, t, a, vel, name, selected))
            else:
                fail(f"unsupported status {op:#x}, data {a} at tick {t}")
        if not ended or not name or name in names or pending: fail("unfinished/duplicate track")
        names.add(name)
        if idx:
            if not has_note or channel in channels: fail("empty part or shared channel")
            channels.add(channel)
            tracks[name] = {"channel":channel+1}
        end_tick = max(end_tick, t)
    if file.read(1) or not tempo or tempo[0][0] or not meter or meter[0][0] or not marks:
        fail("missing initial conductor tempo/meter/markers or trailing bytes")
    tempo_ticks = [t for t, _ in tempo]
    offset = [0.]
    for (a, us), (b, _) in zip(tempo, tempo[1:]):
        offset.append(offset[-1]+(b-a)*us/(ppq*1e6))
    def seconds(t):
        i = bisect_right(tempo_ticks, t)-1
        return round(offset[i]+(t-tempo[i][0])*tempo[i][1]/(ppq*1e6), 6)
    return dict(length=seconds(end_tick), tracks=tracks,
                markers=[dict(time=seconds(t), name=n) for t,n in marks],
                meter=[dict(time=seconds(t), numerator=n, denominator=d) for t,n,d in meter],
                tempo=[dict(time=seconds(t), us_per_quarter=u) for t,u in tempo],
                events=[dict(time=seconds(start), duration=round(seconds(end)-seconds(start), 6),
                             cue="score_"+patch, note=k, velocity=v, track=part)
                        for start, end, k, v, part, patch in sorted(notes)])
