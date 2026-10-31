import Foundation

/// capture.clipboard：目录是 systemAction／externalEffect（不入普通队列），因此沿 todo.copy 只读当前操作草稿、
/// 不建 Run。预览阶段不读剪贴板，只说明“将读取当前剪贴板”；读取只在用户明确提交后发生一次。
enum ClipboardCaptureCommandIssue: Error, Equatable {
    case unassembled, unsupportedPlan, stale, alreadySubmitted, verificationRequired
    /// 提交时剪贴板既没有文字也没有图片：未写入任何内容。
    case empty
}

struct CommandClipboardCapturePreview: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    static let command = "capture.clipboard"
    let lease: CommandHostLease
    let draft: CommandDraftStamp
    let environmentID: UUID
    /// 新待办落在哪一天；跨日后需要重新准备。
    let dayKey: String
    /// 偏好“附来源 Bundle ID”是否开启；预览只说明会不会附，不读前台应用。
    let stampsSource: Bool
    /// 新待办与可能的图片附件身份在准备时分配一次；同一份预览只能提交一次，重试不会另建。
    let todoID: UUID
    let attachmentID: UUID
    var description: String { "CommandClipboardCapturePreview(redacted)" }
    var debugDescription: String { description }

    /// 只接无参数、无目标、普通保护要求的当前草稿；不入列。
    static func validate(_ draft: CommandDraft) throws {
        guard draft.commandID.rawValue == command, draft.targets == .none, draft.arguments.isEmpty,
              draft.baseline == CommandDraftBaseline(), !draft.blocksUnprotectedExport,
              draft.protectionRequirement == .ordinary, draft.check().staticallyValid else {
            throw ClipboardCaptureCommandIssue.unsupportedPlan
        }
    }
}

/// 提交结果。saved 只在保存成功后出现；unknown 表示保存已调用但结果不明，需先核对，不自动重试。
struct CommandClipboardCaptureFacts: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    /// protectedTag：剪贴板文字里有私密或预设标签，指令整条不写（原界面菜单栏入口仍跳过标签照常保存）。
    enum State: String, Equatable { case notSubmitted, empty, saved, unknown, protectedTag }
    enum Kind: String, Equatable { case text, image }
    let draft: CommandDraftStamp
    let todoID: UUID
    var state: State
    var kind: Kind?
    var attachedImage = false
    var tagCount = 0
    /// protectedTag 时逐个列出命中的标签（预置名或私密标签名）及其原因键。
    var protectedTags: [CommandSimpleNotice] = []
    var publication = CommandTaskTitleFacts.Call.notCalled
    var description: String { "CommandClipboardCaptureFacts(\(state))" }
    var debugDescription: String { description }
}

/// 未知结果的只读核对：按准备时分配的待办身份在同容器新 context 里查找。
enum CommandClipboardCaptureVerification: String, Equatable {
    case present, absent, ambiguous, unreadable
}
