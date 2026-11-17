import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

/// Reloj aparte para que los 4 refrescos por segundo no redibujen toda la app.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published var time: Double = 0
}

@MainActor
final class PlayerModel: ObservableObject {
    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published var shuffle = false
    @Published var repeatMode: RepeatMode = .off
    @Published var showFullPlayer = false
    @Published private(set) var contextTitle = ""
    @Published var errorMessage: String? = nil

    @Published var audio = AudioSettings() {
        didSet {
            engine.apply(audio)
            persistAudio()
        }
    }
    @Published var profiles: [AudioProfile] = [] {
        didSet { persistProfiles() }
    }

    let clock = PlaybackClock()
    weak var library: LibraryStore?

    private let engine = AudioEngineService()
    private var originalQueue: [Track] = []
    private var skipFailures = 0
    private var wasInterrupted = false
    private var cancellables = Set<AnyCancellable>()

    var current: Track? {
        guard queue.indices.contains(currentIndex) else { return nil }
        let t = queue[currentIndex]
        return library?.track(id: t.id) ?? t
    }

    // MARK: Init

    init() {
        let defaults = UserDefaults.standard
        if let d = defaults.data(forKey: "audioSettings"),
           let s = try? JSONDecoder().decode(AudioSettings.self, from: d) {
            audio = s
        }
        if let d = defaults.data(forKey: "audioProfiles"),
           let p = try? JSONDecoder().decode([AudioProfile].self, from: d) {
            profiles = p
        }
        engine.apply(audio)
        engine.onFinished = { [weak self] in self?.trackFinished() }

        setupRemoteCommands()
        observeSession()

        Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            .store(in: &cancellables)
    }

    private func persistAudio() {
        if let d = try? JSONEncoder().encode(audio) {
            UserDefaults.standard.set(d, forKey: "audioSettings")
        }
    }

    private func persistProfiles() {
        if let d = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(d, forKey: "audioProfiles")
        }
    }

    private func tick() {
        guard isPlaying else { return }
        clock.time = engine.time()
    }

    // MARK: Reproducción

    func play(_ tracks: [Track], startAt index: Int = 0, shuffled: Bool = false, context: String = "") {
        guard !tracks.isEmpty, tracks.indices.contains(index) else { return }
        originalQueue = tracks
        contextTitle = context
        shuffle = shuffled
        if shuffled {
            var rest = tracks
            let first = rest.remove(at: index)
            rest.shuffle()
            queue = [first] + rest
            currentIndex = 0
        } else {
            queue = tracks
            currentIndex = index
        }
        skipFailures = 0
        loadCurrent(autoplay: true)
    }

    func playShuffled(_ tracks: [Track], context: String = "") {
        guard !tracks.isEmpty else { return }
        play(tracks, startAt: Int.random(in: 0..<tracks.count), shuffled: true, context: context)
    }

    private func loadCurrent(autoplay: Bool) {
        guard let track = current, let library else { return }
        do {
            try engine.load(url: library.url(for: track))
            duration = engine.duration > 0 ? engine.duration : track.duration
            clock.time = 0
            skipFailures = 0
            library.registerPlay(track.id)
            if autoplay {
                engine.play()
                isPlaying = true
            } else {
                isPlaying = false
            }
            updateNowPlaying()
        } catch {
            isPlaying = false
            errorMessage = "No se pudo abrir “\(track.title)”"
            skipFailures += 1
            if autoplay, skipFailures < queue.count, currentIndex + 1 < queue.count {
                currentIndex += 1
                loadCurrent(autoplay: true)
            }
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard current != nil else { return }
        engine.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        engine.pause()
        isPlaying = false
        clock.time = engine.time()
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadCurrent(autoplay: true)
        } else if repeatMode == .all {
            currentIndex = 0
            loadCurrent(autoplay: true)
        } else {
            engine.seek(to: 0)
            engine.pause()
            isPlaying = false
            clock.time = 0
            updateNowPlaying()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if engine.time() > 3 || currentIndex == 0 {
            seek(to: 0)
        } else {
            currentIndex -= 1
            loadCurrent(autoplay: true)
        }
    }

    func seek(to t: Double) {
        engine.seek(to: t)
        clock.time = t
        updateNowPlaying()
    }

    func jump(to index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        loadCurrent(autoplay: true)
    }

    private func trackFinished() {
        if repeatMode == .one {
            engine.seek(to: 0)
            engine.play()
            isPlaying = true
            clock.time = 0
            updateNowPlaying()
        } else {
            next()
        }
    }

    // MARK: Cola

    func toggleShuffle() {
        guard let cur = current else { shuffle.toggle(); return }
        if shuffle {
            shuffle = false
            queue = originalQueue
            currentIndex = queue.firstIndex(where: { $0.id == cur.id }) ?? 0
        } else {
            shuffle = true
            var rest = queue
            rest.remove(at: currentIndex)
            rest.shuffle()
            queue = [cur] + rest
            currentIndex = 0
        }
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func playNext(_ track: Track) {
        if queue.isEmpty { play([track]); return }
        queue.insert(track, at: min(currentIndex + 1, queue.count))
        originalQueue.append(track)
    }

    func addToQueue(_ track: Track) {
        if queue.isEmpty { play([track]); return }
        queue.append(track)
        originalQueue.append(track)
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), index != currentIndex else { return }
        let removed = queue.remove(at: index)
        if index < currentIndex { currentIndex -= 1 }
        if let i = originalQueue.firstIndex(where: { $0.id == removed.id }) {
            originalQueue.remove(at: i)
        }
    }

    // MARK: Audio: perfiles y ajustes

    func applyPreset(_ preset: EQPreset) {
        var s = audio
        s.bands = preset.bands
        s.presetName = preset.name
        s.eqEnabled = true
        audio = s
    }

    func setBand(_ index: Int, to value: Float) {
        guard audio.bands.indices.contains(index) else { return }
        var s = audio
        s.bands[index] = value
        s.presetName = "Personalizado"
        audio = s
    }

    func resetAudio() {
        audio = AudioSettings()
    }

    func saveProfile(named name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        profiles.append(AudioProfile(name: clean, settings: audio))
    }

    func apply(_ profile: AudioProfile) {
        audio = profile.settings
    }

    func deleteProfile(_ profile: AudioProfile) {
        profiles.removeAll { $0.id == profile.id }
    }

    // MARK: Pantalla de bloqueo / Centro de control

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                let t = e.positionTime
                Task { @MainActor in self?.seek(to: t) }
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlaying() {
        guard let t = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: t.artist,
            MPMediaItemPropertyAlbumTitle: t.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: engine.time(),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(audio.rate) : 0.0
        ]
        if let img = ArtworkCache.image(for: t) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: Interrupciones

    private func observeSession() {
        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in
                guard let info = note.userInfo,
                      let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                var shouldResume = false
                if let optRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                    shouldResume = AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume)
                }
                Task { @MainActor in self?.handleInterruption(type, shouldResume: shouldResume) }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                      reason == .oldDeviceUnavailable else { return }
                Task { @MainActor in
                    guard let self, self.isPlaying else { return }
                    self.pause()
                }
            }
            .store(in: &cancellables)
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType, shouldResume: Bool) {
        switch type {
        case .began:
            if isPlaying {
                wasInterrupted = true
                engine.pause()
                isPlaying = false
                updateNowPlaying()
            }
        case .ended:
            if wasInterrupted && shouldResume {
                engine.recover(resume: true)
                isPlaying = engine.isPlaying
                updateNowPlaying()
            }
            wasInterrupted = false
        @unknown default:
            break
        }
    }
}
