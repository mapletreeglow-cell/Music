import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerModel
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var songResults: [Track] {
        library.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
            || $0.artist.localizedCaseInsensitiveContains(trimmed)
            || $0.album.localizedCaseInsensitiveContains(trimmed)
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var albumResults: [TrackGroup] {
        library.albums.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private var artistResults: [TrackGroup] {
        library.artists.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if trimmed.isEmpty {
                    browse
                } else {
                    results
                }
            }
            .background(theme.bg)
            .navigationTitle("Buscar")
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "¿Qué quieres escuchar?")
            .collectionDestinations()
        }
    }

    // MARK: Explorar

    private var browse: some View {
        VStack(alignment: .leading, spacing: 16) {
            if library.tracks.isEmpty {
                EmptyLibraryView()
            } else {
                SectionHeader(title: "Explorar tu música")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    NavigationLink(value: Destination.favorites) {
                        tile(title: "Favoritas", seed: "fav", track: nil, icon: "heart.fill")
                    }
                    NavigationLink(value: Destination.allSongs) {
                        tile(title: "Todas las canciones", seed: "all", track: nil, icon: "music.note")
                    }
                    ForEach(library.albums) { a in
                        NavigationLink(value: Destination.album(a.id)) {
                            tile(title: a.title, seed: a.title, track: a.representative, icon: "square.stack")
                        }
                    }
                    ForEach(library.artists) { a in
                        NavigationLink(value: Destination.artist(a.id)) {
                            tile(title: a.title, seed: a.title, track: a.representative, icon: "person.fill")
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func tile(title: String, seed: String, track: Track?, icon: String) -> some View {
        let h = stableHue(seed)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .fill(Color(hue: h, saturation: 0.6, brightness: theme.isDark ? 0.55 : 0.85))
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(10)
                .frame(maxWidth: 110, alignment: .leading)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ArtworkView(track: track, seed: seed, icon: icon)
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(25))
                        .offset(x: 10, y: 6)
                        .shadow(radius: 4)
                }
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
    }

    // MARK: Resultados

    private var results: some View {
        let songs = songResults
        let albums = albumResults
        let artists = artistResults
        return VStack(alignment: .leading, spacing: 20) {
            if songs.isEmpty && albums.isEmpty && artists.isEmpty {
                Text("Sin resultados para “\(trimmed)”")
                    .foregroundStyle(theme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
            if !artists.isEmpty {
                SectionHeader(title: "Artistas")
                ForEach(artists) { a in
                    NavigationLink(value: Destination.artist(a.id)) {
                        groupRow(a, icon: "person.fill", circle: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !albums.isEmpty {
                SectionHeader(title: "Álbumes")
                ForEach(albums) { a in
                    NavigationLink(value: Destination.album(a.id)) {
                        groupRow(a, icon: "square.stack", circle: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !songs.isEmpty {
                SectionHeader(title: "Canciones")
                LazyVStack(spacing: 8) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { i, t in
                        TrackRow(track: t) {
                            player.play(songs, startAt: i, shuffled: false, context: "Búsqueda: \(trimmed)")
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func groupRow(_ g: TrackGroup, icon: String, circle: Bool) -> some View {
        HStack(spacing: 12) {
            ArtworkView(track: g.representative, seed: g.title, icon: icon, circle: circle)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.title).foregroundStyle(theme.text).lineLimit(1)
                Text(g.subtitle).font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
