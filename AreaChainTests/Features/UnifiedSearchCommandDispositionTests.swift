import AppKit
import SwiftData
import Testing
@testable import AreaChain

/// 目录级用例。走正式版唯一装配（内存容器、fake 副作用），对目录里每一条指令都走与原生输入相同的入口：
/// edit（打字）→ accept（接受候选）→ intent(.open)（Return）→ 草稿／面板 → intent(.submit)（⌘Return，提交入口）。
/// 每条按实际行为归类，再断言与唯一判断入口 disposition(for:) 给出的类别一致（标签类别 = 实际行为）。不开窗口、不发键鼠事件。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchCommandDispositionTests {
    /// navigated：导航入口接上了（未被拒为 unsupported／unassembled）。后台用例没有真实窗口，看不到导航完成反馈，
    /// 因此不在这里区分“前往”与“打开原页面”，只要求标签落在这两类之一；不再用 CommandOriginalPage 表自证。
    /// handedOff：菜单栏把同一文字交给工作台（显示工作台的副作用被调用、菜单栏没有建草稿）。
    enum Observed: String { case executable, navigated, handedOff, notWired }

    struct Outcome { let id: String; let observed: Observed; let disposition: CommandHostDisposition }

    static var commands: [CommandDescriptor] {
        CommandCatalog.standard.entries.filter { $0.category != .group && $0.category != .scope }
    }

    /// 同一入口走一遍，返回观察到的行为；每条指令一份新装配，避免上一条草稿触发切换确认。
    static func drive(_ command: CommandDescriptor, host: String, fixture: UnifiedSearchProductionFixture) async throws -> Outcome {
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = try #require(host == "workspace" ? assembly.workspace : assembly.menubar)
        let disposition = controller.disposition(for: command.id)
        let parser = CommandPathParser()
        // 打字：路径前缀（与原生输入逐字进入 edit 同一入口），再接受这条指令的候选。
        let prefix = String(command.path.dropLast())
        _ = controller.edit(.init(source: controller.buffer, text: prefix, selection: .init(location: prefix.utf16.count, length: 0)))
        let result = parser.parse(.init(text: controller.buffer.text, cursorLocation: controller.buffer.text.utf16.count))
        if let candidate = result.candidates.first(where: { $0.command.id == command.id && $0.intent != .expand(command.id) }),
           let edit = result.accepting(candidate, in: controller.buffer.text, hasMarkedText: false) {
            _ = controller.accept(.init(source: controller.buffer, text: edit.text,
                                        selection: .init(location: edit.cursorLocation, length: 0), acceptance: edit))
        } else {
            _ = controller.edit(.init(source: controller.buffer, text: command.path,
                                      selection: .init(location: command.path.utf16.count, length: 0)))
        }
        let reveals = fixture.probe.reveals
        controller.intent(.open, source: controller.buffer)
        await controller.navigationTask?.value
        if fixture.probe.reveals > reveals {
            #expect(controller.operations?.active == nil, "\(command.id.rawValue) 转交时菜单栏不应建草稿")
            return .init(id: command.id.rawValue, observed: .handedOff, disposition: disposition)
        }
        if UnifiedSearchController.routesAsNavigation(command) {
            let refused = ["unified.navigation.unsupported", "unified.navigation.unassembled"].contains(controller.navigationMessage)
            if refused { return .init(id: command.id.rawValue, observed: .notWired, disposition: disposition) }
            return .init(id: command.id.rawValue, observed: .navigated, disposition: disposition)
        }
        // 草稿必须由同一入口开始；提交入口：⌘Return。没有适配器时落到设置提交并报 unsupported 或 submitBlocked。
        try #require(controller.operations?.active?.commandID == command.id, "\(command.id.rawValue) 未开始草稿（\(host)）")
        controller.intent(.submit, source: controller.buffer)
        let blocked = controller.settingFailure?.issue == .unsupported || controller.operationMessage == "unified.operation.submitBlocked"
        return .init(id: command.id.rawValue, observed: blocked ? .notWired : .executable, disposition: disposition)
    }

    @Test(arguments: ["workspace", "menubar"]) func everyCatalogCommandLabelMatchesBehavior(host: String) async throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        var outcomes: [Outcome] = []
        for command in Self.commands { outcomes.append(try await Self.drive(command, host: host, fixture: fixture)) }
        #expect(outcomes.count == Self.commands.count)
        for outcome in outcomes {
            switch outcome.observed {
            case .executable: #expect(outcome.disposition.kind == .executable, "\(outcome.id)：可执行但标签为 \(outcome.disposition)")
            case .navigated:
                #expect([.executable, .originalPage].contains(outcome.disposition.kind), "\(outcome.id)：导航已接上但标签为 \(outcome.disposition)")
                #expect(outcome.disposition != .executable, "\(outcome.id)：导航类不应标为“Return 开始 · 预览后确认”")
            case .handedOff:
                #expect(host == "menubar" && outcome.disposition == .workspaceHandoff, "\(outcome.id)：已转交但标签为 \(outcome.disposition)")
            case .notWired:
                #expect([.catalogUnavailable, .unwired].contains(outcome.disposition.kind), "\(outcome.id)：走不通但标签为 \(outcome.disposition)")
                if case .catalogUnavailable = outcome.disposition {
                    #expect(CommandCatalog.standard.command(id: .init(rawValue: outcome.id))?.availability != .declared)
                }
            }
        }
        // 用户点名的两条在两宿主都必须可执行（标签与实际行为同时断言）。
        for id in ["setting.appearance", "setting.captureSource"] {
            let outcome = outcomes.first { $0.id == id }
            #expect(outcome?.disposition == .executable && outcome?.observed == .executable, "\(id) 应可执行（\(host)）")
        }
        // 两宿主的类别计数：都没有“未接上”；菜单栏的导航、打开原页面与页面指令交给工作台完成。
        let counts = Dictionary(grouping: outcomes, by: \.disposition.kind).mapValues(\.count)
        let expected: [CommandHostDisposition.Kind: Int] = host == "workspace"
            ? [.executable: 160, .originalPage: 86, .catalogUnavailable: 1]
            : [.executable: 64, .workspaceHandoff: 178, .catalogUnavailable: 5]
        #expect(counts == expected, "\(host)：\(counts)")
        let report = outcomes.map { "\($0.id)\t\($0.observed.rawValue)\t\($0.disposition.kind.rawValue)" }.joined(separator: "\n")
        Attachment.record(report, named: "m7g-c-catalog-\(host).tsv")
        let unwired = outcomes.filter { $0.disposition == .unwired }.map(\.id)
        Attachment.record(unwired.joined(separator: "\n"), named: "m7g-c-unwired-\(host).txt")
    }

    /// 五类标签中英文都有文案，且不同类别文字不同（未接上才写“暂不可用”）。
    @Test func labelsAreLocalizedPerKind() {
        let samples: [CommandHostDisposition] = [.executable, .navigates, .originalPage(pageKey: "tab.tags", finishesOnPage: true),
            .originalPage(pageKey: "unified.candidate.page.help", finishesOnPage: false),
            .workspaceHandoff, .catalogUnavailable(reasonKey: "command.reason.globalUnlink"), .unwired]
        for locale in [Locale(identifier: "en"), Locale(identifier: "zh-Hans")] {
            let labels = samples.map { $0.label(locale: locale) }
            #expect(Set(labels).count == labels.count)
            #expect(!labels.contains { $0.contains("unified.") || $0.contains("command.reason") || $0.contains("%@") })
            let unavailable = L10n.format("unified.input.unavailable", locale: locale)
            #expect(labels.filter { $0 == unavailable }.count == 1)
        }
    }
}
