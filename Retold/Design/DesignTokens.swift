import SwiftUI

/// House-style tokens (brand/HOUSE-STYLE.md), the same values StoryCue ships, until the shared
/// SwiftUI package exists. The accent is the family line's terracotta (AccentColor asset).
enum DesignTokens {
    enum Spacing {           // multiples of 4
        static let s: CGFloat = 8
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let card: CGFloat = 12
    }
    /// Text and symbols on an accent fill (white in light mode, near-black in dark).
    static let onAccent = Color("OnAccent")
    /// The live-recording dot: system red, kept apart from the accent so "recording" never reads as "tap me".
    static let recordingDot = Color.red
    static let recordingDotSize: CGFloat = 20
}

extension View {
    /// The one filled primary action of a screen: full width, large, accent fill, OnAccent label
    /// (house style rule 11). Apply to a Button.
    func primaryAction() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .foregroundStyle(DesignTokens.onAccent)
    }

    /// Full-width bar for a screen's primary action, pinned in thumb reach above the home indicator.
    func primaryActionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignTokens.Spacing.s) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.l)
            .padding(.vertical, DesignTokens.Spacing.s)
            .background(.bar)
        }
    }
}

/// comeup run 2, V1 (Perry's pick; BoardBound OptionButton.tsx:71): a custom row button gets a
/// press state, a quick spring to 0.97 and back. Reduce Motion keeps only the dimming.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration)
    }

    private struct PressableBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.8 : 1)
                .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.3), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressableRowStyle {
    static var pressable: PressableRowStyle { PressableRowStyle() }
}
