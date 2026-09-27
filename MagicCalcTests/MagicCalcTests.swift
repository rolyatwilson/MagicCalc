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

    @Test func expressionDisplaysWithCommasUntilEquals() {
        var calculator = MagicCalculator()

        enter("123456", into: &calculator)
        #expect(calculator.display == "123,456")

        calculator.tapOperation(.add)
        #expect(calculator.display == "123,456 +")

        calculator.tapDigit("7")
        #expect(calculator.display == "123,456 + 7")

        enter("54321", into: &calculator)
        #expect(calculator.display == "123,456 + 754,321")
        #expect(calculator.secondaryDisplay == nil)

        calculator.tapEquals()
        #expect(calculator.secondaryDisplay == "123,456 + 754,321")
        #expect(calculator.display == "877,777")
    }

    @Test func finalExpressionDoesNotShowTrailingOperator() {
        var calculator = MagicCalculator()

        enter("12", into: &calculator)
        calculator.tapOperation(.add)
        enter("34", into: &calculator)
        calculator.tapOperation(.add)
        calculator.tapEquals()

        #expect(calculator.secondaryDisplay == "12 + 34")
        #expect(calculator.display == "46")
    }

    @Test func clearButtonSwitchesBetweenAllClearAndClearEntry() {
        var calculator = MagicCalculator()

        #expect(calculator.clearButtonTitle == "AC")

        calculator.tapDigit("7")
        #expect(calculator.clearButtonTitle == "C")

        calculator.tapClear()
        #expect(calculator.display == "0")
        #expect(calculator.clearButtonTitle == "AC")

        calculator.tapDigit("1")
        calculator.tapOperation(.add)
        #expect(calculator.display == "1 +")
        #expect(calculator.clearButtonTitle == "AC")

        calculator.tapDigit("2")
        #expect(calculator.display == "1 + 2")
        #expect(calculator.clearButtonTitle == "C")

        calculator.tapClear()
        #expect(calculator.display == "1 +")
        #expect(calculator.clearButtonTitle == "AC")
    }

    @Test func clearEntryDoesNotCountTowardTrickArming() {
        var calculator = MagicCalculator()

        calculator.tapDigit("9")
        calculator.tapClear()
        calculator.tapClear()
        calculator.tapClear()

        #expect(calculator.indicatorState == .none)

        calculator.tapClear()
        #expect(calculator.indicatorState == .armed)
    }

    @Test func thirdVisibleEntryIsReplacedDigitByDigitWithCompletingNumber() {
        let now = date(month: 9, day: 27, hour: 21, minute: 14, second: 29)
        var calculator = armedCalculatorWithTwoTerms(now: now)

        #expect(calculator.indicatorState == .capturingSecret)
        #expect(calculator.display == "123,456 + 654,321 +")

        calculator.tapDigit("9", now: now, calendar: calendar)
        #expect(calculator.display == "123,456 + 654,321 + 8")
        #expect(calculator.indicatorState == .capturingSecret)

        enter("999999", into: &calculator, now: now)
        #expect(calculator.display == "123,456 + 654,321 + 8,494,337")
        #expect(calculator.indicatorState == .armed)

        calculator.tapEquals()
        #expect(calculator.secondaryDisplay == "123,456 + 654,321 + 8,494,337")
        #expect(calculator.display == "9,272,114")
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

        #expect(calculator.display == "123,456 + 654,321 + 8,494,337")
        #expect(calculator.indicatorState == .armed)

        calculator.tapEquals()
        #expect(calculator.display == "9,272,114")
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

    private func enter(_ value: String, into calculator: inout MagicCalculator, now: Date? = nil) {
        for digit in value.map(String.init) {
            if let now {
                calculator.tapDigit(digit, now: now, calendar: calendar)
            } else {
                calculator.tapDigit(digit)
            }
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
