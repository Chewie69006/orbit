//
//  ManDaysTests.swift
//  OrbitTests
//

import Foundation
import Testing
@testable import Orbit

@MainActor
struct ManDaysTests {
    @Test func storesEighthsAndNeverGoesNegative() {
        #expect(ManDays(eighths: 12).days == 1.5)
        #expect(ManDays(eighths: -3) == .zero)
        #expect(ManDays(days: 1.3).eighths == 10) // 10,4 → 10
        #expect(ManDays(days: .nan) == .zero)
    }

    @Test(arguments: [
        (0, "0 j"), (1, "⅛ j"), (3, "⅜ j"), (4, "½ j"), (8, "1 j"), (12, "1½ j"), (19, "2⅜ j"), (24, "3 j"),
    ])
    func formatsWithFractionGlyphs(eighths: Int, expected: String) {
        #expect(ManDays(eighths: eighths).description == expected)
    }

    @Test(arguments: [
        ("2", 16), ("1,5", 12), ("1.5 j", 12), ("1 3/8", 11), ("3/8", 3), ("2⅜ j", 19), ("⅜", 3),
        ("6h", 6), ("12 heures", 12), ("0,3", 2), ("1 jour", 8), ("  4 jours ", 32), ("0", 0),
    ])
    func parsesUserInput(input: String, eighths: Int) {
        #expect(ManDays.parse(input)?.eighths == eighths)
    }

    @Test(arguments: ["", "abc", "1/0", "-2", "2 semaines", "1 2 3", "1//2"])
    func rejectsInvalidInput(input: String) {
        #expect(ManDays.parse(input) == nil)
    }

    @Test func descriptionRoundTripsThroughParse() {
        for eighths in 0...40 {
            let value = ManDays(eighths: eighths)
            #expect(ManDays.parse(value.description) == value)
        }
    }

    @Test func scalingRoundsToNearestEighthWithAMinimumOfOne() {
        #expect(ManDays.day.scaled(by: 1.18) == .e(9))   // 9,44
        #expect(ManDays.day.scaled(by: 1.2) == .e(10))   // 9,6
        #expect(ManDays.e(1).scaled(by: 0.2) == .e(1))
        #expect(ManDays.zero.scaled(by: 3) == .zero)
        #expect(ManDays.day.scaled(by: .infinity) == .day)
        #expect(ManDays.day.scaled(by: 0) == .day)
    }

    @Test func codableAsPlainInteger() throws {
        let data = try JSONEncoder().encode([ManDays.e(11)])
        #expect(String(decoding: data, as: UTF8.self) == "[11]")
        #expect(try JSONDecoder().decode([ManDays].self, from: data) == [.e(11)])
    }
}

@MainActor
struct TaskEstimateTests {
    private let teamID = UUID()

    @Test func ownEstimateWinsWhenSubtasksAreSmaller() {
        let task = TaskItem(teamID: teamID, title: "T", estimate: .e(24), subtasks: [
            Subtask(title: "a", estimate: .e(8)),
            Subtask(title: "b", estimate: .e(8)),
        ])
        #expect(task.subtasksEstimate == .e(16))
        #expect(task.effectiveEstimate == .e(24))
        #expect(!task.isEstimateDrivenBySubtasks)
    }

    @Test func subtasksSumWinsWhenGreater() {
        let task = TaskItem(teamID: teamID, title: "T", estimate: .e(16), subtasks: [
            Subtask(title: "a", estimate: .e(8)),
            Subtask(title: "b", estimate: .e(12)),
        ])
        #expect(task.effectiveEstimate == .e(20))
        #expect(task.isEstimateDrivenBySubtasks)
    }

    @Test func withoutSubtasksTheOwnEstimateIsUsed() {
        let task = TaskItem(teamID: teamID, title: "T", estimate: .e(5))
        #expect(task.effectiveEstimate == .e(5))
    }
}
