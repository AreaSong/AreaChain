import SwiftUI

struct WorkspaceReadOnlyContentView: View {
    @Bindable var session: WorkspaceContentSession
    let object: CommandObjectReference
    let controller: UnifiedSearchController
    @Environment(\.workspaceSearchRouter) private var router

    var body: some View {
        Group {
            if let content = session.content, session.validate() {
                switch content {
                case .tag(let tag): WorkspaceFilteredListView(tag: tag, readOnly: true)
                case .diary(let value): diary(value)
                case .image(let image, let filename, let owner, let label):
                    imageContent(image, filename: filename, owner: owner, label: label)
                }
            } else {
                DaybookEmptyState(title: LocalizedStringKey("unified.content." + (session.failure?.rawValue ?? "stale")),
                                  systemImage: "eye.slash")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DaybookPalette.fill.page)
        .background(WorkspaceNavigationProbe(router: router, key: "content." + object.id.uuidString))
        .background(WorkspaceContentReturnKey(controller: controller))
    }

    private func diary(_ value: WorkspaceDiaryContent) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            Text(verbatim: value.day).font(DaybookType.title)
            if !value.tags.isEmpty {
                Text(verbatim: value.tags.map { "#" + $0 }.joined(separator: "  "))
                    .font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
            }
            DaybookSearchReadOnlyText(text: value.text, identifier: "unified.content.diaryText", collapse: {
                guard let ticket = controller.returnSearch else { return }
                Task { await controller.returnToSearch(ticket.id) }
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DaybookSpacing.lg)
        .accessibilityIdentifier("unified.content.diary")
    }

    private func imageContent(_ image: NSImage, filename: String,
                              owner: CommandObjectReference, label: String) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.md) {
            Text(verbatim: filename).font(DaybookType.title).textSelection(.enabled)
            Text(verbatim: label).font(DaybookType.caption).foregroundStyle(DaybookPalette.text.secondary)
            LoadedAttachmentImage(image: image)
                .accessibilityLabel(Text(verbatim: filename))
                .accessibilityIdentifier("unified.content.actualImage")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button("unified.content.openOwner") { controller.openContentOwner(owner) }
                .buttonStyle(DaybookButtonStyle(.subtle))
                .accessibilityIdentifier("unified.content.openOwner")
            Text(LocalizedStringKey(controller.contentOwnerMessage)).font(DaybookType.caption)
                .accessibilityIdentifier("unified.content.ownerMessage")
        }
        .padding(DaybookSpacing.lg)
    }
}
