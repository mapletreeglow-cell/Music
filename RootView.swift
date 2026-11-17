import SwiftUI
import UniformTypeIdentifiers

enum AppTab: String, CaseIterable {
    case home, search, library, settings

    var title: String {
        switch self {
        case .home: return "Inicio"
        case .search: return "Buscar"
        case .library: return "Biblioteca"
        case .settings: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .library: return "books.vertical.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel
    @EnvironmentObject private var library: LibraryStore
    @State private var tab: AppTab = .home

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            // Las cuatro pestañas viven a la vez para conservar su navegación.
            ZStack {
                HomeView().tabVisible(tab == .home)
                SearchView().tabVisible(tab == .search)
                LibraryView().tabVisible(tab == .library)
                SettingsView().tabVisible(tab == .settings)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomBar(tab: $tab)
            }
        }
        .overlay(alignment: .top) { statusBanner }
        .sheet(isPresented: $player.showFullPlayer) {
            NowPlayingView()
                .environmentObject(theme)
                .environmentObject(player)
                .environmentObject(library)
        }
        .fileImporter(
            isPresented: $library.showImporter,
            allowedContentTypes: [.audio, .folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                library.importURLs(urls)
            }
        }
        .alert("No se pudo reproducir", isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .fontDesign(theme.theme.font.design)
        .tint(theme.accent)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let status = library.importStatus {
            HStack(spacing: 10) {
                if library.isImporting { ProgressView().tint(theme.onAccent) }
                Text(status).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(theme.accent))
            .shadow(radius: 6)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private extension View {
    func tabVisible(_ visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

// MARK: - Barra inferior: mini reproductor + pestañas

struct BottomBar: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel
    @Binding var tab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            if player.current != nil {
                MiniPlayer()
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }
            HStack {
                ForEach(AppTab.allCases, id: \.self) { t in
                    Button {
                        tab = t
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon).font(.system(size: 20))
                            Text(t.title).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(tab == t ? theme.text : theme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .padding(.top, 6)
        .background(
            LinearGradient(colors: [theme.bg.opacity(0), theme.bg.opacity(0.96), theme.bg],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        if let t = player.current {
            let hue = stableHue(t.album)
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    ArtworkView(track: t)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Text(t.artist)
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button { library.toggleFavorite(t.id) } label: {
                        Image(systemName: t.isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(t.isFavorite ? theme.accent : theme.text)
                            .frame(width: 40, height: 40)
                    }
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(theme.text)
                            .frame(width: 40, height: 40)
                    }
                }
                MiniProgress(clock: player.clock, duration: player.duration)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.radius + 2, style: .continuous)
                    .fill(Color(hue: hue, saturation: 0.35, brightness: theme.isDark ? 0.32 : 0.85))
            )
            .contentShape(Rectangle())
            .onTapGesture { player.showFullPlayer = true }
        }
    }
}
