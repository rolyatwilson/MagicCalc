//
//  ContentView.swift
//  MagicCalc
//
//  Created by Taylor Wilson on 9/27/26.
//

import SwiftUI

struct ContentView: View {
    @State private var calculator = MagicCalculator()

    private let rows: [[CalculatorKey]] = [
        [.clear, .toggleSign, .percent, .operation(.divide)],
        [.digit("7"), .digit("8"), .digit("9"), .operation(.multiply)],
        [.digit("4"), .digit("5"), .digit("6"), .operation(.subtract)],
        [.digit("1"), .digit("2"), .digit("3"), .operation(.add)],
        [.digit("0"), .decimal, .equals]
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer(minLength: 24)
                display
                keypad
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)

            armedIndicator
        }
    }

    private var armedIndicator: some View {
        Circle()
            .fill(calculator.isArmed ? Color.green : Color.clear)
            .frame(width: 6, height: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 10)
            .padding(.leading, 10)
            .accessibilityHidden(!calculator.isArmed)
            .accessibilityLabel("Trick active")
    }

    #if DEBUG
    // Hidden for now. Keep this debug panel handy while tuning the trick math;
    // it shows armed state, current term, running sum, secret term, and target output.
    private var debugPanel: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(calculator.debugStateText)

                if let planText = calculator.debugPlanText(now: context.date) {
                    Text(planText)
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityIdentifier("debug-panel")
        }
    }
    #endif

    private var display: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(calculator.display)
                .font(.system(size: 82, weight: .light, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("Calculator display")
                .accessibilityValue(calculator.display)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .bottomTrailing)
    }

    private var keypad: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 12
            let buttonSize = (proxy.size.width - spacing * 3) / 4

            VStack(spacing: spacing) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.self) { key in
                            CalculatorButton(key: key) {
                                tap(key)
                            }
                            .frame(
                                width: key.widthMultiplier == 2 ? buttonSize * 2 + spacing : buttonSize,
                                height: buttonSize
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .aspectRatio(0.79, contentMode: .fit)
    }

    private func tap(_ key: CalculatorKey) {
        switch key {
        case .digit(let digit):
            calculator.tapDigit(digit)
        case .decimal:
            calculator.tapDecimal()
        case .clear:
            calculator.tapClear()
        case .toggleSign:
            calculator.tapToggleSign()
        case .percent:
            calculator.tapPercent()
        case .operation(let operation):
            calculator.tapOperation(operation)
        case .equals:
            calculator.tapEquals()
        }
    }
}

private enum CalculatorKey: Hashable {
    case digit(String)
    case decimal
    case clear
    case toggleSign
    case percent
    case operation(CalculatorOperation)
    case equals

    var title: String {
        switch self {
        case .digit(let digit):
            return digit
        case .decimal:
            return "."
        case .clear:
            return "AC"
        case .toggleSign:
            return "+/-"
        case .percent:
            return "%"
        case .operation(let operation):
            return operation.rawValue
        case .equals:
            return "="
        }
    }

    var backgroundColor: Color {
        switch self {
        case .clear, .toggleSign, .percent:
            return Color(.systemGray2)
        case .operation, .equals:
            return .orange
        case .digit, .decimal:
            return Color(.darkGray)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .clear, .toggleSign, .percent:
            return .black
        case .digit, .decimal, .operation, .equals:
            return .white
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .clear:
            return "All Clear"
        case .toggleSign:
            return "Toggle sign"
        case .operation(.add):
            return "Add"
        case .operation(.subtract):
            return "Subtract"
        case .operation(.multiply):
            return "Multiply"
        case .operation(.divide):
            return "Divide"
        case .equals:
            return "Equals"
        case .percent:
            return "Percent"
        case .decimal:
            return "Decimal"
        case .digit(let digit):
            return digit
        }
    }

    var widthMultiplier: CGFloat {
        self == .digit("0") ? 2 : 1
    }
}

private struct CalculatorButton: View {
    let key: CalculatorKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(key.title)
                .font(.system(size: 32, weight: .regular))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(key.backgroundColor)
                .foregroundStyle(key.foregroundColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.accessibilityLabel)
    }
}

struct ContentViewPreview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
