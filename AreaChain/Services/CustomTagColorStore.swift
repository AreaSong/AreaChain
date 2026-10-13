import Foundation
import Observation

/// 持久化管理用户通过调色盘保存的自定义标签颜色列表（支持测试注入独立 UserDefaults）。
@Observable
@MainActor
final class CustomTagColorStore {
    static let shared = CustomTagColorStore()
    nonisolated static let storageKey = "areachain.tags.customColors"

    private let defaults: UserDefaults
    private(set) var colors: [CustomTagColor] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.colors = Self.load(from: defaults)
    }

    @discardableResult
    func upsert(hex: String, name: String = "") -> CustomTagColor? {
        guard let item = CustomTagColor(hex: hex, name: name) else { return nil }
        if let index = colors.firstIndex(where: { $0.hex == item.hex }) {
            let mergedName = item.name.isEmpty ? colors[index].name : item.name
            if let updated = CustomTagColor(hex: item.hex, name: mergedName) {
                colors[index] = updated
            }
        } else {
            colors.append(item)
        }
        persist()
        return colors.first { $0.hex == item.hex }
    }

    func remove(hex: String) {
        guard let normalized = TagColorToken.normalizedHex(hex) else { return }
        colors.removeAll { $0.hex == normalized }
        persist()
    }

    func displayName(for token: String) -> String? {
        guard let normalized = TagColorToken.normalizedHex(token) else { return nil }
        return colors.first(where: { $0.hex == normalized })?.displayTitle ?? normalized
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(colors) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [CustomTagColor] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CustomTagColor].self, from: data) else {
            return []
        }
        return decoded
    }
}
