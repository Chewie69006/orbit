//
//  CompleteTaskSheet.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Fin d'une tâche : la personne indique le temps réellement passé.
/// On montre l'effet sur son coefficient de pondération avant de valider.
struct CompleteTaskSheet: View {
    let task: TaskItem
    let onComplete: (ManDays, Date) -> Void

    @State private var actual: ManDays
    @State private var completedAt = Date()
    @Environment(OrbitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    init(task: TaskItem, onComplete: @escaping (ManDays, Date) -> Void) {
        self.task = task
        self.onComplete = onComplete
        self._actual = State(initialValue: max(task.effectiveEstimate, .eighth))
    }

    var body: some View {
        let member = store.member(task.assigneeID)
        let current = member.map { store.calibration(for: $0.id) }
        let preview = store.calibrationPreview(completing: task, actualSpent: actual, at: completedAt)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Terminer la tâche")
                    .font(.headline)
                Text(task.title)
                    .foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 20)

            Form {
                LabeledContent("Chiffrage retenu") {
                    Text(task.effectiveEstimate.description)
                        .monospacedDigit()
                }
                ManDaysField("Temps réellement passé", value: $actual, minimum: .eighth)
                DatePicker("Terminée le", selection: $completedAt, in: ...Date(), displayedComponents: .date)
                if !task.effectiveEstimate.isZero {
                    LabeledContent("Écart") {
                        Text(OrbitFormat.deviation(ratio: actual.days / task.effectiveEstimate.days))
                            .monospacedDigit()
                    }
                }
            }
            .formStyle(.grouped)

            if let member, let current, let preview {
                HStack(spacing: 8) {
                    MemberAvatar(member: member, size: 22)
                    Text("Coefficient de \(member.name)")
                    Spacer()
                    FactorBadge(calibration: current)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    FactorBadge(calibration: preview)
                }
                .font(.callout)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Divider()
            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Terminer") {
                    onComplete(actual, completedAt)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460, height: 420)
    }
}
