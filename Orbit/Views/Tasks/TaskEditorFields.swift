//
//  TaskEditorFields.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Champs d'édition d'une tâche (sections de `Form`), partagés par la création et l'inspecteur.
struct TaskEditorFields: View {
    @Binding var task: TaskItem
    let members: [Member]
    /// Coefficient appliqué au planning pour la personne assignée (nil s'il n'y en a pas).
    let factor: Double?

    /// Une tâche terminée garde son chiffrage : il sert au calcul de la pondération.
    private var isEstimateLocked: Bool { task.status == .done }

    var body: some View {
        Section {
            TextField("Titre", text: $task.title, prompt: Text("Ex. : Écran de paiement"))
            Picker("Assignée à", selection: $task.assigneeID) {
                Text("Personne").tag(UUID?.none)
                ForEach(members) { member in
                    Text(member.name).tag(UUID?.some(member.id))
                }
            }
        }

        Section {
            ManDaysField("Chiffrage de la tâche", value: $task.estimate)
                .disabled(isEstimateLocked)
            if !task.subtasks.isEmpty {
                LabeledContent("Somme des sous-tâches") {
                    Text(task.subtasksEstimate.description)
                        .monospacedDigit()
                }
                LabeledContent("Chiffrage retenu") {
                    Text(task.effectiveEstimate.description)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            if let factor, task.isOpen, task.assigneeID != nil {
                LabeledContent("Durée planifiée") {
                    Text("\(task.effectiveEstimate.scaled(by: factor).description)  (\(OrbitFormat.factor(factor)))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Chiffrage")
        } footer: {
            Text(estimateFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Sous-tâches") {
            ForEach(task.subtasks) { subtask in
                SubtaskRow(subtask: subtaskBinding(subtask.id), isLocked: isEstimateLocked) {
                    task.subtasks.removeAll { $0.id == subtask.id }
                }
            }
            Button {
                task.subtasks.append(Subtask(title: "", estimate: .halfDay))
            } label: {
                Label("Ajouter une sous-tâche", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(isEstimateLocked)
        }

        if task.isOpen {
            Section("Planification") {
                Toggle("Ne pas commencer avant une date", isOn: hasNotBefore)
                if task.notBefore != nil {
                    DatePicker("Début au plus tôt", selection: notBeforeDate, displayedComponents: .date)
                }
            }
        }

        Section("Notes") {
            TextEditor(text: $task.notes)
                .font(.body)
                .frame(minHeight: 70)
        }
    }

    private var estimateFooter: String {
        if isEstimateLocked {
            return "La tâche est terminée : son chiffrage est figé car il sert au calcul de la pondération."
        }
        return "En jours-hommes, au ⅛ de journée. Si la somme des sous-tâches dépasse le chiffrage de la tâche, c'est elle qui est retenue."
    }

    private func subtaskBinding(_ id: UUID) -> Binding<Subtask> {
        Binding(
            get: { task.subtasks.first { $0.id == id } ?? Subtask(id: id, title: "", estimate: .zero) },
            set: { newValue in
                if let index = task.subtasks.firstIndex(where: { $0.id == id }) {
                    task.subtasks[index] = newValue
                }
            }
        )
    }

    private var hasNotBefore: Binding<Bool> {
        Binding(
            get: { task.notBefore != nil },
            set: { isOn in
                task.notBefore = isOn ? (task.notBefore ?? Calendar.current.startOfDay(for: Date())) : nil
            }
        )
    }

    private var notBeforeDate: Binding<Date> {
        Binding(
            get: { task.notBefore ?? Date() },
            set: { task.notBefore = Calendar.current.startOfDay(for: $0) }
        )
    }
}

struct SubtaskRow: View {
    @Binding var subtask: Subtask
    let isLocked: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("Terminée", isOn: $subtask.isDone)
                .toggleStyle(.checkbox)
                .labelsHidden()
            TextField("Sous-tâche", text: $subtask.title, prompt: Text("Sous-tâche"))
                .labelsHidden()
                .strikethrough(subtask.isDone)
            ManDaysField(value: $subtask.estimate)
                .disabled(isLocked)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .disabled(isLocked)
            .help("Supprimer la sous-tâche")
        }
    }
}
