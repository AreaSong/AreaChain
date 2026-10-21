import AppKit
import SwiftUI

enum AttachmentCarouselSelection {
    static func index(of id: UUID?, in items: [AttachmentRef]) -> Int? {
        guard let id else { return nil }
        return items.firstIndex { $0.id == id }
    }

    static func adjacentID(from id: UUID?, delta: Int, in items: [AttachmentRef]) -> UUID? {
        guard let current = index(of: id, in: items) else { return items.first?.id }
        let target = current + delta
        return items.indices.contains(target) ? items[target].id : nil
    }

    static func nextIDAfterRemoving(_ removedID: UUID, in items: [AttachmentRef]) -> UUID? {
        guard let removedIndex = items.firstIndex(where: { $0.id == removedID }) else { return items.first?.id }
        let remaining = items.filter { $0.id != removedID }
        guard !remaining.isEmpty else { return nil }
        return remaining[min(removedIndex, remaining.count - 1)].id
    }

    static func anchorRect(
        for id: UUID?, in items: [AttachmentRef],
        thumbnailSize: CGFloat, spacing: CGFloat, cellPadding: CGFloat
    ) -> CGRect {
        let idx = index(of: id, in: items) ?? 0
        let originX = CGFloat(idx) * (thumbnailSize + cellPadding + spacing)
        return CGRect(x: originX, y: cellPadding, width: thumbnailSize, height: thumbnailSize)
    }
}

struct AttachmentThumbnails: View {
    var items: [AttachmentRef]
    var inMemoryData: [UUID: Data] = [:]
    var thumbnailSize: CGFloat = 22
    var onRemove: ((AttachmentRef) -> Void)? = nil
    @Environment(\.workspaceHostContext) private var hostContext
    @State private var currentID: UUID?
    @State private var pendingTapID: UUID?
    @State private var pendingTapWork: DispatchWorkItem?

    private var spacing: CGFloat { thumbnailSize > 28 ? 8 : 4 }
    private var cellPadding: CGFloat { onRemove != nil ? 4 : 0 }

    private var currentAnchorRect: CGRect {
        AttachmentCarouselSelection.anchorRect(
            for: currentID, in: items, thumbnailSize: thumbnailSize, spacing: spacing, cellPadding: cellPadding
        )
    }

    private var isPopoverPresented: Binding<Bool> {
        Binding(
            get: { AttachmentCarouselSelection.index(of: currentID, in: items) != nil },
            set: { if !$0 { currentID = nil } }
        )
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                ForEach(items) { item in thumbnailCell(item) }
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: thumbnailSize + cellPadding, maximum: thumbnailSize + cellPadding), spacing: spacing)],
                alignment: .leading, spacing: spacing
            ) {
                ForEach(items) { item in thumbnailCell(item) }
            }
        }
        .popover(isPresented: isPopoverPresented, attachmentAnchor: .rect(.rect(currentAnchorRect))) {
            AttachmentPreviewCarouselView(
                items: items, currentID: $currentID, anchorRect: currentAnchorRect, imageLoader: loadedImage,
                onExpand: { openImageViewer(for: $0) },
                onRemove: onRemove.map { action in { handleRemove($0, action: action) } }
            )
            .padding(12)
        }
        .onChange(of: items.map(\.id)) { _, ids in reconcileSelection(with: ids) }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock)) { _ in cancelAndClose() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask)) { _ in cancelAndClose() }
    }

    private func thumbnailCell(_ item: AttachmentRef) -> some View {
        ZStack(alignment: .topTrailing) {
            Button { handleThumbnailTap(item) } label: { thumbnail(item) }
                .buttonStyle(.plain) // control: 附件缩略图点击区
                .help(item.filename)
                .accessibilityLabel("a11y.attachment \(item.filename)")

            if let onRemove {
                AttachmentImageResolver.removeBadge(id: item.id, font: DaybookType.caption) {
                    handleRemove(item, action: onRemove)
                }
            }
        }
        .padding(.top, cellPadding)
        .padding(.trailing, cellPadding)
    }

    private func handleThumbnailTap(_ item: AttachmentRef) {
        if PointerClickCount.current() >= 2 || (pendingTapID == item.id && pendingTapWork != nil) {
            cancelAndClose()
            openImageViewer(for: item)
            return
        }
        pendingTapWork?.cancel()
        pendingTapID = item.id
        let work = DispatchWorkItem { pendingTapWork = nil; pendingTapID = nil; currentID = item.id }
        pendingTapWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: work)
    }

    private func openImageViewer(for item: AttachmentRef) {
        currentID = nil
        AttachmentImageViewerWindowController.shared.show(
            items: items, initialID: item.id, imageLoader: loadedImage,
            onRemove: onRemove.map { action in { handleRemove($0, action: action) } }
        )
    }

    private func cancelAndClose() {
        pendingTapWork?.cancel(); pendingTapWork = nil; pendingTapID = nil; currentID = nil
    }

    private func handleRemove(_ target: AttachmentRef, action: (AttachmentRef) -> Void) {
        if currentID == target.id {
            currentID = AttachmentCarouselSelection.nextIDAfterRemoving(target.id, in: items)
        }
        action(target)
    }

    private func reconcileSelection(with ids: [UUID]) {
        guard !ids.isEmpty else { currentID = nil; return }
        if let currentID, !ids.contains(currentID) { self.currentID = ids.first }
    }

    private func thumbnail(_ item: AttachmentRef) -> some View {
        let isSelected = currentID == item.id
        let isPending = inMemoryData[item.id] != nil
        let borderColor = isSelected
            ? DaybookPalette.accent.base
            : (isPending ? DaybookPalette.accent.border : DaybookPalette.border.default)
        let lineWidth: CGFloat = isSelected ? 1.6 : (thumbnailSize > 28 ? 1.0 : 0.8)
        return AttachmentImageResolver.box(
            image: loadedImage(item), size: thumbnailSize, smallRadius: thumbnailSize > 28,
            borderColor: borderColor, lineWidth: lineWidth, placeholderFont: DaybookType.badge
        )
        .contentShape(Rectangle())
    }

    private func loadedImage(_ item: AttachmentRef) -> NSImage? {
        AttachmentImageResolver.load(item, inMemoryData: inMemoryData, hostContext: hostContext)
    }
}

struct DiaryAttachmentPill: View {
    var items: [AttachmentRef]
    var inMemoryData: [UUID: Data] = [:]
    var hasPendingAdditions: Bool = false
    var onRemove: (AttachmentRef) -> Void
    @Environment(\.workspaceHostContext) private var hostContext
    @State private var isPresented = false
    @State private var selectedID: UUID?
    @State private var pendingTapID: UUID?
    @State private var pendingTapWork: DispatchWorkItem?

    private let columns = Array(repeating: GridItem(.fixed(68), spacing: 10), count: 3)

    var body: some View {
        Button {
            selectedID = nil
            isPresented.toggle()
        } label: {
            HStack(spacing: 5) {
                if let latest = items.last { miniPreview(latest) }
                Text("drawer.attachments.title \(items.count)").font(DaybookType.caption).lineLimit(1)
                Image(systemName: "chevron.up").font(DaybookType.micro)
            }
            .fixedSize()
        }
        .buttonStyle(DaybookButtonStyle(isPresented || hasPendingAdditions ? .active : .subtle, size: .compact))
        .accessibilityIdentifier("diary.window.attachments.pill")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) { popoverContent.padding(12) }
        .onChange(of: items.isEmpty) { _, empty in if empty { dismissPopover() } }
        .onReceive(NotificationCenter.default.publisher(for: .privacyWillLock)) { _ in dismissPopover() }
        .onReceive(NotificationCenter.default.publisher(for: .privacyMask)) { _ in dismissPopover() }
    }

    private func dismissPopover() {
        pendingTapWork?.cancel(); pendingTapWork = nil; pendingTapID = nil; selectedID = nil; isPresented = false
    }

    @ViewBuilder
    private var popoverContent: some View {
        if AttachmentCarouselSelection.index(of: selectedID, in: items) != nil {
            AttachmentPreviewCarouselView(
                items: items, currentID: $selectedID, imageLoader: loadedImage,
                onBack: { selectedID = nil },
                onExpand: { openImageViewer(for: $0) },
                onRemove: { target in
                    selectedID = AttachmentCarouselSelection.nextIDAfterRemoving(target.id, in: items)
                    onRemove(target)
                }
            )
        } else {
            gridList
        }
    }

    private var gridList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("drawer.attachments.title \(items.count)")
                .font(DaybookType.subtitle).foregroundStyle(DaybookPalette.text.primary)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(items) { item in gridCell(item) }
                }
                .padding(.top, 4).padding(.trailing, 4)
            }
            .frame(width: 232).frame(maxHeight: 210)
        }
    }

    private func gridCell(_ item: AttachmentRef) -> some View {
        let isPending = inMemoryData[item.id] != nil
        let borderColor = isPending ? DaybookPalette.accent.border : DaybookPalette.border.default
        return ZStack(alignment: .topTrailing) {
            Button {
                if PointerClickCount.current() >= 2 || (pendingTapID == item.id && pendingTapWork != nil) {
                    openImageViewer(for: item)
                } else {
                    pendingTapWork?.cancel(); pendingTapID = item.id
                    let work = DispatchWorkItem { pendingTapWork = nil; pendingTapID = nil; selectedID = item.id }
                    pendingTapWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20, execute: work)
                }
            } label: {
                AttachmentImageResolver.box(
                    image: loadedImage(item), size: 68, smallRadius: true,
                    borderColor: borderColor, lineWidth: 1.0, placeholderFont: DaybookType.title
                )
            }
            .buttonStyle(.plain) // control: 附件网格卡片预览点击区
            .help(item.filename)

            AttachmentImageResolver.removeBadge(id: item.id, font: DaybookType.body) { onRemove(item) }
        }
    }

    private func openImageViewer(for item: AttachmentRef) {
        let loader = loadedImage
        dismissPopover()
        AttachmentImageViewerWindowController.shared.show(
            items: items, initialID: item.id, imageLoader: loader, onRemove: onRemove
        )
    }

    @ViewBuilder
    private func miniPreview(_ item: AttachmentRef) -> some View {
        if let image = loadedImage(item) {
            AttachmentImageResolver.box(
                image: image, size: 14, smallRadius: false,
                borderColor: DaybookPalette.border.default, lineWidth: 0.8, placeholderFont: DaybookType.micro
            )
        } else {
            Image(systemName: "photo").font(DaybookType.micro)
        }
    }

    private func loadedImage(_ item: AttachmentRef) -> NSImage? {
        AttachmentImageResolver.load(item, inMemoryData: inMemoryData, hostContext: hostContext)
    }
}

struct AttachmentPreviewCarouselView: View {
    var items: [AttachmentRef]
    @Binding var currentID: UUID?
    var anchorRect: CGRect? = nil
    var imageLoader: (AttachmentRef) -> NSImage?
    var onBack: (() -> Void)? = nil
    var onExpand: ((AttachmentRef) -> Void)? = nil
    var onRemove: ((AttachmentRef) -> Void)? = nil

    @State private var hasCopied = false
    @State private var keyMonitor: Any?
    @State private var activePopover: NSPopover?
    @State private var basePositioningRect: NSRect?
    @State private var baseAnchorX: CGFloat?

    private var currentIndex: Int { AttachmentCarouselSelection.index(of: currentID, in: items) ?? 0 }
    private var currentItem: AttachmentRef? { items.indices.contains(currentIndex) ? items[currentIndex] : items.first }
    private var canGoPrevious: Bool { currentIndex > 0 }
    private var canGoNext: Bool { currentIndex < items.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let item = currentItem {
                headerBar(for: item)
                imageStage(for: item)
            }
        }
        .frame(width: 340)
        .onAppear { installKeyMonitor() }
        .onDisappear {
            removeKeyMonitor()
            activePopover = nil; basePositioningRect = nil; baseAnchorX = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.willShowNotification)) { note in
            guard anchorRect != nil, activePopover == nil, let popover = note.object as? NSPopover else { return }
            activePopover = popover; basePositioningRect = popover.positioningRect; baseAnchorX = anchorRect?.minX
        }
        .onChange(of: anchorRect) { _, newRect in
            guard let newRect, let activePopover, activePopover.isShown,
                  let baseRect = basePositioningRect, let baseX = baseAnchorX else { return }
            var updated = baseRect
            updated.origin.x = baseRect.origin.x + (newRect.minX - baseX)
            activePopover.positioningRect = updated
        }
    }

    private func headerBar(for item: AttachmentRef) -> some View {
        HStack(spacing: 6) {
            if let onBack {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .buttonStyle(DaybookButtonStyle(.subtle, size: .compact))
                    .accessibilityIdentifier("attachment.preview.back")
            }
            if items.count > 1 {
                Text("\(currentIndex + 1) / \(items.count)")
                    .font(DaybookType.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .accessibilityIdentifier("attachment.preview.counter")
                Text("·").font(DaybookType.caption).foregroundStyle(DaybookPalette.text.tertiary)
            }
            Text(item.filename)
                .font(DaybookType.caption.weight(.medium))
                .foregroundStyle(DaybookPalette.text.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            actionCluster(for: item)
        }
    }

    private func actionCluster(for item: AttachmentRef) -> some View {
        HStack(spacing: 4) {
            if items.count > 1 {
                Button { step(by: -1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                    .disabled(!canGoPrevious)
                    .accessibilityIdentifier("attachment.preview.previous")

                Button { step(by: 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                    .disabled(!canGoNext)
                    .accessibilityIdentifier("attachment.preview.next")
            }

            if let onExpand {
                Button { onExpand(item) } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                .help("attachment.viewer.zoomIn")
                .accessibilityIdentifier("attachment.preview.expand")
            }

            Button { copyImage(item) } label: {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
            .help("diary.copy")
            .accessibilityLabel("diary.copy")
            .accessibilityIdentifier("attachment.preview.copy")

            if let onRemove {
                DaybookIconButton(systemName: "trash", label: "alert.trash.move", size: .compact, role: .destructive) {
                    onRemove(item)
                }
                .accessibilityIdentifier("attachment.preview.remove")
            }
        }
    }

    private func imageStage(for item: AttachmentRef) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .fill(DaybookPalette.fill.surface)
            if let image = imageLoader(item) {
                Image(nsImage: image).resizable().scaledToFit().padding(6)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo").font(DaybookType.title)
                    Text(item.filename).font(DaybookType.caption)
                }
                .foregroundStyle(DaybookPalette.text.secondary).padding(12)
            }
        }
        .frame(width: 340, height: 260)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onExpand?(item) }
        .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(DaybookPalette.border.default, lineWidth: 1.0)
        )
    }

    private func step(by delta: Int) {
        guard let next = AttachmentCarouselSelection.adjacentID(from: currentID, delta: delta, in: items) else { return }
        hasCopied = false
        currentID = next
    }

    private func copyImage(_ item: AttachmentRef) {
        guard let image = imageLoader(item), let pngData = ImageBytes.png(from: image) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pngData, forType: .png)
        withAnimation(.snappy) { hasCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation(.snappy) { hasCopied = false } }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
            guard flags.isEmpty, items.count > 1 else { return event }
            if event.keyCode == 123, canGoPrevious { step(by: -1); return nil }
            if event.keyCode == 124, canGoNext { step(by: 1); return nil }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
    }
}

private enum AttachmentImageResolver {
    static func load(_ item: AttachmentRef, inMemoryData: [UUID: Data], hostContext: WorkspaceHostContext?) -> NSImage? {
        if let data = inMemoryData[item.id] { return NSImage(data: data) }
        if let hostContext {
            guard let store = hostContext.attachments,
                  let data = try? store.readOrdinary(reference: item, root: store.directory()) else { return nil }
            return NSImage(data: data)
        }
        return AttachmentStore.image(reference: item)
    }

    static func removeBadge(id: UUID, font: Font, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(font)
                .foregroundStyle(DaybookPalette.text.primary)
                .background(Circle().fill(DaybookPalette.fill.surface).padding(1)) // token-exempt: 移除角标圆底，圆角由圆形自身决定
        }
        .buttonStyle(.plain) // control: 附件缩略图移除按钮
        .help("alert.trash.move")
        .accessibilityIdentifier("attachment.remove.\(id.uuidString)")
        .offset(x: 4, y: -4)
    }

    static func box(
        image: NSImage?, size: CGFloat, smallRadius: Bool,
        borderColor: Color, lineWidth: CGFloat, placeholderFont: Font
    ) -> some View {
        let radius = smallRadius ? DaybookRadius.small : DaybookRadius.xxs
        return Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").font(placeholderFont).foregroundStyle(DaybookPalette.text.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(DaybookPalette.fill.surface)
        .clipShape(RoundedRectangle(cornerRadius: smallRadius ? DaybookRadius.small : DaybookRadius.xxs, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous) // token-exempt: 圆角由 DaybookRadius.small / DaybookRadius.xxs 选择
                .strokeBorder(borderColor, lineWidth: lineWidth)
        )
    }
}
