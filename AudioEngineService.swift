import AVFoundation
import Combine

/// Motor de audio: AVAudioPlayerNode → EQ de 10 bandas → Time/Pitch → Reverb → mezclador.
@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    private let timePitch = AVAudioUnitTimePitch()
    private let reverb = AVAudioUnitReverb()

    private var file: AVAudioFile?
    private var format: AVAudioFormat?
    private var generation = 0
    private var startOffset: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var lastTime: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    var onFinished: (() -> Void)?

    init() {
        engine.attach(player)
        engine.attach(eq)
        engine.attach(timePitch)
        engine.attach(reverb)

        NotificationCenter.default
            .publisher(for: .AVAudioEngineConfigurationChange, object: engine)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.rebuild(resume: self.isPlaying)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Sesión

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    // MARK: Grafo

    private func connect(format newFormat: AVAudioFormat) throws {
        if let f = format, f.sampleRate == newFormat.sampleRate,
           f.channelCount == newFormat.channelCount, engine.isRunning {
            return
        }
        stopPlayer()
        engine.stop()
        engine.connect(player, to: eq, format: newFormat)
        engine.connect(eq, to: timePitch, format: newFormat)
        engine.connect(timePitch, to: reverb, format: newFormat)
        engine.connect(reverb, to: engine.mainMixerNode, format: newFormat)
        format = newFormat
        engine.prepare()
        try engine.start()
    }

    private func stopPlayer() {
        generation += 1          // invalida los callbacks pendientes
        player.stop()
    }

    // MARK: Carga y control

    func load(url: URL) throws {
        activateSession()
        let f = try AVAudioFile(forReading: url)
        file = f
        duration = Double(f.length) / f.processingFormat.sampleRate
        try connect(format: f.processingFormat)
        if !engine.isRunning { try engine.start() }
        pausedTime = 0
        lastTime = 0
        isPlaying = false
        schedule(from: 0)
    }

    private nonisolated func makeCompletion(_ gen: Int) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        return { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == gen else { return }
                self.onFinished?()
            }
        }
    }

    private func schedule(from time: TimeInterval) {
        guard let file else { return }
        stopPlayer()
        let gen = generation
        let sr = file.processingFormat.sampleRate
        let clamped = max(0, min(time, max(duration - 0.05, 0)))
        let startFrame = AVAudioFramePosition(clamped * sr)
        let remaining = AVAudioFrameCount(max(0, file.length - startFrame))
        guard remaining > 0 else { return }
        startOffset = Double(startFrame) / sr
        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: remaining,
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: makeCompletion(gen)
        )
    }

    func play() {
        activateSession()
        if !engine.isRunning { try? engine.start() }
        player.play()
        isPlaying = true
    }

    func pause() {
        pausedTime = time()
        player.pause()
        isPlaying = false
    }

    func seek(to t: TimeInterval) {
        let wasPlaying = isPlaying
        let target = max(0, min(t, duration))
        schedule(from: target)
        pausedTime = target
        lastTime = target
        if wasPlaying { player.play() }
    }

    /// Posición actual en segundos.
    func time() -> TimeInterval {
        if isPlaying,
           let nodeTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            let t = startOffset + Double(playerTime.sampleTime) / playerTime.sampleRate
            lastTime = max(0, min(t, duration))
            return lastTime
        }
        return isPlaying ? lastTime : pausedTime
    }

    private func rebuild(resume: Bool) {
        guard let f = file else { return }
        let t = lastTime
        format = nil
        do { try connect(format: f.processingFormat) } catch { isPlaying = false; return }
        schedule(from: t)
        pausedTime = t
        if resume {
            activateSession()
            player.play()
            isPlaying = true
        } else {
            isPlaying = false
        }
    }

    /// Se usa al terminar una interrupción (llamada, alarma…).
    func recover(resume: Bool) {
        rebuild(resume: resume)
    }

    // MARK: Ajustes de audio

    func apply(_ s: AudioSettings) {
        let maxBoost = max(0, s.bands.max() ?? 0)
        for i in 0..<eq.bands.count {
            let band = eq.bands[i]
            if i == 0 {
                band.filterType = .lowShelf
            } else if i == eq.bands.count - 1 {
                band.filterType = .highShelf
            } else {
                band.filterType = .parametric
            }
            band.frequency = EQ.frequencies[i]
            band.bandwidth = 1.0
            band.gain = s.eqEnabled ? s.bands[i] : 0
            band.bypass = false
        }
        var global = s.preamp
        if s.eqEnabled && s.autoHeadroom { global -= maxBoost }
        eq.globalGain = max(-96, min(24, global))

        timePitch.rate = max(0.5, min(2, s.rate))
        timePitch.pitch = s.pitchSemitones * 100
        timePitch.bypass = (s.rate == 1 && s.pitchSemitones == 0)

        reverb.loadFactoryPreset(AVAudioUnitReverbPreset(rawValue: s.reverbPreset) ?? .largeHall)
        reverb.wetDryMix = max(0, min(100, s.reverbMix))
        reverb.bypass = s.reverbMix <= 0

        player.pan = max(-1, min(1, s.balance))
    }
}
