import FreedomFromKit
import SwiftUI

/// The root while a commitment runs, and the screen a reinstall lands on:
/// re-arm is not a destination, so it is indistinguishable from any other
/// launch (ADR 0007).
///
/// It states **coverage**, not what the commitment named at commit time. That
/// is the substitute for every message the app refuses to show, which makes the
/// count load-bearing rather than cosmetic (ADR 0005).
struct CountdownView: View {
    @Bindable var model: AppModel

    private enum Spur: Hashable {
        case escape
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { tick in
                VStack(spacing: 10) {
                    Text(remaining(at: tick.date))
                        .font(.system(size: 52, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(Quiet.ink)
                    Text(coverageWords)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Quiet.whisper)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()

            NavigationLink(value: Spur.escape) {
                Text("there is a way out. it is in Settings.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Quiet.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
            }

            #if HARDWARE_PASS
                // The second action on the app's most-seen screen, which the
                // one-action invariant forbids — and which is why it is named
                // for the build it belongs to rather than for what it does.
                Button {
                    Task { await model.releaseForHardwarePass() }
                } label: {
                    Text("release · hardware-pass build")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                }
                .buttonStyle(.plain)
            #endif
        }
        .quietScreen()
        .navigationDestination(for: Spur.self) { _ in EscapeView() }
    }

    private func remaining(at now: Date) -> String {
        guard let deadline = model.record.active?.deadline else { return "00:00:00" }
        return Countdown.ticking(until: deadline, from: now)
    }

    private var coverageWords: String {
        let coverage = model.statedCoverage
        return "\(coverage.resolved) of \(coverage.named) covered"
    }
}
