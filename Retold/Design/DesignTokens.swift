import SwiftUI

/// House-style tokens (brand/HOUSE-STYLE.md), the same values StoryCue ships, until the shared
/// SwiftUI package exists. The accent is the family line's terracotta (AccentColor asset).
enum DesignTokens {
    enum Spacing {           // multiples of 4 (StoryCue's values)
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let card: CGFloat = 12
    }
    /// Every animation comes from here (house style rule 8: short, nothing over 0.5 s).
    /// Callers pass nil instead when Reduce Motion is on, or swap a slide for `fade`.
    enum Motion {
        static let morph = Animation.spring(duration: 0.3)
        static let fade = Animation.easeOut(duration: 0.2)
        /// Content that changes in place (a draft, a list, a pill).
        static let change = Animation.smooth(duration: 0.3)
        /// Row press (comeup run 2, V1, Perry's pick; BoardBound OptionButton.tsx:71).
        static let press = Animation.spring(duration: 0.3, bounce: 0.3)
    }
    /// The user's own words (titles, transcripts, live text) in the serif face, as StoryCue sets its
    /// questions (comeup run 3, F1, Perry's pick). Controls, clocks and labels stay in the default face.
    static let wordsFontDesign: Font.Design = .serif
    /// Text and symbols on an accent fill (white in light mode, near-black in dark).
    static let onAccent = Color("OnAccent")
    /// The recording capsule and the stop square: StoryCue's darker-than-system red, so white
    /// text on it clears 4.5:1. Kept apart from the accent so "recording" never reads as "tap me".
    static let recordingFill = Color(red: 0.78, green: 0.10, blue: 0.10)
    /// The length warning: amber with black ink (about 12:1), always paired with words.
    static let warningFill = Color(red: 1.0, green: 0.76, blue: 0.03)
    static let warningInk = Color.black
    /// StoryCue's record ring (comeup run 3, F2, Perry's pick).
    enum RecordRing {
        static let outer: CGFloat = 72
        static let ringWidth: CGFloat = 4
        static let dot: CGFloat = 58
        static let square: CGFloat = 28
        static let squareRadius: CGFloat = 6
    }
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
    /// comeup run 3: a system safe-area bar, so content scrolls under it with the iOS 26 scroll-edge
    /// effect instead of being cut by an opaque strip (house style rule 6).
    func primaryActionBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaBar(edge: .bottom) {
            VStack(spacing: DesignTokens.Spacing.s) {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.l)
            .padding(.vertical, DesignTokens.Spacing.s)
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
                .animation(reduceMotion ? nil : DesignTokens.Motion.press, value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PressableRowStyle {
    static var pressable: PressableRowStyle { PressableRowStyle() }
}
