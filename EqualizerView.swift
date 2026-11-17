import SwiftUI

struct EqualizerView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerModel

    @State private var showSave = false
    @State private var profileName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                eqSection
                effectsSection
                profilesSection

                Button(role: .destructive) {
                    player.resetAudio()
                } label: {
                    Label("Restablecer todo el audio", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .background(theme.bg)
        .navigationTitle("Audio")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Guardar perfil de audio", isPresented: $showSave) {
            TextField("Nombre del perfil", text: $profileName)
            Button("Guardar") { player.saveProfile(named: profileName) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Guarda el ecualizador y los efectos actuales para recuperarlos con un toque.")
        }
    }

    // MARK: Ecualizador

    private var eqSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $player.audio.eqEnabled) {
                Text("Ecualizador").font(.title3.bold()).foregroundStyle(theme.text)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EQPreset.all) { preset in
                        Chip(title: preset.name, selected: player.audio.presetName == preset.name) {
                            player.applyPreset(preset)
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<10, id: \.self) { i in
                    VStack(spacing: 6) {
                        Text(String(format: "%+.0f", player.audio.bands[i]))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(theme.secondary)
                        VerticalSlider(
                            value: Binding(
                                get: { player.audio.bands[i] },
                                set: { player.setBand(i, to: $0) }
                            ),
                            range: -12...12,
                            step: 0.5
                        )
                        .frame(height: 190)
                        Text(EQ.labels[i])
                            .font(.system(size: 10))
                            .foregroundStyle(theme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .opacity(player.audio.eqEnabled ? 1 : 0.4)
            .disabled(!player.audio.eqEnabled)

            VStack(alignment: .leading, spacing: 4) {
                valueRow("Preamplificador", String(format: "%+.1f dB", player.audio.preamp))
                Slider(value: $player.audio.preamp, in: -12...12, step: 0.5)
                Toggle("Evitar distorsión (baja el volumen si subes mucho el EQ)",
                       isOn: $player.audio.autoHeadroom)
                    .font(.footnote)
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    // MARK: Efectos / mezcla

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mezcla y efectos").font(.title3.bold()).foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: 4) {
                valueRow("Velocidad", String(format: "%.2fx", player.audio.rate))
                Slider(value: $player.audio.rate, in: 0.5...2.0, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                valueRow("Tono", String(format: "%+.0f semitonos", player.audio.pitchSemitones))
                Slider(value: $player.audio.pitchSemitones, in: -12...12, step: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                valueRow("Balance izquierda / derecha", balanceText)
                Slider(value: $player.audio.balance, in: -1...1, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                valueRow("Reverberación", String(format: "%.0f %%", player.audio.reverbMix))
                Slider(value: $player.audio.reverbMix, in: 0...100, step: 1)
                Picker("Ambiente", selection: $player.audio.reverbPreset) {
                    ForEach(ReverbOption.all) { option in
                        Text(option.name).tag(option.raw)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var balanceText: String {
        let b = player.audio.balance
        if abs(b) < 0.03 { return "Centro" }
        return b < 0 ? "Izq. \(Int(abs(b) * 100)) %" : "Der. \(Int(b * 100)) %"
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(theme.text)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(theme.secondary)
        }
    }

    // MARK: Perfiles

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mis perfiles de audio").font(.title3.bold()).foregroundStyle(theme.text)
                Spacer()
                Button {
                    profileName = ""
                    showSave = true
                } label: {
                    Label("Guardar actual", systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold))
                }
            }

            if player.profiles.isEmpty {
                Text("Aún no guardaste ninguno. Ajusta el audio a tu gusto y guárdalo aquí (por ejemplo “Audífonos”, “Auto”, “Parlante”).")
                    .font(.footnote)
                    .foregroundStyle(theme.secondary)
            }

            ForEach(player.profiles) { profile in
                HStack {
                    Button {
                        player.apply(profile)
                    } label: {
                        HStack {
                            Image(systemName: "slider.vertical.3").foregroundStyle(theme.accent)
                            Text(profile.name).foregroundStyle(theme.text)
                            Spacer()
                            Text("Aplicar").font(.footnote).foregroundStyle(theme.secondary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(theme.surface)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        player.deleteProfile(profile)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
