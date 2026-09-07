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
    @State private var statusMessage: String?
    @State private var pendingImport: ExportSnapshot?
    @State private var pendingPreview: ImportPreview?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("例行项") {
                ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                    routineRow(routine, index: index)
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
                Text("全局热键 ⌘⇧A 打开菜单栏浮层")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("数据") {
                Button("导出 JSON") { exportJSON() }
                Button("导入 JSON") { importJSON() }
                if StoreHealth.shared.isUsingMemoryFallback {
                    Text("本机库打不开，当前只用内存，关掉就没了。原文件还在。")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                    Button("清空本机库并退出", role: .destructive) {
                        confirmReset = true
                    }
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
        .navigationTitle("AreaChain")
        .alert("确认导入？", isPresented: Binding(
            get: { pendingPreview != nil },
            set: { if !$0 { pendingImport = nil; pendingPreview = nil } }
        )) {
            Button("取消", role: .cancel) {
                pendingImport = nil
                pendingPreview = nil
            }
            Button("写入") { confirmImport() }
        } message: {
            Text(pendingPreview?.summary ?? "")
        }
        .confirmationDialog("会删掉本机 areachain 库，然后退出。原文件打不开才用这一步。", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("清空并退出", role: .destructive) { resetStoreAndQuit() }
            Button("取消", role: .cancel) {}
        }
    }

    private func routineRow(_ routine: DailyRoutine, index: Int) -> some View {
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
            Button("上") { moveRoutine(at: index, by: -1) }
                .disabled(index == 0)
            Button("下") { moveRoutine(at: index, by: 1) }
                .disabled(index >= routines.count - 1)
        }
        .contextMenu {
            Button("删除", role: .destructive) {
                modelContext.delete(routine)
            }
        }
    }

    private func addRoutine() {
        let title = newRoutine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (routines.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(DailyRoutine(title: title, sortOrder: order))
        newRoutine = ""
    }

    private func moveRoutine(at index: Int, by offset: Int) {
        let target = index + offset
        guard routines.indices.contains(target) else { return }
        let current = routines[index].sortOrder
        routines[index].sortOrder = routines[target].sortOrder
        routines[target].sortOrder = current
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = error.localizedDescription
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func exportJSON() {
        do {
            let data = try SyncPort.encode(
                SyncPort.makeSnapshot(routines: routines, checks: checks, todos: todos, diaries: diaries)
            )
            presentSavePanel(data: data)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let snapshot = try SyncPort.decode(try Data(contentsOf: url))
                pendingPreview = ImportPreviewing.preview(snapshot, existing: currentIDs())
                pendingImport = snapshot
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func currentIDs() -> ExistingIDs {
        ExistingIDs(
            routines: Set(routines.map(\.id)),
            todos: Set(todos.map(\.id)),
            diaries: Set(diaries.map(\.id)),
            checks: Set(checks.map(\.id))
        )
    }

    private func confirmImport() {
        guard let snapshot = pendingImport else { return }
        do {
            try SnapshotImporter.apply(snapshot, context: modelContext)
            statusMessage = "已导入"
            BoardEvents.changed()
        } catch {
            statusMessage = error.localizedDescription
        }
        pendingImport = nil
        pendingPreview = nil
    }

    private func resetStoreAndQuit() {
        Persistence.resetStoreOnDisk()
        NSApplication.shared.terminate(nil)
    }

    private func presentSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "areachain-\(DayKey.today()).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                statusMessage = "已导出"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}
