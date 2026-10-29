import Foundation

/// 窗口失焦遮罩后的唯一显式恢复入口。重新拿到 key 本身不恢复，
/// 须由用户在搜索框里的显式动作（改字、Return、⌘Return、↑↓、⌘F）解除本地遮罩并按宿主保留的查询重读，再处理这次动作。
/// 这里只调用 `resumeDisplay` 与（锁定清查询后的）可信页面 enterPage：认证中、更改方式中、vault 不可用与隐私代次
/// 仍由 ReadSession 的 eligibleHost 挡住；真正锁定时已清掉的查询不恢复（重读的是协调者里当前的查询，不是旧文字）。
extension UnifiedSearchController {
    /// 返回继续这次动作要用的缓冲：通常就是 source；锁定清掉查询后经可信页面重建时是重建后的新缓冲（lease 已推进）。
    /// 遮罩时先解除遮罩：reread 为真则按当前查询重读，读完（成功或失败）且缓冲未变才执行 action；
    /// reread 为假（调用方自己会按新文字重读）则解除后立即执行。宿主已变、门禁拒绝或不能重建时返回 nil，不执行 action，给出可见原因。
    @discardableResult
    func resumeForExplicitAction(source: UnifiedSearchBuffer, reread: Bool = true,
                                 then action: ((UnifiedSearchBuffer) -> Void)? = nil) -> UnifiedSearchBuffer? {
        let masked = session.isMasked
        if masked {
            do { try session.resumeDisplay(expecting: source.lease) } catch { reportGate(error); return nil }
            messageKey = "unified.results.awaiting"
            refreshOperationPresentation()
        }
        guard let source = rebuildAfterPrivacyReset(source) else { return nil }
        guard masked, reread else { action?(source); return source }
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
            action?(source)
        }
        return source
    }

    /// edit／accept 用：经显式恢复入口后换上可继续使用的来源缓冲（重建后 lease 已推进，旧来源不能再发事件）。
    func resumedRequest(_ request: UnifiedSearchEdit, reread: Bool = true) -> UnifiedSearchEdit? {
        resumeForExplicitAction(source: request.source, reread: reread).map {
            UnifiedSearchEdit(source: $0, text: request.text, selection: request.selection, acceptance: request.acceptance)
        }
    }

    /// 真正锁定清掉查询后（ContentQueryReducer.privacyReset），查询绑定停在 privacyInvalidated，只能由宿主明确传入
    /// 可信当前页面（enterPage）重建。只在显式动作里做，重新拿到 key 不会走到这里。先过 eligibleHost 的其余门禁：
    /// 认证中、更改方式中、vault 不可用照常拒绝并说明，不因重建绕过。重建只换页面上下文——旧查询文字与条件已被清空，
    /// 不恢复；之后的读取仍按当时的保险箱状态取可见范围（仍锁定时受保护内容照旧不出现）。
    private func rebuildAfterPrivacyReset(_ source: UnifiedSearchBuffer) -> UnifiedSearchBuffer? {
        // 没有注入可信页面的宿主（隔离夹具）照旧：不重建，由后续读取门禁给出 pageContextRequired。
        guard queryAwaitsTrustedPage, let trustedPage else { return source }
        do { try session.validateDisplayHost(expecting: source.lease) }
        catch ContentQueryReadSessionError.pageContextRequired {}
        catch { reportGate(error); return nil }
        do { try coordinator.send(.query(.enterPage(trustedPage())), expecting: source.lease) } catch { reportGate(); return nil }
        guard !queryAwaitsTrustedPage, let owned = try? coordinator.host(source.lease.ownership.hostID) else {
            reportGate(ContentQueryReadSessionError.pageContextRequired); return nil
        }
        renewBuffer(owned.lease)
        return buffer
    }

    /// 查询是否仍在等宿主给可信页面（锁定清查询之后、显式动作重建之前）。
    var queryAwaitsTrustedPage: Bool {
        (try? coordinator.host(buffer.lease.ownership.hostID).session.query.binding) == .independent(.privacyInvalidated)
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
