import SwiftUI

/// 工作台「搜索与指令」页：基本用法、条件速查、常用精选与完整目录，只读说明。
/// 示例按钮只预填工作台搜索框（与 help.example 同一 prefillExample），不执行、不查询。
/// 每行怎么处理只读 `UnifiedSearchController.disposition(for:)`；控制器缺席（装配失败、隔离宿主）时显示“—”，不另写判断。
struct SearchGuidePage: View {
    var workspace: UnifiedSearchController?
    var menubar: UnifiedSearchController?
    @State private var expanded: Set<String> = []

    private static let sections = CommandCatalog.standard.guideSections()

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

    private var basicsSection: some View {
        Section("searchGuide.basics.title") {
            if workspace == nil || menubar == nil {
                note("searchGuide.hostsUnavailable")
                    .accessibilityIdentifier("searchGuide.hostsUnavailable")
            }
            if workspace?.hasUnsavedCommandWork == true {
                note("searchGuide.example.blocked")
                    .accessibilityIdentifier("searchGuide.example.blocked")
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
            ForEach(Self.sections) { section in
                DisclosureGroup(isExpanded: binding(section.id)) {
                    ForEach(section.commands) { command in
                        SearchGuideCatalogRow(command: command, hosts: hosts)
                    }
                } label: {
                    HStack(spacing: DaybookSpacing.xs) {
                        Text(LocalizedStringKey(section.nameKey)).font(DaybookType.body.weight(.semibold))
                        Text(verbatim: "\(section.commands.count)")
                            .font(DaybookType.counter)
                            .foregroundStyle(DaybookPalette.text.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .accessibilityIdentifier("searchGuide.catalog." + section.id)
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

/// 两个宿主的处理方式。只转述唯一入口的结果，nil 表示该宿主没有可用控制器。
@MainActor
struct SearchGuideHosts {
    let workspace: UnifiedSearchController?
    let menubar: UnifiedSearchController?

    /// 示例会替换搜索框文字；没有工作台控制器，或它还有未完成的指令草稿、待执行列表时不提供，
    /// 与菜单栏转交工作台时不覆盖未完成工作的规则一致。
    var blocksExamples: Bool { workspace?.hasUnsavedCommandWork ?? true }

    func dispositions(_ id: CommandID) -> (workspace: CommandHostDisposition?, menubar: CommandHostDisposition?) {
        (workspace?.disposition(for: id), menubar?.disposition(for: id))
    }

    /// 已知的宿主都处理不了才弱化；未知（nil）的宿主不参与，不猜测。
    static func isUnavailable(_ values: [CommandHostDisposition?]) -> Bool {
        let known = values.compactMap { $0 }
        return !known.isEmpty && known.allSatisfy { [.catalogUnavailable, .unwired].contains($0.kind) }
    }
}

private struct SearchGuideFeaturedRow: View {
    let row: SearchGuideFeatured
    let hosts: SearchGuideHosts

    var body: some View {
        let values = hosts.dispositions(row.command)
        let unavailable = SearchGuideHosts.isUnavailable([values.workspace, values.menubar])
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
                Text(LocalizedStringKey(row.nameKey ?? "command.\(row.command.rawValue).name"))
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(unavailable ? DaybookPalette.text.tertiary : DaybookPalette.text.primary)
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
            SearchGuideDispositionLines(workspace: values.workspace, menubar: values.menubar)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchGuide.featured." + row.id)
    }
}

private struct SearchGuideCatalogRow: View {
    let command: CommandDescriptor
    let hosts: SearchGuideHosts

    var body: some View {
        let values = hosts.dispositions(command.id)
        let unavailable = SearchGuideHosts.isUnavailable([values.workspace, values.menubar])
        VStack(alignment: .leading, spacing: DaybookSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.sm) {
                Text(LocalizedStringKey(command.nameKey))
                    .font(DaybookType.body)
                    .foregroundStyle(unavailable ? DaybookPalette.text.tertiary : DaybookPalette.text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: command.path)
                    .font(DaybookType.caption.monospaced())
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
            }
            SearchGuideDispositionLines(workspace: values.workspace, menubar: values.menubar)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("searchGuide.command." + command.id.rawValue)
    }
}

/// 工作台、菜单栏各一行，文案与候选标签同一个 `label(locale:)`。
private struct SearchGuideDispositionLines: View {
    let workspace: CommandHostDisposition?
    let menubar: CommandHostDisposition?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line("searchGuide.host.workspace", workspace)
            line("searchGuide.host.menubar", menubar)
        }
    }

    private func line(_ host: LocalizedStringKey, _ value: CommandHostDisposition?) -> some View {
        (Text(host) + Text(verbatim: " · ") + Text(verbatim: value?.label(locale: locale) ?? "—"))
            .font(DaybookType.badge)
            .foregroundStyle(DaybookPalette.text.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
