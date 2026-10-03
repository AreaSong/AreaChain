import SwiftUI

/// publication 只属于当前一次门禁通过后的原生树；失效由外层同步拆树，不进入 @State。
struct UnifiedSearchResultsContent: View {
    let controller: UnifiedSearchController
    let publication: ContentQueryReadPublication
    let source: UnifiedSearchBuffer
    let layout: UnifiedSearchInputLayout
    @Environment(\.locale) private var locale
    @State private var showsDetails = false
    @FocusState private var focusedControl: ContentQueryDisplayControl?
    private var page: ContentQueryPaginationState { publication.pagination }

    var body: some View {
        let status = page.status
        let copy = UnifiedSearchResultCopy(status)
        VStack(alignment: .leading, spacing: 8) {
            header(status, copy: copy)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if status.hits.known == 0 {
                            DaybookEmptyState(title: LocalizedStringKey(copy.emptyKey), systemImage: "magnifyingglass",
                                              compact: layout == .compact)
                        }
                        ForEach(page.snapshot.units.filter { page.snapshot.visibility.units.contains($0.id) }) { unit in
                            unitView(unit, status: status.groups.first { $0.unit == unit.id })
                        }
                        if status.hasMoreUnits {
                            loadButton("unified.results.loadMore", id: "units", action: .loadMoreUnits)
                        }
                    }
                    .padding(2)
                    .background(DaybookScrollerConfigurator())
                }
                .onChange(of: page.browse.active) { _, active in
                    if let active { proxy.scrollTo(active, anchor: .center) }
                }
            }
        }
        .onChange(of: focusedControl) { _, control in
            controller.focusChanged(control, version: page.snapshot.version, source: source)
        }
        .task(id: controller.focusRevision) {
            guard controller.focusRevision > 0, let control = controller.controlFocus else { return }
            // 等待被收起的原生正文退出 responder 链，再按同一票据转交焦点。
            await Task.yield()
            guard !Task.isCancelled, controller.validates(source),
                  let current = try? controller.session.presentation().pagination.browse,
                  current.snapshot.version == page.snapshot.version, current.reachableControls.contains(control) else { return }
            controller.inputFocused = false
            controller.focusResults?(.control(control))
            focusedControl = control
        }

    }

    private func header(_ status: ContentQueryPaginationStatus, copy: UnifiedSearchResultCopy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: L10n.format("unified.results.count", locale: locale, status.hits.displayed, status.hits.known))
                .font(DaybookType.body.weight(.medium)).accessibilityIdentifier("unified.results.count")
            let sort = page.snapshot.source.source
            Text(sort.applied == .relevance ? "unified.results.relevance" : "unified.results.recent")
                .font(DaybookType.caption)
            if sort.fallback != nil {
                Text("unified.results.sortFallback").font(DaybookType.caption)
            }
            if let primary = copy.reasons.first {
                Text(LocalizedStringKey(primary)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.results.reason")
                Button(showsDetails ? "unified.results.hideDetails" : "unified.results.details") { showsDetails.toggle() }
                    .buttonStyle(DaybookButtonStyle(.quiet)).accessibilityIdentifier("unified.results.details")
                if showsDetails {
                    ForEach(copy.reasons.dropFirst(), id: \.self) { Text(LocalizedStringKey($0)).font(DaybookType.caption) }
                    Text("unified.results.knownOnly").font(DaybookType.caption)
                }
            }
            if !page.snapshot.diagnostics.isEmpty {
                Text("unified.results.groupUnknown").font(DaybookType.caption)
            }
            Group {
                if layout == .compact { VStack(alignment: .leading) { selectionButtons } }
                else { HStack { selectionButtons } }
            }
            .buttonStyle(DaybookButtonStyle(.quiet))
        }
        .foregroundStyle(DaybookPalette.text.secondary)
    }

    @ViewBuilder private var selectionButtons: some View {
        Button("unified.results.selectVisible") { browse(.selectVisible) }
            .buttonStyle(DaybookButtonStyle(.quiet)).focusable()
            .onKeyPress(.space) { browse(.selectVisible); return .handled }
            .accessibilityIdentifier("unified.results.selectVisible")
        Button("unified.results.selectKnown") { browse(.selectAllKnown) }
            .buttonStyle(DaybookButtonStyle(.quiet)).focusable()
            .onKeyPress(.space) { browse(.selectAllKnown); return .handled }
            .accessibilityIdentifier("unified.results.selectKnown")
        Text(verbatim: L10n.format("unified.results.selectionCount", locale: locale, page.browse.selected.count))
            .font(DaybookType.caption)
    }

    private func unitView(_ unit: ContentQueryDisplayUnit, status: ContentQueryGroupPaginationStatus?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if unit.sourceGroup != nil {
                Text("unified.results.trashGroup").font(DaybookType.caption.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.secondary)
            }
            ForEach(unit.hits.filter { page.snapshot.visibility.members.contains($0) }, id: \.self) { id in
                if let row = page.snapshot.row(id) {
                    UnifiedSearchResultRow(row: row, layout: layout, active: page.browse.active == id,
                        selected: page.browse.selected.contains(id), activate: { browse(.activate(id)) },
                        select: { browse(.select(id, !page.browse.selected.contains(id))) })
                    .id(id)
                    ForEach(row.expansion, id: \.field) { reference in expansion(reference) }
                }
            }
            if let status, status.hits.remaining > 0 {
                loadButton("unified.results.loadMembers", id: "members." + unit.bestMatch.searchIdentifier,
                           action: .loadMoreMembers(unit.id))
            }
            if let group = unit.sourceGroup, !unit.context.isEmpty {
                context(unit, group: group, status: status)
            }
            if unit.sourceGroup != nil { Text("unified.results.restoreNotice").font(DaybookType.caption) }
        }
    }

    private func expansion(_ reference: ContentQueryExpansionReference) -> some View {
        let toggle = ContentQueryDisplayControl.bodyToggle(reference.object, reference.field)
        let body = ContentQueryDisplayControl.body(reference.object, reference.field)
        let expanded = page.browse.expanded.contains(toggle)
        return VStack(alignment: .leading, spacing: 4) {
            Button(expansionLabel(reference.field, expanded: expanded)) {
                browse(expanded ? .collapse(toggle, focused: body) : .expand(toggle))
                if expanded { focusedControl = toggle }
            }
            .buttonStyle(DaybookButtonStyle(.quiet)).focusable().focused($focusedControl, equals: toggle)
            .accessibilityValue(Text(expanded ? "unified.results.expanded" : "unified.results.collapsed"))
            .accessibilityIdentifier("unified.expand." + reference.object.searchIdentifier + "." + reference.field.searchIdentifier)
            .onKeyPress(.space) {
                browse(expanded ? .collapse(toggle, focused: body) : .expand(toggle))
                return .handled
            }
            if expanded, let text = try? controller.session.expandedText(body, version: page.snapshot.version) {
                DaybookSearchReadOnlyText(text: text, identifier: "unified.body." + reference.object.searchIdentifier, collapse: {
                    browse(.collapse(toggle, focused: body)); focusedControl = toggle
                }, onFocus: { focused in
                    controller.focusChanged(focused ? body : nil, version: page.snapshot.version, source: source)
                })
                .frame(height: layout == .compact ? 120 : 180)
            }
        }
    }

    private func context(_ unit: ContentQueryDisplayUnit, group: CommandObjectReference,
                         status: ContentQueryGroupPaginationStatus?) -> some View {
        let toggle = ContentQueryDisplayControl.contextToggle(group)
        let expanded = page.browse.expanded.contains(toggle)
        return VStack(alignment: .leading, spacing: 6) {
            Button(expanded ? "unified.results.hideContext" : "unified.results.showContext") {
                browse(expanded ? .collapse(toggle, focused: focusedControl) : .expand(toggle))
                if expanded { focusedControl = toggle }
            }
            .buttonStyle(DaybookButtonStyle(.quiet)).focusable().focused($focusedControl, equals: toggle)
            .accessibilityValue(Text(expanded ? "unified.results.expanded" : "unified.results.collapsed"))
            .accessibilityIdentifier("unified.contextToggle." + group.searchIdentifier)
            .onKeyPress(.space) {
                browse(expanded ? .collapse(toggle, focused: focusedControl) : .expand(toggle))
                return .handled
            }
            if expanded {
                ForEach(page.snapshot.visibleContext(in: unit), id: \.self) { reference in
                    if let value = page.snapshot.context(reference) {
                        UnifiedSearchTrashContext(value: value)
                            .focusable().focused($focusedControl, equals: .context(reference))
                    }
                }
                if let status, status.remainingContextToLoad > 0 {
                    loadButton("unified.results.loadContext", id: "contexts." + group.searchIdentifier,
                               action: .loadMoreContexts(unit.id))
                }
            }
        }
    }

    private func expansionLabel(_ field: ContentQueryMatchField, expanded: Bool) -> LocalizedStringKey {
        switch field {
        case .title, .filename, .tagName: expanded ? "unified.results.collapseName" : "unified.results.expandName"
        case .notes: expanded ? "unified.results.collapseSummary" : "unified.results.expandSummary"
        default: expanded ? "unified.results.collapse" : "unified.results.expand"
        }
    }

    private func browse(_ action: ContentQueryBrowseAction) {
        controller.browse(.init(version: page.snapshot.version, action: action), source: source)
    }

    private func loadButton(_ key: LocalizedStringKey, id: String, action: ContentQueryPaginationAction) -> some View {
        Button(key) { controller.load(.init(stamp: page.stamp, action: action), source: source) }
            .buttonStyle(DaybookButtonStyle(.quiet)).accessibilityIdentifier("unified.load." + id)
    }
}
