//
//  MagicCalcTests.swift
//  MagicCalcTests
//
//  Created by Taylor Wilson on 9/27/26.
//

import Foundation
import Testing
@testable import MagicCalc

struct MagicCalcTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test func trickUsesCurrentMinuteWhenMoreThanThirtySecondsRemain() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)

        let plan = MagicCalculator.makeTrickPlan(currentSum: 1_111_110, now: now, calendar: calendar)

        #expect(plan.targetValue == 9_272_114)
        #expect(plan.selectedNumber == 8_161_004)
        #expect(plan.usesNextMinute == false)
        #expect(plan.isSevenDigitSelection)
    }

    @Test func trickUsesNextMinuteWhenThirtyOrFewerSecondsRemain() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 30)

        let plan = MagicCalculator.makeTrickPlan(currentSum: 1_111_110, now: now, calendar: calendar)

        #expect(plan.targetValue == 9_272_115)
        #expect(plan.selectedNumber == 8_161_005)
        #expect(plan.usesNextMinute)
    }

    @Test func thirdVisibleEntryIsReplacedDigitByDigitWithCompletingNumber() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)
        var calculator = armedCalculatorWithTwoTerms(now: now)

        #expect(calculator.indicatorState == .capturingSecret)

        calculator.tapDigit("9", now: now, calendar: calendar)
        #expect(calculator.display == "8")
        #expect(calculator.indicatorState == .capturingSecret)

        enter("999999", into: &calculator, now: now)
        #expect(calculator.display == "8494337")
        #expect(calculator.indicatorState == .armed)

        calculator.tapEquals()
        #expect(calculator.display == "9272114")
        #expect(calculator.indicatorState == .none)
    }

    @Test func blindEntryConsumesAnyButtonAsNextSecretDigit() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)
        var calculator = armedCalculatorWithTwoTerms(now: now)

        calculator.tapOperation(.multiply)
        calculator.tapClear()
        calculator.tapEquals()
        calculator.tapDecimal()
        calculator.tapToggleSign()
        calculator.tapPercent()
        calculator.tapOperation(.divide)

        #expect(calculator.display == "8494337")
        #expect(calculator.indicatorState == .armed)

        calculator.tapEquals()
        #expect(calculator.display == "9272114")
        #expect(calculator.indicatorState == .none)
    }

    @Test func trickCancelsWhenVisibleTermHasMoreThanSixDigits() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)
        var calculator = MagicCalculator()

        calculator.tapClear()
        calculator.tapClear()
        calculator.tapClear()
        enter("1234567", into: &calculator, now: now)

        #expect(calculator.indicatorState == .cancelled)

        calculator.clearCancellationIndicator()
        #expect(calculator.indicatorState == .none)
    }

    @Test func trickCancelsWhenNonPlusOperatorIsUsedBeforeSecretEntry() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)
        var calculator = MagicCalculator()

        calculator.tapClear()
        calculator.tapClear()
        calculator.tapClear()
        enter("123456", into: &calculator, now: now)
        calculator.tapOperation(.subtract)

        #expect(calculator.indicatorState == .cancelled)
    }

    @Test func debugPlanIsAvailableBeforeThirdTermStarts() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)
        let calculator = armedCalculatorWithTwoTerms(now: now)

        #expect(calculator.debugStateText == "Trick: active | Term: 3 | Sum: 777777")
        #expect(calculator.debugPlanText(now: now, calendar: calendar) == "Secret: 8494337 | Final: 9272114")
    }

    private func armedCalculatorWithTwoTerms(now: Date) -> MagicCalculator {
        var calculator = MagicCalculator()
        calculator.tapClear()
        calculator.tapClear()
        calculator.tapClear()
        enter("123456", into: &calculator, now: now)
        calculator.tapOperation(.add)
        enter("654321", into: &calculator, now: now)
        calculator.tapOperation(.add)
        return calculator
    }

    private func enter(_ value: String, into calculator: inout MagicCalculator, now: Date) {
        for digit in value.map(String.init) {
            calculator.tapDigit(digit, now: now, calendar: calendar)
        }
    }

    private func date(month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ).date!
    }
}
