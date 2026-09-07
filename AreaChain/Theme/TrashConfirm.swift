import SwiftUI

struct PendingTrash {
    var title: String
    var confirm: () -> Void
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
            if let title = pending.wrappedValue?.title {
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
            if let title = pending.wrappedValue?.title {
                Text("alert.purge.message \(title)")
            }
        }
    }
}
