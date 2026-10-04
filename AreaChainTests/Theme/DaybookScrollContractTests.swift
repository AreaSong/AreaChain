import AppKit
import SwiftUI
import Testing
@testable import AreaChain

/// 调用工程中的真实重载；反射只检查装配值，不另写相似重载来推断 Swift 的选择。
@Suite(.serialized)
@MainActor
struct DaybookScrollContractTests {
    @Test func fiveCallFormsRetainTheirConcreteComposition() throws {
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
        let feathers = values.compactMap { $0 as? DaybookScrollEdgeFeatherModifier }
        #expect(feathers.count == 1)
        let feather = try #require(feathers.first)
        #expect(feather.enabled == enabled)
        #expect(feather.featherHeight == height)
        #expect(values.filter { $0 is DaybookScrollerConfigurator }.count == 1)
        let concrete = String(reflecting: V.self)
        print("SCROLL_CONTRACT enabled=\(feather.enabled) height=\(feather.featherHeight) type=\(concrete)")
        // 冻结修改前的具体链，防止增加条件视图、类型擦除或 modifier 包装后仍只靠参数断言通过。
        let original = ScrollView { Text("Synthetic") }
        if hidden {
            let frozen = original.scrollIndicators(.hidden)
                .background(DaybookScrollerConfigurator())
                .modifier(DaybookScrollEdgeFeatherModifier(enabled: enabled))
            #expect(concrete == String(reflecting: type(of: frozen)))
        } else {
            let frozen = original.background(DaybookScrollerConfigurator())
                .modifier(DaybookScrollEdgeFeatherModifier(enabled: enabled, featherHeight: height))
            #expect(concrete == String(reflecting: type(of: frozen)))
        }
    }

    private func descendants(_ value: Any, depth: Int = 0) -> [Any] {
        guard depth < 10 else { return [] }
        return [value] + Mirror(reflecting: value).children.flatMap { descendants($0.value, depth: depth + 1) }
    }
}
