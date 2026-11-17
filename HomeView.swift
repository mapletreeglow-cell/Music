import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerModel

    private struct QuickItem: Identifiable {
        let id: String
        let dest: Destination
        let title: String
        let track: Track?
        let colorHex: String?
        let icon: String
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let base = h < 12 ? "Buenos días" : (h < 20 ? "Buenas tardes" : "Buenas noches")
        let name = theme.theme.greetingName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var quickItems: [QuickItem] {
        var items: [QuickItem] = [
            QuickItem(id: "fav", dest: .favorites, title: "Canciones favoritas",
                      track: nil, colorHex: "5038A0", icon: "heart.fill")
        ]
        for p in library.playlists.prefix(3) {
            let first = library.tracks(in: p.id).first(where: { $0.hasArtwork }) ?? library.tracks(in: p.id).first
            items.append(QuickItem(id: p.id.uuidString, dest: .playlist(p.id), title: p.name,
                                   track: first, colorHex: p.colorHex, icon: "music.note.list"))
        }
        for a in library.albums.sorted(by: { $0.latestAdded > $1.latestAdded }) {
            if items.count >= 6 { break }
            items.append(QuickItem(id: "al-" + a.id, dest: .album(a.id), title: a.title,
                                   track: a.representative, colorHex: nil, icon: "square.stack"))
        }
        return items
    }

    private var recent: [Track] {
        Array(library.tracks.sorted { $0.addedAt > $1.addedAt }.prefix(15))
    }

    private var mostPlayed: [Track] {
        Array(library.tracks.filter { $0.playCount > 0 }
            .sorted { $0.playCount > $1.playCount }.prefix(15))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text(greeting)
                        .font(.title.bold())
                        .foregroundStyle(theme.text)

                    if library.tracks.isEmpty {
                        EmptyLibraryView()
                    } else {
                        if theme.theme.showQuickGrid { quickGrid }
                        if theme.theme.showRecent { trackCarousel("Agregadas recientemente", recent) }
                        if theme.theme.showMostPlayed, !mostPlayed.isEmpty {
                            trackCarousel("Lo que más escuchas", mostPlayed)
                        }
                        if theme.theme.showAlbums { albumCarousel }
                        if theme.theme.showArtists { artistCarousel }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .collectionDestinations()
        }
    }

    private var quickGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(quickItems) { item in
                NavigationLink(value: item.dest) {
                    HStack(spacing: 10) {
                        ArtworkView(track: item.track,
                                    seed: item.colorHex ?? item.title,
                                    icon: item.icon)
                            .frame(width: 52, height: 52)
                        Text(item.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(theme.surface)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func trackCarousel(_ title: String, _ tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { i, t in
                        Button {
                            player.play(tracks, startAt: i, shuffled: false, context: title)
                        } label: {
                            MediaCard(title: t.title, subtitle: t.artist, track: t)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var albumCarousel: some View {
        let albums = library.albums
        return Group {
            if !albums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Tus álbumes")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(albums) { a in
                                NavigationLink(value: Destination.album(a.id)) {
                                    MediaCard(title: a.title, subtitle: a.subtitle, track: a.representative)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var artistCarousel: some View {
        let artists = library.artists
        return Group {
            if !artists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Tus artistas")
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            ForEach(artists) { a in
                                NavigationLink(value: Destination.artist(a.id)) {
                                    MediaCard(title: a.title, subtitle: a.subtitle, track: a.representative,
                                              icon: "person.fill", circle: theme.theme.circularArtists)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}
