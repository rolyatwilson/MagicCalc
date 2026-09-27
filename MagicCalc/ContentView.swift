//
//  ContentView.swift
//  MagicCalc
//
//  Created by Taylor Wilson on 9/27/26.
//

import SwiftUI

struct ContentView: View {
    @State private var calculator = MagicCalculator()
    @State private var handledCancellationToken = 0
    @State private var cancellationClearTask: Task<Void, Never>?

    private let portraitRows: [[CalculatorKey]] = [
        [.backspace, .clear, .percent, .operation(.divide)],
        [.digit("7"), .digit("8"), .digit("9"), .operation(.multiply)],
        [.digit("4"), .digit("5"), .digit("6"), .operation(.subtract)],
        [.digit("1"), .digit("2"), .digit("3"), .operation(.add)],
        [.toggleSign, .digit("0"), .decimal, .equals]
    ]

    private let landscapeRows: [[CalculatorKey]] = [
        [.digit("7"), .digit("8"), .digit("9"), .backspace, .operation(.divide)],
        [.digit("4"), .digit("5"), .digit("6"), .clear, .operation(.multiply)],
        [.digit("1"), .digit("2"), .digit("3"), .percent, .operation(.subtract)],
        [.toggleSign, .digit("0"), .decimal, .equals, .operation(.add)]
    ]

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                Color.black.ignoresSafeArea()

                if isLandscape {
                    landscapeContent
                } else {
                    portraitContent
                }

                armedIndicator
            }
        }
        .onChange(of: calculator.cancellationToken) { _, _ in
            scheduleCancellationIndicatorClear()
        }
    }

    private var portraitContent: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 24)
            display
            portraitKeypad
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private var landscapeContent: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 56
            let bottomPadding: CGFloat = 18
            let keypadSpacing: CGFloat = 12
            let availableWidth = max(0, proxy.size.width - horizontalPadding * 2)
            let buttonWidth = (availableWidth - keypadSpacing * 4) / 5
            let buttonHeight = min((proxy.size.height - 122 - bottomPadding - keypadSpacing * 3) / 4, buttonWidth * 0.38)
            let keypadHeight = buttonHeight * 4 + keypadSpacing * 3

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                displayView(minHeight: 92, mainFontSize: 68, mainFallbackFontSizes: [56, 46, 38])
                    .padding(.horizontal, horizontalPadding)

                Spacer(minLength: 18)

                keypad(rows: landscapeRows, spacing: keypadSpacing, buttonSize: CGSize(width: buttonWidth, height: buttonHeight), fontScale: 0.78)
                    .frame(width: availableWidth, height: keypadHeight)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
    }

    private var armedIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 6, height: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 10)
            .padding(.leading, 10)
            .accessibilityHidden(calculator.indicatorState == .none)
            .accessibilityLabel(indicatorAccessibilityLabel)
    }

    private var indicatorColor: Color {
        switch calculator.indicatorState {
        case .none:
            return .clear
        case .armed:
            return .green
        case .capturingSecret:
            return .yellow
        case .cancelled:
            return .red
        }
    }

    private var indicatorAccessibilityLabel: String {
        switch calculator.indicatorState {
        case .none:
            return ""
        case .armed:
            return "Trick active"
        case .capturingSecret:
            return "Secret input active"
        case .cancelled:
            return "Trick cancelled"
        }
    }

    #if DEBUG
    // Hidden for now. Keep this debug panel handy while tuning the trick math;
    // it shows armed state, current term, running sum, secret term, and target output.
    // To show it again, place debugPanel in the root VStack above Spacer.
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
        displayView()
    }

    private func displayView(
        minHeight: CGFloat = 142,
        mainFontSize: CGFloat = 82,
        mainFallbackFontSizes: [CGFloat] = [64, 54, 46]
    ) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let secondaryDisplay = calculator.secondaryDisplay {
                DisplayLine(
                    text: secondaryDisplay,
                    fontSize: 24,
                    fallbackFontSizes: [20, 17, 14],
                    weight: .regular,
                    color: Color(.systemGray2)
                )
                .accessibilityLabel("Calculator expression")
                .accessibilityValue(secondaryDisplay)
            }

            DisplayLine(
                text: calculator.display,
                fontSize: mainFontSize,
                fallbackFontSizes: mainFallbackFontSizes,
                weight: .light,
                color: .white
            )
            .accessibilityLabel("Calculator display")
            .accessibilityValue(calculator.display)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottomTrailing)
    }

    private var portraitKeypad: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 12
            let buttonSize = (proxy.size.width - spacing * 3) / 4

            keypad(rows: portraitRows, spacing: spacing, buttonSize: CGSize(width: buttonSize, height: buttonSize))
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .aspectRatio(0.79, contentMode: .fit)
    }

    private func keypad(rows: [[CalculatorKey]], spacing: CGFloat, buttonSize: CGSize, fontScale: CGFloat = 1) -> some View {
        VStack(spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { key in
                        CalculatorButton(key: key, titleOverride: titleOverride(for: key), fontScale: fontScale) {
                            tap(key)
                        }
                        .frame(width: buttonSize.width, height: buttonSize.height)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func tap(_ key: CalculatorKey) {
        if calculator.isCapturingSecretInput {
            calculator.tapSecretInput()
            return
        }

        switch key {
        case .digit(let digit):
            calculator.tapDigit(digit)
        case .decimal:
            calculator.tapDecimal()
        case .backspace:
            calculator.tapBackspace()
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

    private func titleOverride(for key: CalculatorKey) -> String? {
        if key == .clear {
            return calculator.clearButtonTitle
        }

        return nil
    }

    private func scheduleCancellationIndicatorClear() {
        let token = calculator.cancellationToken
        guard token > 0, token != handledCancellationToken else { return }

        handledCancellationToken = token
        cancellationClearTask?.cancel()
        cancellationClearTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))

            if calculator.cancellationToken == token {
                calculator.clearCancellationIndicator()
            }
        }
    }
}

private enum CalculatorKey: Hashable {
    case digit(String)
    case decimal
    case backspace
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
        case .backspace:
            return "delete.left"
        case .clear:
            return "AC"
        case .toggleSign:
            return "plus.forwardslash.minus"
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
        case .backspace, .clear, .percent:
            return Color(red: 0.361, green: 0.361, blue: 0.373)
        case .operation, .equals:
            return Color(red: 1.0, green: 0.584, blue: 0.0)
        case .digit, .decimal, .toggleSign:
            return Color(red: 0.165, green: 0.165, blue: 0.173)
        }
    }

    var foregroundColor: Color {
        .white
    }

    var borderColor: Color {
        switch self {
        case .operation, .equals:
            return Color(red: 1.0, green: 0.72, blue: 0.27)
        case .backspace, .clear, .percent:
            return Color(red: 0.63, green: 0.63, blue: 0.64)
        case .digit, .decimal, .toggleSign:
            return Color(red: 0.38, green: 0.38, blue: 0.39)
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .operation, .equals:
            return 37.5
        case .backspace:
            return 34
        case .toggleSign:
            return 33
        case .percent:
            return 34.65
        case .clear:
            return 31.35
        case .decimal:
            return 38
        default:
            return 38
        }
    }

    var systemImageName: String? {
        switch self {
        case .backspace:
            return "delete.left"
        case .toggleSign:
            return "plus.forwardslash.minus"
        case .operation(.add):
            return "plus"
        case .operation(.subtract):
            return "minus"
        case .operation(.multiply):
            return "multiply"
        case .operation(.divide):
            return "divide"
        case .equals:
            return "equal"
        default:
            return nil
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .backspace:
            return "Backspace"
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
        1
    }
}

private struct DisplayLine: View {
    let text: String
    let fontSize: CGFloat
    let fallbackFontSizes: [CGFloat]
    let weight: Font.Weight
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                ViewThatFits(in: .horizontal) {
                    line(size: fontSize)

                    ForEach(fallbackFontSizes, id: \.self) { size in
                        line(size: size)
                    }
                }
                .frame(width: proxy.size.width, alignment: .trailing)
            }
            .frame(width: proxy.size.width, alignment: .trailing)
            .clipped()
        }
        .frame(height: fontSize)
    }

    private func line(size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .default))
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .monospacedDigit()
    }
}

private struct CalculatorButton: View {
    let key: CalculatorKey
    let titleOverride: String?
    let fontScale: CGFloat
    let action: () -> Void

    init(key: CalculatorKey, titleOverride: String? = nil, fontScale: CGFloat = 1, action: @escaping () -> Void) {
        self.key = key
        self.titleOverride = titleOverride
        self.fontScale = fontScale
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            buttonContent
                .font(.system(size: key.fontSize * fontScale, weight: .regular, design: .default))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(key.backgroundColor)
                .foregroundStyle(key.foregroundColor)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(key.borderColor, lineWidth: 1)
                }
        }
        .buttonStyle(CalculatorPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if key == .clear, titleOverride == "C" {
            return "Clear"
        }

        return key.accessibilityLabel
    }

    @ViewBuilder
    private var buttonContent: some View {
        if let systemImageName = key.systemImageName {
            Image(systemName: systemImageName)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            Text(titleOverride ?? key.title)
        }
    }
}

private struct CalculatorPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.22 : 0))
            }
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct ContentViewPreview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
