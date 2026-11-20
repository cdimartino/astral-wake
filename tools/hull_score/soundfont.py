"""One unlooped mono zone per instrument; losslessly reuse the game PCM."""
from struct import pack
import wave


def chunk(tag, data):
    return tag + pack("<I", len(data)) + data + b"\0"*(len(data)%2)


def name20(s):
    return s.encode("ascii")[:19].ljust(20, b"\0")


def display_name(ident):
    return ident.removeprefix("combat_").replace("cartographer","carto").replace("palimpsest","palim").replace("_hollow","_alt").replace("_launch","_send").replace("_take2","_rr2")


def soundfont(book, samples):
    info = chunk(b"LIST", b"INFO" + chunk(b"ifil", pack("<HH",2,1)) +
                 chunk(b"isng", b"EMU8000\0") + chunk(b"INAM", b"Astral Wake - Living Hull\0") +
                 chunk(b"IENG", b"Astral Wake / VCSL\0"))
    # Tables terminate with a sentinel; each zone's range ends at the next
    # one's index. Keep sample guards out of shdr.end per the SF2 spec.
    pd = {tag: bytearray() for tag in
          (b"phdr",b"pbag",b"pmod",b"pgen",b"inst",b"ibag",b"imod",b"igen",b"shdr")}
    pcm = bytearray()
    for i,(ident,(bank,pgm,root,_)) in enumerate(book.items()):
        label = name20(display_name(ident))
        with wave.open(str(samples/f"{ident}.wav")) as w:
            n, rate = w.getnframes(), w.getframerate()
            start = len(pcm)//2
            pcm.extend(w.readframes(n))
        pcm.extend(bytes(46*2))
        pd[b"phdr"] += pack("<20sHHHIII",label,pgm,bank,i,0,0,0)
        pd[b"pbag"] += pack("<HH",i,0)
        pd[b"pgen"] += pack("<HH",41,i)  # instrument
        pd[b"inst"] += pack("<20sH",label,i)
        pd[b"ibag"] += pack("<HH",i*2,0)
        pd[b"igen"] += pack("<HhHH",38,-4400,53,i)  # release (timecents); sampleID last
        pd[b"shdr"] += pack("<20sIIIIIBbHH",label,start,start+n,
            start+8,start+n-8,rate,root,0,0,1)
    count = len(book)
    pd[b"phdr"] += pack("<20sHHHIII",name20("EOP"),0,0,count,0,0,0)
    pd[b"inst"] += pack("<20sH",name20("EOI"),count)
    pd[b"shdr"] += pack("<20sIIIIIBbHH",name20("EOS"),0,0,0,0,0,0,0,0,0)
    for tag, n in ((b"pbag",count),(b"ibag",count*2)):
        pd[tag] += pack("<HH",n,0)
    for tag in (b"imod",b"pmod"): pd[tag] += bytes(10)
    for tag in (b"pgen",b"igen"): pd[tag] += bytes(4)
    return chunk(b"RIFF", b"sfbk"+info+chunk(b"LIST",b"sdta"+chunk(b"smpl",pcm)) +
                 chunk(b"LIST",b"pdta"+b"".join(chunk(tag,table) for tag,table in pd.items())))
