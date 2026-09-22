import SwiftUI

/// 阴影三档。用户决定：浮层面板统一黑 14% / 模糊 8 / 下偏 2；卡片与行不带阴影；分段栏滑块用 raised。
/// 页面不得直接调用 .shadow(color:)。
struct DaybookElevation: Equatable {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let flat = DaybookElevation(color: .clear, radius: 0, y: 0)
    static let raised = DaybookElevation(color: Color.black.opacity(0.08), radius: 1.5, y: 0.5)
    static let floating = DaybookElevation(color: Color.black.opacity(0.14), radius: 8, y: 2)
}

extension View {
    func daybookElevation(_ elevation: DaybookElevation) -> some View {
        shadow(color: elevation.color, radius: elevation.radius, x: 0, y: elevation.y)
    }
}
