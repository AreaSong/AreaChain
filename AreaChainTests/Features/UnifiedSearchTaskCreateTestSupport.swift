import AppKit
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchTaskCreateFixture {
    let io: TaskCreateCommandIO
    let results: UnifiedSearchResultsFixture
    let environment: TaskCreateCommandEnvironment
    let privacy = NotificationCenter()
    var controller: UnifiedSearchController { results.controller }

    init(assembled: Bool = true, capability: TaskCreateCommandAdapter.Capability = .minimal) throws {
        io = try TaskCreateCommandIO()
        environment = try io.environment()
        results = try UnifiedSearchResultsFixture(taskCreateEnvironment: assembled ? environment : nil,
            taskCreateCapability: capability, privacyCenter: capability == .ordinaryComposition ? privacy : nil)
    }

    func stop() { results.stop() }
    func start(title: String = "合成普通任务", day: String? = "2026-10-05") throws {
        try results.startOperation("todo.create")
        try results.typeParameter(.title, text: title)
        if let day {
            try #require(controller.editParameter(.init(parameter: .day, operation: .assign, value: .day(day)),
                                                   source: controller.buffer) != nil)
        }
    }
    func count(_ action: String) -> Int { io.capture.trace.filter { $0 == action }.count }
    func submit() { controller.requestOperationSubmit(controller.buffer) }
    var facts: CommandTaskCreateFacts { get throws { try #require(controller.settingExecution?.units.first?.taskCreation) } }
    func host(layout: UnifiedSearchInputLayout = .standard, width: CGFloat = 620,
              locale: String = "en", dark: Bool = false) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                         results: controller, operations: true)
        try await host.start()
        return host
    }
}

extension UnifiedSearchTestHost {
    /// 面板下沿被裁时，可访问性 frame 只报可见部分，按它滚动不会前进，LazyVGrid 也不创建视口外的行；
    /// 因此把面板顶边对齐到所在滚动区可视区顶部，并断言下沿未被裁，否则点"今天"会随运行日期失败。
    /// 批量日期等不在滚动区里的宿主没有裁剪，只保留面板边界断言。
    func revealTaskDatePicker() async throws {
        let picker = try resultNode("daybook.datePicker")
        try await SettingsButtonTestSupport.reveal(picker, in: window)
        let visible = try SettingsButtonTestSupport.frame(picker, in: window)
        guard let scroll = SettingsButtonTestSupport.elements(window.contentView)
            .compactMap({ $0 as? NSScrollView })
            .filter({ $0.contentView.convert($0.contentView.bounds, to: nil).intersects(visible) })
            .min(by: { $0.contentView.bounds.height < $1.contentView.bounds.height }) else {
            try await revealSettingControlInsidePanel("daybook.datePicker")
            return
        }
        let document = try #require(scroll.documentView)
        let clip = scroll.contentView.convert(scroll.contentView.bounds, to: nil)
        // 窗口坐标原点在左下，maxY 是顶边；与可视区等高的矩形可见即顶边对齐。
        let target = CGRect(x: visible.minX, y: visible.maxY - clip.height, width: visible.width, height: clip.height)
        document.scrollToVisible(document.convert(target, from: nil))
        scroll.reflectScrolledClipView(scroll.contentView)
        try await SystemPageHost.settle(window)
        let revealed = try SettingsButtonTestSupport.frame(resultNode("daybook.datePicker"), in: window)
        #expect(revealed.minY > clip.minY + 0.5, "日期面板下沿仍被滚动区裁掉")
        try await revealSettingControlInsidePanel("daybook.datePicker")
    }
}
