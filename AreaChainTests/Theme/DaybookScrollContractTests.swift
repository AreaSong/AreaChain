import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 调用工程中的真实重载；反射只检查装配值，不另写相似重载来推断 Swift 的选择。
@Suite(.serialized)
@MainActor
struct DaybookScrollContractTests {
    @Test func fiveCallFormsRetainParametersAndScopedComposition() throws {
        let view = ScrollView { Text("Synthetic") }
        try check(view.daybookScroll(), enabled: false, height: 7, hidden: true)
        try check(view.daybookScroll(featherEdges: false), enabled: false, height: 7, hidden: true)
        try check(view.daybookScroll(featherEdges: true), enabled: true, height: 7, hidden: true)
        try check(view.daybookScroll(featherHeight: 13), enabled: true, height: 13, hidden: false)
        try check(view.daybookScroll(featherEdges: false, featherHeight: 13),
                  enabled: false, height: 13, hidden: false)
    }

    private func check<V: View>(_ view: V, enabled: Bool, height: CGFloat, hidden: Bool) throws {
        let values = descendants(view)
        let targets = values.compactMap { $0 as? DaybookScrollTargetModifier }
        #expect(targets.count == 1)
        let target = try #require(targets.first)
        #expect(target.featherEdges == enabled)
        #expect(target.featherHeight == height)
        let concrete = String(reflecting: V.self)
        print("SCROLL_CONTRACT enabled=\(target.featherEdges) height=\(target.featherHeight) type=\(concrete)")
        // 阶段 E 将羽化放入持有 scope 的 modifier，共用 Host 目标；公开参数仍由同一入口传递。
        // 冻结新的静态组合；真实指示器策略、内容身份/焦点/偏移另由原生测试证明。
        let original = ScrollView { Text("Synthetic") }
        if hidden {
            let scoped = original.scrollIndicators(.hidden)
                .modifier(DaybookScrollTargetModifier(featherEdges: enabled, featherHeight: height))
            #expect(concrete == String(reflecting: type(of: scoped)))
        } else {
            let scoped = original.modifier(DaybookScrollTargetModifier(featherEdges: enabled, featherHeight: height))
            #expect(concrete == String(reflecting: type(of: scoped)))
        }
    }

    private func descendants(_ value: Any, depth: Int = 0) -> [Any] {
        guard depth < 10 else { return [] }
        return [value] + Mirror(reflecting: value).children.flatMap { descendants($0.value, depth: depth + 1) }
    }
}
