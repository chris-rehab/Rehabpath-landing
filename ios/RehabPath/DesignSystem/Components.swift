import SwiftUI
import RehabPathCore

// Brand colours come from the asset catalog so light/dark variants meet WCAG AA contrast:
// AccentColor  light #9A5800 (5.6:1 on white)   dark #F5A623 (8.4:1 on #1C1C1E)
// OnAccent     light #FFFFFF                     dark #0D1117 (9.3:1 on #F5A623)
extension Color {
    static let onAccent = Color("OnAccent")
}

/// Grouped "card" container used on Today and Progress.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The one prominent action on a screen. Full width, at least 50pt tall, dark-on-orange in dark mode.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color.onAccent)
            .background(
                Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// 0–10 pain picker. A slider is VoiceOver-adjustable and fits any width; the word label
/// means the value is never conveyed by number alone.
struct PainScalePicker: View {
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(value)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("/ 10 · \(Self.describe(value))")
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            Slider(
                value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                in: Double(PainScale.range.lowerBound)...Double(PainScale.range.upperBound),
                step: 1
            ) {
                Text("Pain")
            } minimumValueLabel: {
                Text("0").accessibilityHidden(true)
            } maximumValueLabel: {
                Text("10").accessibilityHidden(true)
            }
            .accessibilityValue("\(value) out of 10, \(Self.describe(value))")

            Text("0 = no pain, 10 = worst imaginable")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    static func describe(_ value: Int) -> String {
        switch value {
        case 0: "No pain"
        case 1...3: "Mild"
        case 4...6: "Moderate"
        case 7...9: "Severe"
        default: "Worst imaginable"
        }
    }
}

/// Non-dismissable reminder that this is a test build, per the content standards
/// in ARCHITECTURE.md §7 ("do not overstate the product's current state").
struct PrototypeNotice: View {
    var body: some View {
        Label {
            Text("Prototype for testing. RehabPath supports your physio's programme — it doesn't diagnose or treat injuries. If you're worried about pain, contact your physio or call Healthline on 0800 611 116.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
