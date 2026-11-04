//
//  NameSheet.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Petite feuille de saisie d'un nom (création ou renommage d'une équipe).
struct NameSheet: View {
    let title: String
    let actionTitle: String
    let onSubmit: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(title: String, initialName: String = "", actionTitle: String, onSubmit: @escaping (String) -> Void) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSubmit = onSubmit
        self._name = State(initialValue: initialName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            TextField("Nom", text: $name, prompt: Text("Ex. : Équipe Mobile"))
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(actionTitle, action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func submit() {
        guard !trimmedName.isEmpty else { return }
        onSubmit(trimmedName)
        dismiss()
    }
}

extension Binding where Value == Bool {
    /// Vrai tant que la valeur optionnelle est renseignée ; la remet à nil à la fermeture.
    init<Wrapped>(isPresenting optional: Binding<Wrapped?>) {
        self.init(
            get: { optional.wrappedValue != nil },
            set: { if !$0 { optional.wrappedValue = nil } }
        )
    }
}
