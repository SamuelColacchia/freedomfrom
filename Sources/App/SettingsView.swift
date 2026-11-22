import FreedomFromKit
import SwiftUI

/// The app's one settings surface, holding the early unlock code (ADR 0012).
///
/// Reachable whether or not anything runs, so the code's state is always one
/// tap away. It can only be set, changed or removed while nothing runs: a code
/// added mid-commitment could unlock that commitment at once, and it would
/// restrain nothing.
struct SettingsView: View {
    @Bindable var model: AppModel

    private enum Step: Equatable {
        case idle
        case current(Purpose)
        case choose(current: String?)
        case confirm(current: String?, first: String)
    }

    private enum Purpose { case change, remove }

    @State private var step = Step.idle
    @State private var code = ""
    @State private var said: String?

    private var hasCode: Bool { model.record.unlockCode != nil }
    private var isRunning: Bool { !model.record.commitments.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Early unlock code")
                .font(.system(size: 12, weight: .regular))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Quiet.whisper)
                .padding(.top, 20)

            Text(hasCode ? "An unlock code is set." : "No unlock code is set.")
                .say()
                .padding(.top, 12)

            Text(
                "One code unlocks any single commitment early. Give it to someone you trust, or keep it somewhere you will not reach for."
            )
            .whisper()
            .padding(.top, 8)

            if let said {
                Text(said)
                    .whisper()
                    .padding(.top, 10)
            }

            if isRunning {
                Text("It can be set or changed once nothing is running.")
                    .whisper()
                    .padding(.top, 10)
                Spacer()
            } else if let prompt {
                Text(prompt)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Quiet.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)

                CodePad(code: $code)
                    .padding(.top, 20)

                Spacer()

                Button("Cancel") { reset() }
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Quiet.link)
                    .frame(maxWidth: .infinity, minHeight: 44)
            } else {
                VStack(spacing: 10) {
                    if hasCode {
                        QuietButton(title: "Change code") { begin(.current(.change)) }
                        QuietButton(title: "Remove code") { begin(.current(.remove)) }
                    } else {
                        QuietButton(title: "Set code") { begin(.choose(current: nil)) }
                    }
                }
                .padding(.top, 24)
                Spacer()
            }
        }
        .quietScreen()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: code) { _, typed in
            if typed.count == CodePad.length { entered(typed) }
        }
    }

    private var prompt: String? {
        switch step {
        case .idle: nil
        case .current: "Enter the current code"
        case .choose: "Choose a code"
        case .confirm: "Enter it again"
        }
    }

    private func begin(_ next: Step) {
        said = nil
        code = ""
        step = next
    }

    private func entered(_ typed: String) {
        code = ""
        switch step {
        case .idle:
            return
        case .current(.remove):
            said = model.removeUnlockCode(current: typed) ? "Removed." : "That is not the current code."
            step = .idle
        case .current(.change):
            if model.record.unlockCode?.matches(typed) == true {
                step = .choose(current: typed)
            } else {
                said = "That is not the current code."
                step = .idle
            }
        case .choose(let current):
            step = .confirm(current: current, first: typed)
        case .confirm(let current, let first):
            if typed == first {
                said = model.setUnlockCode(typed, current: current) ? "Saved." : "That did not save."
                step = .idle
            } else {
                said = "Those did not match. Choose a code again."
                step = .choose(current: current)
            }
        }
    }

    private func reset() {
        code = ""
        step = .idle
    }
}
