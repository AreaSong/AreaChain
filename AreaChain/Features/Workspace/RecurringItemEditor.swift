import SwiftData
import SwiftUI

/// 今日页新建重复事项。取消不落库；保存失败保留草稿。
struct RecurringItemEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query(sort: \TagItem.sortOrder) private var tags: [TagItem]

    @State private var draft = RecurringCaptureDraft.fresh
    @State private var titleFocused = false
    @State private var notesFocused = false
    @State private var saveFailed = false

    var body: some View {
        DaybookPage(title: "recurring.create.title", minWidth: 440, minHeight: 420) {
            form
            actions
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            SyntaxTextField(
                text: $draft.title,
                placeholder: L10n.string("recurring.create.title.placeholder", locale: locale),
                focused: $titleFocused,
                context: .capture,
                onSubmit: save
            )
            SyntaxTextEditor(
                text: $draft.notes,
                focused: $notesFocused,
                placeholder: L10n.string("recurring.create.notes", locale: locale),
                context: .capture
            )
            .frame(minHeight: 72)
            TaskDetailQuadrantGrid(isImportant: draft.isImportant, isUrgent: draft.isUrgent) { important, urgent in
                draft.isImportant = important
                draft.isUrgent = urgent
            }
            TaskDetailRemindChips(remindMinutes: draft.remindMinutes) { minutes in
                draft.remindMinutes = minutes
            }
            TaskDetailWeekdayPicker(
                resolvedMask: draft.weekdayMask,
                onUpdateMask: { draft.weekdayMask = $0 },
                allowsEmpty: true,
                accessibilityTitle: "residents.days"
            )
            if !draft.hasSelectedWeekday {
                Text("recurring.create.weekdays.required")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
            TaskDetailTagSelector(
                tagIDs: TagIDList.encode(draft.tagIDs),
                tags: tags,
                onToggleTag: { tagID in
                    draft.tagIDs = TagIDList.parse(TagIDList.toggling(TagIDList.encode(draft.tagIDs), tagID))
                },
                onCreateTag: { name in
                    guard let tag = DayBoardMutations.resolveTaskTag(named: name, context: modelContext) else { return false }
                    if !draft.tagIDs.contains(tag.id) { draft.tagIDs.append(tag.id) }
                    return true
                }
            )
            Toggle("residents.enabled", isOn: $draft.isEnabled)
                .toggleStyle(.switch)
            if saveFailed {
                Text("recurring.create.failed")
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.status.danger)
            }
        }
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("recurring.create.cancel", action: cancel)
                .buttonStyle(DaybookButtonStyle(.subtle))
            Button("common.save", action: save)
                .buttonStyle(DaybookButtonStyle(.prominent))
                .disabled(!draft.hasSelectedWeekday)
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        let order = Catalog.nextSortOrder(routines.map(\.sortOrder))
        guard DayBoardMutations.addRecurringItem(draft, sortOrder: order, context: modelContext) else {
            saveFailed = true
            return
        }
        dismiss()
    }
}
