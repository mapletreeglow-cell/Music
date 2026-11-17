import Foundation

// MARK: - Canción y lista

struct Track: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Ruta relativa dentro de Documents/Music (así sobrevive a reinstalaciones y cambios de contenedor).
    var fileName: String
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var addedAt = Date()
    var playCount = 0
    var lastPlayed: Date? = nil
    var isFavorite = false
    var hasArtwork = false
}

struct Playlist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var trackIDs: [UUID] = []
    var createdAt = Date()
    var colorHex: String
}

// MARK: - Navegación

enum Destination: Hashable {
    case playlist(UUID)
    case album(String)
    case artist(String)
    case favorites
    case allSongs
}

struct CollectionInfo {
    var title: String
    var subtitle: String
    var tracks: [Track]
    var playlistID: UUID? = nil
    var colorHex: String? = nil
    var icon: String? = nil
    var circle = false
}

// MARK: - Audio

enum RepeatMode: Int {
    case off, all, one
}

enum EQ {
    static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    static let labels = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
}

struct EQPreset: Identifiable {
    var id: String { name }
    let name: String
    let bands: [Float]

    static let all: [EQPreset] = [
        EQPreset(name: "Plano", bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EQPreset(name: "Más graves", bands: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        EQPreset(name: "Menos graves", bands: [-6, -5, -4, -2, 0, 0, 0, 0, 0, 0]),
        EQPreset(name: "Más agudos", bands: [0, 0, 0, 0, 0, 1, 3, 4, 5, 6]),
        EQPreset(name: "Voces", bands: [-2, -3, -3, 1, 3, 3, 3, 1, 0, -1]),
        EQPreset(name: "Rock", bands: [5, 4, 2, -1, -2, -1, 2, 4, 5, 6]),
        EQPreset(name: "Pop", bands: [-1, 2, 4, 5, 3, 0, -1, -1, -2, -2]),
        EQPreset(name: "Electrónica", bands: [5, 4, 1, 0, -2, 2, 1, 2, 5, 5]),
        EQPreset(name: "Hip-hop", bands: [5, 4, 1, 3, -1, -1, 2, -1, 2, 3]),
        EQPreset(name: "Jazz", bands: [4, 3, 1, 2, -2, -2, 0, 1, 3, 4]),
        EQPreset(name: "Clásica", bands: [4, 3, 3, 2, -1, -1, 0, 2, 3, 3]),
        EQPreset(name: "Acústica", bands: [4, 4, 3, 1, 2, 2, 3, 3, 2, 1]),
        EQPreset(name: "Loudness", bands: [6, 4, 0, 0, -2, 0, -1, -5, 5, 1])
    ]
}

struct ReverbOption: Identifiable {
    var id: Int { raw }
    let name: String
    /// Valor crudo de AVAudioUnitReverbPreset
    let raw: Int

    static let all: [ReverbOption] = [
        ReverbOption(name: "Habitación pequeña", raw: 0),
        ReverbOption(name: "Habitación mediana", raw: 1),
        ReverbOption(name: "Habitación grande", raw: 2),
        ReverbOption(name: "Sala mediana", raw: 3),
        ReverbOption(name: "Sala grande", raw: 4),
        ReverbOption(name: "Plate", raw: 5),
        ReverbOption(name: "Catedral", raw: 8)
    ]
}

struct AudioSettings: Codable, Equatable {
    var eqEnabled = true
    var bands: [Float] = Array(repeating: 0, count: 10)   // dB, -12...12
    var presetName = "Plano"
    var preamp: Float = 0                                   // dB, -12...12
    var autoHeadroom = true                                 // baja el volumen si el EQ sube mucho (evita distorsión)
    var reverbMix: Float = 0                                // 0...100
    var reverbPreset = 4
    var rate: Float = 1                                     // 0.5...2
    var pitchSemitones: Float = 0                           // -12...12
    var balance: Float = 0                                  // -1...1
}

struct AudioProfile: Identifiable, Codable {
    var id = UUID()
    var name: String
    var settings: AudioSettings
}
