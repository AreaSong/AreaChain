import Foundation
import SwiftData

/// 普通手记写入的唯一共享入口。原界面（手记页快速新增、菜单栏与今日页的“记一条”、手记卡片转任务）
/// 转调这里，行为与抽出前逐字一致；指令只经 CommandLongTextEscrow.swift 里的借用出口（`applyLent`）写正文。
/// 保护判定只用现有规则（DiaryEntry.hasProtectedContent、DiaryPrivacy、私密标签），受保护手记不读正文、不解密。
@MainActor enum DiaryWriteService {
    /// 手记页快速新增的“自动分类”：标题／正文分隔与 #标签（含手记预置分类）解析，取自原 DiaryQuickComposerView.submitNote。
    struct Capture: Equatable {
        /// 要保存的正文；为空表示没有可保存的内容。
        let text: String
        /// 解析出的标签名，由调用方在同一流程里经 InputTagResolver 解析为 ID。
        let tagNames: [String]
    }

    static func capture(_ rawText: String) -> Capture {
        let parsed = NaturalLanguageParser.parseDiaryCapture(rawText)
        let text: String
        if parsed.hasNoteSeparator && !parsed.cleanTitle.isEmpty {
            text = parsed.cleanTitle + (parsed.body.isEmpty ? "" : "\n" + parsed.body)
        } else if !parsed.body.isEmpty {
            text = parsed.body
        } else {
            text = NaturalLanguageParser.unescapeSyntax(rawText)
        }
        return .init(text: text, tagNames: parsed.tagNames)
    }

    /// 新建手记的唯一写入（原 DayBoardMutations.addDiary 的闭包）：SwiftData 仓储按调用方决定是否允许锁定时插入，
    /// 其他仓储走协议方法。事务与失败处理由调用方提供。
    @discardableResult
    static func add(text: String, dayKey: String, tagIDs: Set<UUID>, allowLockedInsert: Bool,
                    repository: any DiaryRepositoryProtocol) throws -> DiaryEntry {
        if let swiftData = repository as? SwiftDataDiaryRepository {
            return try swiftData.addDiary(text: text, dayKey: dayKey, tagIDs: tagIDs, allowLockedInsert: allowLockedInsert)
        }
        return try repository.addDiary(text: text, dayKey: dayKey, tagIDs: tagIDs)
    }

    /// 正文全文改写的两种操作（目录 body：clear 因不允许空值在静态校验就被拒，与仓储“手记内容不能为空”一致）。
    /// 追加以换行接在原正文后，同备注追加。
    enum BodyEdit: Equatable {
        case replace(String), append(String)

        init(_ operation: CommandFieldOperation, text: String) throws {
            switch operation {
            case .replace: self = .replace(text)
            case .append: self = .append(text)
            default: throw CommandSimpleIssue.invalidArguments
            }
        }

        func final(_ current: String) -> String {
            switch self {
            case .replace(let text): return text
            case .append(let text): return current.isEmpty ? text : current + "\n" + text
            }
        }
    }

    // MARK: - 保护判定（不读受保护正文）

    /// 普通手记：未加密、没有私密标记、没有挂私密标签（含已删除的私密标签）。与原卡片的敏感判定、
    /// 小窗与其他指令的受保护拒绝同一口径；看记录字段、标签关联，以及未加密正文里的旧 #密码 标记
    /// （isSensitive 自 2026-10-23 恢复该规则），不读取受保护正文。
    static func isOrdinary(_ entry: DiaryEntry, tags: [TagItem]) -> Bool {
        !entry.hasProtectedContent && !DiaryPrivacy.isSensitive(entry.snapshot, tags: tags)
    }

    /// 保存后会不会变成受保护：与仓储 writeContent 同一规则（正文里的标签名或要关联的 ID 命中私密标签，含已删除的）。
    static func becomesProtected(text: String, tagIDs: Set<UUID>, tags: [TagItem]) -> Bool {
        DiaryPrivacy.requiresProtection(text: text, tagIDs: tagIDs, tags: tags)
    }

    /// 要关联的标签里有私密标签（加私密标签等于隐私转换，只能在原手记页完成）。
    static func containsPrivateTag(_ ids: Set<UUID>, tags: [TagItem]) -> Bool {
        tags.contains { $0.isPrivateDiary && ids.contains($0.id) }
    }

    // MARK: - 转今天任务

    /// 原 DayBoardMutations.convertDiaryToTodo 的规则：首行做标题（首行为空取其余），其余做备注；不带标签与附件、不做 NLP。
    /// 只接普通手记的明文；空正文返回 nil。
    static func todoText(from raw: String) -> (title: String, notes: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let newlineIndex = trimmed.firstIndex(of: "\n") else { return (trimmed, "") }
        let firstLine = String(trimmed[..<newlineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = String(trimmed[trimmed.index(after: newlineIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (firstLine.isEmpty ? rest : firstLine, rest)
    }
}

extension DiaryWriteService {
    /// 快速新增解析出的标签名（含手记预置分类）里有没有落到私密标签（同 InputTagResolver 的匹配，含已删除的）。
    static func capturesPrivateTag(_ capture: Capture, tags: [TagItem]) -> Bool {
        let names = Set(capture.tagNames.map(TagSyntax.normalizedName))
        return tags.contains { $0.isPrivateDiary && names.contains(TagSyntax.normalizedName($0.name)) }
    }
}
