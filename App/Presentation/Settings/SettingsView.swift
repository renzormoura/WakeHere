import SwiftUI
import WakeHereDomain

/// Ajustes do app (persistidos pelo `SettingsRepository`).
struct SettingsView: View {
    @EnvironmentObject private var root: CompositionRoot
    @State private var settings = AppSettings.default
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Distância", selection: $settings.distanceUnit) {
                        Text("Métrico (km)").tag(DistanceUnit.metric)
                        Text("Imperial (mi)").tag(DistanceUnit.imperial)
                    }
                } header: {
                    Text("Unidades")
                }

                Section {
                    Stepper(
                        value: $settings.defaultSafetyMarginMinutes,
                        in: 0...30,
                        step: 1
                    ) {
                        HStack {
                            Text("Margem de segurança")
                            Spacer()
                            Text("\(settings.defaultSafetyMarginMinutes) min")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Despertar")
                } footer: {
                    Text("Tempo extra somado ao aviso para absorver imprevistos de trânsito.")
                }

                Section {
                    Toggle("Som do alarme", isOn: $settings.soundEnabled)
                    if settings.soundEnabled {
                        Slider(
                            value: $settings.alarmVolume,
                            in: 0...1
                        ) {
                            Text("Volume")
                        } minimumValueLabel: {
                            Image(systemName: "speaker.fill")
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3.fill")
                        }
                    }
                    Toggle("Vibração", isOn: $settings.hapticsEnabled)
                } header: {
                    Text("Alarme")
                }

                Section {
                    LabeledContent("Versão", value: "1.0.0")
                    Text(
                        "O WakeHere usa sua localização durante a viagem para calcular o tempo e a distância até o destino. Nada é enviado para servidores."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Sobre")
                }
            }
            .navigationTitle("Ajustes")
            .onAppear {
                if !hasLoaded {
                    settings = root.currentSettings
                    hasLoaded = true
                }
            }
            .onChange(of: settings) { _, newValue in
                guard hasLoaded else { return }
                try? root.settingsRepository.save(newValue)
            }
        }
    }
}
