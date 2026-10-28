import Foundation

/// 修复批 M-7G：窗口失焦遮罩后的唯一显式恢复入口。设计规则（§9.39、D3）：重新拿到 key 本身不恢复，
/// 须由用户在搜索框里的显式动作（改字、Return、⌘Return、↑↓、⌘F）解除本地遮罩并按宿主保留的查询重读，再处理这次动作。
/// 这里只调用 `resumeDisplay`：锁定、认证中、隐私代次与页面上下文仍由 ReadSession 的 eligibleHost 挡住；
/// 锁定已按 D3 清掉的查询不在这里恢复（重读的是协调者里当前的查询，不是旧文字）。
extension UnifiedSearchController {
    /// 未遮罩时立即执行 action。遮罩时先解除遮罩：reread 为真则按当前查询重读，读完（成功或失败）且缓冲未变才执行 action；
    /// reread 为假（调用方自己会按新文字重读）则解除后立即执行。宿主已变不能恢复时不执行 action，给出可见原因。
    @discardableResult
    func resumeForExplicitAction(source: UnifiedSearchBuffer, reread: Bool = true, then action: (() -> Void)? = nil) -> Bool {
        guard session.isMasked else { action?(); return true }
        do { try session.resumeDisplay(expecting: source.lease) } catch { reportGate(error); return false }
        messageKey = "unified.results.awaiting"
        refreshOperationPresentation()
        guard reread else { action?(); return true }
        resumeTask?.cancel()
        // edit／accept 会在本次调用里同步发布新缓冲；重读只认同一所有权与隐私代次下的当前缓冲，
        // 不拿调用时的旧缓冲判断（否则改字成指令、接受候选后的重读会被丢掉）。action 仍只在原缓冲未变时执行。
        let ownership = source.lease.ownership, privacy = source.privacyRevision
        let current = { [weak self] () -> Bool in
            guard let self else { return false }
            return self.buffer.lease.ownership == ownership && self.buffer.privacyRevision == privacy && self.validates(self.buffer)
        }
        resumeTask = Task { @MainActor [weak self] in
            guard let self, current(), !Task.isCancelled else { return }
            do { _ = try await self.readObjectSource() } catch {
                guard current(), !Task.isCancelled else { return }
                self.messageKey = self.session.isMasked ? "unified.results.masked" : "unified.results.readFailed"
                self.refreshOperationPresentation()
            }
            guard self.validates(source), !Task.isCancelled else { return }
            action?()
        }
        return true
    }

    /// 门禁拒绝不再静默：在两宿主共用的反馈行里给一句不阻塞的原因（中英文）。
    func reportGate(_ error: Error? = nil) {
        navigationMessage = gateMessage(error)
    }

    /// 没有给出具体错误时按当前宿主状态推断；只读，不改变任何门禁。
    func gateMessage(_ error: Error? = nil) -> String {
        if let error = error as? ContentQueryReadSessionError { return Self.gateKey(error) }
        if isNavigationPresented { return "unified.gate.navigationPresented" }
        do { try session.validateDisplayHost(expecting: buffer.lease) } catch {
            return Self.gateKey(error as? ContentQueryReadSessionError ?? .staleHost)
        }
        if operations?.pending != nil || plan?.editing != nil || settingSubmitting || settingExecution != nil {
            return "unified.gate.busy"
        }
        return "unified.gate.stale"
    }

    /// 读取被这些门禁拒绝时，结果区只显示“读取失败”不够：在反馈行补一句原因。
    static let explainedGates: Set<ContentQueryReadSessionError> = [.pageContextRequired, .vaultBusy, .vaultUnavailable]

    static func gateKey(_ error: ContentQueryReadSessionError) -> String {
        switch error {
        case .masked: "unified.gate.masked"
        case .vaultBusy: "unified.gate.vaultBusy"
        case .vaultUnavailable: "unified.gate.vaultUnavailable"
        case .trackingPending: "unified.gate.pending"
        case .pageContextRequired: "unified.gate.pageContext"
        default: "unified.gate.stale"
        }
    }
}
