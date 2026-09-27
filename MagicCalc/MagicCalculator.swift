//
//  MagicCalculator.swift
//  MagicCalc
//
//  Created by Taylor Wilson on 9/27/26.
//

import Foundation

struct MagicTrickPlan: Equatable {
    let targetValue: Int
    let selectedNumber: Int
    let targetDate: Date
    let usesNextMinute: Bool

    var selectedNumberText: String {
        String(selectedNumber)
    }

    var targetValueText: String {
        String(targetValue)
    }

    var isSevenDigitSelection: Bool {
        (1_000_000...9_999_999).contains(selectedNumber)
    }
}

enum CalculatorOperation: String, Hashable {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"
}

struct MagicCalculator {
    private(set) var display = "0"
    private(set) var activeTrickPlan: MagicTrickPlan?

    private var currentInput = "0"
    private var storedValue: Double?
    private var pendingOperation: CalculatorOperation?
    private var startsNewInput = true
    private var clearTapStreak = 0
    private var isTrickArmed = false
    private var trickAddOperandCount = 0
    private var trickRunningSum = 0
    private var hasStartedMagicTerm = false
    private var magicTermDigits: [Character] = []
    private var nextMagicDigitIndex = 0

    var isArmed: Bool {
        isTrickArmed
    }

    var statusText: String? {
        guard let activeTrickPlan else { return nil }

        if activeTrickPlan.isSevenDigitSelection {
            return activeTrickPlan.usesNextMinute ? "Next minute" : "This minute"
        }

        return "Needs reset"
    }

    var debugStateText: String {
        let activeText = isTrickArmed ? "active" : "inactive"
        return "Trick: \(activeText) | Term: \(currentTermNumber) | Sum: \(trickRunningSum)"
    }

    func debugPlanText(now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard isTrickArmed, pendingOperation == .add, trickAddOperandCount >= 2 else {
            return nil
        }

        let plan = activeTrickPlan ?? Self.makeTrickPlan(currentSum: trickRunningSum, now: now, calendar: calendar)
        return "Secret: \(plan.selectedNumberText) | Final: \(plan.targetValueText)"
    }

    mutating func tapDigit(_ digit: String, now: Date = Date(), calendar: Calendar = .current) {
        guard digit.count == 1, digit.allSatisfy(\.isNumber) else { return }

        clearTapStreak = 0

        if shouldEnterMagicDigit {
            enterNextMagicDigit(now: now, calendar: calendar)
            return
        }

        enterVisibleDigit(digit)
    }

    mutating func tapDecimal() {
        clearTapStreak = 0

        if startsNewInput {
            currentInput = "0."
            startsNewInput = false
        } else if !currentInput.contains(".") {
            currentInput.append(".")
        }

        display = currentInput
    }

    mutating func tapOperation(_ operation: CalculatorOperation) {
        clearTapStreak = 0

        if !startsNewInput {
            recordTrickOperandIfNeeded(for: operation)
            evaluatePendingOperation()
        } else if storedValue == nil {
            storedValue = currentValue
        }

        pendingOperation = operation
        startsNewInput = true
    }

    mutating func tapEquals() {
        clearTapStreak = 0
        evaluatePendingOperation()
        pendingOperation = nil
        startsNewInput = true
        resetTrickStateAfterResult()
    }

    mutating func tapClear() {
        clearTapStreak += 1

        if clearTapStreak >= 3 {
            resetAll()
            isTrickArmed = true
            clearTapStreak = 3
            return
        }

        if startsNewInput || currentInput == "0" {
            resetAll(keepClearStreak: true)
        } else {
            currentInput = "0"
            display = "0"
            startsNewInput = true
        }
    }

    mutating func tapToggleSign() {
        clearTapStreak = 0

        if currentInput.hasPrefix("-") {
            currentInput.removeFirst()
        } else if currentInput != "0" {
            currentInput = "-" + currentInput
        }

        display = currentInput
    }

    mutating func tapPercent() {
        clearTapStreak = 0
        let percentValue = currentValue / 100
        currentInput = Self.format(percentValue)
        display = currentInput
    }

    private var currentValue: Double {
        Double(currentInput) ?? 0
    }

    private var currentTermNumber: Int {
        if !isTrickArmed {
            return 1
        }

        return min(trickAddOperandCount + (startsNewInput ? 1 : 1), 3)
    }

    private var shouldEnterMagicDigit: Bool {
        isTrickArmed &&
        pendingOperation == .add &&
        trickAddOperandCount == 2 &&
        (startsNewInput || hasStartedMagicTerm)
    }

    private mutating func enterVisibleDigit(_ digit: String) {
        if startsNewInput {
            currentInput = digit == "0" ? "0" : digit
            startsNewInput = false
        } else if currentInput == "0" {
            currentInput = digit
        } else {
            currentInput.append(digit)
        }

        display = currentInput
    }

    private mutating func enterNextMagicDigit(now: Date, calendar: Calendar) {
        if !hasStartedMagicTerm {
            let plan = Self.makeTrickPlan(currentSum: trickRunningSum, now: now, calendar: calendar)
            activeTrickPlan = plan
            magicTermDigits = Array(plan.selectedNumberText)
            nextMagicDigitIndex = 0
            currentInput = "0"
            startsNewInput = true
            hasStartedMagicTerm = true
        }

        guard nextMagicDigitIndex < magicTermDigits.count else { return }

        let chosenDigit = String(magicTermDigits[nextMagicDigitIndex])
        nextMagicDigitIndex += 1
        enterVisibleDigit(chosenDigit)
    }

    private mutating func recordTrickOperandIfNeeded(for operation: CalculatorOperation) {
        guard isTrickArmed, operation == .add, !hasStartedMagicTerm else { return }
        guard let integerValue = Int(currentInput), String(abs(integerValue)).count == 6 else { return }

        trickRunningSum += integerValue
        trickAddOperandCount += 1
    }

    private mutating func evaluatePendingOperation() {
        guard let operation = pendingOperation, let storedValue else {
            storedValue = currentValue
            display = Self.format(currentValue)
            return
        }

        let result: Double
        switch operation {
        case .add:
            result = storedValue + currentValue
        case .subtract:
            result = storedValue - currentValue
        case .multiply:
            result = storedValue * currentValue
        case .divide:
            result = currentValue == 0 ? .nan : storedValue / currentValue
        }

        self.storedValue = result.isFinite ? result : nil
        currentInput = result.isFinite ? Self.format(result) : "Error"
        display = currentInput
    }

    private mutating func resetAll(keepClearStreak: Bool = false) {
        let streak = clearTapStreak
        display = "0"
        currentInput = "0"
        storedValue = nil
        pendingOperation = nil
        startsNewInput = true
        isTrickArmed = false
        trickAddOperandCount = 0
        trickRunningSum = 0
        hasStartedMagicTerm = false
        magicTermDigits = []
        nextMagicDigitIndex = 0
        activeTrickPlan = nil
        clearTapStreak = keepClearStreak ? streak : 0
    }

    private mutating func resetTrickStateAfterResult() {
        isTrickArmed = false
        trickAddOperandCount = 0
        trickRunningSum = 0
        hasStartedMagicTerm = false
        magicTermDigits = []
        nextMagicDigitIndex = 0
    }

    static func makeTrickPlan(currentSum: Int, now: Date, calendar: Calendar = .current) -> MagicTrickPlan {
        let second = calendar.component(.second, from: now)
        let secondsRemaining = 60 - second
        let usesCurrentMinute = secondsRemaining > 30
        let targetDate = usesCurrentMinute ? now : calendar.date(byAdding: .minute, value: 1, to: now) ?? now
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: targetDate)
        let targetValue = (components.month ?? 0) * 1_000_000
            + (components.day ?? 0) * 10_000
            + (components.hour ?? 0) * 100
            + (components.minute ?? 0)

        return MagicTrickPlan(
            targetValue: targetValue,
            selectedNumber: targetValue - currentSum,
            targetDate: targetDate,
            usesNextMinute: !usesCurrentMinute
        )
    }

    private static func format(_ value: Double) -> String {
        guard value.isFinite else { return "Error" }

        if value.rounded() == value {
            return String(Int(value))
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
