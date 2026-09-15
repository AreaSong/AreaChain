import Foundation
import Observation
import SwiftData

/// 草稿由列表持有，不能随搜索过滤销毁的卡片一起丢失；密文封存复用小窗编辑会话。
@Observable @MainActor
final class DiaryCardDrafts {
    private var sessions: [UUID: DiaryEditorSession] = [:]

    func editor(for id: UUID) -> DiaryEditorSession? { sessions[id] }

    @discardableResult
    func begin(_ entry: DiaryEntry, context: ModelContext, vault: PrivacyVault) -> DiaryEditorSession {
        if let existing = sessions[entry.id] { existing.reveal(); return existing }
        let session = DiaryEditorSession(source: .entry(entry), context: context, vault: vault)
        sessions[entry.id] = session
        session.reveal()
        return session
    }

    func discard(_ id: UUID) {
        sessions[id]?.mask()
        sessions.removeValue(forKey: id)
    }

    func maskAll() { sessions.values.forEach { $0.mask() } }
}
