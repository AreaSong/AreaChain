import Foundation

/// 合并批 M-3 B、C：窗口与面板、总览统计、退出，以及直接执行的立即锁定。它们不建草稿、不进计划，
/// 走导航面板的“预览 → 回车”；本类型只做纯解析，执行由显式装配的工作台宿主完成（默认不装配）。
/// 合并批 M-4 起另含手记编辑会话的保存／重载／舍弃（只作用于已打开的普通手记小窗，复用 DiaryEditorSession）
/// 与普通手记复制（原卡片的 PrivateClipboard 路径）。
enum CommandSystemAction: Equatable {
    case workspaceOpen, workspaceReveal, workspaceClose, overlayToggle, overlayMode(String)
    case routineAddPanel, routineManagePanel
    case diaryOpen, diaryDraft, diaryPinned(Bool?), diaryClose
    /// window 为真是 diaryWindow.save（当前或唯一小窗），否则是 diary.save（当前手记结果的小窗）。
    case diarySave(window: Bool), diaryReload, diaryDiscard, diaryCopy(DiaryCopyContent.Section)
    case stats(CommandStatsKind, day: String?), statsOpenDay(String), statsOpenActivity
    case quit, privacyLock

    static let commands: Set<String> = Set([
        "workspace.open", "workspace.reveal", "workspace.close", "overlay.toggle", "overlay.mode",
        "routine.addPanel", "routine.managePanel",
        "diaryWindow.open", "diaryWindow.draft", "diaryWindow.pinned", "diaryWindow.close", "diaryWindow.save",
        "diary.save", "diary.reload", "diary.discard", "diary.copy",
        "stats.openDay", "stats.openActivity", "app.quit", "privacy.lock",
    ]).union(CommandStatsKind.allCases.map { "stats." + $0.rawValue })

    /// 参数来自路径解析；缺少或非法即拒绝，不按默认值猜（统计的日期缺省为今天，与总览页一致）。
    init(command: CommandID, arguments: [CommandArgument]) throws {
        let values = Dictionary(arguments.map { ($0.parameter, $0.value) }, uniquingKeysWith: { _, last in last })
        func day() throws -> String? {
            guard let raw = values[.day] else { return nil }
            guard case .day(let key)? = raw, CommandArgumentValidation.isCanonicalDay(key) else {
                throw CommandPageIssue.invalidArguments
            }
            return key
        }
        func bare() throws { guard arguments.isEmpty else { throw CommandPageIssue.invalidArguments } }
        let raw = command.rawValue
        if raw.hasPrefix("stats."), let kind = CommandStatsKind(rawValue: String(raw.dropFirst(6))) {
            self = .stats(kind, day: try day()); return
        }
        switch raw {
        case "workspace.open": try bare(); self = .workspaceOpen
        case "workspace.reveal": try bare(); self = .workspaceReveal
        case "workspace.close": try bare(); self = .workspaceClose
        case "overlay.toggle": try bare(); self = .overlayToggle
        case "overlay.mode":
            guard case .choice(let mode)?? = values[.mode], ["tasks", "diaries"].contains(mode) else {
                throw CommandPageIssue.invalidArguments
            }
            self = .overlayMode(mode)
        case "routine.addPanel": try bare(); self = .routineAddPanel
        case "routine.managePanel": try bare(); self = .routineManagePanel
        case "diaryWindow.open": try bare(); self = .diaryOpen
        case "diaryWindow.draft": try bare(); self = .diaryDraft
        case "diaryWindow.pinned":
            // 不带值时与小窗按钮一样切换；带值时按值设置。
            if let value = values[.enabled] {
                guard case .boolean(let enabled)? = value else { throw CommandPageIssue.invalidArguments }
                self = .diaryPinned(enabled)
            } else { self = .diaryPinned(nil) }
        case "diaryWindow.close": try bare(); self = .diaryClose
        case "diaryWindow.save": try bare(); self = .diarySave(window: true)
        case "diary.save": try bare(); self = .diarySave(window: false)
        case "diary.reload": try bare(); self = .diaryReload
        case "diary.discard": try bare(); self = .diaryDiscard
        case "diary.copy":
            // 缺省整篇，与目录默认值一致。
            guard let raw = values[.section] else { self = .diaryCopy(.record); return }
            guard case .choice(let value)? = raw, let section = DiaryCopyContent.Section(rawValue: value) else {
                throw CommandPageIssue.invalidArguments
            }
            self = .diaryCopy(section)
        case "stats.openDay":
            guard let key = try day() else { throw CommandPageIssue.invalidArguments }
            self = .statsOpenDay(key)
        case "stats.openActivity": try bare(); self = .statsOpenActivity
        case "app.quit": try bare(); self = .quit
        case "privacy.lock": try bare(); self = .privacyLock
        default: throw CommandPageIssue.unsupported
        }
    }
}

/// 总览统计的八种读取；数字只来自 DashboardProjection（与总览页同一投影），不另算。
enum CommandStatsKind: String, CaseIterable, Equatable {
    case today, pending, streaks, routines, diaries, trend, heatmap, activity
}
