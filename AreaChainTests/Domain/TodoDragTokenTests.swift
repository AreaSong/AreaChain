import Foundation
import Testing
@testable import AreaChain

struct TodoDragTokenTests {
    @Test func roundTripAndRejectsPlainText() {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        #expect(TodoDragToken.decode(TodoDragToken.encode(id)) == id)
        #expect(TodoDragToken.decode("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") == nil)
        #expect(TodoDragToken.decode("") == nil)
    }

    @Test func routineTokenDoesNotDecodeAsTodo() {
        let id = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let raw = TodoDragToken.encodeRoutine(id)
        #expect(TodoDragToken.decodeRoutine(raw) == id)
        #expect(TodoDragToken.decode(raw) == nil)
        #expect(TodoDragToken.decodeRoutine(TodoDragToken.encode(id)) == nil)
    }
}
