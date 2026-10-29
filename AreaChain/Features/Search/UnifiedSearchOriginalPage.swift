import SwiftUI

/// “在原页面完成”只做导航（先校验宿主与资格，保留返回搜索的票据），
/// 不建草稿、不写数据、不调系统 API、不申请权限、不打开外部网址。对照唯一来源是 CommandOriginalPage。
extension UnifiedSearchController {
    func executeOriginalPage(_ route: CommandOriginalPage, command: CommandDescriptor, parsed: CommandPathResult,
                             source: UnifiedSearchBuffer) {
        // 参数一律不执行：原页面自己收集与校验；只有 help.example 读取示例文字用于预填。
        switch route.destination {
        case .page(let raw, let focusesTrash):
            guard let tab = WorkspaceTab(rawValue: raw) else { navigationMessage = "unified.originalPage.missingPage"; return }
            let focus = focusesTrash ? originalPageFocus(allowed: command.targetTypes) : nil
            navigate(.page(tab), source: source) { [weak self] _ in
                guard let self else { return }
                if let focus { self.navigationRouter?.navigation.focusedTrashID = focus.id }
                self.navigationMessage = route.finishesOnPage ? "unified.originalPage.displayed" : "unified.navigation.displayed"
            }
        case .object: openOriginalObject(route, command: command, source: source)
        case .syntaxHelp:
            helpCardPresented = true
            navigationMessage = "unified.help.syntax.shown"
        case .pageHelp:
            navigationMessage = originalPageHelpKey == nil ? "unified.help.page.none" : "unified.help.page.shown"
        case .example:
            guard case .shortText(let text)?? = parsed.arguments.first(where: { $0.parameter == .example }).map(\.value),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                helpCardPresented = true
                navigationMessage = "unified.help.example.choose"
                return
            }
            prefillExample(text)
        case .useInstead: navigationMessage = "unified.originalPage.useInstead.choose"
        }
    }

    /// 只把示例放进搜索框，不执行、不查询；当前输入就是 help.example 本身，没有别的未保存内容会被覆盖。
    func prefillExample(_ text: String) {
        helpCardPresented = false
        _ = navigationInput(text)
        navigationMessage = "unified.help.example.prefilled"
    }

    /// 回到搜索前所在页面的说明（页头 info 同一文案键）。
    var originalPageHelpKey: String? { navigationRouter?.navigation.selectedTab.helpKeyName }

    private func originalPageFocus(allowed: Set<CommandObjectType>) -> CommandObjectReference? {
        guard let active = try? session.presentation().pagination.browse.active, allowed.contains(active.type) else { return nil }
        return active
    }

    /// 对象详情沿 inspector.open 的同一解析（openResult → objects.resolve 的隐私与存活检查）；
    /// 手记打开手记页（不开只读正文），重复事项定义没有具体执行日就说明，不猜日期。
    private func openOriginalObject(_ route: CommandOriginalPage, command: CommandDescriptor, source: UnifiedSearchBuffer) {
        // 遮罩期间结果不可见，焦点项与详情都要先在原页面解锁，不借指令绕过。
        guard !session.isMasked else { navigationMessage = "unified.originalPage.needsUnlock"; return }
        guard let page = try? session.presentation().pagination, let active = page.browse.active else {
            navigationMessage = "unified.navigation.chooseObject"; return
        }
        let allowed = command.targetTypes
        switch active.type {
        case .routine where allowed.contains(.routine): navigationMessage = "unified.originalPage.needsDay"
        case .diary where allowed.contains(.diary):
            navigate(.page(.diary), source: source) { [weak self] _ in self?.navigationMessage = "unified.originalPage.displayed" }
        case .todo where allowed.contains(.todo),
             .routineOccurrence where allowed.contains(.routine) || allowed.contains(.routineOccurrence):
            guard let effect = try? session.browse(.init(version: page.snapshot.version, action: .open(inputEditing: false))),
                  effect.rejection == nil, let open = try? session.consumeOpenIntent() else {
                navigationMessage = "unified.navigation.stale"; return
            }
            openResult(open, source: source) { [weak self] _ in
                self?.navigationMessage = route.finishesOnPage ? "unified.originalPage.displayed" : "unified.navigation.displayed"
            }
        default: navigationMessage = "unified.navigation.unsupported"
        }
    }
}

/// 导航面板里的原页面说明：去哪一页（或哪个分节、哪个对象）、为什么要在那里完成；按钮与 Return 同一入口。
struct UnifiedSearchOriginalPageBlock: View {
    @Bindable var controller: UnifiedSearchController
    let route: CommandOriginalPage

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if route.finishesOnPage {
                Text("unified.originalPage.hint").font(DaybookType.body).fixedSize(horizontal: false, vertical: true)
            }
            destination
            Text(LocalizedStringKey(route.noteKey)).font(DaybookType.caption)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.originalPage.note")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unified.originalPage")
        .popover(isPresented: $controller.helpCardPresented, arrowEdge: .bottom) {
            SyntaxExpandableCard(isExpanded: $controller.helpCardPresented, context: .capture,
                                 onSelectToken: { _ in controller.helpCardPresented = false },
                                 onSelectExample: route.destination == .example ? { controller.prefillExample($0) } : nil)
                .padding(DaybookSpacing.sm)
        }
    }

    @ViewBuilder private var destination: some View {
        switch route.destination {
        case .page(let raw, _):
            if let tab = WorkspaceTab(rawValue: raw) {
                (Text("unified.originalPage.target") + Text(verbatim: " ") + Text(tab.titleKey))
                    .font(DaybookType.caption.weight(.semibold))
                    .accessibilityIdentifier("unified.originalPage.target")
            }
            if let section = route.sectionKey {
                (Text("unified.originalPage.section") + Text(verbatim: " ") + Text(LocalizedStringKey(section)))
                    .font(DaybookType.caption).accessibilityIdentifier("unified.originalPage.section")
            }
        case .object:
            Text("unified.originalPage.object").font(DaybookType.caption.weight(.semibold))
                .accessibilityIdentifier("unified.originalPage.target")
        case .syntaxHelp, .example:
            Button("unified.help.syntax.show") { controller.helpCardPresented = true }
                .buttonStyle(DaybookButtonStyle(.subtle))
                .accessibilityIdentifier("unified.help.syntax.show")
        case .pageHelp:
            Text(LocalizedStringKey(controller.originalPageHelpKey ?? "unified.help.page.none"))
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("unified.help.page.text")
        case .useInstead(let commands):
            ForEach(commands, id: \.self) { id in
                if let command = CommandCatalog.standard.command(id: id) {
                    Button { _ = controller.navigationInput(command.path) } label: {
                        Text("unified.originalPage.useCommand") + Text(verbatim: " ")
                            + Text(LocalizedStringKey("command." + id.rawValue + ".name"))
                    }
                    .buttonStyle(DaybookButtonStyle(.subtle))
                    .accessibilityIdentifier("unified.originalPage.use." + id.rawValue)
                }
            }
        }
    }
}
