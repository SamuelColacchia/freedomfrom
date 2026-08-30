import FreedomFromKit
import SwiftUI

/// A short list of durations, tapped, with the resulting deadline in words
/// beneath it. Then the hold, which *is* the confirmation — there is no dialog,
/// because a dialog is a second tap rather than a second thought (ADR 0003).
struct CommitView: View {
    @Bindable var model: AppModel

    @State private var length: CommitmentLength
    @State private var datePickerShown = false
    @State private var chosenDate: Date

    init(model: AppModel) {
        self.model = model
        // The draft's last length, or the shortest commitment there is. A
        // preselection is what keeps this screen to one statement and one
        // action, and fifteen minutes is the cheapest thing it could preselect.
        let remembered = model.draft.length ?? .preset(.fifteenMinutes)
        _length = State(initialValue: remembered)
        _chosenDate = State(initialValue: remembered.deadline(from: Date()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                ForEach(CommitmentLength.Preset.allCases, id: \.self) { preset in
                    row(preset.words, selected: length == .preset(preset)) {
                        select(.preset(preset))
                    }
                }
                row("a date…", selected: isCustom, ruled: false) { datePickerShown = true }
            }
            .padding(.bottom, 20)

            Text("until \(deadline.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))")
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Quiet.until)

            Spacer()

            HoldToConfirm(title: "hold to commit", duration: length.holdDuration) {
                Task { await model.commit(length) }
            }

            Text("\(targetWords) · this device only")
                .whisper()
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .quietScreen()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $datePickerShown) {
            DeadlineSheet(chosen: $chosenDate) { picked in
                select(.custom(seconds: picked.timeIntervalSinceNow))
            }
        }
    }

    private var deadline: Date { length.deadline(from: Date()) }

    private var isCustom: Bool {
        if case .custom = length { return true }
        return false
    }

    private var targetWords: String {
        model.chosen.words(alsoDomains: model.draft.domains.count)
    }

    private func select(_ chosen: CommitmentLength) {
        length = chosen
        model.chooseLength(chosen)
    }

    private func row(
        _ title: String, selected: Bool, ruled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(selected ? Quiet.ink : Quiet.dim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ruled ? Quiet.hairline : .clear).frame(height: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

/// A sheet, because it hands a deadline back to this screen. Pushes are places
/// you go and come back from; sheets return values (ADR 0007).
private struct DeadlineSheet: View {
    @Binding var chosen: Date
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $chosen,
                in: Date().addingTimeInterval(CommitmentLength.minimumSeconds)...Date()
                    .addingTimeInterval(CommitmentLength.maximumSeconds),
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Quiet.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onPick(chosen)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

extension CommitmentLength.Preset {
    /// The list as ADR 0004 fixed it. `oneDay` reads as "24 hours" because that
    /// is what it is: the sub-day presets are elapsed time, and only the
    /// multi-day ones are calendar days.
    var words: String {
        switch self {
        case .fifteenMinutes: "15 minutes"
        case .oneHour: "1 hour"
        case .threeHours: "3 hours"
        case .twelveHours: "12 hours"
        case .oneDay: "24 hours"
        case .threeDays: "3 days"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        }
    }
}
