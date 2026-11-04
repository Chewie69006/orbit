//
//  PlanningView.swift
//  Orbit
//

import Foundation
import SwiftUI

/// Calendrier de l'équipe : une rangée par membre, une colonne par jour.
/// Les tâches s'enchaînent dans l'ordre de la file de chacun, avec leur durée pondérée.
struct PlanningView: View {
    let team: Team
    let members: [Member]
    let rangeStart: Date
    let dayCount: Int
    @Binding var selection: UUID?
    let actions: TaskActions
    let memberActions: MemberActions
    let showQueues: () -> Void

    @Environment(OrbitStore.self) private var store

    static let nameColumnWidth: CGFloat = 220
    static let laneHeight: CGFloat = 30
    static let headerHeight: CGFloat = 46

    var body: some View {
        let now = Date()
        let schedule = store.schedule(for: team.id, now: now)
        let tasksByID = Dictionary(uniqueKeysWithValues: store.tasks(in: team.id).map { ($0.id, $0) })
        let unassignedCount = store.queue(teamID: team.id, assigneeID: nil).count

        GeometryReader { proxy in
            let geometry = TimelineGeometry(
                start: rangeStart,
                dayCount: dayCount,
                width: Double(max(proxy.size.width - Self.nameColumnWidth, 140)),
                workCalendar: schedule.workCalendar,
                anchor: schedule.anchor,
                today: now
            )
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    PlanningRangeTitle(geometry: geometry)
                        .frame(width: Self.nameColumnWidth, height: Self.headerHeight, alignment: .leading)
                    DayHeaderView(geometry: geometry)
                        .frame(width: CGFloat(geometry.totalWidth), height: Self.headerHeight, alignment: .leading)
                }
                Divider()
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(members) { member in
                            PlanningMemberRow(
                                member: member,
                                teamSchedule: schedule,
                                tasks: tasksByID,
                                geometry: geometry,
                                selection: $selection,
                                actions: actions,
                                memberActions: memberActions
                            )
                            Divider()
                        }
                    }
                }
                if unassignedCount > 0 {
                    Divider()
                    HStack {
                        Label(
                            OrbitFormat.count(unassignedCount, "tâche non assignée", "tâches non assignées"),
                            systemImage: "tray"
                        )
                        .foregroundStyle(.secondary)
                        Spacer()
                        Button("Voir les files", action: showQueues)
                            .buttonStyle(.link)
                    }
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

// MARK: - En-tête

/// Mois affichés, en haut de la colonne des noms.
struct PlanningRangeTitle: View {
    let geometry: TimelineGeometry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let first = geometry.days.first?.date, let last = geometry.days.last?.date {
                Text(title(first: first, last: last))
                    .font(.headline)
                Text("\(first, format: .dateTime.day().month(.abbreviated)) – \(last, format: .dateTime.day().month(.abbreviated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
    }

    private func title(first: Date, last: Date) -> String {
        let firstMonth = first.formatted(.dateTime.month(.wide))
        let lastMonth = last.formatted(.dateTime.month(.wide))
        let year = last.formatted(.dateTime.year())
        let text = firstMonth == lastMonth ? "\(firstMonth) \(year)" : "\(firstMonth) – \(lastMonth) \(year)"
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// Jours de la période : jour de la semaine et numéro.
struct DayHeaderView: View {
    let geometry: TimelineGeometry

    var body: some View {
        HStack(spacing: 0) {
            ForEach(geometry.days) { day in
                VStack(spacing: 1) {
                    if day.isWorkingDay {
                        Text(day.date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(day.date, format: .dateTime.day())
                        .font(.callout.weight(day.isToday ? .bold : .regular))
                        .foregroundStyle(dayColor(day))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: CGFloat(day.width), height: PlanningView.headerHeight)
                .background(day.isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                .help(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
            }
        }
    }

    private func dayColor(_ day: TimelineDay) -> Color {
        if day.isToday { return .accentColor }
        return day.isWorkingDay ? .primary : .secondary
    }
}

/// Fond d'une rangée : séparation des jours, week-ends grisés, aujourd'hui en surbrillance.
struct DayColumnsBackground: View {
    let geometry: TimelineGeometry

    var body: some View {
        HStack(spacing: 0) {
            ForEach(geometry.days) { day in
                Rectangle()
                    .fill(fill(for: day))
                    .frame(width: CGFloat(day.width))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 0.5)
                    }
            }
        }
    }

    private func fill(for day: TimelineDay) -> Color {
        if day.isToday { return Color.accentColor.opacity(0.07) }
        if !day.isWorkingDay { return Color.secondary.opacity(0.10) }
        return Color.clear
    }
}

// MARK: - Rangée d'un membre

struct PlanningMemberRow: View {
    let member: Member
    let teamSchedule: TeamSchedule
    let tasks: [UUID: TaskItem]
    let geometry: TimelineGeometry
    @Binding var selection: UUID?
    let actions: TaskActions
    let memberActions: MemberActions

    private struct Bar: Identifiable {
        let task: TaskItem
        let item: ScheduledTask
        let span: TimelineSpan
        var id: UUID { task.id }
    }

    var body: some View {
        let schedule = teamSchedule.members[member.id]
        let laneCount = schedule?.laneCount ?? 1
        let height = max(58, CGFloat(laneCount) * PlanningView.laneHeight + 10)

        HStack(spacing: 0) {
            PlanningMemberLabel(
                member: member,
                schedule: schedule,
                availability: teamSchedule.availabilityDate(for: member.id),
                memberActions: memberActions
            )
            .frame(width: PlanningView.nameColumnWidth, height: height, alignment: .leading)

            ZStack(alignment: .topLeading) {
                DayColumnsBackground(geometry: geometry)
                ForEach(bars(schedule)) { bar in
                    TaskBar(
                        task: bar.task,
                        item: bar.item,
                        color: member.color,
                        isSelected: selection == bar.task.id,
                        continuesBefore: bar.span.continuesBefore,
                        continuesAfter: bar.span.continuesAfter
                    )
                    .frame(width: CGFloat(max(bar.span.width - 2, 6)), height: PlanningView.laneHeight - 6)
                    .offset(x: CGFloat(bar.span.x + 1), y: 5 + CGFloat(bar.item.lane) * PlanningView.laneHeight)
                    .onTapGesture { selection = bar.task.id }
                    .contextMenu { TaskContextMenu(task: bar.task, actions: actions) }
                }
            }
            .frame(width: CGFloat(geometry.totalWidth), height: height, alignment: .topLeading)
            .clipped()
        }
    }

    private func bars(_ schedule: MemberSchedule?) -> [Bar] {
        (schedule?.items ?? []).compactMap { item in
            guard let task = tasks[item.taskID],
                  let span = geometry.span(start: item.start, end: item.end)
            else { return nil }
            return Bar(task: task, item: item, span: span)
        }
    }
}

/// Nom, coefficient et disponibilité d'un membre ; un clic ouvre son historique.
struct PlanningMemberLabel: View {
    let member: Member
    let schedule: MemberSchedule?
    let availability: Date?
    let memberActions: MemberActions

    @State private var showsStats = false

    var body: some View {
        HStack(spacing: 10) {
            MemberAvatar(member: member, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    FactorBadge(calibration: schedule?.calibration ?? .neutral)
                    availabilityText
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { showsStats = true }
        .popover(isPresented: $showsStats, arrowEdge: .trailing) {
            MemberStatsView(member: member)
        }
        .contextMenu {
            Button("Historique de chiffrage…", systemImage: "chart.xyaxis.line") { showsStats = true }
            Button("Modifier…", systemImage: "pencil") { memberActions.edit(member) }
            Divider()
            Button("Retirer de l'équipe…", systemImage: "person.badge.minus", role: .destructive) {
                memberActions.delete(member)
            }
        }
        .help("Cliquer pour voir l'historique de chiffrage de \(member.name)")
    }

    @ViewBuilder
    private var availabilityText: some View {
        if let schedule, schedule.availablePosition > 0, let availability {
            Text("libre le \(availability, format: .dateTime.day().month(.abbreviated))")
        } else {
            Text("disponible")
        }
    }
}

// MARK: - Barre de tâche

struct TaskBar: View {
    let task: TaskItem
    let item: ScheduledTask
    let color: Color
    let isSelected: Bool
    let continuesBefore: Bool
    let continuesAfter: Bool

    var body: some View {
        let radius: CGFloat = 6
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: continuesBefore ? 0 : radius,
            bottomLeadingRadius: continuesBefore ? 0 : radius,
            bottomTrailingRadius: continuesAfter ? 0 : radius,
            topTrailingRadius: continuesAfter ? 0 : radius,
            style: .continuous
        )
        shape
            .fill(fillColor)
            .overlay {
                shape.stroke(strokeColor, lineWidth: isSelected ? 2.5 : 1)
            }
            .overlay(alignment: .leading) {
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .imageScale(.small)
                    Text(task.title)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 6)
            }
            .clipped()
            .contentShape(shape)
            .help(helpText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(helpText)
            .accessibilityAddTraits(.isButton)
    }

    private var fillColor: Color {
        switch item.status {
        case .todo: color.opacity(0.22)
        case .inProgress: color.opacity(0.85)
        case .done: Color.secondary.opacity(0.18)
        }
    }

    private var strokeColor: Color {
        if isSelected { return .primary }
        if item.isOverdue { return .red }
        switch item.status {
        case .todo, .inProgress: return color
        case .done: return Color.secondary.opacity(0.35)
        }
    }

    private var textColor: Color {
        switch item.status {
        case .todo: .primary
        case .inProgress: .white
        case .done: .secondary
        }
    }

    private var iconName: String {
        if item.isOverdue { return "exclamationmark.triangle.fill" }
        switch item.status {
        case .todo: return task.notBefore == nil ? "circle" : "calendar.badge.clock"
        case .inProgress: return "play.fill"
        case .done: return "checkmark"
        }
    }

    private var helpText: String {
        var lines = [task.title]
        let planned = ManDays(eighths: item.duration)
        switch item.status {
        case .done:
            lines.append("Terminée · chiffrage \(task.effectiveEstimate.description) · temps passé \((task.actualSpent ?? planned).description)")
        case .todo, .inProgress:
            lines.append("\(task.status.label) · chiffrage \(task.effectiveEstimate.description) · planifié \(planned.description)")
        }
        if item.isOverdue {
            lines.append("En retard d'après le chiffrage pondéré")
        }
        if !task.subtasks.isEmpty {
            lines.append("Sous-tâches : \(task.completedSubtaskCount)/\(task.subtasks.count)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Menu contextuel

struct TaskContextMenu: View {
    let task: TaskItem
    let actions: TaskActions

    var body: some View {
        switch task.status {
        case .todo:
            Button("Démarrer", systemImage: "play") { actions.start(task.id) }
            Button("Terminer…", systemImage: "checkmark.circle") { actions.complete(task.id) }
        case .inProgress:
            Button("Terminer…", systemImage: "checkmark.circle") { actions.complete(task.id) }
            Button("Remettre à faire", systemImage: "pause") { actions.stop(task.id) }
        case .done:
            Button("Rouvrir", systemImage: "arrow.uturn.backward") { actions.reopen(task.id) }
        }
        Button("Afficher les détails", systemImage: "info.circle") { actions.select(task.id) }
        Divider()
        Button("Supprimer…", systemImage: "trash", role: .destructive) { actions.delete(task.id) }
    }
}
