import AppKit
import SwiftUI

struct TaskDetailNotesView: View {
    let notes: String
    let onUpdate: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("备注", systemImage: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DaybookTheme.muted)
                Spacer()
                if !draft.isEmpty {
                    Text("\(draft.count) 字")
                        .font(.system(size: 9))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.6))
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(DaybookTheme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isFocused ? DaybookTheme.stamp.opacity(0.6) : DaybookTheme.rule.opacity(0.3), lineWidth: 0.8)
                    )

                if draft.isEmpty && !isFocused {
                    Text("添加详细备注、相关说明或链接...")
                        .font(.system(size: 11))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draft)
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.ink)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isFocused)
                    .padding(4)
                    .frame(minHeight: 56, maxHeight: 150)
                    .onChange(of: draft) { _, newValue in
                        onUpdate(newValue)
                    }
            }

            let links = extractURLs(from: draft)
            if !links.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷链接")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DaybookTheme.muted.opacity(0.7))
                    ForEach(links, id: \.self) { url in
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 9))
                                Text(url.absoluteString)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(DaybookTheme.stamp)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(DaybookTheme.stamp.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .onAppear {
            draft = notes
        }
        .onChange(of: notes) { _, newValue in
            if newValue != draft {
                draft = newValue
            }
        }
    }

    private func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }
    }
}
