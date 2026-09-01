import FreedomFromKit
import SwiftUI

/// The one screen in the app that spends words, because here the record *is*
/// the statement (ADR 0007).
///
/// ADR 0005's no-voice rule bans announcing anomalies as they happen, on the
/// grounds that a message the user cannot act on is the app arguing. A past
/// record is not an argument — which is why a break is invisible everywhere
/// else and named plainly here.
struct HistoryView: View {
    @Bindable var model: AppModel

    /// A spur is a place you go and come back from (ADR 0007), and this is the
    /// only one that had no way back. The erase empties the screen, and the
    /// link that reached it is gone the moment it does — Targets shows it only
    /// while there is history — so what was left was a screen nothing could
    /// reach, whose one remaining control erased nothing.
    @Environment(\.dismiss) private var dismiss

    /// Fixed, and longer than any commit hold: clean slate buys the largest
    /// irreversible thing in the app and scales with nothing (ADR 0007).
    private let eraseHold: TimeInterval = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.record.history.reversed().enumerated()), id: \.offset) {
                        _, closed in
                        row(closed)
                    }
                }
            }
            .scrollIndicators(.hidden)

            HoldToConfirm(title: "hold to erase", duration: eraseHold) {
                model.cleanSlate()
                dismiss()
            }
            .padding(.top, 20)
        }
        .quietScreen()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ closed: ClosedCommitment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(what(closed))
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Quiet.ink)

            Text("\(span(closed)) · \(words(for: closed.outcome))")
                .whisper()

            if !closed.domains.isEmpty {
                Text(closed.domains.map(\.host).joined(separator: " · "))
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Quiet.faint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Quiet.hairline).frame(height: 1) }
    }

    private func what(_ closed: ClosedCommitment) -> String {
        let parts = [
            count(closed.namedTargetCount, "app"),
            count(closed.domains.count, "website"),
        ].compactMap { $0 }
        return parts.isEmpty ? "Nothing" : parts.joined(separator: " and ")
    }

    private func count(_ n: Int, _ noun: String) -> String? {
        n == 0 ? nil : "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    private func span(_ closed: ClosedCommitment) -> String {
        let day = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(closed.startedAt.formatted(day)) to \(closed.deadline.formatted(day))"
    }

    /// All three outcomes are named rather than encoded. Degraded reads as a
    /// coverage fact — what was lost — rather than as a verdict that something
    /// went wrong, which keeps the app from scolding while still recording.
    private func words(for outcome: Outcome) -> String {
        switch outcome {
        case .completed: "Completed."
        case .completedDegraded: "Completed. Coverage was lost along the way."
        case .broken: "Broken."
        }
    }
}
