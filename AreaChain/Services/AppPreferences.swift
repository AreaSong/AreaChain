import AppKit
import Foundation
import Observation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        case .system:
            let first = preferredLanguages.first ?? "en"
            if first.hasPrefix("zh") { return "zh-Hans" }
            return "en"
        }
    }

    var resolvedLocale: Locale {
        Locale(identifier: resolvedCode())
    }
}

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 四象限卡片放不下一行时的省略位置。气泡预览始终从标题开头开始。
enum QuadrantTitleTruncation: String, CaseIterable, Identifiable, Sendable {
    case tail
    case middle

    var id: String { rawValue }

    var textTruncation: Text.TruncationMode {
        self == .middle ? .middle : .tail
    }
}

@Observable
@MainActor
final class AppPreferences {
    static let shared = AppPreferences()

    nonisolated static let languageKey = "areachain.prefs.language"
    nonisolated static let appearanceKey = "areachain.prefs.appearance"
    nonisolated static let quadrantTitleTruncationKey = "areachain.prefs.quadrantTitleTruncation"
    nonisolated static let stampCaptureAppKey = "areachain.prefs.stampCaptureApp"
    static let syncCalendarEventsKey = "areachain.prefs.syncCalendarEvents"
    static let isTagsExpandedKey = "areachain.prefs.isTagsExpanded"
    static let boardFiltersKey = "areachain.prefs.boardFilters"

    private let defaults: UserDefaults
    private var isLoading = true

    private var languageValue: AppLanguage
    private var appearanceValue: AppAppearance
    private var truncationValue: QuadrantTitleTruncation
    private var captureValue: Bool
    @ObservationIgnored private let localStorage: LocalPreferenceStorage
    @ObservationIgnored private let effects: LocalPreferenceEffects
    @ObservationIgnored private var revisions: [LocalPreferenceField: UInt64] = [:]
    @ObservationIgnored private var isApplyingLocalSetting = false
    let localPreferenceSource: LocalPreferenceSource

    var language: AppLanguage {
        get { languageValue }
        set { applyLocalSetting(.language(newValue)) }
    }

    var appearance: AppAppearance {
        get { appearanceValue }
        set { applyLocalSetting(.appearance(newValue)) }
    }

    var quadrantTitleTruncation: QuadrantTitleTruncation {
        get { truncationValue }
        set { applyLocalSetting(.quadrantTitleTruncation(newValue)) }
    }

    var stampCaptureApp: Bool {
        get { captureValue }
        set { applyLocalSetting(.stampCaptureApp(newValue)) }
    }

    var syncCalendarEvents: Bool {
        didSet {
            guard !isLoading else { return }
            defaults.set(syncCalendarEvents, forKey: Self.syncCalendarEventsKey)
            notifyChange()
        }
    }

    var isTagsExpanded: Bool {
        didSet {
            guard !isLoading else { return }
            defaults.set(isTagsExpanded, forKey: Self.isTagsExpandedKey)
            notifyChange()
        }
    }

    var resolvedLocale: Locale { language.resolvedLocale }

    var resolvedColorScheme: ColorScheme? { appearance.resolvedColorScheme }

    init(defaults: UserDefaults = .standard, localStorage: LocalPreferenceStorage? = nil,
         effects: LocalPreferenceEffects? = nil) {
        self.defaults = defaults
        let storage = localStorage ?? LocalPreferenceStorage(defaults: defaults)
        self.localStorage = storage
        self.effects = effects ?? .live
        localPreferenceSource = LocalPreferenceSource(instanceID: UUID(), storageID: storage.identity)
        let language = ((try? storage.read(.language)) ?? .unavailable).initialValue(for: .language)
        let appearance = ((try? storage.read(.appearance)) ?? .unavailable).initialValue(for: .appearance)
        let truncation = ((try? storage.read(.quadrantTitleTruncation)) ?? .unavailable).initialValue(for: .quadrantTitleTruncation)
        let capture = ((try? storage.read(.stampCaptureApp)) ?? .unavailable).initialValue(for: .stampCaptureApp)
        if case .language(let value) = language { languageValue = value } else { languageValue = .system }
        if case .appearance(let value) = appearance { appearanceValue = value } else { appearanceValue = .system }
        if case .quadrantTitleTruncation(let value) = truncation { truncationValue = value } else { truncationValue = .tail }
        if case .stampCaptureApp(let value) = capture { captureValue = value } else { captureValue = false }
        syncCalendarEvents = defaults.bool(forKey: Self.syncCalendarEventsKey)
        isTagsExpanded = defaults.object(forKey: Self.isTagsExpandedKey) as? Bool ?? true
        isLoading = false
        applyAppAppearance()
    }

    @discardableResult
    func applyAppAppearance() -> PreferenceCallOutcome {
        call { try effects.applyAppearance(appearance) }
    }

    /// 每次都重新读注入存储。运行内修订不能替代原始键核验，也不能检测外部 ABA。
    func readLocalSetting(_ field: LocalPreferenceField) -> LocalPreferenceSnapshot {
        let raw = (try? localStorage.read(field)) ?? .unavailable
        return LocalPreferenceSnapshot(source: localPreferenceSource, field: field,
            revision: revisions[field, default: 0], value: localValue(field), raw: raw)
    }

    /// 保留旧 Binding 的同值写入/通知；命令的目标已满足判断留给 3A-1B。
    /// matches 仅表示同句柄当前可见值一致，不保证磁盘耐久或跨进程原子性。
    @discardableResult
    func applyLocalSetting(_ value: LocalPreferenceValue, expecting expected: LocalPreferenceSnapshot? = nil,
                           validateBeforeWrite: (() throws -> Void)? = nil) -> LocalPreferenceWriteResult {
        guard !isApplyingLocalSetting else {
            return LocalPreferenceWriteResult(requested: value, before: nil, after: nil, rejection: .reentrant)
        }
        isApplyingLocalSetting = true
        defer { isApplyingLocalSetting = false }
        let before = readLocalSetting(value.field)
        guard before.raw != .unavailable else {
            return LocalPreferenceWriteResult(requested: value, before: before, after: nil, rejection: .unreadableStorage)
        }
        if let expected, before != expected {
            return LocalPreferenceWriteResult(requested: value, before: before, after: nil, rejection: .snapshotChanged)
        }
        do { try validateBeforeWrite?() } catch {
            return LocalPreferenceWriteResult(requested: value, before: before, after: nil, rejection: .executionInvalidated)
        }
        let write = call { try localStorage.write(value) }
        // 即使注入写入抛错也可能已有副作用，必须使旧字段证据失效。
        revisions[value.field, default: 0] += 1
        let raw = (try? localStorage.read(value.field)) ?? .unavailable
        let matches = raw == value.raw
        if matches { updateLocalValue(value) }
        let after = LocalPreferenceSnapshot(source: localPreferenceSource, field: value.field,
            revision: revisions[value.field, default: 0], value: localValue(value.field), raw: raw)
        var result = LocalPreferenceWriteResult(requested: value, before: before, after: after, write: write,
            readback: matches ? .matches : raw == .unavailable ? .unavailable : .differs)
        guard matches else { return result }
        if value.field == .appearance { result.appearance = applyAppAppearance() }
        let change = LocalPreferenceChange(source: localPreferenceSource, field: value.field, revision: after.revision)
        result.event = call { try effects.post(Notification(name: .localPreferenceDidChange, object: change)) }
        return result
    }

    /// 只重试失败的进程内展示步骤；后来写过同字段即使值相同也不能重放旧展示。
    func retryLocalSettingPresentation(_ result: LocalPreferenceWriteResult,
                                       validateBeforeApply: () throws -> Void) throws -> CommandPreferencePresentation {
        guard !isApplyingLocalSetting else { throw CommandExecutionError.busy }
        isApplyingLocalSetting = true
        defer { isApplyingLocalSetting = false }
        guard result.write == .returned, result.readback == .matches, let after = result.after,
              readLocalSetting(result.requested.field) == after else { return .superseded }
        try validateBeforeApply()
        var appearance = result.appearance, event = result.event
        if appearance == .threw { appearance = applyAppAppearance() }
        if event == .threw {
            let change = LocalPreferenceChange(source: after.source, field: after.field, revision: after.revision)
            event = call { try effects.post(Notification(name: .localPreferenceDidChange, object: change)) }
        }
        return .applied(appearance: appearance, event: event)
    }

    private func localValue(_ field: LocalPreferenceField) -> LocalPreferenceValue {
        switch field {
        case .language: return .language(language)
        case .appearance: return .appearance(appearance)
        case .quadrantTitleTruncation: return .quadrantTitleTruncation(quadrantTitleTruncation)
        case .stampCaptureApp: return .stampCaptureApp(stampCaptureApp)
        }
    }

    private func updateLocalValue(_ value: LocalPreferenceValue) {
        switch value {
        case .language(let next): languageValue = next
        case .appearance(let next): appearanceValue = next
        case .quadrantTitleTruncation(let next): truncationValue = next
        case .stampCaptureApp(let next): captureValue = next
        }
    }

    private func call(_ action: () throws -> Void) -> PreferenceCallOutcome {
        do { try action(); return .returned } catch { return .threw }
    }

    func storedBoardFilters() -> BoardFilters {
        guard let data = defaults.data(forKey: Self.boardFiltersKey) else { return BoardFilters() }
        return BoardFilterCodec.decode(data) ?? BoardFilters()
    }

    func storeBoardFilters(_ filters: BoardFilters) {
        guard !isLoading, let data = BoardFilterCodec.encode(filters) else { return }
        defaults.set(data, forKey: Self.boardFiltersKey)
    }

    private func notifyChange() {
        try? effects.post(Notification(name: .appPreferencesDidChange, object: nil))
    }
}

@MainActor
struct AppChrome: ViewModifier {
    @Bindable var prefs: AppPreferences

    init(prefs: AppPreferences? = nil) {
        self.prefs = prefs ?? .shared
    }

    func body(content: Content) -> some View {
        content
            .environment(prefs)
            .environment(\.locale, prefs.resolvedLocale)
            .preferredColorScheme(prefs.resolvedColorScheme)
    }
}

extension View {
    @MainActor
    func appChrome() -> some View {
        modifier(AppChrome())
    }
}
