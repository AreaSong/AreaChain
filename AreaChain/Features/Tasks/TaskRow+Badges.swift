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
                        .font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 9.5, weight: .semibold))
                        .foregroundStyle(DaybookTheme.Syntax.tag)
                        .lineLimit(1)
                        .padding(.horizontal, 4.5)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(DaybookTheme.Syntax.tagFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .stroke(DaybookTheme.Syntax.tagStroke, lineWidth: 0.6)
                        )
                        .help("#\(tagName)")
                }

                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(DaybookTheme.Syntax.tag)
                        .padding(.horizontal, 3.5)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(DaybookTheme.Syntax.tagBadgeFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .stroke(DaybookTheme.Syntax.tagStroke, lineWidth: 0.6)
                        )
                        .help("更多 \(overflow) 个标签: \(tags.dropFirst(2).joined(separator: ", "))")
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
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.orange : DaybookTheme.muted.opacity(style.isWorkspace ? 1 : 0.75))
            Text("\(streak)")
                .font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? DaybookTheme.ink : DaybookTheme.muted.opacity(style.isWorkspace ? 1 : 0.75))
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(DaybookMotion.interactive(reduceMotion), value: streak)
                .offset(y: -0.6)
        }
        .fixedSize()
        .padding(.horizontal, 4.5)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isHighlighted ? Color.orange.opacity(0.12) : Color.clear)
        )
    }

    @ViewBuilder
    func remindBadge(_ minutes: Int) -> some View {
        let isHighlighted = isHovered || state.isSelected
        let content = HStack(spacing: 2.5) {
            Image(systemName: "clock")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(isHighlighted ? DaybookTheme.stamp : DaybookTheme.muted.opacity(style.isWorkspace ? 1 : 0.75))
            Text(RemindMinutes.label(minutes, locale: locale))
                .font(style.isWorkspace ? WorkspaceStyle.countFont : .system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isHighlighted ? DaybookTheme.ink : DaybookTheme.muted.opacity(style.isWorkspace ? 1 : 0.75))
                .lineLimit(1)
                .offset(y: -0.6)
        }
        .fixedSize()
        .padding(.horizontal, 4.5)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isHighlighted ? DaybookTheme.stamp.opacity(0.10) : Color.clear)
        )

        if state.canSetRemind {
            Button {
                pickingTime = true
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
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
        .opacity(style.isWorkspace || isHovered || state.isSelected ? 1.0 : 0.65)
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

