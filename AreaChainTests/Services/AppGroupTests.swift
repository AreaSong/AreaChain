import XCTest
@testable import AreaChain

final class AppGroupTests: XCTestCase {
    func test_identifier_is_stable_and_not_empty() {
        XCTAssertEqual(AppGroup.identifier, "group.com.areachain.app")
    }

    func test_storeURL_is_valid_and_named_areachain_store() {
        let storeURL = AppGroup.storeURL
        #if DEBUG
        XCTAssertEqual(storeURL.lastPathComponent, "areachain-debug.store")
        #else
        XCTAssertEqual(storeURL.lastPathComponent, "areachain.store")
        #endif
        XCTAssertFalse(storeURL.path.isEmpty)
    }

    func test_containerURL_resolves_to_directory() {
        let container = AppGroup.containerURL
        XCTAssertTrue(container.hasDirectoryPath)
    }
}
