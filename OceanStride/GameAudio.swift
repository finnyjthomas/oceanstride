import AVFoundation

/// Original synthesized cues and a quiet pentatonic music loop, generated once in memory.
/// Ambient audio respects the silent switch and mixes with the player's own music.
final class GameAudio {
    enum Cue: CaseIterable { case heal, jump, land, step, dodge, jewel, cannon, laser, hit, death, finish }
    private var clips: [Cue: Data] = [:]
    private var voices: [AVAudioPlayer] = []
    private var music: AVAudioPlayer?
    private var playing = false
    var muted = UserDefaults.standard.bool(forKey: "muted") {
        didSet {
            UserDefaults.standard.set(muted, forKey: "muted")
            if muted { stopVoices(); music?.pause() }
            else if playing { music?.play() }
        }
    }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        for cue in Cue.allCases {
            let notes: [Double]
            let beat: Double
            switch cue {
            case .heal: notes = [523, 659, 784, 1047]; beat = 0.12
            case .jump: notes = [330, 440, 660]; beat = 0.055
            case .land: notes = [100, 70]; beat = 0.045
            case .step: notes = [95]; beat = 0.025
            case .dodge: notes = [240, 300]; beat = 0.035
            case .jewel: notes = [880, 1174, 1568]; beat = 0.08
            case .cannon: notes = [90, 65, 45]; beat = 0.06
            case .laser: notes = [740, 370, 185]; beat = 0.05
            case .hit: notes = [155, 110, 73]; beat = 0.085
            case .death: notes = [392, 330, 262, 196, 98]; beat = 0.16
            case .finish: notes = [392, 494, 587, 784, 988]; beat = 0.14
            }
            clips[cue] = Self.wave(duration: beat * Double(notes.count)) { t in
                let index = min(notes.count - 1, Int(t / beat))
                let local = t - Double(index) * beat
                let envelope = min(1, local / 0.006) * pow(max(0, 1 - local / beat), 1.5)
                let frequency = notes[index]
                return (sin(2 * .pi * frequency * local) + 0.2 * sin(4 * .pi * frequency * local)) * envelope * 0.45
            }
        }
        let melody = [392.0, 0, 494, 587, 0, 494, 440, 0, 330, 392, 0, 494, 440, 0, 330, 0,
                      294, 0, 392, 440, 0, 392, 330, 0, 294, 330, 392, 0, 330, 0, 294, 0]
        let musicData = Self.wave(duration: 16) { t in
            let index = min(31, Int(t / 0.5)), local = t.truncatingRemainder(dividingBy: 0.5)
            let note = melody[index]
            let bell = sin(2 * .pi * note * local) * exp(-local * 6) * min(1, local / 0.015)
            let bass = [98.0, 82.4069, 73.4162, 82.4069][min(3, Int(t / 4))]
            let chordTime = t.truncatingRemainder(dividingBy: 4)
            let padEnvelope = sin(.pi * chordTime / 4) * 0.3
            let pad = (sin(2 * .pi * bass * chordTime) + 0.4 * sin(2 * .pi * bass * 1.5 * chordTime)) * padEnvelope
            return (bell * 0.22 + pad) * min(1, t / 0.05) * min(1, (16 - t) / 0.1)
        }
        music = try? AVAudioPlayer(data: musicData)
        music?.numberOfLoops = -1; music?.volume = 0.14; music?.prepareToPlay()
    }

    func setPlaying(_ value: Bool) {
        playing = value
        if value && !muted { music?.play() }
        else { music?.pause(); stopVoices() }
    }
    func play(_ cue: Cue) {
        guard !muted, let data = clips[cue], let player = try? AVAudioPlayer(data: data) else { return }
        voices.removeAll { !$0.isPlaying }
        if voices.count >= 12 { voices.removeFirst().stop() }
        player.volume = cue == .step ? 0.055 : (cue == .cannon || cue == .laser ? 0.22 : 0.4)
        voices.append(player); player.play()
    }
    func stopVoices() { voices.forEach { $0.stop() }; voices.removeAll() }

    private static func wave(duration: Double, sample: (Double) -> Double) -> Data {
        let rate = 22050, count = Int(duration * Double(rate))
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + count * 2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        text("data"); u32(UInt32(count * 2))
        for frame in 0..<count {
            let value = Int16(max(-1, min(1, sample(Double(frame) / Double(rate)))) * 32760)
            u16(UInt16(bitPattern: value))
        }
        return data
    }
}
