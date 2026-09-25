import SwiftUI

/// 把当前真正画出来的控件标识汇总到页面，供辅助功能和隔离测试读取。
struct SystemPageMarker: PreferenceKey {
    static var defaultValue: Set<String> = []
    static func reduce(value: inout Set<String>, nextValue: () -> Set<String>) {
        value.formUnion(nextValue())
    }
}

extension View {
    func systemPageMarker(_ identifier: String) -> some View {
        preference(key: SystemPageMarker.self, value: [identifier])
    }

    func systemPageMarkers(_ markers: Binding<Set<String>>) -> some View {
        onPreferenceChange(SystemPageMarker.self) { markers.wrappedValue = $0 }
    }
}
