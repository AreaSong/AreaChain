import SwiftUI

struct AttachmentThumbnails: View {
    var items: [AttachmentRef]
    @State private var preview: AttachmentRef?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    preview = item
                } label: {
                    thumbnail(item)
                }
                .buttonStyle(.plain) // control: 附件缩略图点击区
                .help(item.filename)
                .accessibilityLabel("a11y.attachment \(item.filename)")
            }
        }
        .popover(item: $preview) { item in
            if let image = AttachmentStore.image(reference: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 360, maxHeight: 360)
                    .padding(8)
            } else {
                Text(item.filename)
                    .font(.system(size: 12))
                    .foregroundStyle(DaybookTheme.muted)
                    .padding(12)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock)) { _ in preview = nil }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask)) { _ in preview = nil }
    }

    @ViewBuilder
    private func thumbnail(_ item: AttachmentRef) -> some View {
        if let image = AttachmentStore.image(reference: item) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .contentShape(Rectangle())
        } else {
            Image(systemName: "photo")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
    }
}
