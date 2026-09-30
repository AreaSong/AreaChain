import Foundation

/// 补发和稍后提醒只记在本机偏好里，不改事项上保存的提醒时刻。
@MainActor
final class ReminderFollowUpStore {
    static let shared = ReminderFollowUpStore()

    private let defaults: UserDefaults
    private let key = "areachain.reminder.followup"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    struct State: Codable, Equatable {
        var catchUpDayKey: [String: String] = [:]
        var catchUpFire: [String: Date] = [:]
        var snoozeFire: [String: Date] = [:]
    }

    func followUps() -> [UUID: ReminderFollowUp] {
        var result: [UUID: ReminderFollowUp] = [:]
        let state = load()
        for (raw, day) in state.catchUpDayKey {
            guard let id = UUID(uuidString: raw) else { continue }
            result[id, default: ReminderFollowUp()].catchUpDayKey = day
        }
        for (raw, fire) in state.catchUpFire {
            guard let id = UUID(uuidString: raw) else { continue }
            result[id, default: ReminderFollowUp()].catchUpFire = fire
        }
        for (raw, fire) in state.snoozeFire {
            guard let id = UUID(uuidString: raw) else { continue }
            result[id, default: ReminderFollowUp()].snoozeFire = fire
        }
        return result
    }

    func markCatchUps(_ fires: [UUID: Date], dayKey: String) {
        guard !fires.isEmpty else { return }
        var state = load()
        for (id, fire) in fires {
            state.catchUpDayKey[id.uuidString] = dayKey
            state.catchUpFire[id.uuidString] = fire
        }
        save(state)
    }

    func snooze(id: UUID, until: Date, dayKey: String) {
        var state = load()
        state.snoozeFire[id.uuidString] = until
        state.catchUpDayKey[id.uuidString] = dayKey
        save(state)
    }

    func clear(_ ids: some Sequence<UUID>) {
        var state = load()
        var changed = false
        for id in ids {
            let raw = id.uuidString
            if state.catchUpDayKey.removeValue(forKey: raw) != nil { changed = true }
            if state.catchUpFire.removeValue(forKey: raw) != nil { changed = true }
            if state.snoozeFire.removeValue(forKey: raw) != nil { changed = true }
        }
        if changed { save(state) }
    }

    private func load() -> State {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
    }

    private func save(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}
