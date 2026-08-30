import FamilyControls
import FreedomFromKit
import SwiftUI

/// The root when nothing is running, and the busiest screen in the app.
///
/// It carries the weight the rest of the line does not — a count, "Choose
/// apps", the field, the typed list, "Next", and the history line — because
/// every re-entry path already ends here, so an idle screen announcing that
/// nothing is running would be a hub wearing one screen (ADR 0007).
///
/// It arrives holding the draft — which is the typed domains and the length,
/// and not the apps. Apps are picked here and held for this session only, so
/// the count above is what this session chose rather than what an older
/// encoding claims, and a commitment can no longer be degraded at birth
/// (ADR 0008, as amended by hardware check S3).
struct TargetsView: View {
    @Bindable var model: AppModel

    @State private var pickerShown = false
    @State private var typed = ""

    private enum Spur: Hashable {
        case commit
        case history
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("\(model.pickedTargetCount)")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(Quiet.ink)
                Text("chosen")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Quiet.whisper)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            TextField("", text: $typed, prompt: placeholder)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Quiet.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
                .padding(.vertical, 11)
                .overlay(alignment: .bottom) { Rectangle().fill(Quiet.line).frame(height: 1) }
                .onSubmit {
                    model.addDomain(typed)
                    typed = ""
                }

            domains

            if !model.draft.domains.isEmpty {
                Text("Safari's Private Browsing switches off while a commitment with websites runs.")
                    .whisper()
                    .padding(.top, 16)
            }

            Spacer()

            QuietButton(title: "Choose apps") { pickerShown = true }
                .padding(.bottom, 10)

            NavigationLink(value: Spur.commit) {
                Text("Next")
                    .font(.system(size: 15, weight: .light))
                    .tracking(1.5)
                    .foregroundStyle(Quiet.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .overlay(Rectangle().stroke(Quiet.line, lineWidth: 1))
            }
            .disabled(!model.canCommit)
            .opacity(model.canCommit ? 1 : 0.25)

            // Absent when there is no history rather than present and empty:
            // absence reads as absence (ADR 0007).
            if !model.record.history.isEmpty {
                NavigationLink(value: Spur.history) {
                    Text("what you have committed to before")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Quiet.faint)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
            }
        }
        .quietScreen()
        .familyActivityPicker(isPresented: $pickerShown, selection: $model.selection)
        .onChange(of: pickerShown) { _, shown in
            if !shown { model.selectionChanged() }
        }
        .navigationDestination(for: Spur.self) { spur in
            switch spur {
            case .commit: CommitView(model: model)
            case .history: HistoryView(model: model)
            }
        }
    }

    private var placeholder: Text {
        Text("or type a website").foregroundStyle(Quiet.dim)
    }

    /// Typed domains are the only part of a target set the app can read back:
    /// application tokens are opaque, so apps are the count above and websites
    /// are words (ADR 0006).
    @ViewBuilder
    private var domains: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.draft.domains, id: \.host) { domain in
                HStack {
                    Text(domain.host)
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Quiet.until)
                    Spacer()
                    Button {
                        model.removeDomain(domain)
                    } label: {
                        Text("remove")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(Quiet.faint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 11)
                .overlay(alignment: .bottom) { Rectangle().fill(Quiet.hairline).frame(height: 1) }
            }
        }
    }
}
