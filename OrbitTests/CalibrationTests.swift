//
//  CalibrationTests.swift
//  OrbitTests
//

import Foundation
import Testing
@testable import Orbit

@MainActor
struct CalibrationTests {
    private let teamID = UUID()
    private let memberID = UUID()

    private func done(estimate: Int, actual: Int?, on day: Int, subtasks: [Int] = []) -> TaskItem {
        TaskItem(
            teamID: teamID,
            title: "Tâche \(day)",
            assigneeID: memberID,
            estimate: .e(estimate),
            subtasks: subtasks.map { Subtask(title: "s", estimate: .e($0)) },
            status: .done,
            completedAt: TestCalendar.date(2026, 10, day),
            actualSpent: actual.map { .e($0) }
        )
    }

    @Test func isNeutralWithoutHistory() {
        let calibration = Calibration.compute(from: [], smoothing: 0.3)
        #expect(calibration.factor == 1)
        #expect(calibration.sampleCount == 0)
        #expect(calibration.adjusted(.e(10)) == .e(10))
    }

    @Test func appliesExponentialMovingAverageFromANeutralStart() {
        // Ratio 2 avec α = 0,5 : 0,5 × 2 + 0,5 × 1 = 1,5.
        let calibration = Calibration.compute(from: [done(estimate: 8, actual: 16, on: 1)], smoothing: 0.5)
        #expect(abs(calibration.factor - 1.5) < 1e-9)
        #expect(calibration.points.first?.ratio == 2)
    }

    @Test func recentTasksWeighMoreThanOldOnes() {
        let slowThenAccurate = [done(estimate: 8, actual: 16, on: 1), done(estimate: 8, actual: 8, on: 2)]
        let accurateThenSlow = [done(estimate: 8, actual: 8, on: 1), done(estimate: 8, actual: 16, on: 2)]

        let a = Calibration.compute(from: slowThenAccurate, smoothing: 0.5)
        let b = Calibration.compute(from: accurateThenSlow, smoothing: 0.5)
        #expect(abs(a.factor - 1.25) < 1e-9) // 1 → 1,5 → 1,25
        #expect(abs(b.factor - 1.5) < 1e-9)  // 1 → 1 → 1,5
        #expect(b.factor > a.factor)
    }

    @Test func ordersSamplesByCompletionDateNotByArrayOrder() {
        let tasks = [done(estimate: 8, actual: 8, on: 9), done(estimate: 8, actual: 16, on: 3)]
        let calibration = Calibration.compute(from: tasks, smoothing: 0.5)
        #expect(calibration.points.map(\.ratio) == [2, 1])
        #expect(abs(calibration.factor - 1.25) < 1e-9)
    }

    @Test func historyTracksTheFactorAfterEachTask() {
        let tasks = (1...5).map { done(estimate: 8, actual: 12, on: $0) }
        let calibration = Calibration.compute(from: tasks, smoothing: 0.3)
        let factors = calibration.points.map(\.factor)
        #expect(factors == factors.sorted())
        #expect(factors.allSatisfy { $0 > 1 && $0 < 1.5 })
        #expect(calibration.factor == factors.last)
    }

    @Test func ignoresUnusableTasks() {
        var open = done(estimate: 8, actual: 16, on: 1)
        open.status = .inProgress
        let noActual = done(estimate: 8, actual: nil, on: 2)
        let zeroActual = done(estimate: 8, actual: 0, on: 3)
        let unestimated = done(estimate: 0, actual: 8, on: 4)
        let calibration = Calibration.compute(from: [open, noActual, zeroActual, unestimated], smoothing: 0.5)
        #expect(calibration.sampleCount == 0)
        #expect(calibration.factor == 1)
    }

    @Test func usesTheEffectiveEstimateIncludingSubtasks() {
        // Chiffrage 8, sous-tâches 8 + 8 = 16 → c'est 16 qui compte ; 16 passés → ratio 1.
        let task = done(estimate: 8, actual: 16, on: 1, subtasks: [8, 8])
        let calibration = Calibration.compute(from: [task], smoothing: 0.5)
        #expect(calibration.points.first?.estimate == .e(16))
        #expect(calibration.factor == 1)
    }

    @Test func humanReadableDescriptions() {
        #expect(OrbitFormat.biasDescription(.neutral) == "Pas encore d'historique")
        let slow = Calibration.compute(from: [done(estimate: 8, actual: 16, on: 1)], smoothing: 0.5)
        #expect(OrbitFormat.biasDescription(slow).hasPrefix("Prend 50"))
        #expect(OrbitFormat.biasDescription(slow).hasSuffix("de temps en plus"))
        #expect(OrbitFormat.deviation(ratio: 1) == "pile")
        #expect(OrbitFormat.deviation(ratio: 1.25).hasPrefix("+25"))
        #expect(OrbitFormat.deviation(ratio: 0.9).hasPrefix("−10"))
        #expect(OrbitFormat.factor(1.5).hasPrefix("×1"))
        #expect(OrbitFormat.count(1, "tâche", "tâches") == "1 tâche")
        #expect(OrbitFormat.count(3, "tâche", "tâches") == "3 tâches")
    }

    @Test func clampsTheSmoothingFactor() {
        let task = done(estimate: 8, actual: 16, on: 1)
        #expect(Calibration.compute(from: [task], smoothing: 5).factor == 2)
        #expect(Calibration.compute(from: [task], smoothing: -1).factor > 1)
    }
}
