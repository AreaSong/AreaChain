import Foundation

/// 窗口失焦遮罩后的唯一显式恢复入口。重新拿到 key 本身不恢复，
/// 须由用户在搜索框里的显式动作（改字、Return、⌘Return、↑↓、⌘F）解除本地遮罩并按宿主保留的查询重读，再处理这次动作。
extension UnifiedSearchController {
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

    func resumedRequest(_ request: UnifiedSearchEdit, reread: Bool = true) -> UnifiedSearchEdit? {
        resumeForExplicitAction(source: request.source, reread: reread).map {
            UnifiedSearchEdit(source: $0, text: request.text, selection: request.selection)
        }
    }

    private func rebuildAfterPrivacyReset(_ source: UnifiedSearchBuffer) -> UnifiedSearchBuffer? {
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

    var queryAwaitsTrustedPage: Bool {
        (try? coordinator.host(buffer.lease.ownership.hostID).session.query.binding) == .independent(.privacyInvalidated)
    }

    func reportGate(_ error: Error? = nil) {
        navigationMessage = gateMessage(error)
    }

    func gateMessage(_ error: Error? = nil) -> String {
        if let error = error as? ContentQueryReadSessionError { return Self.gateKey(error) }
        if isNavigationPresented { return "unified.gate.navigationPresented" }
        do { try session.validateDisplayHost(expecting: buffer.lease) } catch {
            return Self.gateKey(error as? ContentQueryReadSessionError ?? .staleHost)
        }
        return "unified.gate.stale"
    }

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
