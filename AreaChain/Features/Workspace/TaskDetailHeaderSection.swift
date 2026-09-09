import SwiftUI

/// 抽屉顶部标头组件：承载完成状态、标题编辑、软删除与元信息展示
struct TaskDetailHeaderBar: View {
    var isDone: Bool
    var isRoutine: Bool = false
    var onToggle: () -> Void
    var onTrash: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            if isRoutine {
                Image(systemName: "repeat")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
            }

            ModernCheckbox(isDone: isDone, action: onToggle)

            Spacer()

            Button(role: .destructive, action: onTrash) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DaybookTheme.destructive.opacity(0.85))
                    .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DaybookQuietButtonStyle(destructive: true))
            .help("drawer.delete")

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DaybookTheme.muted)
                        .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DaybookQuietButtonStyle())
                .help("drawer.close.help")
            }
        }
    }
}

/// 抽屉任务大标题可编辑组件
struct TaskDetailTitleEditor: View {
    var title: String
    var onUpdate: (String) -> Void

    @Environment(\.locale) private var locale
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("drawer.title.placeholder", text: $draft)
                    .textFieldStyle(.plain)
                    .font(DaybookType.headline)
                    .foregroundStyle(DaybookTheme.ink)
                    .focused($isFocused)
                    .onSubmit(save)
                    .onExitCommand(perform: cancel)
                    .onChange(of: isFocused) { _, focused in
                        if !focused, isEditing {
                            if BoardSelection.shared.consumeEscapeCancelsEdits() {
                                cancel()
                            } else {
                                save()
                            }
                        }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                            .fill(DaybookTheme.surface)
                    )
            } else {
                Text(title.isEmpty ? L10n.string("drawer.untitled", locale: locale) : title)
                    .font(DaybookType.headline)
                    .foregroundStyle(DaybookTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draft = title
                        isEditing = true
                        DispatchQueue.main.async { isFocused = true }
                    }
            }
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onUpdate(trimmed)
        }
        isEditing = false
        isFocused = false
    }

    private func cancel() {
        _ = BoardSelection.shared.consumeEscapeCancelsEdits()
        draft = title
        isEditing = false
        isFocused = false
    }
}

/// 抽屉底部元信息展示组件
struct TaskDetailMetadataSection: View {
    var createdAt: Date
    var sourceBundleID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("drawer.meta.title")
                .font(DaybookType.label)
                .foregroundStyle(DaybookTheme.muted)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9))
                    Text("drawer.meta.created \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10))
                }
                .foregroundStyle(DaybookTheme.muted)

                if !sourceBundleID.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "app.badge")
                            .font(.system(size: 9))
                        Text("drawer.meta.source \(BundleDisplay.name(for: sourceBundleID))")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(DaybookTheme.muted)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modernCard(cornerRadius: DaybookRadius.small)
        }
    }
}
