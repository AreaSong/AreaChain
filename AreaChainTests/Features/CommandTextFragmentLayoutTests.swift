#if AREACHAIN_QA
import AppKit
import Testing
@testable import AreaChain

/// 先证明同一 paragraph 的有限 fragment 是否保留完整覆盖与原生断行，再考虑大文成本。
@Suite(.serialized) @MainActor struct CommandTextFragmentLayoutTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AREACHAIN_CM2_FRAGMENT_PROBE"] == "1"))
    func boundedFragmentsPreserveDefaultLines() throws {
        let text = String(repeating: "中a🙂", count: 256)
        let expected = try snapshot(text, limit: nil)
        let candidate = try snapshot(text, limit: 128)
        Attachment.record(try JSONSerialization.data(withJSONObject: [
            "baseline": expected.record, "bounded": candidate.record
        ]), named: "CM2-fragment-comparison.json")
        #expect(expected.covers(text.utf16.count))
        #expect(candidate.covers(text.utf16.count))
        #expect(candidate.lines == expected.lines)
        #expect(!candidate.exceededRequests)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["AREACHAIN_CM2_FRAGMENT_PROBE"] == "1"))
    func paragraphChildrenPreserveDefaultLines() throws {
        let text = String(repeating: "中a🙂", count: 256)
        let expected = try snapshot(text, limit: nil)
        let cuts = expected.lineEnds.enumerated().compactMap { index, end in
            (index + 1).isMultiple(of: 4) ? end : nil
        } + [text.utf16.count]
        let candidate = try snapshot(text, limit: nil, childCuts: Array(Set(cuts)).sorted())
        Attachment.record(try JSONSerialization.data(withJSONObject: [
            "baseline": expected.record, "children": candidate.record
        ]), named: "CM2-child-fragment-comparison.json")
        #expect(candidate.covers(text.utf16.count))
        #expect(candidate.lines == expected.lines)
    }

    private func snapshot(_ text: String, limit: Int?, childCuts: [Int]? = nil) throws -> Snapshot {
        let f = try ProtectedDraftFixture(configured: false)
        try f.start()
        try f.host.send(.operation(.edit(f.draft().stamp,
            .init(parameter: .notes, operation: .replace, value: .longText(text)))))
        let editor = CommandProtectedTextView(session: f.service, textSystem: .textKit2())
        editor.configureTypography(font: .systemFont(ofSize: DaybookType.bodySize), color: NSColor(DaybookPalette.text.primary))
        editor.textContainer?.size.width = 400
        let layout = try #require(editor.textLayoutManager)
        let content = try #require(editor.textContentStorage)
        let delegate = FragmentDelegate(limit: limit)
        let paragraphDelegate = childCuts.map { ChildParagraphDelegate(cuts: $0, length: text.utf16.count) }
        layout.delegate = delegate
        content.delegate = paragraphDelegate
        defer { editor.end(); layout.delegate = nil; content.delegate = nil }
        try editor.begin(using: f.service.explicitlyEditOrdinary(f.draft().stamp, expecting: f.host.owned().lease))
        layout.ensureLayout(for: content.documentRange)
        var result = Snapshot()
        layout.enumerateTextLayoutFragments(from: content.documentRange.location, options: [.ensuresLayout]) { fragment in
            let start = content.offset(from: content.documentRange.location, to: fragment.rangeInElement.location)
            let end = content.offset(from: content.documentRange.location, to: fragment.rangeInElement.endLocation)
            result.coverage.append(NSRange(location: start, length: end - start))
            for line in fragment.textLineFragments {
                let sourceStart = line.attributedString.length == end - start ? start : 0
                let range = NSRange(location: sourceStart + line.characterRange.location, length: line.characterRange.length)
                let bounds = line.typographicBounds.offsetBy(dx: fragment.layoutFragmentFrame.minX,
                                                            dy: fragment.layoutFragmentFrame.minY)
                result.lines.append(NSStringFromRange(range) + " " + NSStringFromRect(bounds))
                result.lineEnds.append(NSMaxRange(range))
            }
            return result.coverage.count < 64
        }
        #expect(editor.string == text && editor.textStorage?.length == text.utf16.count)
        result.requests = delegate.requests
        result.exceededRequests = delegate.exceededRequests
        return result
    }

    private struct Snapshot {
        var coverage: [NSRange] = []
        var lines: [String] = []
        var requests: [[String: Int]] = []
        var lineEnds: [Int] = []
        var exceededRequests = false
        func covers(_ length: Int) -> Bool {
            var next = 0
            for range in coverage {
                guard range.location == next, range.length > 0 else { return false }
                next = NSMaxRange(range)
            }
            return next == length
        }
        var record: [String: Any] {
            ["coverage": coverage.map(NSStringFromRange), "lines": lines,
             "requests": requests, "exceededRequests": exceededRequests]
        }
    }
}

@MainActor private final class FragmentDelegate: NSObject, @preconcurrency NSTextLayoutManagerDelegate {
    let limit: Int?
    var requests: [[String: Int]] = []
    var exceededRequests = false
    init(limit: Int?) { self.limit = limit }

    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager,
                                      textLayoutFragmentFor location: NSTextLocation,
                                      in textElement: NSTextElement) -> NSTextLayoutFragment {
        fragment(textLayoutManager, location: location, element: textElement)
    }

    private func fragment(_ layout: NSTextLayoutManager, location: NSTextLocation,
                          element: NSTextElement) -> NSTextLayoutFragment {
        guard let limit, let content = layout.textContentManager as? NSTextContentStorage,
              let elementRange = element.elementRange, let storage = content.textStorage else {
            return NSTextLayoutFragment(textElement: element, range: nil)
        }
        let start = content.offset(from: content.documentRange.location, to: location)
        let end = content.offset(from: content.documentRange.location, to: elementRange.endLocation)
        if requests.count >= 64 {
            exceededRequests = true
            return NSTextLayoutFragment(textElement: element, range: nil)
        }
        var boundedEnd = min(end, start + limit)
        if boundedEnd < storage.length {
            boundedEnd = (storage.string as NSString).rangeOfComposedCharacterSequence(at: boundedEnd).location
        }
        requests.append(["start": start, "elementEnd": end, "boundedEnd": boundedEnd])
        guard boundedEnd > start, let next = content.location(location, offsetBy: boundedEnd - start),
              let range = NSTextRange(location: location, end: next) else {
            return NSTextLayoutFragment(textElement: element, range: nil)
        }
        return NSTextLayoutFragment(textElement: element, range: range)
    }
}

@MainActor private final class ChildParagraphDelegate: NSObject, @preconcurrency NSTextContentStorageDelegate {
    let cuts: [Int]
    let length: Int
    init(cuts: [Int], length: Int) { self.cuts = cuts; self.length = length }

    func textContentStorage(_ textContentStorage: NSTextContentStorage,
                                        textParagraphWith range: NSRange) -> NSTextParagraph? {
        guard range.location == 0, range.length == length, let storage = textContentStorage.textStorage else { return nil }
        return ParentParagraph(value: storage.attributedSubstring(from: range), content: textContentStorage, cuts: cuts)
    }
}

private final class ParentParagraph: NSTextParagraph {
    private var parts: [NSTextElement] = []
    override var childElements: [NSTextElement] { parts }
    override var isRepresentedElement: Bool { false }

    init(value: NSAttributedString, content: NSTextContentStorage, cuts: [Int]) {
        super.init(attributedString: value)
        textContentManager = content
        var start = 0
        for end in cuts where end > start && end <= value.length {
            guard let from = content.location(content.documentRange.location, offsetBy: start),
                  let to = content.location(content.documentRange.location, offsetBy: end),
                  let range = NSTextRange(location: from, end: to) else { continue }
            let child = ChildParagraph(attributedString: value.attributedSubstring(from: NSRange(location: start, length: end - start)))
            child.textContentManager = content
            child.elementRange = range
            child.owner = self
            parts.append(child)
            start = end
        }
    }
}

private final class ChildParagraph: NSTextParagraph {
    weak var owner: NSTextElement?
    override var parent: NSTextElement? { owner }
}
#endif
