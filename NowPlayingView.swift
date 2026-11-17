import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEQ = false
    @State private var showQueue = false
    @State private var showPlaylistPicker = false
    @State private var showEdit = false

    var body: some View {
        ZStack {
            background
            if let t = player.current {
                VStack(spacing: 22) {
                    topBar(t)
                    Spacer(minLength: 0)
                    ArtworkView(track: t, seed: t.album)
                        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                        .scaleEffect(player.isPlaying ? 1 : 0.88)
                        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: player.isPlaying)
                        .padding(.horizontal, 8)
                    Spacer(minLength: 0)
                    titleRow(t)
                    SeekBar(clock: player.clock)
                    controls
                    bottomRow
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            } else {
                Text("No hay nada reproduciéndose")
                    .foregroundStyle(theme.secondary)
            }
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .fontDesign(theme.theme.font.design)
        .tint(theme.accent)
        .sheet(isPresented: $showEQ) {
            NavigationStack {
                EqualizerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("Listo") { showEQ = false }.bold() }
                    }
            }
            .environmentObject(theme)
            .environmentObject(player)
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .environmentObject(theme)
                .environmentObject(player)
        }
        .sheet(isPresented: $showPlaylistPicker) {
            if let t = player.current {
                PlaylistPickerSheet(trackID: t.id)
                    .environmentObject(theme)
                    .environmentObject(library)
            }
        }
        .sheet(isPresented: $showEdit) {
            if let t = player.current {
                EditTrackSheet(track: t)
                    .environmentObject(theme)
                    .environmentObject(library)
            }
        }
    }

    private var background: some View {
        ZStack {
            theme.bg
            if let t = player.current {
                if let _ = ArtworkCache.image(for: t) {
                    ArtworkView(track: t)
                        .scaleEffect(2.4)
                        .blur(radius: 70)
                        .opacity(0.45)
                } else {
                    Color(hue: stableHue(t.album), saturation: 0.5, brightness: 0.5).opacity(0.35)
                }
            }
            LinearGradient(colors: [.clear, theme.bg.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .clipped()
    }

    private func topBar(_ t: Track) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("REPRODUCIENDO DESDE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.secondary)
                Text(player.contextTitle.isEmpty ? t.album : player.contextTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button { showPlaylistPicker = true } label: {
                    Label("Añadir a una lista", systemImage: "music.note.list")
                }
                Button { showEdit = true } label: {
                    Label("Editar información", systemImage: "pencil")
                }
                Button { showEQ = true } label: {
                    Label("Ecualizador y efectos", systemImage: "slider.vertical.3")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(theme.text)
                    .frame(width: 40, height: 40)
            }
        }
    }

    private func titleRow(_ t: Track) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(t.title)
                    .font(.title2.bold())
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(t.artist)
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { library.toggleFavorite(t.id) } label: {
                Image(systemName: t.isFavorite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(t.isFavorite ? theme.accent : theme.text)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button { player.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundStyle(player.shuffle ? theme.accent : theme.text)
            }
            Spacer()
            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.title).foregroundStyle(theme.text)
            }
            Spacer()
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(theme.onAccent)
                    .frame(width: 70, height: 70)
                    .background(Circle().fill(theme.accent))
            }
            Spacer()
            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.title).foregroundStyle(theme.text)
            }
            Spacer()
            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(player.repeatMode == .off ? theme.text : theme.accent)
            }
        }
    }

    private var bottomRow: some View {
        HStack {
            Button { showEQ = true } label: {
                Label("Audio", systemImage: "slider.vertical.3")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.text)
            }
            Spacer()
            Button { showQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(theme.text)
            }
        }
        .padding(.top, 4)
    }
}

struct QueueView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let t = player.current {
                    Section("Reproduciendo") {
                        HStack(spacing: 12) {
                            ArtworkView(track: t).frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(t.title).foregroundStyle(theme.accent).lineLimit(1)
                                Text(t.artist).font(.caption).foregroundStyle(theme.secondary).lineLimit(1)
                            }
                        }
                        .listRowBackground(theme.surface)
                    }
                }
                let upcoming = Array(player.queue.enumerated()).filter { $0.offset > player.currentIndex }
                Section("A continuación") {
                    if upcoming.isEmpty {
                        Text("No hay más canciones en la cola")
                            .foregroundStyle(theme.secondary)
                            .listRowBackground(theme.surface)
                    }
                    ForEach(upcoming, id: \.element.id) { item in
                        Button {
                            player.jump(to: item.offset)
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(track: item.element).frame(width: 44, height: 44)
                                VStack(alignment: .leading) {
                                    Text(item.element.title).foregroundStyle(theme.text).lineLimit(1)
                                    Text(item.element.artist).font(.caption)
                                        .foregroundStyle(theme.secondary).lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(theme.surface)
                        .swipeActions {
                            Button(role: .destructive) {
                                player.removeFromQueue(at: item.offset)
                            } label: { Label("Quitar", systemImage: "trash") }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bg)
            .navigationTitle("Cola")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Listo") { dismiss() }.bold() }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
