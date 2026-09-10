import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// 视图层附件交互控制器：负责文件选取器、剪贴板粘贴、截屏以及相关系统弹窗提示
@MainActor
enum AttachmentPicker {
    /// 打开系统文件选取对话框并导入附件
    static func pickImage(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .gif, .tiff, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let data = try? Data(contentsOf: url) else { return }
            persist {
                _ = try? store.save(
                    data: data,
                    filename: url.lastPathComponent,
                    ownerKind: ownerKind,
                    ownerID: ownerID,
                    context: context,
                    root: nil,
                    id: UUID(),
                    createdAt: .now
                )
            }
        }
    }

    /// 从系统剪贴板读取图片并导入附件
    @discardableResult
    static func pasteImage(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared
    ) -> Bool {
        guard let image = ImageBytes.pasteboardImage(), let data = ImageBytes.png(from: image) else {
            NSSound.beep()
            return false
        }
        persist {
            _ = try? store.save(
                data: data,
                filename: "paste.png",
                ownerKind: ownerKind,
                ownerID: ownerID,
                context: context,
                root: nil,
                id: UUID(),
                createdAt: .now
            )
        }
        return true
    }

    /// 截取屏幕并导入附件，如发生权限或编码错误展示告警弹窗
    static func captureScreen(
        ownerKind: AttachmentOwner,
        ownerID: UUID,
        context: ModelContext,
        store: any AttachmentStorageProtocol = AttachmentStore.shared
    ) {
        Task { @MainActor in
            switch await ScreenCapture.pngData() {
            case .success(let data):
                persist {
                    _ = try? store.save(
                        data: data,
                        filename: "screen.png",
                        ownerKind: ownerKind,
                        ownerID: ownerID,
                        context: context,
                        root: nil,
                        id: UUID(),
                        createdAt: .now
                    )
                }
            case .failure(let failure):
                NSSound.beep()
                presentCaptureFailure(failure)
            }
        }
    }

    /// 移至废纸篓（软删除）
    static func trash(_ item: AttachmentItem) {
        persist { item.deletedAt = .now }
    }

    private static func presentCaptureFailure(_ failure: ScreenCaptureFailure) {
        let alert = NSAlert()
        alert.messageText = L10n.string(
            String.LocalizationValue(stringLiteral: failure.messageKey),
            locale: AppPreferences.shared.resolvedLocale
        )
        alert.alertStyle = .informational
        alert.runModal()
    }

    private static func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }
}

/// 向后兼容别名，确保现有 TaskDetailDrawer / DiaryNoteCard / TaskRowContext / AttachmentBrowserPage 调用完全无需修改
typealias AttachmentActions = AttachmentPicker
