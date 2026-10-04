import Foundation

/// 隔离编辑器的窄暂持边界：不接收基线、摘要或任意异步工作；撤权必须同步释放原生正文与撤销。
@MainActor protocol CommandDraftNativeOwner: AnyObject {
    var parameter: CommandParameterID { get }
    func installProtectedContents(_ state: CommandDraftEditingState) throws
    func clearProtectedContents()
}
