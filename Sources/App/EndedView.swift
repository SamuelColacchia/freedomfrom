import SwiftUI

/// The screen turns light and says "Ended."
///
/// It says nothing about *how* it ended. The release can land while the app is
/// closed, so this is drawn on the first launch after it and every launch after
/// that goes straight to Targets. Naming the outcome here would be the app
/// getting the last word (ADR 0007); the history is where the record lives.
struct EndedView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            Text("Ended.")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Quiet.endedInk)
                .frame(maxWidth: .infinity)

            Spacer()

            Button {
                model.acknowledgeEnded()
            } label: {
                Text("Again")
                    .font(.system(size: 15, weight: .light))
                    .tracking(1.5)
                    .foregroundStyle(Quiet.endedInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .overlay(Rectangle().stroke(Quiet.endedLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        .background(Quiet.endedBackground)
        // The only light screen in the app, so the only one whose status bar
        // has to stop being white.
        .preferredColorScheme(.light)
    }
}
