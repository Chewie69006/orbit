//
//  QueueView.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Les files de l'équipe : les tâches ouvertes de chacun, dans l'ordre où elles seront faites.
/// On les réordonne par glisser-déposer ; le planning suit cet ordre.
struct QueueView: View {
    let team: Team
    let members: [Member]
    @Binding var selection: UUID?
    let actions: TaskActions
    let memberActions: MemberActions

    @Environment(OrbitStore.self) private var store

    var body: some View {
        let schedule = store.schedule(for: team.id)
        let unassigned = store.queue(teamID: team.id, assigneeID: nil)
        let completed = Array(store.completedTasks(in: team.id).prefix(30))

        List(selection: $selection) {
            ForEach(members) { member in
                let queue = store.queue(teamID: team.id, assigneeID: member.id)
                Section {
                    if queue.isEmpty {
                        Text("Aucune tâche en attente")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(queue) { task in
                        QueueTaskRow(task: task, item: schedule.item(for: task.id), schedule: schedule)
                            .tag(task.id)
                            .contextMenu { TaskContextMenu(task: task, actions: actions) }
                    }
                    .onMove { source, destination in
                        store.moveQueuedTasks(teamID: team.id, assigneeID: member.id, fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    QueueSectionHeader(
                        member: member,
                        memberSchedule: schedule.members[member.id],
                        availability: schedule.availabilityDate(for: member.id),
                        memberActions: memberActions
                    )
                }
            }

            if !unassigned.isEmpty {
                Section {
                    ForEach(unassigned) { task in
                        QueueTaskRow(task: task, item: nil, schedule: schedule)
                            .tag(task.id)
                            .contextMenu { TaskContextMenu(task: task, actions: actions) }
                    }
                    .onMove { source, destination in
                        store.moveQueuedTasks(teamID: team.id, assigneeID: nil, fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Label("Non assignées", systemImage: "tray")
                }
            }

            if !completed.isEmpty {
                Section {
                    ForEach(completed) { task in
                        CompletedTaskRow(task: task, member: store.member(task.assigneeID))
                            .tag(task.id)
                            .contextMenu { TaskContextMenu(task: task, actions: actions) }
                    }
                } header: {
                    Label("Terminées récemment", systemImage: "checkmark.circle")
                }
            }
        }
        .listStyle(.inset)
        .onDeleteCommand {
            if let selection { actions.delete(selection) }
        }
    }
}

struct QueueSectionHeader: View {
    let member: Member
    let memberSchedule: MemberSchedule?
    let availability: Date?
    let memberActions: MemberActions

    var body: some View {
        HStack(spacing: 8) {
            MemberAvatar(member: member, size: 20)
            Text(member.name)
                .font(.headline)
            if !member.role.isEmpty {
                Text(member.role)
                    .foregroundStyle(.secondary)
            }
            FactorBadge(calibration: memberSchedule?.calibration ?? .neutral)
                .font(.caption)
            Spacer()
            if let memberSchedule {
                Text("Charge : \(load(memberSchedule).description)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if memberSchedule.availablePosition > 0, let availability {
                    Text("· libre le \(availability, format: .dateTime.day().month(.abbreviated))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Modifier…", systemImage: "pencil") { memberActions.edit(member) }
            Button("Retirer de l'équipe…", systemImage: "person.badge.minus", role: .destructive) {
                memberActions.delete(member)
            }
        }
    }

    /// Somme des durées planifiées (pondérées) des tâches ouvertes.
    private func load(_ schedule: MemberSchedule) -> ManDays {
        ManDays(eighths: schedule.items.filter { $0.status != .done }.map(\.duration).reduce(0, +))
    }
}

struct QueueTaskRow: View {
    let task: TaskItem
    let item: ScheduledTask?
    let schedule: TeamSchedule

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item?.isOverdue == true ? "exclamationmark.triangle.fill" : task.status.systemImage)
                .foregroundStyle(statusColor)
                .frame(width: 18)
                .help(item?.isOverdue == true ? "En retard d'après le chiffrage pondéré" : task.status.label)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    if let item {
                        Text("\(schedule.startDate(of: item), format: .dateTime.day().month(.abbreviated)) → \(schedule.endDate(of: item), format: .dateTime.day().month(.abbreviated))")
                    }
                    if !task.subtasks.isEmpty {
                        Label("\(task.completedSubtaskCount)/\(task.subtasks.count)", systemImage: "checklist")
                    }
                    if let notBefore = task.notBefore {
                        Label("pas avant le \(notBefore, format: .dateTime.day().month(.abbreviated))", systemImage: "calendar.badge.clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            EstimateLabel(estimate: task.effectiveEstimate, planned: item.map { ManDays(eighths: $0.duration) })
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        if item?.isOverdue == true { return .red }
        switch task.status {
        case .todo: return .secondary
        case .inProgress: return .accentColor
        case .done: return .green
        }
    }
}

struct CompletedTaskRow: View {
    let task: TaskItem
    let member: Member?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 18)
            if let member {
                MemberAvatar(member: member, size: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(1)
                if let completedAt = task.completedAt {
                    Text("Terminée le \(completedAt, format: .dateTime.day().month(.abbreviated))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actual = task.actualSpent {
                HStack(spacing: 4) {
                    Text(task.effectiveEstimate.description)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    Text(actual.description)
                        .fontWeight(.semibold)
                    if !task.effectiveEstimate.isZero {
                        Text(OrbitFormat.deviation(ratio: actual.days / task.effectiveEstimate.days))
                            .font(.caption)
                            .foregroundStyle(actual > task.effectiveEstimate ? Color.orange : Color.blue)
                    }
                }
                .monospacedDigit()
                .help("Chiffrage → temps réellement passé")
            }
        }
        .padding(.vertical, 2)
    }
}
