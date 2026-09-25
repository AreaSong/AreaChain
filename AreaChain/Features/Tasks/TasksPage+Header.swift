import SwiftUI

extension TasksPage {
    // MARK: - 顶部工具栏与小窗微型筛选标签流

    @ViewBuilder
    var headerBar: some View {
        let hasChips = yesterdayItems.count > 0 || upcomingModels.count > 0
        let tagChoices = config.externalFilter == nil ? CatalogChoices.tags(tags) : []
        let hasFilters = embedded
            ? (config.externalFilter == nil
                || !tagChoices.isEmpty
                || !todayBundleIDs.isEmpty
                || effectiveFilter.bundleID != nil
                || effectiveFilter.isActive)
            : (config.externalFilter == nil && effectiveFilter.isActive)

        if hasChips || hasFilters {
            HStack(spacing: 8) {
                if hasChips {
                    LeftoverChipsBar(
                        config: LeftoverChipsBarConfig(
                            yesterday: LeftoverChipState(
                                count: yesterdayItems.count,
                                isExpanded: showYesterday,
                                onToggle: { showYesterday.toggle() }
                            ),
                            upcoming: LeftoverChipState(
                                count: upcomingModels.count,
                                isExpanded: showUpcoming,
                                onToggle: { showUpcoming.toggle() }
                            )
                        )
                    )
                }

                if hasChips && hasFilters {
                    Spacer(minLength: 8)
                }

                if hasFilters {
                    if embedded {
                        BoardFilterBar(
                            filter: effectiveFilter,
                            tags: tagChoices,
                            bundleIDs: todayBundleIDs,
                            untaggedCount: untaggedTodosCount,
                            showsPriority: true,
                            showsReminder: true,
                            onChange: updateFilter
                        )
                    } else {
                        compactActiveFilterChips
                    }
                }
            }
            .padding(.horizontal, 1)
            .padding(.top, 1)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var compactActiveFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if effectiveFilter.dateScope != DateFilterScope.all {
                    activeFilterTag(
                        title: effectiveFilter.dateScope.title(locale: locale),
                        icon: "calendar"
                    ) {
                        updateFilter(effectiveFilter.withDateScope(DateFilterScope.all))
                    }
                }

                if effectiveFilter.priorityScope != .all || effectiveFilter.isHighPriorityOnly {
                    activeFilterTag(
                        title: effectiveFilter.priorityTitle(locale: locale),
                        icon: "exclamationmark.3"
                    ) {
                        var next = effectiveFilter.withPriorityScope(.all)
                        next.isHighPriorityOnly = false
                        updateFilter(next)
                    }
                }

                if effectiveFilter.reminderScope != .all {
                    activeFilterTag(
                        title: effectiveFilter.reminderScope.title(locale: locale),
                        icon: "bell"
                    ) {
                        updateFilter(effectiveFilter.withReminderScope(.all))
                    }
                }

                if let bundleID = effectiveFilter.bundleID {
                    activeFilterTag(
                        title: BundleDisplay.name(for: bundleID),
                        icon: "app"
                    ) {
                        updateFilter(effectiveFilter.withBundle(nil))
                    }
                }

                if let tid = effectiveFilter.tagID {
                    if tid == BoardFilter.noneID {
                        activeFilterTag(title: L10n.string("filter.tag.none", locale: locale), icon: "tag") {
                            updateFilter(effectiveFilter.withTag(nil))
                        }
                    } else if let tag = tags.first(where: { $0.id == tid }) {
                        activeFilterTag(title: "#" + tag.name, color: DiaryTagChrome.color(for: tag.name)) {
                            updateFilter(effectiveFilter.withTag(nil))
                        }
                    }
                }
            }
        }
    }

    private func activeFilterTag(
        title: String,
        icon: String? = nil,
        color: Color = DaybookPalette.accent.base,
        onRemove: @escaping () -> Void
    ) -> some View {
        DaybookChip(tint: color, isSelected: true) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold)) // token-exempt: 芯片内移除角标小于 9pt
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain) // control: 芯片内的移除角标
            }
        }
    }

    private func updateFilter(_ next: BoardFilter) {
        if let external = config.externalFilter { external.wrappedValue = next }
        else { boardFilter = next }
    }
}
