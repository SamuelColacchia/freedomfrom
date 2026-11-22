import FreedomFromKit
import SwiftUI

/// Sets, changes or removes the one code that unlocks a commitment early
/// (ADR 0012). Reachable only while nothing runs, which is the only time the
/// record accepts a change to it.
struct UnlockCodeView: View {
    @Bindable var model: AppModel

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var said: String?

    private var hasCode: Bool { model.record.unlockCode != nil }

    private var newIsValid: Bool {
        new.count >= UnlockCode.minimumLength && new == confirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text(hasCode ? "An unlock code is set." : "No unlock code is set.")
                .say()

            Text(
                "One code unlocks any single commitment early. Give it to someone you trust, or keep it somewhere you will not reach for. It can be changed only while nothing is running."
            )
            .whisper()
            .padding(.top, 14)

            VStack(spacing: 0) {
                if hasCode { CodeField(placeholder: "current code", text: $current) }
                CodeField(placeholder: "new code", text: $new)
                CodeField(placeholder: "new code again", text: $confirm)
            }
            .padding(.top, 24)

            if let said {
                Text(said)
                    .whisper()
                    .padding(.top, 12)
            }

            Spacer()

            QuietButton(
                title: hasCode ? "Change code" : "Set code",
                enabled: newIsValid && (!hasCode || !current.isEmpty)
            ) {
                let ok = model.setUnlockCode(new, current: hasCode ? current : nil)
                said = ok ? "Saved." : "That is not the current code."
                clear()
            }

            if hasCode {
                QuietButton(title: "Remove code", enabled: !current.isEmpty) {
                    let ok = model.removeUnlockCode(current: current)
                    said = ok ? "Removed." : "That is not the current code."
                    clear()
                }
                .padding(.top, 10)
            }
        }
        .quietScreen()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func clear() {
        current = ""
        new = ""
        confirm = ""
    }
}
