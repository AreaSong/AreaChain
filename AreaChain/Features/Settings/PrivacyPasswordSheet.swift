import SwiftUI

struct PrivacyPasswordSheet: View {
    var title: LocalizedStringKey
    var confirmation: Bool
    var explanation: LocalizedStringKey
    var action: (String) async throws -> Void
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var repeated = ""
    @State private var busy = false
    @State private var errorKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(DaybookType.title)
            Text(explanation).font(DaybookType.body).foregroundStyle(DaybookTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            SecureField(title, text: $password).onSubmit(submit)
            if confirmation { SecureField("privacy.password.repeat", text: $repeated).onSubmit(submit) }
            if let errorKey {
                Text(LocalizedStringKey(errorKey)).font(DaybookType.caption)
                    .foregroundStyle(DaybookTheme.destructive).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("alert.cancel") { password = ""; repeated = ""; dismiss() }.disabled(busy)
                    .keyboardShortcut(.cancelAction)
                Button("common.save", action: submit).buttonStyle(.borderedProminent)
                    .disabled(busy || password.isEmpty || (confirmation && password != repeated))
            }
        }
        .textFieldStyle(.roundedBorder).padding(24).frame(width: 440)
        .interactiveDismissDisabled(busy)
        .onDisappear { password = ""; repeated = "" }
    }

    private func submit() {
        guard !busy, !password.isEmpty, !confirmation || password == repeated else { return }
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
