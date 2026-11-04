//
//  NewTaskSheet.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Création d'une tâche : le développeur la chiffre (et peut la découper en sous-tâches).
struct NewTaskSheet: View {
    let members: [Member]
    let onCreate: (TaskItem) -> Void

    @State private var draft: TaskItem
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    init(draft: TaskItem, members: [Member], onCreate: @escaping (TaskItem) -> Void) {
        self.members = members
        self.onCreate = onCreate
        self._draft = State(initialValue: draft)
    }

    private var trimmedTitle: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty && !draft.effectiveEstimate.isZero
    }

    /// Coefficient de la personne choisie, pour montrer la durée qui sera planifiée.
    private var factor: Double? {
        guard store.settings.applyCalibration, let assigneeID = draft.assigneeID else { return nil }
        return store.calibration(for: assigneeID).factor
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Nouvelle tâche")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 20)
            Form {
                TaskEditorFields(task: $draft, members: members, factor: factor)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                if draft.effectiveEstimate.isZero {
                    Label("Chiffrez la tâche pour pouvoir la créer.", systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Créer la tâche") {
                    onCreate(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCreate)
            }
            .padding(16)
        }
        .frame(width: 540, height: 640)
    }
}
