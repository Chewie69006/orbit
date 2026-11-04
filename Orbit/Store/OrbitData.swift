//
//  OrbitData.swift
//  Orbit
//

import Foundation

/// Le document enregistré sur disque (JSON).
struct OrbitData: Codable, Hashable {
    static let currentVersion = 1

    var version: Int
    var teams: [Team]
    var members: [Member]
    var tasks: [TaskItem]
    var settings: AppSettings

    init(
        teams: [Team] = [],
        members: [Member] = [],
        tasks: [TaskItem] = [],
        settings: AppSettings = AppSettings()
    ) {
        self.version = Self.currentVersion
        self.teams = teams
        self.members = members
        self.tasks = tasks
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case version, teams, members, tasks, settings
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension OrbitData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        teams = try c.decodeIfPresent([Team].self, forKey: .teams) ?? []
        members = try c.decodeIfPresent([Member].self, forKey: .members) ?? []
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}
