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
    var onApplyTag: (UUID, Bool) -> Void
    var onToggleTag: (UUID) -> Void
    var tags: [TagItem]

    init(
        onApplyTag: @escaping (UUID, Bool) -> Void = { _, _ in },
        onToggleTag: @escaping (UUID) -> Void = { _ in },
        tags: [TagItem] = []
    ) {
        self.onApplyTag = onApplyTag
        self.onToggleTag = onToggleTag
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
    var showsSchedule: Bool = true
    var showsStatus: Bool = true
    var showsEnable: Bool = false
    var onSetEnabled: ((Bool) -> Void)?
    var noteKey: LocalizedStringKey? = nil

    var onMoveToday: () -> Void { schedule.onMoveToday }
    var onMoveTomorrow: () -> Void { schedule.onMoveTomorrow }
    var onToggleDone: (Bool) -> Void { schedule.onToggleDone }
    var onApplyTag: (UUID, Bool) -> Void { classify.onApplyTag }
    var onToggleTag: (UUID) -> Void { classify.onToggleTag }
    var onTrash: () -> Void { lifecycle.onTrash }
    var onClear: () -> Void { lifecycle.onClear }
    var tags: [TagItem] { classify.tags }

    init(
        selectedCount: Int,
        schedule: BatchScheduleActions,
        classify: BatchClassifyActions,
        lifecycle: BatchLifecycleActions,
        showsSchedule: Bool = true,
        showsStatus: Bool = true,
        showsEnable: Bool = false,
        onSetEnabled: ((Bool) -> Void)? = nil,
        noteKey: LocalizedStringKey? = nil
    ) {
        self.selectedCount = selectedCount
        self.schedule = schedule
        self.classify = classify
        self.lifecycle = lifecycle
        self.showsSchedule = showsSchedule
        self.showsStatus = showsStatus
        self.showsEnable = showsEnable
        self.onSetEnabled = onSetEnabled
        self.noteKey = noteKey
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

            if showsSchedule {
                dateAdjustmentMenu
            }
            if showsStatus {
                statusAdjustmentMenu
            }
            if showsEnable {
                enableButtons
            }
            if let noteKey {
                Text(noteKey)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                .font(DaybookType.body)
                .foregroundStyle(DaybookPalette.accent.base)
            Text("batch.selected \(selectedCount)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced)) // token-exempt: 批量计数用等宽，令牌是无衬线
                .foregroundStyle(DaybookPalette.text.primary)
        }
        .padding(.trailing, 4)
    }

    private var dateAdjustmentMenu: some View {
        Menu {
            Button("capture.today", action: onMoveToday)
            Button("capture.tomorrow", action: onMoveTomorrow)
        } label: {
            Label("batch.move.date", systemImage: "calendar")
                .font(DaybookType.caption)
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
                .font(DaybookType.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    @ViewBuilder
    private var tagAssignmentMenu: some View {
        if !taskTags.isEmpty {
            Menu {
                Section("batch.tag.add") {
                    ForEach(taskTags) { tag in
                        Button("#\(tag.name)") { onApplyTag(tag.id, true) }
                    }
                }
                Section("batch.tag.remove") {
                    ForEach(taskTags) { tag in
                        Button("#\(tag.name)") { onApplyTag(tag.id, false) }
                    }
                }
            } label: {
                Label("batch.tag", systemImage: "tag")
                    .font(DaybookType.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var enableButtons: some View {
        HStack(spacing: 6) {
            Button("items.status.enabled") { onSetEnabled?(true) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
            Button("items.status.disabled") { onSetEnabled?(false) }
                .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive, action: onTrash) {
                Label("alert.trash.move", systemImage: "trash")
                    .font(DaybookType.caption)
            }
            .buttonStyle(DaybookButtonStyle(.destructive, size: .compact))

            Spacer(minLength: 8)

            DaybookIconButton(systemName: "xmark.circle.fill", label: "batch.clear", size: .compact, action: onClear)
            .help("batch.clear")
        }
    }

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
            .fill(.ultraThickMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.medium, style: .continuous)
                    .stroke(DaybookPalette.accent.border, lineWidth: 1)
            )
            .daybookElevation(.floating)
    }
}
