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
                    .font(DaybookType.body.weight(.bold))
                    .foregroundStyle(DaybookPalette.accent.base)
                    .frame(width: DaybookMetrics.Hit.regular, height: DaybookMetrics.Hit.regular)
                    .accessibilityLabel("row.resident")
                    .help("row.resident")
            }

            ModernCheckbox(isDone: isDone, action: onToggle)

            Spacer()

            Button(role: .destructive, action: onTrash) {
                Image(systemName: "trash")
                    .font(DaybookType.subtitle.weight(.semibold))
                    .foregroundStyle(DaybookPalette.status.danger.opacity(0.85)) // token-exempt: 85% 危险色没有对应令牌
                    .frame(width: DaybookMetrics.Hit.regular, height: DaybookMetrics.Hit.regular)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DaybookButtonStyle(.destructive))
            .help("drawer.delete")

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(DaybookType.caption.weight(.bold))
                        .foregroundStyle(DaybookPalette.text.secondary)
                        .frame(width: DaybookMetrics.Hit.regular, height: DaybookMetrics.Hit.regular)
                        .contentShape(Rectangle())
                }
                .buttonStyle(DaybookButtonStyle(.quiet))
                .help("drawer.close.help")
            }
        }
    }
}

/// 抽屉任务大标题可编辑组件
struct TaskDetailTitleEditor: View {
    var title: String
    var onUpdate: (String) -> Bool

    @Environment(\.locale) private var locale
    @State private var isEditing = false
    @State private var draft = ""
    @State private var isFocused = false

    var body: some View {
        Group {
            if isEditing {
                SyntaxTextField(
                    text: $draft, placeholder: L10n.string("drawer.title.placeholder", locale: locale),
                    focused: $isFocused, fontSize: DaybookType.titleSize, fontWeight: .semibold,
                    onSubmit: save, onEscape: cancel
                )
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
                            .fill(DaybookPalette.fill.surface)
                    )
            } else {
                Text(title.isEmpty ? L10n.string("drawer.untitled", locale: locale) : title)
                    .font(DaybookType.headline)
                    .foregroundStyle(DaybookPalette.text.primary)
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
            guard onUpdate(trimmed) else { return }
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
                .foregroundStyle(DaybookPalette.text.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(DaybookType.micro)
                    Text("drawer.meta.created \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(DaybookType.badge)
                }
                .foregroundStyle(DaybookPalette.text.secondary)

                if !sourceBundleID.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "app.badge")
                            .font(DaybookType.micro)
                        Text("drawer.meta.source \(BundleDisplay.name(for: sourceBundleID))")
                            .font(DaybookType.badge)
                    }
                    .foregroundStyle(DaybookPalette.text.secondary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .daybookSurface(.card, configure: { $0.radius = DaybookRadius.small })
        }
    }
}
