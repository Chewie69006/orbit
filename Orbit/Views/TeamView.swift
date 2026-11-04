//
//  TeamView.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Actions sur une tâche, partagées par le planning, les files et l'inspecteur.
struct TaskActions {
    var select: (UUID) -> Void
    var start: (UUID) -> Void
    var stop: (UUID) -> Void
    var complete: (UUID) -> Void
    var reopen: (UUID) -> Void
    var delete: (UUID) -> Void
}

/// Actions sur un membre.
struct MemberActions {
    var edit: (Member) -> Void
    var delete: (Member) -> Void
}

enum TeamDisplayMode: String, CaseIterable, Identifiable {
    case planning
    case queues

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planning: "Planning"
        case .queues: "Files"
        }
    }

    var systemImage: String {
        switch self {
        case .planning: "calendar"
        case .queues: "list.bullet.rectangle"
        }
    }
}

enum PlanningSpan: Int, CaseIterable, Identifiable {
    case oneWeek = 1
    case twoWeeks = 2
    case fourWeeks = 4
    case sixWeeks = 6

    var id: Int { rawValue }
    var dayCount: Int { rawValue * 7 }
    var title: String { rawValue == 1 ? "1 semaine" : "\(rawValue) semaines" }
}

/// Écran principal d'une équipe : planning ou files, avec l'inspecteur de tâche.
struct TeamView: View {
    let team: Team

    @Environment(OrbitStore.self) private var store

    @State private var mode: TeamDisplayMode = .planning
    @State private var span: PlanningSpan = .twoWeeks
    @State private var referenceDate = Date()
    @State private var selectedTaskID: UUID?
    @State private var isInspectorPresented = false

    @State private var newTask: TaskItem?
    @State private var taskToComplete: TaskItem?
    @State private var taskToDelete: TaskItem?
    @State private var memberDraft: Member?
    @State private var memberToDelete: Member?

    var body: some View {
        let members = store.members(in: team.id)
        content(members: members)
            .navigationTitle(team.name)
            .navigationSubtitle(subtitle(members: members))
            .toolbar { toolbar(members: members) }
            .inspector(isPresented: $isInspectorPresented) {
                TaskInspector(taskID: selectedTaskID, actions: actions)
                    .inspectorColumnWidth(min: 300, ideal: 350, max: 480)
            }
            .onChange(of: selectedTaskID) { _, taskID in
                if taskID != nil { isInspectorPresented = true }
            }
            .sheet(item: $newTask) { draft in
                NewTaskSheet(draft: draft, members: members) { task in
                    let created = store.addTask(task)
                    selectedTaskID = created.id
                }
            }
            .sheet(item: $taskToComplete) { task in
                CompleteTaskSheet(task: task) { actual, date in
                    store.completeTask(task.id, actualSpent: actual, at: date)
                }
            }
            .sheet(item: $memberDraft) { draft in
                MemberEditorSheet(member: draft, isNew: store.member(draft.id) == nil) { saved in
                    if store.member(saved.id) == nil {
                        store.addMember(name: saved.name, role: saved.role, teamID: team.id, colorIndex: saved.colorIndex)
                    } else {
                        store.updateMember(saved)
                    }
                }
            }
            .confirmationDialog(
                "Supprimer « \(taskToDelete?.title ?? "") » ?",
                isPresented: Binding(isPresenting: $taskToDelete),
                titleVisibility: .visible,
                presenting: taskToDelete
            ) { task in
                Button("Supprimer la tâche", role: .destructive) {
                    if selectedTaskID == task.id { selectedTaskID = nil }
                    store.deleteTask(task.id)
                }
            } message: { _ in
                Text("Cette action est définitive.")
            }
            .confirmationDialog(
                "Retirer \(memberToDelete?.name ?? "") de l'équipe ?",
                isPresented: Binding(isPresenting: $memberToDelete),
                titleVisibility: .visible,
                presenting: memberToDelete
            ) { member in
                Button("Retirer", role: .destructive) {
                    store.deleteMember(member.id)
                }
            } message: { _ in
                Text("Ses tâches deviendront non assignées. L'historique de chiffrage de cette personne sera perdu.")
            }
    }

    // MARK: Contenu

    @ViewBuilder
    private func content(members: [Member]) -> some View {
        if members.isEmpty {
            ContentUnavailableView {
                Label("Aucun membre", systemImage: "person.2.slash")
            } description: {
                Text("Ajoutez les développeurs de l'équipe pour planifier leurs tâches.")
            } actions: {
                Button("Ajouter un membre", action: addMember)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            switch mode {
            case .planning:
                PlanningView(
                    team: team,
                    members: members,
                    rangeStart: rangeStart,
                    dayCount: span.dayCount,
                    selection: $selectedTaskID,
                    actions: actions,
                    memberActions: memberActions,
                    showQueues: { mode = .queues }
                )
            case .queues:
                QueueView(
                    team: team,
                    members: members,
                    selection: $selectedTaskID,
                    actions: actions,
                    memberActions: memberActions
                )
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbar(members: [Member]) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Affichage", selection: $mode) {
                ForEach(TeamDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("Planning : calendrier de chacun · Files : ordre des tâches de chacun")
        }
        if mode == .planning {
            ToolbarItemGroup(placement: .navigation) {
                Button { shift(by: -1) } label: {
                    Label("Période précédente", systemImage: "chevron.left")
                }
                Button("Aujourd'hui") { referenceDate = Date() }
                Button { shift(by: 1) } label: {
                    Label("Période suivante", systemImage: "chevron.right")
                }
                Picker("Période", selection: $span) {
                    ForEach(PlanningSpan.allCases) { span in
                        Text(span.title).tag(span)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: addMember) {
                Label("Ajouter un membre", systemImage: "person.badge.plus")
            }
            .help("Ajouter un membre à l'équipe")
            Button {
                newTask = makeDraft(members: members)
            } label: {
                Label("Nouvelle tâche", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Nouvelle tâche (⌘N)")
            Button {
                isInspectorPresented.toggle()
            } label: {
                Label("Inspecteur", systemImage: "sidebar.trailing")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help("Afficher ou masquer l'inspecteur (⌥⌘I)")
        }
    }

    // MARK: Actions

    private var actions: TaskActions {
        TaskActions(
            select: { selectedTaskID = $0 },
            start: { store.startTask($0) },
            stop: { store.stopTask($0) },
            complete: { taskToComplete = store.task($0) },
            reopen: { store.reopenTask($0) },
            delete: { taskToDelete = store.task($0) }
        )
    }

    private var memberActions: MemberActions {
        MemberActions(
            edit: { memberDraft = $0 },
            delete: { memberToDelete = $0 }
        )
    }

    private func addMember() {
        memberDraft = Member(teamID: team.id, name: "", colorIndex: store.nextColorIndex(in: team.id))
    }

    private func makeDraft(members: [Member]) -> TaskItem {
        let assignee = store.task(selectedTaskID)?.assigneeID ?? members.first?.id
        return TaskItem(teamID: team.id, title: "", assigneeID: assignee, estimate: .day)
    }

    private func shift(by direction: Int) {
        referenceDate = store.workCalendar.addingDays(direction * span.dayCount, to: referenceDate)
    }

    /// Début de la période affichée : la semaine de la date de référence
    /// (une semaine plus tôt pour les longues périodes, pour garder un peu d'historique).
    private var rangeStart: Date {
        let calendar = store.workCalendar
        let weekStart = calendar.startOfWeek(containing: referenceDate)
        return span.rawValue >= 4 ? calendar.addingDays(-7, to: weekStart) : weekStart
    }

    private func subtitle(members: [Member]) -> String {
        let openCount = store.tasks(in: team.id).filter(\.isOpen).count
        return OrbitFormat.count(members.count, "membre", "membres")
            + " · " + OrbitFormat.count(openCount, "tâche ouverte", "tâches ouvertes")
    }
}
