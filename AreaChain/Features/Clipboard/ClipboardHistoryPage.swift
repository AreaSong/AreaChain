import SwiftUI

struct ClipboardHistoryPage: View {
    @Bindable var session = ClipboardHistorySession.shared
    @State private var showsOptions = false

    var body: some View {
        DaybookPage(
            title: "window.clipboard",
            subtitle: "clipboard.subtitle",
            minWidth: 440,
            minHeight: 480,
            trailing: {
                HStack(spacing: DaybookSpacing.sm) {
                    DaybookIconButton(
                        systemName: session.recording ? "pause" : "play",
                        label: session.recording ? "clipboard.pause" : "clipboard.resume",
                        size: .compact
                    ) {
                        session.setRecording(!session.recording)
                    }
                    DaybookIconButton(systemName: "gearshape", label: "clipboard.options", size: .compact) {
                        showsOptions = true
                    }
                    Menu {
                        Button("clipboard.clearUnpinned") { session.clear(includingPinned: false) }
                        Button("clipboard.clearAll", role: .destructive) { session.clear(includingPinned: true) }
                    } label: {
                        Image(systemName: "trash")
                            .font(DaybookType.caption.weight(.semibold))
                            .daybookMenuLabel(size: .compact)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .accessibilityLabel(Text("clipboard.clearUnpinned"))
                }
            },
            content: {
                ClipboardHistoryBrowser(session: session, showsFooter: true, commitsOnClick: false) { id, plain, paste in
                    ClipboardHistoryKeys.commit(id: id, plain: plain, paste: paste, inPanel: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        )
        .onAppear { session.pageOwnsKeys = true }
        .onDisappear { session.pageOwnsKeys = false }
        .onChange(of: showsOptions) { _, shown in
            session.pageOwnsKeys = !shown
        }
        .sheet(isPresented: $showsOptions) {
            // macOS 的 sheet 不会带上工作台的语言环境，不补上就会落回系统语言。
            ClipboardHistoryOptions(session: session)
                .appChrome()
        }
    }
}
