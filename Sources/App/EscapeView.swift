import SwiftUI

/// Four lines, and then it stops.
///
/// The product does not defend itself here, knowingly: the one moment a user
/// most wants an argument is the moment they get four lines (ADR 0003). What it
/// buys is that the exit is named plainly rather than concealed, which is
/// ADR 0001's stance everywhere else in the app.
///
/// The last line is the honest claim, and no copy anywhere in freedomfrom may
/// exceed it.
struct EscapeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Settings → Screen Time →\nfreedomfrom → revoke.")
                .say()

            Text("That ends it. It takes about fifteen seconds and it will be written down.")
                .whisper()
                .padding(.top, 24)

            Text(
                "Deleting the app does not end it. While it is authorized, no app on this phone can be deleted and the clock is held automatic. Revoking ends both."
            )
            .whisper()
            .padding(.top, 16)

            Text(
                "This resists a casual bypass while it is authorized. It cannot prevent a determined one."
            )
            .whisper()
            .padding(.top, 16)

            Spacer()
        }
        .quietScreen()
        .navigationBarTitleDisplayMode(.inline)
    }
}
