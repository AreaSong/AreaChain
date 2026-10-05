import Foundation

/// 只保存普通设置的标量证据；签发登记在具体适配器，构造此值本身不授予执行资格。
struct CommandPreferenceBaseline: Equatable {
    enum Raw: Equatable { case missing, string(String), bool(Bool), number(String), unsupported, unavailable }
    let captureID: UUID
    let draftID: UUID
    let capturedVersion: UInt64
    let commandID: CommandID
    let instanceID: UUID
    let storageID: ObjectIdentifier
    let revision: UInt64
    let raw: Raw
    let memory: CommandValue
    let stored: CommandValue?
}

enum PreferenceCallOutcome: Equatable, Sendable { case notCalled, returned, threw }
enum PreferenceReadback: Equatable, Sendable { case notRead, matches, differs, unavailable }

/// 调用事实与提交确定性分开；抛错后读回一致仍不能将写入归因于本操作。
struct CommandPreferenceWriteFacts: Equatable {
    let write: PreferenceCallOutcome
    let readback: PreferenceReadback
    let appearance: PreferenceCallOutcome
    let event: PreferenceCallOutcome

    var presentationFailed: Bool { appearance == .threw || event == .threw }
    var isValid: Bool {
        if write == .notCalled { return readback == .notRead && appearance == .notCalled && event == .notCalled }
        if readback == .matches { return event != .notCalled }
        return [.differs, .unavailable].contains(readback) && appearance == .notCalled && event == .notCalled
    }
}

enum CommandPreferencePresentation: Equatable {
    case applied(appearance: PreferenceCallOutcome, event: PreferenceCallOutcome)
    case superseded
}
