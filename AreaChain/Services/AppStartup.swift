import Darwin
import Foundation
import MachO
import SwiftData

#if AREACHAIN_QA
@_cdecl("AreaChainQABuildIdentityV1")
func areaChainQABuildIdentityV1() -> Int32 { 1 }
#else
@_cdecl("AreaChainApplicationBuildIdentityV1")
func areaChainApplicationBuildIdentityV1() -> Int32 { 1 }
#endif

/// 在 SwiftUI App（包括属性包装器）构造前冻结决策。这里只读取身份，不接业务单例。
enum AppStartup {
    #if AREACHAIN_QA
    static let compiledForQA = areaChainQABuildIdentityV1() == 1
    #else
    static let compiledForQA = areaChainApplicationBuildIdentityV1() != 1
    #endif

    static let evidence = AppLaunchPolicy.Evidence(
        compiledForQA: compiledForQA,
        schema: Bundle.main.object(forInfoDictionaryKey: "AreaChainBuildIdentitySchema") as? String,
        role: Bundle.main.object(forInfoDictionaryKey: "AreaChainBuildRole") as? String,
        qaIdentifier: Bundle.main.object(forInfoDictionaryKey: "AreaChainQABundleIdentifier") as? String,
        bundleIdentifier: Bundle.main.bundleIdentifier,
        testMarkerPresent: ProcessInfo.processInfo.environment.keys.contains("XCTestConfigurationFilePath"),
        testInjectionLoaded: (0..<_dyld_image_count()).contains { index in
            guard let name = _dyld_get_image_name(index) else { return false }
            return String(cString: name).hasSuffix(
                "/Platforms/MacOSX.platform/Developer/usr/lib/libXCTestBundleInject.dylib")
        }
    )
    static let policy = AppLaunchPolicy.evaluate(evidence)

    @discardableResult static func requireAllowed() -> AppLaunchPolicy {
        if case .rejected(let reason) = policy {
            // 固定类别诊断；不打印环境值、路径、正文或凭据，也不运行退出确认/认证。
            let message = "AreaChain startup rejected: \(reason.rawValue) [78]\n"
            message.withCString { _ = fputs($0, stderr) }
            exit(78)
        }
        return policy
    }

    @MainActor static func memoryContainer() throws -> ModelContainer {
        let container = try ModelContainer(for: Schema(AreaChainSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.autosaveEnabled = false
        return container
    }
}
