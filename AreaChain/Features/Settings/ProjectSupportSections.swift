import AppKit
import SwiftUI

struct ProjectSupportSections: View {
    @Environment(\.locale) private var locale
    @State private var notice: Notice?

    private enum Notice {
        case copied
        case copiedBrowserFailed
        case copyFailed
        case linkFailed

        var key: LocalizedStringKey {
            switch self {
            case .copied: "project.support.copied"
            case .copiedBrowserFailed: "project.support.copied.browserFailed"
            case .copyFailed: "project.support.copyFailed"
            case .linkFailed: "project.support.linkFailed"
            }
        }
    }

    var body: some View {
        Section("project.version.section") {
            LabeledContent("project.version") {
                Text(verbatim: versionText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("project.version")
            .systemPageMarker("project.version")
        }

        Section("project.support.section") {
            Button {
                open(ProjectSupport.usageHelp)
            } label: {
                Text("project.support.usage")
            }
            .accessibilityIdentifier("project.support.usage")
            .buttonStyle(DaybookButtonStyle(.quiet))
            .systemPageMarker("project.support.usage")

            Button(action: reportIssue) {
                Text("project.support.issue")
            }
            .accessibilityIdentifier("project.support.issue")
            .buttonStyle(DaybookButtonStyle(.quiet))
            .systemPageMarker("project.support.issue")

            Button {
                open(ProjectSupport.featureRequest)
            } label: {
                Text("project.support.idea")
            }
            .accessibilityIdentifier("project.support.idea")
            .buttonStyle(DaybookButtonStyle(.quiet))
            .systemPageMarker("project.support.idea")

            Text("project.support.boundary")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("project.support.boundary")
                .systemPageMarker("project.support.boundary")

            if let notice {
                Text(notice.key)
                    .font(DaybookType.subtitle)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        Section("project.about.section") {
            Text("project.about.summary")
                .font(DaybookType.subtitle)
                .foregroundStyle(DaybookPalette.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("project.about.summary")
                .systemPageMarker("project.about.summary")

            Button {
                open(ProjectSupport.repository)
            } label: {
                Text("project.about.repository")
            }
            .accessibilityIdentifier("project.about.repository")
            .buttonStyle(DaybookButtonStyle(.subtle))
            .systemPageMarker("project.about.repository")

            Button {
                open(ProjectSupport.license)
            } label: {
                Text("project.about.license")
            }
            .accessibilityIdentifier("project.about.license")
            .buttonStyle(DaybookButtonStyle(.subtle))
            .systemPageMarker("project.about.license")
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var currentEnvironment: ProjectSupport.Environment {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let language = locale.identifier.hasPrefix("zh") ? "zh-Hans" : "en"
        return ProjectSupport.Environment(
            appVersion: version,
            buildNumber: build,
            macOSVersion: "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)",
            interfaceLanguage: language
        )
    }

    private func open(_ url: URL) {
        if NSWorkspace.shared.open(url) {
            if notice == .linkFailed { notice = nil }
        } else if notice == nil || notice == .linkFailed {
            notice = .linkFailed
        }
    }

    private func reportIssue() {
        let report = ProjectSupport.environmentReport(currentEnvironment)
        let board = NSPasteboard.general
        board.clearContents()
        let copied = board.setString(report, forType: .string)
        let opened = NSWorkspace.shared.open(ProjectSupport.bugReport)
        switch ProjectSupport.issueHandoff(copied: copied, opened: opened) {
        case .copied: notice = .copied
        case .copiedBrowserFailed: notice = .copiedBrowserFailed
        case .copyFailed: notice = .copyFailed
        }
    }
}
