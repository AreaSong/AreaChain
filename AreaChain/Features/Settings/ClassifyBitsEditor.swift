import SwiftData
import SwiftUI

struct ClassifyBitsEditor: View {
    var bits: ClassifyBits
    var projects: [CatalogChoice]
    var tags: [CatalogChoice]
    var onProject: (UUID?) -> Void
    var onToggleTag: (UUID) -> Void
    var onImportant: (Bool) -> Void
    var onUrgent: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Toggle("classify.important", isOn: Binding(
                    get: { bits.isImportant },
                    set: onImportant
                ))
                Toggle("classify.urgent", isOn: Binding(
                    get: { bits.isUrgent },
                    set: onUrgent
                ))
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 12))
            if !projects.isEmpty {
                Picker("classify.project", selection: projectBinding) {
                    Text("classify.project.none").tag(Optional<UUID>.none)
                    ForEach(projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .labelsHidden()
            }
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags) { tag in
                        let on = TagIDList.contains(bits.tagIDs, tag.id)
                        Button(tag.name) { onToggleTag(tag.id) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: on ? .semibold : .regular))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(on ? DaybookTheme.stamp.opacity(0.38) : DaybookTheme.rule.opacity(0.45))
                            .foregroundStyle(on ? DaybookTheme.ink : DaybookTheme.muted)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { bits.projectID },
            set: onProject
        )
    }
}
