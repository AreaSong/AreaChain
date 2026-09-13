import Foundation
import Observation

struct DiaryComposerDraft {
    var id = UUID()
    var text = ""
    var selectedTagIDs: Set<UUID> = []
}

/// 只在本次运行保留快速草稿；收起菜单栏不等于主动丢弃，也不把未保存正文写到偏好中。
@Observable @MainActor
final class DiaryCaptureSession {
    static let shared = DiaryCaptureSession()
    var draft = DiaryComposerDraft()
}
