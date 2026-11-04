//
//  WorkCalendar.swift
//  Orbit
//

import Foundation

/// Calendrier des jours travaillés : permet de convertir des dates en index de jours ouvrés
/// et inversement.
///
/// Les index sont relatifs à un jour ouvré d'ancrage (index 0). Un jour non travaillé
/// prend l'index du jour ouvré qui le suit.
struct WorkCalendar {
    let calendar: Calendar
    let workingDays: Set<Weekday>

    init(workingDays: Set<Weekday>, calendar: Calendar = .current) {
        // Sans aucun jour travaillé, aucun planning n'est possible : on retombe sur la semaine standard.
        self.workingDays = workingDays.isEmpty ? Weekday.defaultWorkingDays : workingDays
        self.calendar = calendar
    }

    // MARK: Jours

    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func weekday(of date: Date) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }

    func isWorkingDay(_ date: Date) -> Bool {
        workingDays.contains(weekday(of: date))
    }

    func addingDays(_ days: Int, to date: Date) -> Date {
        let start = startOfDay(date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start.addingTimeInterval(Double(days) * 86_400)
    }

    /// Nombre de jours calendaires entre deux dates (signé).
    func calendarDays(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(start), to: startOfDay(end)).day ?? 0
    }

    func nextWorkingDay(onOrAfter date: Date) -> Date {
        var day = startOfDay(date)
        for _ in 0..<7 where !isWorkingDay(day) {
            day = addingDays(1, to: day)
        }
        return day
    }

    func previousWorkingDay(onOrBefore date: Date) -> Date {
        var day = startOfDay(date)
        for _ in 0..<7 where !isWorkingDay(day) {
            day = addingDays(-1, to: day)
        }
        return day
    }

    /// Début de la semaine contenant `date` (selon le premier jour de semaine du calendrier).
    func startOfWeek(containing date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(date)
    }

    // MARK: Index de jours ouvrés

    /// Nombre de jours ouvrés dans l'intervalle `[start, end)`.
    func workingDayCount(from start: Date, to end: Date) -> Int {
        let total = calendarDays(from: start, to: end)
        guard total > 0 else { return 0 }
        let weeks = total / 7
        var count = weeks * workingDays.count
        var day = addingDays(weeks * 7, to: start)
        for _ in 0..<(total % 7) {
            if isWorkingDay(day) { count += 1 }
            day = addingDays(1, to: day)
        }
        return count
    }

    /// Index (signé) du jour `date` par rapport au jour ouvré `anchor`.
    /// Un jour non travaillé prend l'index du jour ouvré suivant.
    func workingDayIndex(of date: Date, from anchor: Date) -> Int {
        let anchorDay = nextWorkingDay(onOrAfter: anchor)
        let day = startOfDay(date)
        if day >= anchorDay {
            return workingDayCount(from: anchorDay, to: day)
        } else {
            return -workingDayCount(from: day, to: anchorDay)
        }
    }

    /// Jour ouvré correspondant à l'index `index` par rapport au jour ouvré `anchor`.
    func workingDay(at index: Int, from anchor: Date) -> Date {
        let anchorDay = nextWorkingDay(onOrAfter: anchor)
        let perWeek = workingDays.count
        // On saute d'abord des semaines entières (même jour de semaine que l'ancre, donc ouvré).
        let weeks = index >= 0 ? index / perWeek : -((-index) / perWeek)
        var day = addingDays(weeks * 7, to: anchorDay)
        var current = weeks * perWeek
        while current < index {
            day = addingDays(1, to: day)
            if isWorkingDay(day) { current += 1 }
        }
        while current > index {
            day = addingDays(-1, to: day)
            if isWorkingDay(day) { current -= 1 }
        }
        return day
    }
}

// MARK: - Positions

/// Une position dans le planning est un nombre de huitièmes de journée depuis le début
/// du jour ouvré d'ancrage (index 0). Les positions passées sont négatives.
enum PlanningPosition {
    static let eighthsPerDay = ManDays.eighthsPerDay

    /// Index du jour ouvré qui contient la position de début `position`.
    static func dayIndex(startingAt position: Int) -> Int {
        floorDivide(position, eighthsPerDay)
    }

    /// Index du dernier jour ouvré touché par un intervalle qui se termine (exclusivement) en `position`.
    static func dayIndex(endingAt position: Int) -> Int {
        floorDivide(position - 1, eighthsPerDay)
    }

    static func floorDivide(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        return (value % divisor != 0 && (value < 0) != (divisor < 0)) ? quotient - 1 : quotient
    }
}
