import Testing
@testable import AreaChain

struct WorkspaceAttachmentSearchTests {
    @Test func filenameUsesTextKeywordsOnly() {
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "report #家 !p1"))
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "report #家"))
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "report @15:30"))
        #expect(WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "quarter report"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "notes.pdf", query: "report #家"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "#家"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "!p1"))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "Quarter Report.pdf", query: "   "))
        #expect(!WorkspaceAttachmentQuery.matches(filename: "#家.txt", query: "#家"))
    }
}
