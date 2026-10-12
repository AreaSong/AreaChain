import SwiftUI

struct AttachmentThumbnails: View {
    var items: [AttachmentRef]
    var inMemoryData: [UUID: Data] = [:]
    var thumbnailSize: CGFloat = 22
    var onRemove: ((AttachmentRef) -> Void)? = nil
    @Environment(\.workspaceHostContext) private var hostContext
    @State private var preview: AttachmentRef?

    private var cornerRadius: CGFloat {
        thumbnailSize > 28 ? DaybookRadius.small : DaybookRadius.xxs
    }

    var body: some View {
        HStack(spacing: thumbnailSize > 28 ? 8 : 4) {
            ForEach(items) { item in
                ZStack(alignment: .topTrailing) {
                    Button {
                        preview = item
                    } label: {
                        thumbnail(item)
                    }
                    .buttonStyle(.plain) // control: 附件缩略图点击区
                    .help(item.filename)
                    .accessibilityLabel("a11y.attachment \(item.filename)")

                    if let onRemove {
                        Button {
                            if preview?.id == item.id { preview = nil }
                            onRemove(item)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(DaybookType.caption)
                                .foregroundStyle(DaybookPalette.text.primary)
                                .background(
                                    Circle()
                                        .fill(DaybookPalette.fill.surface)
                                        .padding(1)
                                )
                        }
                        .buttonStyle(.plain) // control: 附件缩略图移除按钮
                        .help("alert.trash.move")
                        .accessibilityIdentifier("attachment.remove.\(item.id.uuidString)")
                        .offset(x: 4, y: -4)
                    }
                }
                .padding(.top, onRemove != nil ? 4 : 0)
                .padding(.trailing, onRemove != nil ? 4 : 0)
            }
        }
        .popover(item: $preview) { item in
            if let image = loadedImage(item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360, maxHeight: 360)
                    .padding(8)
            } else {
                Text(item.filename)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .padding(12)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock)) { _ in preview = nil }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask)) { _ in preview = nil }
    }

    @ViewBuilder
    private func thumbnail(_ item: AttachmentRef) -> some View {
        let isPending = inMemoryData[item.id] != nil
        let borderColor = isPending ? DaybookPalette.accent.border : DaybookPalette.border.default
        if let image = loadedImage(item) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize, height: thumbnailSize)
                .background(DaybookPalette.fill.surface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: thumbnailSize > 28 ? 1.0 : 0.8)
                )
                .contentShape(Rectangle())
        } else {
            Image(systemName: "photo")
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .background(DaybookPalette.fill.surface)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: thumbnailSize > 28 ? 1.0 : 0.8)
                )
                .contentShape(Rectangle())
        }
    }

    private func loadedImage(_ item: AttachmentRef) -> NSImage? {
        if let data = inMemoryData[item.id] {
            return NSImage(data: data)
        }
        if let hostContext {
            guard let store = hostContext.attachments,
                  let data = try? store.readOrdinary(reference: item, root: store.directory()) else { return nil }
            return NSImage(data: data)
        }
        return AttachmentStore.image(reference: item)
    }
}
