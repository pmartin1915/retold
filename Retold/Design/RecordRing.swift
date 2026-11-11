import SwiftUI

/// The recorder's Stop control (comeup run 3, F2, Perry's pick; StoryCue RecordButton.swift): a ring
/// whose red dot morphs into a stop square once audio is being captured, and shows a spinner while
/// the file is saved. The label under it says what a tap does; VoiceOver hears the same word.
struct RecordRing: View {
    enum Glyph: Equatable {
        case dot        // getting ready: nothing is captured yet
        case square     // recording or paused: a tap stops and saves
        case spinner    // saving
    }

    let glyph: Glyph
    let label: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.25), lineWidth: DesignTokens.RecordRing.ringWidth)
                    switch glyph {
                    case .dot, .square:
                        let isSquare = glyph == .square
                        RoundedRectangle(
                            cornerRadius: isSquare ? DesignTokens.RecordRing.squareRadius : DesignTokens.RecordRing.dot / 2
                        )
                        .fill(DesignTokens.recordingFill)
                        .frame(
                            width: isSquare ? DesignTokens.RecordRing.square : DesignTokens.RecordRing.dot,
                            height: isSquare ? DesignTokens.RecordRing.square : DesignTokens.RecordRing.dot
                        )
                    case .spinner:
                        ProgressView()
                    }
                }
                .frame(width: DesignTokens.RecordRing.outer, height: DesignTokens.RecordRing.outer)
                .contentShape(Circle())
                .animation(reduceMotion ? nil : DesignTokens.Motion.morph, value: glyph)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(label)

            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
