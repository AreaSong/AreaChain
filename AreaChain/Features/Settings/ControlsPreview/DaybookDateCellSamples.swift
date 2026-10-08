import SwiftUI

/// 原 ControlsPreview 的同一日格样例，也可单独挂载以核对全部状态。
struct DaybookDateCellSamples: View {
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        VStack(spacing: DaybookSpacing.sm) {
            ForEach([false, true], id: \.self) { compact in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                    ForEach(0..<8) { state in
                        let key = "2026-09-\(String(format: "%02d", state + (compact ? 11 : 1)))"
                        DaybookDateCell(dayKey: key, isToday: state & 1 != 0, isSelected: state & 2 != 0,
                                        presentation: .monthGrid(compact ? .compact : .regular),
                                        annotation: state == 0 ? nil : Text(verbatim: "123456"), isDropTarget: state & 4 != 0) {
                            onSelect(key)
                        }
                    }
                }
            }
        }
    }
}
