import Foundation

/// 灵感手记的常用分类。标签仍走全局 `TagItem`，但这三个名字在手记里始终作为分类入口。
enum DiaryMemoTags {
    static let password = "密码"
    static let idea = "小巧思"
    static let journal = "日记"

    static let presets = [password, idea, journal]

    static func isPasswordName(_ name: String) -> Bool {
        name == password || name.localizedCaseInsensitiveContains("password")
    }

    static func isPresetName(_ name: String) -> Bool {
        presets.contains(name)
    }

    /// 正文关键字自动归类：密码备忘、小巧思、日记。
    static func autoTagNames(in text: String) -> [String] {
        let lower = text.lowercased()
        var names: [String] = []
        if lower.contains("密码") || lower.contains("password") || lower.contains("pwd") {
            names.append(password)
        }
        if lower.contains("巧思") || lower.contains("灵感") || lower.contains("idea") {
            names.append(idea)
        }
        if lower.contains("日记") || lower.contains("diary") || lower.contains("journal") {
            names.append(journal)
        }
        return names
    }

    static func ordered<T>(_ tags: [T], name: (T) -> String, isActive: (T) -> Bool) -> [T] {
        let active = tags.filter(isActive)
        var result: [T] = []
        for preset in presets {
            if let tag = active.first(where: { name($0) == preset }) {
                result.append(tag)
            }
        }
        result.append(contentsOf: active.filter { !isPresetName(name($0)) })
        return result
    }
}
