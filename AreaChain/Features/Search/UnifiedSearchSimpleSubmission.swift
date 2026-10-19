import SwiftUI

/// 简单指令沿原操作面板：准备只读出原值与新值，接受后普通提交写入一次；结果仍由原 Run 展示。
struct UnifiedSearchSimpleSubmission: View {
    @Bindable var controller: UnifiedSearchController

    var body: some View {
        let source = controller.buffer
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            if let unit = controller.simpleUnit, let facts = unit.simple { result(facts, source: source) }
            else if controller.settingExecution != nil { Text("unified.simple.held").font(DaybookType.caption) }
            else { pending(source) }
            if let failure = controller.simpleFailure {
                Text(LocalizedStringKey(failure)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.simple.issue")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain).accessibilityIdentifier("unified.simple.submission")
    }

    private func pending(_ source: UnifiedSearchBuffer) -> some View {
        let preview = controller.currentSimplePreview
        let accepted = controller.currentSimpleAcceptance != nil
        return VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text("unified.simple.pending").font(DaybookType.body)
            if !controller.hasSimple { Text("unified.simple.single").font(DaybookType.caption) }
            if let preview {
                VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
                    Text(LocalizedStringKey(preview.copy.preview)).font(DaybookType.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if preview.noChange { Text("unified.simple.noChange").font(DaybookType.caption) }
                    UnifiedSearchSimpleChangeList(changes: preview.before.changes(to: preview.after), notices: preview.after.notices)
                }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.simple.values")
                if accepted { Text("unified.simple.accepted").font(DaybookType.caption) }
                else {
                    UnifiedSearchPlanButton(title: "unified.simple.accept", identifier: "unified.simple.accept", variant: .prominent) {
                        controller.acceptSimple(preview, source: source)
                    }.disabled(controller.settingSubmitting)
                }
            } else {
                Text(controller.simplePreview == nil ? "unified.simple.baseline" : "unified.simple.stale").font(DaybookType.caption)
            }
            UnifiedSearchPlanButton(title: "unified.simple.prepare", identifier: "unified.simple.prepare") {
                controller.prepareSimple(source)
            }.disabled(controller.settingSubmitting || !controller.hasSimple)
            UnifiedSearchPlanButton(title: "unified.simple.save", identifier: "unified.simple.save", variant: .prominent) {
                controller.requestOperationSubmit(source)
            }.disabled(controller.settingSubmitting || !accepted)
        }
    }

    private func result(_ facts: CommandSimpleFacts, source: UnifiedSearchBuffer) -> some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.sm) {
            Text(LocalizedStringKey(facts.state == .saved ? controller.simpleSavedCopy(facts) : UnifiedSearchSimpleCopy.result(facts)))
                .font(DaybookType.body).accessibilityIdentifier("unified.simple.status")
            if facts.state == .saved {
                UnifiedSearchSimpleChangeList(changes: facts.before.changes(to: facts.after), notices: facts.after.notices)
                Text(facts.publication == .returned && !facts.publicationFailed ? "unified.task.published" : "unified.field.publicationIssue")
                    .font(DaybookType.caption)
                if facts.registrationFailed { Text("unified.field.registrationIssue").font(DaybookType.caption) }
            }
            if facts.conflict { Text("unified.simple.problem.changed").font(DaybookType.caption) }
            if facts.state == .unknown {
                Text("unified.simple.unknownDetail").font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                UnifiedSearchPlanButton(title: "unified.simple.verify", identifier: "unified.simple.verify") {
                    controller.verifySimpleUnknown(source)
                }
                if let verification = controller.simpleVerification {
                    Text(LocalizedStringKey(UnifiedSearchSimpleCopy.outcome(verification))).font(DaybookType.caption)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.simple.verification")
                }
            }
            Text("unified.simple.held").font(DaybookType.caption)
        }
    }
}

extension UnifiedSearchController {
    /// 回执沿接受时那份预览的文案；不重新查找指令。
    func simpleSavedCopy(_ facts: CommandSimpleFacts) -> String {
        guard let accepted = coordinator.simples.acceptances.values.first(where: { $0.id == facts.acceptanceID }) else {
            return UnifiedSearchSimpleCopy.result(facts)
        }
        return accepted.preview.copy.saved
    }
}

/// 逐行列出“对象 · 字段：原值 → 新值”；新建行没有原值。用户内容按原文显示。
/// 多于一行时先给总数；超过 sampleLimit 行只列前面若干行并说明还有多少，避免长清单撑满面板。
struct UnifiedSearchSimpleChangeList: View {
    static let sampleLimit = 20
    let changes: [CommandSimpleChange]
    var notices: [CommandSimpleNotice] = []
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            let objects = Set(changes.map(\.key)).count
            if objects > 1 {
                Text(verbatim: L10n.format("unified.simple.count", locale: locale, objects)).font(DaybookType.caption)
                    .accessibilityIdentifier("unified.simple.count")
            }
            ForEach(Array(changes.prefix(Self.sampleLimit).enumerated()), id: \.offset) { _, change in
                Text(verbatim: line(change)).font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("unified.simple.change." + change.field)
            }
            if changes.count > Self.sampleLimit {
                Text(verbatim: L10n.format("unified.simple.more", locale: locale, changes.count - Self.sampleLimit))
                    .font(DaybookType.caption).accessibilityIdentifier("unified.simple.more")
            }
            ForEach(Array(notices.enumerated()), id: \.offset) { _, notice in
                Text(verbatim: L10n.format(notice.key, locale: locale, notice.title)).font(DaybookType.caption)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("unified.simple.notice")
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("unified.simple.changes")
    }

    private func line(_ change: CommandSimpleChange) -> String {
        let field = L10n.format("unified.simple.field." + change.field, locale: locale)
        let after = text(change.after)
        guard let before = change.before else {
            return L10n.format("unified.simple.change.new", locale: locale, change.title, field, after)
        }
        return L10n.format("unified.simple.change.edit", locale: locale, change.title, field, text(before), after)
    }

    private func text(_ display: CommandSimpleDisplay) -> String {
        switch display {
        case .verbatim(let value): return value
        case .localized(let key): return L10n.format(key, locale: locale)
        case .count(let key, let value): return L10n.format(key, locale: locale, value)
        }
    }
}
