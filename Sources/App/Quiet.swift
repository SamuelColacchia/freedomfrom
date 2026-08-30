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
/// There is deliberately no `onLongPressGesture` here — though not for the
/// reason two earlier commits gave.
///
/// The hold was reported dead twice, both times as "it fills and then nothing".
/// It was blamed first on `maximumDistance: .infinity`, then on FB15711941, the
/// iOS 18 regression where the long-press recogniser reports the press
/// beginning and never reaches its completion. **Both diagnoses were wrong.**
/// The hold had been firing the whole time. `commit()` was holding the screen
/// for the length of six daemon round-trips, and the shield came up minutes
/// later with the button still sitting there — see `AppModel.commit`, which is
/// where the actual fix is.
///
/// The drag stays, on reasons that stand without that story. It is asked only
/// the two questions it answers reliably — the finger is down, the finger is up
/// — so nothing about the completion rides on a recogniser's state machine. It
/// needs no `maximumDistance`, because a drag does not cancel itself when a
/// thumb wanders. And it costs a `GeometryReader`, so the gesture sits on a
/// view whose layout never moves underneath it.
struct HoldToConfirm: View {
    let title: String
    let duration: TimeInterval
    let action: () -> Void

    @State private var progress: CGFloat = 0

    /// The running hold, and the flag that makes starting one idempotent: a
    /// drag reports every tremor in a thumb, and only the first begins a hold.
    @State private var holding: Task<Void, Never>?

    /// When the finger went down, and whether this press has already counted.
    @State private var startedAt: Date?
    @State private var fired = false

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

        startedAt = Date()
        fired = false
        withAnimation(.linear(duration: duration)) { progress = 1 }
        holding = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            // A cancelled sleep is a hold released early, which is not a
            // failure to report: the bar retreats and nothing has happened.
            guard !Task.isCancelled else { return }
            fire()
        }
    }

    private func end() {
        holding?.cancel()
        holding = nil

        // The bar reaches full a frame or two before a sleep armed for the same
        // duration returns, so a thumb lifted *on* the fill lands in between and
        // would cancel a hold that was already long enough. Elapsed time settles
        // it rather than whichever of the two happened to win.
        if let startedAt, Date().timeIntervalSince(startedAt) >= duration { fire() }
        startedAt = nil

        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
    }

    /// Once per press, from whichever of the two paths reaches it first. The
    /// action is irreversible, so arriving twice is not a thing to leave open.
    private func fire() {
        guard !fired else { return }
        fired = true
        action()
    }
}
