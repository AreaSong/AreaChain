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
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { target in
            Button("alert.trash.move", role: .destructive) {
                target.confirm()
                pending.wrappedValue = nil
            }
            Button("alert.cancel", role: .cancel) {
                pending.wrappedValue = nil
            }
        } message: { target in
            Text("alert.trash.message \(target.displayTitle)")
        }
    }

    func confirmPurge(_ pending: Binding<PendingTrash?>) -> some View {
        confirmationDialog(
            "alert.purge.title",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { target in
            Button("alert.purge.one", role: .destructive) {
                target.confirm()
                pending.wrappedValue = nil
            }
            Button("alert.cancel", role: .cancel) {
                pending.wrappedValue = nil
            }
        } message: { target in
            Text("alert.purge.message \(target.displayTitle)")
        }
    }
}
