//
//  OrbitStoreTests.swift
//  OrbitTests
//

import Foundation
import Testing
@testable import Orbit

@MainActor
struct OrbitStoreTests {
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("orbit-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("orbit.json")
    }

    private func makeTeam(_ store: OrbitStore) -> (Team, Member, Member) {
        let team = store.addTeam(name: "  Équipe  ")
        let ada = store.addMember(name: "Ada Lovelace", role: "Back", teamID: team.id)
        let alan = store.addMember(name: "Alan Turing", teamID: team.id)
        return (team, ada, alan)
    }

    // MARK: Persistance

    @Test func persistsEveryChangeAndReloads() throws {
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = OrbitStore(fileURL: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        let (team, ada, _) = makeTeam(store)
        store.addTask(TaskItem(teamID: team.id, title: "API", assigneeID: ada.id, estimate: .e(12)))
        store.settings.workingDays = [.monday, .tuesday, .wednesday, .thursday]
        store.settings.smoothing = 0.5
        #expect(FileManager.default.fileExists(atPath: url.path))

        let reloaded = OrbitStore(fileURL: url)
        #expect(reloaded.teams.map(\.name) == ["Équipe"])
        #expect(reloaded.members.map(\.name) == ["Ada Lovelace", "Alan Turing"])
        #expect(reloaded.tasks.map(\.title) == ["API"])
        #expect(reloaded.tasks.first?.estimate == .e(12))
        #expect(reloaded.settings.workingDays == [.monday, .tuesday, .wednesday, .thursday])
        #expect(reloaded.settings.smoothing == 0.5)
        #expect(reloaded.loadIssue == nil)
        #expect(reloaded.saveError == nil)
    }

    @Test func unreadableFileIsSetAsideAndNeverOverwritten() throws {
        let url = temporaryFileURL()
        let folder = url.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("pas du json".utf8).write(to: url)

        let store = OrbitStore(fileURL: url)
        #expect(store.teams.isEmpty)
        #expect(store.loadIssue != nil)

        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        let backup = try #require(files.first { $0.hasPrefix("orbit-illisible-") })
        #expect(try String(contentsOf: folder.appendingPathComponent(backup), encoding: .utf8) == "pas du json")
    }

    @Test func toleratesMissingFieldsFromOlderVersions() throws {
        let teamID = UUID()
        let json = """
        {"teams":[{"id":"\(teamID)","name":"Ancienne"}],
         "tasks":[{"id":"\(UUID())","teamID":"\(teamID)","title":"Vieille tâche","estimate":6}]}
        """
        let data = try OrbitData.makeDecoder().decode(OrbitData.self, from: Data(json.utf8))
        #expect(data.teams.first?.name == "Ancienne")
        #expect(data.tasks.first?.status == .todo)
        #expect(data.tasks.first?.estimate == .e(6))
        #expect(data.settings == AppSettings())
    }

    // MARK: Files de tâches

    @Test func newTasksGoToTheEndOfTheAssigneeQueue() {
        let store = OrbitStore(data: OrbitData())
        let (team, ada, alan) = makeTeam(store)
        let a = store.addTask(TaskItem(teamID: team.id, title: "A", assigneeID: ada.id, estimate: .e(8)))
        let b = store.addTask(TaskItem(teamID: team.id, title: "B", assigneeID: ada.id, estimate: .e(8)))
        let c = store.addTask(TaskItem(teamID: team.id, title: "C", assigneeID: alan.id, estimate: .e(8)))
        #expect(store.queue(teamID: team.id, assigneeID: ada.id).map(\.id) == [a.id, b.id])
        #expect(store.queue(teamID: team.id, assigneeID: alan.id).map(\.id) == [c.id])
        #expect(store.addTask(TaskItem(teamID: team.id, title: "   ", estimate: .e(1))).title == "Nouvelle tâche")
    }

    @Test func reassigningMovesTheTaskToTheEndOfTheNewQueue() {
        let store = OrbitStore(data: OrbitData())
        let (team, ada, alan) = makeTeam(store)
        let a = store.addTask(TaskItem(teamID: team.id, title: "A", assigneeID: ada.id, estimate: .e(8)))
        let c = store.addTask(TaskItem(teamID: team.id, title: "C", assigneeID: alan.id, estimate: .e(8)))
        var moved = a
        moved.assigneeID = alan.id
        store.updateTask(moved)
        #expect(store.queue(teamID: team.id, assigneeID: alan.id).map(\.id) == [c.id, a.id])
        #expect(store.queue(teamID: team.id, assigneeID: ada.id).isEmpty)
    }

    @Test func reorderingFollowsListMoveConventions() {
        #expect(OrbitStore.reordered(["a", "b", "c", "d"], fromOffsets: [0], toOffset: 3) == ["b", "c", "a", "d"])
        #expect(OrbitStore.reordered(["a", "b", "c", "d"], fromOffsets: [3], toOffset: 0) == ["d", "a", "b", "c"])
        #expect(OrbitStore.reordered(["a", "b", "c", "d"], fromOffsets: [0, 2], toOffset: 4) == ["b", "d", "a", "c"])
        #expect(OrbitStore.reordered(["a", "b"], fromOffsets: [7], toOffset: 0) == ["a", "b"])

        let store = OrbitStore(data: OrbitData())
        let (team, ada, _) = makeTeam(store)
        let ids = (0..<3).map {
            store.addTask(TaskItem(teamID: team.id, title: "T\($0)", assigneeID: ada.id, estimate: .e(8))).id
        }
        store.moveQueuedTasks(teamID: team.id, assigneeID: ada.id, fromOffsets: [2], toOffset: 0)
        #expect(store.queue(teamID: team.id, assigneeID: ada.id).map(\.id) == [ids[2], ids[0], ids[1]])
    }

    // MARK: Cycle de vie

    @Test func startingATaskMovesItAfterTheTasksAlreadyInProgress() {
        let store = OrbitStore(data: OrbitData())
        let (team, ada, _) = makeTeam(store)
        let ids = (0..<4).map {
            store.addTask(TaskItem(teamID: team.id, title: "T\($0)", assigneeID: ada.id, estimate: .e(8))).id
        }
        let monday = TestCalendar.date(2026, 11, 2)
        store.startTask(ids[2], at: monday)
        store.startTask(ids[3], at: monday)
        #expect(store.queue(teamID: team.id, assigneeID: ada.id).map(\.id) == [ids[2], ids[3], ids[0], ids[1]])
        #expect(store.task(ids[2])?.status == .inProgress)
        #expect(store.task(ids[2])?.startedAt == monday)

        store.stopTask(ids[2])
        #expect(store.task(ids[2])?.status == .todo)
        #expect(store.task(ids[2])?.startedAt == nil)
    }

    @Test func completingRecordsTimeSpentAndUpdatesTheCalibration() {
        let store = OrbitStore(data: OrbitData())
        store.settings.smoothing = 0.5
        let (team, ada, _) = makeTeam(store)
        let task = store.addTask(TaskItem(
            teamID: team.id, title: "A", assigneeID: ada.id, estimate: .e(8),
            subtasks: [Subtask(title: "s", estimate: .e(4))]
        ))

        let preview = store.calibrationPreview(completing: task, actualSpent: .e(16), at: Date())
        #expect(preview?.factor == 1.5)
        #expect(store.calibration(for: ada.id).factor == 1)

        store.completeTask(task.id, actualSpent: .e(16), at: TestCalendar.date(2026, 11, 3))
        let done = store.task(task.id)
        #expect(done?.status == .done)
        #expect(done?.actualSpent == .e(16))
        #expect(done?.subtasks.allSatisfy(\.isDone) == true)
        #expect(store.calibration(for: ada.id).factor == 1.5)
        #expect(store.queue(teamID: team.id, assigneeID: ada.id).isEmpty)

        store.reopenTask(task.id)
        #expect(store.task(task.id)?.status == .inProgress)
        #expect(store.task(task.id)?.actualSpent == nil)
        #expect(store.calibration(for: ada.id).factor == 1)
    }

    @Test func deletingAMemberUnassignsTheirTasks() {
        let store = OrbitStore(data: OrbitData())
        let (team, ada, _) = makeTeam(store)
        let task = store.addTask(TaskItem(teamID: team.id, title: "A", assigneeID: ada.id, estimate: .e(8)))
        store.deleteMember(ada.id)
        #expect(store.member(ada.id) == nil)
        #expect(store.task(task.id)?.assigneeID == nil)
        #expect(store.queue(teamID: team.id, assigneeID: nil).map(\.id) == [task.id])
    }

    @Test func deletingATeamDeletesItsMembersAndTasks() {
        let store = OrbitStore(data: OrbitData())
        let (team, ada, _) = makeTeam(store)
        let other = store.addTeam(name: "Autre")
        store.addMember(name: "Grace", teamID: other.id)
        store.addTask(TaskItem(teamID: team.id, title: "A", assigneeID: ada.id, estimate: .e(8)))
        store.deleteTeam(team.id)
        #expect(store.teams.map(\.id) == [other.id])
        #expect(store.members.map(\.name) == ["Grace"])
        #expect(store.tasks.isEmpty)
    }

    @Test func membersGetDistinctColors() {
        let store = OrbitStore(data: OrbitData())
        let team = store.addTeam(name: "T")
        let colors = (0..<OrbitStore.paletteSize).map { store.addMember(name: "M\($0)", teamID: team.id).colorIndex }
        #expect(Set(colors).count == OrbitStore.paletteSize)
        #expect(Member(teamID: team.id, name: "Jean-Luc Picard").initials == "JL")
        #expect(Member(teamID: team.id, name: "  ").initials == "?")
    }

    // MARK: Exemple

    @Test func sampleTeamShowcasesCalibrationAndPlanning() {
        let store = OrbitStore(data: OrbitData())
        let team = store.addSampleTeam()
        let members = store.members(in: team.id)
        #expect(members.count == 4)

        let factors = Dictionary(uniqueKeysWithValues: members.map { ($0.name, store.calibration(for: $0.id).factor) })
        #expect(factors["Camille Martin"]! > 1.1)
        #expect(factors["Léa Dubois"]! < 0.95)
        #expect(factors["Nathan Petit"] == 1)

        let schedule = store.schedule(for: team.id)
        let hugo = members.first { $0.name == "Hugo Bernard" }!
        let exportCSV = store.tasks.first { $0.title == "Export CSV" }!
        #expect(schedule.members[hugo.id]?.item(for: exportCSV.id)?.isOverdue == true)
        #expect(!store.queue(teamID: team.id, assigneeID: nil).isEmpty)
    }
}
