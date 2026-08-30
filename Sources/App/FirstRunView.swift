import SwiftUI

/// Shown once, ever, and the only moment informed consent can happen: ADR 0001
/// deliberately provides no setup ritual.
///
/// The collateral sentence is at full weight rather than in whisper type
/// because the device-wide deletion block is the most surprising consequence of
/// committing and was the line most likely to go unread. If a tester ever says
/// they did not know it would stop them deleting other apps, the fix is that
/// sentence and not a new screen.
struct FirstRunView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("This blocks what you choose,\nuntil a time you choose.")
                .say()

            Text("You will not be able to undo it.")
                .say(Quiet.quieted)
                .padding(.top, 18)

            Spacer()

            Text(
                "While it runs, no app on this phone can be deleted — not just this one — and the clock stays automatic."
            )
            .font(.system(size: 16, weight: .light))
            .foregroundStyle(Quiet.ink)
            .lineSpacing(6)

            Text("The way out is in Settings. It is recorded.")
                .whisper()
                .padding(.top, 14)
                .padding(.bottom, 22)

            QuietButton(title: "Begin") {
                Task { await model.beginFromFirstRun() }
            }
        }
        .quietScreen()
    }
}
