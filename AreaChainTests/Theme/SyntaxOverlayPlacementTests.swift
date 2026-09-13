import AppKit
import Testing
@testable import AreaChain

struct SyntaxOverlayPlacementTests {
    @Test func panelsPreferBelowAndFlipAboveNearTheBottom() {
        let size = CGSize(width: 380, height: 490)
        let preferred = CGSize(width: 240, height: 205)
        for y: CGFloat in [60, 410] {
            let anchor = CGRect(x: 24, y: y, width: 300, height: 30)
            let placement = SyntaxOverlayPlacement.resolve(anchor: anchor, container: size, preferred: preferred, prefersAbove: false)
            #expect(placement.growsUpward == (y == 410))
            #expect(CGRect(origin: .zero, size: size).contains(placement.frame))
            #expect(!placement.frame.intersects(anchor))
            #expect(placement.frame.size == preferred)
        }
    }

    @Test func narrowHostsConstrainThePanelAndOffscreenAnchorsDoNotPresent() {
        let size = CGSize(width: 220, height: 200)
        let anchor = CGRect(x: 175, y: 80, width: 30, height: 20)
        let placement = SyntaxOverlayPlacement.resolve(
            anchor: anchor, container: size, preferred: CGSize(width: 280, height: 280), prefersAbove: false
        )
        #expect(CGRect(origin: .zero, size: size).contains(placement.frame))
        #expect(placement.frame.width == 204)
        #expect(!placement.frame.intersects(anchor))
        #expect(SyntaxOverlayPlacement.resolve(
            anchor: CGRect(x: 0, y: 220, width: 100, height: 20), container: size,
            preferred: CGSize(width: 240, height: 100), prefersAbove: false
        ).frame == .zero)
    }

    @Test func attributePreviewUsesTheExistingParserWithoutChangingText() {
        let text = "#work #新标签 开会 !p1 @09:00"
        let attributes = CaptureAttributes(text: text, knownTags: ["Work"])
        #expect(attributes.count == 4)
        #expect(attributes.items.filter(\.isNewTag).map(\.title) == ["#新标签"])
        #expect(attributes.items.first { $0.id == "time" }?.title == "09:00")
        #expect(attributes.items.first { $0.id == "priority" }?.title == "quadrant.iu")
        #expect(CaptureAttributes(text: "普通内容", knownTags: []).count == 0)
        #expect(text == "#work #新标签 开会 !p1 @09:00")
    }

    @Test @MainActor func candidatesAndAttributesAreMutuallyExclusive() {
        let state = SyntaxAutocompleteState()
        state.update(text: "#工作", cursorLocation: 3, availableTags: ["工作"])
        #expect(state.isActive && !state.showsAttributes)
        state.showAttributes()
        #expect(!state.isActive && state.showsAttributes)
        state.update(text: "!p", cursorLocation: 2)
        #expect(state.isActive && !state.showsAttributes)
        state.dismiss()
        #expect(!state.hasPresentation)
    }

    @Test @MainActor func attributePreviewDoesNotInterruptMarkedText() {
        let state = SyntaxAutocompleteState()
        let editor = NSTextView()
        editor.setMarkedText("今", selectedRange: NSRange(location: 1, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        state.editor = editor
        state.showAttributes()
        #expect(!state.showsAttributes && editor.hasMarkedText())
    }
}
