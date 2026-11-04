//
//  TestSupport.swift
//  OrbitTests
//

import Foundation
@testable import Orbit

/// Calendrier déterministe pour les tests (Paris, semaine commençant le lundi).
///
/// Les types de l'app sont isolés sur le MainActor (isolation par défaut du projet) :
/// les utilitaires et les suites de tests le sont donc aussi.
@MainActor
enum TestCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Lundi → vendredi.
    static let workWeek = WorkCalendar(workingDays: Weekday.defaultWorkingDays, calendar: calendar)

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(year, month, day))
    }
}

extension ManDays {
    @MainActor
    static func e(_ eighths: Int) -> ManDays { ManDays(eighths: eighths) }
}
