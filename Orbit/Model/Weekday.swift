//
//  Weekday.swift
//  Orbit
//

import Foundation

/// Jour de la semaine, aligné sur la numérotation de `Calendar` (1 = dimanche … 7 = samedi).
enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    /// Du lundi au vendredi.
    static let defaultWorkingDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Les jours dans l'ordre d'affichage du calendrier (le lundi en premier en France).
    static func ordered(for calendar: Calendar) -> [Weekday] {
        let first = calendar.firstWeekday
        return (0..<7).compactMap { Weekday(rawValue: (first - 1 + $0) % 7 + 1) }
    }

    func name(in calendar: Calendar = .current) -> String {
        calendar.standaloneWeekdaySymbols[rawValue - 1].capitalized(with: calendar.locale)
    }

    func shortName(in calendar: Calendar = .current) -> String {
        calendar.shortStandaloneWeekdaySymbols[rawValue - 1].capitalized(with: calendar.locale)
    }
}
