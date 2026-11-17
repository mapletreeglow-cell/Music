import SwiftUI
import UIKit

// MARK: - Utilidades

func formatTime(_ t: Double) -> String {
    guard t.isFinite, t >= 0 else { return "0:00" }
    let s = Int(t)
    return String(format: "%d:%02d", s / 60, s % 60)
}

/// Hash estable (hashValue cambia en cada arranque, esto no).
func stableHue(_ s: String) -> Double {
    var h: UInt64 = 5381
    for u in s.unicodeScalars { h = (h &* 33) &+ UInt64(u.value) }
    return Double(h % 360) / 360.0
}

enum ArtworkCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for track: Track?) -> UIImage? {
        guard let track, track.hasArtwork else { return nil }
        let key = track.id.uuidString as NSString
        if let img = cache.object(forKey: key) { return img }
        guard let img = UIImage(contentsOfFile: LibraryStore.artworkURL(for: track.id).path) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }

    static func remove(_ id: UUID) {
        cache.removeObject(forKey: id.uuidString as NSString)
    }
}

// MARK: - Portada

struct ArtworkView: View {
    @EnvironmentObject private var theme: ThemeStore
    var track: Track?
    var seed: String = ""
    var icon: String = "music.note"
    var circle = false

    var body: some View {
        let shape: AnyShape = circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let img = ArtworkCache.image(for: track) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .clipShape(shape)
    }

    private var placeholder: some View {
        let key = seed.isEmpty ? (track?.album ?? "") : seed
        let h = stableHue(key)
        return ZStack {
            LinearGradient(
                colors: [Color(hue: h, saturation: 0.5, brightness: 0.62),
                         Color(hue: h, saturation: 0.65, brightness: 0.30)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GeometryReader { g in
                Image(systemName: icon)
                    .font(.system(size: g.size.width * 0.38))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: g.size.width, height: g.size.height)
            }
        }
    }
}

struct MediaCard: View {
    @EnvironmentObject private var theme: ThemeStore
    let title: String
    let subtitle: String
    var track: Track? = nil
    var seed: String = ""
    var icon: String = "music.note"
    var circle = false
    var width: CGFloat? = 150

    var body: some View {
        VStack(alignment: circle ? .center : .leading, spacing: 8) {
            ArtworkView(track: track, seed: seed.isEmpty ? title : seed, icon: icon, circle: circle)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.secondary)
                .lineLimit(2)
        }
        .frame(width: width, alignment: circle ? .center : .leading)
        .multilineTextAlignment(circle ? .center : .leading)
    }
}

struct SectionHeader: View {
    @EnvironmentObject private var theme: ThemeStore
    let title: String
    var body: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(theme.text)
    }
}

struct Chip: View {
    @EnvironmentObject private var theme: ThemeStore
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? theme.onAccent : theme.text)
                .background(Capsule().fill(selected ? theme.accent : theme.surface))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyLibraryView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 52))
                .foregroundStyle(theme.accent)
            Text("Tu biblioteca está vacía")
                .font(.title3.bold())
                .foregroundStyle(theme.text)
            Text("Importa canciones o carpetas desde la app Archivos (iCloud Drive, En mi iPhone, etc.). Todo se guarda dentro de la app y funciona sin conexión.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
            Button {
                library.showImporter = true
            } label: {
                Label("Importar música", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(theme.accent))
                    .foregroundStyle(theme.onAccent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Slider vertical (para el ecualizador)

struct VerticalSlider: View {
    @EnvironmentObject private var theme: ThemeStore
    @Binding var value: Float
    var range: ClosedRange<Float> = -12...12
    var step: Float = 0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 10
            let inner = max(h - pad * 2, 1)
            let span = range.upperBound - range.lowerBound
            let frac = CGFloat((value - range.lowerBound) / span)
            let thumbY = pad + inner * (1 - frac)
            let midY = pad + inner * 0.5

            ZStack {
                Capsule()
                    .fill(theme.surface)
                    .frame(width: 4, height: h)
                    .position(x: w / 2, y: h / 2)
                Rectangle()
                    .fill(theme.secondary.opacity(0.5))
                    .frame(width: 12, height: 1)
                    .position(x: w / 2, y: midY)
                Capsule()
                    .fill(theme.accent)
                    .frame(width: 4, height: max(abs(thumbY - midY), 0.5))
                    .position(x: w / 2, y: (thumbY + midY) / 2)
                Circle()
                    .fill(theme.text)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .position(x: w / 2, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let f = 1 - min(max((g.location.y - pad) / inner, 0), 1)
                    var v = range.lowerBound + Float(f) * span
                    v = (v / step).rounded() * step
                    if abs(v) < step { v = 0 }
                    value = min(max(v, range.lowerBound), range.upperBound)
                }
            )
        }
    }
}

// MARK: - Barras de progreso (observan el reloj, no todo el reproductor)

struct SeekBar: View {
    @ObservedObject var clock: PlaybackClock
    @EnvironmentObject private var player: PlayerModel
    @EnvironmentObject private var theme: ThemeStore
    @State private var dragging = false
    @State private var dragValue = 0.0

    var body: some View {
        let total = max(player.duration, 1)
        let shown = dragging ? dragValue : min(clock.time, total)
        VStack(spacing: 2) {
            Slider(
                value: Binding(get: { shown }, set: { dragValue = $0 }),
                in: 0...total,
                onEditingChanged: { editing in
                    if editing {
                        dragValue = clock.time
                        dragging = true
                    } else {
                        player.seek(to: dragValue)
                        dragging = false
                    }
                }
            )
            .tint(theme.text)
            HStack {
                Text(formatTime(shown))
                Spacer()
                Text("-" + formatTime(max(0, player.duration - shown)))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(theme.secondary)
        }
    }
}

struct MiniProgress: View {
    @ObservedObject var clock: PlaybackClock
    let duration: Double
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        GeometryReader { g in
            let f = duration > 0 ? min(max(clock.time / duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(theme.secondary.opacity(0.3))
                Capsule().fill(theme.text).frame(width: g.size.width * f)
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Fila de canción

struct TrackRow: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel
    @EnvironmentObject private var library: LibraryStore

    let track: Track
    var showArtwork = true
    var onTap: () -> Void
    var removeAction: (() -> Void)? = nil

    @State private var showPlaylistPicker = false
    @State private var showEdit = false
    @State private var confirmDelete = false

    private var isCurrent: Bool { player.current?.id == track.id }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    if showArtwork {
                        ArtworkView(track: track)
                            .frame(width: theme.theme.compactRows ? 38 : 48,
                                   height: theme.theme.compactRows ? 38 : 48)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.body)
                            .foregroundStyle(isCurrent ? theme.accent : theme.text)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            if track.isFavorite {
                                Image(systemName: "heart.fill").foregroundStyle(theme.accent)
                            }
                            Text(track.artist).lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                    }
                    Spacer(minLength: 0)
                    if isCurrent && player.isPlaying {
                        Image(systemName: "waveform")
                            .foregroundStyle(theme.accent)
                            .symbolEffect(.variableColor.iterative)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(theme.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .contextMenu { actions }
        .sheet(isPresented: $showPlaylistPicker) { PlaylistPickerSheet(trackID: track.id) }
        .sheet(isPresented: $showEdit) { EditTrackSheet(track: track) }
        .confirmationDialog("¿Eliminar “\(track.title)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar archivo de la app", role: .destructive) { library.delete(track) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borra la copia guardada en MiPlayer. Tu archivo original en iCloud no se toca.")
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button { player.playNext(track) } label: {
            Label("Reproducir a continuación", systemImage: "text.insert")
        }
        Button { player.addToQueue(track) } label: {
            Label("Añadir a la cola", systemImage: "text.badge.plus")
        }
        Button { showPlaylistPicker = true } label: {
            Label("Añadir a una lista", systemImage: "music.note.list")
        }
        Button { library.toggleFavorite(track.id) } label: {
            Label(track.isFavorite ? "Quitar de favoritas" : "Añadir a favoritas",
                  systemImage: track.isFavorite ? "heart.slash" : "heart")
        }
        if let removeAction {
            Button(role: .destructive, action: removeAction) {
                Label("Quitar de esta lista", systemImage: "minus.circle")
            }
        }
        Button { showEdit = true } label: {
            Label("Editar información", systemImage: "pencil")
        }
        Button(role: .destructive) { confirmDelete = true } label: {
            Label("Eliminar de la biblioteca", systemImage: "trash")
        }
    }
}

// MARK: - Hojas auxiliares

struct PlaylistPickerSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let trackID: UUID
    @State private var showNew = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Button {
                    newName = ""
                    showNew = true
                } label: {
                    Label("Nueva lista", systemImage: "plus.circle.fill")
                        .foregroundStyle(theme.accent)
                }
                .listRowBackground(theme.surface)

                ForEach(library.playlists) { p in
                    Button {
                        library.add(trackID, to: p.id)
                        dismiss()
                    } label: {
                        HStack {
                            Text(p.name).foregroundStyle(theme.text)
                            Spacer()
                            if p.trackIDs.contains(trackID) {
                                Image(systemName: "checkmark").foregroundStyle(theme.accent)
                            }
                        }
                    }
                    .listRowBackground(theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bg)
            .navigationTitle("Añadir a una lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } }
            }
            .alert("Nueva lista", isPresented: $showNew) {
                TextField("Nombre", text: $newName)
                Button("Crear") {
                    library.createPlaylist(name: newName, trackIDs: [trackID])
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct EditTrackSheet: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Track

    init(track: Track) {
        _draft = State(initialValue: track)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Información") {
                    TextField("Título", text: $draft.title)
                    TextField("Artista", text: $draft.artist)
                    TextField("Álbum", text: $draft.album)
                }
                .listRowBackground(theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.bg)
            .navigationTitle("Editar canción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        library.update(draft)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Destinos de navegación compartidos

extension View {
    func collectionDestinations() -> some View {
        navigationDestination(for: Destination.self) { CollectionDetailView(destination: $0) }
    }
}
