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

enum TrickIndicatorState: Equatable {
    case none
    case armed
    case capturingSecret
    case cancelled
}

struct MagicCalculator {
    private(set) var display = "0"
    private(set) var secondaryDisplay: String?
    private(set) var activeTrickPlan: MagicTrickPlan?
    private(set) var cancellationToken = 0

    private var currentInput = "0"
    private var expressionValues: [Double] = []
    private var expressionTerms: [String] = []
    private var expressionOperations: [CalculatorOperation] = []
    private var pendingOperation: CalculatorOperation?
    private var startsNewInput = true
    private var clearTapStreak = 0
    private var isTrickArmed = false
    private var trickAddOperandCount = 0
    private var trickRunningSum = 0
    private var hasStartedMagicTerm = false
    private var magicTermDigits: [Character] = []
    private var nextMagicDigitIndex = 0
    private var isCancellationIndicatorVisible = false

    var indicatorState: TrickIndicatorState {
        if isCancellationIndicatorVisible {
            return .cancelled
        }

        guard isTrickArmed else {
            return .none
        }

        return isCapturingSecretInput ? .capturingSecret : .armed
    }

    var isCapturingSecretInput: Bool {
        isTrickArmed &&
        pendingOperation == .add &&
        trickAddOperandCount == 2 &&
        !isMagicTermComplete
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

        if isCapturingSecretInput {
            tapSecretInput(now: now, calendar: calendar)
            return
        }

        enterVisibleDigit(digit)
    }

    mutating func tapSecretInput(now: Date = Date(), calendar: Calendar = .current) {
        guard isCapturingSecretInput else { return }
        clearTapStreak = 0
        enterNextMagicDigit(now: now, calendar: calendar)
    }

    mutating func tapDecimal() {
        if isCapturingSecretInput {
            tapSecretInput()
            return
        }

        clearTapStreak = 0

        guard !cancelIfTrickCannotUseNonAddInput() else { return }

        if startsNewInput {
            currentInput = "0."
            startsNewInput = false
        } else if !currentInput.contains(".") {
            currentInput.append(".")
        }

        updateDisplayForCurrentExpression()
        cancelIfVisibleTrickInputIsTooLong()
    }

    mutating func tapOperation(_ operation: CalculatorOperation) {
        if isCapturingSecretInput {
            tapSecretInput()
            return
        }

        clearTapStreak = 0

        if isTrickArmed, trickAddOperandCount < 2, operation != .add {
            cancelTrick()
            return
        }

        secondaryDisplay = nil

        if startsNewInput {
            if !expressionValues.isEmpty {
                replaceLastOperation(with: operation)
            }
        } else {
            recordTrickOperandIfNeeded(for: operation)
            guard !isCancellationIndicatorVisible else { return }
            appendCurrentInputToExpression()
        }

        pendingOperation = operation
        startsNewInput = true
        updateDisplayForCurrentExpression()
    }

    mutating func tapEquals() {
        if isCapturingSecretInput {
            tapSecretInput()
            return
        }

        clearTapStreak = 0

        guard !cancelIfTrickCannotUseNonAddInput() else { return }

        if !startsNewInput {
            appendCurrentInputToExpression()
        }

        guard !expressionValues.isEmpty else {
            updateDisplayForCurrentExpression()
            return
        }

        let result = evaluateExpression()
        secondaryDisplay = expressionResultText()
        currentInput = result.isFinite ? Self.rawString(result) : "Error"
        display = result.isFinite ? Self.formatNumberText(currentInput) : "Error"
        pendingOperation = nil
        startsNewInput = true
        resetExpression(keepingCurrentInput: true)
        resetTrickStateAfterResult()
    }

    mutating func tapClear() {
        if isCapturingSecretInput {
            tapSecretInput()
            return
        }

        clearTapStreak += 1

        if clearTapStreak >= 3 {
            resetAll()
            isTrickArmed = true
            clearTapStreak = 3
            return
        }

        guard !cancelIfTrickCannotUseNonAddInput() else { return }

        if startsNewInput || currentInput == "0" {
            resetAll(keepClearStreak: true)
        } else {
            currentInput = "0"
            startsNewInput = true
            updateDisplayForCurrentExpression()
        }
    }

    mutating func tapToggleSign() {
        if isCapturingSecretInput {
            tapSecretInput()
            return
        }

        clearTapStreak = 0

        guard !cancelIfTrickCannotUseNonAddInput() else { return }

        if currentInput.hasPrefix("-") {
            currentInput.removeFirst()
        } else if currentInput != "0" {
            currentInput = "-" + currentInput
        }

        updateDisplayForCurrentExpression()
        cancelIfVisibleTrickInputIsTooLong()
    }

    mutating func tapPercent() {
        if isCapturingSecretInput {
            tapSecretInput()
            return
        }

        clearTapStreak = 0

        guard !cancelIfTrickCannotUseNonAddInput() else { return }

        let percentValue = currentValue / 100
        currentInput = Self.rawString(percentValue)
        updateDisplayForCurrentExpression()
        cancelIfVisibleTrickInputIsTooLong()
    }

    mutating func clearCancellationIndicator() {
        isCancellationIndicatorVisible = false
    }

    private var currentValue: Double {
        Double(currentInput) ?? 0
    }

    private var currentTermNumber: Int {
        if !isTrickArmed {
            return 1
        }

        return min(trickAddOperandCount + 1, 3)
    }

    private var isMagicTermComplete: Bool {
        hasStartedMagicTerm && nextMagicDigitIndex >= magicTermDigits.count
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

        secondaryDisplay = nil
        updateDisplayForCurrentExpression()
        cancelIfVisibleTrickInputIsTooLong()
    }

    private mutating func enterNextMagicDigit(now: Date, calendar: Calendar) {
        if !hasStartedMagicTerm {
            let plan = Self.makeTrickPlan(currentSum: trickRunningSum, now: now, calendar: calendar)
            guard plan.isSevenDigitSelection else {
                cancelTrick()
                return
            }

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
        enterSecretDigit(chosenDigit)
    }

    private mutating func enterSecretDigit(_ digit: String) {
        if startsNewInput {
            currentInput = digit
            startsNewInput = false
        } else {
            currentInput.append(digit)
        }

        updateDisplayForCurrentExpression()
    }

    private mutating func appendCurrentInputToExpression() {
        if !expressionValues.isEmpty, let pendingOperation {
            expressionOperations.append(pendingOperation)
        }

        expressionValues.append(currentValue)
        expressionTerms.append(currentInput)
    }

    private mutating func replaceLastOperation(with operation: CalculatorOperation) {
        if expressionOperations.isEmpty {
            pendingOperation = operation
        } else {
            expressionOperations[expressionOperations.count - 1] = operation
        }
    }

    private mutating func recordTrickOperandIfNeeded(for operation: CalculatorOperation) {
        guard isTrickArmed, operation == .add, !hasStartedMagicTerm else { return }
        guard let integerValue = Int(currentInput) else { return }

        trickRunningSum += integerValue
        trickAddOperandCount += 1
    }

    private mutating func updateDisplayForCurrentExpression() {
        display = expressionText(includePendingInput: !startsNewInput)
    }

    private func expressionText(includePendingInput: Bool) -> String {
        var parts: [String] = []

        for index in expressionTerms.indices {
            parts.append(Self.formatNumberText(expressionTerms[index]))

            if index < expressionOperations.count {
                parts.append(expressionOperations[index].rawValue)
            } else if index == expressionTerms.count - 1, let pendingOperation {
                parts.append(pendingOperation.rawValue)
            }
        }

        if includePendingInput {
            parts.append(Self.formatNumberText(currentInput))
        }

        return parts.isEmpty ? Self.formatNumberText(currentInput) : parts.joined(separator: " ")
    }

    private func expressionResultText() -> String {
        var parts: [String] = []

        for index in expressionTerms.indices {
            parts.append(Self.formatNumberText(expressionTerms[index]))

            if index < expressionOperations.count {
                parts.append(expressionOperations[index].rawValue)
            }
        }

        return parts.isEmpty ? Self.formatNumberText(currentInput) : parts.joined(separator: " ")
    }

    private func evaluateExpression() -> Double {
        guard var result = expressionValues.first else { return currentValue }

        for index in expressionOperations.indices {
            guard index + 1 < expressionValues.count else { break }

            let value = expressionValues[index + 1]
            switch expressionOperations[index] {
            case .add:
                result += value
            case .subtract:
                result -= value
            case .multiply:
                result *= value
            case .divide:
                result = value == 0 ? .nan : result / value
            }
        }

        return result
    }

    @discardableResult
    private mutating func cancelIfTrickCannotUseNonAddInput() -> Bool {
        guard isTrickArmed, trickAddOperandCount < 2 else { return false }
        cancelTrick()
        return true
    }

    private mutating func cancelIfVisibleTrickInputIsTooLong() {
        guard isTrickArmed, trickAddOperandCount < 2, !startsNewInput else { return }
        let digitCount = currentInput.filter(\.isNumber).count

        if digitCount > 6 {
            cancelTrick()
        }
    }

    private mutating func cancelTrick() {
        isTrickArmed = false
        trickAddOperandCount = 0
        trickRunningSum = 0
        hasStartedMagicTerm = false
        magicTermDigits = []
        nextMagicDigitIndex = 0
        activeTrickPlan = nil
        isCancellationIndicatorVisible = true
        cancellationToken += 1
    }

    private mutating func resetAll(keepClearStreak: Bool = false) {
        let streak = clearTapStreak
        display = "0"
        secondaryDisplay = nil
        currentInput = "0"
        pendingOperation = nil
        startsNewInput = true
        resetExpression(keepingCurrentInput: true)
        isTrickArmed = false
        trickAddOperandCount = 0
        trickRunningSum = 0
        hasStartedMagicTerm = false
        magicTermDigits = []
        nextMagicDigitIndex = 0
        activeTrickPlan = nil
        isCancellationIndicatorVisible = false
        clearTapStreak = keepClearStreak ? streak : 0
    }

    private mutating func resetExpression(keepingCurrentInput: Bool) {
        expressionValues = []
        expressionTerms = []
        expressionOperations = []

        if !keepingCurrentInput {
            currentInput = "0"
        }
    }

    private mutating func resetTrickStateAfterResult() {
        isTrickArmed = false
        trickAddOperandCount = 0
        trickRunningSum = 0
        hasStartedMagicTerm = false
        magicTermDigits = []
        nextMagicDigitIndex = 0
        activeTrickPlan = nil
        isCancellationIndicatorVisible = false
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

    private static func formatNumberText(_ text: String) -> String {
        guard text != "Error", let value = Double(text) else { return text }
        return format(value, keepsTrailingDecimal: text.hasSuffix("."))
    }

    private static func rawString(_ value: Double) -> String {
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

    private static func format(_ value: Double, keepsTrailingDecimal: Bool = false) -> String {
        guard value.isFinite else { return "Error" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = true
        let formatted = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return keepsTrailingDecimal ? formatted + "." : formatted
    }
}
