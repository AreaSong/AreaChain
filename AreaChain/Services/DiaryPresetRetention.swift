import Foundation

/// 记住用户删掉的手记分类名。彻底删除后库里没有墓碑，打开手记不能据此把「密码 / 小巧思 / 日记」再建回来。
enum DiaryPresetRetention {
    static let defaultsKey = "areachain.diaryPresets.dismissed"

    /// 单测换成独立 suite，避免写进正在使用的应用偏好。
    static var defaultsOverride: UserDefaults?

    private static var defaults: UserDefaults { defaultsOverride ?? .standard }

    static func isDismissed(_ name: String) -> Bool {
        dismissedNames().contains(TagSyntax.normalizedName(name))
    }

    static func dismiss(_ name: String) {
        var names = dismissedNames()
        names.insert(TagSyntax.normalizedName(name))
        defaults.set(names.sorted(), forKey: defaultsKey)
    }

    static func retain(_ name: String) {
        var names = dismissedNames()
        names.remove(TagSyntax.normalizedName(name))
        if names.isEmpty {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(names.sorted(), forKey: defaultsKey)
        }
    }

    private static func dismissedNames() -> Set<String> {
        Set(defaults.stringArray(forKey: defaultsKey) ?? [])
    }
}
