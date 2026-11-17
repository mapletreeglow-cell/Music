import SwiftUI

/// Pantalla de detalle para listas, álbumes, artistas, favoritas y "todas las canciones".
struct CollectionDetailView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerModel
    @Environment(\.dismiss) private var dismiss

    let destination: Destination

    @State private var showRename = false
    @State private var renameText = ""
    @State private var confirmDelete = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        let info = library.resolve(destination)
        let headerColor = Color(hex: info.colorHex ?? hexForHue(stableHue(info.title)))

        List {
            header(info)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if info.tracks.isEmpty {
                Text(info.playlistID != nil
                     ? "Esta lista está vacía. Usa el menú ··· de cualquier canción y elige “Añadir a una lista”."
                     : "No hay canciones aquí todavía.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(Array(info.tracks.enumerated()), id: \.element.id) { i, t in
                TrackRow(
                    track: t,
                    onTap: {
                        player.play(info.tracks, startAt: i, shuffled: player.shuffle, context: info.title)
                    },
                    removeAction: info.playlistID == nil ? nil : {
                        if let pid = info.playlistID { library.removeTrack(t.id, from: pid) }
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
                .deleteDisabled(info.playlistID == nil)
                .moveDisabled(info.playlistID == nil)
            }
            .onDelete { offsets in
                guard let pid = info.playlistID else { return }
                let ids = offsets.map { info.tracks[$0].id }
                for id in ids { library.removeTrack(id, from: pid) }
            }
            .onMove { from, to in
                guard let pid = info.playlistID else { return }
                library.moveTracks(from: from, to: to, in: pid)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .background {
            ZStack {
                theme.bg
                LinearGradient(colors: [headerColor.opacity(0.7), theme.bg],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.5))
            }
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if info.playlistID != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            renameText = info.title
                            showRename = true
                        } label: { Label("Cambiar nombre", systemImage: "pencil") }
                        Button {
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        } label: { Label(editMode == .active ? "Terminar de ordenar" : "Reordenar canciones",
                                         systemImage: "arrow.up.arrow.down") }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Eliminar lista", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .alert("Cambiar nombre", isPresented: $showRename) {
            TextField("Nombre", text: $renameText)
            Button("Guardar") {
                if let pid = info.playlistID { library.renamePlaylist(pid, to: renameText) }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("¿Eliminar esta lista?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar lista", role: .destructive) {
                if let pid = info.playlistID {
                    library.deletePlaylist(pid)
                    dismiss()
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las canciones seguirán en tu biblioteca.")
        }
    }

    private func hexForHue(_ h: Double) -> String {
        Color(hue: h, saturation: 0.55, brightness: 0.5).hexString()
    }

    private func header(_ info: CollectionInfo) -> some View {
        let rep = info.tracks.first(where: { $0.hasArtwork }) ?? info.tracks.first
        return VStack(spacing: 14) {
            ArtworkView(track: rep, seed: info.colorHex ?? info.title,
                        icon: info.icon ?? (info.circle ? "person.fill" : "music.note"),
                        circle: info.circle)
                .frame(width: 210, height: 210)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text(info.title)
                    .font(.title2.bold())
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                Text(info.subtitle)
                    .font(.footnote)
                    .foregroundStyle(theme.secondary)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 22) {
                Button {
                    player.playShuffled(info.tracks, context: info.title)
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title2)
                        .foregroundStyle(theme.text)
                }
                .disabled(info.tracks.isEmpty)

                Button {
                    player.play(info.tracks, startAt: 0, shuffled: false, context: info.title)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(theme.accent))
                }
                .disabled(info.tracks.isEmpty)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
