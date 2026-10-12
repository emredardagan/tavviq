import AVFoundation
import UIKit

enum Sound: String, CaseIterable {
    case hop0, hop1, hop2, coin, squash, splash, honk, bell, train, eagle, tap, bump, whoosh
    case unlock, record, cluck, pop, crack, gift, gameover
}

/// Low-latency sound effects on a small pool of AVAudioPlayerNodes, plus a looping music track.
final class Audio {
    static let shared = Audio()

    var sfxOn = true
    var musicOn = true { didSet { musicOn ? startMusic() : stopMusic() } }

    private let engine = AVAudioEngine()
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var pool: [AVAudioPlayerNode] = []
    private var next = 0
    private let music = AVAudioPlayerNode()
    private var musicBuffer: AVAudioPCMBuffer?
    private var format: AVAudioFormat?
    private let queue = DispatchQueue(label: "tavviq.audio")
    private var lastPlayed: [Sound: CFTimeInterval] = [:]
    private var musicTarget: Float = 0.55

    private init() {}

    func boot() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)

        for s in Sound.allCases {
            if let b = load(s.rawValue, ext: "caf") { buffers[s] = b }
        }
        format = buffers[.tap]?.format
        guard let format else { return }
        for _ in 0..<10 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            pool.append(p)
        }
        musicBuffer = load("music", ext: "m4a")
        engine.attach(music)
        engine.connect(music, to: engine.mainMixerNode, format: musicBuffer?.format ?? format)
        music.volume = musicTarget
        engine.prepare()
        start()

        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.start()
        }
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw == AVAudioSession.InterruptionType.ended.rawValue { self?.start() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.start()
        }
    }

    private func start() {
        if !engine.isRunning { try? engine.start() }
        if musicOn { startMusic() }
    }

    private func load(_ name: String, ext: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let file = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { return nil }
        try? file.read(into: buf)
        return buf
    }

    func play(_ s: Sound, volume: Float = 1) {
        guard sfxOn, let buf = buffers[s], !pool.isEmpty else { return }
        let now = CACurrentMediaTime()
        queue.async { [self] in
            if let t = lastPlayed[s], now - t < 0.035 { return }
            lastPlayed[s] = now
            guard engine.isRunning else { return }
            let p = pool[next]
            next = (next + 1) % pool.count
            p.stop()
            p.volume = volume
            p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
            p.play()
        }
    }

    func hop() { play([.hop0, .hop1, .hop2].randomElement()!, volume: 0.8) }

    private func startMusic() {
        guard musicOn, let musicBuffer, engine.isRunning, !music.isPlaying else { return }
        music.scheduleBuffer(musicBuffer, at: nil, options: [.loops], completionHandler: nil)
        music.play()
    }

    private func stopMusic() {
        guard music.engine != nil else { return }   // not booted yet
        music.stop()
    }

    /// Silences everything while a full-screen ad is on screen.
    func suspend(_ on: Bool) {
        engine.mainMixerNode.outputVolume = on ? 0 : 1
    }

    /// Quieter music during a run so effects read clearly.
    func duckMusic(_ ducked: Bool) {
        musicTarget = ducked ? 0.32 : 0.55
        music.volume = musicTarget
    }
}

enum Haptics {
    static var on = true
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let note = UINotificationFeedbackGenerator()

    static func hop() { guard on else { return }; DispatchQueue.main.async { light.impactOccurred(intensity: 0.55) } }
    static func coin() { guard on else { return }; DispatchQueue.main.async { soft.impactOccurred(intensity: 0.8) } }
    static func hit() { guard on else { return }; DispatchQueue.main.async { heavy.impactOccurred() } }
    static func success() { guard on else { return }; DispatchQueue.main.async { note.notificationOccurred(.success) } }
    static func tap() { guard on else { return }; DispatchQueue.main.async { light.impactOccurred(intensity: 0.4) } }
}
