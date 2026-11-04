//
//  AppSettings.swift
//  Orbit
//

import Foundation

/// Paramètres de l'application.
struct AppSettings: Hashable, Codable {
    /// Jours travaillés (du lundi au vendredi par défaut).
    var workingDays: Set<Weekday>
    /// Coefficient de lissage α de la moyenne mobile exponentielle (EMA), entre 0 et 1.
    /// Plus il est élevé, plus les dernières tâches pèsent dans la pondération.
    var smoothing: Double
    /// Applique la pondération de chaque membre aux durées du planning.
    var applyCalibration: Bool

    static let defaultSmoothing = 0.3
    static let smoothingRange: ClosedRange<Double> = 0.05...0.95

    init(
        workingDays: Set<Weekday> = Weekday.defaultWorkingDays,
        smoothing: Double = AppSettings.defaultSmoothing,
        applyCalibration: Bool = true
    ) {
        self.workingDays = workingDays
        self.smoothing = smoothing
        self.applyCalibration = applyCalibration
    }

    var workCalendar: WorkCalendar {
        WorkCalendar(workingDays: workingDays)
    }

    enum CodingKeys: String, CodingKey {
        case workingDays, smoothing, applyCalibration
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let days = try c.decodeIfPresent(Set<Weekday>.self, forKey: .workingDays) ?? Weekday.defaultWorkingDays
        workingDays = days.isEmpty ? Weekday.defaultWorkingDays : days
        smoothing = try c.decodeIfPresent(Double.self, forKey: .smoothing) ?? Self.defaultSmoothing
        applyCalibration = try c.decodeIfPresent(Bool.self, forKey: .applyCalibration) ?? true
    }
}
