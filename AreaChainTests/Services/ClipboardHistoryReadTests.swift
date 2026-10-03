import Foundation
import Testing
@testable import AreaChain

@Suite(.serialized) @MainActor
struct ClipboardHistoryReadTests {
    @Test func absentRootAndAbsentFileDoNotCreateAnything() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        #expect(f.store.readHistory() == .missing)
        #expect(f.store.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: f.root.path))
        try FileManager.default.createDirectory(at: f.root, withIntermediateDirectories: true)
        #expect(f.store.readHistory() == .missing)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.root.path).isEmpty)
        #expect(f.read().state == .missing)
        #expect(try ClipboardFileFixture.response(f.read()).isCompleteForCoveredTypes)
    }

    @Test func emptyAndNonemptyFilesUseExistingFormatAndLoadCompatibility() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        try f.write([])
        #expect(f.store.readHistory() == .decoded([]))
        #expect(f.store.load().isEmpty && f.read().state == .decodedEmpty)
        let records = [ClipboardQueryFixture.record(2), ClipboardQueryFixture.record(1)]
        try f.write(records)
        #expect(f.store.readHistory() == .decoded(records))
        #expect(f.store.load() == records && f.read().state == .decodedRecords)
    }

    @Test(arguments: ["{", "[]", "{}", "{\"items\":{}}", "{\"items\":[{\"id\":\"bad\"}]}"])
    func malformedJSONAndWrongStructuresNeverBecomeEmpty(_ json: String) throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        let data = Data(json.utf8)
        try f.writeData(data)
        let temporary = f.root.appending(path: "history.json.tmp")
        let image = f.root.appending(path: "retained.png")
        try Data([1, 2]).write(to: temporary)
        try Data([3, 4]).write(to: image)
        #expect(f.store.readHistory() == .failed(.decodingFailed))
        #expect(f.store.load().isEmpty)
        #expect(f.read().state == .failed(.decodingFailed))
        let response = try ClipboardFileFixture.response(f.read())
        #expect(response.coverage.records == .failed && response.matches.isEmpty)
        #expect(response.diagnostics.map(\.issue) == [.recordsReadFailed])
        #expect(!response.isCompleteForCoveredTypes)
        #expect(try Data(contentsOf: f.file) == data)
        #expect(try Data(contentsOf: temporary) == Data([1, 2]))
        #expect(try Data(contentsOf: image) == Data([3, 4]))
    }

    @Test func directoryErrorsAreReadFailuresAndLoadStillFallsBack() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        try FileManager.default.createDirectory(at: f.file, withIntermediateDirectories: true)
        #expect(f.store.readHistory() == .failed(.fileReadFailed))
        #expect(f.store.load().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.file.path).isEmpty)
        let badRoot = f.root.appending(path: "ordinary-file")
        try Data([7]).write(to: badRoot)
        #expect(ClipboardHistoryStore(root: badRoot).readHistory() == .failed(.fileReadFailed))
    }

    @Test func injectedPermissionsAndUnknownErrorsAreNotMissingOrDisclosed() {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        let errors = [NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
                      NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
                      NSError(domain: "synthetic", code: Int(ENOENT)),
                      NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                          userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)),
                                     NSLocalizedDescriptionKey: "synthetic-private-path-and-body"])]
        for error in errors {
            let result = f.store.readHistory { _ in throw error }
            #expect(result == .failed(.fileReadFailed))
            #expect(!String(reflecting: result).contains("synthetic-private"))
        }
        #expect(f.store.readHistory { _ in throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT)) } == .missing)
        #expect(!FileManager.default.fileExists(atPath: f.root.path))
    }

    @Test func decoderDoesNotReturnTheGoodPrefixOfABadFile() throws {
        let f = ClipboardFileFixture()
        defer { f.cleanup() }
        let good = try JSONEncoder().encode(ClipboardQueryFixture.record(1))
        var data = Data("{\"items\":[".utf8)
        data.append(good)
        data.append(Data(",{\"plainText\":\"synthetic-invalid\"}]}".utf8))
        try f.writeData(data)
        #expect(f.store.readHistory() == .failed(.decodingFailed))
        #expect(f.read().batch.snapshots.clipboard.records.isEmpty)
    }
}
