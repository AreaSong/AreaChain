import Foundation
import Testing
@testable import AreaChain

struct ProjectSupportTests {
    @Test func environmentReportMatchesTheIssueFormAndOmitsUserContent() {
        let report = ProjectSupport.environmentReport(ProjectSupport.Environment(
            appVersion: "0.1.0",
            buildNumber: "1",
            macOSVersion: "26.0.1",
            interfaceLanguage: "zh-Hans"
        ))
        #expect(report == """
        ### 环境 / Environment
        App 版本 / App version: 0.1.0 (1)
        macOS: 26.0.1
        界面语言 / Interface language: zh-Hans
        """)
        #expect(!report.localizedCaseInsensitiveContains("password"))
        #expect(!report.contains("手记"))
    }

    @Test func issueHandoffKeepsCopyAndBrowserSeparate() {
        #expect(ProjectSupport.issueHandoff(copied: true, opened: true) == .copied)
        #expect(ProjectSupport.issueHandoff(copied: true, opened: false) == .copiedBrowserFailed)
        #expect(ProjectSupport.issueHandoff(copied: false, opened: true) == .copyFailed)
        #expect(ProjectSupport.issueHandoff(copied: false, opened: false) == .copyFailed)
    }

    @Test func supportLinksStayOnTheProjectRepository() {
        let links = [
            ProjectSupport.repository,
            ProjectSupport.usageHelp,
            ProjectSupport.featureRequest,
            ProjectSupport.bugReport,
            ProjectSupport.license
        ]
        #expect(links.allSatisfy { $0.scheme == "https" && $0.host == "github.com" })
        #expect(ProjectSupport.usageHelp.path.hasSuffix("/discussions/categories/q-a"))
        #expect(ProjectSupport.featureRequest.path.hasSuffix("/discussions/categories/ideas"))
        #expect(ProjectSupport.bugReport.query?.contains("template=bug-report.yml") == true)
        #expect(ProjectSupport.license.path.hasSuffix("/LICENSE"))
    }

    @Test func supportCopyResolvesInBothLanguages() {
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        #expect(L10n.string("project.version.section", locale: zh) == "版本")
        #expect(L10n.string("project.version.section", locale: en) == "Version")
        #expect(L10n.string("project.support.issue", locale: zh) == "报告问题")
        #expect(L10n.string("project.support.issue", locale: en) == "Report a problem")
        #expect(L10n.string("project.support.boundary", locale: zh).contains("手记"))
        #expect(L10n.string("project.support.boundary", locale: en).contains("diary"))
        #expect(L10n.string("project.about.summary", locale: zh).contains("不会上传"))
        #expect(L10n.string("project.about.summary", locale: en).contains("not uploaded"))
    }
}
