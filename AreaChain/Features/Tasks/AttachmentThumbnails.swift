import SwiftUI

struct QuadrantDots: View {
    var isImportant: Bool
    var isUrgent: Bool

    var body: some View {
        if isImportant || isUrgent {
            HStack(spacing: 3) {
                if isImportant {
                    Circle()
                        .fill(DaybookTheme.stamp)
                        .frame(width: 5, height: 5)
                        .accessibilityLabel("classify.important")
                        .help("classify.important")
                }
                if isUrgent {
                    Circle()
                        .stroke(DaybookTheme.stamp, lineWidth: 1.2)
                        .frame(width: 5, height: 5)
                        .accessibilityLabel("classify.urgent")
                        .help("classify.urgent")
                }
            }
        }
    }
}

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
                .buttonStyle(.plain)
                .help(item.filename)
            }
        }
        .popover(item: $preview) { item in
            if let image = AttachmentStore.image(id: item.id) {
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
    }

    @ViewBuilder
    private func thumbnail(_ item: AttachmentRef) -> some View {
        if let image = AttachmentStore.image(id: item.id) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        } else {
            Image(systemName: "photo")
                .font(.system(size: 10))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 18, height: 18)
        }
    }
}