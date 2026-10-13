import SwiftData
import SwiftUI

extension TagManagementPage {
    func filterChip(
        title: LocalizedStringKey,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        DaybookChip(tint: DaybookPalette.accent.base, isSelected: isSelected, action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.tertiary)
            }
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(count)"))
    }

    func actionChip(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        tint: Color = DaybookPalette.accent.base,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        DaybookChip(tint: tint, isSelected: isSelected, action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .accessibilityLabel(Text(title))
    }

    var createPrivacyToggle: some View {
        DaybookChip(
            tint: DaybookPalette.accent.base,
            isSelected: createAsPrivate,
            action: { createAsPrivate.toggle() }
        ) {
            HStack(spacing: 4) {
                Image(systemName: createAsPrivate ? "lock.fill" : "lock.open")
                Text("tags.privacy.badge")
            }
        }
        .accessibilityIdentifier("tags.create.private")
    }

    @ViewBuilder var privacySelectionButtons: some View {
        if ordinarySelection.contains(where: { !$0.isPrivateDiary }) {
            actionChip(title: "tags.privacy.authorize", systemImage: "lock.fill") {
                let ids = Set(ordinarySelection.filter { !$0.isPrivateDiary }.map(\.id))
                requestSetPrivacy(ids: ids, isPrivate: true)
            }
        }
        if ordinarySelection.contains(where: \.isPrivateDiary) {
            actionChip(title: "tags.privacy.revoke", systemImage: "lock.open") {
                let ids = Set(ordinarySelection.filter(\.isPrivateDiary).map(\.id))
                requestSetPrivacy(ids: ids, isPrivate: false)
            }
        }
    }

    @ViewBuilder func tagRowContextMenu(_ tag: TagItem) -> some View {
        if tag.deletedAt == nil {
            Menu("tags.color") {
                colorMenuItems(for: [tag.id])
            }
            if tag.isPrivateDiary {
                Button {
                    requestSetPrivacy(ids: [tag.id], isPrivate: false)
                } label: {
                    Label("tags.privacy.revoke", systemImage: "lock.open")
                }
            } else {
                Button {
                    requestSetPrivacy(ids: [tag.id], isPrivate: true)
                } label: {
                    Label("tags.privacy.authorize", systemImage: "lock.fill")
                }
            }
        }
    }

    @ViewBuilder func colorMenuItems(for targetIDs: Set<UUID>) -> some View {
        ForEach(TagColorToken.allCases, id: \.self) { token in
            Button {
                applyColorToken(token.rawValue, to: targetIDs)
            } label: {
                Label {
                    Text(colorTitle(token))
                } icon: {
                    Image(nsImage: DaybookPalette.tagSwatchImage(token: token.rawValue))
                }
            }
        }
        if !customColors.colors.isEmpty {
            Divider()
            ForEach(customColors.colors) { item in
                Button {
                    applyColorToken(item.hex, to: targetIDs)
                } label: {
                    Label {
                        Text(verbatim: item.displayTitle)
                    } icon: {
                        Image(nsImage: DaybookPalette.tagSwatchImage(token: item.hex))
                    }
                }
            }
        }
        Divider()
        Button {
            beginCustomColorPicker(for: targetIDs)
        } label: {
            Label("tags.color.custom.add", systemImage: "paintpalette")
        }
    }

    func colorAccessibilityLabel(for tag: TagItem) -> Text {
        if let preset = TagColorToken(rawValue: tag.colorToken) {
            return Text(colorTitle(preset))
        }
        if let customTitle = customColors.displayName(for: tag.colorToken) {
            return Text(verbatim: customTitle)
        }
        return Text(colorTitle(.default))
    }

    var colorPickerSheet: some View {
        let targetTags = tags.filter { pendingColorTagIDs.contains($0.id) }
        let previewName = targetTags.first?.name ?? ""
        let initialHex = targetTags.first.flatMap { TagColorToken.normalizedHex($0.colorToken) } ?? "#3B82F6"
        return TagColorPickerSheet(
            previewTagName: previewName,
            initialToken: initialHex,
            onCancel: {
                showingColorPicker = false
                pendingColorTagIDs = []
            },
            onConfirm: { hex, name in
                customColors.upsert(hex: hex, name: name)
                applyColorToken(hex, to: pendingColorTagIDs)
                showingColorPicker = false
                pendingColorTagIDs = []
            }
        )
    }

    func beginCustomColorPicker(for targetIDs: Set<UUID>) {
        guard !targetIDs.isEmpty else { return }
        pendingColorTagIDs = targetIDs
        showingColorPicker = true
    }

    func applyColorToken(_ token: String, to targetIDs: Set<UUID>) {
        guard !targetIDs.isEmpty else { return }
        if DayBoardMutations.batchSetTagColor(ids: targetIDs, colorToken: token, context: modelContext) {
            pageError = nil
        } else {
            pageError = "tags.error.save"
        }
    }

    var privacySetupSheet: some View {
        PrivacySetupSheet(
            vault: vault,
            tags: Array(tags),
            creating: true,
            onComplete: {
                showingPrivacySetup = false
                pendingPrivacyTagIDs = []
            },
            initialSelectedTagIDs: pendingPrivacyTagIDs
        )
    }

    var mergeSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("tags.merge.confirm.title")
                .font(DaybookType.body.weight(.semibold))
            Text("tags.merge.confirm.message")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
            DaybookPicker("tags.merge.pickTarget", selection: Binding(
                get: { mergeTarget ?? ordinarySelection.first?.id ?? UUID() },
                set: { mergeTarget = $0 }
            ), options: ordinarySelection.map { .init($0.id, verbatim: $0.name) })
            HStack {
                Spacer()
                Button("alert.cancel") { showMerge = false }
                    .buttonStyle(DaybookButtonStyle(.quiet, size: .compact))
                Button("tags.merge") { commitMerge() }
                    .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
            }
        }
        .padding(DaybookSpacing.page)
        .frame(width: 360)
    }

    func beginMerge() {
        mergeTarget = ordinarySelection.first?.id
        showMerge = true
    }

    func commitMerge() {
        guard let target = mergeTarget else { return }
        let sources = ordinarySelection.map(\.id).filter { $0 != target }
        guard DayBoardMutations.mergeTags(sourceIDs: sources, into: target, context: modelContext) else {
            pageError = "tags.error.save"
            return
        }
        selection = [target]
        showMerge = false
        pageError = nil
    }

    func requestSetPrivacy(ids: Set<UUID>, isPrivate: Bool) {
        guard !ids.isEmpty else { return }
        guard vault.isConfigured else {
            pendingPrivacyTagIDs = isPrivate ? ids : []
            showingPrivacySetup = true
            return
        }
        let reasonKey: String.LocalizationValue = isPrivate
            ? "tags.privacy.authorize.reason"
            : "tags.privacy.revoke.reason"
        Task { @MainActor in
            do {
                try await PrivacyUnlockPresenter.shared.request(
                    reason: L10n.string(reasonKey, locale: locale),
                    force: true,
                    vault: vault
                )
                performSetPrivacy(ids: ids, isPrivate: isPrivate)
            } catch PrivacyError.cancelled {
                return
            } catch {
                pageError = (error as? PrivacyError ?? .storageFailure).messageKey
            }
        }
    }

    func performSetPrivacy(ids: Set<UUID>, isPrivate: Bool) {
        guard !ids.isEmpty else { return }
        let environment = PrivacyPersistence(context: modelContext, vault: vault)
        do {
            try DiaryProtection.setTagsPrivacy(ids, isPrivate: isPrivate, in: environment)
            pageError = nil
        } catch {
            pageError = (error as? PrivacyError ?? .storageFailure).messageKey
        }
    }
}
