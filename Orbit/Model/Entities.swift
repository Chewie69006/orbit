//
//  Entities.swift
//  Orbit
//

import Foundation

// Les décodeurs sont écrits à la main (dans des extensions, pour garder les initialiseurs
// par membre) afin qu'un fichier enregistré par une version précédente reste lisible
// quand de nouveaux champs apparaissent.

// MARK: - Équipe

struct Team: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt
    }
}

extension Team {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Membre

struct Member: Identifiable, Hashable, Codable {
    var id: UUID
    var teamID: UUID
    var name: String
    var role: String
    /// Index dans la palette de couleurs de l'application.
    var colorIndex: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        teamID: UUID,
        name: String,
        role: String = "",
        colorIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teamID = teamID
        self.name = name
        self.role = role
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }

    /// Initiales pour l'avatar (« Ada Lovelace » → « AL »).
    var initials: String {
        let letters = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" })
            .prefix(2)
            .compactMap(\.first)
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }

    enum CodingKeys: String, CodingKey {
        case id, teamID, name, role, colorIndex, createdAt
    }
}

extension Member {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        teamID = try c.decode(UUID.self, forKey: .teamID)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Tâche

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case inProgress
    case done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .todo: "À faire"
        case .inProgress: "En cours"
        case .done: "Terminée"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        }
    }
}

struct Subtask: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var estimate: ManDays
    var isDone: Bool

    init(id: UUID = UUID(), title: String, estimate: ManDays, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.estimate = estimate
        self.isDone = isDone
    }

    enum CodingKeys: String, CodingKey {
        case id, title, estimate, isDone
    }
}

extension Subtask {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        estimate = try c.decodeIfPresent(ManDays.self, forKey: .estimate) ?? .zero
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
    }
}

/// Une tâche de l'équipe. (Nommée `TaskItem` pour ne pas masquer `Task` de Swift Concurrency.)
struct TaskItem: Identifiable, Hashable, Codable {
    var id: UUID
    var teamID: UUID
    var title: String
    var notes: String
    var assigneeID: UUID?
    /// Chiffrage donné par le développeur pour la tâche elle-même.
    var estimate: ManDays
    var subtasks: [Subtask]
    var status: TaskStatus
    /// Position dans la file de la personne assignée (plus petit = plus tôt).
    var rank: Int
    /// Date au plus tôt à laquelle la tâche peut commencer.
    var notBefore: Date?
    var startedAt: Date?
    var completedAt: Date?
    /// Temps réellement passé, saisi à la fin de la tâche.
    var actualSpent: ManDays?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        teamID: UUID,
        title: String,
        notes: String = "",
        assigneeID: UUID? = nil,
        estimate: ManDays,
        subtasks: [Subtask] = [],
        status: TaskStatus = .todo,
        rank: Int = 0,
        notBefore: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        actualSpent: ManDays? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teamID = teamID
        self.title = title
        self.notes = notes
        self.assigneeID = assigneeID
        self.estimate = estimate
        self.subtasks = subtasks
        self.status = status
        self.rank = rank
        self.notBefore = notBefore
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.actualSpent = actualSpent
        self.createdAt = createdAt
    }

    /// Somme des chiffrages des sous-tâches.
    var subtasksEstimate: ManDays {
        subtasks.map(\.estimate).sum()
    }

    /// Chiffrage retenu : la somme des sous-tâches remplace le chiffrage de la tâche
    /// lorsqu'elle est supérieure.
    var effectiveEstimate: ManDays {
        max(estimate, subtasksEstimate)
    }

    /// Vrai quand ce sont les sous-tâches qui déterminent le chiffrage retenu.
    var isEstimateDrivenBySubtasks: Bool {
        subtasksEstimate > estimate
    }

    var isOpen: Bool { status != .done }

    var completedSubtaskCount: Int { subtasks.filter(\.isDone).count }

    enum CodingKeys: String, CodingKey {
        case id, teamID, title, notes, assigneeID, estimate, subtasks, status, rank
        case notBefore, startedAt, completedAt, actualSpent, createdAt
    }
}

extension TaskItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        teamID = try c.decode(UUID.self, forKey: .teamID)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        assigneeID = try c.decodeIfPresent(UUID.self, forKey: .assigneeID)
        estimate = try c.decodeIfPresent(ManDays.self, forKey: .estimate) ?? .zero
        subtasks = try c.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        status = try c.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .todo
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        notBefore = try c.decodeIfPresent(Date.self, forKey: .notBefore)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        actualSpent = try c.decodeIfPresent(ManDays.self, forKey: .actualSpent)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
