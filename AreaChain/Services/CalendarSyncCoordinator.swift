import Foundation

@MainActor
final class CalendarSyncCoordinator {
    private let engine: CalendarSyncEngine
    private let enabled: () -> Bool
    private let publish: (CalendarSyncOutcome) -> Void
    private var running: Task<Void, Never>?
    private var pending = false
    private var generation = 0

    init(engine: CalendarSyncEngine, enabled: @escaping () -> Bool, publish: @escaping (CalendarSyncOutcome) -> Void) {
        self.engine = engine
        self.enabled = enabled
        self.publish = publish
    }

    @discardableResult
    func request() -> Task<Void, Never>? {
        guard enabled() else { stop(); return nil }
        pending = true
        if let running { return running }
        let token = generation
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            repeat {
                self.pending = false
                let outcome = await self.engine.synchronize {
                    token == self.generation && self.enabled() && !Task.isCancelled
                }
                guard token == self.generation, !Task.isCancelled else { return }
                self.publish(outcome)
            } while self.pending && self.enabled()
            if token == self.generation { self.running = nil }
        }
        running = task
        return task
    }

    func stop() {
        generation += 1
        pending = false
        running?.cancel()
        running = nil
        publish(CalendarSyncOutcome(phase: .off))
    }
}
