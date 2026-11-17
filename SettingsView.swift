import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerModel

    @State private var folderSize = "…"
    @State private var confirmWipe = false

    var body: some View {
        NavigationStack {
            List {
                audioSection
                appearanceSection
                homeSection
                librarySection
                helpSection
            }
            .scrollContentBackground(.hidden)
            .background(theme.bg)
            .navigationTitle("Ajustes")
            .task { await refreshSize() }
            .confirmationDialog("¿Borrar toda la música de la app?",
                                isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) {
                    player.pause()
                    library.deleteEverything()
                    Task { await refreshSize() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se eliminan las copias guardadas en MiPlayer. Tus originales en iCloud o Archivos no se tocan.")
            }
        }
    }

    private func refreshSize() async {
        let bytes = await Task.detached { LibraryStore.musicFolderSize() }.value
        folderSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: Audio

    private var audioSection: some View {
        Section("Audio") {
            NavigationLink {
                EqualizerView()
            } label: {
                Label("Ecualizador, mezcla y perfiles", systemImage: "slider.vertical.3")
            }
            .listRowBackground(theme.surface)
        }
    }

    // MARK: Apariencia

    private var appearanceSection: some View {
        Section("Apariencia") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Temas listos").font(.subheadline).foregroundStyle(theme.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ThemePreset.all) { preset in
                            Button {
                                theme.theme = preset.applied(to: theme.theme)
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(hex: preset.background))
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color(hex: preset.surface))
                                            .frame(width: 38, height: 14)
                                            .offset(y: 8)
                                        Circle()
                                            .fill(Color(hex: preset.accent))
                                            .frame(width: 18, height: 18)
                                            .offset(y: -12)
                                    }
                                    .frame(width: 64, height: 64)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(theme.secondary.opacity(0.4), lineWidth: 1)
                                    )
                                    Text(preset.name)
                                        .font(.caption2)
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                }
                                .frame(width: 72)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listRowBackground(theme.surface)

            ColorPicker("Color de acento", selection: theme.binding(\.accentHex), supportsOpacity: false)
                .listRowBackground(theme.surface)
            ColorPicker("Fondo", selection: theme.binding(\.backgroundHex), supportsOpacity: false)
                .listRowBackground(theme.surface)
            ColorPicker("Tarjetas y botones", selection: theme.binding(\.surfaceHex), supportsOpacity: false)
                .listRowBackground(theme.surface)
            ColorPicker("Texto", selection: theme.binding(\.textHex), supportsOpacity: false)
                .listRowBackground(theme.surface)
            ColorPicker("Texto secundario", selection: theme.binding(\.secondaryHex), supportsOpacity: false)
                .listRowBackground(theme.surface)

            VStack(alignment: .leading) {
                HStack {
                    Text("Esquinas redondeadas")
                    Spacer()
                    Text("\(Int(theme.theme.cornerRadius))")
                        .foregroundStyle(theme.secondary)
                }
                Slider(value: $theme.theme.cornerRadius, in: 0...28, step: 1)
            }
            .listRowBackground(theme.surface)

            Picker("Tipografía", selection: $theme.theme.font) {
                ForEach(FontChoice.allCases) { Text($0.label).tag($0) }
            }
            .listRowBackground(theme.surface)

            Toggle("Filas compactas", isOn: $theme.theme.compactRows)
                .listRowBackground(theme.surface)
            Toggle("Artistas con portada circular", isOn: $theme.theme.circularArtists)
                .listRowBackground(theme.surface)

            Button("Restablecer apariencia", role: .destructive) {
                theme.theme = AppTheme()
            }
            .listRowBackground(theme.surface)
        }
    }

    // MARK: Inicio

    private var homeSection: some View {
        Section("Pantalla de inicio") {
            HStack {
                Text("Tu nombre")
                TextField("Opcional", text: $theme.theme.greetingName)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(theme.secondary)
            }
            .listRowBackground(theme.surface)
            Toggle("Accesos rápidos", isOn: $theme.theme.showQuickGrid)
                .listRowBackground(theme.surface)
            Toggle("Agregadas recientemente", isOn: $theme.theme.showRecent)
                .listRowBackground(theme.surface)
            Toggle("Lo que más escuchas", isOn: $theme.theme.showMostPlayed)
                .listRowBackground(theme.surface)
            Toggle("Álbumes", isOn: $theme.theme.showAlbums)
                .listRowBackground(theme.surface)
            Toggle("Artistas", isOn: $theme.theme.showArtists)
                .listRowBackground(theme.surface)
        }
    }

    // MARK: Biblioteca

    private var librarySection: some View {
        Section("Biblioteca") {
            Button {
                library.showImporter = true
            } label: {
                Label("Importar canciones o carpeta", systemImage: "square.and.arrow.down")
            }
            .listRowBackground(theme.surface)

            Button {
                library.scanMusicFolder()
            } label: {
                Label("Buscar archivos nuevos en la carpeta de la app", systemImage: "arrow.clockwise")
            }
            .listRowBackground(theme.surface)

            HStack {
                Text("Canciones")
                Spacer()
                Text("\(library.tracks.count)").foregroundStyle(theme.secondary)
            }
            .listRowBackground(theme.surface)

            HStack {
                Text("Espacio usado")
                Spacer()
                Text(folderSize).foregroundStyle(theme.secondary)
            }
            .listRowBackground(theme.surface)

            Button(role: .destructive) {
                confirmWipe = true
            } label: {
                Label("Borrar toda la música de la app", systemImage: "trash")
            }
            .listRowBackground(theme.surface)
        }
    }

    private var helpSection: some View {
        Section("Cómo agregar música") {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Desde iCloud Drive u otra nube: toca “Importar” y elige archivos o una carpeta. La app los copia al teléfono, así suenan sin internet.")
                Text("2. Desde la app Archivos: abre “En mi iPhone → MiPlayer → Music”, pega ahí tus canciones y vuelve a esta app; las detecta sola.")
                Text("Formatos: MP3, M4A/AAC, WAV, AIFF, CAF, FLAC y ALAC.")
            }
            .font(.footnote)
            .foregroundStyle(theme.secondary)
            .listRowBackground(theme.surface)
        }
    }
}
