// Independent check of the composer handoff, using Apple's sequencer and sampler.
// swift tools/audition_score.swift path/to/AstralWake.sf2 path/to/region_2.mid take.wav
import AVFoundation
import Foundation

enum AuditionError: Error { case arguments, noParts, silent, renderer }
func audition() throws {
    guard CommandLine.arguments.count == 4 else { throw AuditionError.arguments }
    let urls = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) }
    let engine = AVAudioEngine()
    let sequencer = AVAudioSequencer(audioEngine: engine)
    try sequencer.load(from: urls[1], options: [])
    guard sequencer.tracks.count >= 2 else { throw AuditionError.noParts }
    // Apple's DLS synth is multitimbral: let the file's channel and program
    // events drive the custom SF2 directly rather than substituting GM patches.
    let description = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice,
        componentSubType: kAudioUnitSubType_DLSSynth,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0)
    let synth = AVAudioUnitMIDIInstrument(audioComponentDescription: description)
    var bank = urls[0] as CFURL
    let status = AudioUnitSetProperty(synth.audioUnit, kMusicDeviceProperty_SoundBankURL,
        kAudioUnitScope_Global, 0, &bank, UInt32(MemoryLayout<CFURL>.size))
    guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    engine.attach(synth)
    engine.connect(synth, to: engine.mainMixerNode, format: nil)
    for track in sequencer.tracks { track.destinationAudioUnit = synth }
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 2048)
    let output = try AVAudioFile(forWriting: urls[2], settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2048)!
    try engine.start()
    sequencer.prepareToPlay()
    try sequencer.start()
    let duration = min(120, (sequencer.tracks.map(\.lengthInSeconds).max() ?? 0) + 1)
    var peak: Float = 0
    while Double(engine.manualRenderingSampleTime) < duration * format.sampleRate {
        let status = try engine.renderOffline(2048, to: buffer)
        if status == .cannotDoInCurrentContext { continue }
        guard status == .success else { throw AuditionError.renderer }
        if let channels = buffer.floatChannelData {
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channels[0][i]), abs(channels[1][i])) }
        }
        try output.write(from: buffer)
    }
    sequencer.stop()
    engine.stop()
    guard peak > 0.0001 else { throw AuditionError.silent }
    print("Apple DLS / AVAudioSequencer: \(sequencer.tracks.count) tracks, peak \(peak), \(urls[2].lastPathComponent)")
}
do { try audition() } catch { fputs("Audition failed: \(error)\n", stderr); exit(1) }
