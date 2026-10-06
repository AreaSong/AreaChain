import AppKit
import Testing
@testable import AreaChain

@MainActor final class UnifiedSearchTaskCreateFixture {
    let io: TaskCreateCommandIO
    let results: UnifiedSearchResultsFixture
    let environment: TaskCreateCommandEnvironment
    var controller: UnifiedSearchController { results.controller }

    init(assembled: Bool = true) throws {
        io = try TaskCreateCommandIO()
        environment = try io.environment()
        results = try UnifiedSearchResultsFixture(taskCreateEnvironment: assembled ? environment : nil)
    }

    func stop() { results.stop() }
    func start(title: String = "合成普通任务", day: String? = "2026-10-05") throws {
        try results.startOperation("todo.create")
        try results.typeParameter(.title, text: title)
        if let day {
            try #require(controller.editParameter(.init(parameter: .day, operation: .assign, value: .day(day)),
                                                   source: controller.buffer) != nil)
        }
    }
    func count(_ action: String) -> Int { io.capture.trace.filter { $0 == action }.count }
    func submit() { controller.requestOperationSubmit(controller.buffer) }
    var facts: CommandTaskCreateFacts { get throws { try #require(controller.settingExecution?.units.first?.taskCreation) } }
    func host(layout: UnifiedSearchInputLayout = .standard, width: CGFloat = 620,
              locale: String = "en", dark: Bool = false) async throws -> UnifiedSearchTestHost {
        _ = try await results.publish()
        let host = UnifiedSearchTestHost(layout: layout, width: width, locale: locale, dark: dark,
                                         results: controller, operations: true)
        try await host.start()
        return host
    }
}
