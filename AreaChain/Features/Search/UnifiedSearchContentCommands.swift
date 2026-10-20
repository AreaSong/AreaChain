import Foundation

/// 合并批 M-2 C～D：附件与剪贴板页面指令里需要控制器出面的那一步（打开查阅、窗口与系统剪贴板动作）。
extension UnifiedSearchController {
    /// image.preview：沿 N-M2 的普通图片查阅打开，不另开查看器。指令事件会推进租约、使当前结果的展示许可失效，
    /// 因此先同返回搜索一样恢复展示并按当前查询重读；图片仍在当前结果里可见才打开（WorkspaceContentSession 的门禁不变）。
    func openImageCommand(_ image: CommandObjectReference, source: UnifiedSearchBuffer) throws {
        guard navigationRouter?.contents != nil, let pages = pageCommands, contentCommandTask == nil else {
            throw CommandPageIssue.unassembled
        }
        let parent = try pages.imageOwner(image)
        revokePage()
        contentCommandTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.contentCommandTask = nil }
            do {
                try self.session.resumeDisplay(expecting: self.buffer.lease)
                _ = try await self.readObjectSource()
                guard !Task.isCancelled, self.validates(self.buffer),
                      (try? self.session.presentation().pagination.snapshot.visible.contains(image)) == true else {
                    throw CommandPageIssue.notInList
                }
                self.navigate(.content(image), source: self.buffer, content: .init(object: image, parent: parent, viewingTrash: false))
            } catch {
                self.pageFailure = error as? CommandPageIssue ?? .stale
                self.refreshOperationPresentation()
            }
        }
    }
}
