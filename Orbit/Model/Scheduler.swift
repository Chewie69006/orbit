//
//  Scheduler.swift
//  Orbit
//

import Foundation

/// Une tâche placée dans le planning d'une personne.
///
/// `start` et `end` sont des positions en huitièmes de journée relatives au jour ouvré
/// d'ancrage (voir ``PlanningPosition``) ; `end` est exclusif.
struct ScheduledTask: Identifiable, Hashable {
    let taskID: UUID
    let memberID: UUID
    let status: TaskStatus
    let start: Int
    let end: Int
    /// Tâche en cours qui aurait déjà dû être terminée d'après son chiffrage pondéré.
    let isOverdue: Bool
    /// Ligne d'affichage dans la rangée de la personne (0 = première ligne).
    var lane: Int = 0

    var id: UUID { taskID }
    var duration: Int { end - start }
}

/// Le planning d'une personne.
struct MemberSchedule: Hashable {
    let memberID: UUID
    let calibration: Calibration
    /// Coefficient réellement appliqué (1 si la pondération est désactivée).
    let appliedFactor: Double
    let items: [ScheduledTask]
    let laneCount: Int
    /// Première position libre après les tâches ouvertes.
    let availablePosition: Int

    func item(for taskID: UUID) -> ScheduledTask? {
        items.first { $0.taskID == taskID }
    }
}

/// Le planning d'une équipe, avec de quoi convertir les positions en dates.
struct TeamSchedule {
    let workCalendar: WorkCalendar
    /// Jour ouvré d'index 0 (aujourd'hui, ou le prochain jour ouvré).
    let anchor: Date
    let members: [UUID: MemberSchedule]

    static func empty(workCalendar: WorkCalendar, now: Date) -> TeamSchedule {
        TeamSchedule(workCalendar: workCalendar, anchor: workCalendar.nextWorkingDay(onOrAfter: now), members: [:])
    }

    func item(for taskID: UUID) -> ScheduledTask? {
        for schedule in members.values {
            if let item = schedule.item(for: taskID) { return item }
        }
        return nil
    }

    /// Premier jour touché par la tâche.
    func startDate(of item: ScheduledTask) -> Date {
        workCalendar.workingDay(at: PlanningPosition.dayIndex(startingAt: item.start), from: anchor)
    }

    /// Dernier jour touché par la tâche.
    func endDate(of item: ScheduledTask) -> Date {
        let end = max(item.end, item.start + 1)
        return workCalendar.workingDay(at: PlanningPosition.dayIndex(endingAt: end), from: anchor)
    }

    /// Jour à partir duquel la personne n'a plus de tâche planifiée.
    func availabilityDate(for memberID: UUID) -> Date? {
        guard let schedule = members[memberID] else { return nil }
        return workCalendar.workingDay(
            at: PlanningPosition.dayIndex(startingAt: schedule.availablePosition),
            from: anchor
        )
    }
}

/// Place les tâches de chaque personne dans le temps.
///
/// Règles :
/// - les tâches terminées sont placées pour se terminer le jour où elles l'ont été,
///   avec une durée égale au temps passé ;
/// - les tâches ouvertes sont enchaînées dans l'ordre de la file (`rank`) à partir d'aujourd'hui,
///   avec une durée égale au chiffrage retenu multiplié par le coefficient de la personne ;
/// - une tâche en cours démarre le jour où elle a été commencée ; si elle aurait déjà dû être
///   terminée, elle est marquée en retard et prolongée jusqu'à la fin de la journée ;
/// - une date « pas avant le » repousse le début de la tâche.
struct Scheduler {
    let workCalendar: WorkCalendar
    let smoothing: Double
    let applyCalibration: Bool

    init(settings: AppSettings, calendar: Calendar = .current) {
        self.workCalendar = WorkCalendar(workingDays: settings.workingDays, calendar: calendar)
        self.smoothing = settings.smoothing
        self.applyCalibration = settings.applyCalibration
    }

    /// Planifie toutes les personnes `memberIDs` à partir des tâches fournies.
    func schedule(memberIDs: [UUID], tasks: [TaskItem], now: Date) -> TeamSchedule {
        let anchor = workCalendar.nextWorkingDay(onOrAfter: now)
        let tasksByMember = Dictionary(grouping: tasks.filter { $0.assigneeID != nil }, by: { $0.assigneeID! })
        var result: [UUID: MemberSchedule] = [:]
        for memberID in memberIDs {
            result[memberID] = schedule(memberID: memberID, tasks: tasksByMember[memberID] ?? [], anchor: anchor)
        }
        return TeamSchedule(workCalendar: workCalendar, anchor: anchor, members: result)
    }

    /// Planifie une personne. `tasks` doit contenir uniquement ses tâches.
    func schedule(memberID: UUID, tasks: [TaskItem], anchor: Date) -> MemberSchedule {
        let calibration = Calibration.compute(from: tasks, smoothing: smoothing)
        let factor = applyCalibration ? calibration.factor : 1
        let eighthsPerDay = PlanningPosition.eighthsPerDay
        var items: [ScheduledTask] = []

        // Historique : tâches terminées.
        for task in tasks where task.status == .done {
            guard let completedAt = task.completedAt else { continue }
            let lastDay = workCalendar.previousWorkingDay(onOrBefore: completedAt)
            let end = (workCalendar.workingDayIndex(of: lastDay, from: anchor) + 1) * eighthsPerDay
            let duration = (task.actualSpent ?? task.effectiveEstimate).eighths
            items.append(
                ScheduledTask(taskID: task.id, memberID: memberID, status: .done,
                              start: end - duration, end: end, isOverdue: false)
            )
        }

        // File : tâches ouvertes, dans l'ordre.
        let openTasks = tasks
            .filter(\.isOpen)
            .sorted { ($0.rank, $0.createdAt) < ($1.rank, $1.createdAt) }
        var cursor = 0
        for task in openTasks {
            let duration = task.effectiveEstimate.scaled(by: factor).eighths
            if task.status == .inProgress, let startedAt = task.startedAt {
                let startedIndex = workCalendar.workingDayIndex(of: startedAt, from: anchor)
                let start = min(startedIndex * eighthsPerDay, cursor)
                var end = start + duration
                let isOverdue = duration > 0 && end <= 0
                if isOverdue {
                    // Aurait dû être terminée avant aujourd'hui : on suppose qu'elle se termine aujourd'hui.
                    end = eighthsPerDay
                }
                items.append(
                    ScheduledTask(taskID: task.id, memberID: memberID, status: task.status,
                                  start: start, end: end, isOverdue: isOverdue)
                )
                cursor = max(cursor, end)
            } else {
                var start = cursor
                if let notBefore = task.notBefore {
                    start = max(start, workCalendar.workingDayIndex(of: notBefore, from: anchor) * eighthsPerDay)
                }
                let end = start + duration
                items.append(
                    ScheduledTask(taskID: task.id, memberID: memberID, status: task.status,
                                  start: start, end: end, isOverdue: false)
                )
                cursor = max(cursor, end)
            }
        }

        let laneCount = Self.assignLanes(&items)
        return MemberSchedule(
            memberID: memberID,
            calibration: calibration,
            appliedFactor: factor,
            items: items,
            laneCount: laneCount,
            availablePosition: cursor
        )
    }

    /// Répartit les tâches qui se chevauchent sur plusieurs lignes (algorithme glouton).
    /// Renvoie le nombre de lignes utilisées (au moins 1).
    static func assignLanes(_ items: inout [ScheduledTask]) -> Int {
        let order = items.indices.sorted {
            (items[$0].start, items[$0].end) < (items[$1].start, items[$1].end)
        }
        var laneEnds: [Int] = []
        for index in order {
            let item = items[index]
            if let lane = laneEnds.firstIndex(where: { $0 <= item.start }) {
                items[index].lane = lane
                laneEnds[lane] = max(item.end, item.start + 1)
            } else {
                items[index].lane = laneEnds.count
                laneEnds.append(max(item.end, item.start + 1))
            }
        }
        return max(1, laneEnds.count)
    }
}
