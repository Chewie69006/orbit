//
//  WorkCalendarTests.swift
//  OrbitTests
//

import Foundation
import Testing
@testable import Orbit

@MainActor
struct WorkCalendarTests {
    private let work = TestCalendar.workWeek
    // Mercredi 4 novembre 2026.
    private let wednesday = TestCalendar.day(2026, 11, 4)

    @Test func knowsWorkingDays() {
        #expect(work.isWorkingDay(TestCalendar.day(2026, 11, 6)))   // vendredi
        #expect(!work.isWorkingDay(TestCalendar.day(2026, 11, 7)))  // samedi
        #expect(!work.isWorkingDay(TestCalendar.day(2026, 11, 8)))  // dimanche
        #expect(work.isWorkingDay(TestCalendar.day(2026, 11, 9)))   // lundi
    }

    @Test func emptyWorkingDaysFallBackToTheStandardWeek() {
        let calendar = WorkCalendar(workingDays: [], calendar: TestCalendar.calendar)
        #expect(calendar.workingDays == Weekday.defaultWorkingDays)
    }

    @Test func nextAndPreviousWorkingDay() {
        let saturday = TestCalendar.date(2026, 11, 7, hour: 15)
        #expect(work.nextWorkingDay(onOrAfter: saturday) == TestCalendar.day(2026, 11, 9))
        #expect(work.previousWorkingDay(onOrBefore: saturday) == TestCalendar.day(2026, 11, 6))
        #expect(work.nextWorkingDay(onOrAfter: wednesday) == wednesday)
    }

    @Test func countsWorkingDaysInHalfOpenRange() {
        // Du mercredi 4 au mercredi 11 : mer, jeu, ven, lun, mar.
        #expect(work.workingDayCount(from: wednesday, to: TestCalendar.day(2026, 11, 11)) == 5)
        // Sur trois semaines pleines.
        #expect(work.workingDayCount(from: wednesday, to: TestCalendar.day(2026, 11, 25)) == 15)
        #expect(work.workingDayCount(from: wednesday, to: wednesday) == 0)
    }

    @Test func indexesAreSignedAndSkipNonWorkingDays() {
        #expect(work.workingDayIndex(of: wednesday, from: wednesday) == 0)
        #expect(work.workingDayIndex(of: TestCalendar.day(2026, 11, 6), from: wednesday) == 2)
        // Le samedi et le dimanche prennent l'index du lundi suivant.
        #expect(work.workingDayIndex(of: TestCalendar.day(2026, 11, 7), from: wednesday) == 3)
        #expect(work.workingDayIndex(of: TestCalendar.day(2026, 11, 9), from: wednesday) == 3)
        #expect(work.workingDayIndex(of: TestCalendar.day(2026, 11, 2), from: wednesday) == -2)
        #expect(work.workingDayIndex(of: TestCalendar.day(2026, 10, 30), from: wednesday) == -3)
        #expect(work.workingDayIndex(of: TestCalendar.day(2026, 11, 1), from: wednesday) == -2)
    }

    @Test func workingDayAtIndexIsTheInverseOfIndex() {
        for index in -40...40 {
            let day = work.workingDay(at: index, from: wednesday)
            #expect(work.isWorkingDay(day))
            #expect(work.workingDayIndex(of: day, from: wednesday) == index)
        }
    }

    @Test func handlesTheDaylightSavingTimeChange() {
        // Passage à l'heure d'hiver le dimanche 25 octobre 2026.
        let friday = TestCalendar.day(2026, 10, 23)
        let monday = TestCalendar.day(2026, 10, 26)
        #expect(work.workingDayIndex(of: monday, from: friday) == 1)
        #expect(work.workingDay(at: 1, from: friday) == monday)
    }

    @Test func customWorkingWeek() {
        // Semaine de quatre jours, du lundi au jeudi.
        let fourDays = WorkCalendar(workingDays: [.monday, .tuesday, .wednesday, .thursday], calendar: TestCalendar.calendar)
        #expect(!fourDays.isWorkingDay(TestCalendar.day(2026, 11, 6)))
        #expect(fourDays.workingDay(at: 2, from: wednesday) == TestCalendar.day(2026, 11, 9))
        for index in -20...20 {
            let day = fourDays.workingDay(at: index, from: wednesday)
            #expect(fourDays.workingDayIndex(of: day, from: wednesday) == index)
        }
    }

    @Test func weekdayOrderFollowsTheCalendar() {
        #expect(Weekday.ordered(for: TestCalendar.calendar).first == .monday)
        #expect(Weekday.ordered(for: TestCalendar.calendar).last == .sunday)
        var sundayFirst = TestCalendar.calendar
        sundayFirst.firstWeekday = 1
        #expect(Weekday.ordered(for: sundayFirst) == [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
    }

    @Test func positionsUseFloorDivision() {
        #expect(PlanningPosition.dayIndex(startingAt: 0) == 0)
        #expect(PlanningPosition.dayIndex(startingAt: 7) == 0)
        #expect(PlanningPosition.dayIndex(startingAt: 8) == 1)
        #expect(PlanningPosition.dayIndex(startingAt: -1) == -1)
        #expect(PlanningPosition.dayIndex(startingAt: -8) == -1)
        #expect(PlanningPosition.dayIndex(startingAt: -9) == -2)
        #expect(PlanningPosition.dayIndex(endingAt: 8) == 0)
        #expect(PlanningPosition.dayIndex(endingAt: 9) == 1)
        #expect(PlanningPosition.dayIndex(endingAt: 0) == -1)
    }
}
