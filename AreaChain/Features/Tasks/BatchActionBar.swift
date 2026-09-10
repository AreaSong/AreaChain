import SwiftData
import SwiftUI

/// 批量操作排期动作
struct BatchScheduleActions {
    var onMoveToday: () -> Void
    var onMoveTomorrow: () -> Void
    var onToggleDone: (Bool) -> Void

    init(
        onMoveToday: @escaping () -> Void,
        onMoveTomorrow: @escaping () -> Void,
        onToggleDone: @escaping (Bool) -> Void
    ) {
        self.onMoveToday = onMoveToday
        self.onMoveTomorrow = onMoveTomorrow
        self.onToggleDone = onToggleDone
    }
}

/// 批量操作归类与目录动作
struct BatchClassifyActions {
    var onSetProject: (UUID?) -> Void
    var onToggleTag: (UUID) -> Void
    var projects: [ProjectItem]
    var tags: [TagItem]

    init(
        onSetProject: @escaping (UUID?) -> Void,
        onToggleTag: @escaping (UUID) -> Void,
        projects: [ProjectItem] = [],
        tags: [TagItem] = []
    ) {
        self.onSetProject = onSetProject
        self.onToggleTag = onToggleTag
        self.projects = projects
        self.tags = tags
    }
}

/// 批量操作生命周期动作
struct BatchLifecycleActions {
    var onTrash: () -> Void
    var onClear: () -> Void

    init(
        onTrash: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self.onTrash = onTrash
        self.onClear = onClear
    }
}

struct BatchActionBar: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let selectedCount: Int
    let schedule: BatchScheduleActions
    let classify: BatchClassifyActions
    let lifecycle: BatchLifecycleActions

    var onMoveToday: () -> Void { schedule.onMoveToday }
    var onMoveTomorrow: () -> Void { schedule.onMoveTomorrow }
    var onToggleDone: (Bool) -> Void { schedule.onToggleDone }
    var onSetProject: (UUID?) -> Void { classify.onSetProject }
    var onToggleTag: (UUID) -> Void { classify.onToggleTag }
    var onTrash: () -> Void { lifecycle.onTrash }
    var onClear: () -> Void { lifecycle.onClear }
    var projects: [ProjectItem] { classify.projects }
    var tags: [TagItem] { classify.tags }

    init(
        selectedCount: Int,
        schedule: BatchScheduleActions,
        classify: BatchClassifyActions,
        lifecycle: BatchLifecycleActions
    ) {
        self.selectedCount = selectedCount
        self.schedule = schedule
        self.classify = classify
        self.lifecycle = lifecycle
    }

    private var taskTags: [TagItem] {
        Catalog.liveTaskTags(tags)
    }

    var body: some View {
        HStack(spacing: 10) {
            selectedCountBadge

            Divider()
                .frame(height: 14)
                .opacity(0.3)

            dateAdjustmentMenu
            statusAdjustmentMenu
            projectAssignmentMenu
            tagAssignmentMenu
            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(barBackground)
    }

    private var selectedCountBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.badge.questionmark.fill")
                .font(.system(size: 13))
                .foregroundStyle(DaybookTheme.stamp)
            Text("batch.selected \(selectedCount)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(DaybookTheme.ink)
        }
        .padding(.trailing, 4)
    }

    private var dateAdjustmentMenu: some View {
        Menu {
            Button("capture.today", action: onMoveToday)
            Button("capture.tomorrow", action: onMoveTomorrow)
        } label: {
            Label("batch.move.date", systemImage: "calendar")
                .font(.system(size: 11))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var statusAdjustmentMenu: some View {
        Menu {
            Button("batch.done") { onToggleDone(true) }
            Button("batch.undone") { onToggleDone(false) }
        } label: {
            Label("batch.status", systemImage: "checkmark.circle")
                .font(.system(size: 11))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var projectAssignmentMenu: some View {
        if !projects.isEmpty {
            Menu {
                Button("classify.project.none") { onSetProject(nil) }
                Divider()
                ForEach(projects.filter { $0.deletedAt == nil }) { proj in
                    Button(proj.name) { onSetProject(proj.id) }
                }
            } label: {
                Label("batch.project", systemImage: "folder")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    @ViewBuilder
    private var tagAssignmentMenu: some View {
        if !taskTags.isEmpty {
            Menu {
                ForEach(taskTags) { tag in
                    Button("#\(tag.name)") { onToggleTag(tag.id) }
                }
            } label: {
                Label("batch.tag", systemImage: "tag")
                    .font(.system(size: 11))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive, action: onTrash) {
                Label("alert.trash.move", systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.destructive)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DaybookTheme.muted)
            }
            .buttonStyle(.plain)
            .help("batch.clear")
        }
    }

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThickMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DaybookTheme.stamp.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}
