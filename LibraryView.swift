import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerModel

    private enum Filter: String, CaseIterable {
        case all = "Todo", playlists = "Listas", albums = "Álbumes", artists = "Artistas", songs = "Canciones"
    }

    private struct LibItem: Identifiable {
        let id: String
        let dest: Destination
        let title: String
        let subtitle: String
        let track: Track?
        var circle = false
        var icon = "music.note"
        var date: Date
    }

    @State private var filter: Filter = .all
    @State private var alphabetical = false
    @AppStorage("libraryGrid") private var grid = false
    @State private var showNewPlaylist = false
    @State private var newName = ""

    private var items: [LibItem] {
        var result: [LibItem] = []
        if filter == .all {
            result.append(LibItem(id: "fav", dest: .favorites, title: "Canciones favoritas",
                                  subtitle: "Lista · \(library.favorites.count) canciones",
                                  track: nil, icon: "heart.fill", date: .distantFuture))
        }
        if filter == .all || filter == .playlists {
            for p in library.playlists {
                let list = library.tracks(in: p.id)
                result.append(LibItem(id: p.id.uuidString, dest: .playlist(p.id), title: p.name,
                                      subtitle: "Lista · \(list.count) canciones",
                                      track: list.first(where: { $0.hasArtwork }) ?? list.first,
                                      icon: "music.note.list", date: p.createdAt))
            }
        }
        if filter == .all || filter == .albums {
            for a in library.albums {
                result.append(LibItem(id: "al-" + a.id, dest: .album(a.id), title: a.title,
                                      subtitle: "Álbum · \(a.subtitle)", track: a.representative,
                                      icon: "square.stack", date: a.latestAdded))
            }
        }
        if filter == .all || filter == .artists {
            for a in library.artists {
                result.append(LibItem(id: "ar-" + a.id, dest: .artist(a.id), title: a.title,
                                      subtitle: "Artista", track: a.representative,
                                      circle: theme.theme.circularArtists, icon: "person.fill",
                                      date: a.latestAdded))
            }
        }
        if alphabetical {
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } else {
            result.sort { $0.date > $1.date }
        }
        return result
    }

    private var songs: [Track] {
        let all = library.tracks
        return alphabetical
            ? all.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            : all.sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Filter.allCases, id: \.self) { f in
                                Chip(title: f.rawValue, selected: filter == f) { filter = f }
                            }
                        }
                    }

                    HStack {
                        Button {
                            alphabetical.toggle()
                        } label: {
                            Label(alphabetical ? "Orden alfabético" : "Más recientes",
                                  systemImage: "arrow.up.arrow.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(theme.text)
                        }
                        Spacer()
                        if filter != .songs {
                            Button { grid.toggle() } label: {
                                Image(systemName: grid ? "list.bullet" : "square.grid.2x2")
                                    .foregroundStyle(theme.text)
                            }
                        }
                    }

                    if library.tracks.isEmpty && library.playlists.isEmpty {
                        EmptyLibraryView()
                    } else if filter == .songs {
                        let list = songs
                        LazyVStack(spacing: 8) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { i, t in
                                TrackRow(track: t) {
                                    player.play(list, startAt: i, shuffled: player.shuffle, context: "Tus canciones")
                                }
                            }
                        }
                    } else if grid {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                                  spacing: 18) {
                            ForEach(items) { item in
                                NavigationLink(value: item.dest) {
                                    MediaCard(title: item.title, subtitle: item.subtitle, track: item.track,
                                              seed: item.title, icon: item.icon, circle: item.circle, width: nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(items) { item in
                                NavigationLink(value: item.dest) {
                                    HStack(spacing: 12) {
                                        ArtworkView(track: item.track, seed: item.title,
                                                    icon: item.icon, circle: item.circle)
                                            .frame(width: 56, height: 56)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title).foregroundStyle(theme.text).lineLimit(1)
                                            Text(item.subtitle).font(.caption)
                                                .foregroundStyle(theme.secondary).lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(theme.bg)
            .navigationTitle("Tu biblioteca")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { library.showImporter = true } label: {
                            Label("Importar canciones o carpeta", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            newName = ""
                            showNewPlaylist = true
                        } label: {
                            Label("Nueva lista", systemImage: "plus")
                        }
                        Button { library.scanMusicFolder() } label: {
                            Label("Buscar archivos nuevos", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Nueva lista", isPresented: $showNewPlaylist) {
                TextField("Nombre", text: $newName)
                Button("Crear") { library.createPlaylist(name: newName) }
                Button("Cancelar", role: .cancel) {}
            }
            .collectionDestinations()
        }
    }
}
