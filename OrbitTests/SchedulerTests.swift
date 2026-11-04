//
//  SchedulerTests.swift
//  OrbitTests
//

import Foundation
import Testing
@testable import Orbit

@MainActor
struct SchedulerTests {
    private let teamID = UUID()
    private let memberID = UUID()
    /// Mercredi 4 novembre 2026, 10 h (index 0).
    private let now = TestCalendar.date(2026, 11, 4, hour: 10)

    private func scheduler(applyCalibration: Bool = true, smoothing: Double = 1) -> Scheduler {
        Scheduler(
            settings: AppSettings(smoothing: smoothing, applyCalibration: applyCalibration),
            calendar: TestCalendar.calendar
        )
    }

    private func task(
        _ title: String, estimate: Int, rank: Int = 0, status: TaskStatus = .todo,
        startedAt: Date? = nil, completedAt: Date? = nil, actual: Int? = nil, notBefore: Date? = nil
    ) -> TaskItem {
        TaskItem(
            teamID: teamID, title: title, assigneeID: memberID, estimate: .e(estimate),
            status: status, rank: rank, notBefore: notBefore, startedAt: startedAt,
            completedAt: completedAt, actualSpent: actual.map { .e($0) }
        )
    }

    private func schedule(_ tasks: [TaskItem], scheduler: Scheduler? = nil) -> (TeamSchedule, MemberSchedule) {
        let team = (scheduler ?? self.scheduler()).schedule(memberIDs: [memberID], tasks: tasks, now: now)
        return (team, team.members[memberID]!)
    }

    @Test func chainsOpenTasksInQueueOrderFromToday() {
        let a = task("A", estimate: 16, rank: 1)
        let b = task("B", estimate: 12, rank: 0)
        let (team, member) = schedule([a, b])

        #expect(member.item(for: b.id)?.start == 0)
        #expect(member.item(for: b.id)?.end == 12)
        #expect(member.item(for: a.id)?.start == 12)
        #expect(member.item(for: a.id)?.end == 28)
        #expect(member.laneCount == 1)
        #expect(member.availablePosition == 28)

        // A : du jeudi 5 (après-midi) au lundi 9 (week-end sauté).
        let itemA = member.item(for: a.id)!
        #expect(team.startDate(of: itemA) == TestCalendar.day(2026, 11, 5))
        #expect(team.endDate(of: itemA) == TestCalendar.day(2026, 11, 9))
        #expect(team.availabilityDate(for: memberID) == TestCalendar.day(2026, 11, 9))
    }

    @Test func appliesTheMemberCalibration() {
        // Une tâche passée en 12 au lieu de 8 → ratio 1,5 ; avec α = 1, le coefficient vaut 1,5.
        let history = task("H", estimate: 8, status: .done, completedAt: TestCalendar.date(2026, 11, 2), actual: 12)
        let next = task("N", estimate: 8)

        let (_, calibrated) = schedule([history, next])
        #expect(calibrated.appliedFactor == 1.5)
        #expect(calibrated.item(for: next.id)?.duration == 12)

        let (_, raw) = schedule([history, next], scheduler: scheduler(applyCalibration: false))
        #expect(raw.appliedFactor == 1)
        #expect(raw.calibration.factor == 1.5)
        #expect(raw.item(for: next.id)?.duration == 8)
    }

    @Test func notBeforeDelaysTheStart() {
        let first = task("A", estimate: 4, rank: 0)
        let later = task("B", estimate: 8, rank: 1, notBefore: TestCalendar.date(2026, 11, 9, hour: 0))
        let (_, member) = schedule([first, later])
        #expect(member.item(for: later.id)?.start == 24) // lundi 9 = index 3
        #expect(member.availablePosition == 32)
    }

    @Test func inProgressTaskStartsWhenItWasStarted() {
        let started = task("En cours", estimate: 24, rank: 0, status: .inProgress,
                           startedAt: TestCalendar.date(2026, 11, 2, hour: 9))
        let next = task("Suivante", estimate: 8, rank: 1)
        let (_, member) = schedule([started, next])
        let item = member.item(for: started.id)!
        #expect(item.start == -16)
        #expect(item.end == 8)
        #expect(!item.isOverdue)
        #expect(member.item(for: next.id)?.start == 8)
    }

    @Test func lateInProgressTaskIsFlaggedAndExtendedToToday() {
        // Commencée le mercredi 28 octobre pour 2 jours : elle aurait dû finir le jeudi 29.
        let late = task("En retard", estimate: 16, status: .inProgress,
                        startedAt: TestCalendar.date(2026, 10, 28, hour: 9))
        let next = task("Suivante", estimate: 8, rank: 1)
        let (_, member) = schedule([late, next])
        let item = member.item(for: late.id)!
        #expect(item.isOverdue)
        #expect(item.start == -40)
        #expect(item.end == 8)
        #expect(member.item(for: next.id)?.start == 8)
    }

    @Test func doneTasksEndOnTheirCompletionDay() {
        // Terminée mardi 3 : elle se termine à la position 0 et dure le temps passé.
        let tuesday = task("Mardi", estimate: 8, status: .done, completedAt: TestCalendar.date(2026, 11, 3, hour: 17), actual: 12)
        // Terminée un dimanche : rattachée au vendredi précédent (index -3).
        let sunday = task("Dimanche", estimate: 8, status: .done, completedAt: TestCalendar.date(2026, 11, 1, hour: 11), actual: 8)
        let (_, member) = schedule([tuesday, sunday])
        #expect(member.item(for: tuesday.id)?.start == -12)
        #expect(member.item(for: tuesday.id)?.end == 0)
        #expect(member.item(for: sunday.id)?.start == -24)
        #expect(member.item(for: sunday.id)?.end == -16)
        #expect(member.availablePosition == 0)
    }

    @Test func overlappingTasksGetSeparateLanes() {
        let done = task("Finie", estimate: 8, status: .done, completedAt: TestCalendar.date(2026, 11, 3, hour: 17), actual: 12)
        let started = task("En cours", estimate: 24, status: .inProgress, startedAt: TestCalendar.date(2026, 11, 2, hour: 9))
        let (_, member) = schedule([done, started])
        #expect(member.laneCount == 2)
        #expect(Set(member.items.map(\.lane)) == [0, 1])
    }

    @Test func anchorMovesToMondayDuringTheWeekend() {
        let saturday = TestCalendar.date(2026, 11, 7, hour: 10)
        let s = scheduler().schedule(memberIDs: [memberID], tasks: [task("A", estimate: 8)], now: saturday)
        #expect(s.anchor == TestCalendar.day(2026, 11, 9))
    }

    @Test func greedyLaneAssignment() {
        var items = [
            ScheduledTask(taskID: UUID(), memberID: memberID, status: .todo, start: 0, end: 8, isOverdue: false),
            ScheduledTask(taskID: UUID(), memberID: memberID, status: .todo, start: 4, end: 12, isOverdue: false),
            ScheduledTask(taskID: UUID(), memberID: memberID, status: .todo, start: 8, end: 16, isOverdue: false),
            ScheduledTask(taskID: UUID(), memberID: memberID, status: .todo, start: 12, end: 12, isOverdue: false),
        ]
        let lanes = Scheduler.assignLanes(&items)
        #expect(items.map(\.lane) == [0, 1, 0, 1])
        #expect(lanes == 2)
    }

    @Test func ignoresTasksOfOtherPeopleAndUnassignedTasks() {
        var other = task("Autre", estimate: 8)
        other.assigneeID = UUID()
        var unassigned = task("Personne", estimate: 8)
        unassigned.assigneeID = nil
        let (_, member) = schedule([other, unassigned])
        #expect(member.items.isEmpty)
        #expect(member.laneCount == 1)
    }
}
