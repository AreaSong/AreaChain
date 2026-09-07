import Testing
@testable import AreaChain

struct FirstLaunchSeederTests {
    @Test func seedsOnlyWhenEmptyAndNeverSeeded() {
        #expect(FirstLaunchSeeder.shouldSeed(existingCount: 0, alreadySeeded: false))
        #expect(!FirstLaunchSeeder.shouldSeed(existingCount: 2, alreadySeeded: false))
        #expect(!FirstLaunchSeeder.shouldSeed(existingCount: 0, alreadySeeded: true))
    }
}
