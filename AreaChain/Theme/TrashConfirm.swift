import SwiftUI

struct PendingTrash {
    var title: String
    var titleProvider: (() -> String)? = nil
    var confirm: () -> Void

    var displayTitle: String { titleProvider?() ?? title }

    static func diary(
        _ entry: DiaryEntry, tags: @escaping () -> [TagItem], locale: Locale, confirm: @escaping () -> Void
    ) -> PendingTrash {
        PendingTrash(title: "", titleProvider: {
            DiaryPrivacy.displayText(entry.snapshot, tags: tags(), locale: locale)
        }, confirm: confirm)
    }
}

extension View {
    func confirmMoveToTrash(_ pending: Binding<PendingTrash?>) -> some View {
        confirmationDialog(
            "alert.trash.title",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("alert.trash.move", role: .destructive) {
                pending.wrappedValue?.confirm()
                pending.wrappedValue = nil
            }
            Button("alert.cancel", role: .cancel) {
                pending.wrappedValue = nil
            }
        } message: {
            if let title = pending.wrappedValue?.displayTitle {
                Text("alert.trash.message \(title)")
            }
        }
    }

    func confirmPurge(_ pending: Binding<PendingTrash?>) -> some View {
        confirmationDialog(
            "alert.purge.title",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("alert.purge.one", role: .destructive) {
                pending.wrappedValue?.confirm()
                pending.wrappedValue = nil
            }
            Button("alert.cancel", role: .cancel) {
                pending.wrappedValue = nil
            }
        } message: {
            if let title = pending.wrappedValue?.displayTitle {
                Text("alert.purge.message \(title)")
            }
        }
    }
}
