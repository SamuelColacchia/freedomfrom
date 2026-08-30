import SwiftUI

/// The one type treatment, and the only place a colour or a size is named.
///
/// ADR 0003 picked one personality outright rather than the best screen from
/// each, so a second treatment anywhere is the decision leaking. The values are
/// transcribed from the prototype's winning variant, which is the primary
/// source for the voice and for nothing else.
enum Quiet {
    static let background = Color(hex: 0x0A_0A_0B)
    static let ink = Color(hex: 0xED_ED_ED)
    static let whisper = Color(hex: 0x6F_6F_72)
    static let dim = Color(hex: 0x55_55_5A)
    /// One step down from the ink, for the second half of a two-part statement.
    static let quieted = Color(hex: 0x8D_8D_90)
    static let faint = Color(hex: 0x4D_4D_51)
    static let line = Color(hex: 0x31_31_34)
    static let hairline = Color(hex: 0x19_1A_1C)
    static let until = Color(hex: 0x9A_9A_9E)

    /// The screen turns light exactly once, when a commitment ends.
    static let endedBackground = Color(hex: 0xF3_F1_EE)
    static let endedInk = Color(hex: 0x1A_1A_1C)
    static let endedLine = Color(hex: 0xD6_D3_CD)
    static let endedWhisper = Color(hex: 0x83_81_7C)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension View {
    /// What the app says. Nothing on any screen is decorative, so there are
    /// exactly two voices: this one and the whisper.
    func say(_ colour: Color = Quiet.ink) -> some View {
        font(.system(size: 20, weight: .light))
            .foregroundStyle(colour)
            .lineSpacing(8)
    }

    func whisper() -> some View {
        font(.system(size: 13, weight: .light))
            .foregroundStyle(Quiet.whisper)
            .lineSpacing(5)
    }

    func quietScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 26)
            .background(Quiet.background)
            .toolbarBackground(Quiet.background, for: .navigationBar)
            .tint(Quiet.whisper)
    }
}

/// The app's one button shape: an outlined rectangle, full width, no fill.
struct QuietButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .light))
                .tracking(1.5)
                .foregroundStyle(Quiet.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .overlay(Rectangle().stroke(Quiet.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
    }
}

/// The only continuous gesture in the app, and it means one thing wherever it
/// appears: this cannot be undone (ADR 0003 as amended by ADR 0007).
///
/// Releasing early is not a failure to report — the fill simply retreats and
/// nothing has happened, which is the same silence every other refused action
/// in the app gets.
struct HoldToConfirm: View {
    let title: String
    let duration: TimeInterval
    let action: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Quiet.ink).frame(width: geometry.size.width * progress)
                Text(title)
                    .font(.system(size: 14, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Quiet.ink)
                    .blendMode(.difference)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay(Rectangle().stroke(Quiet.line, lineWidth: 1))
            .contentShape(Rectangle())
            // `maximumDistance` is deliberately enormous. A five-second hold is
            // long enough that a thumb always drifts, and the default distance
            // cancels the press when it does — which reads as the hold being
            // broken rather than as the finger having moved. SwiftUI owns the
            // timing here, so the fill and the action cannot desync either.
            .onLongPressGesture(minimumDuration: duration, maximumDistance: .infinity) {
                action()
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: duration) : .easeOut(duration: 0.2)) {
                    progress = pressing ? 1 : 0
                }
            }
        }
        .frame(height: 58)
    }
}
