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
    @State private var isCommandPressed: Bool = false
    @State private var eventMonitor: Any?
    @State private var isHoveringDiary: Bool = false

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
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                isCommandPressed = event.modifierFlags.contains(.command)
                return event
            }
            isCommandPressed = NSEvent.modifierFlags.contains(.command)
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    private var inputRow: some View {
        let focused = focus.wrappedValue
        let plusColor = focused ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.8)
        let strokeColor = focused ? DaybookTheme.stamp.opacity(0.65) : DaybookTheme.rule.opacity(0.4)
        let ringColor = focused ? DaybookTheme.stamp.opacity(0.16) : Color.clear

        return HStack(alignment: .center, spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 11.5, weight: .semibold))
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

            diaryShortcutButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(focused ? DaybookTheme.surface : DaybookTheme.ink.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(strokeColor, lineWidth: focused ? 1.1 : 0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ringColor, lineWidth: 2.0)
                .padding(-2)
        )
    }

    private var diaryShortcutButton: some View {
        let isActive = (canSubmit && isCommandPressed) || (canSubmit && isHoveringDiary)
        let iconColor = isActive ? DaybookTheme.stamp : DaybookTheme.muted.opacity(canSubmit ? 0.6 : 0.25)
        let bgColor = isActive ? DaybookTheme.stamp.opacity(0.12) : Color.clear
        
        return Button(action: onDiary) {
            HStack(spacing: 2.5) {
                Image(systemName: "command")
                    .font(.system(size: 10.5, weight: isActive ? .bold : .semibold))
                Image(systemName: "return")
                    .font(.system(size: 10, weight: isActive ? .bold : .semibold))
            }
            .foregroundStyle(iconColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(bgColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!canSubmit)
        .keyboardShortcut(.return, modifiers: [.command])
        .help("capture.diary")
        .onHover { hovering in
            isHoveringDiary = hovering
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isActive)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: canSubmit)
    }
}
