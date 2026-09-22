import SwiftUI

extension TasksPage {
    // MARK: - 顶部工具栏与小窗微型筛选标签流

    @ViewBuilder
    var headerBar: some View {
        let hasChips = yesterdayItems.count > 0 || upcomingModels.count > 0
        let tagChoices = config.externalFilter == nil ? CatalogChoices.tags(tags) : []
        let hasFilters = embedded
            ? (!CatalogChoices.projects(projects).isEmpty || !tagChoices.isEmpty || !todayBundleIDs.isEmpty
                || effectiveFilter.projectID != nil || effectiveFilter.bundleID != nil
                || (config.externalFilter == nil && effectiveFilter.isActive))
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
                            projects: CatalogChoices.projects(projects),
                            tags: tagChoices,
                            bundleIDs: todayBundleIDs,
                            projectCounts: projectCounts,
                            unclassifiedCount: unclassifiedTodosCount,
                            untaggedCount: untaggedTodosCount,
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

                if effectiveFilter.isHighPriorityOnly {
                    activeFilterTag(
                        title: L10n.string("filter.highPriority", locale: locale),
                        icon: "exclamationmark.3"
                    ) {
                        updateFilter(effectiveFilter.withHighPriority(false))
                    }
                }

                if let pid = effectiveFilter.projectID {
                    let name = pid == BoardFilter.noneID ? L10n.string("filter.project.none", locale: locale) : (projects.first(where: { $0.id == pid })?.name ?? "")
                    activeFilterTag(title: name, icon: "folder") {
                        updateFilter(effectiveFilter.withProject(nil))
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
        color: Color = DaybookTheme.stamp,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .bold))
            }
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .frame(width: 12, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .padding(.vertical, 2.5)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 0.7))
        .foregroundStyle(color)
    }

    private func updateFilter(_ next: BoardFilter) {
        if let external = config.externalFilter { external.wrappedValue = next }
        else { boardFilter = next }
    }
}
