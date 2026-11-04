//
//  ManDaysField.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Saisie d'une durée en jours-hommes : champ texte libre (« 1,5 », « 1 3/8 », « 6h »)
/// et flèches pour ajuster au ⅛ de journée.
struct ManDaysField: View {
    private let title: LocalizedStringKey?
    @Binding private var value: ManDays
    private let minimum: ManDays

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(_ title: LocalizedStringKey? = nil, value: Binding<ManDays>, minimum: ManDays = .zero) {
        self.title = title
        self._value = value
        self.minimum = minimum
    }

    var body: some View {
        Group {
            if let title {
                LabeledContent(title) { editor }
            } else {
                editor
            }
        }
        .onAppear { text = value.description }
        .onChange(of: value) { _, newValue in
            text = newValue.description
        }
    }

    private var editor: some View {
        HStack(spacing: 4) {
            TextField("Durée", text: $text)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
            Stepper("Durée", value: eighths, in: minimum.eighths...(ManDays.eighthsPerDay * 999))
                .labelsHidden()
        }
        .help("En jours (2 · 1,5 · 1 3/8 · ⅜) ou en heures (6h = ¾ j). Précision : ⅛ de journée.")
    }

    private var eighths: Binding<Int> {
        Binding(
            get: { value.eighths },
            set: { value = ManDays(eighths: max($0, minimum.eighths)) }
        )
    }

    private func commit() {
        if let parsed = ManDays.parse(text) {
            value = max(parsed, minimum)
        }
        text = value.description
    }
}
