import SwiftData
import SwiftUI

@Observable
@MainActor
final class CaptureSession {
    static let shared = CaptureSession()
    var draft = ""
}

struct CaptureField: View {
    @Environment(\.locale) private var locale
    @Query(sort: \TagItem.sortOrder) private var allTags: [TagItem]
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onTodo: () -> Void
    var onDiary: () -> Void

    @State private var autocomplete = SyntaxAutocompleteState()

    private var availableTags: [String] {
        allTags.filter { $0.deletedAt == nil }.map(\.name)
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            inputRow
            ZStack(alignment: .topLeading) {
                CaptureTokenBar(text: text)
                if autocomplete.isActive {
                    SyntaxAutocompletePopup(state: autocomplete) { candidate in
                        if let trigger = autocomplete.trigger {
                            let (newText, _) = SyntaxAutocompleteEngine.applyCandidate(
                                candidate,
                                to: text,
                                range: trigger.range
                            )
                            text = newText
                            autocomplete.dismiss()
                        }
                    }
                    .padding(.top, 4)
                    .zIndex(100)
                }
            }
        }
        .animation(DaybookMotion.interactive, value: text)
        .animation(DaybookMotion.interactive, value: focus.wrappedValue)
        .daybookHideInputChrome()
    }

    private var inputRow: some View {
        let focused = focus.wrappedValue
        let plusColor = focused ? DaybookTheme.stamp : DaybookTheme.muted
        let strokeColor = focused ? DaybookTheme.stamp.opacity(0.6) : DaybookTheme.rule.opacity(0.4)
        let ringColor = focused ? DaybookTheme.stamp.opacity(0.18) : Color.clear

        return HStack(alignment: .center, spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(plusColor)
                .frame(width: 14)

            DaybookTextField(
                text: $text,
                placeholder: L10n.string("capture.placeholder.today", locale: locale),
                focus: focus,
                autocomplete: autocomplete,
                availableTags: availableTags,
                onSubmit: onTodo,
                onCommandReturn: onDiary
            )
            .accessibilityLabel("capture.placeholder.today")

            if canSubmit {
                ComposerAddButton(enabled: canSubmit, action: onTodo)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            diaryShortcutButton
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(DaybookTheme.ink.opacity(focused ? 0.05 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(strokeColor, lineWidth: focused ? 1.0 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ringColor, lineWidth: 2.0)
                .padding(-2)
        )
    }

    private var diaryShortcutButton: some View {
        let diaryInk = canSubmit ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.7)
        return Button(action: onDiary) {
            HStack(spacing: 3.5) {
                Text("capture.diary")
                    .font(.system(size: 10.5, weight: .medium))
                Text("⌘↩")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(DaybookTheme.ink.opacity(canSubmit ? 0.12 : 0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .stroke(DaybookTheme.rule.opacity(canSubmit ? 0.45 : 0.25), lineWidth: 0.5)
                    )
            }
            .foregroundStyle(diaryInk)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(
                canSubmit ? DaybookTheme.stamp.opacity(0.12) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.5)
        .help("capture.diary")
    }
}
