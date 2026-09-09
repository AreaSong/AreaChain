import SwiftUI

/// 抽屉顶部标头组件：承载完成状态、标题编辑、软删除与元信息展示
struct TaskDetailHeaderBar: View {
    var isDone: Bool
    var isRoutine: Bool = false
    var onToggle: () -> Void
    var onTrash: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if !isRoutine {
                ModernCheckbox(isDone: isDone, action: onToggle)
            } else {
                Image(systemName: "repeat")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DaybookTheme.stamp)
                    .frame(width: DaybookTheme.hit, height: DaybookTheme.hit)
            }

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
        }
    }
}

/// 抽屉任务大标题可编辑组件
struct TaskDetailTitleEditor: View {
    var title: String
    var onUpdate: (String) -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("drawer.title.placeholder", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DaybookTheme.ink)
                    .focused($isFocused)
                    .onSubmit(save)
                    .onExitCommand(perform: cancel)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                            .fill(DaybookTheme.surface)
                    )
            } else {
                Text(title.isEmpty ? "无标题" : title)
                    .font(.system(size: 16, weight: .semibold))
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9))
                    Text("创建于 \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10))
                }
                .foregroundStyle(DaybookTheme.muted)

                if !sourceBundleID.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "app.badge")
                            .font(.system(size: 9))
                        Text("来源：\(sourceBundleID)")
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
