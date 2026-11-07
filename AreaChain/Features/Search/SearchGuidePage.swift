import SwiftUI

/// 工作台「搜索与指令」页：基本用法、条件速查、常用精选与从 `ActionRegistry` 自动派生的全量动作目录。
struct SearchGuidePage: View {
    var workspace: UnifiedSearchController?
    var menubar: UnifiedSearchController?
    @State private var expanded: Set<String> = []
    @Environment(\.locale) private var locale

    var body: some View {
        DaybookPage(title: "tab.searchGuide", systemImage: WorkspaceTab.searchGuide.iconName, minWidth: 420, minHeight: 560) {
            Form {
                basicsSection
                conditionsSection
                ForEach(SearchGuideFeatured.Group.allCases, id: \.self) { group in
                    Section(LocalizedStringKey(group.titleKey)) {
                        ForEach(SearchGuideFeatured.all.filter { $0.group == group }) { row in
                            SearchGuideFeaturedRow(row: row, hosts: hosts)
                        }
                    }
                }
                catalogSection
            }
            .formStyle(.grouped)
            .daybookScroll()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("searchGuide.page")
    }

    private var hosts: SearchGuideHosts { .init(workspace: workspace, menubar: menubar) }

    private var catalogGroups: [ActionCatalogGroup] {
        StandardActionCatalog.bootstrapIfNeeded()
        return ActionRegistry.shared.exportedCatalogGroups()
    }

    private var basicsSection: some View {
        Section("searchGuide.basics.title") {
            if workspace == nil || menubar == nil {
                note("searchGuide.hostsUnavailable")
                    .accessibilityIdentifier("searchGuide.hostsUnavailable")
            }
            ForEach(SearchGuideSyntax.basics, id: \.self) { key in
                Text(LocalizedStringKey(key))
                    .font(DaybookType.body)
                    .foregroundStyle(DaybookPalette.text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var conditionsSection: some View {
        Section("searchGuide.conditions.title") {
            ForEach(SearchGuideSyntax.conditions) { condition in
                HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
                    Group {
                        if let key = condition.tokenKey { Text(LocalizedStringKey(key)) } else { Text(verbatim: condition.token) }
                    }
                    .font(DaybookType.caption.monospaced())
                    .foregroundStyle(DaybookPalette.accent.base)
                    .frame(minWidth: 120, alignment: .leading)
                    Text(LocalizedStringKey(condition.key))
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var catalogSection: some View {
        Section("searchGuide.catalog.title") {
            note("searchGuide.catalog.hint")
            ForEach(catalogGroups) { group in
                DisclosureGroup(isExpanded: binding(group.id.rawValue)) {
                    ForEach(group.actions, id: \.id) { item in
                        SearchGuideActionCatalogRow(item: item, hosts: hosts)
                    }
                } label: {
                    HStack(spacing: DaybookSpacing.xs) {
                        Text(verbatim: group.category.localizedTitle(for: locale))
                            .font(DaybookType.body.weight(.semibold))
                        Text(verbatim: "\(group.actions.count)")
                            .font(DaybookType.counter)
                            .foregroundStyle(DaybookPalette.text.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityIdentifier("searchGuide.catalog." + group.id.rawValue)
            }
        }
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { expanded.contains(id) },
                set: { open in if open { expanded.insert(id) } else { expanded.remove(id) } })
    }

    private func note(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(DaybookType.caption)
            .foregroundStyle(DaybookPalette.text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
struct SearchGuideHosts {
    let workspace: UnifiedSearchController?
    let menubar: UnifiedSearchController?

    var blocksExamples: Bool { workspace?.hasUnsavedCommandWork ?? true }
}

private struct SearchGuideFeaturedRow: View {
    let row: SearchGuideFeatured
    let hosts: SearchGuideHosts
    @Environment(\.locale) private var locale

    private var descriptor: ActionMetadataDescriptor? {
        StandardActionCatalog.bootstrapIfNeeded()
        return ActionRegistry.shared.action(for: row.actionID)?.metadata
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
                Text(verbatim: descriptor?.localizedTitle(for: locale) ?? row.actionID.rawValue)
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    guard !hosts.blocksExamples else { return }
                    hosts.workspace?.prefillExample(row.example)
                } label: {
                    Text(verbatim: row.example).font(DaybookType.caption.monospaced())
                }
                .buttonStyle(DaybookButtonStyle(.subtle))
                .disabled(hosts.blocksExamples)
                .help(Text("searchGuide.example.help"))
                .accessibilityLabel(Text("searchGuide.example.label") + Text(verbatim: " " + row.example))
                .accessibilityIdentifier("searchGuide.example." + row.id)
            }
            Text(LocalizedStringKey(row.summaryKey))
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchGuide.featured." + row.id)
    }
}

private struct SearchGuideActionCatalogRow: View {
    let item: ActionMetadataDescriptor
    let hosts: SearchGuideHosts
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
            Text(verbatim: item.localizedTitle(for: locale))
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                guard !hosts.blocksExamples else { return }
                hosts.workspace?.prefillExample("/\(item.primaryCommand) ")
            } label: {
                Text(verbatim: item.commandNames.prefix(2).map { "/\($0)" }.joined(separator: " · "))
                    .font(DaybookType.caption.monospaced())
            }
            .buttonStyle(DaybookButtonStyle(.subtle))
            .disabled(hosts.blocksExamples)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("searchGuide.action." + item.id.rawValue)
    }
}
