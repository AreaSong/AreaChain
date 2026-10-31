import Foundation

/// “在原页面完成”的唯一对照。系统类、永久删除类、附件系统动作（用户决定）
/// 在指令里只导航到原页面，不写数据、不调系统 API、不申请权限、不打开外部网址；真正的操作由原页面完成。
/// 本表只声明目的地与说明，不是可用性规则，也不授予任何执行能力。
struct CommandOriginalPage: Equatable, Sendable {
    enum Destination: Equatable, Sendable {
        /// WorkspaceTab 的 rawValue；`focusesTrash` 时若当前焦点是回收站结果，就在回收站里定位到它。
        case page(String, focusesTrash: Bool = false)
        /// 当前结果焦点项的详情（沿 inspector.open 的解析与导航）；手记对象打开手记页。
        case object
        /// 原页面说明、示例预填（只放进搜索框，不执行）。
        case pageHelp, example
        /// 通知横幅上的动作：搜索里没有对应通知，只提供跳到其他指令的入口，不另写执行。
        case useInstead([CommandID])
    }

    let command: CommandID
    let destination: Destination
    /// 原页面里对应分节的标题键（只用于说明，页面不自动滚动）。
    let sectionKey: String?
    let noteKey: String
    /// false 表示指令本身就是导航或帮助（notification.open、help.*、通知横幅动作的改用入口），预览不说“要在原页面完成”。
    let finishesOnPage: Bool

    static func route(for id: CommandID) -> CommandOriginalPage? { table[id] }

    static let all: [CommandOriginalPage] = {
        var rows: [CommandOriginalPage] = []
        func add(_ ids: String, _ destination: Destination, section: String? = nil, note: String, finishes: Bool = true) {
            for id in ids.split(separator: " ") {
                rows.append(.init(command: .init(rawValue: String(id)), destination: destination,
                                  sectionKey: section, noteKey: "command.originalPage.note." + note, finishesOnPage: finishes))
            }
        }
        // 永久删除与清理
        add("tag.delete", .page("tags"), section: "tags.deleted.show", note: "permanentDeletion")
        add("tag.cleanup", .page("tags"), note: "cleanup")
        add("clipboard.delete clipboard.prune clipboard.empty", .page("clipboard"), note: "permanentDeletion")
        // 剪贴板记录控制与偏好（偏好在剪贴板页的“剪贴板选项”里，设置页没有剪贴板分节）
        add("clipboard.recording clipboard.skipNext clipboard.ignoreApp", .page("clipboard"), note: "clipboardControl")
        add("""
            clipboard.ignoreUniversal clipboard.limit clipboard.interval clipboard.searchMode clipboard.position \
            clipboard.clickAction clipboard.plainText clipboard.sound clipboard.unignoreApp clipboard.addPattern \
            clipboard.removePattern clipboard.addType clipboard.removeType
            """, .page("clipboard"), section: "clipboard.options", note: "preference")
        // 选图、粘贴图、截图
        add("image.pick image.paste image.capture", .object, note: "attachment")
        // 设置里的系统分节
        add("setting.login setting.loginSettings", .page("settings"), section: "settings.launch", note: "system")
        add("notification.status notification.request notification.test notification.settings",
            .page("settings"), section: "settings.notify", note: "system")
        add("calendarSync.enabled calendarSync.status calendarSync.retry calendarSync.settings calendarSync.conflicts",
            .page("settings"), section: "settings.calendar.sync", note: "system")
        // 搜索里没有日历冲突对象的来源，打开本地项只能从设置的冲突对照里进入。
        add("calendarSync.openLocal", .page("settings"), section: "settings.calendar.sync", note: "calendarConflict")
        add("setting.icloud", .page("settings"), section: "settings.icloud", note: "info")
        // 通知横幅动作
        add("notification.complete", .useInstead([.init(rawValue: "todo.completion"), .init(rawValue: "occurrence.complete")]),
            note: "useInstead", finishes: false)
        add("notification.snooze", .useInstead([.init(rawValue: "todo.reminder")]), note: "useInstead", finishes: false)
        add("notification.open", .object, note: "openObject", finishes: false)
        // 快捷键
        add("shortcut.record shortcut.reset shortcut.resetAll shortcut.cancel", .page("shortcuts"), note: "shortcut")
        // 隐私指令：除 privacy.lock（直接执行）外的全部隐私指令
        add("""
            privacy.create privacy.setupMethod privacy.setupTags privacy.protectExisting privacy.unlock \
            privacy.systemUnlock privacy.setPassword privacy.changePassword privacy.removePassword privacy.idle \
            privacy.tags privacy.unprotect privacy.retryImages privacy.retryKeys privacy.quitForCleanup
            """, .page("privacy"), note: "privacy")
        // 手记“私密”标记、显示与遮罩要在原手记页完成（认证、隐私转换与显示状态都属于那一页）
        add("diary.privateMark diary.reveal diary.mask", .page("diary"), note: "diaryPrivacy")
        // 回收站永久删除、数据交换、加密备份、降级恢复（降级提示就在数据与备份页）
        add("trash.delete trash.empty", .page("trash", focusesTrash: true), note: "permanentDeletion")
        // 回收站浏览：原界面是回收站页的五组列表与类别筛选；类别参数不在指令里执行，在页面的筛选里选。
        add("trash.browse", .page("trash"), note: "trashBrowse", finishes: false)
        add("data.export data.selectImport data.validateImport data.previewImport data.applyImport",
            .page("dataBackup"), note: "data")
        add("backup.export backup.inspect backup.preview backup.restore", .page("dataBackup"), note: "backup")
        add("recovery.status recovery.resetQuit", .page("dataBackup"), note: "recovery")
        // 帮助
        add("help.syntax", .page("searchGuide"), note: "searchGuide", finishes: false)
        add("help.page", .pageHelp, note: "pageHelp", finishes: false)
        add("help.example", .example, note: "example", finishes: false)
        // 版本、支持、关于（不在指令里打开外部网址）
        add("support.version", .page("settings"), section: "project.version.section", note: "support")
        add("support.discussion support.suggestion support.issue", .page("settings"),
            section: "project.support.section", note: "support")
        add("support.about support.repository support.license", .page("settings"),
            section: "project.about.section", note: "support")
        return rows
    }()

    private static let table: [CommandID: CommandOriginalPage] = Dictionary(
        all.map { ($0.command, $0) }, uniquingKeysWith: { first, _ in first })
}

extension CommandDescriptor {
    /// 目录条目的“在原页面完成”标记：唯一来源是 CommandOriginalPage，不另起可用性规则。
    var completesOnOriginalPage: Bool { CommandOriginalPage.route(for: id)?.finishesOnPage == true }
}
