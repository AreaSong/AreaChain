import SwiftUI

// MARK: - Task Row Badges & Chips

extension TaskRow {
    @ViewBuilder
    var tagChips: some View {
        let tags = attachedTagNames
        if !tags.isEmpty {
            let displayTags = Array(tags.prefix(2))
            let overflow = tags.count - displayTags.count

            HStack(spacing: 3) {
                ForEach(displayTags, id: \.self) { tagName in
                    Text("#\(tagName)")
                        .font(DaybookType.micro.weight(.semibold))
                        .foregroundStyle(DaybookPalette.Syntax.tag)
                        .lineLimit(1)
                        .padding(.horizontal, 4.5)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .fill(DaybookPalette.Syntax.tagFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .stroke(DaybookPalette.Syntax.tagStroke, lineWidth: 0.6)
                        )
                        .help("#\(tagName)")
                }

                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .bold, design: .rounded)) // token-exempt: 标签溢出计数用圆体
                        .foregroundStyle(DaybookPalette.Syntax.tag)
                        .padding(.horizontal, 3.5)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .fill(DaybookPalette.Syntax.tagBadgeFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                                .stroke(DaybookPalette.Syntax.tagStroke, lineWidth: 0.6)
                        )
                        .help(L10n.format("row.tag.overflow.help", locale: locale, overflow, tags.dropFirst(2).joined(separator: ", ")))
                }
            }
        }
    }

    var quadrantBadge: some View {
        let isImportant = state.classify?.isImportant == true || state.isImportant
        let isUrgent = state.classify?.isUrgent == true || state.isUrgent
        let slot = QuadrantSlot.of(important: isImportant, urgent: isUrgent)
        let isHighlighted = isHovered || state.isSelected
        return QuadrantBadge(slot: slot, isHighlighted: isHighlighted)
    }

    var formattedNoteSnippet: String? {
        guard let notes = state.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let firstLine = notes.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return firstLine?.trimmingCharacters(in: .whitespaces)
    }

    func streakBadge(_ streak: Int) -> some View {
        let isHighlighted = isHovered || state.isSelected
        return HStack(spacing: 2.5) {
            Image(systemName: "flame.fill")
                .font(DaybookType.micro.weight(.semibold))
                .foregroundStyle(isHighlighted ? DaybookPalette.status.pending : DaybookPalette.text.tertiary)
            Text("\(streak)")
                .font(.system(size: 10, weight: .bold, design: .rounded)) // token-exempt: 连击数字用圆体
                .foregroundStyle(isHighlighted ? DaybookPalette.text.primary : DaybookPalette.text.tertiary)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(DaybookMotion.interactive(reduceMotion), value: streak)
                .offset(y: -0.6)
        }
        .fixedSize()
        .padding(.horizontal, 4.5)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                .fill(isHighlighted ? DaybookPalette.status.pending.opacity(0.12) : Color.clear) // token-exempt: 待办橙 12% 底没有单独令牌
        )
    }

    func remindBadge(_ minutes: Int) -> some View {
        let isHighlighted = isHovered || state.isSelected
        return DaybookChip(tint: DaybookPalette.accent.base, isSelected: isHighlighted, action: state.canSetRemind ? { pickingTime = true } : nil) {
            HStack(spacing: 2.5) {
                Image(systemName: "clock")
                Text(RemindMinutes.label(minutes, locale: locale))
            }
        }
    }

    @ViewBuilder
    var metadataCluster: some View {
        HStack(spacing: 5) {
            quadrantBadge

            tagChips

            if state.isResident, let streak = state.streak, streak >= 1 {
                streakBadge(streak)
            }

            if let remindMinutes = state.remindMinutes {
                remindBadge(remindMinutes)
            }

            if !state.subtasks.isEmpty {
                TaskRowSubtaskChip(
                    subtasks: state.subtasks,
                    isExpanded: $isSubtasksExpanded,
                    reduceMotion: reduceMotion
                )
            }

            if let items = state.attachments?.items, !items.isEmpty {
                AttachmentThumbnails(items: items)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .opacity(isHovered || state.isSelected ? 1.0 : 0.65)
        .animation(DaybookMotion.interactive(reduceMotion), value: isHovered)
    }

    var attachedTagNames: [String] {
        guard let classify = state.classify else { return [] }
        let selectedIDs = Set(TagIDList.parse(classify.tagIDs))
        guard !selectedIDs.isEmpty else { return [] }
        return classify.tags.filter { selectedIDs.contains($0.id) }.map(\.name)
    }

    var hasVisibleMetadata: Bool {
        state.isImportant || state.classify?.isImportant == true
            || state.isUrgent || state.classify?.isUrgent == true
            || !attachedTagNames.isEmpty
            || (state.isResident && (state.streak ?? 0) >= 1)
            || state.remindMinutes != nil
            || !state.subtasks.isEmpty
            || !(state.attachments?.items.isEmpty ?? true)
    }
}
