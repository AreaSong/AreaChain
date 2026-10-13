import SwiftUI

/// 工作台「数据与备份」顶部的本地存储空间检索与管理模块（圆环图 + 图例 + 三分类卡片）。
struct DataBackupStorageSection: View {
    let snapshot: LocalStorageSnapshot
    let onManageAttachments: () -> Void
    let onRequestCleanCache: () -> Void
    let onRevealInFinder: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Section("dataBackup.storage.title") {
            VStack(spacing: DaybookSpacing.md) {
                ringOverviewHeader
                categoryCardsStack
            }
            .padding(.vertical, DaybookSpacing.sm)
            .frame(maxWidth: .infinity)
        }
    }

    private var ringOverviewHeader: some View {
        VStack(spacing: DaybookSpacing.md) {
            ZStack {
                storageRingCanvas
                    .frame(width: 172, height: 172)
                ringCenterLabels
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("dataBackup.storage.ring")
            .systemPageMarker("dataBackup.storage.ring")

            legendRow
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DaybookSpacing.xs)
    }

    private var storageRingCanvas: some View {
        let fractions = snapshot.ringFractions
        let trackColor = DaybookPalette.border.subtle
        let systemColor = DaybookPalette.tagDefault
        let appColor = DaybookPalette.accent.base
        return Canvas { context, size in
            let lineWidth: CGFloat = 22
            let radius = (min(size.width, size.height) - lineWidth) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var trackPath = Path()
            trackPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            context.stroke(trackPath, with: .color(trackColor), lineWidth: lineWidth)

            let usedSpan = min(1.0, max(0.0, fractions.systemUsed + fractions.app))
            if usedSpan > 0.001 {
                var usedPath = Path()
                usedPath.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * usedSpan),
                    clockwise: false
                )
                context.stroke(
                    usedPath,
                    with: .color(systemColor),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }

            if fractions.app > 0.001 {
                var appPath = Path()
                appPath.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * fractions.app),
                    clockwise: false
                )
                context.stroke(
                    appPath,
                    with: .color(appColor),
                    style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                )
            }
        }
    }

    private var ringCenterLabels: some View {
        let totalParts = StorageByteFormat.split(snapshot.appTotalBytes)
        return VStack(spacing: DaybookSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xxs) {
                Text(totalParts.number)
                    .font(DaybookType.display.weight(.bold))
                    .foregroundStyle(DaybookPalette.text.primary)
                Text(totalParts.unit)
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)
            }
            Text(snapshot.usageRatioText(locale: locale))
                .font(DaybookType.badge)
                .foregroundStyle(DaybookPalette.text.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, DaybookSpacing.lg)
    }

    private var legendRow: some View {
        HStack(spacing: DaybookSpacing.lg) {
            legendItem(color: DaybookPalette.accent.base, title: "dataBackup.storage.legend.app")
            legendItem(color: DaybookPalette.tagDefault, title: "dataBackup.storage.legend.systemUsed")
            legendItem(color: DaybookPalette.border.default, title: "dataBackup.storage.legend.available")
        }
    }

    private func legendItem(color: Color, title: LocalizedStringKey) -> some View {
        HStack(spacing: DaybookSpacing.xs) {
            DaybookStatusDot(color: color, size: 8)
            Text(title)
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
                .lineLimit(1)
        }
    }

    private struct CategoryCardModel {
        let title: LocalizedStringKey
        let bytes: Int64
        let description: LocalizedStringKey
        let buttonTitle: LocalizedStringKey
        let buttonVariant: DaybookButtonVariant
        let buttonIdentifier: String
        let isButtonDisabled: Bool
        let action: () -> Void
    }

    private var categoryCardsStack: some View {
        VStack(spacing: DaybookSpacing.sm) {
            storageCategoryCard(CategoryCardModel(
                title: "dataBackup.storage.attachments.title",
                bytes: snapshot.attachmentsBytes,
                description: "dataBackup.storage.attachments.desc",
                buttonTitle: "dataBackup.storage.action.manage",
                buttonVariant: .quiet,
                buttonIdentifier: "dataBackup.storage.manageAttachments",
                isButtonDisabled: false,
                action: onManageAttachments
            ))

            storageCategoryCard(CategoryCardModel(
                title: "dataBackup.storage.cache.title",
                bytes: snapshot.cacheAndCleanableBytes,
                description: "dataBackup.storage.cache.desc",
                buttonTitle: "dataBackup.storage.action.clean",
                buttonVariant: .prominent,
                buttonIdentifier: "dataBackup.storage.cleanCache",
                isButtonDisabled: !snapshot.hasCleanableItems,
                action: onRequestCleanCache
            ))

            storageCategoryCard(CategoryCardModel(
                title: "dataBackup.storage.other.title",
                bytes: snapshot.databaseAndOtherBytes,
                description: "dataBackup.storage.other.desc",
                buttonTitle: "dataBackup.storage.action.finder",
                buttonVariant: .quiet,
                buttonIdentifier: "dataBackup.storage.revealFinder",
                isButtonDisabled: false,
                action: onRevealInFinder
            ))
        }
    }

    private func storageCategoryCard(_ card: CategoryCardModel) -> some View {
        let parts = StorageByteFormat.split(card.bytes)
        return HStack(alignment: .center, spacing: DaybookSpacing.md) {
            VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                Text(card.title)
                    .font(DaybookType.body.weight(.semibold))
                    .foregroundStyle(DaybookPalette.text.primary)

                HStack(alignment: .firstTextBaseline, spacing: DaybookSpacing.xxs) {
                    Text(parts.number)
                        .font(DaybookType.entity.weight(.bold))
                        .foregroundStyle(DaybookPalette.text.primary)
                    Text(parts.unit)
                        .font(DaybookType.caption.weight(.semibold))
                        .foregroundStyle(DaybookPalette.text.primary)
                }

                Text(card.description)
                    .font(DaybookType.caption)
                    .foregroundStyle(DaybookPalette.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DaybookSpacing.sm)
            Button(card.buttonTitle, action: card.action)
                .buttonStyle(DaybookButtonStyle(card.buttonVariant))
                .disabled(card.isButtonDisabled)
                .accessibilityIdentifier(card.buttonIdentifier)
                .systemPageMarker(card.buttonIdentifier)
        }
        .padding(DaybookSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .daybookStaticCardSurface()
    }
}
