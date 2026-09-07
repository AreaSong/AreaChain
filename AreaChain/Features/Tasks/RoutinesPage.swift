import SwiftData
import SwiftUI

struct RoutinesPage: View {
    @Environment(\.modelContext) private var modelContext
    var routines: [DailyRoutine]

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("routines.hint")
                .font(.system(size: 11))
                .foregroundStyle(DaybookTheme.muted)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if routines.isEmpty {
                        Text("routines.empty")
                            .font(.system(size: 12))
                            .foregroundStyle(DaybookTheme.muted)
                            .padding(.vertical, 4)
                    }
                    ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                        routineCard(routine, index: index)
                    }
                }
            }
            addRow
        }
    }

    private var addRow: some View {
        HStack {
            TextField("routines.new", text: $draft)
                .textFieldStyle(.plain)
                .onSubmit(addRoutine)
            Button("routines.add", action: addRoutine)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .font(.system(size: 12))
    }

    private func routineCard(_ routine: DailyRoutine, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("routines.name", text: Binding(
                get: { routine.title },
                set: { routine.title = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(DaybookTheme.ink)
            HStack(spacing: 8) {
                Toggle("routines.enabled", isOn: Binding(
                    get: { routine.isEnabled },
                    set: {
                        routine.isEnabled = $0
                        BoardEvents.changed()
                    }
                ))
                Toggle("routines.weekdays", isOn: Binding(
                    get: { routine.weekdaysOnly },
                    set: {
                        routine.weekdaysOnly = $0
                        BoardEvents.changed()
                    }
                ))
                Spacer(minLength: 0)
                Button("routines.up") { move(at: index, by: -1) }
                    .disabled(index == 0)
                Button("routines.down") { move(at: index, by: 1) }
                    .disabled(index >= routines.count - 1)
            }
            .font(.system(size: 11))
            .foregroundStyle(DaybookTheme.muted)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("routines.delete", role: .destructive) {
                modelContext.delete(routine)
                BoardEvents.changed()
            }
        }
    }

    private func addRoutine() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(DailyRoutine(title: title, sortOrder: order))
        draft = ""
        BoardEvents.changed()
    }

    private func move(at index: Int, by offset: Int) {
        let target = index + offset
        guard routines.indices.contains(target) else { return }
        let current = routines[index].sortOrder
        routines[index].sortOrder = routines[target].sortOrder
        routines[target].sortOrder = current
        BoardEvents.changed()
    }
}
