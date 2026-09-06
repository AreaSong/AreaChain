import AppKit
import ServiceManagement
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRoutine.sortOrder) private var routines: [DailyRoutine]
    @Query private var checks: [RoutineCheck]
    @Query private var todos: [TodoItem]
    @Query private var diaries: [DiaryEntry]

    @State private var newRoutine = ""
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var exportError: String?

    var body: some View {
        Form {
            Section("例行项") {
                ForEach(routines, id: \.id) { routine in
                    HStack {
                        TextField("名称", text: Binding(
                            get: { routine.title },
                            set: { routine.title = $0 }
                        ))
                        Toggle("启用", isOn: Binding(
                            get: { routine.isEnabled },
                            set: { routine.isEnabled = $0 }
                        ))
                        .labelsHidden()
                        .help("启用后会出现在每天的例行清单里")
                    }
                    .contextMenu {
                        Button("删除", role: .destructive) {
                            modelContext.delete(routine)
                        }
                    }
                }
                HStack {
                    TextField("新的例行项", text: $newRoutine)
                    Button("加上") { addRoutine() }
                        .disabled(newRoutine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("启动") {
                Toggle("登录时打开", isOn: Binding(
                    get: { launchesAtLogin },
                    set: { enabled in
                        launchesAtLogin = enabled
                        updateLoginItem(enabled)
                    }
                ))
            }

            Section("数据") {
                Button("导出 JSON") { exportJSON() }
                if let exportError {
                    Text(exportError)
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
        .navigationTitle("AreaChain")
    }

    private func addRoutine() {
        let title = newRoutine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(DailyRoutine(title: title, sortOrder: order))
        newRoutine = ""
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            exportError = error.localizedDescription
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func exportJSON() {
        do {
            let snapshot = SyncPort.makeSnapshot(
                routines: routines,
                checks: checks,
                todos: todos,
                diaries: diaries
            )
            let data = try SyncPort.encode(snapshot)
            presentSavePanel(data: data)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func presentSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "areachain-\(DayKey.today()).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                exportError = nil
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}
