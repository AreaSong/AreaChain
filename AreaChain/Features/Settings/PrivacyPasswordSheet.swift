import SwiftUI

struct PrivacyPasswordSheet: View {
    var title: LocalizedStringKey
    var confirmation: Bool
    var explanation: LocalizedStringKey
    var minimumLength: Int = 1
    var action: (String) async throws -> Void
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var repeated = ""
    @State private var busy = false
    @State private var errorKey: String?

    private var isLengthValid: Bool {
        password.count >= minimumLength && password.utf8.count <= 4_096
    }

    private var canSave: Bool {
        !busy && !password.isEmpty && isLengthValid && (!confirmation || password == repeated)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(DaybookType.title)
            Text(explanation).font(DaybookType.body).foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DaybookSecureField(title, text: $password).onSubmit(submit)
            if confirmation { DaybookSecureField("privacy.password.repeat", text: $repeated).onSubmit(submit) }
            if let errorKey {
                Text(LocalizedStringKey(errorKey)).font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger).fixedSize(horizontal: false, vertical: true)
            } else if minimumLength > 1 && !password.isEmpty && !isLengthValid {
                Text(LocalizedStringKey(PrivacyError.weakPassword.messageKey)).font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("alert.cancel") { password = ""; repeated = ""; dismiss() }.disabled(busy)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(DaybookButtonStyle(.quiet))
                Button("common.save", action: submit).buttonStyle(DaybookButtonStyle(.prominent))
                    .disabled(!canSave)
            }
        }
        .padding(24).frame(width: 440)
        .interactiveDismissDisabled(busy)
        .onDisappear { password = ""; repeated = "" }
    }

    private func submit() {
        guard !busy, !password.isEmpty else { return }
        guard isLengthValid else {
            errorKey = PrivacyError.weakPassword.messageKey
            return
        }
        guard !confirmation || password == repeated else { return }
        busy = true
        errorKey = nil
        let input = password
        password = ""
        repeated = ""
        Task {
            do { try await action(input); busy = false; onComplete() }
            catch { errorKey = (error as? PrivacyError ?? .corruptData).messageKey; busy = false }
        }
    }
}
