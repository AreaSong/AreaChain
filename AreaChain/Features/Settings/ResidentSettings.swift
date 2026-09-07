import SwiftData
import SwiftUI

struct ResidentSettings: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @State private var draft = ""

    private var items: [DailyRoutine] {
        routines.filter { $0.deletedAt == nil }
    }

    var body: some View {
        Section {
            if items.isEmpty {
                Text("settings.residents.empty")
                    .foregroundStyle(DaybookTheme.muted)
            }
            ForEach(items, id: \.id) { routine in
                ResidentSettingsRow(routine: routine)
            }
            addRow
        } header: {
            Text("settings.residents")
        } footer: {
            Text("settings.residents.hint")
        }
    }

    private var addRow: some View {
        HStack {
            TextField("resident.add", text: $draft)
                .onSubmit(add)
            ComposerAddButton(
                enabled: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: add
            )
        }
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        persist {
            modelContext.insert(DailyRoutine(title: title, sortOrder: order))
            draft = ""
        }
    }

    private func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }
}

private struct ResidentSettingsRow: View {
    @Environment(\.locale) private var locale
    var routine: DailyRoutine

    @State private var titleDraft = ""
    @State private var pickingTime = false
    @State private var pendingTrash: PendingTrash?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("settings.residents.rename", text: $titleDraft)
                    .onSubmit(saveTitle)
                Toggle("settings.residents.enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("settings.residents.enabled")
                RowIconButton(systemName: "trash", label: "row.delete", role: .destructive, action: requestTrash)
            }
            HStack(spacing: 12) {
                Toggle("row.weekdays", isOn: weekdaysBinding)
                Spacer()
                timeControls
            }
            .font(.system(size: 12))
        }
        .padding(.vertical, 4)
        .onAppear { titleDraft = routine.title }
        .onChange(of: routine.title) { _, value in
            if titleDraft != value { titleDraft = value }
        }
        .popover(isPresented: $pickingTime) {
            DatePicker(
                "row.time",
                selection: timeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .padding(12)
            .frame(minWidth: 180)
        }
        .confirmMoveToTrash($pendingTrash)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { routine.isEnabled },
            set: { next in persist { routine.isEnabled = next } }
        )
    }

    private var weekdaysBinding: Binding<Bool> {
        Binding(
            get: { routine.weekdaysOnly },
            set: { next in persist { routine.weekdaysOnly = next } }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                RemindMinutes.date(minutes: routine.remindMinutes ?? RemindMinutes.from(date: .now)) ?? .now
            },
            set: { date in setRemind(RemindMinutes.from(date: date)) }
        )
    }

    @ViewBuilder
    private var timeControls: some View {
        Button("row.time.set") {
            if routine.remindMinutes == nil {
                setRemind(RemindMinutes.from(date: .now))
            }
            pickingTime = true
        }
        .buttonStyle(.plain)
        .foregroundStyle(DaybookTheme.muted)
        if let minutes = routine.remindMinutes {
            Text(RemindMinutes.label(minutes, locale: locale))
                .foregroundStyle(DaybookTheme.muted)
                .monospacedDigit()
            Button("row.time.clear") { setRemind(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(DaybookTheme.muted)
        }
    }

    private func saveTitle() {
        let next = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if next.isEmpty {
            titleDraft = routine.title
            return
        }
        persist {
            routine.title = next
            titleDraft = next
        }
    }

    private func requestTrash() {
        pendingTrash = PendingTrash(title: routine.title) {
            persist { routine.deletedAt = .now }
        }
    }

    private func setRemind(_ minutes: Int?) {
        persist { routine.remindMinutes = RemindMinutes.clamped(minutes) }
        if minutes != nil {
            NotificationScheduler.shared.ensureAuthorization()
        }
    }

    private func persist(_ work: () -> Void) {
        work()
        BoardEvents.changed()
    }
}
