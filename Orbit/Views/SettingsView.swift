//
//  SettingsView.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Réglages de l'application (⌘,).
struct SettingsView: View {
    @Environment(OrbitStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                ForEach(Weekday.ordered(for: .current)) { day in
                    Toggle(day.name(), isOn: workingDayBinding(day))
                        .disabled(isLastWorkingDay(day))
                }
            } header: {
                Text("Jours travaillés")
            } footer: {
                Text("Le planning n'enchaîne les tâches que sur ces jours. Il faut au moins un jour travaillé.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Ajuster les durées du planning avec le coefficient de chaque membre", isOn: $store.settings.applyCalibration)
                LabeledContent("Réactivité (α)") {
                    HStack {
                        Slider(value: $store.settings.smoothing, in: AppSettings.smoothingRange, step: 0.05) {
                            Text("Réactivité")
                        } minimumValueLabel: {
                            Text("Stable")
                        } maximumValueLabel: {
                            Text("Réactive")
                        }
                        .labelsHidden()
                        Text(store.settings.smoothing.formatted(.number.precision(.fractionLength(2))))
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Button("Rétablir la valeur par défaut (\(AppSettings.defaultSmoothing.formatted(.number.precision(.fractionLength(2)))))") {
                    store.settings.smoothing = AppSettings.defaultSmoothing
                }
                .disabled(store.settings.smoothing == AppSettings.defaultSmoothing)
            } header: {
                Text("Pondération des chiffrages")
            } footer: {
                Text("""
                Quand une tâche est terminée, on compare le temps passé au chiffrage. Le coefficient de chaque \
                membre est une moyenne mobile exponentielle de ces rapports : coefficient = α × dernier rapport \
                + (1 − α) × coefficient précédent. Plus α est élevé, plus les dernières tâches comptent.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
    }

    private func workingDayBinding(_ day: Weekday) -> Binding<Bool> {
        Binding(
            get: { store.settings.workingDays.contains(day) },
            set: { isOn in
                var days = store.settings.workingDays
                if isOn {
                    days.insert(day)
                } else if days.count > 1 {
                    days.remove(day)
                }
                store.settings.workingDays = days
            }
        )
    }

    private func isLastWorkingDay(_ day: Weekday) -> Bool {
        store.settings.workingDays == [day]
    }
}

#Preview {
    SettingsView()
        .environment(OrbitStore(data: OrbitData()))
}
