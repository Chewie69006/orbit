//
//  TaskInspector.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Panneau latéral : détail et édition de la tâche sélectionnée.
struct TaskInspector: View {
    let taskID: UUID?
    let actions: TaskActions

    @Environment(OrbitStore.self) private var store

    var body: some View {
        if let task = store.task(taskID) {
            TaskDetailView(task: task, actions: actions)
                .id(task.id)
        } else {
            ContentUnavailableView(
                "Aucune tâche sélectionnée",
                systemImage: "square.dashed",
                description: Text("Sélectionnez une tâche dans le planning ou dans les files.")
            )
        }
    }
}

struct TaskDetailView: View {
    let task: TaskItem
    let actions: TaskActions

    @Environment(OrbitStore.self) private var store

    /// Chaque modification est enregistrée immédiatement dans le store.
    private var binding: Binding<TaskItem> {
        Binding(
            get: { store.task(task.id) ?? task },
            set: { store.updateTask($0) }
        )
    }

    var body: some View {
        let schedule = store.schedule(for: task.teamID)
        let item = schedule.item(for: task.id)
        Form {
            statusSection(schedule: schedule, item: item)
            TaskEditorFields(
                task: binding,
                members: store.members(in: task.teamID),
                factor: task.assigneeID.flatMap { schedule.members[$0]?.appliedFactor }
            )
            if task.status == .done {
                completionSection
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Sections

    @ViewBuilder
    private func statusSection(schedule: TeamSchedule, item: ScheduledTask?) -> some View {
        Section {
            LabeledContent("Statut") {
                Label(task.status.label, systemImage: task.status.systemImage)
            }
            if let item {
                let startTitle: String = task.isOpen ? "Début prévu" : "Début"
                let endTitle: String = task.isOpen ? "Fin prévue" : "Fin"
                LabeledContent(startTitle) {
                    Text(schedule.startDate(of: item), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                }
                LabeledContent(endTitle) {
                    Text(schedule.endDate(of: item), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                }
                if item.isOverdue {
                    Label("Aurait déjà dû être terminée d'après le chiffrage pondéré.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } else if task.assigneeID == nil {
                Text("Assignez la tâche à quelqu'un pour la planifier.")
                    .foregroundStyle(.secondary)
            }
            actionButtons
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            switch task.status {
            case .todo:
                Button("Démarrer", systemImage: "play.fill") { actions.start(task.id) }
                Button("Terminer…", systemImage: "checkmark") { actions.complete(task.id) }
            case .inProgress:
                Button("Terminer…", systemImage: "checkmark") { actions.complete(task.id) }
                    .buttonStyle(.borderedProminent)
                Button("Remettre à faire", systemImage: "pause") { actions.stop(task.id) }
            case .done:
                Button("Rouvrir", systemImage: "arrow.uturn.backward") { actions.reopen(task.id) }
            }
            Spacer()
            Button(role: .destructive) {
                actions.delete(task.id)
            } label: {
                Image(systemName: "trash")
            }
            .help("Supprimer la tâche")
        }
    }

    private var completionSection: some View {
        Section {
            ManDaysField("Temps passé", value: actualBinding, minimum: .eighth)
            DatePicker("Terminée le", selection: completedAtBinding, displayedComponents: .date)
            if let actual = task.actualSpent, !task.effectiveEstimate.isZero {
                LabeledContent("Écart") {
                    Text(OrbitFormat.deviation(ratio: actual.days / task.effectiveEstimate.days))
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Réalisé")
        } footer: {
            Text("Le temps passé alimente le coefficient de pondération de la personne assignée.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actualBinding: Binding<ManDays> {
        Binding(
            get: { binding.wrappedValue.actualSpent ?? binding.wrappedValue.effectiveEstimate },
            set: { binding.wrappedValue.actualSpent = $0 }
        )
    }

    private var completedAtBinding: Binding<Date> {
        Binding(
            get: { binding.wrappedValue.completedAt ?? Date() },
            set: { binding.wrappedValue.completedAt = $0 }
        )
    }
}
