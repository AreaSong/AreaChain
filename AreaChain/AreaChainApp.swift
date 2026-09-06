import SwiftData
import SwiftUI

@main
struct AreaChainApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: DailyRoutine.self, RoutineCheck.self, TodoItem.self, DiaryEntry.self)
        } catch {
            fatalError("无法打开本地数据：\(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
        .modelContainer(container)
    }
}
