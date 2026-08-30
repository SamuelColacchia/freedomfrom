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
/// There is deliberately no `onLongPressGesture` here.
///
/// It was the obvious way to write this and it does not work. On iOS 18 and
/// later the long-press recogniser reports the press beginning — so
/// `onPressingChanged` fires and the bar fills the whole way — and then never
/// reaches its completion, so `perform` is never called. Apple has the report
/// as FB15711941, still reproducing on 18.3, and the durations this app needs
/// are exactly the ones that fail: the workarounds offered are all in the
/// tenths of a second.
///
/// Two attempts were made to keep the recogniser by tuning `maximumDistance`,
/// first `.infinity` and then a large finite value. Neither changed anything,
/// because the distance was never what was wrong.
///
/// So the recogniser is gone from the path that matters. What replaces it is a
/// zero-distance drag, which is only asked the two questions it answers
/// reliably — the finger is down, the finger is up — and an explicit clock
/// between them. This is what the production hold-to-confirm implementations in
/// the wild do, for this reason.
struct HoldToConfirm: View {
    let title: String
    let duration: TimeInterval
    let action: () -> Void

    @State private var progress: CGFloat = 0

    /// The running hold, and the flag that makes starting one idempotent: a
    /// drag reports every tremor in a thumb, and only the first begins a hold.
    @State private var holding: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .leading) {
            // Scaled rather than sized to a `GeometryReader`'s width, so the
            // fill is one GPU transform on a view whose layout never changes.
            Rectangle()
                .fill(Quiet.ink)
                .scaleEffect(x: progress, anchor: .leading)
            Text(title)
                .font(.system(size: 14, weight: .light))
                .tracking(2.5)
                .textCase(.uppercase)
                .foregroundStyle(Quiet.ink)
                .blendMode(.difference)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 58)
        .overlay(Rectangle().stroke(Quiet.line, lineWidth: 1))
        .contentShape(Rectangle())
        // Two holds exist and never share a screen, so one identifier reaches
        // whichever is on it. `FreedomFromUITests` presses this.
        .accessibilityIdentifier("hold")
        .accessibilityLabel(title)
        // Zero minimum distance, so this is a press and not a swipe — and a
        // drag never cancels itself on movement, which is what the long press
        // needed `maximumDistance` for. A thumb can wander the whole screen.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in begin() }
                .onEnded { _ in end() }
        )
    }

    private func begin() {
        guard holding == nil else { return }

        withAnimation(.linear(duration: duration)) { progress = 1 }
        holding = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            // A cancelled sleep is a hold released early, which is not a
            // failure to report: the bar retreats and nothing has happened.
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func end() {
        holding?.cancel()
        holding = nil
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
    }
}
