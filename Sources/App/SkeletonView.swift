import FamilyControls
import SwiftUI

/// Deliberately a console, not a design.
///
/// The v1 flow is seven screens with one statement and one action each
/// (ADR 0003, ADR 0007), and none of that is here: guessing at it now would
/// mean writing it twice. What this screen owes the project is a way to fire
/// each step of the chain by hand while the log is being read.
struct SkeletonView: View {
    @Bindable var model: SkeletonModel
    @State private var pickerShown = false

    var body: some View {
        NavigationStack {
            List {
                Section("state") {
                    LabeledContent("authorization", value: model.authorization)
                    LabeledContent("status", value: model.status)
                    if let coverage = model.coverage {
                        LabeledContent(
                            "coverage", value: "\(coverage.resolved) of \(coverage.named)")
                    }
                    if let deadline = model.deadline {
                        LabeledContent("deadline", value: deadline.formatted(date: .omitted, time: .standard))
                    }
                }

                Section("chain") {
                    Button("Authorize") {
                        Task { await model.requestAuthorization() }
                    }
                    Button("Choose apps (\(model.selection.applicationTokens.count))") {
                        pickerShown = true
                    }
                    Button("Commit 15 minutes") {
                        model.commit()
                    }
                    Button("Release", role: .destructive) {
                        model.forceReleaseForSkeletonOnly()
                    }
                }
            }
            .navigationTitle("skeleton")
            .familyActivityPicker(isPresented: $pickerShown, selection: $model.selection)
        }
    }
}
