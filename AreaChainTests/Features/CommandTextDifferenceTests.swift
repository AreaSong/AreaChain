import AppKit
import Testing
@testable import AreaChain

struct CommandTextDifferenceTests {
    @Test func unicodeReplacementKeepsExactUTF16AndUnchangedEdges() {
        let samples = ["", "abc", "ab中", "e\u{301}", "é", "👩🏽‍💻", "👩‍💻", "🇨🇳🇺🇸", "中\n🙂\r\n尾", "e\u{301}尾"]
        for old in samples {
            for next in samples {
                let delta = CommandNativeTextInput.difference(from: old, to: next)
                let result = (old as NSString).replacingCharacters(in: delta.range, with: delta.text)
                #expect((result as NSString).isEqual(to: next))
                #expect(CommandDraftEditingState.valid(delta.range, in: old))
            }
        }
        let large = String(repeating: "中a🙂", count: 131_072)
        let addition = CommandNativeTextInput.difference(from: large, to: large + "字")
        #expect(addition.range == NSRange(location: large.utf16.count, length: 0))
        #expect(addition.text == "字")
        let flags = String(repeating: "🇨🇳", count: 512)
        let shifted = "🇺" + flags
        let delta = CommandNativeTextInput.difference(from: flags, to: shifted)
        let result = (flags as NSString).replacingCharacters(in: delta.range, with: delta.text)
        #expect((result as NSString).isEqual(to: shifted))
        #expect(CommandDraftEditingState.valid(delta.range, in: flags))
    }
}
