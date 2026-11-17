import Foundation
import AVFoundation
import UIKit

struct TrackGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tracks: [Track]
    var representative: Track? { tracks.first(where: { $0.hasArtwork }) ?? tracks.first }
    var latestAdded: Date { tracks.map(\.addedAt).max() ?? .distantPast }
}

struct TrackMeta: Sendable {
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var artwork: Data?
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published var isImporting = false
    @Published var importStatus: String? = nil
    @Published var showImporter = false

    private struct Snapshot: Codable {
        var tracks: [Track]
        var playlists: [Playlist]
    }

    // MARK: Rutas

    nonisolated static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    /// Visible en la app Archivos: "En mi iPhone > MiPlayer > Music"
    nonisolated static var musicDirectory: URL {
        documents.appendingPathComponent("Music", isDirectory: true)
    }
    nonisolated static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiPlayer", isDirectory: true)
    }
    nonisolated static var artworkDirectory: URL {
        supportDirectory.appendingPathComponent("Artwork", isDirectory: true)
    }
    nonisolated static var libraryFile: URL {
        supportDirectory.appendingPathComponent("library.json")
    }
    nonisolated static func artworkURL(for id: UUID) -> URL {
        artworkDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }
    nonisolated static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [musicDirectory, artworkDirectory] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    nonisolated static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "alac"]
    nonisolated static func isAudio(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }

    func url(for track: Track) -> URL {
        Self.musicDirectory.appendingPathComponent(track.fileName)
    }

    // MARK: Init / persistencia

    init() {
        Self.ensureDirectories()
        if let data = try? Data(contentsOf: Self.libraryFile),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            tracks = snap.tracks
            playlists = snap.playlists
        }
    }

    private func save() {
        let snap = Snapshot(tracks: tracks, playlists: playlists)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: Self.libraryFile, options: .atomic)
        }
    }

    // MARK: Consultas

    func track(id: UUID) -> Track? {
        tracks.first(where: { $0.id == id })
    }

    var favorites: [Track] {
        tracks.filter(\.isFavorite).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var albums: [TrackGroup] {
        Dictionary(grouping: tracks, by: { $0.album }).map { key, value in
            let artists = Set(value.map(\.artist))
            let subtitle = artists.count == 1 ? (artists.first ?? "") : "Varios artistas"
            return TrackGroup(
                id: key, title: key, subtitle: subtitle,
                tracks: value.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var artists: [TrackGroup] {
        Dictionary(grouping: tracks, by: { $0.artist }).map { key, value in
            TrackGroup(
                id: key, title: key, subtitle: "\(value.count) canciones",
                tracks: value.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func tracks(in playlistID: UUID) -> [Track] {
        guard let p = playlists.first(where: { $0.id == playlistID }) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return p.trackIDs.compactMap { byID[$0] }
    }

    func resolve(_ destination: Destination) -> CollectionInfo {
        switch destination {
        case .playlist(let id):
            guard let p = playlists.first(where: { $0.id == id }) else {
                return CollectionInfo(title: "Lista eliminada", subtitle: "", tracks: [])
            }
            let list = tracks(in: id)
            return CollectionInfo(title: p.name, subtitle: "Lista · \(list.count) canciones",
                                  tracks: list, playlistID: id, colorHex: p.colorHex, icon: "music.note.list")
        case .album(let name):
            let list = tracks.filter { $0.album == name }
                .sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
            let artists = Set(list.map(\.artist))
            let who = artists.count == 1 ? (artists.first ?? "") : "Varios artistas"
            return CollectionInfo(title: name, subtitle: "Álbum · \(who) · \(list.count) canciones", tracks: list)
        case .artist(let name):
            let list = tracks.filter { $0.artist == name }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return CollectionInfo(title: name, subtitle: "Artista · \(list.count) canciones", tracks: list, circle: true)
        case .favorites:
            let list = favorites
            return CollectionInfo(title: "Canciones favoritas", subtitle: "\(list.count) canciones",
                                  tracks: list, colorHex: "5038A0", icon: "heart.fill")
        case .allSongs:
            let list = tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return CollectionInfo(title: "Todas las canciones", subtitle: "\(list.count) canciones",
                                  tracks: list, colorHex: "2E5E8C", icon: "music.note")
        }
    }

    // MARK: Importación

    func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        importStatus = "Copiando archivos…"
        Task {
            let names = await Task.detached { Self.copyIntoLibrary(urls) }.value
            if names.isEmpty {
                importStatus = "No se encontraron archivos de audio nuevos o compatibles"
            } else {
                importStatus = "Leyendo etiquetas y portadas…"
                let n = await ingest(fileNames: names)
                importStatus = n > 0 ? "Se agregaron \(n) canciones" : "Esas canciones ya estaban en tu biblioteca"
            }
            isImporting = false
            try? await Task.sleep(for: .seconds(3))
            importStatus = nil
        }
    }

    /// Busca archivos nuevos en Documents/Music (por ejemplo, los que pegaste desde la app Archivos)
    /// y quita de la biblioteca los que ya no existen.
    func scanMusicFolder() {
        Task {
            let found = await Task.detached { Self.listMusicFiles() }.value
            let foundSet = Set(found)

            let missing = tracks.filter { !foundSet.contains($0.fileName) }
            if !missing.isEmpty {
                for t in missing {
                    try? FileManager.default.removeItem(at: Self.artworkURL(for: t.id))
                    ArtworkCache.remove(t.id)
                }
                let ids = Set(missing.map(\.id))
                tracks.removeAll { ids.contains($0.id) }
                for i in playlists.indices { playlists[i].trackIDs.removeAll { ids.contains($0) } }
                save()
            }

            let known = Set(tracks.map(\.fileName))
            let new = found.filter { !known.contains($0) }
            guard !new.isEmpty else { return }
            isImporting = true
            importStatus = "Encontré \(new.count) archivos nuevos…"
            let n = await ingest(fileNames: new)
            isImporting = false
            importStatus = n > 0 ? "Se agregaron \(n) canciones" : nil
            try? await Task.sleep(for: .seconds(3))
            importStatus = nil
        }
    }

    private func ingest(fileNames: [String]) async -> Int {
        var added = 0
        for name in fileNames {
            if tracks.contains(where: { $0.fileName == name }) { continue }
            let url = Self.musicDirectory.appendingPathComponent(name)
            let meta = await Self.readMetadata(url: url)
            var track = Track(fileName: name, title: meta.title, artist: meta.artist,
                              album: meta.album, duration: meta.duration)
            if let data = meta.artwork, Self.saveArtwork(data, id: track.id) {
                track.hasArtwork = true
            }
            tracks.append(track)
            added += 1
            if added % 20 == 0 {
                save()
                importStatus = "Importadas \(added) de \(fileNames.count)…"
            }
        }
        save()
        return added
    }

    // MARK: Trabajo de archivos (fuera del hilo principal)

    nonisolated static func listMusicFiles() -> [String] {
        let fm = FileManager.default
        let base = musicDirectory.standardizedFileURL.path + "/"
        guard let en = fm.enumerator(at: musicDirectory, includingPropertiesForKeys: nil,
                                     options: [.skipsHiddenFiles]) else { return [] }
        var result: [String] = []
        for case let url as URL in en where isAudio(url) {
            let p = url.standardizedFileURL.path
            if p.hasPrefix(base) { result.append(String(p.dropFirst(base.count))) }
        }
        return result
    }

    nonisolated static func copyIntoLibrary(_ urls: [URL]) -> [String] {
        let fm = FileManager.default
        var result: [String] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            var files: [URL] = []
            if isDir {
                if let en = fm.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for case let f as URL in en where isAudio(f) { files.append(f) }
                }
            } else if isAudio(url) {
                files.append(url)
            }
            for f in files {
                if let name = copyOne(f) { result.append(name) }
            }
        }
        return result
    }

    /// Copia un archivo a Documents/Music. Devuelve el nombre final, o nil si ya existía igual o falló.
    nonisolated private static func copyOne(_ src: URL) -> String? {
        let fm = FileManager.default
        let ext = src.pathExtension
        let base = src.deletingPathExtension().lastPathComponent
        var name = src.lastPathComponent
        var dst = musicDirectory.appendingPathComponent(name)
        var n = 1
        let srcSize = (try? src.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1

        while fm.fileExists(atPath: dst.path) {
            let dstSize = (try? dst.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -2
            if srcSize == dstSize { return nil }   // mismo nombre y tamaño: duplicado
            n += 1
            name = "\(base) (\(n)).\(ext)"
            dst = musicDirectory.appendingPathComponent(name)
        }

        // El coordinador fuerza la descarga si el archivo está en iCloud y aún no está en el teléfono.
        var coordError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: src, options: [], error: &coordError) { readURL in
            do { try fm.copyItem(at: readURL, to: dst) } catch { copyError = error }
        }
        if coordError != nil || copyError != nil { return nil }
        return name
    }

    nonisolated static func readMetadata(url: URL) async -> TrackMeta {
        var meta = TrackMeta(
            title: url.deletingPathExtension().lastPathComponent,
            artist: "Artista desconocido",
            album: "Álbum desconocido",
            duration: 0,
            artwork: nil
        )
        let asset = AVURLAsset(url: url)
        if let d = try? await asset.load(.duration) {
            let s = CMTimeGetSeconds(d)
            if s.isFinite { meta.duration = s }
        }
        guard let items = try? await asset.load(.commonMetadata) else { return meta }
        for item in items {
            guard let key = item.commonKey else { continue }
            if key == .commonKeyTitle {
                if let s = try? await item.load(.stringValue), !s.isEmpty { meta.title = s }
            } else if key == .commonKeyArtist {
                if let s = try? await item.load(.stringValue), !s.isEmpty { meta.artist = s }
            } else if key == .commonKeyAlbumName {
                if let s = try? await item.load(.stringValue), !s.isEmpty { meta.album = s }
            } else if key == .commonKeyArtwork {
                if let d = try? await item.load(.dataValue) {
                    meta.artwork = d
                } else if let v = try? await item.load(.value), let d = v as? Data {
                    meta.artwork = d
                }
            }
        }
        return meta
    }

    nonisolated static func saveArtwork(_ data: Data, id: UUID) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        let maxSide: CGFloat = 600
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return false }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return false }
        do {
            try jpeg.write(to: artworkURL(for: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    nonisolated static func musicFolderSize() -> Int64 {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: musicDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in en {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // MARK: Edición de canciones

    func registerPlay(_ id: UUID) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[i].playCount += 1
        tracks[i].lastPlayed = Date()
        save()
    }

    func toggleFavorite(_ id: UUID) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[i].isFavorite.toggle()
        save()
    }

    func update(_ track: Track) {
        guard let i = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[i] = track
        save()
    }

    func delete(_ track: Track) {
        try? FileManager.default.removeItem(at: url(for: track))
        try? FileManager.default.removeItem(at: Self.artworkURL(for: track.id))
        ArtworkCache.remove(track.id)
        tracks.removeAll { $0.id == track.id }
        for i in playlists.indices { playlists[i].trackIDs.removeAll { $0 == track.id } }
        save()
    }

    func deleteEverything() {
        for t in tracks {
            try? FileManager.default.removeItem(at: url(for: t))
            try? FileManager.default.removeItem(at: Self.artworkURL(for: t.id))
            ArtworkCache.remove(t.id)
        }
        tracks = []
        for i in playlists.indices { playlists[i].trackIDs = [] }
        save()
    }

    // MARK: Listas

    private static let playlistColors = ["1E7A4F", "8C3B5E", "2E5E8C", "8C6A1E", "5B3F9E", "9E3F3F", "2F7F86", "6B7F2E"]

    @discardableResult
    func createPlaylist(name: String, trackIDs: [UUID] = []) -> Playlist {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = Playlist(
            name: clean.isEmpty ? "Mi lista n.º \(playlists.count + 1)" : clean,
            trackIDs: trackIDs,
            colorHex: Self.playlistColors[playlists.count % Self.playlistColors.count]
        )
        playlists.append(p)
        save()
        return p
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { playlists[i].name = clean; save() }
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
        save()
    }

    func add(_ trackID: UUID, to playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[i].trackIDs.contains(trackID) {
            playlists[i].trackIDs.append(trackID)
            save()
        }
    }

    func removeTrack(_ trackID: UUID, from playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[i].trackIDs.removeAll { $0 == trackID }
        save()
    }

    func moveTracks(from offsets: IndexSet, to destination: Int, in playlistID: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[i].trackIDs.move(fromOffsets: offsets, toOffset: destination)
        save()
    }
}
