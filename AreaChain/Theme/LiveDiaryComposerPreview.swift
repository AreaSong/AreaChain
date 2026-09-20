import SwiftUI

/// 手记实时镜像预览卡片：在单行输入框打字时，100% 镜像呈现手记落入列表后的卡片版式。
/// 支持单行 `//` 拆分的首行粗体标题、次行灰色摘要、底栏时间戳、动态彩色标签群及隐私锁标记。
struct LiveDiaryComposerPreview: View {
    var text: String
    var allTags: [TagItem] = []
    var isSensitiveExternal: Bool = false
    var onClose: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var parsed: ParsedDiaryCapture {
        NaturalLanguageParser.parseDiaryCapture(text)
    }

    private var isSensitive: Bool {
        if isSensitiveExternal { return true }
        let names = Set(parsed.tagNames.map(TagSyntax.normalizedName))
        return allTags.contains { tag in
            tag.isPrivateDiary && names.contains(TagSyntax.normalizedName(tag.name))
        }
    }

    private var todayTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: Date())
        return L10n.format("diary.date.today", locale: locale, time)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            contentArea
            metadataLine
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 46)
        .background(
            DaybookTheme.ink.opacity(0.025),
            in: RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.small, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 0.9, dash: [3.5, 3]),
                    antialiased: true
                )
                .foregroundStyle(DaybookTheme.stamp.opacity(0.48))
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("diary.preview.card")
    }

    @ViewBuilder
    private var contentArea: some View {
        if !parsed.cleanTitle.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(parsed.cleanTitle)
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !parsed.body.isEmpty {
                    Text(parsed.body)
                        .font(DaybookType.caption)
                        .foregroundStyle(DaybookTheme.muted)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            let displayBody = parsed.body.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : parsed.body
            Text(displayBody.isEmpty ? " " : displayBody)
                .font(DaybookType.body)
                .lineSpacing(2)
                .foregroundStyle(isSensitive ? DaybookTheme.muted : DaybookTheme.ink)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 5) {
            if isSensitive {
                Image(systemName: "lock.shield")
                    .font(.system(size: 9.5))
                    .foregroundStyle(DaybookTheme.stamp)
                    .accessibilityLabel("diary.privacy")
            }

            Text(todayTimeString)
                .lineLimit(1)
                .font(DaybookType.badge)
                .foregroundStyle(DaybookTheme.muted)

            if !parsed.tagNames.isEmpty {
                HStack(spacing: 3) {
                    ForEach(parsed.tagNames, id: \.self) { tagName in
                        tagPill(tagName)
                    }
                }
            }

            Spacer(minLength: 0)

            Text("⌘↵")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(DaybookTheme.muted.opacity(0.55))
        }
        .frame(height: 22)
    }

    private func tagPill(_ name: String) -> some View {
        let color = DiaryTagChrome.color(for: name)
        return Text("#" + name)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
    }
}
