import Foundation
import SwiftData

/// 手记类简单指令的显式装配：手记仓储（隔离保险箱与附件目录）、任务仓储、附件位置、日期、来源戳与带键摘要
/// 都由调用方注入。只在测试夹具里构造；生产没有构造点。
@MainActor struct DiaryCommandDependencies {
    var diaries: (ModelContext) -> SwiftDataDiaryRepository
    var tasks: (ModelContext) -> any TaskRepositoryProtocol = { SwiftDataTaskRepository(context: $0) }
    var attachments: TaskNotesService.Attachments
    var today: () -> String
    /// 转任务时的来源戳（原界面沿 CaptureStamp 与偏好）；隔离环境注入固定值。
    var sourceBundleID: () -> String
    /// 协调者的带键摘要；正文基线只存 HMAC，不存明文。
    var digest: CommandTextDigest
}

/// 手记类指令共用的读取、保护判定与显示规则。只有普通手记直接执行（用户决定）：
/// 受保护（加密、私密标记、挂私密标签）的目标在读取正文之前就拒绝，面板改为“打开原手记页”。
@MainActor enum DiaryCommandSpecs {
    /// 正文（受控借用）：新建与改写。默认不装配，只在隔离 QA 测试里显式传给 SimpleCommandAdapter。
    static func longText(_ dependencies: DiaryCommandDependencies) -> [any SimpleCommandSpec] {
        [DiaryCreateSpec(dependencies: dependencies), DiaryBodySpec(dependencies: dependencies)]
    }

    /// 同 UUID 多行拒绝；回收站里的手记只有 allowDeleted（回收的写后核对）才接受。
    static func entry(_ id: UUID, in context: ModelContext, allowDeleted: Bool = false) throws -> DiaryEntry {
        let rows = try context.fetch(FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.id == id }))
        guard let entry = rows.first else { throw CommandSimpleIssue.invalidTarget(.missing) }
        guard rows.count == 1 else { throw CommandSimpleIssue.invalidTarget(.duplicate) }
        guard allowDeleted || entry.deletedAt == nil else { throw CommandSimpleIssue.invalidTarget(.deleted) }
        return entry
    }

    /// 普通手记才返回；受保护的在读取正文前就拒绝（DiaryWriteService.isOrdinary 只看记录字段与标签关联）。
    static func ordinary(_ target: CommandObjectReference, in context: ModelContext,
                         allowDeleted: Bool = false) throws -> DiaryEntry {
        guard target.type == .diary else { throw CommandSimpleIssue.invalidArguments }
        let entry = try entry(target.id, in: context, allowDeleted: allowDeleted)
        guard DiaryWriteService.isOrdinary(entry, tags: try context.fetch(FetchDescriptor<TagItem>())) else {
            throw CommandSimpleIssue.invalidTarget(.protectedDiary)
        }
        return entry
    }

    /// 行标题沿卡片行的首行（最多 40 字）；只用于普通手记。
    static func title(_ text: String) -> String {
        let main = DiaryCopyContent.split(text).mainText
        return main.isEmpty ? "—" : String(main.prefix(40))
    }

    /// 长文两条（新建、改写正文）的行标题只用归属日：标题行就是正文，预览、接受与回执里不能出现正文。
    static func dayTitle(_ dayKey: String) -> String { dayKey }

    /// 正文只给带键摘要与字数，不存明文；摘要只用于冲突比较。
    static func bodyField(_ text: String, _ digest: CommandTextDigest) -> CommandSimpleField {
        .init(id: "body", value: digest.hex(text), display: .count("unified.simple.value.characters", text.count))
    }

    /// 手记标签按名字排序：仓储从集合编码关联，保存后的顺序不固定，比较只看集合。
    static func tagsField(_ names: [String]) -> CommandSimpleField {
        TaskCommandSpecs.tagsField(names.sorted())
    }

    static func tagNames(_ encoded: String, in context: ModelContext) throws -> [String] {
        try TaskCommandSpecs.tagNames(encoded, in: context)
    }

    static func pinnedField(_ pinned: Bool) -> CommandSimpleField {
        .init(id: "pinned", value: pinned ? "on" : "off",
              display: .localized(pinned ? "unified.simple.value.pinned" : "unified.simple.value.unpinned"))
    }

    static func dayField(_ key: String) -> CommandSimpleField { .init(id: "day", value: key, display: .verbatim(key)) }

    static func row(_ entry: DiaryEntry, fields: [CommandSimpleField]) -> CommandSimpleRow {
        .init(key: entry.id.uuidString, record: entry.persistentModelID, title: title(entry.text), fields: fields)
    }

    static func value(_ input: CommandResolvedInput, _ parameter: CommandParameterID) -> CommandArgument? {
        input.arguments.first { $0.parameter == parameter }
    }
}
