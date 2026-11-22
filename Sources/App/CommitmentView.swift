import FreedomFromKit
import SwiftUI

/// One running commitment: its countdown, what it blocks once revealed, and
/// the way to unlock it early when a code is set (ADR 0012).
struct CommitmentView: View {
    @Bindable var model: AppModel
    let id: UUID

    @State private var unlocking = false

    private var commitment: Commitment? { model.record.commitments.first { $0.id == id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let commitment {
                TimelineView(.periodic(from: .now, by: 1)) { tick in
                    Text(Countdown.ticking(until: commitment.deadline, from: tick.date))
                        .font(.system(size: 64, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(Quiet.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(.top, 40)

                Text(
                    "until \(commitment.deadline.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))"
                )
                .whisper()
                .padding(.top, 6)

                contents(of: commitment)
                    .padding(.top, 28)

                Spacer()

                if model.record.unlockCode != nil {
                    QuietButton(title: "Unlock early") { unlocking = true }
                }
            }
        }
        .quietScreen()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $unlocking) {
            UnlockSheet(model: model, id: id)
        }
    }

    @ViewBuilder
    private func contents(of commitment: Commitment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.contentsRevealed {
                let coverage = model.statedCoverage(of: commitment)
                line(
                    ChosenTargets(apps: commitment.namedHandles.count)
                        .words(alsoDomains: commitment.domains.count),
                    trailing: "\(coverage.resolved) of \(coverage.named) covered")
                ForEach(commitment.domains, id: \.host) { domain in
                    line(domain.host, colour: Quiet.until)
                }
            } else {
                Button {
                    Task { await model.revealContents() }
                } label: {
                    line("contents hidden", trailing: "show", colour: Quiet.whisper)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Quiet.hairline).frame(height: 1) }
    }

    private func line(_ text: String, trailing: String? = nil, colour: Color = Quiet.ink)
        -> some View
    {
        HStack {
            Text(text).foregroundStyle(colour)
            Spacer()
            if let trailing { Text(trailing).foregroundStyle(Quiet.link) }
        }
        .font(.system(size: 15, weight: .light))
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Quiet.hairline).frame(height: 1) }
    }
}

/// Ends one commitment early: the code on the pad, then a hold, because this
/// cannot be undone either (ADR 0007). The others keep running.
private struct UnlockSheet: View {
    @Bindable var model: AppModel
    let id: UUID

    @State private var code = ""
    @State private var refused = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Quiet.quieted)
                Spacer()
            }

            Text("Unlock this one early.")
                .say()
                .padding(.top, 24)

            Text(
                refused
                    ? "That is not the unlock code."
                    : "It ends now and is written down as unlocked. The others keep running."
            )
            .whisper()
            .multilineTextAlignment(.center)
            .padding(.top, 10)

            CodePad(code: $code)
                .padding(.top, 28)

            Spacer(minLength: 20)

            if code.count == CodePad.length {
                HoldToConfirm(title: "hold to unlock", duration: 3) {
                    let typed = code
                    Task {
                        if await model.unlock(id, code: typed) {
                            dismiss()
                        } else {
                            refused = true
                            code = ""
                        }
                    }
                }
            } else {
                Color.clear.frame(height: 58)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Quiet.background)
        .preferredColorScheme(.dark)
    }
}
