import Foundation

/// 构建身份与运行身份分别核验；任何不完整的 QA 身份都不能选择生产工厂。
enum AppLaunchPolicy: Equatable {
    case application
    case testing
    case rejected(Rejection)

    enum Rejection: String, Error { case buildIdentity, testRuntime }

    struct Evidence {
        var compiledForQA: Bool
        var schema: String?
        var role: String?
        var qaIdentifier: String?
        var bundleIdentifier: String?
        var testMarkerPresent: Bool
        var testInjectionLoaded: Bool
    }

    static func evaluate(_ evidence: Evidence) -> Self {
        guard evidence.schema == "1", let identifier = evidence.bundleIdentifier, !identifier.isEmpty else {
            return .rejected(.buildIdentity)
        }
        let qaNamespace = identifier == "com.areachain.privacy-qa" || identifier.hasPrefix("com.areachain.privacy-qa.")
        if evidence.compiledForQA {
            guard evidence.role == "qa", qaNamespace, evidence.qaIdentifier == identifier else {
                return .rejected(.buildIdentity)
            }
        } else if evidence.role != "application" || qaNamespace || !(evidence.qaIdentifier ?? "").isEmpty {
            return .rejected(.buildIdentity)
        }
        // 空 marker 是当前 Xcode 的合法情况；运行时同时要求 dyld 已实际载入测试注入库。
        if evidence.testMarkerPresent && evidence.testInjectionLoaded { return .testing }
        if evidence.compiledForQA || evidence.testMarkerPresent || evidence.testInjectionLoaded {
            return .rejected(.testRuntime)
        }
        return .application
    }

    func construct<Value>(application: () throws -> Value, testing: () throws -> Value) throws -> Value {
        switch self {
        case .application: return try application()
        case .testing: return try testing()
        case .rejected(let reason): throw reason
        }
    }

    func startServices(_ application: () -> Void) throws {
        try construct(application: application, testing: {})
    }
}
