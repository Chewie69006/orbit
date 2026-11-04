//
//  TimelineGeometry.swift
//  Orbit
//

import Foundation

/// Une colonne (un jour) de la frise du planning.
struct TimelineDay: Identifiable, Hashable {
    let date: Date
    let isWorkingDay: Bool
    let isToday: Bool
    /// Index du jour ouvré (nil pour un jour non travaillé).
    let workingIndex: Int?
    let x: Double
    let width: Double

    var id: Date { date }
}

/// Segment horizontal occupé par une tâche dans la frise.
struct TimelineSpan: Hashable {
    let x: Double
    let width: Double
    /// La tâche commence avant la période affichée.
    let continuesBefore: Bool
    /// La tâche se termine après la période affichée.
    let continuesAfter: Bool
}

/// Calcule la géométrie de la frise : largeur des jours (les jours non travaillés sont
/// plus étroits) et conversion des positions du planning en abscisses.
struct TimelineGeometry {
    let days: [TimelineDay]
    let totalWidth: Double
    private let columnByWorkingIndex: [Int: Int]
    private let firstWorkingIndex: Int?
    private let lastWorkingIndex: Int?

    /// - Parameters:
    ///   - start: premier jour affiché.
    ///   - dayCount: nombre de jours affichés.
    ///   - width: largeur disponible.
    ///   - anchor: jour ouvré d'index 0 (voir ``TeamSchedule/anchor``).
    ///   - nonWorkingDayRatio: largeur d'un jour non travaillé par rapport à un jour travaillé.
    init(
        start: Date,
        dayCount: Int,
        width: Double,
        workCalendar: WorkCalendar,
        anchor: Date,
        today: Date,
        nonWorkingDayRatio: Double = 0.35
    ) {
        let firstDay = workCalendar.startOfDay(start)
        let todayStart = workCalendar.startOfDay(today)
        let dates = (0..<max(0, dayCount)).map { workCalendar.addingDays($0, to: firstDay) }
        let working = dates.map { workCalendar.isWorkingDay($0) }
        let units = working.reduce(0.0) { $0 + ($1 ? 1 : nonWorkingDayRatio) }
        let unitWidth = units > 0 ? max(0, width) / units : 0

        var days: [TimelineDay] = []
        var columns: [Int: Int] = [:]
        var x = 0.0
        // Index ouvré du premier jour affiché, puis on incrémente au fil des jours ouvrés.
        var nextWorkingIndex = dates.first.map { workCalendar.workingDayIndex(of: $0, from: anchor) } ?? 0
        for (offset, date) in dates.enumerated() {
            let isWorking = working[offset]
            let dayWidth = unitWidth * (isWorking ? 1 : nonWorkingDayRatio)
            var workingIndex: Int?
            if isWorking {
                workingIndex = nextWorkingIndex
                columns[nextWorkingIndex] = days.count
                nextWorkingIndex += 1
            }
            days.append(
                TimelineDay(
                    date: date,
                    isWorkingDay: isWorking,
                    isToday: date == todayStart,
                    workingIndex: workingIndex,
                    x: x,
                    width: dayWidth
                )
            )
            x += dayWidth
        }

        self.days = days
        self.totalWidth = x
        self.columnByWorkingIndex = columns
        self.firstWorkingIndex = days.lazy.compactMap(\.workingIndex).first
        self.lastWorkingIndex = days.reversed().lazy.compactMap(\.workingIndex).first
    }

    /// Plage de positions visibles `[début, fin)`.
    var visiblePositions: Range<Int>? {
        guard let first = firstWorkingIndex, let last = lastWorkingIndex else { return nil }
        return (first * PlanningPosition.eighthsPerDay)..<((last + 1) * PlanningPosition.eighthsPerDay)
    }

    /// Abscisse d'une position du planning (bornée à la période affichée).
    func x(forPosition position: Int, isEnd: Bool) -> Double {
        guard let visible = visiblePositions else { return 0 }
        if position <= visible.lowerBound { return days.first(where: \.isWorkingDay)?.x ?? 0 }
        if position >= visible.upperBound {
            return days.last(where: \.isWorkingDay).map { $0.x + $0.width } ?? totalWidth
        }
        let perDay = PlanningPosition.eighthsPerDay
        let dayIndex = isEnd ? PlanningPosition.dayIndex(endingAt: position) : PlanningPosition.dayIndex(startingAt: position)
        guard let column = columnByWorkingIndex[dayIndex] else { return 0 }
        let day = days[column]
        let offset = Double(position - dayIndex * perDay) / Double(perDay)
        return day.x + offset * day.width
    }

    /// Segment occupé par l'intervalle `[start, end)`, ou nil s'il est hors de la période affichée.
    func span(start: Int, end: Int) -> TimelineSpan? {
        guard let visible = visiblePositions else { return nil }
        let end = max(end, start)
        // Un intervalle vide reste visible s'il tombe dans la période (marqueur).
        if end == start {
            guard visible.contains(start) else { return nil }
        } else {
            guard end > visible.lowerBound, start < visible.upperBound else { return nil }
        }
        let x0 = x(forPosition: start, isEnd: false)
        let x1 = end == start ? x0 : x(forPosition: end, isEnd: true)
        return TimelineSpan(
            x: x0,
            width: max(0, x1 - x0),
            continuesBefore: start < visible.lowerBound,
            continuesAfter: end > visible.upperBound
        )
    }

    /// Abscisse du début de la journée d'aujourd'hui, si elle est affichée.
    var todayX: Double? {
        days.first(where: \.isToday)?.x
    }
}
