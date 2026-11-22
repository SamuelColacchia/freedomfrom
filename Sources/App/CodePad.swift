import SwiftUI

/// A passcode-style pad: four dots and a keypad, like the system lock screen.
/// The parent watches `code` reach `length` and decides what that means.
struct CodePad: View {
    static let length = 4

    @Binding var code: String

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "delete"]

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 18) {
                ForEach(0..<Self.length, id: \.self) { index in
                    Circle()
                        .fill(index < code.count ? Quiet.ink : .clear)
                        .overlay(Circle().stroke(Quiet.quieted, lineWidth: 1))
                        .frame(width: 13, height: 13)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(code.count) of \(Self.length) digits")

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(76), spacing: 26), count: 3),
                spacing: 16
            ) {
                ForEach(keys, id: \.self) { key in
                    switch key {
                    case "": Color.clear.frame(width: 76, height: 76)
                    case "delete":
                        Button {
                            if !code.isEmpty { code.removeLast() }
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 22, weight: .light))
                                .foregroundStyle(Quiet.quieted)
                                .frame(width: 76, height: 76)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("delete")
                    default:
                        Button {
                            if code.count < Self.length { code.append(key) }
                        } label: {
                            Text(key)
                                .font(.system(size: 30, weight: .ultraLight))
                                .foregroundStyle(Quiet.ink)
                                .frame(width: 76, height: 76)
                                .overlay(Circle().stroke(Quiet.line, lineWidth: 1))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
