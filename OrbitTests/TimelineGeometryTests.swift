//
//  TimelineGeometryTests.swift
//  OrbitTests
//

import Foundation
import Testing
@testable import Orbit

@MainActor
struct TimelineGeometryTests {
    /// Semaine du lundi 2 novembre 2026, ancrée sur le mercredi 4 (index 0).
    /// 5 jours ouvrés + 2 jours de week-end à demi-largeur = 6 unités de 100 points.
    private let geometry = TimelineGeometry(
        start: TestCalendar.day(2026, 11, 2),
        dayCount: 7,
        width: 600,
        workCalendar: TestCalendar.workWeek,
        anchor: TestCalendar.day(2026, 11, 4),
        today: TestCalendar.date(2026, 11, 4, hour: 15),
        nonWorkingDayRatio: 0.5
    )

    @Test func laysOutDaysWithNarrowerWeekends() {
        #expect(geometry.days.count == 7)
        #expect(geometry.days.map(\.width) == [100, 100, 100, 100, 100, 50, 50])
        #expect(geometry.days.map(\.x) == [0, 100, 200, 300, 400, 500, 550])
        #expect(geometry.days.map(\.workingIndex) == [-2, -1, 0, 1, 2, nil, nil])
        #expect(geometry.totalWidth == 600)
        #expect(geometry.todayX == 200)
        #expect(geometry.days.filter(\.isToday).count == 1)
    }

    @Test func visiblePositionsCoverTheWorkingDays() {
        #expect(geometry.visiblePositions == -16..<24)
    }

    @Test func spanInsideTheRange() {
        let span = geometry.span(start: 0, end: 12)
        #expect(span == TimelineSpan(x: 200, width: 150, continuesBefore: false, continuesAfter: false))
    }

    @Test func spanEndingAtEndOfDayStaysInThatDay() {
        #expect(geometry.span(start: 0, end: 8)?.width == 100)
        // Du vendredi au lundi suivant : coupé à la fin du vendredi affiché.
        let span = geometry.span(start: 16, end: 32)
        #expect(span == TimelineSpan(x: 400, width: 100, continuesBefore: false, continuesAfter: true))
    }

    @Test func spanStartingBeforeTheRangeIsClipped() {
        let span = geometry.span(start: -20, end: -12)
        #expect(span == TimelineSpan(x: 0, width: 50, continuesBefore: true, continuesAfter: false))
    }

    @Test func spansOutsideTheRangeAreHidden() {
        #expect(geometry.span(start: -40, end: -16) == nil)
        #expect(geometry.span(start: 24, end: 30) == nil)
        #expect(geometry.span(start: 30, end: 30) == nil)
    }

    @Test func emptySpanInsideTheRangeIsAMarker() {
        #expect(geometry.span(start: 4, end: 4) == TimelineSpan(x: 250, width: 0, continuesBefore: false, continuesAfter: false))
    }

    @Test func rangeStartingOnAWeekend() {
        let weekend = TimelineGeometry(
            start: TestCalendar.day(2026, 11, 7),
            dayCount: 3,
            width: 200,
            workCalendar: TestCalendar.workWeek,
            anchor: TestCalendar.day(2026, 11, 4),
            today: TestCalendar.day(2026, 11, 4),
            nonWorkingDayRatio: 0.5
        )
        #expect(weekend.days.map(\.workingIndex) == [nil, nil, 3])
        #expect(weekend.visiblePositions == 24..<32)
        #expect(weekend.todayX == nil)
    }
}
