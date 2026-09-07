import SwiftData
import SwiftUI

@main
struct AreaChainApp: App {
    private let container: ModelContainer
    @State private var dayClock = DayClock.shared

    init() {
        container = Persistence.makeContainer()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .background(WindowOpener())
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("今日", id: "board") {
            MenuBarPopoverView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: DaybookTheme.popoverSize.width, height: DaybookTheme.popoverSize.height)
        .modelContainer(container)

        Window("日记", id: "diary") {
            DiaryStandaloneView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 420, height: 520)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
        .modelContainer(container)
    }
}
