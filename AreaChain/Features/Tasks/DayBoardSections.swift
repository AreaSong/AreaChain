import SwiftUI

extension DayBoardList {
    @ViewBuilder
    func openItemsSection(_ identity: DayBoardListIdentity) -> some View {
        if identity.openRows.isEmpty && !identity.doneRows.isEmpty {
            allDoneBanner
        } else if !identity.openRows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(identity.openRows, id: \.listID) { row in
                    dayRow(row, isDone: false, identity: identity)
                }
            }
        }
    }

    var allDoneBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(DaybookType.body.weight(.semibold))
                .foregroundStyle(DaybookPalette.accent.base)
            Text("board.banner.all_done")
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(DaybookPalette.text.primary.opacity(0.85)) // token-exempt: 85% 墨色没有对应令牌
            Spacer()
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.accent.base.opacity(0.05)) // token-exempt: 5% 印章底没有对应令牌
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookPalette.accent.fill, lineWidth: 0.8)
        )
        .padding(.top, 2)
    }

    func completedSection(_ identity: DayBoardListIdentity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .opacity(0.15)
                .padding(.top, 4)
                .padding(.bottom, 4)

            Button {
                withAnimation(DaybookMotion.animation(reduceMotion)) {
                    showCompleted.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(DaybookType.micro.weight(.bold))
                        .foregroundStyle(DaybookPalette.text.secondary)
                    DaybookSectionHeader(
                        title: showCompleted
                            ? "stamp.completed.collapse \(identity.doneRows.count)"
                            : "stamp.completed \(identity.doneRows.count)",
                        icon: "checkmark.circle"
                    )
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // control: 分节折叠头，整行点击
            .opacity(showCompleted ? 1.0 : 0.6)
            .accessibilityAddTraits(showCompleted ? [.isSelected] : [])

            if showCompleted {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(identity.doneRows, id: \.listID) { row in
                        dayRow(row, isDone: true, identity: identity)
                    }
                }
            }
        }
    }
}

struct DayBoardKeyNavigationModifier: ViewModifier {
    var interaction: DayBoardInteraction
    var onNavigate: (Int) -> Void
    var onToggle: (UUID) -> Void
    var onDelete: (UUID) -> Void
    var onInspect: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.downArrow) { handle(.downArrow) }
            .onKeyPress(.upArrow) { handle(.upArrow) }
            .onKeyPress(.space) { handle(.space) }
            .onKeyPress(.delete) { handle(.delete) }
            .onKeyPress(.return) { handle(.return) }
    }

    func handle(_ key: KeyEquivalent) -> KeyPress.Result {
        guard interaction.isKeyboardEnabled(), let focus = interaction.focusedTaskID else { return .ignored }
        switch key {
        case .downArrow: onNavigate(1)
        case .upArrow: onNavigate(-1)
        case .space:
            guard let id = focus.wrappedValue else { return .ignored }
            onToggle(id)
        case .delete:
            guard let id = focus.wrappedValue else { return .ignored }
            onDelete(id)
        case .return:
            guard let id = focus.wrappedValue else { return .ignored }
            onInspect(id)
        default: return .ignored
        }
        return .handled
    }
}
