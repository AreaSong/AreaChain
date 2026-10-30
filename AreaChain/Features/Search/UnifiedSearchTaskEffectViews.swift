import SwiftUI

/// 新增和标题修改共用效果展示，只消费已经形成的标签计划，不解析输入或改变顺序。
struct UnifiedSearchTaskTagSummary: View {
    let associations: [CommandTaskTagAssociation]
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: L10n.format("unified.composition.tagSummary", locale: locale,
            associations.filter { $0.effect == .createAndAssociate }.count,
            associations.filter { $0.effect == .restoreAndAssociate }.count,
            associations.filter { $0.effect == .associateLive }.count))
            .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }
}

struct UnifiedSearchTaskTagEffects: View {
    let associations: [CommandTaskTagAssociation]
    @Environment(\.locale) private var locale
    private typealias Copy = UnifiedSearchTaskCompositionCopy

    var body: some View {
        ForEach(Array(associations.enumerated()), id: \.offset) { index, tag in
            Text(verbatim: "\(index + 1). " + Copy.name(tag.target) + " · " + L10n.format(Copy.effect(tag.effect), locale: locale)
                + " · " + tag.origins.map { L10n.format($0 == .titleSyntax
                    ? "unified.composition.syntax" : "unified.composition.explicit", locale: locale) }.joined(separator: " + "))
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 保存后的提醒、日历与授权反馈：正常时不说话，只在被拒绝或失败时用一句白话说明（请求返回不等于送达或同步成功，
/// 所以“已请求”本身不作为成功展示）。调用参数保留给各提交区沿用同一入口。
struct UnifiedSearchTaskExternalFeedback: View {
    let authorizationCall: String
    let authorizationResult: String
    let notificationRequested: Bool?
    let calendarRequested: Bool?
    let unit: CommandExecutionUnit
    var externalResults: [CommandExternalEffect: CommandExternalResult]?

    var body: some View {
        let results = externalResults ?? unit.effects
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            if authorizationResult == "denied" { Text("unified.composition.authorizationDenied") }
            if results[.notification] == .failed { Text("unified.composition.notificationFailed") }
            if results[.calendar] == .failed { Text("unified.composition.calendarFailed") }
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }
}
