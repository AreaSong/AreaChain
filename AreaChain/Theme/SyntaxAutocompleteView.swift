import SwiftUI

@Observable
@MainActor
final class SyntaxAutocompleteState {
    var isActive: Bool = false
    var trigger: SyntaxTrigger? = nil
    var candidates: [SyntaxCandidate] = []
    var selectedIndex: Int = 0

    func update(text: String, cursorLocation: Int, availableTags: [String] = []) {
        guard let detected = SyntaxAutocompleteEngine.detectTrigger(in: text, cursorLocation: cursorLocation) else {
            dismiss()
            return
        }

        let items = SyntaxAutocompleteEngine.candidates(for: detected, availableTags: availableTags)
        guard !items.isEmpty else {
            dismiss()
            return
        }

        trigger = detected
        candidates = items
        selectedIndex = max(0, min(selectedIndex, items.count - 1))
        isActive = true
    }

    func selectPrevious() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + candidates.count) % candidates.count
    }

    func selectNext() {
        guard !candidates.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % candidates.count
    }

    func selectedCandidate() -> SyntaxCandidate? {
        guard isActive, !candidates.isEmpty, selectedIndex >= 0, selectedIndex < candidates.count else {
            return nil
        }
        return candidates[selectedIndex]
    }

    func dismiss() {
        isActive = false
        trigger = nil
        candidates = []
        selectedIndex = 0
    }
}

struct SyntaxAutocompletePopup: View {
    @Bindable var state: SyntaxAutocompleteState
    var onCommit: (SyntaxCandidate) -> Void

    var body: some View {
        if state.isActive && !state.candidates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                candidateList
                Divider()
                    .background(DaybookTheme.rule.opacity(0.5))
                footerGuide
            }
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .fill(DaybookTheme.paper)
                    .shadow(color: DaybookTheme.ink.opacity(0.12), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                    .stroke(DaybookTheme.rule.opacity(0.7), lineWidth: 0.7)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
        }
    }

    private var candidateList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(state.candidates.enumerated()), id: \.element.id) { index, item in
                        candidateRow(item, isSelected: index == state.selectedIndex)
                            .id(item.id)
                            .onTapGesture {
                                onCommit(item)
                            }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 180)
            .onChange(of: state.selectedIndex) { _, newIndex in
                if newIndex >= 0 && newIndex < state.candidates.count {
                    withAnimation(DaybookMotion.interactive) {
                        proxy.scrollTo(state.candidates[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func candidateRow(_ item: SyntaxCandidate, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            iconView(for: item)
                .frame(width: 16, height: 16)

            Text(item.title)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(DaybookTheme.ink)

            Spacer(minLength: 4)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(isSelected ? DaybookTheme.stamp : DaybookTheme.muted)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected ? DaybookTheme.stamp.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func iconView(for item: SyntaxCandidate) -> some View {
        switch item.kind {
        case .tag:
            if item.isCreation {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 10.5))
                    .foregroundStyle(DaybookTheme.stamp)
            } else {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(nsColor: .systemIndigo))
            }
        case .priority:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(priorityColor(for: item.title))
        case .time:
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.stamp)
        }
    }

    private func priorityColor(for title: String) -> Color {
        switch title {
        case "!p1": return DaybookTheme.destructive
        case "!p2": return Color.orange
        case "!p3": return Color.blue
        default: return DaybookTheme.muted
        }
    }

    private var footerGuide: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text("↑↓")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
                Text("切换")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            HStack(spacing: 3) {
                Text("⇥ / ↵")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
                Text("补全")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Text("Esc")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 2.5).fill(DaybookTheme.ink.opacity(0.06)))
                Text("关闭")
                    .font(.system(size: 9))
                    .foregroundStyle(DaybookTheme.muted)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(DaybookTheme.ink.opacity(0.02))
    }
}

extension Notification.Name {
    static let diaryAppendToken = Notification.Name("AreaChain.diaryAppendToken")
}
