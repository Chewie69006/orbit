//
//  OrbitStore.swift
//  Orbit
//

import Foundation
import Observation

/// Source de vérité de l'application : équipes, membres, tâches et paramètres.
///
/// Toutes les modifications passent par ce store, qui les enregistre immédiatement
/// dans un fichier JSON (dans « Application Support/Orbit » par défaut).
@MainActor
@Observable
final class OrbitStore {
    /// Nombre de couleurs de la palette des membres (voir `MemberPalette`).
    static let paletteSize = 10

    private(set) var teams: [Team] = [] { didSet { persist() } }
    private(set) var members: [Member] = [] { didSet { persist() } }
    private(set) var tasks: [TaskItem] = [] { didSet { persist() } }
    var settings = AppSettings() { didSet { persist() } }

    /// Problème rencontré au chargement (fichier illisible mis de côté).
    var loadIssue: String?
    /// Dernière erreur d'enregistrement, nil si tout va bien.
    private(set) var saveError: String?

    @ObservationIgnored let fileURL: URL?
    @ObservationIgnored private var isPersistenceEnabled = false
    @ObservationIgnored private var batchDepth = 0

    /// - Parameter fileURL: fichier de données ; nil pour un store en mémoire (aperçus, tests).
    init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL {
            load(from: fileURL)
        }
        isPersistenceEnabled = true
    }

    /// Store en mémoire initialisé avec des données (aperçus, tests).
    init(data: OrbitData) {
        self.fileURL = nil
        apply(data)
        isPersistenceEnabled = true
    }

    /// Store enregistré dans le dossier « Application Support » de l'utilisateur.
    static func live() -> OrbitStore {
        OrbitStore(fileURL: defaultFileURL)
    }

    static var defaultFileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("orbit.json", isDirectory: false)
    }

    var snapshot: OrbitData {
        OrbitData(teams: teams, members: members, tasks: tasks, settings: settings)
    }

    var workCalendar: WorkCalendar { settings.workCalendar }

    // MARK: - Lecture

    func team(_ id: UUID?) -> Team? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    func member(_ id: UUID?) -> Member? {
        guard let id else { return nil }
        return members.first { $0.id == id }
    }

    func task(_ id: UUID?) -> TaskItem? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    func members(in teamID: UUID) -> [Member] {
        members.filter { $0.teamID == teamID }
    }

    func tasks(in teamID: UUID) -> [TaskItem] {
        tasks.filter { $0.teamID == teamID }
    }

    func tasks(assignedTo memberID: UUID) -> [TaskItem] {
        tasks.filter { $0.assigneeID == memberID }
    }

    /// File des tâches ouvertes d'une personne (ou des tâches non assignées si `assigneeID` est nil),
    /// dans l'ordre de planification.
    func queue(teamID: UUID, assigneeID: UUID?) -> [TaskItem] {
        tasks
            .filter { $0.teamID == teamID && $0.assigneeID == assigneeID && $0.isOpen }
            .sorted { ($0.rank, $0.createdAt) < ($1.rank, $1.createdAt) }
    }

    /// Tâches terminées de l'équipe, de la plus récente à la plus ancienne.
    func completedTasks(in teamID: UUID) -> [TaskItem] {
        tasks
            .filter { $0.teamID == teamID && $0.status == .done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    // MARK: - Équipes

    @discardableResult
    func addTeam(name: String) -> Team {
        let team = Team(name: Self.cleaned(name, fallback: "Nouvelle équipe"))
        teams.append(team)
        return team
    }

    func renameTeam(_ id: UUID, to name: String) {
        guard let index = teams.firstIndex(where: { $0.id == id }) else { return }
        teams[index].name = Self.cleaned(name, fallback: teams[index].name)
    }

    /// Supprime l'équipe, ses membres et ses tâches.
    func deleteTeam(_ id: UUID) {
        batch {
            teams.removeAll { $0.id == id }
            members.removeAll { $0.teamID == id }
            tasks.removeAll { $0.teamID == id }
        }
    }

    // MARK: - Membres

    @discardableResult
    func addMember(name: String, role: String = "", teamID: UUID, colorIndex: Int? = nil) -> Member {
        let member = Member(
            teamID: teamID,
            name: Self.cleaned(name, fallback: "Nouveau membre"),
            role: role.trimmingCharacters(in: .whitespacesAndNewlines),
            colorIndex: colorIndex ?? nextColorIndex(in: teamID)
        )
        members.append(member)
        return member
    }

    func updateMember(_ member: Member) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        var updated = member
        updated.name = Self.cleaned(member.name, fallback: members[index].name)
        updated.role = member.role.trimmingCharacters(in: .whitespacesAndNewlines)
        members[index] = updated
    }

    /// Supprime un membre ; ses tâches deviennent non assignées.
    func deleteMember(_ id: UUID) {
        guard let member = member(id) else { return }
        batch {
            var nextRank = (queue(teamID: member.teamID, assigneeID: nil).map(\.rank).max() ?? -1) + 1
            for index in tasks.indices where tasks[index].assigneeID == id {
                tasks[index].assigneeID = nil
                if tasks[index].isOpen {
                    tasks[index].rank = nextRank
                    nextRank += 1
                }
            }
            members.removeAll { $0.id == id }
        }
    }

    /// Couleur la moins utilisée dans l'équipe.
    func nextColorIndex(in teamID: UUID) -> Int {
        var usage = Array(repeating: 0, count: Self.paletteSize)
        for member in members(in: teamID) {
            usage[((member.colorIndex % Self.paletteSize) + Self.paletteSize) % Self.paletteSize] += 1
        }
        let minimum = usage.min() ?? 0
        return usage.firstIndex(of: minimum) ?? 0
    }

    // MARK: - Tâches

    /// Ajoute une tâche à la fin de la file de la personne assignée.
    @discardableResult
    func addTask(_ task: TaskItem) -> TaskItem {
        var task = task
        task.title = Self.cleaned(task.title, fallback: "Nouvelle tâche")
        if task.isOpen {
            task.rank = nextRank(teamID: task.teamID, assigneeID: task.assigneeID)
        }
        tasks.append(task)
        return task
    }

    /// Met à jour une tâche. Si la personne assignée change, la tâche passe à la fin de sa file.
    func updateTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        if updated.assigneeID != tasks[index].assigneeID, updated.isOpen {
            updated.rank = nextRank(teamID: updated.teamID, assigneeID: updated.assigneeID)
        }
        guard updated != tasks[index] else { return }
        tasks[index] = updated
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }

    /// Passe la tâche « en cours » et la place en tête de file (après les autres tâches en cours).
    func startTask(_ id: UUID, at date: Date = Date()) {
        guard let task = task(id), task.status == .todo else { return }
        batch {
            mutateTask(id) {
                $0.status = .inProgress
                $0.startedAt = date
            }
            moveToFrontOfQueue(id)
        }
    }

    /// Remet une tâche en cours dans l'état « à faire ».
    func stopTask(_ id: UUID) {
        mutateTask(id) {
            guard $0.status == .inProgress else { return }
            $0.status = .todo
            $0.startedAt = nil
        }
    }

    /// Termine la tâche en indiquant le temps réellement passé.
    func completeTask(_ id: UUID, actualSpent: ManDays, at date: Date = Date()) {
        mutateTask(id) {
            $0.status = .done
            $0.actualSpent = actualSpent
            $0.completedAt = date
            if $0.startedAt == nil { $0.startedAt = date }
            for index in $0.subtasks.indices {
                $0.subtasks[index].isDone = true
            }
        }
    }

    /// Rouvre une tâche terminée : elle repasse « en cours », en tête de file.
    func reopenTask(_ id: UUID, at date: Date = Date()) {
        guard let task = task(id), task.status == .done else { return }
        batch {
            mutateTask(id) {
                $0.status = .inProgress
                $0.completedAt = nil
                $0.actualSpent = nil
                if $0.startedAt == nil { $0.startedAt = date }
            }
            moveToFrontOfQueue(id)
        }
    }

    /// Réordonne la file d'une personne (mêmes conventions que `List.onMove`).
    func moveQueuedTasks(teamID: UUID, assigneeID: UUID?, fromOffsets source: IndexSet, toOffset destination: Int) {
        let queue = queue(teamID: teamID, assigneeID: assigneeID)
        let reordered = Self.reordered(queue.map(\.id), fromOffsets: source, toOffset: destination)
        renumber(reordered)
    }

    // MARK: - Pondération et planning

    func calibration(for memberID: UUID) -> Calibration {
        Calibration.compute(from: tasks(assignedTo: memberID), smoothing: settings.smoothing)
    }

    /// Pondération qu'aurait la personne assignée si la tâche était terminée avec ce temps passé.
    func calibrationPreview(completing task: TaskItem, actualSpent: ManDays, at date: Date) -> Calibration? {
        guard let memberID = task.assigneeID else { return nil }
        var finished = task
        finished.status = .done
        finished.actualSpent = actualSpent
        finished.completedAt = date
        let others = tasks(assignedTo: memberID).filter { $0.id != task.id }
        return Calibration.compute(from: others + [finished], smoothing: settings.smoothing)
    }

    func schedule(for teamID: UUID, now: Date = Date()) -> TeamSchedule {
        Scheduler(settings: settings).schedule(
            memberIDs: members(in: teamID).map(\.id),
            tasks: tasks(in: teamID),
            now: now
        )
    }

    // MARK: - Données d'exemple

    /// Ajoute une équipe d'exemple, avec un historique de tâches terminées.
    @discardableResult
    func addSampleTeam(now: Date = Date()) -> Team {
        let sample = SampleData.make(now: now, workCalendar: workCalendar)
        batch {
            teams.append(sample.team)
            members.append(contentsOf: sample.members)
            tasks.append(contentsOf: sample.tasks)
        }
        return sample.team
    }

    // MARK: - Utilitaires internes

    private func mutateTask(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        var task = tasks[index]
        change(&task)
        if task != tasks[index] {
            tasks[index] = task
        }
    }

    private func nextRank(teamID: UUID, assigneeID: UUID?) -> Int {
        (queue(teamID: teamID, assigneeID: assigneeID).map(\.rank).max() ?? -1) + 1
    }

    /// Place la tâche juste après les tâches déjà en cours de sa file.
    private func moveToFrontOfQueue(_ id: UUID) {
        guard let task = task(id) else { return }
        var ids = queue(teamID: task.teamID, assigneeID: task.assigneeID).map(\.id)
        ids.removeAll { $0 == id }
        let inProgressCount = ids.prefix(while: { self.task($0)?.status == .inProgress }).count
        ids.insert(id, at: inProgressCount)
        renumber(ids)
    }

    private func renumber(_ orderedIDs: [UUID]) {
        let ranks = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
        var updated = tasks
        for index in updated.indices {
            if let rank = ranks[updated[index].id] {
                updated[index].rank = rank
            }
        }
        if updated != tasks {
            tasks = updated
        }
    }

    /// Regroupe plusieurs modifications en un seul enregistrement.
    private func batch(_ changes: () -> Void) {
        batchDepth += 1
        changes()
        batchDepth -= 1
        persist()
    }

    static func reordered<Element>(_ elements: [Element], fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        let valid = source.filter { elements.indices.contains($0) }
        let moving = valid.sorted().map { elements[$0] }
        var remaining = elements.enumerated().filter { !valid.contains($0.offset) }.map(\.element)
        let insertion = destination - valid.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(max(insertion, 0), remaining.count))
        return remaining
    }

    private static func cleaned(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    // MARK: - Persistance

    private func apply(_ data: OrbitData) {
        teams = data.teams
        members = data.members
        tasks = data.tasks
        settings = data.settings
    }

    private func load(from url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let raw = try Data(contentsOf: url)
            apply(try OrbitData.makeDecoder().decode(OrbitData.self, from: raw))
        } catch {
            // On ne réécrit jamais par-dessus un fichier illisible : il est mis de côté.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingLastPathComponent().appendingPathComponent("orbit-illisible-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            loadIssue = "Le fichier de données était illisible. Il a été mis de côté sous le nom « \(backup.lastPathComponent) »."
        }
    }

    private func persist() {
        guard isPersistenceEnabled, batchDepth == 0, let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try OrbitData.makeEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            if saveError != nil { saveError = nil }
        } catch {
            saveError = "Impossible d'enregistrer les données : \(error.localizedDescription)"
        }
    }
}
