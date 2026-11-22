import FreedomFromKit
import SwiftUI

/// The root while anything runs, and the screen a reinstall lands on: re-arm
/// is not a destination, so it is indistinguishable from any other launch
/// (ADR 0007).
///
/// One row per running commitment, nearest deadline first, each a single tap
/// target that opens it. A row states **coverage**, not what it named at
/// commit time, because that is the substitute for every message the app
/// refuses to show (ADR 0005). What each one blocks stays hidden until Face ID
/// or the device passcode passes; the countdowns never are (ADR 0012).
struct RunningView: View {
    @Bindable var model: AppModel

    enum Spur: Hashable {
        case escape
        case another
        case settings
        case commitment(UUID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Spacer()
                Button {
                    if model.contentsRevealed {
                        model.hideContents()
                    } else {
                        Task { await model.revealContents() }
                    }
                } label: {
                    corner(model.contentsRevealed ? "eye" : "eye.slash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    model.contentsRevealed ? "hide what they block" : "show what they block")

                NavigationLink(value: Spur.settings) { corner("gearshape") }
                    .accessibilityLabel("settings")
            }
            .padding(.trailing, -10)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.running, id: \.id) { commitment in
                        NavigationLink(value: Spur.commitment(commitment.id)) {
                            row(commitment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            NavigationLink(value: Spur.another) {
                Text("Another")
                    .font(.system(size: 15, weight: .light))
                    .tracking(1.5)
                    .foregroundStyle(Quiet.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .overlay(Rectangle().stroke(Quiet.line, lineWidth: 1))
            }
            .padding(.top, 12)

            NavigationLink(value: Spur.escape) {
                Text("there is a way out. it is in Settings.")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Quiet.link)
                    .frame(maxWidth: .infinity, minHeight: 44)
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
                        .padding(.top, 8)
                }
                .buttonStyle(.plain)
            #endif
        }
        .quietScreen()
        .navigationDestination(for: Spur.self) { spur in
            switch spur {
            case .escape: EscapeView()
            case .another: TargetsView(model: model)
            case .settings: SettingsView(model: model)
            case .commitment(let id): CommitmentView(model: model, id: id)
            }
        }
    }

    private func corner(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .light))
            .foregroundStyle(Quiet.quieted)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private func row(_ commitment: Commitment) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                TimelineView(.periodic(from: .now, by: 1)) { tick in
                    Text(Countdown.ticking(until: commitment.deadline, from: tick.date))
                        .font(.system(size: 44, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(Quiet.ink)
                }
                Text("until \(commitment.deadline.formatted(date: .omitted, time: .shortened)) · \(summary(of: commitment))")
                    .whisper()
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Quiet.dim)
        }
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Quiet.hairline).frame(height: 1) }
    }

    private func summary(of commitment: Commitment) -> String {
        guard model.contentsRevealed else { return "contents hidden" }
        let coverage = model.statedCoverage(of: commitment)
        let named = ChosenTargets(apps: commitment.namedHandles.count)
            .words(alsoDomains: commitment.domains.count)
        return "\(named) · \(coverage.resolved) of \(coverage.named) covered"
    }
}
